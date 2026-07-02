import 'package:flutter/material.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/citizen/citizen_report_detail_screen.dart';
import 'package:disaster360/widgets/image_viewer_overlay.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/widgets/pressable_widget.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED REPORT CARD (Used in Citizen Home & Rescue Home)
// ══════════════════════════════════════════════════════════════════════════════

class SharedReportCard extends StatefulWidget {
  final ReportModel report;
  
  // Citizen Callbacks
  final VoidCallback? onUpvote;
  final VoidCallback? onDownvote;
  
  // Rescue Callbacks
  final bool isRescueMode;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCardTap; // Allows overriding the default navigation
  
  final Duration animationDelay;

  const SharedReportCard({
    super.key,
    required this.report,
    this.onUpvote,
    this.onDownvote,
    this.isRescueMode = false,
    this.onAccept,
    this.onReject,
    this.onCardTap,
    this.animationDelay = Duration.zero,
  });

  @override
  State<SharedReportCard> createState() => _SharedReportCardState();
}

class _SharedReportCardState extends State<SharedReportCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _isExpanded = false;
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
                  onTap: widget.onCardTap ?? () {
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
                        // ── Top Header: Badges & Time ──────────────────────────
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                              ),
                              child: Text(
                                report.disasterType,
                                style: const TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SharedSeverityBadge(severity: report.severity),
                            const Spacer(),
                            const Icon(Icons.access_time, color: Colors.white38, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _relativeDate(report.createdAt),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Image Section ──────────────────────────────────────
                        _buildImageGrid(report.mediaUrls),
                        const SizedBox(height: 16),

                        // ── Report Information ─────────────────────────────────
                        Text(
                          report.title.isNotEmpty ? report.title : report.disasterType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            height: 1.5,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),

                        // ── Submissions Dropdown ───────────────────────────────
                        if (report.submissions.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.group_outlined,
                                color: Colors.white54,
                                size: 14,
                              ),
                              const Text(
                                'Reported by:',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              ...report.submissions.map(
                                (sub) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    (sub['user_name'] ?? 'Citizen').toString(),
                                    style: const TextStyle(
                                      color: AppColors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (report.submissions.isNotEmpty)
                          const SizedBox(height: 16),

                        // ── Nested Reports Dropdown ────────────────────────────
                        if (report.submissions.length > 1) ...[
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12, height: 1),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isExpanded
                                        ? 'Hide Matched Reports'
                                        : 'Show Matched Reports ()',
                                    style: const TextStyle(
                                      color: AppColors.orange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.orange,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isExpanded)
                            ...report.submissions
                                .skip(1)
                                .map((sub) => _buildNestedReportCard(sub, report)),
                          const SizedBox(height: 16),
                        ],

                        // ── Footer: Location & Reporter ────────────────────────
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.white38, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Lat: , Lng: ',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              report.userName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            SharedStatusBadge(status: report.status),
                            if (widget.isRescueMode && report.rescueTeam.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  report.rescueTeam,
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Action Buttons (Vote vs Accept/Reject) ─────────────
                        if (widget.isRescueMode)
                          Row(
                            children: [
                              Expanded(
                                child: SharedActionButton(
                                  label: 'Accept',
                                  icon: Icons.check_circle_outline,
                                  activeIcon: Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  active: false,
                                  onTap: widget.onAccept ?? () {},
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SharedActionButton(
                                  label: 'Reject',
                                  icon: Icons.cancel_outlined,
                                  activeIcon: Icons.cancel_rounded,
                                  color: AppColors.danger,
                                  active: false,
                                  onTap: widget.onReject ?? () {},
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: SharedActionButton(
                                  label: '',
                                  icon: Icons.thumb_up_alt_outlined,
                                  activeIcon: Icons.thumb_up_alt_rounded,
                                  color: AppColors.success,
                                  active: report.userReaction == 'LIKE',
                                  onTap: widget.onUpvote ?? () {},
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SharedActionButton(
                                  label: '',
                                  icon: Icons.thumb_down_alt_outlined,
                                  activeIcon: Icons.thumb_down_alt_rounded,
                                  color: AppColors.danger,
                                  active: report.userReaction == 'DISLIKE',
                                  onTap: widget.onDownvote ?? () {},
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

  Widget _buildNestedReportCard(dynamic sub, ReportModel mainReport) {
    return GestureDetector(
      onTap: () {
        _showNestedReportDetails(sub, mainReport);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    sub['title'] ?? mainReport.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatTime(sub['timestamp'] ?? mainReport.createdAt),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sub['description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.orange,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  sub['user_name'] ?? 'Citizen',
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    return _relativeDate(raw);
  }

  void _showNestedReportDetails(dynamic sub, ReportModel mainReport) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        sub['title'] ?? mainReport.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: AppColors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sub['user_name'] ?? 'Citizen',
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.access_time,
                      color: Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(sub['timestamp'] ?? mainReport.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nested Image Grid
                if (sub['media_urls'] != null &&
                    (sub['media_urls'] as List).isNotEmpty)
                  _buildSubImageGrid(
                    (sub['media_urls'] as List).map((e) => e.toString()).toList(),
                    sub['id'].toString(),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: AppColors.bgDark,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            color: Colors.white24,
                            size: 40,
                          ),
                          Positioned(
                            bottom: 8,
                            child: Text(
                              'No Evidence Photo',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                Text(
                  'Description',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sub['description'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Likes/Dislikes for Child Report
                if (!widget.isRescueMode)
                  Row(
                    children: [
                      Expanded(
                        child: SharedActionButton(
                          label: '${sub['likes'] ?? 0}',
                          icon: Icons.thumb_up_alt_outlined,
                          activeIcon: Icons.thumb_up_alt_rounded,
                          color: AppColors.success,
                          active: sub['user_reaction'] == 'LIKE',
                          onTap: () {
                            context.read<ReportProvider>().reactToSubmission(
                              mainReport.id,
                              sub['id'],
                              'LIKE',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SharedActionButton(
                          label: '${sub['dislikes'] ?? 0}',
                          icon: Icons.thumb_down_alt_outlined,
                          activeIcon: Icons.thumb_down_alt_rounded,
                          color: AppColors.danger,
                          active: sub['user_reaction'] == 'DISLIKE',
                          onTap: () {
                            context.read<ReportProvider>().reactToSubmission(
                              mainReport.id,
                              sub['id'],
                              'DISLIKE',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openImageViewerFromSub(int index, List<String> mediaUrls, String reportId) {
    if (mediaUrls.isEmpty) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder:
          (_, __, ___) => ImageViewerOverlay(
            mediaUrls: mediaUrls,
            initialIndex: index,
            reportId: reportId,
          ),
    );
  }

  Widget _buildSubImageGrid(List<String> mediaUrls, String reportId) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();
    final actualCount = mediaUrls.length.clamp(1, 5);
    final visibleCards = actualCount == 1 ? 1 : 2;
    final extraCount = actualCount - visibleCards;

    return Row(
      children: List.generate(visibleCards, (i) {
        final isLast = i == visibleCards - 1 && extraCount > 0;
        return Expanded(
          child: GestureDetector(
            onTap: () => _openImageViewerFromSub(i, mediaUrls, reportId),
            child: Container(
              height: 160,
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
                          (context, error, stackTrace) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white.withOpacity(0.2),
                                size: 32,
                              ),
                            ],
                          ),
                    ),
                    if (isLast)
                      Container(
                        color: Colors.black.withOpacity(0.65),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+$extraCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'more',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
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
    );
  }

  Widget _buildImageGrid(List<String> mediaUrls) {
    if (mediaUrls.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 8),
            Text(
              'No visual evidence provided',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }
    
    final actualCount = mediaUrls.length;
    final visibleCards = actualCount.clamp(1, 2);
    final extraCount = actualCount - visibleCards;

    return Row(
      children: List.generate(visibleCards, (i) {
        final isLast = i == visibleCards - 1 && extraCount > 0;
        return Expanded(
          child: GestureDetector(
            onTap: () => _openImageViewer(i),
            child: Container(
              height: 240, // Increased height for desktop
              margin: EdgeInsets.only(right: i < visibleCards - 1 ? 12 : 0),
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
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white.withOpacity(0.2),
                            size: 32,
                          ),
                        ],
                      ),
                    ),
                    if (isLast)
                      Container(
                        color: Colors.black.withOpacity(0.65),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'more',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
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
    );
  }

  String _relativeDate(String dateStr) {
    try {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inHours < 1) {
        if (diff.inMinutes < 1) return 'Just now';
        return '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} hours ago';
      } else if (diff.inDays < 30) {
        return '${diff.inDays} days ago';
      } else if (diff.inDays < 365) {
        const monthNames = [
          "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        return '${monthNames[dt.month - 1]} ${dt.day}';
      } else {
        const monthNames = [
          "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTION BUTTON (Vote or Accept/Reject)
// ══════════════════════════════════════════════════════════════════════════════

class SharedActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const SharedActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  State<SharedActionButton> createState() => _SharedActionButtonState();
}

class _SharedActionButtonState extends State<SharedActionButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _tapCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _tapCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _tapCtrl.forward();
    _tapCtrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color:
                  widget.active
                      ? widget.color.withOpacity(0.25)
                      : _hovered
                      ? widget.color.withOpacity(0.18)
                      : widget.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.color.withOpacity(
                  widget.active
                      ? 0.8
                      : _hovered
                      ? 0.55
                      : 0.30,
                ),
                width: widget.active ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder:
                      (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    widget.active ? widget.activeIcon : widget.icon,
                    key: ValueKey(widget.active),
                    color: widget.color,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: widget.color,
                    fontSize: widget.active || _hovered ? 12.8 : 12,
                    fontWeight:
                        widget.active ? FontWeight.w800 : FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STATUS BADGE
// ══════════════════════════════════════════════════════════════════════════════

class SharedStatusBadge extends StatelessWidget {
  final String status;
  const SharedStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final bg = StatusHelper.getStatusBgColor(status);
    final text = StatusHelper.getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: text.withOpacity(0.4), width: 1),
      ),
      child: Text(
        StatusHelper.getStatusText(status),
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class StatusHelper {
  static String getStatusText(String dbStatus) {
    final lower = dbStatus.toLowerCase();
    if (lower == 'verified rescue in progress') return 'In Progress';
    if (lower == 'verified controlled') return 'Controlled';
    if (lower == 'verified and closed') return 'Resolved';
    if (lower == 'assigned') return 'Team Dispatched';
    if (lower == 'verified') return 'Verified';
    if (lower == 'rejected') return 'Declined';
    return 'Under Review';
  }

  static Color getStatusColor(String dbStatus) {
    final lower = dbStatus.toLowerCase();
    if (lower == 'verified rescue in progress') return AppColors.info;
    if (lower == 'verified controlled') return AppColors.success;
    if (lower == 'verified and closed') return Colors.tealAccent;
    if (lower == 'assigned') return AppColors.orange;
    if (lower == 'verified') return Colors.blueAccent;
    if (lower == 'rejected') return AppColors.danger;
    return AppColors.warning;
  }

  static Color getStatusBgColor(String dbStatus) {
    return getStatusColor(dbStatus).withOpacity(0.15);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEVERITY BADGE
// ══════════════════════════════════════════════════════════════════════════════

class SharedSeverityBadge extends StatelessWidget {
  final String severity;
  const SharedSeverityBadge({super.key, required this.severity});

  Color get _color {
    switch (severity.toLowerCase()) {
      case 'low': return const Color(0xFF4CAF50);
      case 'moderate': return const Color(0xFF8BC34A);
      case 'medium': return AppColors.warning;
      case 'high': return AppColors.orange;
      case 'severe': return AppColors.danger;
      case 'critical': return AppColors.danger;
      case 'extreme': return const Color(0xFFB71C1C);
      default: return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelStr = severity.isNotEmpty ? severity[0].toUpperCase() + severity.substring(1).toLowerCase() : 'Unknown';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: _color, size: 14),
          const SizedBox(width: 6),
          Text(
            levelStr,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
