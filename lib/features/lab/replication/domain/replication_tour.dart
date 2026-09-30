import 'package:flutter/foundation.dart';

import '../../../../shared/motion/animation_timeline.dart';
import 'genome_replication.dart';
import 'monotone_curve.dart';

/// A guided view of processes that run together at an established fork.
/// The first clock is playback time; the second is the existing synthesis
/// model's time. Extra time at the opening lets each machine be seen clearly.
enum ReplicationChapter {
  overview('Replication fork', 0, 0),
  helicase('Helicase', 4, 0.8),
  binding('Strand-binding proteins', 14, 3.2),
  topoisomerase('Topoisomerase', 24, 5.6),
  primase('Primase', 34, 8),
  polymerase('DNA polymerase', 44, 12),
  leading('Leading strand', 58, 24),
  lagging('Lagging strand', 70, 32),
  nextPrimer('Next primer', 88, 50),
  fragments('Okazaki fragments', 100, 62),
  replacement('Replacing primers', 126, 88),
  ligase('DNA ligase', 140, 102),
  result('Final result', 152, 114);

  const ReplicationChapter(this.title, this.second, this.modelSecond);
  final String title;
  final double second;
  final double modelSecond;
}

@immutable
class ReplicationMoment {
  const ReplicationMoment(this.seconds);
  final double seconds;

  ReplicationChapter get chapter => ReplicationChapter.values.lastWhere(
    (ReplicationChapter chapter) => seconds >= chapter.second,
  );

  // Each chapter starts exactly on its model second; between them the model
  // clock changes speed smoothly instead of lurching at the boundary.
  static final MonotoneCurve _clock = MonotoneCurve(<(double, double)>[
    for (final ReplicationChapter chapter in ReplicationChapter.values)
      (chapter.second, chapter.modelSecond),
    (ReplicationTimeline.durationSeconds.toDouble(), 120),
  ]);

  ReplicationFrame get frame => ReplicationFrame(_clock.at(seconds));

  String get caption => switch (chapter) {
    ReplicationChapter.overview =>
      'One fork, two new strands. Follow the machinery at work.',
    ReplicationChapter.helicase =>
      'CMG helicase separates the two parental strands.',
    ReplicationChapter.binding =>
      'RPA, the human SSB, holds exposed single strands open.',
    ReplicationChapter.topoisomerase =>
      'Topoisomerase relieves twisting ahead of the opening fork.',
    ReplicationChapter.primase || ReplicationChapter.nextPrimer =>
      frame.seconds - (chapter == ReplicationChapter.primase ? 8 : 50) < 4
          ? 'Primase builds a short RNA start for the next DNA fragment.'
          : 'Pol α adds DNA to the RNA primer, then hands it to Pol δ.',
    ReplicationChapter.polymerase =>
      frame.seconds < 20
          ? 'Pol α extends the primer; Pol δ takes over with PCNA.'
          : 'PCNA holds Pol δ around DNA as the fragment grows.',
    ReplicationChapter.leading =>
      'Pol ε copies continuously towards the fork, adding at the 3′ end.',
    ReplicationChapter.lagging =>
      'Pol δ builds a short fragment away from the fork, still 5′ → 3′.',
    ReplicationChapter.fragments =>
      'The next Okazaki fragment grows back towards the earlier primer.',
    ReplicationChapter.replacement =>
      'Pol δ replaces RNA with DNA. FEN1 cuts away the displaced primer.',
    ReplicationChapter.ligase =>
      'DNA ligase seals the remaining nick in the new backbone.',
    ReplicationChapter.result =>
      'Each duplex has one old and one new strand. The fork continues.',
  };

  String get description => '${chapter.title}. $caption';

  @override
  bool operator ==(Object other) =>
      other is ReplicationMoment && other.seconds == seconds;

  @override
  int get hashCode => seconds.hashCode;
}

class ReplicationTimeline extends AnimationTimeline<ReplicationMoment> {
  const ReplicationTimeline();

  static const int durationSeconds = 160;

  @override
  int get beats => durationSeconds;

  @override
  List<PhaseMark> get phases => _phases;
  static final List<PhaseMark> _phases = List<PhaseMark>.unmodifiable(
    ReplicationChapter.values.map(
      (ReplicationChapter chapter) => PhaseMark(
        name: chapter.title,
        t: chapter.second / durationSeconds,
        captionKey: chapter.name,
      ),
    ),
  );

  @override
  ReplicationMoment stateAt(double t) =>
      ReplicationMoment(t.clamp(0.0, 1.0) * durationSeconds);
}
