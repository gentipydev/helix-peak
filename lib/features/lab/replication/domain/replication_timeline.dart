import 'package:flutter/foundation.dart';

import '../../../../shared/motion/animation_timeline.dart';
import 'replication_plan.dart';

/// The chapters of a record's replication, in order.
enum ReplicationPhase { origin, leading, lagging, proofreading, whole, done }

/// The proofreading set piece, one beat to a step.
///
/// What the last three steps show depends on whether proofreading is on:
/// with it, the polymerase steps back, cuts the wrong base out and puts the
/// right one in; without it, it builds on past the wrong base, which stays.
/// Either way the fork waits the same five beats, so the timeline is the same
/// whatever the reader chooses.
enum SetPieceStep { wrongBase, stall, stepBack, excise, retry }

/// One frame of a replication.
@immutable
final class ReplicationFrame {
  const ReplicationFrame({
    required this.t,
    required this.phase,
    required this.travel,
    this.setPiece,
    this.setPieceProgress = 0,
    this.setPiecePlayed = false,
  });

  final double t;
  final ReplicationPhase phase;

  /// How far each fork has travelled from the origin, in bases.
  final double travel;

  /// The step of the proofreading set piece on screen, or null outside it.
  final SetPieceStep? setPiece;

  /// How far through that step, from 0 to 1.
  final double setPieceProgress;

  /// Whether the set piece is over: the base at its site is the one it left.
  final bool setPiecePlayed;

  @override
  bool operator ==(Object other) =>
      other is ReplicationFrame &&
      other.t == t &&
      other.phase == phase &&
      other.travel == travel &&
      other.setPiece == setPiece &&
      other.setPieceProgress == setPieceProgress &&
      other.setPiecePlayed == setPiecePlayed;

  @override
  int get hashCode =>
      Object.hash(t, phase, travel, setPiece, setPieceProgress, setPiecePlayed);

  @override
  String toString() =>
      'ReplicationFrame(${phase.name} @ $t, travel $travel'
      '${setPiece == null ? '' : ', ${setPiece!.name} $setPieceProgress'})';
}

/// A record's replication as a pure function of time, on the plan's own
/// numbers.
///
/// Thirty beats, in six chapters:
///
/// 1. **The origin opens** (two beats): a bubble opens, each fork unwinding
///    [ReplicationPlan.bubble] bases, and each leading strand's primer goes
///    down at the origin.
/// 2. **Leading strand** (four): the forks run on, each leading strand made
///    continuously behind its fork, until the right fork has unwound its
///    first fragment's length of lagging template.
/// 3. **Lagging strand** (nine): the first fragment is primed and made
///    backwards, its loop of template growing, until it meets the piece at
///    the origin, replaces its primer and is sealed; the next primer goes
///    down and the loop lets go. The last beat carries the fork on to where
///    the set piece happens.
/// 4. **Proofreading** (five): the set piece, the fork waiting: one step of
///    [SetPieceStep] to a beat.
/// 5. **The rest of the record** (eight): the forks run on past both ends,
///    and every piece inside the record is made and stitched.
/// 6. **Two copies** (two): nothing moves.
///
/// Each chapter's still, the frame reduced motion shows, is its first.
class ReplicationTimeline extends AnimationTimeline<ReplicationFrame> {
  ReplicationTimeline(this.plan)
    : _firstPrimer = plan.fragmentsOf(Fork.right)[0].primedAt,
      _secondPrimer = plan.fragmentsOf(Fork.right)[1].primedAt;

  final ReplicationPlan plan;

  final double _firstPrimer;
  final double _secondPrimer;

  static const int _total = 30;

  // Where each stretch starts, in beats.
  static const int _leading = 2;
  static const int _lagging = 6;
  static const int _approach = 14;
  static const int _setPiece = 15;
  static const int _whole = 20;
  static const int _done = 28;

  @override
  int get beats => _total;

  static const List<PhaseMark> _phases = <PhaseMark>[
    PhaseMark(name: 'The origin opens', t: 0, captionKey: 'origin'),
    PhaseMark(
      name: 'Leading strand',
      t: _leading / _total,
      captionKey: 'leading',
    ),
    PhaseMark(
      name: 'Lagging strand',
      t: _lagging / _total,
      captionKey: 'lagging',
    ),
    PhaseMark(
      name: 'Proofreading',
      t: _setPiece / _total,
      captionKey: 'proofreading',
    ),
    PhaseMark(
      name: 'The rest of the record',
      t: _whole / _total,
      captionKey: 'whole',
    ),
    PhaseMark(name: 'Two copies', t: _done / _total, captionKey: 'done'),
  ];

  @override
  List<PhaseMark> get phases => _phases;

  /// The chapter [t] is in.
  static ReplicationPhase chapterAt(double t) {
    final double b = t.clamp(0.0, 1.0) * _total;
    return b < _leading
        ? ReplicationPhase.origin
        : b < _lagging
        ? ReplicationPhase.leading
        : b < _setPiece
        ? ReplicationPhase.lagging
        : b < _whole
        ? ReplicationPhase.proofreading
        : b < _done
        ? ReplicationPhase.whole
        : ReplicationPhase.done;
  }

  @override
  ReplicationFrame stateAt(double t) {
    final double at = t.clamp(0.0, 1.0);
    final double b = at * _total;
    final ReplicationPhase phase = chapterAt(at);
    final double setPiece = plan.setPieceTravel;

    double between(double from, double to, int start, int end) =>
        from + (to - from) * ((b - start) / (end - start)).clamp(0.0, 1.0);

    final double travel = b < _leading
        ? ReplicationPlan.bubble *
              AnimationTimeline.slice(b, 0, _leading.toDouble())
        : b < _lagging
        ? between(
            ReplicationPlan.bubble.toDouble(),
            _firstPrimer,
            _leading,
            _lagging,
          )
        : b < _approach
        ? between(_firstPrimer, _secondPrimer, _lagging, _approach)
        : b < _setPiece
        ? between(_secondPrimer, setPiece, _approach, _setPiece)
        : b < _whole
        ? setPiece
        : b < _done
        ? between(setPiece, plan.travelEnd, _whole, _done)
        : plan.travelEnd;

    SetPieceStep? step;
    double progress = 0;
    if (b >= _setPiece && b < _whole) {
      final int index = (b - _setPiece).floor().clamp(0, 4);
      step = SetPieceStep.values[index];
      progress = (b - _setPiece - index).clamp(0.0, 1.0);
    }
    return ReplicationFrame(
      t: at,
      phase: phase,
      travel: travel,
      setPiece: step,
      setPieceProgress: progress,
      setPiecePlayed: b >= _whole,
    );
  }
}
