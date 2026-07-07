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
import 'package:disaster360/services/session_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:disaster360/services/supabase_storage_service.dart';
import 'package:disaster360/models/report_media.dart';
import 'package:disaster360/rescue/widgets/post_incident_report_widget.dart';

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
  int get _operationId {
    final taskId = int.tryParse(widget.task.taskId.replaceAll(RegExp(r'[^0-9]'), ''));
    if (taskId != null && taskId > 0) return taskId;
    final assignId = int.tryParse(widget.task.assignmentId.replaceAll(RegExp(r'[^0-9]'), ''));
    if (assignId != null && assignId > 0) return assignId;
    return 0;
  }

  // Animation controllers
  late AnimationController _cardController;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  late AnimationController _decisionController;
  late Animation<double> _decisionFade;
  late Animation<Offset> _decisionSlide;

  List<RescueTimelineEvent>? _timelineEvents;
  bool _isLoadingTimeline = true;
  String? _timelineError;
  String? _currentUserId;
  bool _isCurrentUserAdmin = false;
  List<ReportMedia>? _operationMedia;
  bool _isUploadingMedia = false;
  final Map<int, GlobalKey> _mediaKeys = {};
  int? _highlightedMediaId;

  Future<void> _fetchTimelineEvents() async {
    try {
      final eventsData = await RescueService().getTimelineEvents(_operationId);
      final events = eventsData.map((e) => RescueTimelineEvent.fromJson(e)).toList();
      final mediaData = await RescueService().getOperationMedia(_operationId);
      final media = mediaData.map((m) => ReportMedia.fromJson(m)).toList();
      final session = SessionService();
      if (session.currentUser == null) {
        await session.initialize();
      }
      if (mounted) {
        setState(() {
          _timelineEvents = events;
          _operationMedia = media;
          _isLoadingTimeline = false;
          _currentUserId = session.currentUser?.id;
          _isCurrentUserAdmin = session.currentUser?.role == 'admin';
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
  }

  void _showEditTimelineDialog(RescueTimelineEvent event, int index) {
    final controller = TextEditingController(text: event.description ?? event.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgSurface,
          title: const Text('Edit Timeline Event', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(
              filled: true,
              fillColor: AppColors.bgDark,
              border: OutlineInputBorder(),
              hintText: 'Enter description',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final newDescription = controller.text.trim();
                if (newDescription.isEmpty) return;
                Navigator.pop(context);
                
                final oldDescription = event.description ?? "";
                if (newDescription == oldDescription.trim()) return;
                
                final oldEvent = _timelineEvents![index];
                
                setState(() {
                  _timelineEvents![index] = RescueTimelineEvent(
                    id: oldEvent.id,
                    incidentId: oldEvent.incidentId,
                    assignmentId: oldEvent.assignmentId,
                    teamId: oldEvent.teamId,
                    teamName: oldEvent.teamName,
                    createdBy: oldEvent.createdBy,
                    eventType: oldEvent.eventType,
                    title: oldEvent.title,
                    description: newDescription,
                    createdAt: oldEvent.createdAt,
                    updatedAt: DateTime.now().toUtc().toIso8601String(),
                    updatedBy: _currentUserId,
                    metadataJson: oldEvent.metadataJson,
                    isSystemGenerated: oldEvent.isSystemGenerated,
                    isEdited: true,
                  );
                });

                try {
                  final updatedMap = await RescueService().updateTimelineEvent(event.id, newDescription);
                  if (mounted) {
                    setState(() {
                      _timelineEvents![index] = RescueTimelineEvent.fromJson(updatedMap);
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _timelineEvents![index] = oldEvent;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update event: $e')));
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTimelineEvent(RescueTimelineEvent event, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgSurface,
          title: const Text('Delete Event?', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to delete this event? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                Navigator.pop(context);
                
                final oldEvent = _timelineEvents![index];
                
                setState(() {
                  _timelineEvents!.removeAt(index);
                });

                try {
                  await RescueService().deleteTimelineEvent(event.id);
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _timelineEvents!.insert(index, oldEvent);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

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
    _fetchTimelineEvents();
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
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.orange),
          onPressed: () {
            _fetchTimelineEvents();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Refreshing details...'), duration: Duration(seconds: 1)),
            );
          },
          tooltip: 'Refresh Details',
        ),
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
      _isLoadingTimeline
          ? const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ))
          : _timelineError != null
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Failed to load timeline: $_timelineError', style: const TextStyle(color: Colors.white54)),
                )
              : _timelineEvents == null || _timelineEvents!.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No timeline events yet.', style: TextStyle(color: Colors.white54)),
                    )
                  : Column(
                      children: [
                        ...List.generate(_timelineEvents!.length, (i) {
                          final events = _timelineEvents!;
                          final isLast = i == events.length - 1;
                          final event = events[i];
                          
                          Color color;
                          if (event.eventType == 'SYSTEM') {
                            color = AppColors.info;
                          } else {
                            color = AppColors.primary;
                          }
                          
                          final bool canEdit = !event.isSystemGenerated && (_isCurrentUserAdmin || event.createdBy == _currentUserId);

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
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: event.mediaId != null ? () {
                                          setState(() {
                                            _expandedSections['Operation Updates'] = true;
                                          });
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            final key = _mediaKeys[event.mediaId];
                                            if (key != null && key.currentContext != null) {
                                              Scrollable.ensureVisible(
                                                key.currentContext!,
                                                duration: const Duration(milliseconds: 400),
                                                curve: Curves.easeInOut,
                                              );
                                              setState(() {
                                                _highlightedMediaId = event.mediaId;
                                              });
                                              Future.delayed(const Duration(milliseconds: 2500), () {
                                                if (mounted && _highlightedMediaId == event.mediaId) {
                                                  setState(() {
                                                    _highlightedMediaId = null;
                                                  });
                                                }
                                              });
                                            }
                                          });
                                        } : null,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: event.mediaId != null ? 8.0 : 0.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
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
                                                (event.isEdited && event.description != null && event.description!.isNotEmpty) 
                                                    ? event.description! 
                                                    : event.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (!event.isEdited && event.description != null && event.description!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  event.description!,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                              if (event.isEdited && event.updatedAt != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Edited • ${RescueTask.formatDateTime(event.updatedAt!)}",
                                                  style: TextStyle(
                                                    color: color.withOpacity(0.6),
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
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
                                        if (canEdit)
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                            color: AppColors.bgDark,
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showEditTimelineDialog(event, i);
                                              } else if (value == 'delete') {
                                                _confirmDeleteTimelineEvent(event, i);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit', style: TextStyle(color: Colors.white)),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete', style: TextStyle(color: AppColors.danger)),
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
                              ],
                            ),
                          );
                        }),
                        if (widget.task.status == TaskStatus.pending) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 16),
                          if (widget.task.assignmentStatus.toLowerCase() == 'accepted')
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Start the operation from the home screen to add timeline updates.',
                                style: TextStyle(color: AppColors.warning, fontStyle: FontStyle.italic),
                              ),
                            )
                          else
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
                                      final newMap = await RescueService().addManualTimelineEvent(
                                        _operationId,
                                        text,
                                        null,
                                      );
                                      _timelineUpdateController.clear();
                                      _fetchTimelineEvents();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error adding update: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
    );
  }

  // ─── Section 6 & 7: Operation Updates & Media ───────────────────────────────

  Widget _buildOperationUpdates() {
    Map<int, String> finalTitles = {};
    if (_operationMedia != null && _operationMedia!.isNotEmpty) {
      Map<String, int> titleCounts = {};
      for (var media in _operationMedia!) {
        if (!_mediaKeys.containsKey(media.id)) {
          _mediaKeys[media.id] = GlobalKey();
        }
        String baseTitle = media.title ?? 'Image';
        titleCounts[baseTitle] = (titleCounts[baseTitle] ?? 0) + 1;
        if (titleCounts[baseTitle]! > 1) {
          finalTitles[media.id] = '$baseTitle (${titleCounts[baseTitle]})';
        } else {
          finalTitles[media.id] = baseTitle;
        }
      }
    }

    return _buildAccordion(
      'Operation Updates',
      Icons.description_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_operationMedia != null && _operationMedia!.isNotEmpty)
            Column(
              children: List.generate(_operationMedia!.length, (index) {
                final media = _operationMedia![index];
                
                String subtitle = 'Unknown Upload Time';
                if (media.createdAt != null) {
                  try {
                    final dateTime = DateTime.parse(media.createdAt!).toLocal();
                    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
                    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
                    final min = dateTime.minute.toString().padLeft(2, '0');
                    subtitle = 'Uploaded $hour:$min $ampm';
                  } catch (e) {
                    // Ignore parsing error
                  }
                }

                return Padding(
                  key: _mediaKeys[media.id],
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: AppColors.bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _highlightedMediaId == media.id ? AppColors.primary : AppColors.border,
                        width: _highlightedMediaId == media.id ? 3 : 2,
                      ),
                      boxShadow: _highlightedMediaId == media.id 
                          ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)] 
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'close',
                          barrierColor: Colors.transparent,
                          transitionDuration: const Duration(milliseconds: 250),
                          pageBuilder: (_, __, ___) => ImageViewerOverlay(
                            mediaUrls: _operationMedia!.map((m) => m.filePath).toList(),
                            initialIndex: index,
                            reportId: widget.task.taskId,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt, color: Colors.white70, size: 36),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    finalTitles[media.id] ?? 'Image ${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              }),
            ),
          if (widget.task.assignmentStatus.toLowerCase() == 'accepted')
            Container(
              height: 100,
              width: MediaQuery.of(context).size.width * 0.45,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), style: BorderStyle.solid),
              ),
              padding: const EdgeInsets.all(8),
              child: const Center(
                child: Text(
                  'Start operation to add media',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _isUploadingMedia ? null : () async {
                int incidentId = 0;
                try {
                  incidentId = int.parse(widget.task.taskId.replaceAll(RegExp(r'[^0-9]'), ''));
                } catch (e) {
                  return;
                }
                
                final picker = ImagePicker();
                final List<XFile> images = await picker.pickMultiImage();
                
                if (images.isEmpty) return;

                String? titleInput;
                bool? proceed = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    final textController = TextEditingController();
                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        final isValid = textController.text.trim().isNotEmpty && textController.text.trim().length <= 100;
                        
                        return AlertDialog(
                          backgroundColor: AppColors.bgDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Upload Images', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Image Title', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: textController,
                                style: const TextStyle(color: Colors.white),
                                maxLength: 100,
                                onChanged: (v) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Enter a descriptive title...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  prefixIcon: const Icon(Icons.camera_alt_outlined, color: Colors.white54),
                                  filled: true,
                                  fillColor: AppColors.bgSurface,
                                  counterText: '',
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Example:\n"Collapsed Bridge"\n"Flooded Main Road"\n"Victim Evacuation"',
                                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'This title will appear in the Rescue Timeline.',
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                            ),
                            ElevatedButton(
                              onPressed: isValid ? () {
                                titleInput = textController.text.trim();
                                Navigator.pop(context, true);
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                                disabledForegroundColor: Colors.white54,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Upload'),
                            ),
                          ],
                        );
                      }
                    );
                  }
                );

                if (proceed != true) return;
                
                setState(() {
                  _isUploadingMedia = true;
                });
                
                try {
                  final storageService = SupabaseStorageService();
                  final filesToUpload = images.map((img) => File(img.path)).toList();
                  final uploadedUrls = await storageService.uploadImages(filesToUpload);
                  
                  final List<Map<String, dynamic>> mediaPayload = [];
                  for (int i = 0; i < uploadedUrls.length; i++) {
                    final file = File(images[i].path);
                    mediaPayload.add({
                      'url': uploadedUrls[i],
                      'filename': images[i].name,
                      'size': await file.length(),
                      'title': titleInput,
                    });
                  }
                  
                  await RescueService().uploadOperationMedia(incidentId, mediaPayload);
                  
                  if (mounted) {
                    _fetchTimelineEvents();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isUploadingMedia = false;
                    });
                  }
                }
              },
              child: Container(
                height: 100,
                width: MediaQuery.of(context).size.width * 0.45,
                decoration: BoxDecoration(
                  color: _isUploadingMedia ? Colors.transparent : AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isUploadingMedia ? Colors.transparent : AppColors.primary.withOpacity(0.3), style: BorderStyle.solid),
                ),
                child: _isUploadingMedia 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : const Column(
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


  // ─── Section 10: Post-Incident Report ───────────────────────────────────────

  Widget _buildPostIncidentReport() {
    bool isCompleted = widget.task.status == TaskStatus.completed;
    return _buildAccordion(
      'Post-Incident Report',
      Icons.task_outlined,
      PostIncidentReportWidget(
        operationId: _operationId,
        isCompleted: isCompleted,
      ),
    );
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
    switch (status.toLowerCase()) {
      case 'in progress':
        bg = AppColors.orange.withOpacity(0.18);
        text = AppColors.orange;
        break;
      case 'verified':
      case 'controlled':
      case 'completed':
      case 'resolved':
        bg = AppColors.success.withOpacity(0.15);
        text = AppColors.success;
        break;
      case 'closed':
        bg = AppColors.info.withOpacity(0.15);
        text = AppColors.info;
        break;
      case 'rejected':
      case 'cancelled':
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
