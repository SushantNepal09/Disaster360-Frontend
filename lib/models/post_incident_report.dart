class PostIncidentReportAttachment {
  final int id;
  final String originalFilename;
  final String fileUrl;
  final int fileSize;
  final String? uploadedAt;

  PostIncidentReportAttachment({
    required this.id,
    required this.originalFilename,
    required this.fileUrl,
    required this.fileSize,
    this.uploadedAt,
  });

  factory PostIncidentReportAttachment.fromJson(Map<String, dynamic> json) {
    return PostIncidentReportAttachment(
      id: json['id'],
      originalFilename: json['original_filename'],
      fileUrl: json['file_url'],
      fileSize: json['file_size'],
      uploadedAt: json['uploaded_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_filename': originalFilename,
      'file_url': fileUrl,
      'file_size': fileSize,
      'uploaded_at': uploadedAt,
    };
  }
}

class PostIncidentReport {
  final int? id;
  final String? createdAt;
  final List<PostIncidentReportAttachment> attachments;

  PostIncidentReport({
    this.id,
    this.createdAt,
    this.attachments = const [],
  });

  factory PostIncidentReport.fromJson(Map<String, dynamic> json) {
    return PostIncidentReport(
      id: json['id'],
      createdAt: json['created_at'],
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((a) => PostIncidentReportAttachment.fromJson(a))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt,
    };
  }
}
