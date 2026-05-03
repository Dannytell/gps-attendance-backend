import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/auth_provider.dart';
import '../lecturer/lecturer_dashboard.dart';
import '../student/student_dashboard.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  bool isLecturer = false;
  bool isLoading = false;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final MapController _mapController = MapController();
  late AnimationController _zoomAnimationController;
  late Animation<double> _zoomAnimation;
  
  // Radar Pulse Animation
  late AnimationController _radarController;
  
  // Destination coordinates (e.g. Nairobi CBD)
  final LatLng _destination = const LatLng(-1.2921, 36.8219);

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _zoomAnimation = Tween<double>(begin: 14.5, end: 17.5).animate(
      CurvedAnimation(parent: _zoomAnimationController, curve: Curves.easeInOut),
    )..addListener(() {
        if (_mapController.mapEventStream.isBroadcast) {
          try {
            _mapController.move(_destination, _zoomAnimation.value);
          } catch (_) {}
        }
      });
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _radarController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startMapAnimation() {
    if (!_zoomAnimationController.isAnimating && !_zoomAnimationController.isCompleted) {
      _zoomAnimationController.forward();
    }
  }

  Future<void> _handleLogin() async {
    setState(() => isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = isLecturer ? 'lecturer' : 'student';
    final error = await auth.login(_idController.text, _passwordController.text, role);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (error == null) {
      _showCustomMessage('ACCESS GRANTED', isError: false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => isLecturer ? const LecturerDashboard() : const StudentDashboard(),
          ));
        }
      });
    } else {
      _showCustomMessage(error, isError: true);
    }
  }

  void _showCustomMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: Colors.white),
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
      backgroundColor: const Color(0xFF0D0E15),
      body: Stack(
        children: [
          // Background Map Layer with luminous blending
          ShaderMask(
            shaderCallback: (rect) {
              return RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.transparent,
                ],
                stops: const [0.4, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                const Color(0xFF00F0FF).withOpacity(0.2),
                BlendMode.color,
              ),
              child: Opacity(
                opacity: 0.8,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _destination,
                    initialZoom: 14.5,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    onMapReady: _startMapAnimation,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _destination,
                          width: 200,
                          height: 200,
                          child: AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _RadarPulsePainter(_radarController.value),
                              );
                            },
                          ),
                        ),
                        Marker(
                          point: _destination,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.gps_fixed, color: Color(0xFF00F0FF), size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Gradient Overlay to ensure text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D0E15).withOpacity(0.5),
                  const Color(0xFF1A1C29).withOpacity(0.2),
                ],
              ),
            ),
          ),

          // Login Form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1C29).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NEO-EDU',
                          style: GoogleFonts.orbitron(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00F0FF),
                            shadows: [
                              const Shadow(
                                blurRadius: 10.0,
                                color: Color(0xFF00F0FF),
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SECURE ATTENDANCE TERMINAL',
                          style: TextStyle(
                            letterSpacing: 2.0,
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Role Toggle
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
                        const SizedBox(height: 20),
                        
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'PASSWORD',
                            prefixIcon: Icon(Icons.lock, color: Color(0xFF00F0FF)),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F0FF).withOpacity(0.1),
                            ),
                            child: isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF00F0FF), strokeWidth: 2))
                              : const Text('LOGIN'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                              },
                              child: const Text('Create Account', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                              },
                              child: Text('Forgot Password?', style: TextStyle(color: const Color(0xFFFF003C).withOpacity(0.8), fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String title, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isLecturer = title == 'LECTURER';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F0FF).withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF00F0FF) : Colors.white24,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: GoogleFonts.rajdhani(
            color: isSelected ? const Color(0xFF00F0FF) : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  final double progress;
  _RadarPulsePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(1.0 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw 3 rings
    for (int i = 0; i < 3; i++) {
      double ringProgress = (progress + (i / 3.0)) % 1.0;
      double radius = (size.width / 2) * ringProgress;
      canvas.drawCircle(center, radius, paint..color = const Color(0xFF00F0FF).withOpacity(1.0 - ringProgress));
    }
  }

  @override
  bool shouldRepaint(_RadarPulsePainter oldDelegate) => true;
}
