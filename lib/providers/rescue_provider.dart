import 'package:flutter/material.dart';
import 'package:disaster360/services/rescue_service.dart';
import 'package:disaster360/rescue/rescue_tasks_screen.dart';
import 'package:disaster360/providers/report_provider.dart';

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
  List<ReportModel> _homeFeed = [];
  Map<String, dynamic>? _profile;

  bool _isLoading = false;
  String? _error;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  List<RescueTask> get myAssignments => _myAssignments;
  List<RescueTask> get allReports => _allReports;
  List<ReportModel> get homeFeed => _homeFeed;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clear() {
    _myAssignments.clear();
    _allReports.clear();
    _homeFeed.clear();
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
      await Future.wait([fetchMyAssignments(), fetchAllReports(), fetchHomeFeed()]);
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
  // Fetch Home Feed (Assigned reports in ReportModel format)
  // ---------------------------------------------------------------------------
  Future<void> fetchHomeFeed() async {
    try {
      final data = await _service.getHomeFeed();
      _homeFeed = data.map((r) => ReportModel.fromJson(r)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('fetchHomeFeed error: $e');
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
  // Accept a Rescue Assignment
  // ---------------------------------------------------------------------------
  Future<String> acceptAssignment(int assignmentId) async {
    final result = await _service.acceptAssignment(assignmentId);
    await fetchMyAssignments();
    return result['message'] ?? 'Assignment accepted successfully';
  }

  // ---------------------------------------------------------------------------
  // Reject a Rescue Assignment
  // ---------------------------------------------------------------------------
  Future<String> rejectAssignment(int assignmentId, {String? reason}) async {
    final result = await _service.rejectAssignment(assignmentId, reason: reason);
    await fetchMyAssignments();
    return result['message'] ?? 'Assignment rejected successfully';
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
