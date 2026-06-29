import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/rescue/rescue_disaster_report.dart';
import 'package:disaster360/rescue/rescue_mark_controlled.dart';
import 'package:disaster360/rescue/rescue_motion.dart';

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

  List<RescueTask> _filteredTasks(List<RescueTask> allTasks) {
    List<RescueTask> list;

    if (_selectedFilter == 'All') {
      final active =
          allTasks.where((t) => t.status == TaskStatus.active).toList();
      final pending =
          allTasks.where((t) => t.status == TaskStatus.pending).toList();
      final completed =
          allTasks.where((t) => t.status == TaskStatus.completed).toList();
      list = [...active, ...pending, ...completed];
    } else {
      final statusMap = {
        'Active': TaskStatus.active,
        'Pending': TaskStatus.pending,
        'Completed': TaskStatus.completed,
      };
      list =
          allTasks
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
        final allTasks = provider.allTasks;
        final filtered = _filteredTasks(allTasks);

        Widget content = Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Column(
            children: [
              _buildStickyTopBar(),
              Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: provider.isLoading && allTasks.isEmpty
                              ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                              : RefreshIndicator(
                                  color: AppColors.orange,
                                  backgroundColor: const Color(0xFF1F1F1F),
                                  onRefresh: () => provider.fetchAll(),
                                  child: CustomScrollView(
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                          child: _buildFilterTabs(),
                                        ),
                                      ),
                                      if (filtered.isEmpty)
                                        SliverFillRemaining(
                                          child: _buildEmptyState(),
                                        )
                                      else
                                        SliverList(
                                          delegate: SliverChildBuilderDelegate(
                                            (context, i) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                child: _FacebookReportCard(
                                                  task: filtered[i],
                                                  onAccept: () => _handleAccept(context, filtered[i]),
                                                  onDetails: () => _handleDetails(context, filtered[i]),
                                                ),
                                              );
                                            },
                                            childCount: filtered.length,
                                          ),
                                        ),
                                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              )
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
        children: _filters.map((filter) {
          final isActive = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? Colors.white : const Color(0x0FFFFFFF)),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white54,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
          Text('No tasks available', style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }

  // ── Button handlers ────────────────────────────────────────────────────────
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
          await provider.acknowledgeReport(int.parse(task.taskId));
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
    _showTaskDetailSheet(context, task);
  }

  void _handleStatusReport(BuildContext context, RescueTask task) {
    _showStatusReportSheet(context, task);
  }

  void _handleMarkDone(BuildContext context, RescueTask task) {
    RescueMotion.push(context, MarkAsControlledScreen(task: task)).then((_) {
      // Refresh tasks after returning from mark controlled screen
      if (context.mounted) context.read<RescueProvider>().fetchMyOperations();
    });
  }

  void _handleCompletionReport(BuildContext context, RescueTask task) {
    RescueMotion.push(context, PostDisasterReportScreen(preSelectedTask: task));
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

  void _showTaskDetailSheet(BuildContext context, RescueTask task) {
    RescueMotion.showSweetBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.92,
            minChildSize: 0.4,
            builder:
                (_, ctrl) => Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _sheetHandle()),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '#${task.taskId}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          _TaskStatusBadge(status: task.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${task.type} — ${task.location}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.description,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          controller: ctrl,
                          children: [
                            _DetailRow(
                              icon: Icons.local_fire_department_outlined,
                              label: 'Severity',
                              widget: _SeverityBadge(level: task.severityLevel),
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.verified_user_outlined,
                              label: 'Verified by Admin',
                              value: task.verifiedByAdmin,
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.location_on_outlined,
                              label: 'GPS',
                              value: '${task.lat}, ${task.lng}',
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.report_outlined,
                              label: 'Report ID',
                              value: '#${task.reportId}',
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.image_outlined,
                              label: 'Photos',
                              value: '${task.mediaUrls.length} attached',
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              icon: Icons.access_time_outlined,
                              label: 'Assigned',
                              value: task.assignedAgo,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
  final VoidCallback onDetails;

  const _FacebookReportCard({
    required this.task,
    required this.onAccept,
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
                  child: const Icon(Icons.person, color: AppColors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Citizen Reporter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          _TaskStatusBadge(status: task.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(task.assignedAgo, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white54),
                  onPressed: onDetails, // Map details to more_horiz
                )
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
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.type,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _SeverityBadge(level: task.severityLevel),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(task.location, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.description,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Photo Gallery
          if (task.mediaUrls.isNotEmpty)
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
                if (task.status == TaskStatus.active)
                  ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                    label: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.white70),
                    label: const Text('View Details', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x0FFFFFFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  const _FacebookPhotoGallery({required this.mediaUrls, required this.reportId});

  void _open(BuildContext context, int index) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => _ImageViewerOverlay(
        mediaUrls: mediaUrls,
        initialIndex: index,
        reportId: reportId,
      ),
    );
  }

  Widget _buildImage(BuildContext context, int index, {BoxFit fit = BoxFit.cover}) {
    return GestureDetector(
      onTap: () => _open(context, index),
      child: Image.network(
        mediaUrls[index],
        fit: fit,
        errorBuilder: (_, __, ___) => Container(color: Colors.white12, child: const Icon(Icons.broken_image, color: Colors.white38)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = mediaUrls.length;
    if (count == 0) return const SizedBox.shrink();

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
                                child: Text('+${count - 4}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
  final TaskStatus status;
  const _TaskStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, text;
    String label;
    switch (status) {
      case TaskStatus.active:
        bg = AppColors.info.withOpacity(0.18);
        text = AppColors.info;
        label = 'Active';
        break;
      case TaskStatus.pending:
        bg = AppColors.orange.withOpacity(0.15);
        text = AppColors.orange;
        label = 'Pending';
        break;
      case TaskStatus.completed:
        bg = AppColors.success.withOpacity(0.15);
        text = AppColors.success;
        label = 'Completed';
        break;
    }
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
            'L$level ┬╖ ${_labels[level]}',
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
  final String taskId;
  final TaskStatus status;
  final String type;
  final String location;
  final String description;
  final String assignedAgo;
  final int severityLevel;
  final String verifiedByAdmin;
  final List<String> mediaUrls;
  final String lat;
  final String lng;
  final String reportId;
  // For operations that have been acknowledged — used for status updates
  final int? rescueUpdateId;
  final List<String> assignedTeams;

  const RescueTask({
    required this.taskId,
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
    this.rescueUpdateId,
    this.assignedTeams = const [],
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

  // ── Build from GET /rescue/verified-reports item ──────────────────────────
  // These are verified incidents NOT yet acknowledged by this member
  factory RescueTask.fromJson(Map<String, dynamic> json) {
    return RescueTask(
      taskId: '${json['id']}',
      status: TaskStatus.active,
      type: json['disaster_type'] ?? 'Unknown',
      location: json['location'] ?? 'Unknown',
      description: json['description'] ?? '',
      assignedAgo: _timeAgo(json['created_at']?.toString()),
      severityLevel: _parseSeverity(json['severity']?.toString()),
      verifiedByAdmin: 'Admin',
      mediaUrls: (json['media_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      lat: '${json['latitude'] ?? 0.0}',
      lng: '${json['longitude'] ?? 0.0}',
      reportId: '${json['id']}',
      rescueUpdateId: json['rescue_update_id'] as int?,
      assignedTeams:
          (json['assigned_teams'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  // ── Build from GET /rescue/my-operations item ─────────────────────────────
  // These are incidents this member has acknowledged (pending / completed)
  factory RescueTask.fromMyOperation(Map<String, dynamic> json) {
    final rescueStatus = json['rescue_status'] ?? 'Acknowledged';
    TaskStatus status;
    if (rescueStatus == 'Controlled' || rescueStatus == 'Closed') {
      status = TaskStatus.completed;
    } else {
      status = TaskStatus.pending;
    }

    return RescueTask(
      taskId: '${json['incident_id']}',
      status: status,
      type: json['disaster_type'] ?? 'Unknown',
      location: json['location'] ?? 'Unknown',
      description: json['description'] ?? '',
      assignedAgo: _timeAgo(json['acknowledged_at']?.toString()),
      severityLevel: _parseSeverity(json['severity']?.toString()),
      verifiedByAdmin: 'Admin',
      mediaUrls: (json['media_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      lat: '${json['latitude'] ?? 0.0}',
      lng: '${json['longitude'] ?? 0.0}',
      reportId: '${json['incident_id']}',
      rescueUpdateId: json['rescue_update_id'] as int?,
      assignedTeams:
          const [], // my-operations doesn't need assignedTeams as they are already accepted
    );
  }
}
