import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/peptide_lm/domain/loop_pace.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';

import 'support/toy_trace.dart';

/// A loss that falls slowly, then steeply between steps 50 and 95, then
/// levels out: as a run that learns its data by heart does.
double _burst(int step) => 0.06 + 3.16 / (1 + math.exp((step - 62) / 8)) + 0.002 * (200 - step) / 200;

void main() {
  final TrainingTrace toy = toyTrace();
  final Map<String, LoopPace> paces = <String, LoopPace>{
    'curated-like': LoopPace.plan(steps: 200, kept: <int>[1, 13, 21, 49, 66, 95, 200], loss: _burst),
    'toy': LoopPace.of(toy),
    'four steps': LoopPace.plan(steps: 4, kept: <int>[1, 4], loss: (int s) => 3.0 - 0.1 * s),
    'one step': LoopPace.plan(steps: 1, kept: <int>[1], loss: (int s) => 3.0),
  };

  test('the parts follow each other and fill the stage', () {
    for (final MapEntry<String, LoopPace> entry in paces.entries) {
      final LoopPace pace = entry.value;
      expect(pace.beats, LmStage.loop.beats, reason: entry.key);
      expect(pace.spans.first.from, 0, reason: entry.key);
      expect(pace.spans.last.to, LmStage.loop.beats, reason: entry.key);
      for (int i = 1; i < pace.spans.length; i++) {
        expect(pace.spans[i].from, closeTo(pace.spans[i - 1].to, 1e-9), reason: entry.key);
        expect(pace.spans[i].to, greaterThan(pace.spans[i].from), reason: entry.key);
      }
      expect(
        pace.spans.take(3).map((LoopSpan s) => s.part),
        <LoopPart>[LoopPart.done, LoopPart.guesses, LoopPart.cost],
        reason: entry.key,
      );
      expect(
        pace.spans.skip(pace.spans.length - 2).map((LoopSpan s) => s.part),
        <LoopPart>[LoopPart.left, LoopPart.heart],
        reason: entry.key,
      );
    }
  });

  test('the step never goes back, sits still where the loop stops, and ends on the last', () {
    for (final MapEntry<String, LoopPace> entry in paces.entries) {
      final LoopPace pace = entry.value;
      double before = 1;
      for (int i = 0; i <= 4000; i++) {
        final LoopMoment now = pace.at(i / 4000);
        expect(now.step, greaterThanOrEqualTo(before - 1e-9), reason: '${entry.key} at $i');
        expect(now.step, inInclusiveRange(1, pace.steps), reason: entry.key);
        switch (now.part) {
          case LoopPart.done:
          case LoopPart.guesses:
          case LoopPart.cost:
            expect(now.step, 1, reason: entry.key);
          case LoopPart.single:
          case LoopPart.hold:
            expect(now.step, pace.stops[now.stop].step, reason: entry.key);
          case LoopPart.left:
          case LoopPart.heart:
            expect(now.step, pace.steps, reason: entry.key);
          case LoopPart.move:
            break;
        }
        before = now.step;
      }
      expect(pace.at(1).part, LoopPart.heart, reason: entry.key);
      expect(pace.at(1).step, pace.steps, reason: entry.key);
    }
  });

  test('steps 2 to 4 one at a time, then every kept step held', () {
    String stops(LoopPace pace) => pace.stops.map((LoopStop s) => '${s.step}${s.held ? 'h' : ''}').join(' ');
    expect(stops(paces['curated-like']!), '2 3 4 13h 21h 49h 66h 95h 200h');
    // The toy keeps steps 2 and 3, so they are held, never passed as singles.
    expect(stops(paces['toy']!), '2h 3h 4 9h 11h 20h');
    expect(stops(paces['four steps']!), '2 3 4h');
    expect(paces['one step']!.stops, isEmpty);
  });

  test('a long move takes at least its least, and the steepest fall the longest', () {
    final LoopPace pace = paces['curated-like']!;
    final List<LoopSpan> moves = <LoopSpan>[
      for (final LoopSpan s in pace.spans)
        if (s.part == LoopPart.move && pace.stops[s.stop].held) s,
    ];
    expect(moves, hasLength(6));
    for (final LoopSpan move in moves) {
      expect(move.to - move.from, greaterThanOrEqualTo(LoopPace.leastMove - 1e-9));
    }
    final LoopSpan longest = moves.reduce((LoopSpan a, LoopSpan b) => a.to - a.from >= b.to - b.from ? a : b);
    expect(pace.stops[longest.stop].step, 66);
  });

  test('a kept step picked lands in its hold, settled; step 1 at the end of its cost', () {
    for (final MapEntry<String, LoopPace> entry in paces.entries) {
      final LoopPace pace = entry.value;
      final LoopMoment first = pace.at(pace.landing(0));
      expect(first.part, LoopPart.cost, reason: entry.key);
      expect(first.step, 1, reason: entry.key);
      for (final LoopStop stop in pace.stops.where((LoopStop s) => s.held)) {
        final LoopMoment there = pace.at(pace.landing(stop.checkpoint!));
        expect(there.part, LoopPart.hold, reason: '${entry.key} ${stop.step}');
        expect(there.step, stop.step, reason: '${entry.key} ${stop.step}');
        expect(there.through, greaterThan(0), reason: '${entry.key} ${stop.step}');
      }
    }
  });

  test('the samples hit every part, once', () {
    for (final MapEntry<String, LoopPace> entry in paces.entries) {
      final LoopPace pace = entry.value;
      expect(pace.samples, hasLength(pace.spans.length), reason: entry.key);
      for (int i = 0; i < pace.spans.length; i++) {
        expect(identical(pace.at(pace.samples[i]).span, pace.spans[i]), isTrue, reason: '${entry.key} $i');
      }
    }
  });

  test('a run is laid out once', () {
    expect(identical(LoopPace.of(toy), LoopPace.of(toy)), isTrue);
  });
}
