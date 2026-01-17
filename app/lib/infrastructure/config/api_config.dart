import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    // Check for environment variable first (allows override)
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Platform-specific defaults
    if (kIsWeb) {
      return 'http://localhost:8081';
    } else if (Platform.isAndroid || Platform.isIOS) {
      return 'http://192.168.1.60:8081';
    } else {
      // Linux, macOS, Windows desktop
      return 'http://localhost:8081';
    }
  }

  static const Duration timeout = Duration(seconds: 30);
}
