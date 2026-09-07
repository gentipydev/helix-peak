import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/features/home/presentation/screens/home_screen.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(File(path).readAsBytesSync().buffer),
      ),
    );
  }
  await loader.load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary =
      tester.firstRenderObject(find.byType(RepaintBoundary))
          as RenderRepaintBoundary;

  // Both of these resolve on the real event loop, which the fake clock inside
  // testWidgets never pumps. Awaited directly they hang until the whole test
  // times out — the file still lands, ten minutes late, and the run is marked
  // failed. runAsync hands them a loop that actually turns.
  final ByteData? bytes = await tester.runAsync<ByteData>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!;
  });

  File('${Platform.environment['SHOT_DIR']}/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    await _loadFont('SpaceGrotesk', <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
      'assets/fonts/SpaceGrotesk-Bold.ttf',
    ]);
    await _loadFont('JetBrainsMono', <String>[
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Medium.ttf',
    ]);
  });

  testWidgets('home screen', (WidgetTester tester) async {
    if ((Platform.environment['SHOT_DIR'] ?? '').isEmpty) {
      markTestSkipped('set SHOT_DIR to capture the screens');
      return;
    }

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await _capture(tester, 'home');
  });
}
