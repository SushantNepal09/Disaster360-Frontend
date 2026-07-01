import 'package:disaster360/services/api_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  RESCUE SERVICE — Wraps all /rescue/* API endpoints
// ═══════════════════════════════════════════════════════════════════════════════

class RescueService {
  final ApiService _api = ApiService();

  // ---------------------------------------------------------------------------
  // GET /rescue/profile — Current rescue team member's profile + stats
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.get('/rescue/profile');
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------------
  // GET /rescue/my-assignments — All incidents explicitly assigned to this team
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getMyAssignments() async {
    final response = await _api.get('/rescue/my-assignments');
    final map = response as Map<String, dynamic>;
    if (map['success'] == true) {
      final list = map['data'] as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // GET /rescue/all-reports — All verified incidents available to rescue teams
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllReports() async {
    final response = await _api.get('/rescue/all-reports');
    final map = response as Map<String, dynamic>;
    if (map['success'] == true) {
      final list = map['data'] as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // PUT /rescue/assignments/{assignmentId}/accept
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> acceptAssignment(int assignmentId) async {
    final response = await _api.put('/rescue/assignments/$assignmentId/accept');
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------------
  // PUT /rescue/assignments/{assignmentId}/reject
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> rejectAssignment(int assignmentId, {String? reason}) async {
    final Map<String, dynamic> body = reason != null ? {'reason': reason} : {};
    final response = await _api.put('/rescue/assignments/$assignmentId/reject', body: body);
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------------
  // POST /rescue/acknowledge — Acknowledge / accept a verified incident
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> acknowledgeReport(int incidentId) async {
    final response = await _api.post(
      '/rescue/acknowledge',
      body: {'incident_id': incidentId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------------
  // PUT /rescue/operations/{assignmentId}/status — Update operation status
  // Status: "Accepted" | "In Progress" | "Completed" | "Cancelled"
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> updateOperationStatus(
    int assignmentId,
    String status,
  ) async {
    final response = await _api.put(
      '/rescue/operations/$assignmentId/status',
      body: {'status': status},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------------
  // POST /rescue/operations/{assignmentId}/post-incident-report
  // Submit a post-incident report (only when status is Completed)
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> submitPostIncidentReport(
    int assignmentId,
    String reportText,
  ) async {
    final response = await _api.post(
      '/rescue/operations/$assignmentId/post-incident-report',
      body: {'post_incident_report': reportText},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------------
  // GET /rescue/home — Get home feed (assigned reports formatted as ReportModel)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getHomeFeed() async {
    final response = await _api.get('/rescue/home');
    return List<Map<String, dynamic>>.from(response as List);
  }
}
