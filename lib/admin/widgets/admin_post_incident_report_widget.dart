import 'package:disaster360/colors.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPostIncidentReportWidget extends StatefulWidget {
  final String incidentId;
  final bool isCompleted;

  const AdminPostIncidentReportWidget({
    Key? key,
    required this.incidentId,
    required this.isCompleted,
  }) : super(key: key);

  @override
  State<AdminPostIncidentReportWidget> createState() => _AdminPostIncidentReportWidgetState();
}

class _AdminPostIncidentReportWidgetState extends State<AdminPostIncidentReportWidget> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _reportData;

  String get _cleanIncidentId => widget.incidentId.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.fetchAdminReport(_cleanIncidentId);
      if (response != null && response['success'] == true) {
        _reportData = response['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("Failed to load admin report: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPDFs() async {
    if (!widget.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operation must be Completed to upload documents.')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isSaving = true);
        final paths = result.files.map((e) => e.path!).toList();
        await _apiService.uploadAdminReportAttachments(_cleanIncidentId, paths);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDFs uploaded successfully.')),
          );
        }
        await _loadReport();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload PDFs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    try {
      setState(() => _isSaving = true);
      await _apiService.deleteAdminReportAttachment(_cleanIncidentId, attachmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment deleted.')),
        );
      }
      await _loadReport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete attachment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final attachments = (_reportData?['attachments'] as List<dynamic>?) ?? [];
    final description = _reportData?['description'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.bgDark,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Admin Final Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (description != null && description.isNotEmpty) ...[
              const Text(
                'Final Admin Description:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
            ],
            const Text(
              'Attachments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            if (attachments.isEmpty)
              const Text(
                'No attachments yet.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  final att = attachments[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
                    title: Text(att['original_filename'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text('${(att['file_size'] / 1024).toStringAsFixed(1)} KB', style: const TextStyle(color: Colors.white54)),
                    onTap: () => _openFile(att['file_url']),
                    trailing: widget.isCompleted
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download, color: Colors.blueAccent),
                                onPressed: () => _openFile(att['file_url']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: _isSaving ? null : () => _deleteAttachment(att['id']),
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.download, color: Colors.blueAccent),
                            onPressed: () => _openFile(att['file_url']),
                          ),
                  );
                },
              ),
            if (widget.isCompleted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _pickAndUploadPDFs,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('Upload PDFs', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
