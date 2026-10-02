import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/replication/presentation/replication_camera.dart';
import 'package:helixpeek/features/replication/presentation/replication_geometry.dart';
import 'package:helixpeek/features/replication/presentation/replication_staging.dart';

/// Where the machines stand relative to each other, as the stage places
/// them at a moment of the synthesis model: the clamp loader on the face of
/// PCNA that the polymerase binds next, and PCNA on the DNA until the nick is
/// sealed.
void main() {
  ReplicationStaging stageAt(double model) => ReplicationStaging(
    const ReplicationMoment(0),
    ReplicationGeometry(ReplicationFrame(model), top: -1e4, bottom: 1e4),
    ReplicationCamera.overview,
    showLabels: false,
  );

  StagedRing? ring(ReplicationStaging stage, String key) {
    for (final StagedRing ring in stage.rings) {
      if (ring.key == key) return ring;
    }
    return null;
  }

  test('RFC holds the primer end on the face of PCNA that Pol δ binds', () {
    for (final int k in <int>[0, 1]) {
      final double done = ReplicationFrame.primerDoneAt(k);
      final double handoff = ReplicationFrame.handoffAt(k);
      int judged = 0;
      for (double model = done; model <= handoff; model += 0.1) {
        final ReplicationStaging stage = stageAt(model);
        final StagedRing? rfc = ring(stage, 'rfc-$k');
        final StagedRing? pcna = ring(stage, 'pcna-$k');
        if (rfc == null || pcna == null || rfc.opacity < 1) continue;
        judged++;
        // Pol α has let the end go before RFC is on it.
        expect(
          stage.items.any(
            (StagedItem item) =>
                item.key == 'primase-$k' && item.opacity > 0.05,
          ),
          isFalse,
          reason: '$k at $model',
        );
        // The lagging strand grows towards lower indices: that way lies the
        // primer's 3′ end, and RFC.
        final ReplicationGeometry g = ReplicationGeometry(
          ReplicationFrame(model),
        );
        final double tip = ReplicationFrame(model).tipOf(k);
        final Offset towardsThreePrime =
            g.centre(tip - 1, leading: false) -
            g.centre(tip + 1, leading: false);
        final Offset fromClamp = rfc.centre - pcna.centre;
        expect(
          fromClamp.dx * towardsThreePrime.dx +
              fromClamp.dy * towardsThreePrime.dy,
          greaterThan(0),
          reason: '$k at $model',
        );
      }
      expect(judged, greaterThan(5), reason: 'RFC seen on fragment $k');
    }
  });

  test('PCNA stays on the DNA through ligation, then comes off', () {
    // Fragment 1's nick is sealed from 102 to 110 model seconds.
    for (double model = 102; model <= 110; model += 0.25) {
      final StagedRing? pcna = ring(stageAt(model), 'pcna-1');
      expect(pcna, isNotNull, reason: '$model');
      expect(pcna!.opacity, 1, reason: '$model');
    }
    expect(ring(stageAt(113), 'pcna-1'), isNull);
  });
}
