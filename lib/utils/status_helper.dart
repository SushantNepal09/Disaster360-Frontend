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
        return 'Pending Verification';
      case 'verified':
        return 'Verified';
      case 'assigned':
        return 'Rescue Team Assigned';
      case 'accepted':
      case 'in progress':
      case 'rescue in progress':
        return 'Rescue in Progress';
      case 'completed':
      case 'controlled':
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'rejected':
      case 'cancelled':
        return 'Rejected / Cancelled';
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
      case 'assigned':
        return AppColors.orange; // Orange
      case 'accepted':
      case 'in progress':
      case 'rescue in progress':
        return AppColors.info; // Cyan / Lite Blue
      case 'completed':
      case 'controlled':
      case 'resolved':
      case 'closed':
        return AppColors.success; // Green
      case 'rejected':
      case 'cancelled':
        return AppColors.danger; // Red
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
        return Icons.verified_user_rounded;
      case 'assigned':
        return Icons.assignment_ind_rounded;
      case 'accepted':
      case 'in progress':
      case 'rescue in progress':
        return Icons.directions_run_rounded;
      case 'completed':
      case 'controlled':
      case 'resolved':
      case 'closed':
        return Icons.task_alt_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
