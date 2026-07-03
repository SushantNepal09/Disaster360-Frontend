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

  factory LiveUpdateModel.fromJson(Map<String, dynamic> json) {
    return LiveUpdateModel(
      id: json['id'] ?? 0,
      teamId: json['team_id'] ?? '',
      teamName: json['team_name'] ?? 'Unknown Team',
      category: json['category'] ?? 'General',
      severity: json['severity'] ?? 'Normal',
      message: json['message'] ?? '',
      mediaUrl: json['media_url'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      visibility: json['visibility'] ?? 'Public',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
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
