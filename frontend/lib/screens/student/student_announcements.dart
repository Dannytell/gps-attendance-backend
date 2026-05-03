import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class StudentAnnouncements extends StatefulWidget {
  const StudentAnnouncements({super.key});

  @override
  State<StudentAnnouncements> createState() => _StudentAnnouncementsState();
}

class _StudentAnnouncementsState extends State<StudentAnnouncements> {
  List<dynamic> _announcements = [];
  List<dynamic> _activeSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final annResult = await ApiService.get('/announcements/student/all');
    final sesResult = await ApiService.get('/lecturer/active-sessions');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (annResult['success']) {
          _announcements = annResult['data'] as List;
        }
        if (sesResult['success']) {
          _activeSessions = sesResult['data'] as List;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)));
    }

    if (_announcements.isEmpty && _activeSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('NO ALERTS', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Announcements and active classes\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.3)),
            ),
          ],
        ),
      );
    }

    final totalItems = _activeSessions.length + _announcements.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF00F0FF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index < _activeSessions.length) {
            return _buildActiveSessionCard(_activeSessions[index]);
          } else {
            return _buildAnnouncementCard(_announcements[index - _activeSessions.length]);
          }
        },
      ),
    );
  }

  Widget _buildActiveSessionCard(Map<String, dynamic> session) {
    final classCode = session['class_code'] ?? 'Class';
    final classTitle = session['class_title'] ?? '';
    final code = session['dynamic_code'] ?? '';
    
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code $code copied to clipboard!'),
            backgroundColor: const Color(0xFF00F0FF),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF003C).withOpacity(0.1),
          border: Border.all(color: const Color(0xFFFF003C).withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF003C).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensor_door_outlined, color: Color(0xFFFF003C)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLASS IN SESSION!',
                      style: GoogleFonts.orbitron(color: const Color(0xFFFF003C), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$classCode • $classTitle',
                      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: $code (Tap to copy)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.copy, color: Color(0xFFFF003C), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final createdAt = announcement['created_at'] != null
        ? DateFormat('MMM d, yyyy • HH:mm').format(DateTime.parse(announcement['created_at']).toLocal())
        : '';

    final isRecent = announcement['created_at'] != null &&
        DateTime.now().difference(DateTime.parse(announcement['created_at'])).inHours < 24;

    final fileUrl = announcement['file_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C29),
        border: Border.all(color: isRecent ? const Color(0xFF00F0FF).withOpacity(0.4) : Colors.white12),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isRecent
            ? [BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.08), blurRadius: 12)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, size: 16, color: Color(0xFF00F0FF)),
                const SizedBox(width: 8),
                Text(
                  announcement['lecturer_name'] ?? 'Lecturer',
                  style: GoogleFonts.rajdhani(
                      color: const Color(0xFF00F0FF), fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (announcement['class_code'] != null) ...[
                  Text(' • ', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                  Text(
                    announcement['class_code'],
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
                const Spacer(),
                if (isRecent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F0FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('NEW',
                        style: GoogleFonts.rajdhani(
                            fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement['title'] ?? '',
                  style: GoogleFonts.rajdhani(
                      fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  announcement['body'] ?? '',
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
                ),
                // File attachment
                if (fileUrl != null) ...[
                  const SizedBox(height: 12),
                  _buildAttachmentButton(fileUrl),
                ],
                const SizedBox(height: 12),
                Text(createdAt,
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton(String fileUrl) {
    final fileName = fileUrl.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg', 'gif'].contains(ext);

    return InkWell(
      onTap: () async {
        final fullUrl = '${ApiService.baseUrl.replaceAll('/api', '')}$fileUrl';
        final uri = Uri.parse(fullUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF00F0FF).withOpacity(0.08),
          border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImage ? Icons.image_outlined : Icons.attach_file,
              size: 16,
              color: const Color(0xFF00F0FF),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                fileName,
                style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.download, size: 14, color: Color(0xFF00F0FF)),
          ],
        ),
      ),
    );
  }
}
