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
  List<RescueTask> _myAssignments = [];
  List<RescueTask> _allReports = [];
  Map<String, dynamic>? _profile;

  bool _isLoading = false;
  String? _error;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  List<RescueTask> get myAssignments => _myAssignments;
  List<RescueTask> get allReports => _allReports;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clear() {
    _myAssignments.clear();
    _allReports.clear();
    _profile = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Stats derived from myAssignments
  int get activeCount =>
      _myAssignments.where((t) => t.status == TaskStatus.active).length;
  int get pendingCount =>
      _myAssignments.where((t) => t.status == TaskStatus.pending).length;
  int get completedCount =>
      _myAssignments.where((t) => t.status == TaskStatus.completed).length;

  // ---------------------------------------------------------------------------
  // Fetch All Data (called on screen load)
  // ---------------------------------------------------------------------------
  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await fetchProfile();
      await Future.wait([fetchMyAssignments(), fetchAllReports()]);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch My Assignments
  // ---------------------------------------------------------------------------
  Future<void> fetchMyAssignments() async {
    try {
      final data = await _service.getMyAssignments();
      _myAssignments = data.map((r) => RescueTask.fromJson(r)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchMyAssignments error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch All Reports
  // ---------------------------------------------------------------------------
  Future<void> fetchAllReports() async {
    try {
      final data = await _service.getAllReports();
      _allReports = data.map((r) => RescueTask.fromJson(r)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchAllReports error: $e');
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
    await fetchMyAssignments();
    return result['message'] ?? 'Acknowledged successfully';
  }

  // ---------------------------------------------------------------------------
  // Update operation status (e.g. → "Controlled")
  // ---------------------------------------------------------------------------
  Future<void> updateOperationStatus(int rescueUpdateId, String status) async {
    await _service.updateOperationStatus(rescueUpdateId, status);
    await fetchMyAssignments();
  }

  // ---------------------------------------------------------------------------
  // Submit post-incident report
  // ---------------------------------------------------------------------------
  Future<void> submitPostIncidentReport(
    int rescueUpdateId,
    String reportText,
  ) async {
    await _service.submitPostIncidentReport(rescueUpdateId, reportText);
    await fetchMyAssignments();
  }
}
