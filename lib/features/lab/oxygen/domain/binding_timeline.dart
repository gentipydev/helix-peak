import 'package:flutter/foundation.dart';

import '../../../../shared/format.dart';
import '../../../../shared/motion/animation_timeline.dart';
import 'mwc.dart';

/// One frame of oxygen binding.
@immutable
final class BindingFrame {
  const BindingFrame({
    required this.t,
    required this.bound,
    required this.arriving,
    required this.relaxed,
    required this.pressure,
    required this.saturation,
  });

  final double t;

  /// How many oxygen molecules are bound.
  final int bound;

  /// How far the next one has come, 0 far off to 1 at its haem; 0 once all
  /// the sites are full.
  final double arriving;

  /// How far the molecule is from tense (0) to relaxed (1): the model's R
  /// share for a molecule with that many bound, `1 / (1 + L c^i)`.
  final double relaxed;

  /// Where the curve's marked point is: the pressure at which the sites are
  /// as full as this molecule is, and that fullness.
  final double pressure;
  final double saturation;
}

/// Oxygen binding one molecule at a time, driven by the MWC model.
///
/// Each step, one oxygen arrives and binds, then the molecule settles to the
/// tense-or-relaxed balance the model gives a molecule with that many bound.
/// The curve's point climbs to the pressure at which the sites are that full.
/// MWC treats the sites alike, so which site binds first is not the model's to
/// say; they are filled in the morph's own order.
class BindingTimeline extends AnimationTimeline<BindingFrame> {
  BindingTimeline(this.model)
    : _phases = List<PhaseMark>.unmodifiable(<PhaseMark>[
        for (int i = 0; i < model.sites; i++)
          PhaseMark(
            name: model.sites == 1
                ? 'Oxygen binds'
                : '${spelledLeading(i + 1)} of ${spelled(model.sites)} bound',
            t: i / model.sites,
            captionKey: 'bound${i + 1}',
          ),
      ]);

  final Mwc model;
  final List<PhaseMark> _phases;

  /// The highest pressure the curve is drawn to, in mmHg.
  static const double ceiling = 100;

  @override
  int get beats => model.sites * 2;

  @override
  List<PhaseMark> get phases => _phases;

  /// The pressure at which a molecule is [bound] of the way full, held to the
  /// curve's ceiling: the last site fills only as pressure goes without limit.
  double pressureFor(int bound) {
    if (bound <= 0) {
      return 0;
    }
    if (bound >= model.sites) {
      return ceiling;
    }
    final double p = model.pressureAt(bound / model.sites);
    return p < ceiling ? p : ceiling;
  }

  @override
  BindingFrame stateAt(double t) {
    final double at = t.clamp(0.0, 1.0);
    final int n = model.sites;
    final int step = (at * n).floor().clamp(0, n - 1);
    final double local = at * n - step;
    final double arriving = AnimationTimeline.slice(local, 0, 0.5);
    final bool done = local >= 0.5 || at >= 1;
    final int bound = done ? step + 1 : step;
    final double settle = AnimationTimeline.slice(local, 0.5, 1);
    final double relaxed = at >= 1
        ? model.relaxedWith(n)
        : model.relaxedWith(step) +
              (model.relaxedWith(step + 1) - model.relaxedWith(step)) * settle;
    final double from = pressureFor(step);
    final double to = pressureFor(step + 1);
    final double pressure = at >= 1
        ? to
        : from + (to - from) * AnimationTimeline.slice(local, 0, 1);
    return BindingFrame(
      t: at,
      bound: bound,
      arriving: at >= 1 ? 0 : (done ? 0 : arriving),
      relaxed: relaxed,
      pressure: pressure,
      saturation: model.saturation(pressure),
    );
  }
}
