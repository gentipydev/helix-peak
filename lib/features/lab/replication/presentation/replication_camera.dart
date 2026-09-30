import 'dart:ui';

import '../domain/genome_replication.dart';
import '../domain/replication_tour.dart';
import 'replication_geometry.dart';

/// A camera on the same deterministic clock as synthesis. Each chapter begins
/// with its target in view; the previous chapter's last 2.5 seconds ease into it.
/// Pausing freezes the camera too, and seeking needs no accumulated history.
class ReplicationCamera {
  const ReplicationCamera(this.centre, this.zoom);

  static const ReplicationCamera overview = ReplicationCamera(
    Offset(180, 300),
    1,
  );
  static const double transitionSeconds = 2.5;

  final Offset centre;
  final double zoom;

  Rect get bounds => Rect.fromCenter(
    center: centre,
    width: ReplicationGeometry.designSize.width / zoom,
    height: ReplicationGeometry.designSize.height / zoom,
  );

  Offset project(Offset point) =>
      const Offset(180, 300) + (point - centre) * zoom;

  static ReplicationCamera forChapter(
    ReplicationChapter chapter,
    ReplicationGeometry g,
  ) => switch (chapter) {
    ReplicationChapter.overview || ReplicationChapter.result => overview,
    ReplicationChapter.helicase => ReplicationCamera(
      Offset(174, g.forkY + 10),
      2.35,
    ),
    ReplicationChapter.binding => ReplicationCamera(
      g.template(67, leading: false),
      2.8,
    ),
    ReplicationChapter.topoisomerase => ReplicationCamera(
      Offset(180, g.forkY - 108),
      2.8,
    ),
    ReplicationChapter.primase || ReplicationChapter.polymerase =>
      ReplicationCamera(g.centre(g.frame.tipOf(0), leading: false), 2.5),
    ReplicationChapter.leading => ReplicationCamera(
      g.leadingEnzyme + const Offset(4, 25),
      2.25,
    ),
    ReplicationChapter.lagging => ReplicationCamera(
      g.centre(g.frame.tipOf(0), leading: false) + const Offset(-4, -20),
      2.15,
    ),
    ReplicationChapter.nextPrimer => ReplicationCamera(
      g.centre(g.frame.tipOf(1), leading: false),
      2.5,
    ),
    ReplicationChapter.fragments => ReplicationCamera(
      g.centre(g.frame.tipOf(1), leading: false) + const Offset(-4, -20),
      2.15,
    ),
    ReplicationChapter.replacement => ReplicationCamera(
      g.centre(100 - g.frame.replacedBases, leading: false) +
          const Offset(-12, 8),
      2.8,
    ),
    ReplicationChapter.ligase => ReplicationCamera(
      g.centre(89.5, leading: false),
      3,
    ),
  };

  /// Where the camera is at [moment]. [blend] eases between the whole fork
  /// (0) and the guided close-ups (1) when the reader switches between them.
  static ReplicationCamera at(
    ReplicationMoment moment, {
    bool follow = true,
    double blend = 1,
    bool reducedMotion = false,
  }) {
    if (!follow || blend <= 0) return overview;
    final ReplicationCamera guided = _guided(moment, reducedMotion);
    if (blend >= 1) return guided;
    final double eased = blend * blend * (3 - 2 * blend);
    return ReplicationCamera(
      Offset.lerp(overview.centre, guided.centre, eased)!,
      lerpDouble(overview.zoom, guided.zoom, eased)!,
    );
  }

  static ReplicationCamera _guided(
    ReplicationMoment moment,
    bool reducedMotion,
  ) {
    final ReplicationGeometry g = ReplicationGeometry(moment.frame);
    final ReplicationChapter chapter = moment.chapter;
    final ReplicationCamera from = forChapter(chapter, g);
    if (reducedMotion || chapter == ReplicationChapter.values.last) return from;
    final ReplicationChapter next =
        ReplicationChapter.values[chapter.index + 1];
    final double t = ReplicationFrame.progress(
      moment.seconds,
      next.second - transitionSeconds,
      next.second,
    );
    if (t == 0) return from;
    final ReplicationCamera to = forChapter(next, g);
    final double eased = t * t * t * (10 + t * (-15 + t * 6));
    return ReplicationCamera(
      Offset.lerp(from.centre, to.centre, eased)!,
      lerpDouble(from.zoom, to.zoom, eased)!,
    );
  }
}
