import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/providers/auth_provider.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/providers/notification_provider.dart';

import 'package:disaster360/services/deep_link_router.dart';
import 'package:disaster360/services/notification_service.dart';
import 'package:disaster360/splash_screen.dart';



import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate router synchronously so it can be provided to the app
  final router = DeepLinkRouter();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => RescueProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: DisasterApp(router: router),
    ),
  );
}

class DisasterApp extends StatelessWidget {
  final DeepLinkRouter router;

  const DisasterApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: router.navigatorKey, // Injected for global routing
      title: 'Disaster360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: SplashScreen(router: router),
    );
  }
}
