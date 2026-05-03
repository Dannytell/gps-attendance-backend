import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class StudentTimetable extends StatefulWidget {
  const StudentTimetable({super.key});

  @override
  State<StudentTimetable> createState() => _StudentTimetableState();
}

class _StudentTimetableState extends State<StudentTimetable> {
  List<dynamic> _classes = [];
  bool _isLoading = true;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    final result = await ApiService.get('/student/timetable');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _classes = result['data'] as List;
        }
      });
    }
  }

  String _getCurrentDay() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)));
    }

    if (_classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('NO CLASSES ENROLLED', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Your timetable will appear once you\nenroll in classes.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.3))),
          ],
        ),
      );
    }

    final currentDay = _getCurrentDay();

    return RefreshIndicator(
      onRefresh: _loadTimetable,
      color: const Color(0xFF00F0FF),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final day in _days)
            if (_classes.any((c) => c['day_of_week'] == day)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8, top: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: day == currentDay ? const Color(0xFF00F0FF).withOpacity(0.15) : Colors.transparent,
                        border: Border.all(
                          color: day == currentDay ? const Color(0xFF00F0FF) : Colors.white24,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        day.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          color: day == currentDay ? const Color(0xFF00F0FF) : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (day == currentDay) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F0FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('TODAY', style: GoogleFonts.rajdhani(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              ..._classes.where((c) => c['day_of_week'] == day).map((c) => _buildClassCard(c, day == currentDay)),
            ],
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData, bool isToday) {
    final startTime = classData['start_time']?.toString().substring(0, 5) ?? '';
    final endTime = classData['end_time']?.toString().substring(0, 5) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C29),
        border: Border.all(color: isToday ? const Color(0xFF00F0FF).withOpacity(0.4) : Colors.white12),
        borderRadius: BorderRadius.circular(10),
        boxShadow: isToday
            ? [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.1), blurRadius: 10)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFF00F0FF) : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classData['title'] ?? 'Untitled',
                  style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(classData['code'] ?? '', style: TextStyle(color: const Color(0xFF00F0FF).withOpacity(0.7), fontSize: 12)),
                    if (classData['lecturer_name'] != null) ...[
                      Text(' • ', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                      Text(classData['lecturer_name'], style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(startTime, style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
              Text(endTime, style: GoogleFonts.orbitron(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }
}
