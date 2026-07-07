class LiveUpdateModel {
  final int id;
  final String teamId;
  final String teamName;
  final String category;
  final String severity;
  final String message;
  final String? mediaUrl;
  final double? latitude;
  final double? longitude;
  final String visibility;
  final DateTime createdAt;

  LiveUpdateModel({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.category,
    required this.severity,
    required this.message,
    this.mediaUrl,
    this.latitude,
    this.longitude,
    required this.visibility,
    required this.createdAt,
  });

  
  String normalizeDate(String dateStr) {
    if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
      return 'Z';
    }
    return dateStr;
  }

  factory LiveUpdateModel.fromJson(Map<String, dynamic> json) {
    String normalizeDate(String dateStr) {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        return 'Z';
      }
      return dateStr;
    }

    return LiveUpdateModel(
      id: json['id'] ?? 0,
      incidentId: json['incident_id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'Unknown',
      mediaUrl: json['media_url'],
      source: json['source'] ?? 'Citizen',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(normalizeDate(json['created_at'].toString())) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'team_name': teamName,
      'category': category,
      'severity': severity,
      'message': message,
      'media_url': mediaUrl,
      'latitude': latitude,
      'longitude': longitude,
      'visibility': visibility,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
