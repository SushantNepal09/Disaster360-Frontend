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
  // GET /rescue/verified-reports — All verified incidents (active queue)
  // Returns [] when empty (backend no longer throws 404)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getVerifiedReports() async {
    final response = await _api.get('/rescue/verified-reports');
    final list = response as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------------------------------------------------------------------------
  // GET /rescue/my-operations — This rescue team's acknowledged operations
  // Returns [] when empty
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getMyOperations() async {
    final response = await _api.get('/rescue/my-operations');
    final list = response as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
  // PUT /rescue/operations/{rescueUpdateId}/status — Update operation status
  // Status: "Acknowledged" | "Rescue In Progress" | "Controlled" | "Closed"
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> updateOperationStatus(
    int rescueUpdateId,
    String status,
  ) async {
    final response = await _api.put(
      '/rescue/operations/$rescueUpdateId/status',
      body: {'status': status},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------------
  // POST /rescue/operations/{rescueUpdateId}/post-incident-report
  // Submit a post-incident report (only when status is Controlled or Closed)
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> submitPostIncidentReport(
    int rescueUpdateId,
    String reportText,
  ) async {
    final response = await _api.post(
      '/rescue/operations/$rescueUpdateId/post-incident-report',
      body: {'post_incident_report': reportText},
    );
    return Map<String, dynamic>.from(response as Map);
  }
}
