import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:disaster360/colors.dart';

class CitizenPostIncidentReportWidget extends StatefulWidget {
  final String incidentId;

  const CitizenPostIncidentReportWidget({
    Key? key,
    required this.incidentId,
  }) : super(key: key);

  @override
  State<CitizenPostIncidentReportWidget> createState() => _CitizenPostIncidentReportWidgetState();
}

class _CitizenPostIncidentReportWidgetState extends State<CitizenPostIncidentReportWidget> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
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
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ));
    }

    final attachments = (_reportData?['attachments'] as List<dynamic>?) ?? [];
    final description = _reportData?['description'] as String?;

    if (attachments.isEmpty && (description == null || description.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.bgDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Post Disaster Report',
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
              Text(
                description,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],
            if (attachments.isNotEmpty) ...[
              const Text(
                'Attached Documents',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ...attachments.map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openFile(att['file_url']),
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: Text(
                        'View/Download ${att['original_filename'] ?? 'Report'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}
