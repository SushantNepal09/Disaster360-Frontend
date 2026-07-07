import 'package:disaster360/colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/providers/report_provider.dart';

class AdminCompletedReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const AdminCompletedReportDetailScreen({super.key, required this.report});

  @override
  State<AdminCompletedReportDetailScreen> createState() =>
      _AdminCompletedReportDetailScreenState();
}

class _AdminCompletedReportDetailScreenState
    extends State<AdminCompletedReportDetailScreen> {

  List<dynamic> _timelineEvents = [];
  bool _isLoadingTimeline = true;

  @override
  void initState() {
    super.initState();
    _fetchTimeline();
  }

  Future<void> _fetchTimeline() async {
    try {
      final incidentId = widget.report['incident_id'];
      final api = ApiService();
      final response = await api.get('/reports/$incidentId/rescue-timeline');
      if (mounted) {
        setState(() {
          if (response is List) {
             _timelineEvents = response;
          } else if (response is Map) {
             _timelineEvents = response['data'] ?? response['timeline'] ?? [];
          }
          _isLoadingTimeline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTimeline = false;
        });
      }
    }
  }

  final TextEditingController _finalReportController = TextEditingController();
  bool _isSubmitting = false;

  void _submitFinalReport() async {
    final text = _finalReportController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a final resolution report.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final incidentId = int.parse(widget.report['incident_id'].toString());
      await context.read<ReportProvider>().submitFinalAdminReport(
        incidentId,
        text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident closed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error closing incident: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _finalReportController.dispose();
    super.dispose();
  }

  String _relativeDate(String dateStr) {
    try {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }
      final dt = DateTime.parse(dateStr).toLocal();
      const monthNames = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override

  Widget _buildRescueTimeline() {
    if (_isLoadingTimeline) {
      return const Center(child: CircularProgressIndicator(color: AppColors.orange));
    }
    if (_timelineEvents.isEmpty) {
      return const Text('No timeline events found.', style: TextStyle(color: Colors.white54));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RESCUE TIMELINE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        ..._timelineEvents.map((event) {
          final title = event['title'] ?? 'Event';
          final desc = event['description'] ?? '';
          final time = event['timestamp'] != null ? _relativeDate(event['timestamp']) : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 40,
                      color: AppColors.border,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPostIncidentReport() {
    // Backend doesn't return attachments for completed operations, so this is handled in team reports.
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final teams = (report['teams'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Completed Operation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRescueTimeline(),
            const SizedBox(height: 24),
            _buildPostIncidentReport(),

            const SizedBox(height: 24),
            const Text(
              'RESCUE POST DISASTER REPORTS',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ).animate().fade().slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),

            // Teams list
            ...teams.map((t) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          (t['team_name'] ?? 'Unknown Team').toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          t['completed_at'] != null
                              ? _relativeDate(t['completed_at'].toString())
                              : '',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Text(
                      (t['report'] ?? 'No final report provided.').toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.05, end: 0);
            }),

            if (teams.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No rescue teams were assigned to this incident.',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            const Text(
              'ADMIN RESOLUTION',
              style: TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ).animate().fade().slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _finalReportController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText:
                      'Enter final resolution report to close this incident...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ).animate().fade().slideY(begin: 0.05, end: 0),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFinalReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child:
                    _isSubmitting
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'SUBMIT & CLOSE INCIDENT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
              ),
            ).animate().fade().slideY(begin: 0.05, end: 0),
            const SizedBox(height: 40),
          ],
        ),
      ),
     ),
    ),
   );
  }
}
