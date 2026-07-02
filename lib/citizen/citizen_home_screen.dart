import 'package:disaster360/widgets/shared_report_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/providers/auth_provider.dart';
import 'package:disaster360/citizen/citizen_profile_screen.dart';
import 'package:disaster360/citizen/citizen_my_reports.dart';
import 'package:disaster360/services/map_screen.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/services/fab_add_report.dart';
import 'package:disaster360/services/notification_alert.dart';
import 'package:disaster360/services/notification_service.dart';
import 'package:disaster360/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/citizen/citizen_report_detail_screen.dart';
import 'package:disaster360/utils/status_helper.dart';
import 'package:disaster360/widgets/pressable_widget.dart';

class AlertData {
  final String title;
  final String date;
  final String location;
  final String status;
  final Color dotColor;
  final String reportId;
  final String description;
  final String lat;
  final String lng;
  final String reporter;
  final int upvotes;
  final int downvotes;
  final int photos;
  final String type;
  final String currentStatus;

  const AlertData({
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.dotColor,
    required this.reportId,
    required this.description,
    required this.lat,
    required this.lng,
    required this.reporter,
    required this.upvotes,
    required this.downvotes,
    required this.photos,
    required this.type,
    required this.currentStatus,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

class ReportModelMock {
  final String title;
  final String date;
  final String location;
  final String status;
  final Color dotColor;
  final String reportId;
  final String description;
  final String lat;
  final String lng;
  final String reporter;
  final int upvotes;
  final int downvotes;
  final int photos;
  final String type;
  final String currentStatus;

  const ReportModelMock({
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.dotColor,
    required this.reportId,
    required this.description,
    required this.lat,
    required this.lng,
    required this.reporter,
    required this.upvotes,
    required this.downvotes,
    required this.photos,
    required this.type,
    required this.currentStatus,
  });
}

/// Mutable wrapper for each card — upvotes/downvotes change on tap


class _NavData {
  final IconData icon;
  final String label;
  const _NavData(this.icon, this.label);
}

// ══════════════════════════════════════════════════════════════════════════════
//  SORT ORDER FOR STATUS
// ══════════════════════════════════════════════════════════════════════════════

int _statusSortOrder(String status) {
  final s = status.toLowerCase();
  if (s == 'pending') return 0;
  if (s == 'verified') return 1;
  if (s == 'assigned') return 2;
  if (s == 'acknowledged') return 3;
  if (s.contains('progress')) return 4;
  if (s.contains('resolved') || s.contains('controlled')) return 5;
  if (s == 'rejected') return 6;
  return 7;
}

// ══════════════════════════════════════════════════════════════════════════════
//  CITIZEN HOME SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  String _selectedHomeFilter = 'All';
  final List<String> _homeFilters = [
    'All',
    'My Reports',
    'Pending',
    'On Rescue',
    'Verified',
    'Fire',
    'Landslide',
    'Road Blockage',
    'Flood',
    'Earthquake',
  ];

  String _selectedSortOption = 'Date';
  final List<String> _sortOptions = ['Date', 'Severity', 'Most Reported'];

  int _activeNav = 0;
  final Map<int, GlobalKey> _cardKeys = {};
  final ScrollController _scrollController = ScrollController();

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchReports();
      NotificationService().checkAndPromptPermission(context);
    });
    context.read<ReportProvider>().addListener(_onReportProviderChanged);
  }

  @override
  void dispose() {
    // Note: Since this is often a root widget, we usually don't unmount, but good practice
    // if it were to be disposed.
    _scrollController.dispose();
    super.dispose();
  }

  void _onReportProviderChanged() {
    if (!mounted) return;
    final reportProvider = context.read<ReportProvider>();
    final targetId = reportProvider.highlightedReportId;
    
    if (targetId != null) {
      if (_activeNav != 0) {
        setState(() => _activeNav = 0);
      }
      if (_selectedHomeFilter != 'All') {
        setState(() => _selectedHomeFilter = 'All');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _cardKeys[targetId];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: IndexedStack(
        index: _activeNav,
        children: [
          _buildHomeTab(),
          const CitizenMyReportsScreen(),
          const DisasterMapScreen(),
          const CitizenProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton(
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportDisasterScreen()),
              ),
          backgroundColor: AppColors.orange,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        SafeArea(bottom: false, child: _buildHeader()),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.orange,
            backgroundColor: AppColors.bgSurface,
            onRefresh: () async {
              await context.read<ReportProvider>().fetchReports();
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatCards(),
                  const SizedBox(height: 28),
                  _buildFilterAndSortButtons(context),
                  _buildReportCardsSection(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── FIXED HEADER (only shown on Home screen) ─────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (_activeNav == 0) _scrollToTop();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                'DISASTER360',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Namaste, ${context.watch<AuthProvider>().user?.fullName ?? 'Citizen'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          ),
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
            child: Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                Consumer<NotificationProvider>(
                  builder: (context, provider, _) {
                    if (provider.unreadCount == 0) return const SizedBox.shrink();
                    return Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STAT CARDS ──────────────────────────────────────────────────────────────
  Widget _buildStatCards() {
    final reports = context.watch<ReportProvider>().reports;
    final pending =
        reports.where((r) => r.status.toLowerCase().contains('pending')).length;
    final inProgress =
        reports
            .where((r) => r.status.toLowerCase().contains('progress'))
            .length;
    final controlled =
        reports
            .where(
              (r) =>
                  r.status.toLowerCase().contains('controlled') ||
                  r.status.toLowerCase().contains('verified'),
            )
            .length;
    return Row(
      children: [
        _StatCard(
          value: '$pending',
          label: 'Pending',
          valueColor: AppColors.warning,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '$inProgress',
          label: 'In Progress',
          valueColor: AppColors.orange,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '$controlled',
          label: 'Controlled',
          valueColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildFilterAndSortButtons(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: PressableWidget(
              onTap: () => _showFilterBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_list_rounded,
                          color: AppColors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedHomeFilter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PressableWidget(
              onTap: () => _showSortBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sort_rounded,
                            color: AppColors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedSortOption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 18,
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

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 24,
            left: 20,
            right: 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort By',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sortOptions.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (ctx, index) {
                    final option = _sortOptions[index];
                    final isSelected = option == _selectedSortOption;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? AppColors.orange : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.check_circle,
                                color: AppColors.orange,
                                size: 22,
                              )
                              : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedSortOption = option);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 24,
            left: 20,
            right: 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Filter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _homeFilters.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (ctx, index) {
                    final filter = _homeFilters[index];
                    final isSelected = filter == _selectedHomeFilter;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? AppColors.orange : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.check_circle,
                                color: AppColors.orange,
                                size: 22,
                              )
                              : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedHomeFilter = filter);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── REPORT CARDS SECTION ────────────────────────────────────────────────────

  List<ReportModel> _getFilteredReports(BuildContext context) {
    final all = context.watch<ReportProvider>().reports;
    List<ReportModel> filtered = [];

    if (_selectedHomeFilter == 'All') {
      filtered = List.from(all);
    } else if (_selectedHomeFilter == 'My Reports') {
      final auth = context.read<AuthProvider>();
      filtered = all.where((r) => r.userId == auth.user?.id).toList();
    } else if ([
      'Pending',
      'On Rescue',
      'Verified',
    ].contains(_selectedHomeFilter)) {
      if (_selectedHomeFilter == 'On Rescue') {
        filtered =
            all
                .where((r) => r.status.toLowerCase().contains('progress'))
                .toList();
      } else {
        filtered = all.where((r) => r.status == _selectedHomeFilter).toList();
      }
    } else {
      // Type filters
      filtered =
          all.where((r) => r.disasterType == _selectedHomeFilter).toList();
    }

    // Sort rules
    if (_selectedSortOption == 'Severity') {
      filtered.sort(
        (a, b) => _getSeverityScore(
          b.severity,
        ).compareTo(_getSeverityScore(a.severity)),
      );
    } else if (_selectedSortOption == 'Most Reported') {
      filtered.sort(
        (a, b) => b.submissions.length.compareTo(a.submissions.length),
      );
    } else {
      // Default: Date (Recent to oldest)
      filtered.sort((a, b) {
        DateTime dateA =
            DateTime.tryParse(a.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB =
            DateTime.tryParse(b.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    }

    return filtered;
  }

  int _getSeverityScore(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  Widget _buildReportCardsSection(BuildContext context) {
    final reports = _getFilteredReports(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedSortOption == 'Most Reported'
              ? 'HOT REPORTS'
              : 'RECENT REPORTS',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 12),
        ...reports.map((report) {
          return SharedReportCard(
            key: ValueKey(report.id.toString()),
            report: report,
            animationDelay: Duration(
              milliseconds: 60 * reports.indexOf(report),
            ),
            onUpvote:
                () => context.read<ReportProvider>().reactToReport(
                  report.id,
                  'LIKE',
                ),
            onDownvote:
                () => context.read<ReportProvider>().reactToReport(
                  report.id,
                  'DISLIKE',
                ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── BOTTOM NAV ──────────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    final items = [
      _NavData(Icons.home_rounded, 'Home'),
      _NavData(Icons.warning_amber_rounded, 'Reports'),
      _NavData(Icons.map_outlined, 'Map'),
      _NavData(Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          return _AnimatedNavItem(
            icon: items[i].icon,
            label: items[i].label,
            isActive: _activeNav == i,
            onTap: () {
              if (_activeNav == i && i == 0) {
                _scrollToTop();
              } else {
                setState(() => _activeNav = i);
              }
            },
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ANIMATED NAV ITEM
// ══════════════════════════════════════════════════════════════════════════════

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
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: widget.isActive ? 76 : 56,
        height: 54,
        decoration: BoxDecoration(
          color:
              widget.isActive
                  ? AppColors.orange.withOpacity(0.15)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border:
              widget.isActive
                  ? Border.all(
                    color: AppColors.orange.withOpacity(0.25),
                    width: 1,
                  )
                  : null,
        ),
        child: ScaleTransition(
          scale: _bounceAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder:
                    (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  widget.icon,
                  key: ValueKey('${widget.icon}_${widget.isActive}'),
                  color: widget.isActive ? AppColors.orange : Colors.white38,
                  size: widget.isActive ? 24 : 22,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isActive ? AppColors.orange : Colors.white38,
                  fontSize: widget.isActive ? 10.5 : 10,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  STAT CARD
// ══════════════════════════════════════════════════════════════════════════════

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
      child: PressableWidget(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
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
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
