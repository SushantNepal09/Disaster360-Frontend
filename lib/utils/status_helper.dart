import 'package:flutter/material.dart';
import 'package:disaster360/colors.dart';

class StatusHelper {
  /// Returns the formatted status string (Title Cased)
  static String getStatusText(String status) {
    if (status.isEmpty) return 'Unknown';
    
    // Normalize to lowercase for comparison
    final s = status.toLowerCase().trim();
    
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'assigned':
        return 'Assigned';
      case 'acknowledged':
        return 'Acknowledged';
      case 'rescue in progress':
      case 'in_progress':
        return 'Rescue in Progress';
      case 'resolved':
        return 'Resolved';
      case 'resolved (report available)':
        return 'Resolved (Report Available)';
      default:
        // Capitalize first letter as fallback
        return '${s[0].toUpperCase()}${s.substring(1)}';
    }
  }

  /// Returns the correct AppColors based on the status
  static Color getStatusColor(String status) {
    if (status.isEmpty) return Colors.grey;

    final s = status.toLowerCase().trim();
    
    switch (s) {
      case 'pending':
        return AppColors.warning; // Yellow
      case 'verified':
        return AppColors.success; // Green
      case 'rejected':
        return AppColors.danger; // Red
      case 'assigned':
        return AppColors.orange; // Orange
      case 'acknowledged':
        return AppColors.warning; // Yellow
      case 'rescue in progress':
      case 'in_progress':
        return AppColors.info; // Cyan / Lite Blue
      case 'resolved':
      case 'resolved (report available)':
        return AppColors.success; // Green
      default:
        return Colors.grey;
    }
  }

  /// Returns a complementary background color (usually 10-15% opacity of main color)
  static Color getStatusBgColor(String status) {
    return getStatusColor(status).withOpacity(0.15);
  }

  /// Returns an appropriate icon based on the status
  static IconData getStatusIcon(String status) {
    if (status.isEmpty) return Icons.help_outline_rounded;

    final s = status.toLowerCase().trim();
    
    switch (s) {
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'verified':
        return Icons.verified_user_rounded; // or check_circle
      case 'rejected':
        return Icons.cancel_rounded;
      case 'assigned':
        return Icons.assignment_ind_rounded;
      case 'acknowledged':
        return Icons.thumb_up_alt_rounded;
      case 'rescue in progress':
      case 'in_progress':
        return Icons.directions_run_rounded;
      case 'resolved':
      case 'resolved (report available)':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
