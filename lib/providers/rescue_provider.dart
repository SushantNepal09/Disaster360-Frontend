import 'package:flutter/material.dart';
import 'package:disaster360/services/rescue_service.dart';
import 'package:disaster360/rescue/rescue_tasks_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  RESCUE PROVIDER — State management for the entire rescue section
//
//  Holds:
//    • verifiedReports — Unacknowledged verified incidents from admin
//    • myOperations — This rescue member's acknowledged/active operations
//    • profile — Profile data + mission stats from backend
//
//  TaskStatus mapping (from backend rescue_status string):
//    "Not Acknowledged"             → TaskStatus.active   (Accept button)
//    "Acknowledged"                 → TaskStatus.pending  (Status Report / Mark Done)
//    "Rescue In Progress"           → TaskStatus.pending  (Status Report / Mark Done)
//    "Controlled" / "Closed"        → TaskStatus.completed (Completion Report)
// ═══════════════════════════════════════════════════════════════════════════════

class RescueProvider extends ChangeNotifier {
  final RescueService _service = RescueService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  List<RescueTask> _verifiedReports = [];
  List<RescueTask> _myOperations = [];
  List<RescueTask> _allVerifiedReports = [];
  Map<String, dynamic>? _profile;

  bool _isLoading = false;
  String? _error;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  List<RescueTask> get verifiedReports => _verifiedReports;
  List<RescueTask> get myOperations => _myOperations;
  List<RescueTask> get allVerifiedReports => _allVerifiedReports;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clear() {
    _verifiedReports.clear();
    _myOperations.clear();
    _allVerifiedReports.clear();
    _profile = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// All tasks combined: verified (active) + my operations (pending/completed)
  List<RescueTask> get allTasks => [..._verifiedReports, ..._myOperations];

  /// Stats derived from operations
  int get activeCount =>
      _verifiedReports.where((t) => t.status == TaskStatus.active).length;
  int get pendingCount =>
      _myOperations.where((t) => t.status == TaskStatus.pending).length;
  int get completedCount =>
      _myOperations.where((t) => t.status == TaskStatus.completed).length;

  // ---------------------------------------------------------------------------
  // Fetch All Data (called on screen load)
  // ---------------------------------------------------------------------------
  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await fetchProfile();
      await Future.wait([fetchVerifiedReports(), fetchMyOperations()]);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch Verified Reports (unacknowledged verified incidents = "active" tasks)
  // ---------------------------------------------------------------------------
  String _debugString = '';
  String get debugString => _debugString;

  Future<void> fetchVerifiedReports() async {
    try {
      final data = await _service.getVerifiedReports();
      final parsed = data.map((r) => RescueTask.fromJson(r)).toList();
      _allVerifiedReports = parsed;

      final teamName =
          (_profile != null &&
                  _profile!['full_name'] != null &&
                  _profile!['full_name'].toString().trim().isNotEmpty)
              ? _profile!['full_name']
              : _profile?['email'];

      // Only include reports NOT yet acknowledged by this member AND assigned to this team
      _verifiedReports =
          data
              .where((r) => r['rescue_status'] == 'Not Acknowledged')
              .map((r) {
                final task = RescueTask.fromJson(r);
                return task;
              })
              .where((t) {
                if (teamName == null) return false;
                final myTeam = teamName.toString().trim().toLowerCase();
                return t.assignedTeams.any((assigned) => assigned.trim().toLowerCase() == myTeam);
              })
              .toList();
      
      _debugString = 'Team: $teamName | Verified API count: \${data.length} | Matched: \${_verifiedReports.length}';
      notifyListeners();
    } catch (e) {
      // Silently handle — allTasks will just show empty active list
      _debugString = 'Error: $e';
      debugPrint('fetchVerifiedReports error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch My Operations (acknowledged/in-progress/completed operations)
  // ---------------------------------------------------------------------------
  Future<void> fetchMyOperations() async {
    try {
      final data = await _service.getMyOperations();
      _myOperations = data.map((r) => RescueTask.fromMyOperation(r)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchMyOperations error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch Profile
  // ---------------------------------------------------------------------------
  Future<void> fetchProfile() async {
    try {
      _profile = await _service.getProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchProfile error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Acknowledge a verified incident → moves it from active → pending
  // ---------------------------------------------------------------------------
  Future<String> acknowledgeReport(int incidentId) async {
    final result = await _service.acknowledgeReport(incidentId);
    // Refresh both lists after acknowledging
    await Future.wait([fetchVerifiedReports(), fetchMyOperations()]);
    return result['message'] ?? 'Acknowledged successfully';
  }

  // ---------------------------------------------------------------------------
  // Update operation status (e.g. → "Controlled")
  // ---------------------------------------------------------------------------
  Future<void> updateOperationStatus(int rescueUpdateId, String status) async {
    await _service.updateOperationStatus(rescueUpdateId, status);
    await fetchMyOperations();
  }

  // ---------------------------------------------------------------------------
  // Submit post-incident report
  // ---------------------------------------------------------------------------
  Future<void> submitPostIncidentReport(
    int rescueUpdateId,
    String reportText,
  ) async {
    await _service.submitPostIncidentReport(rescueUpdateId, reportText);
    await fetchMyOperations();
  }
}
