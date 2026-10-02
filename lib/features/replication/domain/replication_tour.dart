import 'package:flutter/foundation.dart';

import '../../../shared/motion/animation_timeline.dart';
import 'genome_replication.dart';
import 'monotone_curve.dart';

/// A guided view of replication: an origin firing into two forks, then the
/// processes that run together at the upper fork. The first clock is
/// playback time; the second is the synthesis model's time, negative before
/// the tour joins the upper fork. Extra time lets each machine be seen.
enum ReplicationChapter {
  origin('Origin', 0, -60),
  licensing('Pre-replication complex', 8, -52),
  firing('Origin firing', 20, -40),
  bubble('Two forks', 30, -30),
  overview('Replication fork', 44, 0),
  helicase('Helicase', 48, 0.8),
  binding('Strand-binding proteins', 58, 3.2),
  topoisomerase('Topoisomerase', 68, 5.6),
  primase('Primase', 82, 8),
  polymerase('DNA polymerase', 92, 12),
  leading('Leading strand', 106, 24),
  lagging('Lagging strand', 118, 32),
  nextPrimer('Next primer', 136, 50),
  fragments('Okazaki fragments', 148, 62),
  replacement('Replacing primers', 174, 88),
  ligase('DNA ligase', 188, 102),
  result('Final result', 200, 114);

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
    ReplicationChapter.origin =>
      'A/T-rich DNA opens first: an A·T pair has two hydrogen bonds, a G·C '
          'pair three.',
    ReplicationChapter.licensing =>
      frame.seconds < -47.5
          ? 'In G1, ORC and Cdc6 bind the origin; Cdt1 brings MCM2–7 rings.'
          : 'Two MCM2–7 rings close round the DNA head to head: the '
                'pre-replication complex.',
    ReplicationChapter.firing =>
      frame.seconds < -36
          ? 'In S phase, kinases add Cdc45 and GINS to each MCM ring, making '
                'two CMG helicases.'
          : 'The A/T-rich DNA melts first. Each CMG closes round one strand, '
                'and they pass each other.',
    ReplicationChapter.bubble =>
      frame.seconds < -16
          ? 'Two forks leave the origin in opposite directions: replication '
                'is bidirectional.'
          : 'Each fork’s leading strand starts at the origin, and its lagging '
                'strand ends there.',
    ReplicationChapter.overview =>
      'One fork, two new strands. Follow the machinery at work.',
    ReplicationChapter.helicase =>
      'CMG, powered by ATP, separates the parental strands; the DNA ahead '
          'winds tighter.',
    ReplicationChapter.binding =>
      'RPA, the human SSB, stops single strands reannealing and shields them '
          'from nucleases.',
    ReplicationChapter.topoisomerase =>
      frame.seconds < 6
          ? 'Unwinding overwinds the DNA ahead: it is wound tighter and tighter.'
          : frame.seconds < 7
          ? 'Topoisomerase II cuts both strands, holds the cut ends, and '
                'passes another duplex through.'
          : 'It rejoins the ends it holds, and the DNA ahead relaxes.',
    ReplicationChapter.primase || ReplicationChapter.nextPrimer =>
      frame.seconds - (chapter == ReplicationChapter.primase ? 8 : 50) < 4
          ? 'Primase makes a short RNA primer: DNA polymerases can only '
                'extend an existing 3′ end.'
          : 'Pol α adds DNA to the RNA primer, then hands it on.',
    ReplicationChapter.polymerase =>
      frame.seconds < ReplicationFrame.primerDoneAt(0)
          ? 'Pol α adds DNA to the RNA primer, then hands it on.'
          : frame.seconds < ReplicationFrame.handoffAt(0)
          ? 'RFC opens the PCNA ring and closes it round the primer end; '
                'Pol δ takes over.'
          : 'PCNA holds Pol δ on the DNA as the fragment grows.',
    ReplicationChapter.leading =>
      'Pol ε copies continuously towards the fork, adding at the 3′ end.',
    ReplicationChapter.lagging =>
      frame.seconds < 46
          ? 'Pol δ builds a short fragment away from the fork, still 5′ → 3′.'
          : 'Pol δ reaches the previous fragment’s RNA primer.',
    ReplicationChapter.fragments =>
      'The next Okazaki fragment grows back towards the earlier primer.',
    ReplicationChapter.replacement =>
      'Pol δ displaces the RNA primer into a flap; FEN1 cuts the flap away.',
    ReplicationChapter.ligase =>
      'DNA ligase seals the remaining nick in the new backbone.',
    ReplicationChapter.result =>
      'Each duplex has one old and one new strand. Both forks move on, away '
          'from the origin.',
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

  static const int durationSeconds = 212;

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
