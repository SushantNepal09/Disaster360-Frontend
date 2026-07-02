import 'package:disaster360/admin/admin_report_details.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/widgets/image_viewer_overlay.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/citizen/citizen_home_screen.dart';
import 'package:disaster360/admin/admin_completed_report_details.dart';

// ─── Max content width — centers everything on ultra-wide screens ─────────────
const double _kMaxContentWidth = 1320.0;

class AdminCompletedOperationsScreen extends StatefulWidget {
  const AdminCompletedOperationsScreen({super.key});

  @override
  State<AdminCompletedOperationsScreen> createState() => _AdminCompletedOperationsScreenState();
}

class _AdminCompletedOperationsScreenState extends State<AdminCompletedOperationsScreen>
    with SingleTickerProviderStateMixin {
  String _activeFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<String> _filters = ['All', 'Pending', 'Verified', 'Closed'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchCompletedOperations();
    });
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entryController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredReports {
    final reportProvider = context.watch<ReportProvider>();
    final allOperations = reportProvider.completedOperations;

    return allOperations.where((op) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          (op['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (op['incident_id']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (op['location']?['address']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch;
    }).toList();
  }

  // Breakpoints: mobile < 680  |  tablet 680-1099  |  desktop >= 1100
  int _cols(double w) {
    if (w >= 1100) return 3;
    if (w >= 680) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.of(context).size.width;
    final int cols = _cols(screenW);
    final double hPad = cols == 1 ? 16.0 : 24.0;

    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header centered within max content width
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kMaxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Completed Operations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AnimatedSearchBar(
                          controller: _searchController,
                          onChanged:
                              (val) => setState(() => _searchQuery = val),
                        ),
                        const SizedBox(height: 14),
                        // Removed filter chips
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // Body
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.orange,
                  backgroundColor: AppColors.bgSurface,
                  onRefresh:
                      () => context.read<ReportProvider>().fetchReports(),
                  child:
                      _filteredReports.isEmpty
                          ? const SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: 300,
                              child: Center(
                                child: Text(
                                  'No reports found.',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          )
                          : _ReportBody(
                            reports: _filteredReports,
                            cols: cols,
                            hPad: hPad,
                            onTap: _navigateToDetail,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> report) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (_, animation, __) => AdminCompletedReportDetailScreen(report: report),
        transitionsBuilder:
            (_, animation, __, child) => FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }
}

// ─── Report Body ──────────────────────────────────────────────────────────────
// Owns scrolling + explicit width calculation.
// Using LayoutBuilder gives us a guaranteed finite maxWidth so every card
// child gets a real pixel width — root fix for all unbounded-width overflows.
class _ReportBody extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final int cols;
  final double hPad;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _ReportBody({
    required this.reports,
    required this.cols,
    required this.hPad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cols == 1) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder:
            (_, i) => _StaggeredCard(
              index: i,
              child: _AdminReportCard(
                report: reports[i],
                onTap: () => onTap(reports[i]),
              ),
            ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap to max content width for ultra-wide centering
        final double availW = constraints.maxWidth.clamp(
          0.0,
          _kMaxContentWidth,
        );
        const double gap = 14.0;
        final double innerW = availW - hPad * 2;
        // Explicit per-card width — eliminates unbounded-width RenderFlex errors
        final double cardW = (innerW - gap * (cols - 1)) / cols;
        final double extraPad = ((constraints.maxWidth - availW) / 2).clamp(
          0.0,
          double.infinity,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad + extraPad, 0, hPad + extraPad, 24),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: List.generate(
              reports.length,
              (i) => SizedBox(
                width: cardW,
                child: _StaggeredCard(
                  index: i,
                  child: _AdminReportCard(
                    report: reports[i],
                    onTap: () => onTap(reports[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Staggered Card Wrapper ───────────────────────────────────────────────────
class _StaggeredCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredCard({required this.index, required this.child});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 300));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ─── Animated Search Bar ──────────────────────────────────────────────────────
class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _AnimatedSearchBar({required this.controller, required this.onChanged});

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _focused ? AppColors.orange.withOpacity(0.7) : AppColors.border,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow:
            _focused
                ? [
                  BoxShadow(
                    color: AppColors.orange.withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
                : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.search_rounded,
              key: ValueKey(_focused),
              color: _focused ? AppColors.orange : Colors.white38,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onFocusChange: (v) => setState(() => _focused = v),
              child: TextField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search reports...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chip Row ──────────────────────────────────────────────────────────
class _FilterChipRow extends StatelessWidget {
  final List<String> filters;
  final String activeFilter;
  final ValueChanged<String> onSelect;

  const _FilterChipRow({
    required this.filters,
    required this.activeFilter,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            filters
                .map(
                  (f) => _AnimatedFilterChip(
                    label: f,
                    isActive: activeFilter == f,
                    onTap: () => onSelect(f),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _AnimatedFilterChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _AnimatedFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_AnimatedFilterChip> createState() => _AnimatedFilterChipState();
}

class _AnimatedFilterChipState extends State<_AnimatedFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color:
                widget.isActive
                    ? AppColors.orange
                    : _hovered
                    ? AppColors.orange.withOpacity(0.12)
                    : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  widget.isActive
                      ? AppColors.orange
                      : _hovered
                      ? AppColors.orange.withOpacity(0.4)
                      : AppColors.border,
              width: 1,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              color:
                  widget.isActive
                      ? Colors.white
                      : _hovered
                      ? AppColors.orange
                      : Colors.white54,
              fontSize: _hovered && !widget.isActive ? 13.5 : 13,
              fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w400,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

// ─── Admin Report Card ────────────────────────────────────────────────────────
class _AdminReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;
  const _AdminReportCard({required this.report, required this.onTap});

  @override
  State<_AdminReportCard> createState() => _AdminReportCardState();
}

class _AdminReportCardState extends State<_AdminReportCard> {
  bool _hovered = false;

  void _onReview() => Navigator.push(
    context,
    _pageRoute(AdminCompletedReportDetailScreen(report: widget.report)),
  );

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
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        ];
        return '${monthNames[dt.month - 1]} ${dt.day}';
      } else {
        const monthNames = [
          "Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        ];
        return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }

  PageRoute _pageRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder:
        (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
    transitionDuration: const Duration(milliseconds: 300),
  );

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              _hovered
                  ? AppColors.bgSurface.withOpacity(0.92)
                  : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _hovered
                    ? AppColors.orange.withOpacity(0.35)
                    : AppColors.border,
            width: 1,
          ),
          boxShadow:
              _hovered
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '#${report['incident_id']}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                _StatusBadge(status: 'Completed'),
                const Spacer(),
                Flexible(
                  child: Text(
                    report['created_at'] != null ? _relativeDate(report['created_at'].toString()) : '',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              (report['disaster_type'] ?? 'Unknown').toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),

            Text(
              (report['location']?['address'] ?? 'Unknown Location').toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 8),

            Text(
              (report['description'] ?? 'No description provided').toString(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    label: 'Review Final Report',
                    icon: Icons.remove_red_eye_outlined,
                    color: Colors.white60,
                    filled: false,
                    onTap: _onReview,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Image Placeholder Row ────────────────────────────────────────────────────
// 140px height = passport-photo visible size, clearly readable at a glance.
// Up to 3 tiles. If photoCount > 3, last tile shows "+N more" overlay.
// 1.5px border visible on every tile as requested.


// ─── Status Banner ────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Action Button ───────────────────────────────────────────────────────
class _CardActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  final bool fullWidth;

  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  State<_CardActionButton> createState() => _CardActionButtonState();
}

class _CardActionButtonState extends State<_CardActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _pressed ? 0.96 : (_hovered ? 1.02 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 130),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.fullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color:
                  widget.filled
                      ? widget.color.withOpacity(_hovered ? 0.28 : 0.18)
                      : _hovered
                      ? widget.color.withOpacity(0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    widget.filled
                        ? widget.color.withOpacity(_hovered ? 0.7 : 0.5)
                        : _hovered
                        ? widget.color.withOpacity(0.5)
                        : AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.color, size: 13),
                const SizedBox(width: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: TextStyle(
                    color: widget.color,
                    fontSize: _hovered ? 12.5 : 12,
                    fontWeight: FontWeight.w600,
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

// ─── Status Badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    switch (status) {
      case 'In Progress':
        bg = AppColors.orange.withOpacity(0.18);
        text = AppColors.orange;
        break;
      case 'Verified':
      case 'Controlled':
        bg = AppColors.success.withOpacity(0.15);
        text = AppColors.success;
        break;
      case 'Closed':
        bg = AppColors.info.withOpacity(0.15);
        text = AppColors.info;
        break;
      case 'Rejected':
        bg = AppColors.danger.withOpacity(0.15);
        text = AppColors.danger;
        break;
      default:
        bg = AppColors.warning.withOpacity(0.15);
        text = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: text.withOpacity(0.4), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// you as a professonal forntend developer and best coder give me 3 sized responsive screens ....1 its alredy in mobile screen responsive, anothe is tablet and last is desktop form....it must be responsive and overflow error free....and .image must be double of passport size photo (which asked when we fill form in goverment sectors)   in that report if image is clicked show it in full screen form...... ....and button , links , cards etc must be in basic animation and transition and hand hoverd cursor .....clean and managed
