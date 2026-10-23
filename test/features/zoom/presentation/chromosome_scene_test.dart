import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// [t]'s chromosome.
ChromosomeScene _scene(ProteinTarget t) =>
    ChromosomeScene(ZoomSubject(track: locusOf(t), record: recordOf(t)));

/// The most [scene]'s chromatid widens on the way from [from] to [to].
double _widening(ChromosomeScene scene, double from, double to) {
  const int steps = 4000;
  double last = scene.widthAt(from);
  double widening = 0;
  for (int i = 1; i <= steps; i++) {
    final double w = scene.widthAt(from + (to - from) * i / steps);
    widening = math.max(widening, w - last);
    last = w;
  }
  return widening;
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

  test('a chromatid narrows toward its centromere and its rounded ends and '
      'nowhere else, a stalk as thick as its arm', () {
    int stalks = 0;
    for (final ProteinTarget target in TestCatalog.all) {
      final LocusTrack track = locusOf(target);
      final ChromosomeScene scene = _scene(target);
      // Clear of each end's rounding, each arm narrows only as it nears the
      // centromere.
      final double ends = scene.form.look.endRound * scene.half;
      final double top = scene.yOf(1) + ends;
      final double bottom = scene.yOf(track.length + 1) - ends;
      expect(
        _widening(scene, top, scene.centromere),
        lessThan(1e-12),
        reason: '${target.slug}: the short arm',
      );
      expect(
        _widening(scene, bottom, scene.centromere),
        lessThan(1e-12),
        reason: '${target.slug}: the long arm',
      );
      for (final CytoBand band in track.bands) {
        if (band.stain == Stain.stalk) {
          stalks++;
          final double y =
              (scene.yOf(band.start) + scene.yOf(band.end + 1)) / 2;
          expect(
            scene.widthAt(y),
            greaterThan(scene.half * 0.9),
            reason: '${target.slug}: ${band.name}',
          );
        }
      }
    }
    expect(stalks, isPositive, reason: 'no chromosome with a stalk');
  });
}
