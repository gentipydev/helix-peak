import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'zoom_camera.dart';
import 'zoom_depth.dart';

/// How long a flight between two depths takes: a beat to set off, and the
/// rest in proportion to the depth crossed, within bounds, so one stop's
/// step and a dive from the body to the DNA both read as moves.
Duration flightDuration(double from, double to) {
  final double ms = 350 + 260 * (to - from).abs();
  return Duration(milliseconds: ms.clamp(450, 2600).round());
}

/// A flight from one depth to another, eased in and out in depth itself, so
/// its speed never jumps where it crosses from one segment to the next.
@immutable
final class ZoomFlight {
  ZoomFlight(this.from, this.to) : duration = flightDuration(from, to);

  final double from;
  final double to;
  final Duration duration;

  double at(Duration elapsed) {
    final int total = duration.inMicroseconds;
    final double t = total == 0 ? 1 : elapsed.inMicroseconds / total;
    return from + (to - from) * smootherstep(t);
  }

  bool doneAt(Duration elapsed) => elapsed >= duration;
}

/// Where a pinch let go at [depth], moving at [velocity] (depth a second),
/// comes to rest: the stop nearest the depth it would coast to.
ZoomStop flingTarget(ZoomDepth depth, double at, double velocity) {
  const double coast = 0.35;
  return depth.nearest((at + velocity * coast).clamp(0.0, depth.total));
}

/// The dive the Play button plays: from the stop at or after where it
/// starts to the DNA, resting at each stop and travelling the depth between
/// at a steady rate, but never in less than [shortestLeg], easing in and out
/// of every stop.
///
/// Under reduced motion it steps instead: each stop is held for
/// [steppedHold] and the next replaces it, with nothing in between.
@immutable
final class PlaySchedule {
  PlaySchedule(this.depth, {required double from, this.stepped = false})
    : _first = _firstFrom(depth, from) {
    final List<_Leg> legs = <_Leg>[];
    Duration at = Duration.zero;
    final double startDepth = from.clamp(0.0, depth.total);
    final double firstStop = depth.depthOf(ZoomStop.values[_first]);
    if (!stepped && firstStop - startDepth > 1e-9) {
      final Duration travel = _travel(firstStop - startDepth);
      legs.add(_Leg(at, travel, startDepth, firstStop));
      at += travel;
    }
    for (int k = _first; k < ZoomStop.values.length; k++) {
      final double here = depth.depthOf(ZoomStop.values[k]);
      final Duration hold = stepped ? steppedHold : dwell;
      legs.add(_Leg(at, hold, here, here));
      at += hold;
      if (k + 1 < ZoomStop.values.length && !stepped) {
        final double next = depth.depthOf(ZoomStop.values[k + 1]);
        final Duration travel = _travel(next - here);
        legs.add(_Leg(at, travel, here, next));
        at += travel;
      }
    }
    _legs = List<_Leg>.unmodifiable(legs);
    length = at;
  }

  final ZoomDepth depth;
  final bool stepped;
  final int _first;
  late final List<_Leg> _legs;

  /// How long the whole dive takes.
  late final Duration length;

  /// How long the dive rests at each stop.
  static const Duration dwell = Duration(milliseconds: 1500);

  /// How long the dive takes to cross a tenfold step.
  static const double secondsPerDecade = 0.9;

  /// The least time the dive spends between two stops, so that the shortest
  /// segments' changes still read as moves rather than cuts.
  static const Duration shortestLeg = Duration(milliseconds: 1400);

  /// How long each stop is held when the dive steps.
  static const Duration steppedHold = Duration(seconds: 3);

  static int _firstFrom(ZoomDepth depth, double from) {
    for (final ZoomStop stop in ZoomStop.values) {
      if (depth.depthOf(stop) >= from - 1e-9) {
        return stop.index;
      }
    }
    return ZoomStop.values.length - 1;
  }

  static Duration _travel(double decades) {
    final Duration steady = Duration(
      microseconds: (math.max(decades, 0) * secondsPerDecade * 1e6).round(),
    );
    return steady < shortestLeg ? shortestLeg : steady;
  }

  /// The depth [elapsed] into the dive.
  double at(Duration elapsed) {
    for (final _Leg leg in _legs) {
      if (elapsed < leg.start + leg.length) {
        final int span = leg.length.inMicroseconds;
        final double t = span == 0
            ? 1
            : (elapsed - leg.start).inMicroseconds / span;
        return leg.from + (leg.to - leg.from) * smootherstep(t);
      }
    }
    return depth.total;
  }

  bool doneAt(Duration elapsed) => elapsed >= length;
}

@immutable
final class _Leg {
  const _Leg(this.start, this.length, this.from, this.to);

  final Duration start;
  final Duration length;
  final double from;
  final double to;
}
