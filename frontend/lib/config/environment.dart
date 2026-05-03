import 'package:flutter/foundation.dart' show kIsWeb;

class Environment {
  /// Returns the base URL for API requests.
  /// - For web: uses localhost (since web and backend run on same machine via localhost)
  /// - For mobile: uses the value from the dart-define API_BASE_URL, falling back to
  ///   http://10.0.2.2:5000/api (the Android emulator's alias to the host loopback).
  ///   For a physical device, you must set API_BASE_URL to your development machine's
  ///   IP address (e.g., http://192.168.1.100:5000/api) and ensure the device is on
  ///   the same network and can reach that IP:port.
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'https://gps-attendance-backend.onrender.com/api';
    }
    return String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://gps-attendance-backend.onrender.com/api');
  }
}