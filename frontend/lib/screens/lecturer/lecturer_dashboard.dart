import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/weather_service.dart';
import '../../services/notification_service.dart';
import '../student/student_weather.dart';
import 'lecturer_timetable.dart';
import 'lecturer_announcements.dart';
import 'lecturer_profile.dart';
import 'class_analytics_screen.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _LecturerHome(),
    const LecturerTimetable(),
    const LecturerAnnouncements(),
    const StudentWeather(),
    const LecturerProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFFF003C), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0D0E15),
          selectedItemColor: const Color(0xFFFF003C),
          unselectedItemColor: Colors.white24,
          selectedLabelStyle: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.rajdhani(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'TIMETABLE'),
            BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'ALERTS'),
            BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'WEATHER'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LECTURER HOME — Session Management & Analytics
// ============================================
class _LecturerHome extends StatefulWidget {
  const _LecturerHome();

  @override
  State<_LecturerHome> createState() => _LecturerHomeState();
}

class _LecturerHomeState extends State<_LecturerHome> {
  String _timeString = '';
  String _dateString = '';
  String _temperature = '...';
  Timer? _timer;

  String? _activeCode;
  String? _activeSessionId;
  bool _isSessionActive = false;
  List<dynamic> _classes = [];
  String? _selectedClassId;
  bool _isStarting = false;

  // Analytics State
  Map<String, dynamic>? _analytics;
  bool _isLoadingAnalytics = true;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _fetchWeather();
    _loadClasses();
    _loadAnalytics();
    _loadCurrentSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  Future<void> _loadClasses() async {
    final result = await ApiService.get('/lecturer/classes');
    if (mounted && result['success']) {
      setState(() {
        _classes = result['data'] as List;
        if (_classes.isNotEmpty && _selectedClassId == null) {
          _selectedClassId = _classes[0]['id'];
        }
      });
    }
  }

  Future<void> _loadAnalytics() async {
    final result = await ApiService.get('/lecturer/dashboard/analytics');
    if (mounted) {
      setState(() {
        _isLoadingAnalytics = false;
        if (result['success']) {
          _analytics = result['data'];
        }
      });
    }
  }

  Future<void> _loadCurrentSession() async {
    final result = await ApiService.get('/lecturer/current-session');
    if (mounted && result['success'] && result['data'] != null) {
      final data = result['data'];
      setState(() {
        _activeCode = data['dynamic_code'];
        _activeSessionId = data['id'];
        _selectedClassId = data['class_id'];
        _isSessionActive = true;
      });
    }
  }

  // Show location picker dialog before starting a session
  Future<void> _showLocationPickerDialog() async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a class in Timetable first'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    double? pickedLat;
    double? pickedLon;
    bool useGPS = true;
    bool isFetchingGPS = false;
    String gpsStatus = 'Tap to detect location';

    final latCtrl = TextEditingController();
    final lonCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1C29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFF003C)),
          ),
          title: Text(
            'SET CLASS LOCATION',
            style: GoogleFonts.orbitron(color: const Color(0xFFFF003C), fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose how to set the location for this session:',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 16),

                // GPS Option
                InkWell(
                  onTap: () async {
                    setDlgState(() {
                      useGPS = true;
                      isFetchingGPS = true;
                      gpsStatus = 'Detecting location...';
                    });
                    try {
                      LocationPermission perm = await Geolocator.checkPermission();
                      if (perm == LocationPermission.denied) {
                        perm = await Geolocator.requestPermission();
                      }
                      if (perm == LocationPermission.deniedForever) {
                        setDlgState(() {
                          gpsStatus = 'Permission denied. Use manual input.';
                          isFetchingGPS = false;
                        });
                        return;
                      }
                      final pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      ).timeout(const Duration(seconds: 15));
                      pickedLat = pos.latitude;
                      pickedLon = pos.longitude;
                      setDlgState(() {
                        gpsStatus = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
                        isFetchingGPS = false;
                      });
                    } catch (e) {
                      setDlgState(() {
                        gpsStatus = 'Failed: ${e.toString().substring(0, 40)}';
                        isFetchingGPS = false;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: useGPS
                          ? const Color(0xFFFF003C).withOpacity(0.1)
                          : const Color(0xFF0D0E15),
                      border: Border.all(
                        color: useGPS ? const Color(0xFFFF003C) : Colors.white24,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.gps_fixed,
                          color: useGPS ? const Color(0xFFFF003C) : Colors.white38,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'USE MY GPS LOCATION',
                                style: GoogleFonts.rajdhani(
                                  color: useGPS ? const Color(0xFFFF003C) : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              isFetchingGPS
                                  ? const SizedBox(
                                      height: 12,
                                      width: 12,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFFF003C),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      gpsStatus,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Manual Option
                InkWell(
                  onTap: () {
                    setDlgState(() {
                      useGPS = false;
                      pickedLat = null;
                      pickedLon = null;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: !useGPS
                          ? const Color(0xFFFF003C).withOpacity(0.1)
                          : const Color(0xFF0D0E15),
                      border: Border.all(
                        color: !useGPS ? const Color(0xFFFF003C) : Colors.white24,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit_location_alt,
                                color: !useGPS ? const Color(0xFFFF003C) : Colors.white38, size: 22),
                            const SizedBox(width: 12),
                            Text(
                              'ENTER COORDINATES MANUALLY',
                              style: GoogleFonts.rajdhani(
                                color: !useGPS ? const Color(0xFFFF003C) : Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (!useGPS) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              hintText: 'e.g. -1.2921',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFFFF003C)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: lonCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              hintText: 'e.g. 36.8219',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFFFF003C)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'You can skip location — students will only need the code.',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                pickedLat = null;
                pickedLon = null;
                Navigator.pop(ctx, true);
              },
              child: const Text('SKIP', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (!useGPS) {
                  pickedLat = double.tryParse(latCtrl.text.trim()) ?? 0;
                  pickedLon = double.tryParse(lonCtrl.text.trim()) ?? 0;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0x33FF003C)),
              child: Text(
                'START SESSION',
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (pickedLat != null && pickedLon != null) {
      await _generateCode(pickedLat!, pickedLon!);
    }
  }

  Future<void> _generateCode(double lat, double lon) async {
    setState(() => _isStarting = true);

    final result = await ApiService.post('/lecturer/session/start', {
      'class_id': _selectedClassId,
      'session_lat': lat,
      'session_lon': lon,
    });

    if (!mounted) return;
    setState(() => _isStarting = false);

    if (result['success']) {
      final data = result['data'];
      setState(() {
        _activeCode = data['dynamic_code'];
        _activeSessionId = data['id'];
        _isSessionActive = true;
      });

      final classInfo = data['class_info'] as Map<String, dynamic>? ?? {};
      await NotificationService.showSessionStarted(
        classCode: classInfo['code'] ?? '',
        classTitle: classInfo['title'] ?? '',
        sessionCode: data['dynamic_code'] ?? '',
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed to start session'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _revokeCode() async {
    if (_activeSessionId == null) return;

    await ApiService.post('/lecturer/session/end', {
      'session_id': _activeSessionId,
    });

    if (mounted) {
      setState(() {
        _activeCode = null;
        _activeSessionId = null;
        _isSessionActive = false;
      });
      // Refresh analytics after session ends
      _loadAnalytics();
    }
  }

  Widget _buildAnalyticsDashboard() {
    if (_isLoadingAnalytics) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: Color(0xFFFF003C)),
        ),
      );
    }

    if (_analytics == null) return const SizedBox();

    final trend = _analytics!['trend'] as String? ?? 'SAME';
    final totalEnrolled = _analytics!['total_enrolled']?.toString() ?? '0';
    final attendedToday = _analytics!['attended_today']?.toString() ?? '0';
    final absentees = _analytics!['absentees'] as List? ?? [];

    IconData trendIcon = Icons.trending_flat;
    Color trendColor = Colors.white54;
    String trendText = 'Stable';

    if (trend == 'UP') {
      trendIcon = Icons.trending_up;
      trendColor = Colors.greenAccent;
      trendText = 'Attendance Up';
    } else if (trend == 'DOWN') {
      trendIcon = Icons.trending_down;
      trendColor = Colors.redAccent;
      trendText = 'Attendance Down';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY\'S ANALYTICS',
          style: GoogleFonts.orbitron(fontSize: 16, color: const Color(0xFFFF003C)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C29),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STUDENTS', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: attendedToday,
                            style: GoogleFonts.rajdhani(
                                fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' / $totalEnrolled',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Attended Today', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C29),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TREND', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(trendIcon, color: trendColor, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trendText,
                            style: GoogleFonts.rajdhani(
                                fontSize: 16, color: trendColor, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('vs. Last Session', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMyClasses() {
    if (_classes.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MY CLASSES',
          style: GoogleFonts.orbitron(fontSize: 16, color: const Color(0xFFFF003C)),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _classes.length,
          itemBuilder: (context, index) {
            final cls = _classes[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C29),
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF003C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.class_, color: Color(0xFFFF003C)),
                ),
                title: Text(
                  cls['code'] ?? '',
                  style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  cls['title'] ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClassAnalyticsScreen(
                        classId: cls['id'],
                        classCode: cls['code'],
                        classTitle: cls['title'],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userName = auth.user?['name'] ?? 'LECTURER';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userName, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_dateString, style: TextStyle(color: const Color(0xFFFF003C).withOpacity(0.7), fontSize: 11)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF003C)),
            onPressed: () {
              _loadClasses();
              _loadAnalytics();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadClasses();
          await _loadAnalytics();
        },
        color: const Color(0xFFFF003C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Manager (Compact when inactive, expanded when active)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A1C29),
                      _isSessionActive ? const Color(0x3300F0FF) : const Color(0x33FF003C),
                    ],
                  ),
                  border: Border.all(
                    color: _isSessionActive ? const Color(0xFF00F0FF) : const Color(0xFFFF003C),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (!_isSessionActive) ...[
                      if (_classes.isNotEmpty)
                        DropdownButton<String>(
                          value: _selectedClassId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1C29),
                          style: const TextStyle(color: Colors.white),
                          underline: const SizedBox(),
                          items: _classes.map<DropdownMenuItem<String>>((c) {
                            return DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text('${c['code']} - ${c['title']}'),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedClassId = v),
                        ),
                      const SizedBox(height: 16),
                    ],
                    if (_isSessionActive)
                      Column(
                        children: [
                          Text('SESSION ACTIVE',
                              style: GoogleFonts.orbitron(fontSize: 16, color: const Color(0xFF00F0FF))),
                          const SizedBox(height: 12),
                          Text(
                            _activeCode!,
                            style: GoogleFonts.orbitron(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 10,
                              shadows: const [Shadow(color: Color(0xFF00F0FF), blurRadius: 20)],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Students have been notified',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isStarting ? null : (_isSessionActive ? _revokeCode : _showLocationPickerDialog),
                        icon: _isStarting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F0FF)),
                              )
                            : Icon(_isSessionActive ? Icons.stop : Icons.play_arrow),
                        label: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(_isStarting ? 'STARTING...' : (_isSessionActive ? 'END SESSION' : 'START SESSION')),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: _isSessionActive ? const Color(0xFFFF003C) : const Color(0xFF00F0FF),
                          side: BorderSide(
                            color: _isSessionActive ? const Color(0xFFFF003C) : const Color(0xFF00F0FF),
                            width: 2,
                          ),
                          backgroundColor: _isSessionActive ? const Color(0x33FF003C) : const Color(0x3300F0FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Analytics Dashboard
              _buildAnalyticsDashboard(),
              
              const SizedBox(height: 32),
              
              // My Classes
              _buildMyClasses(),
              
            ],
          ),
        ),
      ),
    );
  }
}
