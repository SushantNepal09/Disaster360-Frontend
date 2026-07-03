class RescueTimelineEvent {
  final int id;
  final int incidentId;
  final int? assignmentId;
  final String? teamId;
  final String? teamName;
  final String? createdBy;
  final String eventType;
  final String title;
  final String? description;
  final String createdAt;
  final Map<String, dynamic>? metadataJson;
  final bool isSystemGenerated;

  RescueTimelineEvent({
    required this.id,
    required this.incidentId,
    this.assignmentId,
    this.teamId,
    this.teamName,
    this.createdBy,
    required this.eventType,
    required this.title,
    this.description,
    required this.createdAt,
    this.metadataJson,
    required this.isSystemGenerated,
  });

  factory RescueTimelineEvent.fromJson(Map<String, dynamic> json) {
    return RescueTimelineEvent(
      id: json['id'],
      incidentId: json['incident_id'],
      assignmentId: json['assignment_id'],
      teamId: json['team_id'],
      teamName: json['team_name'],
      createdBy: json['created_by'],
      eventType: json['event_type'] ?? 'SYSTEM',
      title: json['title'] ?? 'Unknown Event',
      description: json['description'],
      createdAt: json['created_at'] ?? '',
      metadataJson: json['metadata_json'] as Map<String, dynamic>?,
      isSystemGenerated: json['is_system_generated'] ?? false,
    );
  }
}
