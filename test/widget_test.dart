// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:disaster360/main.dart';
import 'package:disaster360/services/deep_link_router.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    final router = DeepLinkRouter();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(DisasterApp(router: router));

    // Verify that the app builds and shows the home screen.
    // Note: since this is a complex app with routers, we may just test if it mounts.
    expect(find.byType(DisasterApp), findsOneWidget);
  });
}
