import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class LecturerProfile extends StatefulWidget {
  const LecturerProfile({super.key});

  @override
  State<LecturerProfile> createState() => _LecturerProfileState();
}

class _LecturerProfileState extends State<LecturerProfile> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _deptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.get('/lecturer/profile');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _profile = result['data'];
          _nameController.text = _profile?['full_name'] ?? '';
          _emailController.text = _profile?['email'] ?? '';
          _deptController.text = _profile?['department'] ?? '';
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    final result = await ApiService.put('/lecturer/profile', {
      'full_name': _nameController.text,
      'email': _emailController.text,
      'department': _deptController.text,
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFFF003C), Color(0xFFFF6B6B)]),
              boxShadow: [BoxShadow(color: const Color(0xFFFF003C).withOpacity(0.4), blurRadius: 20)],
            ),
            child: Center(
              child: Text(
                (_profile?['full_name'] ?? 'L')[0].toUpperCase(),
                style: GoogleFonts.orbitron(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _profile?['full_name'] ?? 'Lecturer',
            style: GoogleFonts.orbitron(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            _profile?['department'] ?? '',
            style: const TextStyle(color: Color(0xFFFF003C), fontSize: 14, letterSpacing: 2),
          ),
          const SizedBox(height: 30),

          if (!_isEditing) ...[
            _buildInfoTile(Icons.badge, 'Staff ID', _profile?['staff_id'] ?? 'N/A'),
            _buildInfoTile(Icons.person, 'Full Name', _profile?['full_name'] ?? 'N/A'),
            _buildInfoTile(Icons.email, 'Email', _profile?['email'] ?? 'N/A'),
            _buildInfoTile(Icons.business, 'Department', _profile?['department'] ?? 'N/A'),
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
            const SizedBox(height: 16),
            _buildEditField('Department', _deptController, Icons.business),
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
          const SizedBox(height: 30),
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
              style: ElevatedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF003C), width: 2)),
            ),
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
          Icon(icon, color: const Color(0xFFFF003C), size: 22),
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
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: const Color(0xFFFF003C))),
    );
  }
}
