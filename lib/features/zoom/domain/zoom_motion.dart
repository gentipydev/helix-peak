import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'zoom_depth.dart';

/// How long a flight between two depths takes: about a second and a half for
/// a step to the next stop, a little longer the more tenfold steps it
/// crosses, and never more than 1.9 s. Each step crossfades two scenes and
/// glides the camera to where the next lies, and at 60 frames a second
/// nothing may change by more than 0.08 of its opacity from one frame to the
/// next, nor jolt by more than 1.5 pixels near the middle
/// (`zoom_smoothness_test`): the shortest steps need 1.4 s for that, and a
/// long chromosome's turn into its band about 1.6 s.
Duration flightDuration(double from, double to) {
  final double seconds = (1.3 + 0.15 * (to - from).abs()).clamp(1.45, 1.9);
  return Duration(microseconds: (seconds * 1e6).round());
}

/// A flight from one depth to another.
///
/// It sets off at [velocity], the speed the depth already has, so a step
/// asked for mid-flight carries straight on rather than stalling; and it
/// comes to rest at its end with no speed and no change of speed. Its path
/// is a quintic in time: from rest it is the smootherstep the zoom has always
/// eased by, in depth itself, so the speed never jumps where it crosses from
/// one segment to the next. It takes [flightDuration], or [minimum] where
/// that is longer: the step into the DNA takes its time
/// ([ZoomDepth.leastFlight]).
///
/// With a [cruise] it spends that share of its time in its middle at one
/// speed, easing up to it and down from it with no jolt at either end: the
/// step into the DNA, where five things happen one after another, would
/// otherwise cross the middle ones at nearly twice its mean speed.
@immutable
final class ZoomFlight {
  ZoomFlight(
    this.from,
    this.to, {
    double velocity = 0,
    Duration minimum = Duration.zero,
    this.cruise = 0,
  }) : duration = _durationOf(from, to, minimum),
       _push = _pushOf(from, to, velocity, _durationOf(from, to, minimum));

  /// The share of the flight in its middle spent at one speed: 0, the
  /// quintic every step has always eased by.
  final double cruise;

  static Duration _durationOf(double from, double to, Duration minimum) {
    final Duration own = flightDuration(from, to);
    return minimum > own ? minimum : own;
  }

  final double from;
  final double to;
  final Duration duration;

  /// The starting speed, as depth per whole flight, held to no more than
  /// twice the distance: past that the flight would overshoot its stop.
  final double _push;

  static double _pushOf(
    double from,
    double to,
    double velocity,
    Duration duration,
  ) {
    final double span = (to - from).abs();
    final double push = velocity * duration.inMicroseconds / 1e6;
    return push.clamp(-2 * span, 2 * span);
  }

  double _t(Duration elapsed) {
    final int total = duration.inMicroseconds;
    return total == 0 ? 1 : (elapsed.inMicroseconds / total).clamp(0.0, 1.0);
  }

  /// How far along its way the flight is at [u] of its time, from rest to
  /// rest: the quintic, or with a [cruise], speed rising as a smootherstep
  /// over the first of the two equal ramps, held, and falling over the last.
  double _eased(double u) {
    if (cruise <= 0) {
      return u * u * u * (u * (u * 6 - 15) + 10);
    }
    final double ramp = (1 - cruise) / 2;
    // The integral of a smootherstep from 0 to x: x⁶ − 3x⁵ + 2.5x⁴.
    double rise(double x) => x * x * x * x * (x * x - 3 * x + 2.5);
    final double whole = 1 - ramp;
    if (u <= ramp) {
      return ramp * rise(u / ramp) / whole;
    }
    if (u >= 1 - ramp) {
      return 1 - ramp * rise((1 - u) / ramp) / whole;
    }
    return (ramp / 2 + (u - ramp)) / whole;
  }

  /// How fast [_eased] moves at [u], in its way a whole flight.
  double _easedSpeed(double u) {
    if (cruise <= 0) {
      return 30 * u * u * (1 - u) * (1 - u);
    }
    final double ramp = (1 - cruise) / 2;
    double step(double x) => x * x * x * (x * (x * 6 - 15) + 10);
    final double whole = 1 - ramp;
    if (u <= ramp) {
      return step(u / ramp) / whole;
    }
    if (u >= 1 - ramp) {
      return step((1 - u) / ramp) / whole;
    }
    return 1 / whole;
  }

  /// The depth [elapsed] into the flight.
  double at(Duration elapsed) {
    final double u = _t(elapsed);
    final double eased = _eased(u);
    // u (1 − u)³ (1 + 3u): the start's speed, worn away by the end.
    final double carried = u * math.pow(1 - u, 3) * (1 + 3 * u);
    return from + (to - from) * eased + _push * carried;
  }

  /// How fast the depth moves [elapsed] into the flight, in depth a second.
  double speedAt(Duration elapsed) {
    final double u = _t(elapsed);
    final double eased = _easedSpeed(u);
    final double carried = math.pow(1 - u, 2) * (1 + 2 * u - 15 * u * u);
    final double seconds = duration.inMicroseconds / 1e6;
    return seconds == 0 ? 0 : ((to - from) * eased + _push * carried) / seconds;
  }

  bool doneAt(Duration elapsed) => elapsed >= duration;
}

/// Where a pinch let go at [depth], moving at [velocity] (depth a second),
/// comes to rest: the stop nearest the depth it would coast to.
ZoomStop flingTarget(ZoomDepth depth, double at, double velocity) {
  const double coast = 0.35;
  return depth.nearest((at + velocity * coast).clamp(0.0, depth.total));
}
