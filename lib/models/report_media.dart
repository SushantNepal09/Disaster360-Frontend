class ReportMedia {
  final int id;
  final int? incidentId;
  final int? reportId;
  final int? assignmentId;
  final String userId;
  final String filePath;
  final String? fileType;
  final String? originalFilename;
  final String? title;
  final int? fileSize;
  final String? createdAt;

  ReportMedia({
    required this.id,
    this.incidentId,
    this.reportId,
    this.assignmentId,
    required this.userId,
    required this.filePath,
    this.fileType,
    this.originalFilename,
    this.title,
    this.fileSize,
    this.createdAt,
  });

  factory ReportMedia.fromJson(Map<String, dynamic> json) {
    return ReportMedia(
      id: json['id'],
      incidentId: json['incident_id'],
      assignmentId: json['assignment_id'],
      userId: json['user_id'] ?? '',
      filePath: json['file_path'] ?? json['url'] ?? '',
      originalFilename: json['original_filename'],
      title: json['title'],
      fileSize: json['file_size'],
      createdAt: json['created_at'] != null 
          ? (json['created_at'].toString().endsWith('Z') 
              ? json['created_at'] 
              : '${json['created_at']}Z') 
          : null,
    );
  }
}
