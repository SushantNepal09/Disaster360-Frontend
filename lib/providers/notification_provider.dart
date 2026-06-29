import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:disaster360/services/notification_alert.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService().get('/notifications/');
      if (response is List) {
        _notifications = response.map((json) => AppNotification.fromJson(json)).toList();
      } else {
        _error = 'Failed to load notifications';
      }
    } catch (e) {
      _error = 'An error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    // Optimistic update
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();

      try {
        await ApiService().patch('/notifications/$id/read', body: {});
      } catch (e) {
        // Revert on failure
        _notifications[index].isRead = false;
        notifyListeners();
        debugPrint('Failed to mark notification $id as read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIndices = <int>[];
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        unreadIndices.add(i);
        _notifications[i].isRead = true;
      }
    }
    
    if (unreadIndices.isEmpty) return;
    notifyListeners();

    try {
      await ApiService().patch('/notifications/action/mark-all-read', body: {});
    } catch (e) {
      // Revert on failure
      for (final i in unreadIndices) {
        _notifications[i].isRead = false;
      }
      notifyListeners();
      debugPrint('Failed to mark all notifications as read: $e');
    }
  }
}
