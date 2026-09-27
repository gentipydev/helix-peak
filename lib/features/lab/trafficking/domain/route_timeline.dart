import 'package:flutter/foundation.dart';

import '../../../../shared/motion/animation_timeline.dart';
import 'trafficking_route.dart';

/// Where the scene is: which step of the route, and how far through it.
@immutable
final class RouteMoment {
  const RouteMoment(this.step, this.progress);

  /// The index of the step in [TraffickingRoute.steps].
  final int step;

  /// How far through that step's beat, from 0 to 1. The first half carries
  /// the chain there from the step before; the second is what happens there.
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is RouteMoment && other.step == step && other.progress == progress;

  @override
  int get hashCode => Object.hash(step, progress);

  @override
  String toString() => 'RouteMoment($step, $progress)';
}

/// A route played one step to a beat, each step a phase of its own.
final class RouteTimeline extends AnimationTimeline<RouteMoment> {
  RouteTimeline(this.route)
    : phases = List<PhaseMark>.unmodifiable(<PhaseMark>[
        for (int i = 0; i < route.steps.length; i++)
          PhaseMark(
            name: nameOf(route.steps[i].compartment),
            t: i / route.steps.length,
            captionKey: 'step-$i',
          ),
      ]);

  final TraffickingRoute route;

  @override
  final List<PhaseMark> phases;

  @override
  int get beats => route.steps.length;

  @override
  RouteMoment stateAt(double t) {
    final (int beat, double local) = beatAt(t);
    return RouteMoment(beat, local);
  }

  /// What the transport bar, a screen reader and the scene's own labels call
  /// a compartment.
  static String nameOf(Compartment compartment) => switch (compartment) {
    Compartment.cytosol => 'Cytosol',
    Compartment.er => 'Endoplasmic reticulum',
    Compartment.golgi => 'Golgi',
    Compartment.vesicle => 'Vesicle',
    Compartment.extracellular => 'Outside the cell',
    Compartment.membrane => 'Cell membrane',
    Compartment.nucleus => 'Nucleus',
    Compartment.gpiAnchored => 'Anchored to the surface',
    Compartment.unknown => 'Not known',
  };
}
