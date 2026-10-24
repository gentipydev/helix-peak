import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome/chromosome_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import 'features/zoom/record_fixtures.dart';
import 'features/zoom/zoom_fixtures.dart';
import 'support/test_catalog.dart';

/// How long the zoom takes to record a frame, at every stop and inside
/// every step, for a few proteins: the work done on the UI thread each
/// frame, both layers, the scenes and what lies over them.
///
/// ZOOM_PAINT_TIMING=1 flutter test test/zoom_paint_timing_check.dart
///
/// It prints, for each protein, what each scene takes to build what it
/// caches (once, before its first frame: the screen does it while nothing
/// moves), then the median of many recordings of each moment, in
/// microseconds, and the worst moment. It measures the recording only, not
/// the rasterising a device does after; a moment that records slowly is one
/// to look at on a device. Without the variable it records each moment once
/// and checks nothing threw. The chromosome's line says how many vertices
/// its meshes hold at rest and on its way into the map.
void main() {
  final bool timing = Platform.environment['ZOOM_PAINT_TIMING'] == '1';
  testWidgets('the zoom records each frame without much work', (
    WidgetTester tester,
  ) async {
    late ZoomInks inks;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext context) {
            inks = ZoomInks.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    const Size size = Size(390, 600);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    final TextStyle caption = AppTheme.analysis.caption!;
    final int runs = timing ? 25 : 1;
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.hemoglobin,
      TestCatalog.dystrophin,
      TestCatalog.p53,
      TestCatalog.prion,
      TestCatalog.amylase,
      TestCatalog.sod1,
      TestCatalog.oxytocin,
      TestCatalog.cftr,
      TestCatalog.ubiquitin,
      TestCatalog.bySlug('recoverin')!,
      TestCatalog.bySlug('phospholamban')!,
      TestCatalog.bySlug('uromodulin')!,
      TestCatalog.bySlug('cystatinb')!,
      TestCatalog.bySlug('tyrp1')!,
      TestCatalog.bySlug('thyroglobulin')!,
      TestCatalog.bySlug('cyp17a1')!,
      TestCatalog.somatotropin,
      TestCatalog.app,
      TestCatalog.relaxin,
    ]) {
      final ZoomStage stage = ZoomStage(
        ZoomSubject(track: locusOf(t), record: recordOf(t)),
      );
      final ZoomDepth depth = stage.depth;
      final StringBuffer built = StringBuffer();
      for (final ZoomStop stop in ZoomStop.values) {
        final Stopwatch watch = Stopwatch()..start();
        stage.prepare(stop, inks);
        built.write('${stop.name}: ${watch.elapsedMicroseconds}  ');
      }
      final Map<String, double> moments = <String, double>{
        for (final ZoomStop stop in ZoomStop.values) ...<String, double>{
          stop.name: depth.depthOf(stop),
          if (stop != ZoomStop.dna)
            for (final double s in <double>[
              0.25,
              0.5,
              0.75,
              // Closer through the chromosome's two steps, where it is
              // built afresh each frame, and the cell's, where its parts
              // come up and go.
              if (stop == ZoomStop.tissue) ...<double>[0.9],
              if (stop == ZoomStop.cell) ...<double>[0.1],
              if (stop == ZoomStop.nucleus) ...<double>[0.02, 0.1, 0.9, 0.98],
              if (stop == ZoomStop.chromosome) ...<double>[
                0.02,
                0.1,
                0.2,
                0.35,
              ],
            ])
              '${stop.name}+${(s * 100).round()}':
                  depth.depthOf(stop) + s * depth.travelOf(stop.index),
        },
      };
      String worst = '';
      double slowest = 0;
      final StringBuffer table = StringBuffer();
      for (final MapEntry<String, double> moment in moments.entries) {
        final ZoomPainter painter = ZoomPainter(
          stage: stage,
          at: () => moment.value,
          inks: inks,
          labels: labels,
        );
        final ZoomOverlayPainter overlay = ZoomOverlayPainter(
          stage: stage,
          at: () => moment.value,
          inks: inks,
          labels: labels,
          caption: caption,
          credit: 'credit',
          clock: () => 3.3,
          dwell: () => 0.5,
        );
        final List<int> times = <int>[];
        for (int r = 0; r < runs; r++) {
          final Stopwatch watch = Stopwatch()..start();
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          painter.paint(canvas, size);
          overlay.paint(canvas, size);
          recorder.endRecording().dispose();
          watch.stop();
          times.add(watch.elapsedMicroseconds);
        }
        expect(tester.takeException(), isNull, reason: moment.key);
        times.sort();
        final int median = times[times.length ~/ 2];
        table.write('${moment.key}: $median  ');
        if (median > slowest) {
          slowest = median.toDouble();
          worst = moment.key;
        }
      }
      if (timing) {
        final ChromosomeScene chromosome =
            stage.scenes[ZoomStop.chromosome.index] as ChromosomeScene;
        int vertices = 0;
        for (final ({Float32List positions, Int32List colours}) mesh
            in ChromosomeArt(chromosome.form, inks).meshData) {
          vertices += mesh.colours.length;
        }
        // ignore: avoid_print
        print(
          '${t.slug}: slowest $worst ${slowest.round()} µs\n'
          '  built: $built\n  $table\n'
          '  chromosome: $vertices vertices at rest, '
          '${chromosome.tubeIn(inks).vertexCount} on its way into the map',
        );
      }
    }
  });
}
