import 'package:disaster360/colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/providers/notification_provider.dart';
import 'package:intl/intl.dart';
import 'package:disaster360/services/deep_link_router.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

enum NotificationType {
  proximityAlert,
  reportVerified,
  statusUpdate,
  riskZone,
  reportRejected,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String time;
  final int? reportId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.reportId,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType parsedType;
    switch (json['type']) {
      case 'incident_created':
      case 'earthquake_alert':
        parsedType = NotificationType.proximityAlert;
        break;
      case 'incident_verified':
        parsedType = NotificationType.reportVerified;
        break;
      case 'rescue_update':
      case 'rescue_assigned':
        parsedType = NotificationType.statusUpdate;
        break;
      case 'incident_closed':
        parsedType = NotificationType.reportRejected;
        break;
      default:
        parsedType = NotificationType.proximityAlert;
    }

    // Format relative time
    String formattedTime = 'Just now';
    if (json['time'] != null) {
      try {
        final dateTime = DateTime.parse(json['time']).toLocal();
        final diff = DateTime.now().difference(dateTime);
        if (diff.inMinutes < 60) {
          formattedTime = diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes} min ago';
        } else if (diff.inHours < 24) {
          formattedTime = '${diff.inHours} hours ago';
        } else if (diff.inDays < 7) {
          formattedTime = '${diff.inDays} days ago';
        } else {
          formattedTime = DateFormat('MMM d, yyyy').format(dateTime);
        }
      } catch (e) {
        // ignore
      }
    }

    return AppNotification(
      id: json['id'].toString(),
      type: parsedType,
      title: json['title'] ?? 'Notification',
      body: json['message'] ?? '',
      time: formattedTime,
      reportId: json['incident_id'] != null 
          ? int.tryParse(json['incident_id'].toString()) 
          : (json['report_id'] != null ? int.tryParse(json['report_id'].toString()) : null),
      isRead: json['is_read'] ?? false,
    );
  }

  String get typeLabel {
    switch (type) {
      case NotificationType.proximityAlert:
        return 'PROXIMITY ALERT';
      case NotificationType.reportVerified:
        return 'REPORT VERIFIED';
      case NotificationType.statusUpdate:
        return 'STATUS UPDATE';
      case NotificationType.riskZone:
        return 'RISK ZONE UPDATE';
      case NotificationType.reportRejected:
        return 'REPORT REJECTED';
    }
  }

  Color get accentColor {
    switch (type) {
      case NotificationType.proximityAlert:
        return AppColors.danger;
      case NotificationType.reportVerified:
        return AppColors.success;
      case NotificationType.statusUpdate:
        return AppColors.warning;
      case NotificationType.riskZone:
        return AppColors.info;
      case NotificationType.reportRejected:
        return AppColors.warning;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.proximityAlert:
        return Icons.warning_amber_rounded;
      case NotificationType.reportVerified:
        return Icons.verified_outlined;
      case NotificationType.statusUpdate:
        return Icons.update_rounded;
      case NotificationType.riskZone:
        return Icons.location_on_outlined;
      case NotificationType.reportRejected:
        return Icons.cancel_outlined;
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }


  void _showDetail(AppNotification notification) {
    if (!notification.isRead) {
      context.read<NotificationProvider>().markAsRead(notification.id);
    }
    
    if (notification.reportId != null) {
      // Direct deep link to report on dashboard
      DeepLinkRouter().routeToReport(notification.reportId!);
    } else {
      // Fallback for notifications without a specific report
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.bgSurface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _NotificationDetailSheet(notification: notification),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: _buildAppBar(context, provider),
          body: provider.isLoading && provider.notifications.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                  ),
                )
              : provider.notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: AppColors.orange,
                      backgroundColor: AppColors.bgSurface,
                      onRefresh: () => provider.fetchNotifications(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: provider.notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _NotificationCard(
                          notification: provider.notifications[i],
                          onTap: () => _showDetail(provider.notifications[i]),
                        ),
                      ),
                    ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, NotificationProvider provider) {
    final unreadCount = provider.unreadCount;
    return AppBar(
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      titleSpacing: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
      ),
      title: Row(
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (unreadCount > 0)
          TextButton(
            onPressed: () => provider.markAllAsRead(),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }



  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: Colors.white24,
            size: 52,
          ),
          SizedBox(height: 14),
          Text(
            'No notifications yet',
            style: TextStyle(color: Colors.white38, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Notification card ────────────────────────────────────────────────────────
//
// ROOT CAUSE OF BLANK CARDS:
// Flutter 3.x cannot render a BoxDecoration that has BOTH:
//   • borderRadius (e.g. BorderRadius.circular(14))
//   • a non-uniform Border (e.g. left: 3.5px, others: 0.8px)
// When this combination is detected, Flutter clips the child paint area
// to zero — the card background color shows (so the border is visible)
// but all child widgets are invisible.
//
// FIX: Split into two layers using a Stack:
//   1. Outer Container — uniform Border.all(0.8px) + borderRadius → no clip issue
//   2. Positioned Container — the colored left accent bar drawn on top
// This is visually identical to the original design.

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final accent = notification.accentColor;
    final accentDimmed = Color.fromRGBO(
      accent.red,
      accent.green,
      accent.blue,
      0.35,
    );
    final accentCurrent = isRead ? accentDimmed : accent;
    final accentBg = Color.fromRGBO(
      accent.red,
      accent.green,
      accent.blue,
      0.12,
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Layer 1: Card with uniform border (renders children correctly)
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Padding(
              // left: 17 = 3.5px accent bar + 13.5px inner gap ≈ original 14px feel
              padding: const EdgeInsets.only(
                left: 17,
                right: 14,
                top: 14,
                bottom: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon bubble
                  Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      notification.icon,
                      color: accentCurrent,
                      size: 18,
                    ),
                  ),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type label
                        Text(
                          notification.typeLabel,
                          style: TextStyle(
                            color: accentCurrent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Title
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: isRead ? Colors.white70 : Colors.white,
                            fontSize: 13.5,
                            fontWeight:
                                isRead ? FontWeight.w400 : FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Time row + unread dot
                        Row(
                          children: [
                            Text(
                              notification.time,
                              style: TextStyle(
                                color: isRead ? Colors.white54 : Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Layer 2: Colored left accent bar (drawn over the card, no border conflicts)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: accentCurrent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail bottom sheet ──────────────────────────────────────────────────────

class _NotificationDetailSheet extends StatelessWidget {
  final AppNotification notification;

  const _NotificationDetailSheet({required this.notification});

  @override
  Widget build(BuildContext context) {
    final accent = notification.accentColor;
    final accentBg = Color.fromRGBO(
      accent.red,
      accent.green,
      accent.blue,
      0.12,
    );
    final accentBorder = Color.fromRGBO(
      accent.red,
      accent.green,
      accent.blue,
      0.35,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(notification.icon, color: accent, size: 13),
                const SizedBox(width: 6),
                Text(
                  notification.typeLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            notification.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Body
          Text(
            notification.body,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),

          // Timestamp
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white24, size: 13),
              const SizedBox(width: 6),
              Text(
                notification.time,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dismiss button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Dismiss',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
