import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:disaster360/providers/auth_provider.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/auth/auth_wrapper.dart';
import 'package:disaster360/services/notification_service.dart';

class SecureLogout {
  /// Executes a scorched-earth cleanup of all user-specific memory,
  /// tokens, and caches, ensuring no leakage across sessions.
  static Future<void> performLogout(BuildContext context) async {
    // 1. Clear memory caches in Providers
    if (context.mounted) {
      context.read<ReportProvider>().clear();
      context.read<RescueProvider>().clear();
    }

    // 2. Clear Image Cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // 3. Clear Push Token
    await NotificationService().clearToken();

    // 4. Purge temporary files (e.g., offline photos named temp_*)
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final List<FileSystemEntity> entities = tempDir.listSync();
        for (var entity in entities) {
          if (entity is File && entity.path.contains('temp_')) {
            entity.deleteSync();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error cleaning temp directory: $e');
    }

    // 5. Finally clear secure session
    if (context.mounted) {
      await context.read<AuthProvider>().logout();

      // 6. Navigate to AuthWrapper which handles Login routing securely
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }
}
