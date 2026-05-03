import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String idNumber;
  final String role;

  const ResetPasswordScreen({
    super.key,
    required this.idNumber,
    required this.role,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool isLoading = false;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleReset() async {
    final otp = _otpController.text.trim();
    final pass = _passwordController.text;

    if (otp.isEmpty || pass.isEmpty) {
      _showCustomMessage('Please fill all fields', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_number': widget.idNumber,
          'role': widget.role,
          'otp': otp,
          'new_password': pass,
        }),
      ).timeout(const Duration(seconds: 10));

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        _showCustomMessage('Password reset successful!', isError: false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Pop back to login screen
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showCustomMessage(data['error'] ?? 'Reset failed', isError: true);
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
                const Icon(Icons.mark_email_read, size: 64, color: Color(0xFF00F0FF)),
                const SizedBox(height: 20),
                Text(
                  'VERIFY OTP',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the 6-digit code sent to your email and your new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-DIGIT OTP',
                    prefixIcon: Icon(Icons.pin, color: Color(0xFF00F0FF)),
                  ),
                  style: GoogleFonts.orbitron(color: Colors.white, letterSpacing: 5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'NEW PASSWORD',
                    prefixIcon: Icon(Icons.lock_reset, color: Color(0xFF00F0FF)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleReset,
                    child: isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2))
                      : const Text('CONFIRM PASSWORD RESET'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
