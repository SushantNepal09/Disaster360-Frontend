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
  Future<Map<String, dynamic>> rejectAssignment(
    int assignmentId, {
    required String reason,
  }) async {
    final Map<String, dynamic> body = {'reason': reason};
    final response = await _api.put(
      '/rescue/assignments/$assignmentId/reject',
      body: body,
    );
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

  // ---------------------------------------------------------------------------
  // GET /rescue/completed-assignments
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getCompletedAssignments() async {
    final response = await _api.get('/rescue/completed-assignments');
    final map = response as Map<String, dynamic>;
    if (map['success'] == true) {
      final list = map['data'] as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // LIVE UPDATES & OFFLINE QUEUE
  // ---------------------------------------------------------------------------
  
  // Simple in-memory queue for offline updates (would be persisted via Hive/SQLite in prod)
  static final List<Map<String, dynamic>> _offlineUpdatesQueue = [];

  Future<Map<String, dynamic>> postLiveUpdate(
    int incidentId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _api.post(
        '/rescue/incidents/$incidentId/live-updates',
        body: payload,
      );
      
      // If successful, try to sync queued items
      _syncOfflineUpdates();
      
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      // If network error, queue the update
      payload['incident_id'] = incidentId;
      _offlineUpdatesQueue.add(payload);
      print("Network error. Live update queued offline. Queue size: ${_offlineUpdatesQueue.length}");
      
      // Return a simulated success response so the UI can proceed
      return {
        "success": true,
        "message": "Update queued offline",
        "data": {"id": -1, "queued": true}
      };
    }
  }
  
  Future<void> _syncOfflineUpdates() async {
    if (_offlineUpdatesQueue.isEmpty) return;
    
    print("Attempting to sync ${_offlineUpdatesQueue.length} offline updates...");
    final List<Map<String, dynamic>> failedUpdates = [];
    
    for (var update in _offlineUpdatesQueue) {
      final int incidentId = update['incident_id'];
      
      // Remove incident_id from body payload to match schema exactly
      final payload = Map<String, dynamic>.from(update);
      payload.remove('incident_id');
      
      try {
        await _api.post('/rescue/incidents/$incidentId/live-updates', body: payload);
      } catch (e) {
        failedUpdates.add(update);
      }
    }
    
    _offlineUpdatesQueue.clear();
    _offlineUpdatesQueue.addAll(failedUpdates);
    
    if (_offlineUpdatesQueue.isEmpty) {
      print("All offline updates synced successfully.");
    }
  }

  Future<List<Map<String, dynamic>>> getTimelineEvents(int operationId) async {
    final response = await _api.get('/rescue/operations/$operationId/timeline');
    final map = response as Map<String, dynamic>;
    if (map['success'] == true) {
      final list = map['data'] as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> addManualTimelineEvent(
    int operationId,
    String title,
    String? description,
  ) async {
    final response = await _api.post(
      '/rescue/operations/$operationId/timeline',
      body: {
        'title': title,
        'description': description,
        'event_type': 'MANUAL',
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> updateTimelineEvent(
    int eventId,
    String description,
  ) async {
    final response = await _api.put(
      '/rescue/operations/timeline/$eventId',
      body: {
        'description': description,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> deleteTimelineEvent(int eventId) async {
    await _api.delete('/rescue/operations/timeline/$eventId');
  }
}
