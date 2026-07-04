import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'package:disaster360/colors.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/providers/auth_provider.dart';
import 'package:disaster360/services/gis_service.dart';
import 'package:disaster360/services/map_screen.dart' show DisasterStyle;
import 'package:disaster360/widgets/image_viewer_overlay.dart';

// ─── Constants ─────────────────────────────────────────────
const LatLng _nepalCenter = LatLng(28.2, 83.9);
const LatLng _nepalSW = LatLng(26.347, 80.052);
const LatLng _nepalNE = LatLng(30.448, 88.201);

class DesktopMapScreen extends StatefulWidget {
  const DesktopMapScreen({super.key});
  @override
  State<DesktopMapScreen> createState() => _DesktopMapScreenState();
}

class _DesktopMapScreenState extends State<DesktopMapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final GisService _gisService = GisService();
  
  // Boundary State
  String _activeBoundaryLayer = 'None';
  List<MapRegion> _cachedProvinces = [];
  List<MapRegion> _cachedDistricts = [];
  List<MapRegion> _cachedWards = [];
  bool _isLoadingBoundaries = false;

  // Filters State
  Set<String> _selectedDisasterTypes = {'All'};
  Set<String> _selectedSeverities = {};
  Set<String> _selectedStatuses = {};
  
  // Map State
  ReportModel? _selectedIncident;
  String? _tappedRegionName;
  String? _tappedRegionLayer;
  Timer? _regionInfoTimer;
  bool _showLegend = true;
  bool _showZones = true;
  bool _isSatellite = false;
  LatLng? _myLocation;
  
  // Layout State
  bool _isSidebarExpanded = true;
  bool _isIncidentPanelExpanded = false;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _loadAllBoundaries();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllBoundaries() async {
    setState(() => _isLoadingBoundaries = true);
    try {
      final prov = await _gisService.loadLayer('Province', 'assets/maps/province0.json');
      final dist = await _gisService.loadLayer('District', 'assets/maps/districts0.json');
      final LocalUnit = await _gisService.loadLayer('LocalUnit', 'assets/maps/local_unit.json');
      if (mounted) {
        setState(() {
          _cachedProvinces = prov;
          _cachedDistricts = dist;
          _cachedWards = LocalUnit;
          _isLoadingBoundaries = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading boundaries: $e");
      if (mounted) setState(() => _isLoadingBoundaries = false);
    }
  }

  Future<void> _locateMe() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _myLocation = LatLng(position.latitude, position.longitude);
    });
    _mapController.move(_myLocation!, 14.0);
  }

  List<ReportModel> get _reports => context.watch<ReportProvider>().reports;

  List<ReportModel> get _filteredReports {
    return _reports.where((i) {
      // Filter by Type
      if (!_selectedDisasterTypes.contains('All')) {
        if (!_selectedDisasterTypes.contains(i.disasterType)) return false;
      }
      // Filter by Severity
      if (_selectedSeverities.isNotEmpty) {
        if (!_selectedSeverities.contains(i.severity)) return false;
      }
      // Filter by Status
      if (_selectedStatuses.isNotEmpty) {
        if (!_selectedStatuses.contains(i.status)) return false;
      }
      return true;
    }).toList();
  }

  void _selectIncident(ReportModel inc) {
    setState(() {
      _selectedIncident = inc;
      _isIncidentPanelExpanded = true;
    });
    _mapController.move(LatLng(inc.latitude, inc.longitude), 12.0);
  }

  void _closeIncidentPanel() {
    setState(() {
      _isIncidentPanelExpanded = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isIncidentPanelExpanded) {
          setState(() => _selectedIncident = null);
        }
      });
    });
  }

  // ─── MAIN BUILD ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    
    // Auto collapse sidebar on smaller screens
    if (!isDesktop && _isSidebarExpanded) {
      // Defer state update to avoid build cycle issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isSidebarExpanded = false);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          // 1. Top Toolbar (Full width)
          _buildToolbar(),
          
          // 2. Main Area (Sidebar + Map)
          Expanded(
            child: Row(
              children: [
                // Collapsible Sidebar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isSidebarExpanded ? 280 : 0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: 280,
                      minWidth: 280,
                      child: Theme(
                        data: ThemeData.dark(),
                        child: _buildSidebar(),
                      ),
                    ),
                  ),
                ),
                
                // Map Area
                Expanded(
                  child: Stack(
                    children: [
                      // Map Layer
                      _buildMap(),
                      
                      // Statistics Row Overlay
                      _buildStatisticsRow(),
                      
                      // Map Controls (Locate, Zoom)
                      _buildMapControls(),
                      
                      // Floating Sidebar Toggle
                      _buildSidebarToggle(),
                      
                      // Floating Legend
                      if (_showLegend) _buildLegend(),
                      
                      // Tapped Region Info
                      if (_tappedRegionName != null) _buildRegionInfoPopup(),
                      
                      // Incident Detail Panel (Right Sidebar overlay)
                      if (_selectedIncident != null) _buildIncidentPanel(),
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

  // ─── TOOLBAR & TOGGLE ───────────────────────────────────────

  Widget _buildSidebarToggle() {
    return Positioned(
      left: 16,
      top: MediaQuery.of(context).size.height / 2 - 28,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                _isSidebarExpanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Spacer(),
          
          // Boundary Selector
          _buildBoundarySelector(),
          const SizedBox(width: 16),
          
          // Map Type Toggle
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                _buildToggleBtn(
                  'Standard',
                  !_isSatellite,
                  () => setState(() => _isSatellite = false),
                ),
                _buildToggleBtn(
                  'Satellite',
                  _isSatellite,
                  () => setState(() => _isSatellite = true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            onPressed: () {
              context.read<ReportProvider>().fetchReports();
              context.read<ReportProvider>().fetchActiveRescues();
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.info : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBoundarySelector() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activeBoundaryLayer,
          dropdownColor: AppColors.bgSurface,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: ['None', 'Province', 'District', 'LocalUnit'].map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val == 'LocalUnit' ? 'Local Unit' : val),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _activeBoundaryLayer = val);
          },
        ),
      ),
    );
  }

  // ─── SIDEBAR ────────────────────────────────────────────────

  Widget _buildSidebar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarSectionTitle('DISASTER TYPES'),
          _buildDisasterTypeToggles(),
          const SizedBox(height: 24),
          
          _buildSidebarSectionTitle('SEVERITY'),
          _buildSeverityToggles(),
          const SizedBox(height: 24),
          
          _buildSidebarSectionTitle('STATUS'),
          _buildStatusToggles(),
          const SizedBox(height: 24),
          
          _buildSidebarSectionTitle('LAYERS'),
          SwitchListTile(
            title: const Text('Show Danger Zones', style: TextStyle(color: Colors.white, fontSize: 13)),
            value: _showZones,
            activeColor: AppColors.info,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _showZones = v),
          ),
          SwitchListTile(
            title: const Text('Show Legend Panel', style: TextStyle(color: Colors.white, fontSize: 13)),
            value: _showLegend,
            activeColor: AppColors.info,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _showLegend = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDisasterTypeToggles() {
    final types = ['All', 'Earthquake', 'Flood', 'Landslide', 'Fire', 'Storm', 'Roadblock'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final isSelected = _selectedDisasterTypes.contains(type);
        return FilterChip(
          label: Text(type),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (type == 'All') {
                _selectedDisasterTypes = {'All'};
              } else {
                _selectedDisasterTypes.remove('All');
                if (selected) {
                  _selectedDisasterTypes.add(type);
                } else {
                  _selectedDisasterTypes.remove(type);
                  if (_selectedDisasterTypes.isEmpty) _selectedDisasterTypes = {'All'};
                }
              }
            });
          },
          backgroundColor: Colors.white.withOpacity(0.05),
          selectedColor: AppColors.info.withOpacity(0.2),
          checkmarkColor: AppColors.info,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.info : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? AppColors.info.withOpacity(0.5) : Colors.white12,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeverityToggles() {
    final severities = ['Critical', 'High', 'Moderate', 'Low'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: severities.map((sev) {
        final isSelected = _selectedSeverities.contains(sev);
        final color = DisasterStyle.severityColor(sev);
        return FilterChip(
          label: Text(sev),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) _selectedSeverities.add(sev);
              else _selectedSeverities.remove(sev);
            });
          },
          backgroundColor: Colors.white.withOpacity(0.05),
          selectedColor: color.withOpacity(0.2),
          checkmarkColor: color,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelStyle: TextStyle(
            color: isSelected ? color : Colors.white70,
            fontSize: 12,
          ),
          side: BorderSide(
            color: isSelected ? color.withOpacity(0.5) : Colors.white12,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusToggles() {
    final statuses = ['Pending', 'Verified', 'Assigned', 'In Progress', 'Controlled', 'Resolved', 'Rejected'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final isSelected = _selectedStatuses.contains(status);
        final color = DisasterStyle.statusColor(status);
        return FilterChip(
          label: Text(status),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) _selectedStatuses.add(status);
              else _selectedStatuses.remove(status);
            });
          },
          backgroundColor: Colors.white.withOpacity(0.05),
          selectedColor: color.withOpacity(0.2),
          checkmarkColor: color,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelStyle: TextStyle(
            color: isSelected ? color : Colors.white70,
            fontSize: 12,
          ),
          side: BorderSide(
            color: isSelected ? color.withOpacity(0.5) : Colors.white12,
          ),
        );
      }).toList(),
    );
  }

  // ─── STATISTICS OVERLAY ─────────────────────────────────────

  Widget _buildStatisticsRow() {
    final totalActive = _reports.where((r) => r.status != 'Controlled' && r.status != 'Resolved' && r.status != 'Rejected').length;
    final pending = _reports.where((r) => r.status.toLowerCase() == 'pending').length;
    final verified = _reports.where((r) => r.status.toLowerCase() == 'verified').length;
    final inProgress = _reports.where((r) => r.status.toLowerCase() == 'in progress').length;
    
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isSidebarExpanded ? 1.0 : 0.0,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
            _buildStatCard('Active Incidents', totalActive.toString(), AppColors.danger),
            _buildStatCard('Pending', pending.toString(), AppColors.orange),
            _buildStatCard('Verified', verified.toString(), Colors.blue),
            _buildStatCard('In Progress', inProgress.toString(), AppColors.info),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color accent) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── LEGEND ────────────────────────────────────────────────

  Widget _buildLegend() {
    final highCount = _reports.where((i) => i.severity.toLowerCase() == 'high' && i.status.toLowerCase() != 'controlled').length;
    final moderateCount = _reports.where((i) => i.severity.toLowerCase() == 'moderate' && i.status.toLowerCase() != 'controlled').length;
    
    return Positioned(
      bottom: 24,
      right: _isIncidentPanelExpanded ? 360 : 24,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RISK LEGEND', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildLegendItem('High Risk', AppColors.danger, highCount),
            const SizedBox(height: 8),
            _buildLegendItem('Moderate Risk', AppColors.warning, moderateCount),
            const SizedBox(height: 8),
            _buildLegendItem('Low Risk / Safe', AppColors.success, 0),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))),
        if (count > 0)
          Text(count.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── MAP CONTROLS ──────────────────────────────────────────

  Widget _buildMapControls() {
    return Positioned(
      top: 100,
      right: _isIncidentPanelExpanded ? 360 : 24,
      child: Column(
        children: [
          _buildMapControlButton(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
          const SizedBox(height: 8),
          _buildMapControlButton(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
          const SizedBox(height: 8),
          _buildMapControlButton(Icons.my_location, _locateMe),
        ],
      ),
    );
  }

  Widget _buildMapControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.bgSurface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ─── INCIDENT PANEL ────────────────────────────────────────

  Widget _buildIncidentPanel() {
    final inc = _selectedIncident!;
    final authProvider = context.read<AuthProvider>();
    final isAdmin = authProvider.user?.role == 'Admin';
    final isRescue = authProvider.user?.role == 'RescueTeam';

    return Positioned(
      top: 16,
      bottom: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isIncidentPanelExpanded ? 320 : 0,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(-5, 0)),
          ],
        ),
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Incident Details',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: _closeIncidentPanel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildBadge(inc.disasterType.toUpperCase(), DisasterStyle.colorForType(inc.disasterType)),
                          _buildBadge(inc.severity.toUpperCase(), DisasterStyle.severityColor(inc.severity)),
                          _buildBadge(inc.status.toUpperCase(), DisasterStyle.statusColor(inc.status)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Title & Desc
                      Text(
                        inc.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        inc.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      
                      // Details
                      _buildDetailRow(Icons.person, 'Reporter', inc.userName),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.access_time, 'Time', _formatDate(inc.createdAt)),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.location_on, 'Location', '${inc.latitude.toStringAsFixed(4)}, ${inc.longitude.toStringAsFixed(4)}'),
                      if (inc.district != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.map, 'District', inc.district!),
                      ],
                      if (inc.localUnit != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.account_balance, 'Local Unit', inc.localUnit!),
                      ],
                      const SizedBox(height: 24),
                      
                      // Images
                      if (inc.mediaUrls.isNotEmpty) ...[
                        const Text('EVIDENCE MEDIA', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: inc.mediaUrls.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              return GestureDetector(
                                onTap: () {
                                  showGeneralDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    barrierLabel: 'close',
                                    pageBuilder: (_, __, ___) => ImageViewerOverlay(mediaUrls: inc.mediaUrls, initialIndex: i, reportId: inc.id.toString()),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(inc.mediaUrls[i], width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Actions Base
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isAdmin) ...[
                      if (inc.status.toLowerCase() == 'pending')
                        ElevatedButton(
                          onPressed: () {
                            context.read<ReportProvider>().verifyReport(inc.id);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          child: const Text('Verify Report'),
                        ),
                      if (inc.status.toLowerCase() == 'verified')
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                          child: const Text('Assign Rescue Team'),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('View Full Details'),
                      ),
                    ],
                    
                    if (isRescue) ...[
                      if (inc.status.toLowerCase() == 'assigned')
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                          child: const Text('Accept Mission'),
                        ),
                      if (inc.status.toLowerCase() == 'in progress')
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                          child: const Text('Mark Controlled'),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Navigate to Incident'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Unknown Time';
    try {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) dateStr += 'Z';
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour12:$minute $ampm';
    } catch (e) {
      return dateStr.split("T").first;
    }
  }

  // ─── MAP LAYER BUILDERS ─────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _nepalCenter,
        initialZoom: 7.0,
        minZoom: 6.0,
        maxZoom: 18,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(_nepalSW, _nepalNE),
        ),
        onTap: (_, point) {
          if (_selectedIncident != null) _closeIncidentPanel();
          if (_activeBoundaryLayer != 'None') {
            List<MapRegion> activeRegions = [];
            if (_activeBoundaryLayer == 'Province') activeRegions = _cachedProvinces;
            if (_activeBoundaryLayer == 'District') activeRegions = _cachedDistricts;
            if (_activeBoundaryLayer == 'LocalUnit') activeRegions = _cachedWards;

            final regionName = _gisService.identifyRegion(point, activeRegions);
            if (regionName != null) {
              setState(() {
                _tappedRegionName = regionName;
                _tappedRegionLayer = _activeBoundaryLayer == 'LocalUnit' ? 'Local Unit' : _activeBoundaryLayer;
              });
              _regionInfoTimer?.cancel();
              _regionInfoTimer = Timer(const Duration(seconds: 4), () {
                if (mounted) setState(() => _tappedRegionName = null);
              });
            }
          }
        },
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: _isSatellite
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.disaster360.app',
          maxZoom: 18,
        ),
        if (_activeBoundaryLayer != 'None') _buildBoundaryLayer(),
        if (_showZones) _buildZoneLayer(),
        MarkerLayer(markers: _buildMarkers()),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OSM Contributors',
              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
      ],
    );
  }

  PolygonLayer _buildBoundaryLayer() {
    List<MapRegion> activeRegions = [];
    if (_activeBoundaryLayer == 'Province') activeRegions = _cachedProvinces;
    if (_activeBoundaryLayer == 'District') activeRegions = _cachedDistricts;
    if (_activeBoundaryLayer == 'LocalUnit') activeRegions = _cachedWards;
    final color = _activeBoundaryLayer == 'Province' ? Colors.deepPurpleAccent : _activeBoundaryLayer == 'District' ? Colors.blueAccent : Colors.teal;

    return PolygonLayer(
      simplificationTolerance: 0.5,
      polygons: activeRegions.expand((r) => r.polygons).map<Polygon>((polyCoords) {
        return Polygon(
          points: polyCoords,
          color: color.withOpacity(0.15),
          borderColor: color.withOpacity(0.8),
          borderStrokeWidth: 2.0,
        );
      }).toList(),
    );
  }

  CircleLayer _buildZoneLayer() {
    return CircleLayer(
      circles: _filteredReports.map((inc) {
        final radius = inc.severity.toLowerCase() == 'high' ? 18000.0 : inc.severity.toLowerCase() == 'moderate' ? 11000.0 : 6000.0;
        return CircleMarker(
          point: LatLng(inc.latitude, inc.longitude),
          radius: radius,
          useRadiusInMeter: true,
          color: DisasterStyle.zoneColor(inc.disasterType),
          borderColor: DisasterStyle.colorForType(inc.disasterType).withOpacity(0.4),
          borderStrokeWidth: 1.5,
        );
      }).toList(),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = _filteredReports.map((inc) {
      final isSelected = _selectedIncident?.id == inc.id;
      return Marker(
        point: LatLng(inc.latitude, inc.longitude),
        width: isSelected ? 64 : 44,
        height: isSelected ? 64 : 44,
        child: GestureDetector(
          onTap: () => _selectIncident(inc),
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final pulse = (inc.severity.toLowerCase() == 'high' && inc.status.toLowerCase() != 'controlled')
                  ? (0.85 + 0.15 * sin(_pulseCtrl.value * 2 * pi))
                  : 1.0;
              return Transform.scale(scale: pulse, child: child);
            },
            child: _DesktopMarkerWidget(incident: inc, isSelected: isSelected),
          ),
        ),
      );
    }).toList();

    if (_myLocation != null) {
      markers.add(
        Marker(
          point: _myLocation!,
          width: 50,
          height: 50,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.info, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildRegionInfoPopup() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _tappedRegionLayer?.toUpperCase() ?? '',
                style: const TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                _tappedRegionName ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopMarkerWidget extends StatelessWidget {
  final ReportModel incident;
  final bool isSelected;
  const _DesktopMarkerWidget({required this.incident, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final color = DisasterStyle.colorForType(incident.disasterType);
    final icon = DisasterStyle.iconForType(incident.disasterType);
    
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isSelected ? 0.8 : 0.4),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 4 : 1,
          )
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: isSelected ? 28 : 20),
      ),
    );
  }
}
