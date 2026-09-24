import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';

// TRANSLATION_SHOT_DIR=/tmp/translation flutter test test/translation_render_check.dart
// Captures the actual screen at a fixed cadence, suitable for a filmstrip or GIF.
void main() {
  setUpAll(loadAppFonts);
  final String directory = Platform.environment['TRANSLATION_SHOT_DIR'] ?? '';
  for (final double width in <double>[390, 320]) {
    testWidgets('translation frames at ${width.toInt()}px', (
      WidgetTester tester,
    ) async {
      const Key boundaryKey = ValueKey<String>('translation-capture');
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: AppTheme.analysis,
            debugShowCheckedModeBanner: false,
            home: AnatomyScreen(target: ProteinCatalog.insulin, record: insulin()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> swipe(bool forward) async {
        final Rect screen = tester.getRect(find.byType(AnatomyScreen));
        await tester.dragFrom(
          Offset(screen.center.dx, screen.bottom - 40),
          Offset(forward ? -160 : 160, 0),
        );
        await tester.pump();
      }

      Future<void> capture(String name) async {
        final RenderRepaintBoundary boundary = tester.renderObject(
          find.byKey(boundaryKey),
        );
        await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage(pixelRatio: 2);
          final ByteData data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          image.dispose();
          File('$directory/${width.toInt()}-$name.png')
              .writeAsBytesSync(data.buffer.asUint8List());
        });
      }

      await swipe(true);
      await tester.pumpAndSettle();
      await capture('mrna');
      await swipe(true);
      final int frames =
          (AnatomyCanvas.durationOf(StageKind.protein).inMilliseconds / 50)
              .ceil();
      for (int frame = 0; frame <= frames; frame++) {
        if (frame > 0) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await capture('forward-${frame.toString().padLeft(2, '0')}');
      }
      await tester.pumpAndSettle();
      await capture('protein');
      await swipe(false);
      for (int frame = 0; frame <= frames; frame++) {
        if (frame > 0) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await capture('reverse-${frame.toString().padLeft(2, '0')}');
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, skip: directory.isEmpty);
  }
}
