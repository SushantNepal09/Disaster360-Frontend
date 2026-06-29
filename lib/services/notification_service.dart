import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disaster360/services/session_service.dart';
import 'package:disaster360/services/gis_cache_service.dart';
import 'dart:io' show Platform;

class NotificationService {
  // Singleton pattern for easy access across the app
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Initializes FCM and Local Notifications
  Future<void> initialize() async {
    if (!kIsWeb && (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS)) {
      return;
    }
    
    _firebaseMessaging = FirebaseMessaging.instance;

    // 1. Request permissions for iOS and Android 13+
    await _requestPermission();

    // 2. Initialize Local Notifications (for foreground messages)
    await _initLocalNotifications();

    // 3. Get initial FCM token
    await _getToken();

    // 4. Listen to token refresh automatically
    _firebaseMessaging!.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      sendTokenToBackend(newToken);
    });

    // 5. Handle foreground notifications
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Handle background notifications (when app is in background but opened via tap)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 7. Handle terminated state notifications (when app is fully closed and opened via tap)
    final initialMessage = await _firebaseMessaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _requestPermission() async {
    if (_firebaseMessaging == null) return;
    await _firebaseMessaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Checks if notification permission is denied, and prompts the user to open settings.
  /// Uses SharedPreferences to avoid spamming the user if they hit cancel.
  Future<void> checkAndPromptPermission(BuildContext context) async {
    if (_firebaseMessaging == null) return;
    if (!kIsWeb && (!Platform.isAndroid && !Platform.isIOS)) return;

    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('hasPromptedForNotifications') ?? false;

    if (hasPrompted) return;

    NotificationSettings settings = await _firebaseMessaging!.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      // First, try standard request
      settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // If still denied, show manual prompt
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (!context.mounted) return;
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Text('Enable Notifications', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Disaster360 relies on notifications to send you critical disaster alerts near your location. Please enable notifications in your app settings.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.setBool('hasPromptedForNotifications', true);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Not Now', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
        );
      }
    }
  }


  Future<void> _initLocalNotifications() async {
    // Android initialization (requires default icon setup in AndroidManifest)
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle local notification tap when app is in foreground
        if (response.payload != null) {
          // Implement deep linking or state changes here using the payload
        }
      },
    );
  }

  Future<void> _getToken() async {
    if (_firebaseMessaging == null) return;
    try {
      _fcmToken = await _firebaseMessaging!.getToken();
      if (_fcmToken != null) {
        await sendTokenToBackend(_fcmToken!);
      }
    } catch (e) {
      debugPrint("❌ Error getting FCM token: $e");
    }
  }

  /// Revoke the FCM token (call this on logout)
  Future<void> clearToken() async {
    if (_firebaseMessaging == null) return;
    try {
      await _firebaseMessaging!.deleteToken();
      _fcmToken = null;
    } catch (e) {
      debugPrint("❌ Error deleting FCM token: $e");
    }
  }

  /// Sends the device token to the backend API endpoint
  Future<void> sendTokenToBackend(String token, {double? lat, double? lon, String? localUnit}) async {
    try {
      final sessionToken = SessionService().token;
      if (sessionToken == null) {
        return;
      }
      
      double? finalLat = lat;
      double? finalLon = lon;

      if (finalLat == null || finalLon == null) {
        try {
          final perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
            final pos = await Geolocator.getLastKnownPosition();
            if (pos != null) {
              finalLat = pos.latitude;
              finalLon = pos.longitude;
            }
          }
        } catch (e) {
          debugPrint("Geolocator fetch failed during token sync: $e");
        }
      }

      String? finalLocalUnit = localUnit;
      if (finalLocalUnit == null && finalLat != null && finalLon != null) {
         try {
            final areas = await GisCacheService().identifyAdministrativeAreas(finalLat, finalLon);
            if (areas.length >= 3) {
               finalLocalUnit = areas[2];
            }
         } catch (e) {
            debugPrint("Failed to resolve local unit for token: $e");
         }
      }

      // Use dotenv or fallback to a localhost URL
      final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
      final response = await http.put(
        Uri.parse('$apiUrl/auth/profile/device'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: jsonEncode({
          'fcm_token': token,
          if (finalLat != null) 'latitude': finalLat,
          if (finalLon != null) 'longitude': finalLon,
          if (finalLocalUnit != null && finalLocalUnit != "Unknown") 'local_unit': finalLocalUnit,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
      } else {
        debugPrint("⚠️ Failed to send FCM token to backend. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error sending FCM token to backend: $e");
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Implement navigation logic based on message.data here
    // e.g., mapping to DeepLinkRouter to redirect to an alert details page
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification!;
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'disaster360_high_importance_channel', // id
      'High Importance Notifications', // name
      channelDescription: 'This channel is used for important disaster alerts.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher', // Make sure this matches your app icon
    );
    const darwinPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    // Show the actual notification UI on top of the screen
    await _localNotificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }
}
