import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:disaster360/auth/auth_wrapper.dart';
import 'package:disaster360/services/session_service.dart';
import 'package:disaster360/services/deep_link_router.dart';
import 'package:disaster360/services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:disaster360/colors.dart';

// Required by Firebase for background/terminated state messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId}");
}

class SplashScreen extends StatefulWidget {
  final DeepLinkRouter router;

  const SplashScreen({super.key, required this.router});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _isInitComplete = false;
  bool _isAnimationComplete = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(vsync: this);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isAnimationComplete = true;
        _checkAndNavigate();
        if (!_isInitComplete) {
          // If init is not complete, loop the animation
          _animationController.repeat();
        }
      }
    });

    // Start background initialization
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");

      // 1. SessionService
      final sessionService = SessionService();
      await sessionService.initialize();

      // 2. DeepLinkRouter
      await widget.router.checkInitialUri();
      widget.router.initialize();

      // 3. Firebase
      if (!kIsWeb &&
          (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        try {
          await Firebase.initializeApp();
          FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler,
          );
        } catch (e) {
          debugPrint("Firebase init error: $e");
        }
      } else {
        debugPrint(
          "Firebase is not supported or configured on this platform. Skipping.",
        );
      }

      // 4. Notification Service
      final notificationService = NotificationService();
      await notificationService.initialize();

      // 5. Supabase
      await Supabase.initialize(
        url: 'https://lavkbxvdjzyhznixpche.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhdmtieHZkanp5aHpuaXhwY2hlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2MDcyODIsImV4cCI6MjA5NTE4MzI4Mn0.hxsjmII5VEL3EwJX1IA1cp2RfjUXb-motsaUo4bHTiI',
      );

      _isInitComplete = true;
      _checkAndNavigate();
    } catch (e) {
      debugPrint("Initialization Error: $e");
      // Even if it fails, we should let the user through to handle errors gracefully in the app
      _isInitComplete = true;
      _checkAndNavigate();
    }
  }

  void _checkAndNavigate() {
    if (_isInitComplete && _isAnimationComplete) {
      if (mounted) {
        // Prevent repeating the navigation
        _isAnimationComplete = false;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine responsive sizing based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    // We want the animation to be prominent but not overwhelming.
    final animWidth = screenWidth > 600 ? 400.0 : screenWidth * 0.7;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFF2C2E33), // Center soft dark grey
              Color(0xFF0C0D0F), // Outer dark edges
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "DISASTER360",
              style: GoogleFonts.outfit(
                fontSize: screenWidth > 600 ? 46 : 38,
                fontWeight: FontWeight.w900,
                color: AppColors.successLight, // Professional Green
                letterSpacing: 2.0,
              ),
            ).animate().fade(duration: 800.ms).slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutQuart),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: animWidth,
              height: animWidth, // Add height constraint to prevent RenderFlex overflow
              child: Lottie.asset(
                'assets/animations/nepal_delivery.json',
                controller: _animationController,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _animationController.duration = composition.duration;
                  _animationController.forward();
                },
              ),
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: 48,
              height: 48,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                strokeWidth: 4.5,
                strokeCap: StrokeCap.round,
              ),
            ).animate().fade(delay: 400.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
