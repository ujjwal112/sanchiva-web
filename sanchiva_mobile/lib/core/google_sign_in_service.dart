import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_config.dart';

/// Thrown when the user dismisses the Google account picker (not a real error).
class GoogleSignInCanceled implements Exception {
  @override
  String toString() => 'GoogleSignInCanceled';
}

bool isGoogleSignInCanceled(Object e) {
  if (e is GoogleSignInCanceled) return true;
  if (e is GoogleSignInException) {
    return e.code == GoogleSignInExceptionCode.canceled ||
        e.code == GoogleSignInExceptionCode.interrupted;
  }
  final s = e.toString().toLowerCase();
  return s.contains('canceled') ||
      s.contains('cancelled') ||
      s.contains('sign_in_canceled') ||
      s.contains('signincanceled');
}

/// Wraps google_sign_in 7.x for one-shot sign-in + tokens for our API.
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!GoogleConfig.isConfigured) {
      throw Exception(
        'Google Sign-In is not configured. '
        'Pass --dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID from Google Cloud>.',
      );
    }
    await GoogleSignIn.instance.initialize(
      serverClientId: GoogleConfig.serverClientId,
      clientId: GoogleConfig.androidClientId.isEmpty
          ? null
          : GoogleConfig.androidClientId,
    );
    _initialized = true;
  }

  /// Interactive Google sign-in. Returns profile + tokens for backend exchange.
  /// Throws [GoogleSignInCanceled] if the user dismisses the picker.
  Future<GoogleAuthResult> signIn() async {
    await ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception('Google Sign-In is not supported on this platform.');
    }

    late final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw GoogleSignInCanceled();
      }
      rethrow;
    } catch (e) {
      if (isGoogleSignInCanceled(e)) throw GoogleSignInCanceled();
      rethrow;
    }

    final idToken = account.authentication.idToken;
    String? accessToken;
    try {
      final authz = await account.authorizationClient.authorizationForScopes(
        const ['email', 'profile'],
      );
      accessToken = authz?.accessToken;
    } catch (e) {
      if (isGoogleSignInCanceled(e)) throw GoogleSignInCanceled();
      debugPrint('[GoogleSignIn] access token optional: $e');
    }

    if ((idToken == null || idToken.isEmpty) &&
        (accessToken == null || accessToken.isEmpty)) {
      throw Exception(
        'Google did not return a token. Check GOOGLE_SERVER_CLIENT_ID '
        '(Web client ID) and that Android OAuth client + SHA-1 are set in Google Cloud.',
      );
    }

    return GoogleAuthResult(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    try {
      if (!_initialized) await ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[GoogleSignIn] signOut: $e');
    }
  }
}

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.idToken,
    this.accessToken,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? idToken;
  final String? accessToken;
}
