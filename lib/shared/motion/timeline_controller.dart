import 'package:flutter/widgets.dart';

import 'animation_timeline.dart';

/// Plays an [AnimationTimeline]: the clock, the speed and the reader's
/// controls, over a timeline that knows none of them.
///
/// An [AnimationController] keeps the wall clock, from 0 to 1 over the whole
/// playing time, and [speedCurve] turns that into the timeline's [t]. Seeking
/// and stepping set [t] exactly, never through the curve and back, so a step
/// lands on its boundary rather than a rounding error short of it.
///
/// With [reducedMotion] on (`MediaQuery.disableAnimations`, which the
/// transport bar passes in), playback resolves to phase boundaries only: [t]
/// holds at the last boundary passed, one still frame per phase.
class TimelineController extends ChangeNotifier {
  TimelineController({
    required TickerProvider vsync,
    required this.timeline,
    this.beat = const Duration(milliseconds: 600),
    SpeedCurve speedCurve = SpeedCurve.linear,
    double speed = 1,
    this._reducedMotion = false,
  }) : assert(speed > 0, 'a speed must move time forwards'),
       _curve = speedCurve,
       _speed = speed {
    _clock = AnimationController(vsync: vsync, duration: _playingTime)
      ..addListener(_tick)
      ..addStatusListener(_status);
  }

  /// What is being played.
  final AnimationTimeline<Object?> timeline;

  /// How long one beat takes at speed 1.
  final Duration beat;

  late final AnimationController _clock;
  SpeedCurve _curve;
  double _speed;
  bool _reducedMotion;

  /// The exact `t` a seek or a step asked for, held until the clock next
  /// moves: the curve's inverse is sampled, and a boundary read back through
  /// it could land a hair before itself.
  double? _held = 0;

  /// Where the timeline is, from 0 to 1.
  double get t {
    final double raw = _held ?? _curve.tAt(_clock.value);
    return _reducedMotion ? timeline.snapToPhase(raw) : raw;
  }

  /// The phase [t] is in.
  PhaseMark? get phase => timeline.phaseAt(t);

  bool get isPlaying => _clock.isAnimating;

  /// At the end, where play starts again from the beginning.
  bool get atEnd => t >= 1;

  /// The playing time is the beats at [beat] each, divided by this.
  double get speed => _speed;
  set speed(double value) {
    assert(value > 0, 'a speed must move time forwards');
    if (value == _speed) {
      return;
    }
    _speed = value;
    _retime();
  }

  /// How wall-clock progress maps to [t]. Changing it keeps [t] where it is.
  SpeedCurve get speedCurve => _curve;
  set speedCurve(SpeedCurve value) {
    if (identical(value, _curve)) {
      return;
    }
    final double at = t;
    _curve = value;
    _moveTo(at);
  }

  /// Whether playback shows only one still frame per phase.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) {
      return;
    }
    _reducedMotion = value;
    notifyListeners();
  }

  void play() {
    if (atEnd) {
      _moveTo(0);
    }
    _held = null;
    _clock.forward();
    notifyListeners();
  }

  void pause() {
    if (!_clock.isAnimating) {
      return;
    }
    final double at = _curve.tAt(_clock.value);
    _clock.stop();
    _held = at;
    notifyListeners();
  }

  /// Goes to [t], clamped to the timeline. Playing stays playing.
  void seek(double t) {
    final bool playing = _clock.isAnimating;
    _moveTo(t.clamp(0.0, 1.0));
    if (playing) {
      _held = null;
      _clock.forward();
    }
    notifyListeners();
  }

  /// Pauses, then goes to the next phase boundary, and never past the end.
  void stepToNextPhase() {
    pause();
    seek(timeline.nextBoundary(t));
  }

  /// Pauses, then goes back to the start of this phase, or to the phase before
  /// it when already at a start.
  void stepToPreviousPhase() {
    pause();
    seek(timeline.previousBoundary(t));
  }

  /// Pauses at the very beginning.
  void reset() {
    pause();
    seek(0);
  }

  Duration get _playingTime => Duration(
    microseconds: (beat.inMicroseconds * timeline.beats / _speed).round(),
  );

  void _moveTo(double t) {
    _clock.value = _curve.wallAt(t);
    _held = t;
  }

  void _retime() {
    final bool playing = _clock.isAnimating;
    final double at = t;
    _clock.stop();
    _clock.duration = _playingTime;
    _moveTo(at);
    if (playing) {
      _held = null;
      _clock.forward();
    }
    notifyListeners();
  }

  void _tick() {
    if (_clock.isAnimating) {
      _held = null;
    }
    notifyListeners();
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _held = 1;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }
}
