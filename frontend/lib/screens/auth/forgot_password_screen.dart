import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool isLecturer = false;
  bool isLoading = false;
  final TextEditingController _idController = TextEditingController();

  Future<void> _handleRequestOTP() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _showCustomMessage('Please enter your ID', isError: true);
      return;
    }

    setState(() => isLoading = true);
    final role = isLecturer ? 'lecturer' : 'student';

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_number': id, 'role': role}),
      ).timeout(const Duration(seconds: 10));

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        _showCustomMessage('OTP sent to your email!', isError: false);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(idNumber: id, role: role),
            ),
          );
        }
      } else {
        final data = jsonDecode(response.body);
        _showCustomMessage(data['error'] ?? 'Failed to request OTP', isError: true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showCustomMessage('Connection failed. Try again.', isError: true);
    }
  }

  void _showCustomMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
             Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
             const SizedBox(width: 12),
             Expanded(child: Text(message, style: GoogleFonts.rajdhani(fontSize: 15))),
           ],
         ),
         backgroundColor: isError ? Colors.redAccent : const Color(0xFF00F0FF).withValues(alpha: 0.8),
         behavior: SnackBarBehavior.floating,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         margin: const EdgeInsets.all(16),
         duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00F0FF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0E15), Color(0xFF1A1C29)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_reset, size: 64, color: Color(0xFF00F0FF)),
                const SizedBox(height: 20),
                Text(
                  'RECOVER ACCESS',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                 Text(
                   'Enter your ID to receive a verification code on your registered email.',
                   textAlign: TextAlign.center,
                   style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.5),
                 ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildRoleButton('STUDENT', !isLecturer),
                    const SizedBox(width: 10),
                    _buildRoleButton('LECTURER', isLecturer),
                  ],
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    labelText: isLecturer ? 'STAFF ID' : 'UNIVERSITY ID',
                    prefixIcon: const Icon(Icons.badge, color: Color(0xFF00F0FF)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleRequestOTP,
                    child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2))
                      : const Text('SEND RECOVERY CODE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(String title, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => isLecturer = title == 'LECTURER'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.white24, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: GoogleFonts.rajdhani(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
