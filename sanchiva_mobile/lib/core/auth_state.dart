import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'google_sign_in_service.dart';
import 'notification_inbox.dart';
import '../services/notification_service.dart';

const _guestAccess = 'sanchiva.guest.local';
const _guestFlag = 'sanchiva.is_guest_session';

class AuthState extends ChangeNotifier {
  AuthState() {
    _bootstrap();
  }

  final _api = ApiClient.instance;
  Map<String, dynamic>? user;
  bool loading = true;
  String? error;

  bool get isAuthenticated => user != null;
  bool get isGuest =>
      user?['is_guest'] == true || user?['auth_provider'] == 'guest';
  bool get isGoogleUser =>
      user?['auth_provider'] == 'google' || user?['provider'] == 'google';
  String? get googlePhotoUrl {
    final u = user?['photo_url']?.toString() ?? user?['picture']?.toString();
    if (u == null || u.isEmpty) return null;
    return u;
  }

  Future<void> _bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      // Hard cap so a hung network can never freeze the splash forever.
      await _bootstrapInner().timeout(const Duration(seconds: 15));
    } catch (_) {
      // Timeout or unexpected error — try cached session, never hang.
      try {
        await _restoreCachedUser();
      } catch (_) {
        user = null;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final guest = prefs.getBool(_guestFlag) ?? false;
    await _api.loadTokens();

    if (guest || _api.accessToken == _guestAccess) {
      user = _localGuestUser();
      await _bindInboxForUser(user);
      return;
    }
    if (!_api.hasToken) {
      user = null;
      await _bindInboxForUser(null);
      return;
    }
    final name = prefs.getString('sanchiva.user.name') ?? 'User';
    final email = prefs.getString('sanchiva.user.email') ?? '';
    final photo = prefs.getString('sanchiva.user.photo_url');
    final provider = prefs.getString('sanchiva.user.auth_provider') ?? 'local';
    user = {
      'id': prefs.getString('sanchiva.user.id') ?? 'cached',
      'name': name,
      'email': email,
      'is_guest': false,
      'auth_provider': provider,
      if (photo != null && photo.isNotEmpty) 'photo_url': photo,
    };
    await _bindInboxForUser(user);
  }

  Future<void> _bootstrapInner() async {
    final prefs = await SharedPreferences.getInstance();
    final guest = prefs.getBool(_guestFlag) ?? false;
    await _api.loadTokens();

    if (guest || _api.accessToken == _guestAccess) {
      user = _localGuestUser();
      await _bindInboxForUser(user);
      return;
    }

    if (!_api.hasToken) {
      user = null;
      await _bindInboxForUser(null);
      return;
    }

    try {
      final me = await _api.get('/auth/me');
      user = _mapApiUser(me);
      await _saveUserPrefs(user!);
      await _bindInboxForUser(user);
    } catch (_) {
      // Offline / expired / timeout — fall back to cached profile if we have tokens
      await _restoreCachedUser();
    }
  }

  Map<String, dynamic> _localGuestUser() => {
        'id': 'guest-local',
        'name': 'Guest',
        'email': '',
        'is_guest': true,
        'auth_provider': 'guest',
      };

  Map<String, dynamic> _mapApiUser(Map<String, dynamic> u) {
    final provider = u['provider']?.toString() ?? 'local';
    final picture = u['picture']?.toString() ?? u['photo_url']?.toString();
    return {
      'id': u['id']?.toString() ?? '',
      'name': u['name']?.toString() ?? 'User',
      'email': u['email']?.toString() ?? '',
      'is_guest': provider == 'guest',
      'auth_provider': provider,
      'provider': provider,
      if (picture != null && picture.isNotEmpty) 'photo_url': picture,
      if (picture != null && picture.isNotEmpty) 'picture': picture,
    };
  }

  Future<void> _saveUserPrefs(Map<String, dynamic> u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sanchiva.user.id', u['id']?.toString() ?? '');
    await prefs.setString('sanchiva.user.name', u['name']?.toString() ?? '');
    await prefs.setString('sanchiva.user.email', u['email']?.toString() ?? '');
    await prefs.setString(
      'sanchiva.user.auth_provider',
      u['auth_provider']?.toString() ?? u['provider']?.toString() ?? 'local',
    );
    final photo = u['photo_url']?.toString() ?? u['picture']?.toString();
    if (photo != null && photo.isNotEmpty) {
      await prefs.setString('sanchiva.user.photo_url', photo);
    } else {
      await prefs.remove('sanchiva.user.photo_url');
    }
  }

  /// Bind inbox (+ cancel system schedules when logged out) to the active account.
  Future<void> _bindInboxForUser(Map<String, dynamic>? u) async {
    final id = u?['id']?.toString();
    try {
      await NotificationInboxState.instance?.setUser(id);
    } catch (e) {
      debugPrint('bind inbox: $e');
    }
  }

  Future<void> _applyTokenResponse(Map<String, dynamic> data) async {
    final access = data['access_token']?.toString();
    final refresh = data['refresh_token']?.toString();
    if (access == null || access.isEmpty) {
      throw Exception('No access token from server');
    }
    await _api.setTokens(access, refresh ?? '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestFlag, false);

    Map<String, dynamic> u;
    if (data['user'] is Map) {
      u = _mapApiUser(Map<String, dynamic>.from(data['user'] as Map));
    } else {
      final me = await _api.get('/auth/me');
      u = _mapApiUser(me);
    }
    user = u;
    await _saveUserPrefs(u);
    await _bindInboxForUser(u);
  }

  Future<void> login({required String email, required String password}) async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final data = await _api.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      await _applyTokenResponse(data);
    } catch (e) {
      error = e.toString().replaceFirst('ApiException: ', '');
      // Fallback local login if API unreachable (dev)
      if (error!.contains('Cannot reach API') || error!.contains('SocketException')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_guestFlag, false);
        await _api.setTokens('local-user-access', 'local-user-refresh');
        user = {
          'id': 'local-user',
          'name': email.trim().split('@').first,
          'email': email.trim(),
          'is_guest': false,
          'auth_provider': 'local',
        };
        await _saveUserPrefs(user!);
        await _bindInboxForUser(user);
        error = null;
      } else {
        rethrow;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Real Google Sign-In → POST /api/auth/google/mobile → JWT session.
  /// Throws [GoogleSignInCanceled] if the user dismisses the account picker (no error UI).
  Future<void> loginWithGoogle() async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final g = await GoogleSignInService.instance.signIn();
      final body = <String, dynamic>{};
      if (g.idToken != null && g.idToken!.isNotEmpty) {
        body['id_token'] = g.idToken;
      }
      if (g.accessToken != null && g.accessToken!.isNotEmpty) {
        body['access_token'] = g.accessToken;
      }

      final data = await _api.post('/auth/google/mobile', body);
      await _applyTokenResponse(data);

      // Prefer Google picture if API user missing picture but account has one
      if ((user?['photo_url'] == null || user!['photo_url'].toString().isEmpty) &&
          g.photoUrl != null) {
        user = {
          ...user!,
          'photo_url': g.photoUrl,
          'picture': g.photoUrl,
        };
        await _saveUserPrefs(user!);
      }
    } on GoogleSignInCanceled {
      error = null;
      rethrow; // UI should ignore silently
    } catch (e) {
      if (isGoogleSignInCanceled(e)) {
        error = null;
        throw GoogleSignInCanceled();
      }
      error = e.toString().replaceFirst('ApiException: ', '');
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loginGuest() async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final data = await _api.post('/auth/guest');
      await _applyTokenResponse(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestFlag, true);
    } catch (e) {
      // Offline guest fallback
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestFlag, true);
      await _api.setTokens(_guestAccess, 'guest-local-refresh');
      user = _localGuestUser();
      await _bindInboxForUser(user);
      error = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      if (password != confirmPassword) {
        throw Exception('Passwords do not match');
      }
      final data = await _api.post('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      });
      await _applyTokenResponse(data);
    } catch (e) {
      error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestFlag, false);
    try {
      if (_api.hasToken && _api.accessToken != _guestAccess) {
        await _api.post('/auth/logout', {
          if (_api.accessToken != null) 'refresh_token': '', // refresh cleared client-side
        });
      }
    } catch (_) {
      /* ignore */
    }
    try {
      await GoogleSignInService.instance.signOut();
    } catch (_) {
      /* ignore */
    }
    try {
      await _api.clearTokens();
    } catch (_) {
      /* ignore */
    }
    // Detach inbox from account + cancel system EMI schedules (device-wide).
    try {
      await NotificationInboxState.instance?.setUser(null);
      await NotificationService.instance.cancelAll();
    } catch (_) {
      /* ignore */
    }
    user = null;
    notifyListeners();
  }
}
