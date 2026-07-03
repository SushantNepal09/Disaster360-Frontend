import 'package:flutter/material.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/citizen/citizen_report_detail_screen.dart';
import 'package:disaster360/widgets/image_viewer_overlay.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/widgets/pressable_widget.dart';

class CitizenReportCard extends StatefulWidget {
  final ReportModel report;
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;
  final Duration animationDelay;

  const CitizenReportCard({
    super.key,
    required this.report,
    this.onUpvote,
    this.onDownvote,
    this.animationDelay = Duration.zero,
  });

  @override
  State<CitizenReportCard> createState() => _CitizenReportCardState();
}

class _CitizenReportCardState extends State<CitizenReportCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _isDescriptionExpanded = false;
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOutCubic,
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.animationDelay, () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
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

  String _relativeDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return dateString;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> mediaUrls) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();
    final actualCount = mediaUrls.length.clamp(1, 5);
    final visibleCards = actualCount == 1 ? 1 : (actualCount == 2 ? 2 : 3);
    final extraCount = actualCount - visibleCards;

    return SizedBox(
      height: 180,
      child: Row(
        children: List.generate(visibleCards, (i) {
          final isLast = i == visibleCards - 1 && extraCount > 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => _openImageViewer(i),
              child: Container(
                margin: EdgeInsets.only(right: i < visibleCards - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        mediaUrls[i],
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white24,
                              size: 32,
                            ),
                      ),
                      if (isLast)
                        Container(
                          color: Colors.black.withOpacity(0.65),
                          child: Center(
                            child: Text(
                              '+$extraCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: Material(
                color: Colors.transparent,
                child: PressableWidget(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CitizenReportDetailScreen(report: widget.report),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _hovering ? AppColors.orange.withOpacity(0.35) : AppColors.border,
                        width: 1,
                      ),
                      boxShadow: _hovering
                          ? [
                              BoxShadow(
                                color: AppColors.orange.withOpacity(0.08),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. User Information
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.orange.withOpacity(0.2),
                              child: Text(
                                report.userName.isNotEmpty ? report.userName[0].toUpperCase() : 'C',
                                style: const TextStyle(
                                  color: AppColors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _relativeDate(report.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2. Disaster Information
                        Row(
                          children: [
                            Text(
                              report.disasterType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildSeverityBadge(report.severity),
                            const SizedBox(width: 8),
                            _buildStatusBadge(report.status),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 3. Report Description
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isDescriptionExpanded = !_isDescriptionExpanded;
                            });
                          },
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            crossFadeState: _isDescriptionExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            firstChild: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: report.description.length > 50 
                                      ? report.description.substring(0, 50) 
                                      : report.description,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (report.description.length > 50)
                                    const TextSpan(
                                      text: ' ... See more',
                                      style: TextStyle(
                                        color: AppColors.info,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            secondChild: Text(
                              report.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Report Images
                        _buildImageGrid(report.mediaUrls),
                        if (report.mediaUrls.isNotEmpty) const SizedBox(height: 16),

                        // 5. Bottom Information Row
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (report.submissions.length > 1) ...[
                              const Icon(Icons.group_outlined, color: Colors.white54, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${report.submissions.length}',
                                style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 24),
                            ],
                            const Spacer(),
                            GestureDetector(
                              onTap: widget.onUpvote,
                              child: Row(
                                children: [
                                  Icon(
                                    report.userReaction == 'LIKE' ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                                    color: report.userReaction == 'LIKE' ? AppColors.success : Colors.white54,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${report.likes}',
                                    style: TextStyle(
                                      color: report.userReaction == 'LIKE' ? AppColors.success : Colors.white54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            GestureDetector(
                              onTap: widget.onDownvote,
                              child: Row(
                                children: [
                                  Icon(
                                    report.userReaction == 'DISLIKE' ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined,
                                    color: report.userReaction == 'DISLIKE' ? AppColors.danger : Colors.white54,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${report.dislikes}',
                                    style: TextStyle(
                                      color: report.userReaction == 'DISLIKE' ? AppColors.danger : Colors.white54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
