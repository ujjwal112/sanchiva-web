import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'local_date.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

enum _RefreshResult { success, invalid, networkError, noToken }

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _accessKey = 'sanchiva_access_token';
  static const _refreshKey = 'sanchiva_refresh_token';

  /// Prevents hung sockets from freezing splash / login forever.
  /// Splits writes + guest seed can take a bit longer on mobile networks.
  static const Duration requestTimeout = Duration(seconds: 30);

  String? _access;
  String? _refresh;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString(_accessKey);
    _refresh = prefs.getString(_refreshKey);
  }

  Future<void> setTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  bool get hasToken => (_access != null && _access!.isNotEmpty);
  bool get hasRefreshToken => (_refresh != null && _refresh!.isNotEmpty);
  String? get accessToken => _access;
  String? get refreshToken => _refresh;

  /// Offline / dev-only tokens — never call /auth/refresh (server would 401 and wipe session).
  bool get isLocalOnlySession {
    final a = _access ?? '';
    final r = _refresh ?? '';
    if (a == 'sanchiva.guest.local' || a == 'local-user-access') return true;
    if (r == 'guest-local-refresh' || r == 'local-user-refresh') return true;
    return false;
  }

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body: body);
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);

  Future<List<dynamic>> getList(String path) async {
    final data = await _requestRaw('GET', path);
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'] as List;
    throw ApiException('Expected list response');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    final data = await _requestRaw(method, path, body: body, retry: retry);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }

  Future<dynamic> _requestRaw(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    final uri = Uri.parse(ApiConfig.api(path));
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Phone local calendar day — server uses this for “today” / day-wise KPIs.
      'X-Client-Local-Date': localDateYmd(),
    };
    if (_access != null && _access!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_access';
    }

    late http.Response res;
    try {
      final Future<http.Response> future;
      switch (method) {
        case 'GET':
          future = http.get(uri, headers: headers);
          break;
        case 'POST':
          future = http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PUT':
          future = http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PATCH':
          future = http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'DELETE':
          future = http.delete(uri, headers: headers);
          break;
        default:
          throw ApiException('Unsupported method $method');
      }
      res = await future.timeout(requestTimeout);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Cannot reach API (${ApiConfig.baseUrl}). Is the server running?');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      data = {'error': res.body};
    }

    // Access expired → try refresh. Never wipe tokens on network blips or local-only sessions.
    if (res.statusCode == 401 &&
        retry &&
        !isLocalOnlySession &&
        _refresh != null &&
        _refresh!.isNotEmpty &&
        !path.startsWith('/auth/')) {
      final result = await _refreshAccess();
      if (result == _RefreshResult.success) {
        return _requestRaw(method, path, body: body, retry: false);
      }
      if (result == _RefreshResult.invalid) {
        // Server rejected refresh — only then end the session storage.
        await clearTokens();
        throw ApiException('Session expired', statusCode: 401);
      }
      // Network error while refreshing: keep tokens, surface offline error.
      throw ApiException(
        'Cannot refresh session (offline). Try again when online.',
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode >= 400) {
      final msg = data is Map ? (data['error']?.toString() ?? res.reasonPhrase) : res.reasonPhrase;
      throw ApiException(msg ?? 'Request failed', statusCode: res.statusCode);
    }
    return data;
  }

  Future<_RefreshResult> _refreshAccess() async {
    if (isLocalOnlySession) return _RefreshResult.success;
    if (_refresh == null || _refresh!.isEmpty) return _RefreshResult.noToken;
    try {
      final uri = Uri.parse(ApiConfig.api('/auth/refresh'));
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': _refresh}),
          )
          .timeout(requestTimeout);
      // Only definitive auth failures end the session.
      if (res.statusCode == 401 || res.statusCode == 403) {
        return _RefreshResult.invalid;
      }
      // 5xx / 429 / other errors: keep tokens (temporary server / network issues).
      if (res.statusCode >= 400) return _RefreshResult.networkError;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final access = data['access_token']?.toString();
      final refresh = data['refresh_token']?.toString();
      if (access == null || access.isEmpty) return _RefreshResult.invalid;
      await setTokens(access, refresh ?? _refresh!);
      return _RefreshResult.success;
    } catch (_) {
      return _RefreshResult.networkError;
    }
  }

  /// Proactively refresh if we have a refresh token (e.g. app resume).
  /// Returns true if the session is still usable. Never clears tokens on offline.
  Future<bool> tryRefreshSession() async {
    if (isLocalOnlySession) return hasToken;
    if (!hasRefreshToken) return hasToken;
    final result = await _refreshAccess();
    if (result == _RefreshResult.success) return true;
    if (result == _RefreshResult.invalid) {
      await clearTokens();
      return false;
    }
    // Offline / server blip: keep existing tokens
    return hasToken;
  }
}
