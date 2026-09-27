import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/ribosome/domain/one_cycle.dart';
import 'package:helixpeek/features/lab/ribosome/domain/translation_timeline.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/ribosome_screen.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/translation_ending.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/translation_painter.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';
import 'support/test_catalog.dart';

// RIBOSOME_SHOT_DIR=<dir> flutter test test/ribosome_render_check.dart
//
// One elongation cycle of insulin, drawn by the translation painter: one PNG
// at the start of the cycle, then one at the end of each of its four phases.
// Then the whole run's landmarks, for insulin and for dystrophin, whose chain
// is far too long to draw whole.
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

  testWidgets('the whole run, at its landmarks', (WidgetTester tester) async {
    if (directory.isEmpty) {
      markTestSkipped('Set RIBOSOME_SHOT_DIR to write the frames.');
      return;
    }
    Directory(directory).createSync(recursive: true);
    const Key boundary = ValueKey<String>('ribosome-run');
    await tester.binding.setSurfaceSize(const Size(390, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (String name, String gene) in <(String, String)>[
      ('insulin', 'ins'),
      ('dystrophin', 'dmd'),
    ]) {
      final TranslationTimeline translation = TranslationTimeline(
        name == 'insulin' ? insulin() : _record(gene),
      );
      final Map<String, double> moments = <String, double>{
        'first-out': translation.firstExit ?? 0.5,
        'srp-open': translation.srpWindow?.$1 ?? 0.6,
        'middle': translation.beatStart(translation.beats * 0.5),
        'stop': translation.beatStart(translation.firstTerminationBeat + 0.5),
        'released': translation.beatStart(
          translation.firstTerminationBeat + 1.99,
        ),
      };
      for (final MapEntry<String, double> moment in moments.entries) {
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
                      at: () => moment.value,
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
          File('$directory/run-$name-${moment.key}.png')
              .writeAsBytesSync(data.buffer.asUint8List());
        });
      }
    }
  });

  testWidgets('the ending: the chain flying home, and the page it lands on', (
    WidgetTester tester,
  ) async {
    if (directory.isEmpty) {
      markTestSkipped('Set RIBOSOME_SHOT_DIR to write the frames.');
      return;
    }
    Directory(directory).createSync(recursive: true);
    const Key boundary = ValueKey<String>('ribosome-ending-capture');
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: AppTheme.analysis,
          debugShowCheckedModeBanner: false,
          home: RibosomeScreen(target: TestCatalog.insulin, record: insulin()),
        ),
      ),
    );
    await tester.pump();
    tester.widget<TransportBar>(find.byType(TransportBar)).controller.seek(1);
    await tester.pump();
    Future<void> capture(String name) async {
      final RenderRepaintBoundary render = tester.renderObject(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final ui.Image image = await render.toImage(pixelRatio: 2);
        final ByteData data = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        image.dispose();
        File('$directory/ending-$name.png')
            .writeAsBytesSync(data.buffer.asUint8List());
      });
    }

    await tester.pump(TranslationEnding.flight * 0.35);
    await capture('flight');
    await tester.pump(TranslationEnding.flight);
    await tester.pump();
    await capture('landed');
  });
}

GeneRecord _record(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();
