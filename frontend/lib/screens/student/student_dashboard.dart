import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/weather_service.dart';
import '../../services/notification_service.dart';
import 'student_timetable.dart';
import 'student_weather.dart';
import 'student_announcements.dart';
import 'student_profile.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  Timer? _sessionPollTimer;
  final Set<String> _notifiedSessionIds = {};
  int _unreadAlerts = 0;

  final LocalAuthentication auth = LocalAuthentication();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _StudentHome(onAttendanceComplete: _clearUnreadAlerts),
      const StudentTimetable(),
      const StudentWeather(),
      const StudentAnnouncements(),
      const StudentProfile(),
    ];
    _requestPermissions();
    _startSessionPolling();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  @override
  void dispose() {
    _sessionPollTimer?.cancel();
    super.dispose();
  }

  void _clearUnreadAlerts() {
    setState(() => _unreadAlerts = 0);
  }

  void _startSessionPolling() {
    _pollActiveSessions();
    _sessionPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollActiveSessions());
  }

  Future<void> _pollActiveSessions() async {
    final result = await ApiService.get('/lecturer/active-sessions');
    if (!mounted || !result['success']) return;

    final sessions = result['data'] as List;
    for (final session in sessions) {
      final sessionId = session['id'] as String;
      if (!_notifiedSessionIds.contains(sessionId)) {
        _notifiedSessionIds.add(sessionId);
        setState(() => _unreadAlerts++);
        // Removed SnackBar and push notifications per user request.
        // Sessions will now be handled in the Alerts tab.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF00F0FF), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() {
              _currentIndex = i;
              if (i == 3) _unreadAlerts = 0; // Clear badges when viewing alerts (or we can just keep them for classes)
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0D0E15),
          selectedItemColor: const Color(0xFF00F0FF),
          unselectedItemColor: Colors.white24,
          selectedLabelStyle: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.rajdhani(fontSize: 10),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'HOME'),
            const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'TIMETABLE'),
            const BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'WEATHER'),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadAlerts > 0,
                label: Text(_unreadAlerts.toString()),
                child: const Icon(Icons.campaign),
              ),
              label: 'ALERTS',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }
}

// ============================================
// HOME TAB — Attendance signing + HUD
// ============================================
class _StudentHome extends StatefulWidget {
  final VoidCallback onAttendanceComplete;
  const _StudentHome({required this.onAttendanceComplete});

  @override
  State<_StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<_StudentHome> with SingleTickerProviderStateMixin {
  String _timeString = '';
  String _dateString = '';
  String _temperature = '...';
  Timer? _timer;
  late AnimationController _glowController;

  final TextEditingController _codeController = TextEditingController();
  bool _isSigningIn = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _fetchWeather();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString = DateFormat('HH:mm:ss').format(now);
        _dateString = DateFormat('EEEE, MMMM d').format(now);
      });
    }
  }

  Future<void> _fetchWeather() async {
    final temp = await WeatherService.getTemperature();
    if (mounted) setState(() => _temperature = temp);
  }

  Future<void> _initiateAttendance() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your class access code'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSigningIn = true);

    try {
      // 1. Check for biometrics
      bool authenticated = false;

      if (!kIsWeb) {
        try {
          bool canCheckBiometrics = await auth.canCheckBiometrics;
          bool isSupported = await auth.isDeviceSupported();

          if (canCheckBiometrics && isSupported) {
            authenticated = await auth.authenticate(
              localizedReason: 'Scan your fingerprint to sign attendance',
              options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
            );
          }
        } catch (e) {
          debugPrint('Biometric Error: $e');
        }
      }

      if (authenticated) {
        await _signAttendance(code: code, verifiedBiometrics: true);
      } else {
        // Fallback to OTP via Email
        await _fallbackToOTP(code);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _fallbackToOTP(String code) async {
    // Send OTP request
    final otpRes = await ApiService.post('/student/attendance/send-otp', {});
    if (!mounted) return;

    if (otpRes['success'] != true) {
      setState(() => _isSigningIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(otpRes['error'] ?? 'Failed to send OTP'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Show OTP input dialog
    final otpCtrl = TextEditingController();
    bool isSubmittingOTP = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1C29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00F0FF)),
          ),
          title: Text('EMAIL VERIFICATION', style: GoogleFonts.orbitron(color: const Color(0xFF00F0FF), fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('A 6-digit code has been sent to your email. Enter it below to sign in.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(fontSize: 24, color: Colors.white, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
                ),
                maxLength: 6,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _isSigningIn = false);
                Navigator.pop(ctx);
              },
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isSubmittingOTP
                  ? null
                  : () async {
                      if (otpCtrl.text.length != 6) return;
                      setDlgState(() => isSubmittingOTP = true);
                      Navigator.pop(ctx);
                      await _signAttendance(code: code, verifiedBiometrics: false, otpCode: otpCtrl.text);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0x3300F0FF)),
              child: isSubmittingOTP
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('VERIFY'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signAttendance({required String code, required bool verifiedBiometrics, String? otpCode}) async {
    double latitude = 0;
    double longitude = 0;
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10));
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (e) {
      debugPrint('Location error (non-fatal): $e');
    }

    final body = {
      'dynamic_code': code,
      'latitude': latitude,
      'longitude': longitude,
      if (verifiedBiometrics) 'verified_biometrics': true,
      if (otpCode != null) 'otp_code': otpCode,
    };

    final result = await ApiService.post('/student/attendance/sign', body);

    if (!mounted) return;
    setState(() => _isSigningIn = false);

    if (result['success'] == true && result['data']?['success'] == true) {
      widget.onAttendanceComplete();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1C29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00F0FF)),
          ),
          title: Text('ACCESS GRANTED', style: GoogleFonts.orbitron(color: const Color(0xFF00F0FF), fontSize: 18)),
          content: Text(result['data']?['message'] ?? 'Attendance logged successfully.',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _codeController.clear();
              },
              child: const Text('OK', style: TextStyle(color: Color(0xFF00F0FF))),
            )
          ],
        ),
      );
    } else {
      final errorMsg = result['error'] ?? result['data']?['error'] ?? 'Failed to sign attendance';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userName = auth.user?['name'] ?? 'STUDENT';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userName, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_dateString, style: TextStyle(color: const Color(0xFF00F0FF).withOpacity(0.7), fontSize: 11)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Time & Weather HUD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A1C29), const Color(0xFF00F0FF).withOpacity(0.05)],
                ),
                border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.08), blurRadius: 15)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_timeString,
                      style: GoogleFonts.orbitron(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.thermostat, color: Color(0xFFFF003C), size: 20),
                      Text(_temperature,
                          style: GoogleFonts.rajdhani(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Code Entry
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C29),
                    border: Border.all(
                      color: Color.lerp(
                          const Color(0xFF00F0FF).withOpacity(0.3), const Color(0xFF00F0FF), _glowController.value)!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withOpacity(0.05 + 0.1 * _glowController.value),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('LINK TO CLASS SESSION',
                          style: GoogleFonts.orbitron(fontSize: 14, color: const Color(0xFF00F0FF))),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codeController,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.orbitron(fontSize: 28, letterSpacing: 8, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'ENTER CODE',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), letterSpacing: 8),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSigningIn ? null : _initiateAttendance,
                          icon: _isSigningIn
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2))
                              : const Icon(Icons.fingerprint, size: 24),
                          label: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(_isSigningIn ? 'VERIFYING...' : 'VERIFY & SIGN IN'),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0x3300F0FF)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
