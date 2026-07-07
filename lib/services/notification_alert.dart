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
  adminAlert,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String time;
  final int? reportId;
  final String reporterName;
  final String disasterType;
  final String rescueStatus;
  final DateTime rawDate;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.reporterName,
    required this.disasterType,
    required this.rescueStatus,
    required this.rawDate,
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
      case 'admin_alert':
      case 'admin_notification':
      case 'disaster_alert':
        parsedType = NotificationType.adminAlert;
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

    DateTime parsedDate = DateTime.now();
    if (json['time'] != null) {
      try {
        parsedDate = DateTime.parse(json['time']).toLocal();
      } catch (e) {
        // ignore
      }
    }

    return AppNotification(
      id: json['id'].toString(),
      type: parsedType,
      title: (json['type'] == 'admin_alert' || json['type'] == 'admin_notification' || json['type'] == 'disaster_alert') ? "Admin's Alert Notification" : (json['title'] ?? 'Notification'),
      body: json['message'] ?? '',
      time: formattedTime,
      reporterName: (json['type'] == 'admin_alert' || json['type'] == 'admin_notification' || json['type'] == 'disaster_alert') ? 'Admin' : (json['reporter_name']?.toString() ?? 'Someone'),
      disasterType: json['disaster_type']?.toString() ?? 'Disaster',
      rescueStatus: json['status']?.toString() ?? 'Updated',
      rawDate: parsedDate,
      reportId: json['incident_id'] != null 
          ? int.tryParse(json['incident_id'].toString()) 
          : (json['report_id'] != null ? int.tryParse(json['report_id'].toString()) : null),
      isRead: json['is_read'] ?? false,
    );
  }

  String getFormattedMessage() {
    final name = reporterName.isNotEmpty ? reporterName : 'Someone';
    final dtype = disasterType.isNotEmpty ? disasterType : 'Disaster';
    
    switch (type) {
      case NotificationType.proximityAlert:
        return '$name reported $dtype in your area';
      case NotificationType.reportVerified:
        return "$name's $dtype report got verified";
      case NotificationType.statusUpdate:
        final stat = rescueStatus.isNotEmpty ? rescueStatus : 'Updated';
        if (stat.toLowerCase() == 'accepted') {
          return "$name's $dtype report was accepted by the rescue team";
        }
        return "$name's $dtype report was $stat by the rescue team";
      case NotificationType.reportRejected:
        return "$name's $dtype report was closed";
      case NotificationType.riskZone:
          return "Risk zone updated in your area";
      case NotificationType.adminAlert:
          return body;
    }
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
      case NotificationType.adminAlert:
        return 'ADMIN ALERT';
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
      case NotificationType.adminAlert:
        return const Color(0xFF9C27B0);
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
      case NotificationType.adminAlert:
        return Icons.campaign_rounded;
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
        final notifications = provider.notifications;
        
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        final todayList = <AppNotification>[];
        final yesterdayList = <AppNotification>[];
        final olderList = <AppNotification>[];

        for (var n in notifications) {
          final d = n.rawDate;
          final dateOnly = DateTime(d.year, d.month, d.day);
          if (dateOnly == today) {
            todayList.add(n);
          } else if (dateOnly == yesterday) {
            yesterdayList.add(n);
          } else {
            olderList.add(n);
          }
        }

        List<Widget> slivers = [];
        
        if (provider.isLoading && notifications.isEmpty) {
          slivers.add(
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                ),
              ),
            ),
          );
        } else if (notifications.isEmpty) {
          slivers.add(
            SliverFillRemaining(
              child: _buildEmptyState(),
            ),
          );
        } else {
          if (todayList.isNotEmpty) {
            slivers.add(_buildSectionHeader('Today'));
            slivers.add(_buildListSliver(todayList));
          }
          if (yesterdayList.isNotEmpty) {
            slivers.add(_buildSectionHeader('Yesterday'));
            slivers.add(_buildListSliver(yesterdayList));
          }
          if (olderList.isNotEmpty) {
            slivers.add(_buildSectionHeader('Older'));
            slivers.add(_buildListSliver(olderList));
          }
          
          if (provider.hasMore) {
            slivers.add(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: TextButton(
                      onPressed: () => provider.fetchNotifications(loadMore: true),
                      child: provider.isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange),
                            )
                          : const Text(
                              'Tap to View More Reports',
                              style: TextStyle(
                                color: AppColors.orange,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: _buildAppBar(context, provider),
          body: RefreshIndicator(
            color: AppColors.orange,
            backgroundColor: AppColors.bgSurface,
            onRefresh: () => provider.fetchNotifications(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildListSliver(List<AppNotification> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final isLast = index == items.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: _NotificationCard(
                notification: items[index],
                onTap: () => _showDetail(items[index]),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
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
    final firstLetter = notification.reporterName.isNotEmpty ? notification.reporterName[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: notification.accentColor.withOpacity(0.2),
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: notification.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.type == NotificationType.adminAlert 
                        ? "Admin's Alert Notification" 
                        : (notification.reporterName.isNotEmpty ? notification.reporterName : 'User'),
                    style: TextStyle(
                      color: isRead ? Colors.white70 : Colors.white,
                      fontSize: 15,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.getFormattedMessage(),
                    style: TextStyle(
                      color: isRead ? Colors.white54 : Colors.white70,
                      fontSize: 13.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.time,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
