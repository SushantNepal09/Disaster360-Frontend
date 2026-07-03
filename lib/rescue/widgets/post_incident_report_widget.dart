import 'package:disaster360/colors.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:disaster360/models/post_incident_report.dart';
import 'package:disaster360/services/rescue_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PostIncidentReportWidget extends StatefulWidget {
  final int operationId;
  final bool isCompleted;

  const PostIncidentReportWidget({
    Key? key,
    required this.operationId,
    required this.isCompleted,
  }) : super(key: key);

  @override
  State<PostIncidentReportWidget> createState() => _PostIncidentReportWidgetState();
}

class _PostIncidentReportWidgetState extends State<PostIncidentReportWidget> {
  final RescueService _rescueService = RescueService();
  bool _isLoading = true;
  bool _isSaving = false;
  PostIncidentReport? _report;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _rescueService.getPostIncidentReport(widget.operationId);
      if (data != null) {
        _report = PostIncidentReport.fromJson(data);
      }
    } catch (e) {
      debugPrint("Failed to load report: \$e");
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
        await _rescueService.uploadReportAttachments(widget.operationId, paths);
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
          SnackBar(content: Text('Failed to upload PDFs: \$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    if (_report == null || _report!.id == null) return;
    try {
      setState(() => _isSaving = true);
      await _rescueService.deleteReportAttachment(_report!.id!, attachmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment deleted.')),
        );
      }
      await _loadReport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete attachment: \$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Post Incident Report',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Supporting Documents',
          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        
        if (_report?.attachments != null && _report!.attachments.isNotEmpty)
          ..._report!.attachments.map((att) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
              title: Text(att.originalFilename, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('\${(att.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB', style: const TextStyle(color: Colors.white54)),
                  if (att.uploadedAt != null) ...[
                    const SizedBox(height: 2),
                    Text('Uploaded: \${_formatDate(att.uploadedAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.blueAccent),
                    onPressed: () => launchUrl(Uri.parse(att.fileUrl)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: _isSaving ? null : () => _deleteAttachment(att.id),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          )).toList()
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text('No supporting documents uploaded yet.', style: TextStyle(color: Colors.white54)),
          ),

        const Divider(color: Colors.white10, height: 32),
        
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          icon: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.upload_file),
          label: const Text('Upload PDF', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _isSaving ? null : _pickAndUploadPDFs,
        ),
      ],
    );
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
