import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/admin/widgets/admin_post_incident_report_widget.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:disaster360/services/gis_cache_service.dart';
import 'package:disaster360/utils/status_helper.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/widgets/image_viewer_overlay.dart';
import 'package:disaster360/widgets/shared_report_card.dart'; // for SharedActionButton if needed, or just build them

class CitizenReportDetailScreen extends StatefulWidget {
  final ReportModel report;

  const CitizenReportDetailScreen({super.key, required this.report});

  @override
  State<CitizenReportDetailScreen> createState() => _CitizenReportDetailScreenState();
}

class _CitizenReportDetailScreenState extends State<CitizenReportDetailScreen> {
  bool _isMergedExpanded = false;
  bool _isLiking = false;
  bool _isDisliking = false;
  
  List<dynamic> _timelineEvents = [];
  bool _isLoadingTimeline = true;
  String? _timelineError;

  String _localUnit = "Not Available";
  String _district = "Not Available";
  String _province = "Not Available";

  @override
  void initState() {
    super.initState();
    _fetchTimeline();
    _fetchLocationDetails();
  }

  Future<void> _fetchLocationDetails() async {
    try {
      final areas = await GisCacheService().identifyAdministrativeAreas(widget.report.latitude, widget.report.longitude);
      if (areas.isNotEmpty && areas.length >= 3) {
        if (mounted) {
          setState(() {
            _province = areas[0];
            _district = areas[1];
            _localUnit = areas[2];
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch location details: $e");
    }
  }

  Future<void> _fetchTimeline() async {
    final status = widget.report.status.toLowerCase();
    // Only fetch if it's assigned, in progress, controlled, or closed
    if (['assigned', 'in progress', 'controlled', 'closed', 'resolved'].contains(status)) {
      try {
        final res = await ApiService().fetchRescueTimeline(widget.report.id.toString());
        if (mounted) {
          setState(() {
            _timelineEvents = res['data'] ?? [];
            _isLoadingTimeline = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _timelineError = e.toString();
            _isLoadingTimeline = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingTimeline = false;
        });
      }
    }
  }

  Widget _buildTimelineSection() {
    if (_isLoadingTimeline) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }
    
    if (_timelineError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('Error loading timeline: $_timelineError', style: TextStyle(color: Colors.red)),
      );
    }

    if (_timelineEvents.isEmpty) {
      return _buildCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No rescue updates available yet.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rescue Operation Timeline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ..._timelineEvents.map((event) {
            final dateStr = _formatDate(event['created_at'] ?? '');
            final hasMedia = event['media_url'] != null && event['media_url'].toString().isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 50,
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'] ?? 'Update',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        if (event['description'] != null && event['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            event['description'],
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                        if (hasMedia) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              event['media_url'],
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 120,
                                color: Colors.grey[800],
                                child: const Icon(Icons.broken_image, color: Colors.white54),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  int _currentStepIndex(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return 0;
    if (s == 'verified') return 1;
    if (s == 'assigned' || s == 'acknowledged') return 2;
    if (s.contains('progress')) return 3;
    if (s.contains('resolved') || s.contains('controlled')) return 4;
    return 0;
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty || dateStr == 'Not Available') return 'Not Available';
    try {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      final month = months[dt.month - 1];
      final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $month ${dt.year} • $hour12:$minute $ampm';
    } catch (e) {
      return dateStr.split("T").first;
    }
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical':
        color = AppColors.danger;
        break;
      case 'high':
        color = AppColors.orange;
        break;
      case 'moderate':
        color = AppColors.warning;
        break;
      case 'low':
        color = AppColors.success;
        break;
      default:
        color = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Severity: ${severity.toUpperCase()}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = AppColors.orange;
        break;
      case 'verified':
        color = Colors.blue;
        break;
      case 'assigned':
        color = Colors.purple;
        break;
      case 'in progress':
      case 'inprogress':
        color = Colors.cyan;
        break;
      case 'resolved':
      case 'controlled':
        color = AppColors.success;
        break;
      case 'rejected':
        color = AppColors.danger;
        break;
      default:
        color = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Status: ${status.toUpperCase()}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  void _openImageViewer(int index) {
    if (widget.report.mediaUrls.isEmpty) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder:
          (_, __, ___) => ImageViewerOverlay(
            mediaUrls: widget.report.mediaUrls,
            initialIndex: index,
            reportId: widget.report.id.toString(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final steps = ['Pending', 'Verified', 'Assigned & In Progress', 'Controlled'];
    final currentIndex = _currentStepIndex(report.status);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
        ),
        title: Text(
          'Report Detail',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Header
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          report.disasterType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        report.title.isNotEmpty ? report.title : report.disasterType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSeverityBadge(report.severity),
                          _buildStatusBadge(report.status),
                        ],
                      ),
                    ],
                  ),
                ),

                // Section 2: Reporter Info
                _buildCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.info.withOpacity(0.2),
                        child: Text(
                          report.userName.isNotEmpty ? report.userName[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Uploaded: ${_formatDate(report.createdAt)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Section 3: Description
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        report.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Section 4: Images
                if (report.mediaUrls.isNotEmpty)
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Evidence Media',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: report.mediaUrls.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openImageViewer(index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  report.mediaUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Icon(Icons.broken_image_outlined, color: Colors.white24),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                // Section: Timeline
                if (['assigned', 'in progress', 'controlled', 'closed', 'resolved'].contains(report.status.toLowerCase()))
                  _buildTimelineSection(),

                if (['closed', 'resolved'].contains(report.status.toLowerCase()))
                  AdminPostIncidentReportWidget(incidentId: widget.report.id.toString(), isCompleted: false),

                // Section 5: Location
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Details',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_outlined, color: AppColors.orange, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Local Unit: $_localUnit',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'District: $_district',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Province: $_province',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Section 6: Timeline
                if (!['closed', 'resolved', 'controlled', 'rejected', 'pending'].contains(report.status.toLowerCase()))
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Timeline',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...List.generate(steps.length, (i) {
                          final isDone = i <= currentIndex;
                          final isCurrent = i == currentIndex;
                          final isLast = i == steps.length - 1;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCurrent 
                                              ? AppColors.info 
                                              : (isDone ? AppColors.success : Colors.transparent),
                                          border: Border.all(
                                            color: isCurrent 
                                                ? AppColors.info 
                                                : (isDone ? AppColors.success : Colors.white24),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            color: isDone && i < currentIndex
                                                ? AppColors.success
                                                : Colors.white12,
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        steps[i],
                                        style: TextStyle(
                                          color: isCurrent
                                              ? AppColors.info
                                              : (isDone ? Colors.white : Colors.white30),
                                          fontSize: 15,
                                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      if (isCurrent && report.rescueTeam.isNotEmpty && steps[i].toLowerCase() != 'pending' && steps[i].toLowerCase() != 'verified') ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Assigned to: ${report.rescueTeam}',
                                          style: TextStyle(
                                            color: AppColors.info.withOpacity(0.8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // Section 7: Merged Reports
                if (report.submissions.length > 1)
                  _buildCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          'Merged Reports (${report.submissions.length - 1})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        iconColor: AppColors.info,
                        collapsedIconColor: Colors.white54,
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        onExpansionChanged: (val) => setState(() => _isMergedExpanded = val),
                        children: report.submissions.skip(1).map((sub) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.orange.withOpacity(0.2),
                                      child: Text(
                                        (sub['user_name'] ?? 'C').toString()[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sub['user_name'] ?? 'Citizen',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Uploaded: ${_formatDate(sub['created_at'] ?? sub['timestamp'] ?? 'Not Available')}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  sub['description'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Bottom Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLiking || _isDisliking ? null : () async {
                          setState(() => _isLiking = true);
                          await context.read<ReportProvider>().toggleReaction(report.id, 'LIKE');
                          if(mounted) setState(() => _isLiking = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: report.userReaction == 'LIKE' ? AppColors.success.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: report.userReaction == 'LIKE' ? AppColors.success.withOpacity(0.5) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isLiking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success)) : Icon(
                                report.userReaction == 'LIKE' ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                                color: report.userReaction == 'LIKE' ? AppColors.success : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${report.likes} Likes',
                                style: TextStyle(
                                  color: report.userReaction == 'LIKE' ? AppColors.success : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLiking || _isDisliking ? null : () async {
                          setState(() => _isDisliking = true);
                          await context.read<ReportProvider>().toggleReaction(report.id, 'DISLIKE');
                          if(mounted) setState(() => _isDisliking = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: report.userReaction == 'DISLIKE' ? AppColors.danger.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: report.userReaction == 'DISLIKE' ? AppColors.danger.withOpacity(0.5) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isDisliking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger)) : Icon(
                                report.userReaction == 'DISLIKE' ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined,
                                color: report.userReaction == 'DISLIKE' ? AppColors.danger : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${report.dislikes} Dislikes',
                                style: TextStyle(
                                  color: report.userReaction == 'DISLIKE' ? AppColors.danger : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
