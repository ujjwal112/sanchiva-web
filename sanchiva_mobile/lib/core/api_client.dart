import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

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
  String? get accessToken => _access;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body: body);
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

    if (res.statusCode == 401 && retry && _refresh != null && !path.startsWith('/auth/')) {
      final ok = await _refreshAccess();
      if (ok) return _requestRaw(method, path, body: body, retry: false);
      await clearTokens();
      throw ApiException('Session expired', statusCode: 401);
    }

    if (res.statusCode >= 400) {
      final msg = data is Map ? (data['error']?.toString() ?? res.reasonPhrase) : res.reasonPhrase;
      throw ApiException(msg ?? 'Request failed', statusCode: res.statusCode);
    }
    return data;
  }

  Future<bool> _refreshAccess() async {
    if (_refresh == null) return false;
    try {
      final uri = Uri.parse(ApiConfig.api('/auth/refresh'));
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': _refresh}),
          )
          .timeout(requestTimeout);
      if (res.statusCode >= 400) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await setTokens(data['access_token'] as String, data['refresh_token'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }
}
