import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/lab/oxygen/domain/binding_timeline.dart';
import 'package:helixpeek/features/lab/oxygen/domain/mwc.dart';
import 'package:helixpeek/features/lab/oxygen/domain/oxygen_morph.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';

const String fixture =
    'test/features/lab/oxygen/fixtures/hemoglobin-a_morph.json';

void main() {
  final Mwc adult = OxygenModel.of(Carrier.adult, 7.4);

  test('four sites, one step each, named by how many are bound', () {
    final BindingTimeline timeline = BindingTimeline(adult);
    expect(timeline.phases.map((PhaseMark p) => p.name), <String>[
      'One of four bound',
      'Two of four bound',
      'Three of four bound',
      'Four of four bound',
    ]);
    expect(
      BindingTimeline(OxygenModel.of(Carrier.oneSite, 7.4)).phases.single.name,
      'Oxygen binds',
    );
  });

  test(
    'MWC drives the molecule: after each binding it is R_i, not a Hill curve',
    () {
      final BindingTimeline timeline = BindingTimeline(adult);
      expect(timeline.stateAt(0).relaxed, adult.relaxedWith(0));
      for (int i = 0; i < 4; i++) {
        final BindingFrame settled = timeline.stateAt((i + 1) / 4 - 1e-9);
        expect(settled.bound, i + 1);
        expect(settled.relaxed, closeTo(adult.relaxedWith(i + 1), 1e-6));
      }
      expect(timeline.stateAt(1).relaxed, adult.relaxedWith(4));
      // Mostly tense with two bound or fewer here, mostly relaxed with three.
      expect(adult.relaxedWith(2), lessThan(0.5));
      expect(adult.relaxedWith(3), greaterThan(0.9));
    },
  );

  test('the point climbs the model’s own curve, a quarter at a time', () {
    final BindingTimeline timeline = BindingTimeline(adult);
    for (double t = 0; t <= 1; t += 0.01) {
      final BindingFrame frame = timeline.stateAt(t);
      expect(
        frame.saturation,
        closeTo(adult.saturation(frame.pressure), 1e-12),
      );
    }
    for (int i = 1; i < 4; i++) {
      final BindingFrame frame = timeline.stateAt(i / 4 - 1e-9);
      expect(frame.saturation, closeTo(i / 4, 1e-6));
    }
  });

  test('one site has no tense state to leave', () {
    final BindingTimeline timeline = BindingTimeline(
      OxygenModel.of(Carrier.oneSite, 7.4),
    );
    for (final double t in <double>[0, 0.3, 0.7, 1]) {
      expect(timeline.stateAt(t).relaxed, 1);
    }
  });

  test('the morph is the two states of one tetramer, in one frame', () {
    final OxygenMorph morph = OxygenMorph.decode(
      File(fixture).readAsBytesSync(),
      oxygenAssembly,
    );
    expect(morph.chains.map((MorphChain c) => c.node), <String>[
      'alpha1',
      'beta1',
      'alpha2',
      'beta2',
    ]);
    expect(morph.chains.map((MorphChain c) => c.gene).toSet(), hasLength(2));
    for (final MorphChain chain in morph.chains) {
      expect(chain.tense.length, chain.relaxed.length);
      expect(chain.oxygen, hasLength(2));
    }
    expect(morph.entries, <String, String>{'tense': '2DN2', 'relaxed': '2DN1'});
    expect(morph.turnedDegrees, closeTo(14.1, 0.05));
    expect(
      () => OxygenMorph.decode(File(fixture).readAsBytesSync(), 'another'),
      throwsFormatException,
    );
  });
}
