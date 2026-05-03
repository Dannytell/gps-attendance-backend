import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class ApiService {
  static String get baseUrl => Environment.apiBaseUrl;
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  /// Exposed for multipart upload requests that bypass ApiService.post
  static String? get currentToken => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': _parseError(response)};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      debugPrint('API GET error: $e');
      return {'success': false, 'error': 'Connection failed'};
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': _parseError(response)};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      debugPrint('API POST error: $e');
      return {'success': false, 'error': 'Connection failed'};
    }
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': _parseError(response)};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      debugPrint('API PUT error: $e');
      return {'success': false, 'error': 'Connection failed'};
    }
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': _parseError(response)};
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      debugPrint('API DELETE error: $e');
      return {'success': false, 'error': 'Connection failed'};
    }
  }

  static String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['error'] ?? 'Unknown error (${response.statusCode})';
    } catch (_) {
      return 'Server error (${response.statusCode})';
    }
  }
}
