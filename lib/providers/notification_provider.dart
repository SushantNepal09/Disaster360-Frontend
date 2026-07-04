import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:disaster360/services/notification_alert.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  
  int _offset = 0;
  final int _limit = 15;
  bool _hasMore = true;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    WidgetsBinding.instance.addObserver(this);
    
    // Fetch immediately
    fetchNotifications();

    // Fetch when a foreground notification arrives
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      FirebaseMessaging.onMessage.listen((_) {
        fetchNotifications();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> fetchNotifications({bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMore) return;
      _offset += _limit;
    } else {
      _offset = 0;
      _hasMore = true;
      _isLoading = true;
      notifyListeners();
    }
    
    _error = null;

    try {
      final response = await ApiService().get('/notifications/?limit=$_limit&offset=$_offset');
      if (response is List) {
        final newItems = response.map((json) => AppNotification.fromJson(json)).toList();
        if (newItems.length < _limit) {
          _hasMore = false;
        }
        if (loadMore) {
          _notifications.addAll(newItems);
        } else {
          _notifications = newItems;
        }
      } else {
        if (!loadMore) _error = 'Failed to load notifications';
      }
    } catch (e) {
      if (!loadMore) _error = 'An error occurred: $e';
    } finally {
      if (!loadMore) _isLoading = false;
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
