import 'package:disaster360/providers/notification_provider.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/rescue/rescue_all_reports_screen.dart';
import 'package:disaster360/rescue/rescue_motion.dart';
import 'package:disaster360/rescue/rescue_profile_screen.dart';
import 'package:disaster360/rescue/rescue_disaster_detail_screen.dart';
import 'package:disaster360/rescue/rescue_tasks_screen.dart';
import 'package:disaster360/services/desktop_map_screen.dart';
import 'package:disaster360/services/notification_alert.dart';
import 'package:disaster360/services/notification_service.dart';
import 'package:disaster360/widgets/rejection_dialog.dart';
import 'package:disaster360/widgets/shared_report_card.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/core/statuses.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  RESCUE HOME SCREEN — with fixed header only on Home tab
// ═══════════════════════════════════════════════════════════════════════════════

class RescueHomeScreen extends StatefulWidget {
  const RescueHomeScreen({super.key});

  @override
  State<RescueHomeScreen> createState() => _RescueHomeScreenState();
}

class _RescueHomeScreenState extends State<RescueHomeScreen>
    with TickerProviderStateMixin {
  int _activeNav = 0; // 0: Home, 1: Map, 2: Tasks, 3: All Reports, 4: Profile

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchReports();
      context.read<RescueProvider>().fetchAll();
      NotificationService().checkAndPromptPermission(context);
    });
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _switchNav(int index) {
    if (_activeNav == index) return;
    _fadeController.reset();
    setState(() => _activeNav = index);
    _fadeController.forward();

    // Refresh data when switching to Home or Tasks
    if (index == 0 || index == 2) {
      context.read<RescueProvider>().fetchAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _Breakpoint.isDesktop(context);
    final isTablet = _Breakpoint.isTablet(context);
    final isMobile = !isDesktop && !isTablet;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
      body:
          isDesktop || isTablet
              ? Row(
                children: [
                  _SideRail(
                    activeNav: _activeNav,
                    onNavTap: _switchNav,
                    expanded: isDesktop,
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _getScreenForNav(),
                      ),
                    ),
                  ),
                ],
              )
              : FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _getScreenForNav(),
                ),
              ),
    );
  }

  Widget _getScreenForNav() {
    switch (_activeNav) {
      case 0:
        // Home screen: includes fixed header + scrollable content
        return Column(
          children: [
            SafeArea(bottom: false, child: _buildHeader()),
            Expanded(
              child: Consumer<RescueProvider>(
                builder:
                    (context, provider, _) => _RescueHomeBody(
                      onGoToTasks: () => _switchNav(2),
                      myAssignments: provider.myAssignments,
                      homeFeed: provider.homeFeed,
                      isLoading: provider.isLoading,
                    ),
              ),
            ),
          ],
        );
      case 1:
        return const DesktopMapScreen();
      case 2:
        return const RescueTasksScreen();
      case 3:
        return const RescueAllReportsScreen();
      case 4:
        return const RescueProfileScreen();
      default:
        return const SizedBox();
    }
  }

  // ── Fixed header (only shown on Home screen) ────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RESCUE DASHBOARD',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: _Breakpoint.isDesktop(context) ? 26 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Rescue Team',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Row(
            children: [

              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.success, size: 22),
                  onPressed: () {
                    final provider = context.read<RescueProvider>();
                    provider.fetchAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshing dashboard...'), duration: Duration(seconds: 1)),
                    );
                  },
                  tooltip: 'Refresh',
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom navigation with active pill background + raised effect ────────────
  Widget _buildBottomNav() {
    return Container(
      // Allow raised items to extend upward without clipping
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      // Extra top padding to give room for the raised (translateY) effect
      padding: const EdgeInsets.only(top: 9, bottom: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _AnimatedNavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isActive: _activeNav == 0,
            onTap: () => _switchNav(0),
          ),
          _AnimatedNavItem(
            icon: Icons.map_outlined,
            label: 'Map',
            isActive: _activeNav == 1,
            onTap: () => _switchNav(1),
          ),
          _AnimatedNavItem(
            icon: Icons.checklist_rounded,
            label: 'Your Tasks',
            isActive: _activeNav == 2,
            onTap: () => _switchNav(2),
          ),
          _AnimatedNavItem(
            icon: Icons.insert_drive_file_outlined,
            label: 'All Reports',
            isActive: _activeNav == 3,
            onTap: () => _switchNav(3),
          ),
          _AnimatedNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isActive: _activeNav == 4,
            onTap: () => _switchNav(4),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ANIMATED NAV ITEM (SQUARE BACKGROUND + REDUCED HEIGHT + RAISED)
// ═══════════════════════════════════════════════════════════════════════════════

class _AnimatedNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_AnimatedNavItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _bounceCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- RAISED EFFECT: translate Y up when active ---
    final translateY = widget.isActive ? -1.0 : 0.0;

    // --- ACTIVE STYLES (bigger icon/text, square background) ---
    final activeIconSize = 24.0;
    final inactiveIconSize = 18.0;
    final activeFontSize = 12.0;
    final inactiveFontSize = 10.0;

    final currentIconSize = widget.isActive ? activeIconSize : inactiveIconSize;
    final currentFontSize = widget.isActive ? activeFontSize : inactiveFontSize;

    // Square background (small radius) instead of pill
    final backgroundColor =
        widget.isActive
            ? AppColors.orange.withOpacity(0.2)
            : Colors.transparent;
    final borderColor =
        widget.isActive
            ? AppColors.orange.withOpacity(0.35)
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            // REDUCED HEIGHT: smaller vertical padding (was 8.0)
            padding: EdgeInsets.symmetric(
              horizontal:
                  widget.isActive
                      ? 16.0
                      : 10.0, // horizontal padding slightly reduced
              vertical: 4.0, // was 8.0 → now shorter height
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              // SQUARE shape (small radius, not pill)
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: borderColor,
                width: widget.isActive ? 1.2 : 0,
              ),
              boxShadow:
                  widget.isActive
                      ? [
                        BoxShadow(
                          color: AppColors.orange.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: ScaleTransition(
              scale: _bounceAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder:
                        (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      widget.icon,
                      key: ValueKey('${widget.icon}_${widget.isActive}'),
                      color:
                          widget.isActive ? AppColors.orange : Colors.white38,
                      size: currentIconSize,
                    ),
                  ),
                  // Reduced gap between icon and text (was 5.0)
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color:
                          widget.isActive ? AppColors.orange : Colors.white38,
                      fontSize: currentFontSize,
                      fontWeight:
                          widget.isActive ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════════════════════
//  HOME BODY (scrollable content, without header)
// ═══════════════════════════════════════════════════════════════════════════════

class _RescueHomeBody extends StatelessWidget {
  final VoidCallback onGoToTasks;
  final List<RescueTask> myAssignments;
  final List<ReportModel> homeFeed;
  final bool isLoading;

  const _RescueHomeBody({
    required this.onGoToTasks,
    this.myAssignments = const [],
    this.homeFeed = const [],
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Split myAssignments by status
    final assigned =
        myAssignments.where((t) => t.status == TaskStatus.active).toList();
    final inProgress =
        myAssignments.where((t) => t.status == TaskStatus.pending).toList();
    final completed =
        myAssignments.where((t) => t.status == TaskStatus.completed).toList();

    // Banner: show latest in-progress assignment
    final latestAssigned =
        myAssignments.isNotEmpty ? myAssignments.first : null;

    if (isLoading && myAssignments.isEmpty && homeFeed.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
        ),
      );
    }

    // Active Rescue Mode Check
    if (inProgress.isNotEmpty) {
      final activeTask = inProgress.first;
      return RefreshIndicator(
        color: AppColors.orange,
        backgroundColor: AppColors.bgSurface,
        onRefresh: () => context.read<RescueProvider>().fetchAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: _Breakpoint.horizontalPadding(context),
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _Breakpoint.contentMaxWidth(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActiveRescueDisasterCard(
                    task: activeTask,
                    onGoToTasks: onGoToTasks,
                  ),
                  const SizedBox(height: 40),
                  // Hide normal assignments and stats
                  const Center(
                    child: Text(
                      'You are currently responding to this disaster.\nComplete or update this operation before accepting another assignment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.5,
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

    return RefreshIndicator(
      color: AppColors.orange,
      backgroundColor: AppColors.bgSurface,
      onRefresh: () => context.read<RescueProvider>().fetchAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: _Breakpoint.horizontalPadding(context),
          vertical: 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _Breakpoint.contentMaxWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner only shows when there are assigned operations
                if (latestAssigned != null) ...[
                  _AssignedMissionBanner(
                    task: latestAssigned,
                    onTap: onGoToTasks,
                  ),
                  const SizedBox(height: 20),
                ],

                // Stats: only from MY assignments
                _buildStatCards(
                  assigned: assigned.length,
                  inProgress: inProgress.length,
                  completed: completed.length,
                ),
                const SizedBox(height: 28),

                // ── MY ASSIGNED MISSIONS ──────────────────────────────
                if (myAssignments.isEmpty)
                  _EmptyMyMissions(onGoToTasks: onGoToTasks)
                else ...[
                  if (inProgress.isNotEmpty) ...[
                    _SectionLabel('MY ACTIVE MISSIONS'),
                    const SizedBox(height: 12),
                    ...inProgress.map(
                      (t) => _MyOperationCard(
                        task: t,
                        accentColor: AppColors.warning,
                        onTap: onGoToTasks,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (completed.isNotEmpty) ...[
                    _SectionLabel('COMPLETED MISSIONS'),
                    const SizedBox(height: 12),
                    ...completed.map(
                      (t) => _MyOperationCard(
                        task: t,
                        accentColor: AppColors.success,
                        onTap: onGoToTasks,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],

                // ── ASSIGNED REPORTS FEED ───────────────
                _SectionLabel('ASSIGNED REPORTS FEED'),
                const SizedBox(height: 6),
                const Text(
                  'Incidents assigned to your team',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 14),
                if (homeFeed.isEmpty)
                  _EmptySection(
                    icon: Icons.check_circle_outline,
                    message: 'No assigned reports in queue',
                  )
                else
                  ...homeFeed.map((report) {
                    return SharedReportCard(
                      report: report,
                      isRescueMode: true,
                      onCardTap: () {
                        final provider = context.read<RescueProvider>();
                        final matchingTask = provider.myAssignments
                            .cast<RescueTask?>()
                            .firstWhere(
                              (t) => t?.reportId == report.id.toString(),
                              orElse: () => null,
                            );

                        if (matchingTask == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not find task details. Please refresh.',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => RescueDisasterDetailScreen(
                                  task: matchingTask,
                                ),
                          ),
                        ).then((_) {
                          if (context.mounted) {
                            context.read<RescueProvider>().fetchAll();
                          }
                        });
                      },
                      onAccept: () {
                        // Accept logic
                        context
                            .read<RescueProvider>()
                            .acknowledgeReport(report.id)
                            .then((msg) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              }
                            })
                            .catchError((e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            });
                      },
                      onReject: () {
                        final provider = context.read<RescueProvider>();
                        final matchingTask = provider.myAssignments
                            .cast<RescueTask?>()
                            .firstWhere(
                              (t) => t?.reportId == report.id.toString(),
                              orElse: () => null,
                            );

                        if (matchingTask == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not find task details. Please refresh.',
                              ),
                            ),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          builder:
                              (ctx) => RejectionDialog(
                                assignmentId: int.parse(
                                  matchingTask.assignmentId,
                                ),
                              ),
                        );
                      },
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards({
    required int assigned,
    required int inProgress,
    required int completed,
  }) {
    return Row(
      children: [
        _StatCard(
          value: '$assigned',
          label: 'Assigned',
          valueColor: AppColors.info,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '$inProgress',
          label: 'In Progress',
          valueColor: AppColors.warning,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '$completed',
          label: 'Completed',
          valueColor: AppColors.success,
        ),
      ],
    );
  }
}

// ─── Assigned Mission Banner ──────────────────────────────────────────────────

class _AssignedMissionBanner extends StatefulWidget {
  final VoidCallback onTap;
  final RescueTask task;
  const _AssignedMissionBanner({required this.onTap, required this.task});

  @override
  State<_AssignedMissionBanner> createState() => _AssignedMissionBannerState();
}

class _AssignedMissionBannerState extends State<_AssignedMissionBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.55),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You have an active mission',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.task.type} — ${widget.task.location}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── My Operation Card ────────────────────────────────────────────────────────

class _MyOperationCard extends StatefulWidget {
  final RescueTask task;
  final Color accentColor;
  final VoidCallback onTap;
  const _MyOperationCard({
    required this.task,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_MyOperationCard> createState() => _MyOperationCardState();
}

class _MyOperationCardState extends State<_MyOperationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        StatusTheme.getAssignmentTheme(widget.task.assignmentStatus).label;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: _hovered ? AppColors.bgDark : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      _hovered
                          ? widget.accentColor.withOpacity(0.5)
                          : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.task.location,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.accentColor.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Left accent stripe
            Positioned(
              left: 0,
              top: 0,
              bottom: 12,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Verified Report Card (global queue) ──────────────────────────────────────

class _VerifiedReportCard extends StatefulWidget {
  final RescueTask task;
  final VoidCallback onGoToTasks;
  const _VerifiedReportCard({required this.task, required this.onGoToTasks});

  @override
  State<_VerifiedReportCard> createState() => _VerifiedReportCardState();
}

class _VerifiedReportCardState extends State<_VerifiedReportCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onGoToTasks,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bgDark : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  _hovered ? AppColors.info.withOpacity(0.5) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.report_problem_outlined,
                  color: AppColors.info,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.task.location,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: const Text(
                  'Verified',
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _EmptyMyMissions extends StatelessWidget {
  final VoidCallback onGoToTasks;
  const _EmptyMyMissions({required this.onGoToTasks});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onGoToTasks,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.assignment_outlined,
              color: Colors.white24,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              'No missions assigned to you yet',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Go to Tasks to accept an incoming incident',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 18),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  RESPONSIVE LAYOUT & NAVIGATION CLASSES
// ═══════════════════════════════════════════════════════════════════════════════

class _Breakpoint {
  static bool isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;
  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600 &&
      MediaQuery.of(ctx).size.width < 1024;
  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 1024;

  static double horizontalPadding(BuildContext ctx) {
    if (isDesktop(ctx)) return MediaQuery.of(ctx).size.width * 0.12;
    if (isTablet(ctx)) return 32;
    return 16;
  }

  static double contentMaxWidth(BuildContext ctx) {
    if (isDesktop(ctx)) return 960;
    if (isTablet(ctx)) return 720;
    return double.infinity;
  }
}

class _NavData {
  final IconData icon;
  final String label;
  const _NavData(this.icon, this.label);
}

class _SideRail extends StatelessWidget {
  final int activeNav;
  final ValueChanged<int> onNavTap;
  final bool expanded;

  const _SideRail({
    required this.activeNav,
    required this.onNavTap,
    required this.expanded,
  });

  static const _items = [
    _NavData(Icons.home_rounded, 'Home'),
    _NavData(Icons.map_outlined, 'Map'),
    _NavData(Icons.checklist_rounded, 'Your Tasks'),
    _NavData(Icons.insert_drive_file_outlined, 'All Reports'),
    _NavData(Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: expanded ? 220 : 72,
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child:
                  expanded
                      ? const Text(
                        'DISASTER360',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      )
                      : const Icon(
                        Icons.shield_outlined,
                        color: AppColors.orange,
                        size: 28,
                      ),
            ),
            const SizedBox(height: 28),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            _SideRailItem(
              icon: _items[0].icon,
              label: _items[0].label,
              isActive: activeNav == 0,
              expanded: expanded,
              onTap: () => onNavTap(0),
            ),
            _SideRailItem(
              icon: _items[1].icon,
              label: _items[1].label,
              isActive: activeNav == 1,
              expanded: expanded,
              onTap: () => onNavTap(1),
            ),

            if (expanded) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: const Text(
                    'REPORTS & TASKS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Colors.white12, height: 1),
              ),
              const SizedBox(height: 16),
            ],

            _SideRailItem(
              icon: _items[2].icon,
              label: _items[2].label,
              isActive: activeNav == 2,
              expanded: expanded,
              onTap: () => onNavTap(2),
            ),
            _SideRailItem(
              icon: _items[3].icon,
              label: _items[3].label,
              isActive: activeNav == 3,
              expanded: expanded,
              onTap: () => onNavTap(3),
            ),

            if (expanded) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: const Text(
                    'ACCOUNT',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Colors.white12, height: 1),
              ),
              const SizedBox(height: 16),
            ],

            _SideRailItem(
              icon: _items[4].icon,
              label: _items[4].label,
              isActive: activeNav == 4,
              expanded: expanded,
              onTap: () => onNavTap(4),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SideRailItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool expanded;
  final VoidCallback onTap;

  const _SideRailItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<_SideRailItem> createState() => _SideRailItemState();
}

class _SideRailItemState extends State<_SideRailItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? AppColors.orange : Colors.white38;
    final bg =
        widget.isActive
            ? AppColors.bgDark
            : _hovered
            ? Colors.white.withOpacity(0.05)
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 14 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border:
                widget.isActive
                    ? Border.all(color: AppColors.border, width: 1)
                    : null,
          ),
          child: Row(
            mainAxisAlignment:
                widget.expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _hovered && !widget.isActive ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 150),
                child:
                    widget.expanded
                        ? Icon(widget.icon, color: color, size: 20)
                        : Tooltip(
                          message: widget.label,
                          preferBelow: false,
                          child: Icon(widget.icon, color: color, size: 20),
                        ),
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: color,
                    fontSize: _hovered && !widget.isActive ? 13.5 : 13,
                    fontWeight:
                        widget.isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════════════════════
//  SUPPORTING WIDGETS (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRescueDisasterCard extends StatefulWidget {
  final RescueTask task;
  final VoidCallback onGoToTasks;
  const _ActiveRescueDisasterCard({
    required this.task,
    required this.onGoToTasks,
  });

  @override
  State<_ActiveRescueDisasterCard> createState() => _ActiveRescueDisasterCardState();
}

class _ActiveRescueDisasterCardState extends State<_ActiveRescueDisasterCard> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_turned_in, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'ACTIVE OPERATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.task.assignmentStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.type,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.task.location,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCol(
                        'Severity',
                        'Level ${widget.task.severityLevel}',
                        AppColors.danger,
                      ),
                      _buildInfoCol(
                        'Time assigned',
                        widget.task.assignedAgo,
                        Colors.white70,
                      ),
                      _buildInfoCol('Reporter', widget.task.reporterName, Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => RescueDisasterDetailScreen(task: widget.task),
                        ),
                      ).then((_) {
                        if (context.mounted) {
                          context.read<RescueProvider>().fetchAll();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bgDark,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OPEN OPERATION DETAILS',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.task.assignmentStatus.toLowerCase() == 'accepted' ||
                    widget.task.assignmentStatus.toLowerCase() == 'in progress')
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : () async {
                        setState(() { _isUpdating = true; });
                        final nextStatus =
                            widget.task.assignmentStatus.toLowerCase() == 'accepted'
                                ? 'In Progress'
                                : 'Completed';
                        try {
                          await context
                              .read<RescueProvider>()
                              .updateOperationStatus(
                                int.parse(widget.task.assignmentId),
                                nextStatus,
                              );
                          if (context.mounted) {
                            try {
                              final rProv = context.read<ReportProvider>();
                              rProv.fetchReports();
                              rProv.fetchActiveRescues();
                              rProv.fetchCompletedOperations();
                            } catch (_) {}
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Task marked as $nextStatus!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update task: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() { _isUpdating = false; });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.task.assignmentStatus.toLowerCase() == 'accepted' 
                            ? AppColors.primary 
                            : AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isUpdating 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : Text(
                            widget.task.assignmentStatus.toLowerCase() == 'accepted'
                                ? 'START OPERATION'
                                : 'MARK AS COMPLETED',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
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

  Widget _buildInfoCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toUpperCase(),
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
