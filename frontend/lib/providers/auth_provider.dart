import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../config/environment.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isLecturer => _user?['role'] == 'lecturer';

  final String baseUrl = Environment.apiBaseUrl;

  /// Returns null on success, or an error message string on failure.
  Future<String?> login(String idNumber, String password, String role) async {
    if (idNumber.trim().isEmpty || password.trim().isEmpty) {
      return 'Please enter your ID and password.';
    }

    try {
      debugPrint('Attempting login to: $baseUrl/auth/login');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_number': idNumber.trim(),
          'password': password,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = data['user'];

        // Set token for API service
        ApiService.setToken(_token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', jsonEncode(_user));

        notifyListeners();
        return null; // success
      } else if (response.statusCode == 401) {
        return 'Invalid credentials. Please check your ID and password.';
      } else {
        try {
          final data = jsonDecode(response.body);
          return 'Server error: ${data['error'] ?? 'Unknown error'}';
        } catch (_) {
          return 'Server error (${response.statusCode}). Please try again.';
        }
      }
    } on TimeoutException {
      return 'Connection timed out. Is the server running?';
    } on http.ClientException catch (e) {
      return 'Cannot reach server: ${e.message}';
    } catch (e) {
      debugPrint('Login error: $e');
      return 'Connection failed: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}';
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('token')) return false;

    _token = prefs.getString('token');
    _user = jsonDecode(prefs.getString('user')!);
    ApiService.setToken(_token);
    notifyListeners();
    return true;
  }
}
