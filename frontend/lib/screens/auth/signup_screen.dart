import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool isLecturer = false;
  bool isLoading = false;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final id = _idController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (name.isEmpty || id.isEmpty || pass.isEmpty || email.isEmpty) {
      _showCustomMessage('Please fill all fields', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final roleEndpoint = isLecturer ? 'lecturer' : 'student';
      final payload = isLecturer
          ? {'staff_id': id, 'full_name': name, 'email': email, 'password': pass}
          : {'university_id': id, 'full_name': name, 'email': email, 'password': pass};

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/register/$roleEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        _showCustomMessage('Account created successfully! You can now log in.', isError: false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        final data = jsonDecode(response.body);
        _showCustomMessage(data['error'] ?? 'Signup failed', isError: true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showCustomMessage('Connection failed: ${e.toString().split('\n')[0]}', isError: true);
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
                const SizedBox(height: 40),
                Text(
                  'CREATE ACCOUNT',
                  style: GoogleFonts.orbitron(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    shadows: [Shadow(blurRadius: 10.0, color: Theme.of(context).primaryColor)],
                  ),
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
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'FULL NAME', prefixIcon: Icon(Icons.person, color: Color(0xFF00F0FF))),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(labelText: isLecturer ? 'STAFF ID' : 'UNIVERSITY ID', prefixIcon: const Icon(Icons.badge, color: Color(0xFF00F0FF))),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'EMAIL ADDRESS', prefixIcon: Icon(Icons.email, color: Color(0xFF00F0FF))),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'PASSWORD', prefixIcon: Icon(Icons.lock, color: Color(0xFF00F0FF))),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleSignup,
                    child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2)) : const Text('REGISTER SYSTEM ACCESS'),
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
