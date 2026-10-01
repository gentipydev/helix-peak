import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/lab/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_camera.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_geometry.dart';
import 'package:helixpeek/features/lab/replication/presentation/replication_staging.dart';

/// Flicker is a thing that jumps, blinks or kinks from one frame to the next.
/// The scene is a pure function of time, so every frame at 60 fps can be
/// staged and compared with its neighbours without drawing a pixel.
void main() {
  const double fps = 60;
  final int frames = (ReplicationTimeline.durationSeconds * fps).round();

  ReplicationMoment momentAt(int frame) => ReplicationMoment(frame / fps);

  /// Every keyed thing on the stage, as its screen position and opacity.
  Map<String, (Offset, double)> stageAt(int frame) {
    final ReplicationMoment moment = momentAt(frame);
    final ReplicationCamera camera = ReplicationCamera.at(moment);
    // No culling to a viewport: a thing leaving the frame is not a pop.
    final ReplicationGeometry g = ReplicationGeometry(
      moment.frame,
      top: -1e4,
      bottom: 1e4,
    );
    final ReplicationStaging stage = ReplicationStaging(moment, g, camera);
    return <String, (Offset, double)>{
      for (final StagedItem item in stage.items)
        'item:${item.key}': (camera.project(item.centre), item.opacity),
      for (final StagedRing ring in stage.rings)
        'ring:${ring.key}': (camera.project(ring.centre), ring.opacity),
      for (final StagedLabel label in stage.labels)
        'label:${label.key}': (label.target ?? label.at, label.opacity),
      for (final StagedArrow arrow in stage.arrows)
        'arrow:${arrow.key}': (arrow.from, arrow.opacity),
      for (final StagedFlap flap in stage.flaps)
        'flap:${flap.key}': (camera.project(flap.base), flap.opacity),
      for (final StagedNick nick in stage.nicks)
        'nick:${nick.key}': (camera.project(nick.centre), nick.opacity),
    };
  }

  test('nothing on the stage jumps, and nothing appears or goes at once', () {
    Map<String, (Offset, double)> twoBack = stageAt(0);
    Map<String, (Offset, double)> oneBack = stageAt(1);
    final List<String> faults = <String>[];
    for (int frame = 2; frame <= frames && faults.length < 12; frame++) {
      final Map<String, (Offset, double)> now = stageAt(frame);
      final String at = '${(frame / fps).toStringAsFixed(3)} s';
      for (final MapEntry<String, (Offset, double)> entry in now.entries) {
        final (Offset p, double opacity) = entry.value;
        final (Offset, double)? previous = oneBack[entry.key];
        if (previous == null) {
          if (opacity > 0.08) {
            faults.add('$at: ${entry.key} appears at opacity $opacity');
          }
          continue;
        }
        if ((opacity - previous.$2).abs() > 0.08) {
          faults.add(
            '$at: ${entry.key} opacity ${previous.$2} → $opacity in a frame',
          );
        }
        final (Offset, double)? earlier = twoBack[entry.key];
        if (earlier != null) {
          final double jerk = (p - previous.$1 * 2 + earlier.$1).distance;
          if (jerk > 1.5) {
            faults.add('$at: ${entry.key} jumps (${jerk.toStringAsFixed(2)})');
          }
        }
      }
      for (final MapEntry<String, (Offset, double)> entry
          in oneBack.entries) {
        if (!now.containsKey(entry.key) && entry.value.$2 > 0.08) {
          faults.add(
            '$at: ${entry.key} vanishes from opacity ${entry.value.$2}',
          );
        }
      }
      twoBack = oneBack;
      oneBack = now;
    }
    expect(faults, isEmpty, reason: faults.join('\n'));
  });

  test('the template bends smoothly where fragments start, end and join', () {
    for (int frame = 0; frame <= frames; frame += 30) {
      final ReplicationMoment moment = momentAt(frame);
      final ReplicationGeometry g = ReplicationGeometry(moment.frame);
      for (final bool leading in <bool>[true, false]) {
        double worst = 0;
        double where = 0;
        final double cut = g.parentalCut(leading: leading);
        final double gap = 1.2 * g.frame.topoCut + 0.15;
        for (
          double i = g.frame.fork - 300;
          i < g.frame.fork + 150;
          i += 0.1
        ) {
          // Topoisomerase II's cut is a deliberate break, not a kink.
          if (g.frame.topoCut > 0 && (i - cut).abs() < gap + 0.1) {
            continue;
          }
          final double step =
              (g.template(i + 0.1, leading: leading) -
                      g.template(i, leading: leading))
                  .distance;
          if (step > worst) {
            worst = step;
            where = i;
          }
        }
        // A 0.1-nt step moves at most 0.18 down and a little across; the
        // old step function jumped 20 design units at a fragment's 5′ end.
        expect(
          worst,
          lessThan(0.8),
          reason:
              '${moment.seconds} s, ${leading ? 'leading' : 'lagging'} '
              'template at $where',
        );
      }
    }
  });

  test('synthesis fronts and the model clock never lurch', () {
    double second(double Function(double) f, double t, double h) =>
        f(t + h) - 2 * f(t) + f(t - h);
    const double h = 1 / fps;
    for (int frame = 1; frame < frames; frame++) {
      final double t = frame / fps;
      double model(double s) => ReplicationMoment(s).frame.seconds;
      expect(second(model, t, h).abs(), lessThan(1e-3), reason: '$t s');
      for (final double Function(ReplicationFrame) front
          in <double Function(ReplicationFrame)>[
            (ReplicationFrame f) => f.fork,
            (ReplicationFrame f) => f.leadingTip,
            (ReplicationFrame f) => f.tipOf(0),
            (ReplicationFrame f) => f.tipOf(1),
            (ReplicationFrame f) => f.replacedBases,
          ]) {
        final double jerk = second(
          (double s) => front(ReplicationMoment(s).frame),
          t,
          h,
        ).abs();
        expect(jerk, lessThan(0.02), reason: '$t s');
      }
    }
  });

  test('the camera moves without a jolt', () {
    ReplicationCamera cameraAt(int frame) =>
        ReplicationCamera.at(momentAt(frame));
    for (int frame = 1; frame < frames; frame++) {
      final ReplicationCamera a = cameraAt(frame - 1);
      final ReplicationCamera b = cameraAt(frame);
      final ReplicationCamera c = cameraAt(frame + 1);
      // A long eased pan accelerates by up to ~0.1 scene units a frame²;
      // a jump or a cut would be many times that.
      expect(
        (a.centre - b.centre * 2 + c.centre).distance,
        lessThan(0.15),
        reason: '${frame / fps} s',
      );
      expect(
        (a.zoom - 2 * b.zoom + c.zoom).abs(),
        lessThan(3e-3),
        reason: '${frame / fps} s',
      );
    }
  });

  test('a new base grows in, and its colour changes gradually', () {
    for (int frame = 0; frame < frames; frame++) {
      final ReplicationGeometry a = ReplicationGeometry(momentAt(frame).frame);
      final ReplicationGeometry b = ReplicationGeometry(
        momentAt(frame + 1).frame,
      );
      for (int i = -20; i < 200; i += 5) {
        for (final bool leading in <bool>[true, false]) {
          final double index = i.toDouble();
          expect(
            (b.presence(index, leading: leading) -
                    a.presence(index, leading: leading))
                .abs(),
            lessThan(0.1),
            reason: '${frame / fps} s, base $i',
          );
          // Colour shows only where a base is: hold what is seen of each.
          double rna(ReplicationGeometry g) =>
              g.presence(index, leading: leading) *
              g.rna(index, leading: leading);
          double dna(ReplicationGeometry g) =>
              g.presence(index, leading: leading) *
              (1 - g.rna(index, leading: leading));
          expect(
            (rna(b) - rna(a)).abs(),
            lessThan(0.1),
            reason: '${frame / fps} s, RNA at base $i',
          );
          expect(
            (dna(b) - dna(a)).abs(),
            lessThan(0.1),
            reason: '${frame / fps} s, DNA at base $i',
          );
        }
      }
    }
  });
}
