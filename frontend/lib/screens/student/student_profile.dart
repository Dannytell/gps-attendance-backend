import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class StudentProfile extends StatefulWidget {
  const StudentProfile({super.key});

  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.get('/student/profile');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _profile = result['data'];
          _nameController.text = _profile?['full_name'] ?? '';
          _emailController.text = _profile?['email'] ?? '';
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    final result = await ApiService.put('/student/profile', {
      'full_name': _nameController.text,
      'email': _emailController.text,
    });
    if (mounted) {
      if (result['success']) {
        setState(() {
          _profile = result['data'];
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Color(0xFF00F0FF)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFF0080FF)]),
              boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.4), blurRadius: 20)],
            ),
            child: Center(
              child: Text(
                (_profile?['full_name'] ?? 'S')[0].toUpperCase(),
                style: GoogleFonts.orbitron(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _profile?['full_name'] ?? 'Student',
            style: GoogleFonts.orbitron(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            _profile?['university_id'] ?? '',
            style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 14, letterSpacing: 2),
          ),
          const SizedBox(height: 30),

          // Info Cards
          if (!_isEditing) ...[
            _buildInfoTile(Icons.badge, 'University ID', _profile?['university_id'] ?? 'N/A'),
            _buildInfoTile(Icons.person, 'Full Name', _profile?['full_name'] ?? 'N/A'),
            _buildInfoTile(Icons.email, 'Email', _profile?['email'] ?? 'N/A'),
            _buildInfoTile(Icons.fingerprint, 'Biometrics', _profile?['biometrics_enabled'] == true ? 'Enabled' : 'Disabled'),
            _buildInfoTile(Icons.calendar_today, 'Joined', _profile?['created_at']?.toString().substring(0, 10) ?? 'N/A'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit),
                label: const Text('EDIT PROFILE'),
              ),
            ),
          ] else ...[
            _buildEditField('Full Name', _nameController, Icons.person),
            const SizedBox(height: 16),
            _buildEditField('Email', _emailController, Icons.email),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0x3300F0FF)),
                    child: const Text('SAVE'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showChangePasswordDialog,
              icon: const Icon(Icons.lock, color: Color(0xFF00F0FF)),
              label: const Text('CHANGE PASSWORD'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.power_settings_new, color: Color(0xFFFF003C)),
              label: const Text('LOGOUT', style: TextStyle(color: Color(0xFFFF003C))),
              style: ElevatedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF003C), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00F0FF)),
        ),
        title: Text('CHANGE PASSWORD', style: GoogleFonts.orbitron(color: const Color(0xFF00F0FF), fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPwCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF00F0FF)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPwCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF00F0FF)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF00F0FF)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPwCtrl.text != confirmPwCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              if (newPwCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              final result = await ApiService.put('/student/password', {
                'current_password': currentPwCtrl.text,
                'new_password': newPwCtrl.text,
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['success'] ? 'Password updated!' : (result['error'] ?? 'Failed')),
                    backgroundColor: result['success'] ? const Color(0xFF00F0FF) : Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0x3300F0FF)),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C29),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00F0FF), size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF00F0FF)),
      ),
    );
  }
}
