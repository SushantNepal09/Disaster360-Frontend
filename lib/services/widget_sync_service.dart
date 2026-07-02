import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disaster360/services/session_service.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/services/gis_cache_service.dart';
import 'package:flutter/foundation.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('com.example.disaster360/widget');

  static Future<void> updateWidgetData(ReportProvider reportProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = SessionService().currentUser;
      
      if (user == null || user.role.toLowerCase() != 'citizen') {
        await prefs.setBool('widget_has_report', false);
      } else {
        // Find latest report for user
        final userReports = reportProvider.reports
            .where((r) => r.userId == user.id)
            .toList();
            
        if (userReports.isEmpty) {
          await prefs.setBool('widget_has_report', false);
        } else {
          // Assuming the list is ordered or we pick the first one (most recent)
          // The backend usually returns latest first, but let's sort to be safe
          userReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final latest = userReports.first;
          
          await prefs.setBool('widget_has_report', true);
          await prefs.setString('widget_disaster_type', latest.disasterType);
          await prefs.setString('widget_report_status', latest.status);
          await prefs.setString('widget_rescue_status', latest.rescueTeam);
          
          // Determine location (Local Unit)
          String localUnit = "Location Unknown";
          try {
            // Check permission before getting position
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
              Position? position = await Geolocator.getLastKnownPosition();
              if (position != null) {
                final areas = await GisCacheService().identifyAdministrativeAreas(
                  position.latitude, 
                  position.longitude
                );
                if (areas.isNotEmpty && areas.length >= 3) {
                  localUnit = areas[2]; // Index 2 is Local Unit
                }
              }
            }
          } catch (e) {
            debugPrint("WidgetSyncService location error: $e");
          }
          await prefs.setString('widget_location', localUnit);
        }
      }
      
      // Trigger Native Widget Update
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint("Error syncing widget data: $e");
    }
  }

  static Future<void> clearWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('widget_has_report', false);
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint("Error clearing widget data: $e");
    }
  }
}
