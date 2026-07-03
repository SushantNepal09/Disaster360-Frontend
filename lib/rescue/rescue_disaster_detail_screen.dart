import 'package:disaster360/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:disaster360/rescue/widgets/live_update_form_sheet.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disaster360/widgets/image_viewer_overlay.dart';
import 'package:disaster360/models/rescue_timeline_event.dart';
import 'package:disaster360/services/rescue_service.dart';
import 'package:disaster360/citizen/citizen_home_screen.dart';
import 'package:disaster360/rescue/rescue_tasks_screen.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/widgets/rejection_dialog.dart';

// ─── Data Model ───────────────────────────────────────────────────────────────

// ─── Breakpoints ──────────────────────────────────────────────────────────────

class _BP {
  static bool isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;
  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600 &&
      MediaQuery.of(ctx).size.width < 1024;
  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 1024;
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class RescueDisasterDetailScreen extends StatefulWidget {
  final RescueTask task;
  final String initialDecisionState;

  const RescueDisasterDetailScreen({
    super.key,
    required this.task,
    this.initialDecisionState = 'pending',
  });

  @override
  State<RescueDisasterDetailScreen> createState() =>
      _RescueDisasterDetailScreenState();
}

class _RescueDisasterDetailScreenState extends State<RescueDisasterDetailScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _cardController;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  late AnimationController _decisionController;
  late Animation<double> _decisionFade;
  late Animation<Offset> _decisionSlide;

  @override
  void initState() {
    super.initState();

    // Card entrance animation
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _cardFade = CurvedAnimation(parent: _cardController, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOut));

    // Decision area animation
    _decisionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _decisionFade = CurvedAnimation(
      parent: _decisionController,
      curve: Curves.easeOut,
    );
    _decisionSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _decisionController, curve: Curves.easeOut),
    );

    _cardController.forward();
    _decisionController.forward();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_BP.isDesktop(context)) return _buildDesktopLayout();
          if (_BP.isTablet(context)) return _buildTabletLayout();
          return _buildMobileLayout();
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      leading: _AnimatedIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Navigator.pop(context),
      ),
      title: Text(
        widget.task.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _StatusBadge(status: widget.task.status.name),
        ),
      ],
    );
  }

  // ─── Accordion State ────────────────────────────────────────────────────────
  
  Map<String, bool> _expandedSections = {
    'Disaster Information': true,
    'Location': true,
    'Disaster Status': true,
    'Rescue Timeline': true,
    'Operation Updates': true,
    'Operation Notes': false,
    'Resources Used': false,
    'Post-Incident Report': false,
  };

  final TextEditingController _timelineUpdateController = TextEditingController();

  @override
  void dispose() {
    _timelineUpdateController.dispose();
    super.dispose();
  }

  void _toggleSection(String title) {
    setState(() {
      _expandedSections[title] = !(_expandedSections[title] ?? false);
    });
  }

  // ─── Reusable Widgets ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon, {bool isExpanded = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordion(String title, IconData icon, Widget child) {
    final isExpanded = _expandedSections[title] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title, icon, isExpanded: isExpanded, onTap: () => _toggleSection(title)),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
        ],
      ),
    );
  }

  // ─── Section 1: Active Disaster Header ──────────────────────────────────────

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: AppColors.danger.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppColors.danger, size: 10),
                const SizedBox(width: 8),
                const Text(
                  '🚨 ACTIVE DISASTER',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
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
                // Type Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    widget.task.type.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  widget.task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Rajdhani',
                  ),
                ),
                const SizedBox(height: 16),
                // Severity and Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.task.severityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: widget.task.severityColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        widget.task.formattedSeverity,
                        style: TextStyle(color: widget.task.severityColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.task.statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: widget.task.statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        widget.task.formattedStatus,
                        style: TextStyle(color: widget.task.statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 2x2 Grid
                Row(
                  children: [
                    Expanded(child: _buildGridItem('ACCEPTED', RescueTask.formatDateTime(widget.task.acceptedAt), Icons.check_circle_outline)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGridItem('REPORTED', RescueTask.formatDateTime(widget.task.reportedAt), Icons.access_time)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildGridItem('ASSIGNED BY', widget.task.assignedBy ?? 'System', Icons.person_outline)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGridItem('INCIDENT ID', widget.task.taskId, Icons.tag)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section 2: Disaster Information ────────────────────────────────────────

  Widget _buildDisasterInformation() {
    return _buildAccordion(
      'Disaster Information',
      Icons.info_outline_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.task.description.isEmpty ? 'No description provided.' : widget.task.description,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Reporter', widget.task.reporterName),
          const SizedBox(height: 12),
          _buildInfoRow('Merged Reports', '${widget.task.mergedReports} reports'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Section 3: Location ────────────────────────────────────────────────────

  Widget _buildLocation() {
    return _buildAccordion(
      'Location',
      Icons.location_on_outlined,
      Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.location.isEmpty ? 'Location Unknown' : widget.task.location,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${widget.task.lat.toStringAsFixed(4)}    Lng: ${widget.task.lng.toStringAsFixed(4)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  Icons.open_in_new, 
                  'Google Maps', 
                  AppColors.primary,
                  onTap: () async {
                    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${widget.task.lat},${widget.task.lng}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  Icons.navigation, 
                  'Navigate', 
                  AppColors.success,
                  onTap: () async {
                    final uri = Uri.parse('google.navigation:q=${widget.task.lat},${widget.task.lng}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      final fallbackUri = Uri.parse('geo:${widget.task.lat},${widget.task.lng}?q=${widget.task.lat},${widget.task.lng}');
                      if (await canLaunchUrl(fallbackUri)) {
                        await launchUrl(fallbackUri);
                      }
                    }
                  }
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  Icons.copy, 
                  'Copy Coords', 
                  AppColors.warning,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '${widget.task.lat}, ${widget.task.lng}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coordinates copied to clipboard')),
                    );
                  }
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── Section 5: Rescue Timeline ─────────────────────────────────────────────

  Widget _buildRescueTimeline() {
    return _buildAccordion(
      'Rescue Timeline',
      Icons.access_time_filled_rounded,
      FutureBuilder<List<Map<String, dynamic>>>(
        future: RescueService().getTimelineEvents(int.parse(widget.task.taskId)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ));
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Failed to load timeline.', style: TextStyle(color: Colors.white54)),
            );
          }
          
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No timeline events yet.', style: TextStyle(color: Colors.white54)),
            );
          }

          final events = data.map((e) => RescueTimelineEvent.fromJson(e)).toList();

          return Column(
            children: [
              ...List.generate(events.length, (i) {
                final isLast = i == events.length - 1;
                final event = events[i];
                
                Color color;
                if (event.eventType == 'SYSTEM') {
                  color = AppColors.info;
                } else {
                  color = AppColors.primary;
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                border: Border.all(color: color, width: 2),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        color, 
                                        (i + 1 < events.length && events[i+1].eventType == 'SYSTEM') ? AppColors.info : AppColors.primary
                                      ],
                                    ),
                                  ),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                RescueTask.formatDateTime(event.createdAt),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                event.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (event.description != null && event.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  event.description!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (event.teamName != null && event.teamName!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "By ${event.teamName}",
                                  style: TextStyle(
                                    color: color.withOpacity(0.8),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (widget.task.status == TaskStatus.pending) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _timelineUpdateController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add manual update (e.g., Arrived at site)',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: AppColors.bgDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final text = _timelineUpdateController.text.trim();
                        if (text.isEmpty) return;
                        
                        try {
                          await RescueService().addManualTimelineEvent(
                            int.parse(widget.task.taskId),
                            text,
                            null,
                          );
                          _timelineUpdateController.clear();
                          setState(() {}); // refresh FutureBuilder
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error adding update: $e')),
                          );
                        }
                      },
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ─── Section 6 & 7: Operation Updates & Media ───────────────────────────────

  Widget _buildOperationUpdates() {
    return _buildAccordion(
      'Operation Updates',
      Icons.description_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Before rescue — flooded road', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Stranded vehicles near bridge', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              int incidentId = 0;
              try {
                incidentId = int.parse(widget.task.taskId.replaceAll(RegExp(r'[^0-9]'), ''));
              } catch (e) {
                // Ignore
              }
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => LiveUpdateFormSheet(
                  incidentId: incidentId,
                ),
              );
            },
            child: Container(
              height: 100,
              width: MediaQuery.of(context).size.width * 0.45,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.primary),
                  SizedBox(height: 4),
                  Text('Add Media', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Photos and videos are organized chronologically. Visible to Admin.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── Section 8: Operation Notes ─────────────────────────────────────────────

  Widget _buildOperationNotes() {
    return _buildAccordion('Operation Notes', Icons.visibility_outlined, const Text('Private team notes will go here.', style: TextStyle(color: Colors.white54)));
  }

  // ─── Section 9: Resources Used ──────────────────────────────────────────────

  Widget _buildResourcesUsed() {
    return _buildAccordion('Resources Used', Icons.inventory_2_outlined, const Text('Resources used tracking goes here.', style: TextStyle(color: Colors.white54)));
  }

  // ─── Section 10: Post-Incident Report ───────────────────────────────────────

  Widget _buildPostIncidentReport() {
    return _buildAccordion('Post-Incident Report', Icons.task_outlined, const Text('7 field form goes here.', style: TextStyle(color: Colors.white54)));
  }

  // ─── Bottom CTA ─────────────────────────────────────────────────────────────

  Widget _buildBottomCTA() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          // Complete logic
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.black87),
            SizedBox(width: 8),
            Text(
              'COMPLETE RESCUE OPERATION',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Layout Implementations ─────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return FadeTransition(
      opacity: _cardFade,
      child: SlideTransition(
        position: _cardSlide,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              _buildHeaderCard(),
              _buildDisasterInformation(),
              _buildLocation(),
              _buildRescueTimeline(),
              _buildOperationUpdates(),
              _buildOperationNotes(),
              _buildResourcesUsed(),
              _buildPostIncidentReport(),
              _buildBottomCTA(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: _buildMobileLayout(),
      ),
    );
  }
}

class _AnimatedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 150),
          child: Icon(icon, color: Colors.white38, size: 20),
        ),
      ),
    );
  }
}

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
