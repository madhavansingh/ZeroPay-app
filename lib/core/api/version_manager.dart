import 'package:flutter/foundation.dart';

class ApiVersionManager {
  ApiVersionManager._();

  // Point to local Express backend on Android Emulator host machine in debug mode
  static String get domain {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:4000'
          : 'http://localhost:4000';
    }
    return 'https://api.zeropay.network';
  }
  static String _activeVersion = 'v1';

  static String get activeVersion => _activeVersion;

  static void setVersion(String version) {
    if (version == 'v1' || version == 'v2') {
      _activeVersion = version;
      if (kDebugMode) {
        print('API Version switched to: $_activeVersion');
      }
    }
  }

  static String get baseUrl => '$domain/api/$_activeVersion';

  // Format path depending on active version
  static String formatEndpoint(String path) {
    // If an endpoint has a version-specific override, handle it here
    if (_activeVersion == 'v2') {
      // E.g., if v2 has different routes, map them dynamically
      if (path == '/auth/login') return '/auth/connect';
    }
    return path;
  }
}
