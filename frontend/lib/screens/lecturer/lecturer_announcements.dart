import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class LecturerAnnouncements extends StatefulWidget {
  const LecturerAnnouncements({super.key});

  @override
  State<LecturerAnnouncements> createState() => _LecturerAnnouncementsState();
}

class _LecturerAnnouncementsState extends State<LecturerAnnouncements> {
  List<dynamic> _announcements = [];
  List<dynamic> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final announcementsResult = await ApiService.get('/announcements/lecturer/all');
    final classesResult = await ApiService.get('/lecturer/timetable');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (announcementsResult['success']) _announcements = announcementsResult['data'] as List;
        if (classesResult['success']) _classes = classesResult['data'] as List;
      });
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String? selectedClassId;
    String? attachedFileName;
    String? uploadedFileUrl;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1C29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFF003C)),
          ),
          title: Text('NEW ANNOUNCEMENT',
              style: GoogleFonts.orbitron(color: const Color(0xFFFF003C), fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class selector
                if (_classes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedClassId,
                    dropdownColor: const Color(0xFF1A1C29),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Class (optional)'),
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('All Students', style: TextStyle(color: Colors.white54))),
                      ..._classes.map((c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text('${c['code']} - ${c['title']}'),
                          )),
                    ],
                    onChanged: (v) => setDlgState(() => selectedClassId = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // File attachment section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0E15),
                    border: Border.all(
                      color: uploadedFileUrl != null
                          ? const Color(0xFFFF003C).withOpacity(0.6)
                          : Colors.white12,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATTACHMENT',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isUploading)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Color(0xFFFF003C), strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Uploading...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          ],
                        )
                      else if (uploadedFileUrl != null)
                        Row(
                          children: [
                            const Icon(Icons.attach_file, color: Color(0xFFFF003C), size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                attachedFileName ?? 'File attached',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setDlgState(() {
                                uploadedFileUrl = null;
                                attachedFileName = null;
                              }),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: [
                                'pdf', 'doc', 'docx', 'ppt', 'pptx',
                                'xls', 'xlsx', 'png', 'jpg', 'jpeg', 'gif'
                              ],
                            );
                            if (picked == null || picked.files.isEmpty) return;
                            final file = picked.files.first;

                            setDlgState(() => isUploading = true);

                            try {
                              final url = Uri.parse('${ApiService.baseUrl}/announcements/upload');
                              final req = http.MultipartRequest('POST', url);
                              req.headers['Authorization'] = 'Bearer ${ApiService.currentToken}';

                              if (kIsWeb && file.bytes != null) {
                                req.files.add(http.MultipartFile.fromBytes(
                                  'file',
                                  file.bytes!,
                                  filename: file.name,
                                ));
                              } else if (!kIsWeb && file.path != null) {
                                req.files.add(await http.MultipartFile.fromPath(
                                  'file',
                                  file.path!,
                                  filename: file.name,
                                ));
                              }

                              final response = await req.send().timeout(const Duration(seconds: 30));
                              final body = await http.Response.fromStream(response);

                              if (response.statusCode == 200) {
                                final data = jsonDecode(body.body);
                                setDlgState(() {
                                  uploadedFileUrl = data['file_url'];
                                  attachedFileName = file.name;
                                  isUploading = false;
                                });
                              } else {
                                setDlgState(() => isUploading = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Upload failed'),
                                        backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            } catch (e) {
                              debugPrint('Upload error: $e');
                              setDlgState(() => isUploading = false);
                            }
                          },
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Attach File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                    ],
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
                if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                final body = <String, dynamic>{
                  'title': titleCtrl.text.trim(),
                  'body': bodyCtrl.text.trim(),
                };
                if (selectedClassId != null) body['class_id'] = selectedClassId!;
                if (uploadedFileUrl != null) body['file_url'] = uploadedFileUrl!;

                final result = await ApiService.post('/announcements', body);
                if (mounted) {
                  Navigator.pop(ctx);
                  if (result['success']) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Announcement posted'),
                          backgroundColor: Color(0xFFFF003C)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0x33FF003C)),
              child: const Text('POST'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAnnouncement(String id) async {
    final result = await ApiService.delete('/announcements/$id');
    if (result['success']) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF003C)));
    }

    return Scaffold(
      body: _announcements.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('NO ANNOUNCEMENTS',
                      style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Tap + to create your first announcement',
                      style: TextStyle(color: Colors.white.withOpacity(0.3))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFF003C),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _announcements.length,
                itemBuilder: (context, index) {
                  final a = _announcements[index];
                  return _buildAnnouncementCard(a);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFFFF003C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final createdAt = announcement['created_at'] != null
        ? DateFormat('MMM d, yyyy • HH:mm')
            .format(DateTime.parse(announcement['created_at']).toLocal())
        : '';
    final fileUrl = announcement['file_url'] as String?;

    return Dismissible(
      key: Key(announcement['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      onDismissed: (_) => _deleteAnnouncement(announcement['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C29),
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF003C).withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  if (announcement['class_code'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF003C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(announcement['class_code'],
                          style: GoogleFonts.rajdhani(
                              color: const Color(0xFFFF003C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(announcement['class_title'] ?? '',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ] else
                    Text('All Students',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  const Spacer(),
                  Text(createdAt,
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(announcement['title'] ?? '',
                      style: GoogleFonts.rajdhani(
                          fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(announcement['body'] ?? '',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5)),
                  // File attachment chip
                  if (fileUrl != null) ...[
                    const SizedBox(height: 12),
                    _buildAttachmentChip(fileUrl),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentChip(String fileUrl) {
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFF003C).withOpacity(0.1),
          border: Border.all(color: const Color(0xFFFF003C).withOpacity(0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImage ? Icons.image : Icons.attach_file,
              size: 14,
              color: const Color(0xFFFF003C),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                fileName,
                style: const TextStyle(color: Color(0xFFFF003C), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new, size: 12, color: Color(0xFFFF003C)),
          ],
        ),
      ),
    );
  }
}
