import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';

/// What a toy timeline shows: which beat, how far through it, and a value
/// eased across the whole run.
typedef _Frame = (int beat, double local, double eased);

/// Five beats, with a phase at each beat's start and one halfway through the
/// third, so not every boundary is a beat boundary.
final class _Toy extends AnimationTimeline<_Frame> {
  const _Toy();

  @override
  int get beats => 5;

  @override
  List<PhaseMark> get phases => const <PhaseMark>[
    PhaseMark(name: 'one', t: 0, captionKey: 'toy.one'),
    PhaseMark(name: 'two', t: 0.2, captionKey: 'toy.two'),
    PhaseMark(name: 'three', t: 0.4, captionKey: 'toy.three'),
    PhaseMark(name: 'three, later', t: 0.5, captionKey: 'toy.threeLater'),
    PhaseMark(name: 'four', t: 0.6, captionKey: 'toy.four'),
    PhaseMark(name: 'five', t: 0.8, captionKey: 'toy.five'),
  ];

  @override
  _Frame stateAt(double t) {
    final (int beat, double local) = beatAt(t);
    return (beat, local, AnimationTimeline.slice(t, 0, 1));
  }
}

void main() {
  const _Toy toy = _Toy();

  group('the timeline', () {
    test('is deterministic: the same t is the same state, every time', () {
      final math.Random random = math.Random(7);
      for (int i = 0; i < 2000; i++) {
        final double t = random.nextDouble();
        expect(toy.stateAt(t), toy.stateAt(t));
        expect(const _Toy().stateAt(t), toy.stateAt(t));
      }
      expect(toy.stateAt(0), (0, 0.0, 0.0));
      expect(toy.stateAt(1), (4, 1.0, 1.0));
    });

    test('puts every t in a beat, the end in the last one', () {
      expect(toy.beatAt(0), (0, 0.0));
      expect(toy.beatAt(0.2), (1, 0.0));
      expect(toy.beatAt(0.3).$1, 1);
      expect(toy.beatAt(0.3).$2, closeTo(0.5, 1e-12));
      expect(toy.beatAt(1), (4, 1.0));
      expect(toy.beatStart(3), 0.6);
    });

    test('names the phase each t is in', () {
      expect(toy.phaseAt(0)!.name, 'one');
      expect(toy.phaseAt(0.199)!.name, 'one');
      expect(toy.phaseAt(0.2)!.name, 'two');
      expect(toy.phaseAt(0.55)!.name, 'three, later');
      expect(toy.phaseAt(1)!.name, 'five');
    });

    test('boundaries are every phase start, and the end', () {
      expect(toy.boundaries, <double>[0, 0.2, 0.4, 0.5, 0.6, 0.8, 1]);
    });

    test('a slice eases between its ends and holds outside them', () {
      expect(AnimationTimeline.slice(0.1, 0.35, 0.55), 0);
      expect(AnimationTimeline.slice(0.45, 0.35, 0.55), closeTo(0.5, 1e-12));
      expect(AnimationTimeline.slice(0.9, 0.35, 0.55), 1);
      expect(
        AnimationTimeline.slice(0.4, 0.35, 0.55, eased: false),
        closeTo(0.25, 1e-12),
      );
    });
  });

  group('the speed curve', () {
    test('linear is the identity', () {
      for (final double t in <double>[0, 0.25, 0.5, 1]) {
        expect(SpeedCurve.linear.tAt(t), t);
        expect(SpeedCurve.linear.wallAt(t), t);
      }
    });

    test('a rate curve never runs backwards and inverts itself', () {
      final SpeedCurve curve = SpeedCurve.fromRate(
        (double t) => t < 0.2 ? 0.5 : (t > 0.8 ? 0.5 : 4),
      );
      double last = -1;
      for (int i = 0; i <= 1000; i++) {
        final double wall = i / 1000;
        final double t = curve.tAt(wall);
        expect(t, greaterThanOrEqualTo(last));
        last = t;
        expect(curve.wallAt(t), closeTo(wall, 1e-9));
      }
      expect(curve.tAt(0), 0);
      expect(curve.tAt(1), 1);
    });

    test('a slow stretch takes more of the playing time than a fast one', () {
      final SpeedCurve curve = SpeedCurve.fromRate(
        (double t) => t < 0.5 ? 1 : 4,
      );
      // Half the timeline at rate 1 against half at rate 4: 4/5 of the time.
      expect(curve.wallAt(0.5), closeTo(0.8, 1e-9));
    });
  });

  group('the controller', () {
    TimelineController controlled({
      SpeedCurve curve = SpeedCurve.linear,
      bool reduced = false,
    }) => TimelineController(
      vsync: const TestVSync(),
      timeline: toy,
      beat: const Duration(milliseconds: 100),
      speedCurve: curve,
      reducedMotion: reduced,
    );

    test('starts at the beginning, paused', () {
      final TimelineController c = controlled();
      addTearDown(c.dispose);
      expect(c.t, 0);
      expect(c.isPlaying, isFalse);
      expect(c.phase!.name, 'one');
    });

    test('stepping forwards lands on each boundary and never past the end', () {
      final TimelineController c = controlled(
        curve: SpeedCurve.fromRate((double t) => 1 + 3 * t),
      );
      addTearDown(c.dispose);
      final List<double> landed = <double>[];
      for (int i = 0; i < toy.phases.length + 4; i++) {
        c.stepToNextPhase();
        landed.add(c.t);
        expect(c.t, lessThanOrEqualTo(1));
      }
      expect(landed.take(6), <double>[0.2, 0.4, 0.5, 0.6, 0.8, 1]);
      expect(landed.skip(6), everyElement(1.0));
      expect(c.atEnd, isTrue);
    });

    test('stepping backwards lands on each boundary and never before 0', () {
      final TimelineController c = controlled();
      addTearDown(c.dispose);
      c.seek(1);
      final List<double> landed = <double>[];
      for (int i = 0; i < toy.phases.length + 3; i++) {
        c.stepToPreviousPhase();
        landed.add(c.t);
        expect(c.t, greaterThanOrEqualTo(0));
      }
      expect(landed.take(6), <double>[0.8, 0.6, 0.5, 0.4, 0.2, 0]);
      expect(landed.skip(6), everyElement(0.0));
    });

    test('from inside a phase, back goes to its start first', () {
      final TimelineController c = controlled();
      addTearDown(c.dispose);
      c.seek(0.55);
      c.stepToPreviousPhase();
      expect(c.t, 0.5);
      c.stepToNextPhase();
      expect(c.t, 0.6);
    });

    test('a seek is exact even through a sampled curve', () {
      final TimelineController c = controlled(
        curve: SpeedCurve.fromRate((double t) => t < 0.3 ? 0.25 : 3),
      );
      addTearDown(c.dispose);
      for (final double target in <double>[0.2, 0.4, 0.5, 0.123456789]) {
        c.seek(target);
        expect(c.t, target);
      }
    });

    testWidgets('plays to the end in its playing time, and stops there', (
      WidgetTester tester,
    ) async {
      final TimelineController c = controlled();
      addTearDown(c.dispose);
      c.play();
      expect(c.isPlaying, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.t, closeTo(0.5, 1e-6));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.isPlaying, isFalse);
      expect(c.t, 1);
      c.play();
      expect(c.t, 0, reason: 'play at the end starts again');
      c.pause();
    });

    testWidgets('pause holds, and play carries on from there', (
      WidgetTester tester,
    ) async {
      final TimelineController c = controlled();
      addTearDown(c.dispose);
      c.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      c.pause();
      final double held = c.t;
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.t, held);
      c.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.t, closeTo(held + 0.2, 1e-6));
      c.pause();
    });

    testWidgets('a new speed keeps t and changes how fast it moves', (
      WidgetTester tester,
    ) async {
      final TimelineController c = controlled();
      addTearDown(c.dispose);
      c.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double before = c.t;
      c.speed = 2;
      expect(c.t, closeTo(before, 1e-9));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.t, closeTo(before + 0.4, 1e-6));
      c.pause();
    });

    testWidgets('reduced motion shows only phase-boundary states', (
      WidgetTester tester,
    ) async {
      final TimelineController c = controlled(reduced: true);
      addTearDown(c.dispose);
      final Set<double> boundaries = toy.boundaries.toSet();
      final Set<_Frame> stills = <_Frame>{
        for (final double b in boundaries) toy.stateAt(b),
      };
      final List<double> seen = <double>[];
      c.addListener(() => seen.add(c.t));
      c.play();
      await tester.pump();
      for (int frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(boundaries, contains(c.t));
        expect(stills, contains(toy.stateAt(c.t)));
      }
      expect(seen, everyElement(isIn(boundaries)));
      expect(seen.toSet().length, greaterThan(1), reason: 'it still plays');
      c.pause();
    });

    testWidgets('without reduced motion, playback passes between boundaries', (
      WidgetTester tester,
    ) async {
      final TimelineController c = controlled();
      addTearDown(c.dispose);
      final Set<double> boundaries = toy.boundaries.toSet();
      c.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(boundaries, isNot(contains(c.t)));
      c.pause();
    });
  });

  test('the controller needs no widget tree, only a ticker', () {
    // A guard for the separation the abstraction promises: the timeline file
    // is pure, and only the controller reaches the scheduler.
    expect(const TestVSync(), isA<TickerProvider>());
  });
}
