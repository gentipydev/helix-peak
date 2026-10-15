import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

ChromosomeScene _scene(ProteinTarget t) =>
    ChromosomeScene(ZoomSubject(track: locusOf(t), record: recordOf(t)));

/// The widest [scene]'s chromatid is from [from] to [to], sampled finely.
double _widest(ChromosomeScene scene, double from, double to) {
  double widest = 0;
  for (int i = 0; i <= 400; i++) {
    widest = math.max(widest, scene.widthAt(from + (to - from) * i / 400));
  }
  return widest;
}

void main() {
  test(
    'a chromatid narrows and widens with no step, at a stalk or anywhere',
    () {
      for (final ProteinTarget target in TestCatalog.all) {
        final ChromosomeScene scene = _scene(target);
        const int steps = 20000;
        final double top = scene.yOf(1);
        double last = scene.widthAt(top);
        double jump = 0;
        for (int i = 1; i <= steps; i++) {
          final double w = scene.widthAt(
            top + ChromosomeScene.length * i / steps,
          );
          jump = math.max(jump, (w - last).abs());
          last = w;
        }
        // A rounded end is the steepest the outline may be: well under a
        // tenth of a chromatid's half-width between two of these samples.
        expect(jump, lessThan(scene.half * 0.1), reason: target.slug);
      }
    },
  );

  test('an acrocentric\'s satellite is a knob on its stalk\'s thread', () {
    int acrocentric = 0;
    for (final ProteinTarget target in TestCatalog.all) {
      final LocusTrack track = locusOf(target);
      final ChromosomeScene scene = _scene(target);
      for (final CytoBand stalk in track.bands) {
        if (stalk.stain != Stain.stalk) {
          continue;
        }
        acrocentric++;
        final double thread = scene.half * ChromosomeScene.thread;
        final double from = scene.yOf(stalk.start);
        final double to = scene.yOf(stalk.end + 1);
        expect(
          scene.widthAt((from + to) / 2),
          closeTo(thread, 1e-9),
          reason: target.slug,
        );
        expect(
          _widest(scene, scene.yOf(1), from),
          greaterThan(thread * 2),
          reason: '${target.slug}: the satellite',
        );
        expect(
          _widest(scene, to, scene.yOf(track.length + 1)),
          closeTo(scene.half, scene.half * 0.01),
          reason: '${target.slug}: the chromatid',
        );
      }
    }
    expect(acrocentric, isPositive, reason: 'no chromosome with a stalk');
  });
}
