import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'class_analytics_screen.dart';

class LecturerTimetable extends StatefulWidget {
  const LecturerTimetable({super.key});

  @override
  State<LecturerTimetable> createState() => _LecturerTimetableState();
}

class _LecturerTimetableState extends State<LecturerTimetable> {
  List<dynamic> _classes = [];
  bool _isLoading = true;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    final result = await ApiService.get('/lecturer/timetable');
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

  void _showAddClassDialog() {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    String selectedDay = 'Monday';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1C29),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFFF003C))),
          title: Text('ADD CLASS', style: GoogleFonts.orbitron(color: const Color(0xFFFF003C), fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Class Code (e.g. CSC401)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Class Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  dropdownColor: const Color(0xFF1A1C29),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDialogState(() => selectedDay = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: startCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Start Time (e.g. 09:00)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'End Time (e.g. 11:00)'),
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
                if (codeCtrl.text.isEmpty || titleCtrl.text.isEmpty || startCtrl.text.isEmpty || endCtrl.text.isEmpty) {
                  return;
                }
                final result = await ApiService.post('/lecturer/timetable', {
                  'code': codeCtrl.text.trim(),
                  'title': titleCtrl.text.trim(),
                  'day_of_week': selectedDay,
                  'start_time': startCtrl.text.trim(),
                  'end_time': endCtrl.text.trim(),
                  'latitude': 0,
                  'longitude': 0,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  if (result['success']) {
                    _loadTimetable();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['error'] ?? 'Failed'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0x33FF003C)),
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteClass(String id) async {
    final result = await ApiService.delete('/lecturer/timetable/$id');
    if (result['success']) {
      _loadTimetable();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF003C)));
    }

    final currentDay = _getCurrentDay();

    return Scaffold(
      body: _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('NO CLASSES YET', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first class', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTimetable,
              color: const Color(0xFFFF003C),
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
                                color: day == currentDay ? const Color(0xFFFF003C).withOpacity(0.15) : Colors.transparent,
                                border: Border.all(color: day == currentDay ? const Color(0xFFFF003C) : Colors.white24),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                day.toUpperCase(),
                                style: GoogleFonts.orbitron(
                                  fontSize: 12,
                                  color: day == currentDay ? const Color(0xFFFF003C) : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (day == currentDay) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFFF003C), borderRadius: BorderRadius.circular(4)),
                                child: Text('TODAY', style: GoogleFonts.rajdhani(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ..._classes.where((c) => c['day_of_week'] == day).map((c) => _buildClassCard(c, day == currentDay)),
                    ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClassDialog,
        backgroundColor: const Color(0xFFFF003C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData, bool isToday) {
    final startTime = classData['start_time']?.toString().substring(0, 5) ?? '';
    final endTime = classData['end_time']?.toString().substring(0, 5) ?? '';

    return Dismissible(
      key: Key(classData['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      onDismissed: (_) => _deleteClass(classData['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C29),
          border: Border.all(color: isToday ? const Color(0xFFFF003C).withOpacity(0.4) : Colors.white12),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isToday ? [BoxShadow(color: const Color(0xFFFF003C).withOpacity(0.1), blurRadius: 10)] : null,
        ),
        child: Row(
          children: [
            Container(
              width: 4, height: 50,
              decoration: BoxDecoration(color: isToday ? const Color(0xFFFF003C) : Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(classData['title'] ?? 'Untitled', style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(classData['code'] ?? '', style: TextStyle(color: const Color(0xFFFF003C).withOpacity(0.7), fontSize: 12)),
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
      ),
    );
  }
}
