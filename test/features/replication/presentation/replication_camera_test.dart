import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/replication/domain/genome_replication.dart';
import 'package:helixpeek/features/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/replication/presentation/replication_camera.dart';
import 'package:helixpeek/features/replication/presentation/replication_geometry.dart';

void main() {
  test(
    'every chapter opens on its working site, with the whole fork at the ends',
    () {
      for (final ReplicationChapter chapter in ReplicationChapter.values) {
        final ReplicationMoment moment = ReplicationMoment(chapter.second);
        final ReplicationCamera camera = ReplicationCamera.at(moment);
        final ReplicationGeometry g = ReplicationGeometry(moment.frame);
        final Offset origin = Offset(180, g.yOf(GenomeReplication.origin));
        final Offset target = switch (chapter) {
          ReplicationChapter.origin ||
          ReplicationChapter.licensing ||
          ReplicationChapter.firing ||
          ReplicationChapter.bubble => origin,
          ReplicationChapter.overview ||
          ReplicationChapter.result => const Offset(180, 300),
          ReplicationChapter.helicase => Offset(164, g.forkY + 9),
          ReplicationChapter.binding => g.template(67, leading: false),
          ReplicationChapter.topoisomerase => Offset(180, g.forkY - 108),
          ReplicationChapter.primase || ReplicationChapter.polymerase =>
            g.centre(g.frame.tipOf(0), leading: false),
          ReplicationChapter.leading => g.leadingEnzyme,
          ReplicationChapter.lagging => g.centre(
            g.frame.tipOf(0),
            leading: false,
          ),
          ReplicationChapter.nextPrimer || ReplicationChapter.fragments =>
            g.centre(g.frame.tipOf(1), leading: false),
          ReplicationChapter.replacement => g.laggingEnzyme,
          ReplicationChapter.ligase => g.nick,
        };
        expect(
          const Rect.fromLTWH(
            100,
            200,
            160,
            200,
          ).contains(camera.project(target)),
          isTrue,
          reason: chapter.name,
        );
        // The fork's close-ups are magnified; the origin is seen whole.
        expect(
          camera.zoom,
          switch (chapter) {
            ReplicationChapter.overview || ReplicationChapter.result => 1,
            ReplicationChapter.origin ||
            ReplicationChapter.licensing ||
            ReplicationChapter.firing ||
            ReplicationChapter.bubble => inInclusiveRange(1.3, 1.8),
            _ => greaterThan(2),
          },
          reason: chapter.name,
        );
      }
    },
  );

  test('pans and synthesis are continuous across every chapter boundary', () {
    const double epsilon = 0.00001;
    for (final ReplicationChapter chapter in ReplicationChapter.values.skip(
      1,
    )) {
      final ReplicationMoment before = ReplicationMoment(
        chapter.second - epsilon,
      );
      final ReplicationMoment after = ReplicationMoment(
        chapter.second + epsilon,
      );
      final ReplicationCamera a = ReplicationCamera.at(before);
      final ReplicationCamera b = ReplicationCamera.at(after);
      expect(
        (a.centre - b.centre).distance,
        lessThan(0.001),
        reason: chapter.name,
      );
      expect((a.zoom - b.zoom).abs(), lessThan(0.001), reason: chapter.name);
      expect(
        after.frame.seconds,
        closeTo(before.frame.seconds, 0.001),
        reason: chapter.name,
      );
    }
  });

  test('extension stays in frame and seeking reproduces the same camera', () {
    for (
      double second = 0;
      second <= ReplicationTimeline.durationSeconds;
      second += 0.1
    ) {
      final ReplicationMoment moment = ReplicationMoment(second);
      final ReplicationCamera camera = ReplicationCamera.at(moment);
      ReplicationCamera.at(
        ReplicationMoment(ReplicationTimeline.durationSeconds.toDouble()),
      );
      ReplicationCamera.at(const ReplicationMoment(0));
      final ReplicationCamera repeated = ReplicationCamera.at(moment);
      expect(repeated.centre, camera.centre);
      expect(repeated.zoom, camera.zoom);
      expect(camera.centre.dx.isFinite && camera.centre.dy.isFinite, isTrue);
      // Pulled back to the whole bubble at the start and the end; never
      // closer than three times.
      expect(camera.zoom, inInclusiveRange(0.36 - 1e-9, 3 + 1e-9));
      final ReplicationChapter chapter = moment.chapter;
      if (chapter == ReplicationChapter.lagging ||
          chapter == ReplicationChapter.fragments) {
        final double next = ReplicationChapter.values[chapter.index + 1].second;
        if (second >= next - ReplicationCamera.transitionSeconds) continue;
        final ReplicationGeometry g = ReplicationGeometry(moment.frame);
        final int fragment = chapter == ReplicationChapter.lagging ? 0 : 1;
        final Offset tip = g.daughter(g.frame.tipOf(fragment), leading: false);
        expect(
          camera.bounds.deflate(20).contains(tip),
          isTrue,
          reason: '$second',
        );
      }
    }
  });

  test(
    'reduced motion holds the chapter view and whole fork overrides the tour',
    () {
      // Late in the binding chapter, as the camera leaves for topo II.
      const ReplicationMoment moment = ReplicationMoment(67);
      final ReplicationCamera held = ReplicationCamera.at(
        moment,
        reducedMotion: true,
      );
      expect(
        held.project(
          ReplicationGeometry(moment.frame).template(67, leading: false),
        ),
        const Offset(180, 300),
      );
      expect(ReplicationCamera.at(moment).centre, isNot(held.centre));
      expect(
        ReplicationCamera.at(moment, follow: false),
        same(ReplicationCamera.overview),
      );
    },
  );
}
