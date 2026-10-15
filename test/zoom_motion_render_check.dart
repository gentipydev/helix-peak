import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/zoom/domain/transcription.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import 'features/gene_lookup/anatomy/anatomy_fixture.dart';
import 'features/zoom/record_fixtures.dart';
import 'features/zoom/zoom_fixtures.dart';
import 'support/test_catalog.dart';

/// The zoom's canvas in motion, as numbered PNGs to look at or to make into
/// an animation: what moves at rest and what moves in a step, drawn at the
/// depth and the ambient clock of each frame.
///
/// ZOOM_MOTION_SHOTS=/tmp/motion flutter test test/zoom_motion_render_check.dart
///
/// ZOOM_GENES=insulin,dystrophin names the proteins (those two by default).
/// ZOOM_MOTION picks the takes, by name, comma separated: `gene` (one pass
/// of the gene being read, at its stop, 10 frames a second), `arrive` (the
/// step from the band to the gene, then two seconds there, 30 frames a
/// second), `dive` (the step from the gene to the DNA as the screen flies
/// it, then a second there, 30 frames a second, the clock running on);
/// `gene,dive` by default. ZOOM_MOTION_WIDTH sets the canvas's width (390).
/// Without ZOOM_MOTION_SHOTS it draws nothing and passes.
void main() {
  final String directory = Platform.environment['ZOOM_MOTION_SHOTS'] ?? '';
  final String genes = Platform.environment['ZOOM_GENES'] ?? '';
  final String takes = Platform.environment['ZOOM_MOTION'] ?? 'gene,dive';
  final double width =
      double.tryParse(Platform.environment['ZOOM_MOTION_WIDTH'] ?? '') ?? 390;
  final List<ProteinTarget> targets = genes.isEmpty
      ? <ProteinTarget>[TestCatalog.insulin, TestCatalog.dystrophin]
      : <ProteinTarget>[
          for (final String slug in genes.split(','))
            TestCatalog.bySlug(slug.trim())!,
        ];

  setUpAll(loadAppFonts);

  for (final ProteinTarget target in targets) {
    testWidgets('the zoom of ${target.slug} in motion', (
      WidgetTester tester,
    ) async {
      if (directory.isEmpty) {
        return;
      }
      final Size canvas = Size(width, 560);
      await tester.binding.setSurfaceSize(canvas);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(target), record: recordOf(target)),
      );
      final ZoomDepth depth = stage.depth;
      // Each frame: its depth, its ambient clock and its dwell.
      final List<(String, double, double)> frames = <(String, double, double)>[
        if (takes.contains('gene'))
          for (int f = 0; f < Transcription.passSeconds * 10; f++)
            ('gene', depth.depthOf(ZoomStop.gene), f / 10),
        if (takes.contains('arrive'))
          ...() {
            final double from = depth.depthOf(ZoomStop.band);
            final double to = depth.depthOf(ZoomStop.gene);
            final ZoomFlight flight = ZoomFlight(from, to);
            final int count = (flight.duration.inMicroseconds / 1e6 * 30)
                .ceil();
            return <(String, double, double)>[
              for (int f = 0; f <= count; f++)
                (
                  'arrive',
                  flight.at(Duration(microseconds: (f * 1e6 / 30).round())),
                  f / 30,
                ),
              // And two seconds at the gene, read.
              for (int f = 1; f <= 60; f++) ('arrive', to, (count + f) / 30),
            ];
          }(),
        if (takes.contains('dive'))
          ...() {
            final double from = depth.depthOf(ZoomStop.gene);
            final double to = depth.depthOf(ZoomStop.dna);
            final ZoomFlight flight = ZoomFlight(
              from,
              to,
              minimum: depth.leastFlight(from, to),
              cruise: depth.cruiseOf(from, to),
            );
            final int count = (flight.duration.inMicroseconds / 1e6 * 30)
                .ceil();
            return <(String, double, double)>[
              for (int f = 0; f <= count; f++)
                (
                  'dive',
                  flight.at(Duration(microseconds: (f * 1e6 / 30).round())),
                  3 + f / 30,
                ),
              // And a second at the DNA, its helix turning.
              for (int f = 1; f <= 30; f++) ('dive', to, 3 + (count + f) / 30),
            ];
          }(),
      ];
      final Directory out = Directory(directory)..createSync(recursive: true);
      final Map<String, int> numbered = <String, int>{};
      const Key key = ValueKey<String>('zoom-motion-capture');
      for (final (String take, double d, double clock) in frames) {
        final int n = numbered[take] = (numbered[take] ?? -1) + 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.analysis,
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (BuildContext context) {
                final ThemeData theme = Theme.of(context);
                final ZoomInks inks = ZoomInks.of(context);
                final TextStyle labels = theme.textTheme.labelSmall!;
                // A painter of its own each frame: one that changes only its
                // clock is not asked to paint again.
                return RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    key: ValueKey<String>('$take $n'),
                    color: inks.ground,
                    child: Stack(
                      children: <Widget>[
                        CustomPaint(
                          size: canvas,
                          painter: ZoomPainter(
                            stage: stage,
                            at: () => d,
                            inks: inks,
                            labels: labels,
                          ),
                        ),
                        CustomPaint(
                          size: canvas,
                          painter: ZoomOverlayPainter(
                            stage: stage,
                            at: () => d,
                            clock: () => clock,
                            dwell: () => clock,
                            inks: inks,
                            labels: labels,
                            caption: theme.caption ?? labels,
                            credit: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.runAsync(() async {
          final RenderRepaintBoundary boundary = tester.renderObject(
            find.byKey(key),
          );
          final ui.Image image = await boundary.toImage(pixelRatio: 2);
          final ByteData data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          image.dispose();
          File(
            '${out.path}/${target.slug}-$take-${n.toString().padLeft(3, '0')}.png',
          ).writeAsBytesSync(data.buffer.asUint8List());
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
