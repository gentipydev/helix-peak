import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/folding/presentation/fold_painter.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';

import 'shared/folding/folding_fixtures.dart';

// FOLD_SHOT_DIR=<dir> flutter test test/folding_render_check.dart
//
// The fold animation for a few proteins, drawn by the fold painter at the
// start and at the end of each of its four steps, in a phone-sized box.
void main() {
  final String directory = Platform.environment['FOLD_SHOT_DIR'] ?? '';

  testWidgets('each step of a few folds', (WidgetTester tester) async {
    if (directory.isEmpty) {
      markTestSkipped('Set FOLD_SHOT_DIR to write the frames.');
      return;
    }
    Directory(directory).createSync(recursive: true);
    const Key boundary = ValueKey<String>('fold-capture');
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final String slug in <String>[
      'prion',
      'insulin',
      'sod1',
      'glucagon',
    ]) {
      final ProteinTarget protein = target(slug);
      final FoldTimeline timeline = FoldTimeline(geometryOf(protein));
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
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
                    painter: FoldPainter(
                      timeline: timeline,
                      at: () => t,
                      inks: FoldInks.of(context, protein),
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
          final ui.Image image = await render.toImage(pixelRatio: 1);
          final ByteData data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          image.dispose();
          File('$directory/${slug}_${(t * 100).round()}.png')
              .writeAsBytesSync(data.buffer.asUint8List());
        });
      }
    }
  });
}
