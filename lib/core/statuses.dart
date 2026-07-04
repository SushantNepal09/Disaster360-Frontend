import 'package:flutter/material.dart';

class IncidentStatus {
  static const String PENDING = "Pending";
  static const String VERIFIED = "Verified";
  static const String ASSIGNED = "Assigned";
  static const String IN_PROGRESS = "In Progress";
  static const String CONTROLLED = "Controlled";
  static const String CLOSED = "Closed";
  static const String REJECTED = "Rejected";
}

class AssignmentStatus {
  static const String ASSIGNED = "Assigned";
  static const String ACCEPTED = "Accepted";
  static const String IN_PROGRESS = "In Progress";
  static const String COMPLETED = "Completed";
  static const String REJECTED = "Rejected";
  static const String CANCELLED = "Cancelled";
}

class StatusMetadata {
  final String label;
  final Color color;
  final IconData icon;

  const StatusMetadata({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class StatusTheme {
  static final Map<String, StatusMetadata> incidentMetadata = {
    IncidentStatus.PENDING: StatusMetadata(
      label: "Pending",
      color: Colors.orange,
      icon: Icons.access_time,
    ),
    IncidentStatus.VERIFIED: StatusMetadata(
      label: "Verified",
      color: Colors.blue,
      icon: Icons.verified_user,
    ),
    IncidentStatus.ASSIGNED: StatusMetadata(
      label: "Rescue Assigned",
      color: Colors.purple,
      icon: Icons.group,
    ),
    IncidentStatus.IN_PROGRESS: StatusMetadata(
      label: "In Progress",
      color: Colors.deepPurple,
      icon: Icons.run_circle,
    ),
    IncidentStatus.CONTROLLED: StatusMetadata(
      label: "Controlled",
      color: Colors.green,
      icon: Icons.check_circle_outline,
    ),
    IncidentStatus.CLOSED: StatusMetadata(
      label: "Closed",
      color: Colors.grey,
      icon: Icons.lock,
    ),
    IncidentStatus.REJECTED: StatusMetadata(
      label: "Rejected",
      color: Colors.red,
      icon: Icons.cancel,
    ),
  };

  static final Map<String, StatusMetadata> assignmentMetadata = {
    AssignmentStatus.ASSIGNED: StatusMetadata(
      label: "Assigned",
      color: Colors.blue,
      icon: Icons.assignment,
    ),
    AssignmentStatus.ACCEPTED: StatusMetadata(
      label: "Accepted",
      color: Colors.cyan,
      icon: Icons.thumb_up,
    ),
    AssignmentStatus.IN_PROGRESS: StatusMetadata(
      label: "In Progress",
      color: Colors.orange,
      icon: Icons.directions_run,
    ),
    AssignmentStatus.COMPLETED: StatusMetadata(
      label: "Completed",
      color: Colors.green,
      icon: Icons.done_all,
    ),
    AssignmentStatus.REJECTED: StatusMetadata(
      label: "Rejected",
      color: Colors.red,
      icon: Icons.close,
    ),
    AssignmentStatus.CANCELLED: StatusMetadata(
      label: "Cancelled",
      color: Colors.grey,
      icon: Icons.block,
    ),
  };

  static StatusMetadata getIncidentTheme(String? status) {
    return incidentMetadata[status] ??
        StatusMetadata(
          label: status ?? "Unknown",
          color: Colors.grey,
          icon: Icons.help_outline,
        );
  }

  static StatusMetadata getAssignmentTheme(String? status) {
    return assignmentMetadata[status] ??
        StatusMetadata(
          label: status ?? "Unknown",
          color: Colors.grey,
          icon: Icons.help_outline,
        );
  }
}
