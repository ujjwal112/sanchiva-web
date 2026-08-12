/// Google Sign-In configuration.
///
/// [serverClientId] must be the **Web application** OAuth client ID
/// (same as server `GOOGLE_CLIENT_ID`) so Android returns an ID token
/// the API can verify.
///
/// Default is the production Sanchiva Web client so installs work without
/// dart-define. Override when needed:
/// ```bash
/// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=other.apps.googleusercontent.com
/// ```
class GoogleConfig {
  /// Web OAuth client ID (not the Android client secret).
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '651417817054-tve9nnubpeqb7apb9kl00ukpeo77o16b.apps.googleusercontent.com',
  );

  /// Optional Android OAuth client id (usually not needed if serverClientId is set).
  static const String androidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isConfigured => serverClientId.isNotEmpty;
}
