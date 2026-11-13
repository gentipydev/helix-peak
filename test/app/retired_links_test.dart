import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/app.dart';
import 'package:helixpeek/features/home/presentation/screens/home_screen.dart';

/// DNA Replication was removed on 2026-11-13; links saved to it open home
/// rather than "Page not found".
void main() {
  for (final String link in <String>[
    '/replication',
    '/lab/replication',
    '/lab/replication/insulin',
  ]) {
    testWidgets('$link opens home', (WidgetTester tester) async {
      await tester.pumpWidget(const HelixPeekApp());
      await tester.pump();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', <String, Object?>{
            'location': link,
            'state': null,
          }),
        ),
        (ByteData? _) {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Page not found'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
