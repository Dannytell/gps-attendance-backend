import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../services/api_service.dart';

class ClassAnalyticsScreen extends StatefulWidget {
  final String classId;
  final String classCode;
  final String classTitle;

  const ClassAnalyticsScreen({
    super.key,
    required this.classId,
    required this.classCode,
    required this.classTitle,
  });

  @override
  State<ClassAnalyticsScreen> createState() => _ClassAnalyticsScreenState();
}

class _ClassAnalyticsScreenState extends State<ClassAnalyticsScreen> {
  bool _isLoading = true;
  List<dynamic> _sessions = [];
  List<dynamic> _logs = [];
  List<dynamic> _enrolled = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final result = await ApiService.get('/lecturer/class/${widget.classId}/analytics');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _sessions = result['data']['sessions'] as List;
          _logs = result['data']['logs'] as List;
          _enrolled = result['data']['enrolled'] as List? ?? [];
        }
      });
    }
  }

  Future<void> _exportCSV() async {
    if (_sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance data to export.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    List<List<dynamic>> csvData = [
      ['Session Date', 'Student Name', 'Registration Number', 'Status', 'Signed At']
    ];

    for (var session in _sessions) {
      final sessionDate = session['session_date'] != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(session['session_date']))
          : 'Unknown';
          
      final sessionLogs = _logs.where((l) => l['session_id'] == session['id']).toList();
      final presentStudentIds = sessionLogs.map((l) => l['student_id']).toSet();
      
      for (var student in _enrolled) {
        final isPresent = presentStudentIds.contains(student['student_id']);
        String signedAt = 'N/A';
        
        if (isPresent) {
          final log = sessionLogs.firstWhere((l) => l['student_id'] == student['student_id']);
          signedAt = log['signed_at'] != null 
              ? DateFormat('HH:mm:ss').format(DateTime.parse(log['signed_at']).toLocal()) 
              : 'Unknown';
        }
        
        csvData.add([
          sessionDate,
          student['full_name'] ?? 'Unknown',
          student['university_id'] ?? 'Unknown',
          isPresent ? 'Present' : 'Absent',
          signedAt,
        ]);
      }
    }

    String csvString = const ListToCsvConverter().convert(csvData);
    final fileName = 'Attendance_${widget.classCode}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

    try {
      if (kIsWeb) {
        final bytes = utf8.encode(csvString);
        final base64String = base64Encode(bytes);
        final uri = Uri.parse('data:text/csv;base64,$base64String');
        await launchUrl(uri);
      } else {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csvString);
        await Share.shareXFiles([XFile(path)], text: 'Attendance Report for ${widget.classCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CLASS ANALYTICS', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${widget.classCode} • ${widget.classTitle}',
                style: TextStyle(color: const Color(0xFFFF003C).withOpacity(0.7), fontSize: 11)),
          ],
        ),
        backgroundColor: const Color(0xFF1A1C29),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFFFF003C)),
            onPressed: _isLoading ? null : _exportCSV,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF003C)))
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text('NO SESSIONS YET', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final sessionLogs = _logs.where((l) => l['session_id'] == session['id']).toList();
                    
                    // Analytics calculations
                    final presentIds = sessionLogs.map((l) => l['student_id']).toSet();
                    final absentStudents = _enrolled.where((s) => !presentIds.contains(s['student_id'])).toList();
                    final presentStudents = _enrolled.where((s) => presentIds.contains(s['student_id'])).toList();
                    
                    final totalEnrolled = _enrolled.length;
                    final presentCount = presentStudents.length;
                    final absentCount = absentStudents.length;
                    final attendanceRate = totalEnrolled > 0 ? presentCount / totalEnrolled : 0.0;
                    
                    // Trend vs Previous Session
                    String trendText = 'Stable';
                    IconData trendIcon = Icons.trending_flat;
                    Color trendColor = Colors.white54;
                    
                    if (index + 1 < _sessions.length) {
                      final prevSession = _sessions[index + 1];
                      final prevLogs = _logs.where((l) => l['session_id'] == prevSession['id']).toList();
                      final prevPresentCount = prevLogs.length;
                      final diff = presentCount - prevPresentCount;
                      
                      if (diff > 0) {
                        trendText = '▲ +$diff from last session';
                        trendIcon = Icons.trending_up;
                        trendColor = Colors.greenAccent;
                      } else if (diff < 0) {
                        trendText = '▼ $diff from last session';
                        trendIcon = Icons.trending_down;
                        trendColor = Colors.redAccent;
                      }
                    }

                    final sessionDate = session['session_date'] != null
                        ? DateFormat('EEEE, MMM d, yyyy').format(DateTime.parse(session['session_date']))
                        : 'Unknown Date';

                    return Card(
                      color: const Color(0xFF1A1C29),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: const Color(0xFFFF003C),
                          collapsedIconColor: Colors.white54,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sessionDate, style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: attendanceRate,
                                      backgroundColor: Colors.white12,
                                      color: attendanceRate > 0.7 ? Colors.greenAccent : (attendanceRate > 0.4 ? Colors.orangeAccent : Colors.redAccent),
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('${(attendanceRate * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$presentCount Present • $absentCount Absent', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                                if (index < _sessions.length - 1)
                                  Row(
                                    children: [
                                      Text(trendText, style: TextStyle(color: trendColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          children: [
                            _SessionDetailsTabs(presentStudents: sessionLogs, absentStudents: absentStudents),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SessionDetailsTabs extends StatelessWidget {
  final List<dynamic> presentStudents;
  final List<dynamic> absentStudents;

  const _SessionDetailsTabs({required this.presentStudents, required this.absentStudents});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: const Color(0xFFFF003C),
            labelColor: const Color(0xFFFF003C),
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'PRESENT (${presentStudents.length})'),
              Tab(text: 'ABSENT (${absentStudents.length})'),
            ],
          ),
          SizedBox(
            height: 300, // Fixed height for the tab views inside ExpansionTile
            child: TabBarView(
              children: [
                // PRESENT TAB
                presentStudents.isEmpty
                    ? Center(child: Text('Nobody attended', style: TextStyle(color: Colors.white.withOpacity(0.3))))
                    : ListView.separated(
                        itemCount: presentStudents.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (context, idx) {
                          final log = presentStudents[idx];
                          final time = log['signed_at'] != null
                              ? DateFormat('HH:mm').format(DateTime.parse(log['signed_at']).toLocal())
                              : '';
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.greenAccent.withOpacity(0.1),
                              child: const Icon(Icons.check, size: 14, color: Colors.greenAccent),
                            ),
                            title: Text(log['full_name'] ?? 'Unknown', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14)),
                            subtitle: Text(log['university_id'] ?? 'Unknown', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                            trailing: Text(time, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                          );
                        },
                      ),
                // ABSENT TAB
                absentStudents.isEmpty
                    ? Center(child: Text('Perfect attendance!', style: TextStyle(color: Colors.greenAccent.withOpacity(0.8))))
                    : ListView.separated(
                        itemCount: absentStudents.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (context, idx) {
                          final student = absentStudents[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.redAccent.withOpacity(0.1),
                              child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                            ),
                            title: Text(student['full_name'] ?? 'Unknown', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14)),
                            subtitle: Text(student['university_id'] ?? 'Unknown', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text('ABSENT', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
