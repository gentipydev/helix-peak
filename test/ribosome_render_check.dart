import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/ribosome/domain/one_cycle.dart';
import 'package:helixpeek/features/lab/ribosome/domain/translation_timeline.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/translation_painter.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';

// RIBOSOME_SHOT_DIR=<dir> flutter test test/ribosome_render_check.dart
//
// One elongation cycle of insulin, drawn by the translation painter: one PNG
// at the start of the cycle, then one at the end of each of its four phases.
void main() {
  setUpAll(loadAppFonts);
  final String directory = Platform.environment['RIBOSOME_SHOT_DIR'] ?? '';

  testWidgets('one elongation cycle, one frame per phase', (
    WidgetTester tester,
  ) async {
    if (directory.isEmpty) {
      markTestSkipped('Set RIBOSOME_SHOT_DIR to write the frames.');
      return;
    }
    Directory(directory).createSync(recursive: true);
    final TranslationTimeline translation = TranslationTimeline(insulin());
    final OneCycle cycle = OneCycle(translation, codon: 2);
    const Key boundary = ValueKey<String>('ribosome-capture');
    await tester.binding.setSurfaceSize(const Size(390, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> capture(String name, double t) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: AppTheme.analysis,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => CustomPaint(
                  size: Size.infinite,
                  painter: TranslationPainter(
                    timeline: translation,
                    at: () => cycle.fullT(t),
                    inks: TranslationInks.of(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final RenderRepaintBoundary render = tester.renderObject(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final ui.Image image = await render.toImage(pixelRatio: 2);
        final ByteData data = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        image.dispose();
        File('$directory/$name.png')
            .writeAsBytesSync(data.buffer.asUint8List());
      });
    }

    final List<PhaseMark> phases = cycle.phases;
    await capture('0-start', 0);
    for (int i = 0; i < phases.length; i++) {
      final double end = i + 1 < phases.length ? phases[i + 1].t : 1;
      await capture('${i + 1}-${phases[i].captionKey}', end - 1e-6);
    }
  });
}
