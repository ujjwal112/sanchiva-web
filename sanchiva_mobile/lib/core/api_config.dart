import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Backend API configuration.
///
/// Override anytime:
/// ```bash
/// flutter run --dart-define=API_BASE=https://sanchivaorg.duckdns.org
/// flutter run --dart-define=API_BASE=http://localhost:5000
/// flutter run --dart-define=API_BASE=http://192.168.x.x:5000
/// ```
///
/// Defaults:
/// - **Android / iOS (phone or emulator):** production Oracle HTTPS
/// - **Chrome / Windows / desktop:** `http://localhost:5000` (local API for web/desktop dev)
class ApiConfig {
  /// Always-on Oracle stack (Caddy + HTTPS).
  static const String productionBase = 'https://sanchivaorg.duckdns.org';

  static const String _fromEnv = String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;

    // Browser or desktop on the same machine as a local API
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://localhost:5000';
    }

    // Phones and emulators → live backend (no LAN IP required)
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return productionBase;
    }

    return productionBase;
  }

  static String api(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl/api$p';
  }
}
