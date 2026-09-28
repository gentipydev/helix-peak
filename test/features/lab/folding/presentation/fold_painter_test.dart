import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/folding/presentation/fold_painter.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';
import 'package:helixpeek/shared/structure/structure_model.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../shared/folding/folding_fixtures.dart';
import '../../../../support/test_catalog.dart';

void main() {
  const Size box = Size(390, 520);

  test('the last frame lands where the fold page’s camera puts each CA', () {
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldGeometry geometry = geometryOf(protein);
      final FoldingTrack track = geometry.track;
      final FoldFrame last = FoldTimeline(geometry).stateAt(1);
      final FoldProjector lens = FoldProjector(track, box);
      // The page's own camera, built as StructureView builds it, from the
      // model's bounds.
      final camera = structureCamera(
        vm.Aabb3.minMax(
          vm.Vector3(
            track.boundsMin.$1,
            track.boundsMin.$2,
            track.boundsMin.$3,
          ),
          vm.Vector3(
            track.boundsMax.$1,
            track.boundsMax.$2,
            track.boundsMax.$3,
          ),
        ),
      );
      for (int i = 0; i < geometry.length; i++) {
        final ModelPoint? ca = geometry.drawn[i].ca;
        if (ca == null) {
          continue;
        }
        final Offset? drawn = lens.screenOf(
          vm.Vector3(
            last.positions[3 * i],
            last.positions[3 * i + 1],
            last.positions[3 * i + 2],
          ),
          vm.Quaternion.identity(),
        );
        final Offset? page = camera.worldToScreen(
          vm.Vector3(ca.$1, ca.$2, ca.$3),
          box,
        );
        expect(
          drawn,
          page,
          reason: '${protein.slug} ${geometry.drawn[i].number}',
        );
      }
    }
  });

  test('the whole fold stays inside the box, every step of the way', () {
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldGeometry geometry = geometryOf(protein);
      final FoldTimeline timeline = FoldTimeline(geometry);
      final FoldProjector lens = FoldProjector(geometry.track, box);
      // Every step, and the loose residues at any time on the screen's clock.
      for (int step = 0; step <= 40; step++) {
        final double t = step / 40;
        final FoldFrame frame = timeline.frameAt(t, idle: step * 0.37);
        for (int i = 0; i < geometry.length; i++) {
          final Offset at = lens.screenOf(
            vm.Vector3(
              frame.positions[3 * i],
              frame.positions[3 * i + 1],
              frame.positions[3 * i + 2],
            ),
            vm.Quaternion.identity(),
          )!;
          expect(
            at.dx >= 0 &&
                at.dx <= box.width &&
                at.dy >= 0 &&
                at.dy <= box.height,
            isTrue,
            reason: '${protein.slug} residue $i at $t: $at',
          );
        }
      }
    }
  });

  testWidgets('it paints every protein through every step', (
    WidgetTester tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: Builder(
          builder: (BuildContext c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    for (final ProteinTarget protein in TestCatalog.all) {
      final FoldTimeline timeline = FoldTimeline(geometryOf(protein));
      for (final double t in <double>[0, 0.2, 0.4, 0.6, 0.8, 1]) {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        FoldPainter(
          timeline: timeline,
          at: () => t,
          inks: FoldInks.of(context, protein),
          idle: () => 0.5,
        ).paint(Canvas(recorder), box);
        recorder.endRecording().dispose();
      }
    }
  });

  test('a screen reader hears the step, and hears when it is folded', () {
    final FoldTimeline timeline = FoldTimeline(geometryOf(target('prion')));
    expect(
      FoldPainter.describe(timeline, timeline.stateAt(0.1)),
      'Hydrophobic collapse. An illustration of 109 residues folding, drawn as '
      'the chain through their alpha carbons, with 98 loose.',
    );
    expect(
      FoldPainter.describe(timeline, timeline.stateAt(1)),
      endsWith('Folded, as the structure page draws it.'),
    );
  });
}
