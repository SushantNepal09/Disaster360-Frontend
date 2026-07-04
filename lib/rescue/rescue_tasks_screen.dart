import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:disaster360/core/statuses.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/rescue/rescue_disaster_report.dart';
import 'package:disaster360/rescue/rescue_mark_controlled.dart';
import 'package:disaster360/rescue/rescue_motion.dart';
import 'package:disaster360/widgets/image_viewer_overlay.dart';
import 'package:disaster360/rescue/rescue_disaster_detail_screen.dart';
import 'package:disaster360/widgets/rejection_dialog.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  RESCUE TASKS SCREEN — Disaster360
//  • Search bar + filter tabs: All / Active / Pending / Completed
//  • Case A — Active:    Severity, Verified by admin, Accept + Details buttons
//  • Case B — Pending:   Severity, Verified by admin, Status Report + Mark as Done + Details buttons
//  • Case C — Completed: Severity, Verified by admin, Send Completion Report + Details buttons
//  • Case D — All:       Active first → Pending → Completed
//  • Emergency-themed Active cards (pulsing red left border)
//  • Basic hover + tap animations, hand cursor
//  • AppColors from existing codebase
//  • Image gallery: two-image grid with +N overlay, full-screen swipe gallery (same as citizen home)
// ═══════════════════════════════════════════════════════════════════════════════

class RescueTasksScreen extends StatefulWidget {
  const RescueTasksScreen({super.key});

  @override
  State<RescueTasksScreen> createState() => _RescueTasksScreenState();
}

class _RescueTasksScreenState extends State<RescueTasksScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<String> _filters = ['All', 'Active', 'Pending', 'Completed'];

  List<RescueTask> _filteredTasks(RescueProvider provider) {
    List<RescueTask> list;

    if (_selectedFilter == 'All') {
      list = provider.myAssignments;
    } else if (_selectedFilter == 'Completed') {
      list = provider.completedAssignments;
    } else {
      final statusMap = {
        'Active': TaskStatus.active,
        'Pending': TaskStatus.pending,
      };
      list =
          provider.myAssignments
              .where((t) => t.status == statusMap[_selectedFilter])
              .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list =
          list
              .where(
                (t) =>
                    t.taskId.toLowerCase().contains(q) ||
                    t.type.toLowerCase().contains(q) ||
                    t.location.toLowerCase().contains(q),
              )
              .toList();
    }

    return list;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    // Fetch real data from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RescueProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RescueProvider>(
      builder: (context, provider, _) {
        final filtered = _filteredTasks(provider);

        Widget content = Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Column(
            children: [
              _buildStickyTopBar(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child:
                        provider.isLoading &&
                                provider.myAssignments.isEmpty &&
                                provider.completedAssignments.isEmpty
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.orange,
                              ),
                            )
                            : RefreshIndicator(
                              color: AppColors.orange,
                              backgroundColor: const Color(0xFF1F1F1F),
                              onRefresh: () => provider.fetchAll(),
                              child: CustomScrollView(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        8,
                                      ),
                                      child: _buildFilterTabs(),
                                    ),
                                  ),
                                  if (filtered.isEmpty)
                                    SliverFillRemaining(
                                      child: _buildEmptyState(),
                                    )
                                  else
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate((
                                        context,
                                        i,
                                      ) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: _FacebookReportCard(
                                            task: filtered[i],
                                            onAccept:
                                                () => _handleAccept(
                                                  context,
                                                  filtered[i],
                                                ),
                                            onReject:
                                                () => _handleReject(
                                                  context,
                                                  filtered[i],
                                                ),
                                            onDetails:
                                                () => _handleDetails(
                                                  context,
                                                  filtered[i],
                                                ),
                                          ),
                                        );
                                      }, childCount: filtered.length),
                                    ),
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 32),
                                  ),
                                ],
                              ),
                            ),
                  ), // ConstrainedBox
                ), // Center
              ), // Expanded
            ], // children
          ), // Column
        ); // Scaffold
        return content;
      },
    );
  }

  Widget _buildStickyTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(bottom: BorderSide(color: Color(0x0FFFFFFF), width: 1)),
      ),
      child: Row(
        children: [
          const Text(
            'Your Tasks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            width: 200,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<RescueProvider>().fetchAll();
            },
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _filters.map((filter) {
              final isActive = _selectedFilter == filter;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? Colors.white : const Color(0x0FFFFFFF),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white54,
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, color: Colors.white24, size: 64),
          SizedBox(height: 16),
          Text(
            'No assignments yet',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Button handlers ────────────────────────────────────────────────────────

  void _handleReject(BuildContext context, RescueTask task) {
    showDialog(
      context: context,
      builder:
          (ctx) => RejectionDialog(assignmentId: int.parse(task.assignmentId)),
    );
  }

  void _handleAccept(BuildContext context, RescueTask task) {
    _showActionDialog(
      context: context,
      title: 'Accept Task',
      message:
          'Are you sure you want to accept ${task.taskId}?\nYou will be deployed to ${task.location}.',
      confirmLabel: 'Accept',
      confirmColor: AppColors.success,
      onConfirm: () async {
        Navigator.pop(context);
        try {
          final provider = context.read<RescueProvider>();
          await provider.acceptAssignment(int.parse(task.assignmentId));
          if (context.mounted) {
            _showSnack(
              context,
              '✓ Task #${task.taskId} accepted. Head to ${task.location}.',
              color: AppColors.success,
            );
          }
        } catch (e) {
          if (context.mounted) {
            _showSnack(
              context,
              e.toString().replaceFirst('Exception: ', ''),
              color: AppColors.danger,
            );
          }
        }
      },
    );
  }

void _handleDetails(BuildContext context, RescueTask task) {
    RescueMotion.push(context, RescueDisasterDetailScreen(task: task)).then((_) {
      if (context.mounted) {
        context.read<RescueProvider>().fetchMyAssignments();
      }
    });
  }

  void _handleStatusReport(BuildContext context, RescueTask task) {
    _showStatusReportSheet(context, task);
  }

  void _handleMarkDone(BuildContext context, RescueTask task) {
    RescueMotion.push(context, MarkAsControlledScreen(task: task)).then((_) {
      // Refresh tasks after returning from mark controlled screen
      if (context.mounted) context.read<RescueProvider>().fetchMyAssignments();
    });
  }

  void _handleCompletionReport(BuildContext context, RescueTask task) {
    RescueMotion.push(
      context,
      PostDisasterReportScreen(preSelectedTask: task),
    ).then((_) {
      if (context.mounted) context.read<RescueProvider>().fetchMyAssignments();
    });
  }

  void _showSnack(BuildContext context, String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: color.withOpacity(0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showActionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    RescueMotion.showSweetDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showStatusReportSheet(BuildContext context, RescueTask task) {
    final noteCtrl = TextEditingController();
    String selectedStatus = 'On Scene';
    final statuses = [
      'En Route',
      'On Scene',
      'Rescue Ongoing',
      'Awaiting Support',
    ];

    RescueMotion.showSweetBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder:
                  (ctx, setLS) => Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _sheetHandle()),
                        const SizedBox(height: 16),
                        const Text(
                          'Submit Status Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${task.taskId} · ${task.location}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Current Status',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              statuses.map((s) {
                                final sel = selectedStatus == s;
                                return GestureDetector(
                                  onTap: () => setLS(() => selectedStatus = s),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          sel
                                              ? AppColors.info.withOpacity(0.2)
                                              : AppColors.bgPrimary,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            sel
                                                ? AppColors.info
                                                : AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        color:
                                            sel
                                                ? AppColors.info
                                                : Colors.white54,
                                        fontSize: 12,
                                        fontWeight:
                                            sel
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Notes / Observations',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteCtrl,
                          maxLines: 3,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Describe current situation on the ground...',
                            hintStyle: const TextStyle(
                              color: Colors.white24,
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: AppColors.bgPrimary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.info,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showSnack(
                                context,
                                '✓ Status report submitted: $selectedStatus',
                                color: AppColors.info,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Submit Report',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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
  }

  Widget _sheetHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FULL-SCREEN IMAGE VIEWER OVERLAY (identical to citizen home)
// ══════════════════════════════════════════════════════════════════════════════

class _ImageViewerOverlay extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;
  final String reportId;

  const _ImageViewerOverlay({
    this.mediaUrls = const [],
    required this.initialIndex,
    required this.reportId,
  });

  @override
  State<_ImageViewerOverlay> createState() => _ImageViewerOverlayState();
}

class _ImageViewerOverlayState extends State<_ImageViewerOverlay>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  int _currentIndex = 0;

  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _focusNode = FocusNode()..requestFocus();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _close() {
    _fadeCtrl.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (_currentIndex > 0) {
                _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (_currentIndex < widget.mediaUrls.length - 1) {
                _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              _close();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // Blurred + darkened background
            GestureDetector(
              onTap: _close,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.black.withOpacity(0.88)),
              ),
            ),

            // Full-screen swipeable image pages – edge‑to‑edge
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.mediaUrls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                return Container(
                  color: AppColors.bgDark,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          color: Colors.white.withOpacity(0.2),
                          size: 72,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Photo ${i + 1}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '#${widget.reportId}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Next/Prev Arrows (Desktop navigation)
            if (widget.mediaUrls.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              if (_currentIndex < widget.mediaUrls.length - 1)
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
            ],

            // Top bar: report ID (left), counter (center), close button (right)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '#${widget.reportId}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'Photo ${_currentIndex + 1} of ${widget.mediaUrls.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _close,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dot indicators at bottom
            if (widget.mediaUrls.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.mediaUrls.length, (i) {
                    final active = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? AppColors.orange : Colors.white30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TASK CARD — with two‑image grid + full‑screen viewer
// ══════════════════════════════════════════════════════════════════════════════

class _FacebookReportCard extends StatelessWidget {
  final RescueTask task;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDetails;

  const _FacebookReportCard({
    required this.task,
    required this.onAccept,
    required this.onReject,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0FFFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.orange.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            task.reporterName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  task.reporterStatus.toLowerCase() == 'active'
                                      ? AppColors.success.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              task.reporterStatus,
                              style: TextStyle(
                                color:
                                    task.reporterStatus.toLowerCase() ==
                                            'active'
                                        ? AppColors.success
                                        : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.assignedAgo,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white54),
                  onPressed: onDetails, // Map details to more_horiz
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _SeverityBadge(level: task.severityLevel),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white38,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.location,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Photo Gallery
          _FacebookPhotoGallery(
            mediaUrls: task.mediaUrls,
            reportId: task.reportId,
          ),

          // Action Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == TaskStatus.active) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      label: const Text(
                        'Reject',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      'View Details',
                      style: TextStyle(color: Colors.white70),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x0FFFFFFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacebookPhotoGallery extends StatelessWidget {
  final List<String> mediaUrls;
  final String reportId;

  const _FacebookPhotoGallery({
    required this.mediaUrls,
    required this.reportId,
  });

  void _open(BuildContext context, int index) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.transparent,
      pageBuilder:
          (_, __, ___) => ImageViewerOverlay(
            mediaUrls: mediaUrls,
            initialIndex: index,
            reportId: reportId,
          ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    int index, {
    BoxFit fit = BoxFit.cover,
  }) {
    return GestureDetector(
      onTap: () => _open(context, index),
      child: Image.network(
        mediaUrls[index],
        fit: fit,
        errorBuilder:
            (_, __, ___) => Container(
              color: Colors.white12,
              child: const Icon(Icons.broken_image, color: Colors.white38),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = mediaUrls.length;
    if (count == 0) {
      return Container(
        height: 180,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white38,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                'No media attached',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (count == 1) {
      return SizedBox(
        width: double.infinity,
        height: 300,
        child: _buildImage(context, 0, fit: BoxFit.cover),
      );
    } else if (count == 2) {
      return SizedBox(
        height: 300,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildImage(context, 0)),
            const SizedBox(width: 2),
            Expanded(child: _buildImage(context, 1)),
          ],
        ),
      );
    } else if (count == 3) {
      return SizedBox(
        height: 300,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: _buildImage(context, 0)),
            const SizedBox(width: 2),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildImage(context, 1)),
                  const SizedBox(height: 2),
                  Expanded(child: _buildImage(context, 2)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildImage(context, 0)),
                  const SizedBox(width: 2),
                  Expanded(child: _buildImage(context, 1)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildImage(context, 2)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImage(context, 3),
                        if (count > 4)
                          GestureDetector(
                            onTap: () => _open(context, 3),
                            child: Container(
                              color: Colors.black54,
                              child: Center(
                                child: Text(
                                  '+${count - 4}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _TaskStatusBadge extends StatelessWidget {
  final String status;
  const _TaskStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final meta = StatusTheme.getAssignmentTheme(status);
    final bg = meta.color.withOpacity(0.15);
    final text = meta.color;
    final label = meta.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: text.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final int level;
  const _SeverityBadge({required this.level});

  static const _labels = ['', 'Low', 'Moderate', 'High', 'Severe', 'Extreme'];

  Color get _color {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50);
      case 2:
        return const Color(0xFF8BC34A);
      case 3:
        return AppColors.warning;
      case 4:
        return AppColors.orange;
      case 5:
        return AppColors.danger;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, color: _color, size: 11),
          const SizedBox(width: 4),
          Text(
            _labels[level],
            style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? widget;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.widget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white38, size: 15),
        const SizedBox(width: 8),
        Text(
          '$label  ',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        Expanded(
          child:
              widget != null
                  ? Align(alignment: Alignment.centerRight, child: widget!)
                  : Text(
                    value ?? '',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
        ),
      ],
    );
  }
}

// ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
//  DATA MODELS
// ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ

enum TaskStatus { active, pending, completed }

class RescueTask {
  final String assignmentId;
  final String assignmentStatus;
  final String? rejectionReason;
  final String taskId;
  final String teamAssignmentStatus;
  final bool isAssignedToCurrentTeam;
  final TaskStatus status;
  final String type;
  final String location;
  final String description;
  final String assignedAgo;
  final int severityLevel;
  final String verifiedByAdmin;
  final List<String> mediaUrls;
  final double lat;
  final double lng;
  final String reportId;
  final String reporterName;
  final String reporterStatus;
  final String title;
  final int? rescueUpdateId;
  final bool canAcknowledge;
  final bool canUpdateStatus;
  final bool canSubmitReport;
  final List<String> assignedTeams;
  final String? postIncidentReport;
  
  final String? acceptedAt;
  final String? reportedAt;
  final String? assignedBy;
  final int mergedReports;

  const RescueTask({
    required this.assignmentId,
    required this.assignmentStatus,
    this.rejectionReason,
    required this.taskId,
    this.teamAssignmentStatus = '',
    this.isAssignedToCurrentTeam = false,
    required this.status,
    required this.type,
    required this.location,
    required this.description,
    required this.assignedAgo,
    required this.severityLevel,
    required this.verifiedByAdmin,
    this.mediaUrls = const [],
    required this.lat,
    required this.lng,
    required this.reportId,
    required this.reporterName,
    required this.reporterStatus,
    required this.title,
    this.rescueUpdateId,
    this.canAcknowledge = false,
    this.canUpdateStatus = false,
    this.canSubmitReport = false,
    this.assignedTeams = const [],
    this.postIncidentReport,
    this.acceptedAt,
    this.reportedAt,
    this.assignedBy,
    required this.mergedReports,
  });

  // ── Severity string → int ─────────────────────────────────────────────────
  static int _parseSeverity(String? severity) {
    switch ((severity ?? '').toLowerCase()) {
      case 'low':
        return 1;
      case 'moderate':
        return 2;
      case 'high':
        return 3;
      case 'severe':
        return 4;
      case 'extreme':
        return 5;
      default:
        return 3;
    }
  }

  // ── Format datetime string to "X ago" ─────────────────────────────────────
  static String _timeAgo(String? dateStr) {
    if (dateStr == null) return 'Recently';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
  }

  // ── Build from new Backend JSON Envelope ──────────────────────────────────

  String get formattedSeverity {
    switch (severityLevel) {
      case 1: return 'LOW SEVERITY';
      case 2: return 'MODERATE SEVERITY';
      case 3: return 'HIGH SEVERITY';
      case 4: return 'SEVERE';
      case 5: return 'EXTREME SEVERITY';
      default: return 'UNKNOWN SEVERITY';
    }
  }

  Color get severityColor {
    switch (severityLevel) {
      case 1: return AppColors.success;
      case 2: return AppColors.info;
      case 3: return AppColors.warning;
      case 4:
      case 5: return AppColors.danger;
      default: return AppColors.primary;
    }
  }

  String get formattedStatus {
    return assignmentStatus.toUpperCase();
  }

  Color get statusColor {
    switch (assignmentStatus.toLowerCase()) {
      case 'in progress':
      case 'accepted':
        return AppColors.warning;
      case 'completed':
      case 'controlled':
      case 'closed':
        return AppColors.success;
      case 'cancelled':
      case 'rejected':
        return AppColors.danger;
      case 'assigned':
      default:
        return AppColors.info;
    }
  }

  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Unknown Time';
    try {
      if (!isoString.endsWith('Z') && !isoString.contains(RegExp(r'[+-]\d{2}:?\d{2}$'))) {
        isoString = '${isoString}Z';
      }
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      
      String hour = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
      String min = dt.minute.toString().padLeft(2, '0');
      String ampm = dt.hour < 12 ? 'AM' : 'PM';
      
      String timeStr = '$hour:$min $ampm';
      
      if (isToday) {
        return 'Today $timeStr';
      } else {
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $timeStr';
      }
    } catch (_) {
      return 'Invalid Time';
    }
  }
  factory RescueTask.fromJson(Map<String, dynamic> json) {
    final assignmentStatus = json['assignmentStatus'] ?? json['status'] ?? '';
    TaskStatus tStatus;
    if (assignmentStatus == 'Completed' ||
        assignmentStatus == 'Controlled' ||
        assignmentStatus == 'Closed') {
      tStatus = TaskStatus.completed;
    } else if (assignmentStatus == 'Accepted' ||
        assignmentStatus == 'In Progress') {
      tStatus = TaskStatus.pending;
    } else {
      tStatus = TaskStatus.active;
    }

    final loc = json['location'] as Map<String, dynamic>? ?? {};
    final mediaList = json['media'] as List<dynamic>? ?? [];
    List<String> parsedMediaUrls =
        mediaList.map((m) => m['url'].toString()).toList();

    if (parsedMediaUrls.isEmpty && json['media_urls'] != null) {
      parsedMediaUrls.addAll(List<String>.from(json['media_urls']));
    }
    if (parsedMediaUrls.isEmpty) {
      if (json['image'] != null && json['image'].toString().isNotEmpty) {
        parsedMediaUrls.add(json['image'].toString());
      } else if (json['imageUrl'] != null &&
          json['imageUrl'].toString().isNotEmpty) {
        parsedMediaUrls.add(json['imageUrl'].toString());
      } else if (json['operation'] != null &&
          json['operation']['image'] != null) {
        parsedMediaUrls.add(json['operation']['image'].toString());
      } else if (json['incident'] != null &&
          json['incident']['image'] != null) {
        parsedMediaUrls.add(json['incident']['image'].toString());
      }
    }
    // Clean out 'null' strings that may have been parsed
    parsedMediaUrls =
        parsedMediaUrls
            .where((url) => url.trim() != 'null' && url.isNotEmpty)
            .toList();

    final actions = json['actions'] as Map<String, dynamic>? ?? {};

    // Parse rescueUpdateId which might be inside actions or root
    int? parsedRescueUpdateId;
    if (json['rescueUpdateId'] != null) {
      parsedRescueUpdateId = int.tryParse(json['rescueUpdateId'].toString());
    } else if (actions['rescueUpdateId'] != null) {
      parsedRescueUpdateId = int.tryParse(actions['rescueUpdateId'].toString());
    }

    final rescueTeam = json['rescueTeam'] as Map<String, dynamic>?;
    final List<String> parsedAssignedTeams = [];
    if (rescueTeam != null && rescueTeam['name'] != null) {
      parsedAssignedTeams.add(rescueTeam['name'].toString());
    }

    return RescueTask(
      assignmentId: json['assignmentId']?.toString() ?? '',
      assignmentStatus: json['assignmentStatus']?.toString() ?? '',
      rejectionReason: json['rejectionReason']?.toString(),
      taskId: json['incidentId']?.toString() ?? '',
      teamAssignmentStatus: json['teamAssignmentStatus']?.toString() ?? '',
      isAssignedToCurrentTeam: json['isAssignedToCurrentTeam'] ?? false,
      status: tStatus,
      type: json['disasterType'] ?? 'Unknown',
      location: loc['address'] ?? 'Unknown',
      description: json['description'] ?? '',
      assignedAgo: _timeAgo(
        (json['assignedAt'] ?? json['reportedAt'])?.toString(),
      ),
      severityLevel: _parseSeverity(json['severity']?.toString()),
      verifiedByAdmin: json['verificationStatus'] ?? 'Admin',
      mediaUrls: parsedMediaUrls,
      lat: double.tryParse(loc['latitude']?.toString() ?? '0.0') ?? 0.0,
      lng: double.tryParse(loc['longitude']?.toString() ?? '0.0') ?? 0.0,
      reportId: json['incidentId']?.toString() ?? '',
      reporterName: json['reporterName'] ?? 'Unknown Reporter',
      reporterStatus: json['reporterStatus'] ?? 'Unknown',
      title: json['title'] ?? 'Untitled Report',
      rescueUpdateId: parsedRescueUpdateId,
      canAcknowledge: actions['canAcknowledge'] == true,
      canUpdateStatus: actions['canUpdateStatus'] == true,
      canSubmitReport: actions['canSubmitReport'] == true,
      assignedTeams: parsedAssignedTeams,
      postIncidentReport: json['postIncidentReport']?.toString(),
      acceptedAt: json['acceptedAt']?.toString(),
      reportedAt: json['reportedAt']?.toString(),
      assignedBy: json['assignedBy']?.toString(),
      mergedReports: json['sources'] as int? ?? 1,
    );
  }
}
