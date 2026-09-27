import 'package:flutter/foundation.dart';

import '../../../../core/evidence/protein_constraint.dart';
import 'route_evidence.dart';

/// Where a chain is at one step of its route.
enum Compartment {
  /// Where every chain is begun, on a ribosome in the cytosol.
  cytosol,

  /// The endoplasmic reticulum, which a signal peptide or a signal anchor
  /// takes the chain into as it is made.
  er,

  /// The Golgi apparatus, which everything leaving the ER passes through.
  golgi,

  /// The vesicles that bud from the Golgi and carry the chain to the surface.
  vesicle,

  /// Outside the cell, released when a vesicle fuses with the membrane.
  extracellular,

  /// The plasma membrane, held there by a stretch of the chain that crosses
  /// it.
  membrane,

  /// The nucleus. No route reaches it yet: nothing in [RouteEvidence] is a
  /// nuclear localization signal.
  nucleus,

  /// The outer face of the plasma membrane, held there by a GPI anchor
  /// rather than by any stretch of the chain.
  gpiAnchored,

  /// Somewhere the evidence does not settle. [TraffickingRoute.unresolved]
  /// says why.
  unknown,
}

/// What happens to the chain at a step: each is one piece of evidence acting
/// where it acts, in the order they are listed.
enum RouteEvent {
  /// Signal peptidase cuts the signal peptide off as the chain enters the ER.
  signalPeptideCleaved,

  /// A transmembrane span is threaded into the ER membrane, and the chain is
  /// held in membranes from then on.
  membraneInserted,

  /// The disulfide bridges form: in the ER for a chain that enters it, in the
  /// cytosol for one that never leaves.
  disulfidesFormed,

  /// The GPI-anchor signal is cut off, and a GPI anchor attached in its place.
  gpiAnchorAttached,

  /// The precursor is cut into its pieces, or around a stretch it loses.
  proproteinCut,
}

/// Why a route stops at [Compartment.unknown].
enum Unresolved {
  /// Whether any stretch crosses a membrane, which nothing has said. After a
  /// signal peptide, a transmembrane span holds the chain in the membrane and
  /// its absence lets it go. Without a signal peptide, a span would take the
  /// chain into the ER as a signal anchor, and its absence leaves the chain in
  /// the cytosol.
  topology,

  /// The evidence contradicts itself: a GPI-anchor signal with no signal
  /// peptide to take the chain into the ER, where the anchor is attached, or
  /// with a transmembrane span to hold it there besides.
  conflict,
}

/// One compartment on a route, and what happens to the chain there.
@immutable
final class RouteStep {
  const RouteStep(this.compartment, [this.events = const <RouteEvent>[]]);

  final Compartment compartment;
  final List<RouteEvent> events;

  @override
  String toString() =>
      events.isEmpty ? compartment.name : '${compartment.name} $events';
}

/// The compartments one chain passes through, in order, derived from its
/// evidence rather than written down for it.
///
/// Every chain starts in the cytosol. A signal peptide or a transmembrane
/// span takes it into the ER as it is made, and from there it goes through
/// the Golgi and a vesicle to the surface. What it does there follows from
/// the rest of the evidence. A GPI-anchor signal leaves it anchored, a
/// transmembrane span holds it in the membrane, and with neither it is
/// released. A chain with neither leader nor span stays where it was made.
/// Where the evidence stops short of a compartment the route says
/// [Compartment.unknown] and [unresolved] says why, rather than choosing.
@immutable
final class TraffickingRoute {
  const TraffickingRoute._(this.evidence, this.steps, this.unresolved);

  factory TraffickingRoute.derive(RouteEvidence evidence) {
    final bool signal = evidence.signalPeptide != null;
    final bool gpi = evidence.gpiSignal != null;
    final List<(int, int)>? spans = evidence.transmembrane;
    final bool crosses = spans != null && spans.isNotEmpty;
    final bool bridged = evidence.bridges.isNotEmpty;
    final bool cut = evidence.cut;

    // A chain that never leaves the cytosol is bridged and cut there. Where
    // the route stops short, so does what is known of where that happens, and
    // the two go with the unknown step.
    final List<RouteEvent> atFold = <RouteEvent>[
      if (bridged) RouteEvent.disulfidesFormed,
      if (cut) RouteEvent.proproteinCut,
    ];
    TraffickingRoute stops(Unresolved why) =>
        TraffickingRoute._(evidence, <RouteStep>[
          const RouteStep(Compartment.cytosol),
          RouteStep(Compartment.unknown, atFold),
        ], why);

    if (gpi && (!signal || crosses)) {
      return stops(Unresolved.conflict);
    }
    if (!signal && !crosses) {
      return spans == null
          ? stops(Unresolved.topology)
          : TraffickingRoute._(evidence, <RouteStep>[
              RouteStep(Compartment.cytosol, atFold),
            ], null);
    }

    final Compartment destination = gpi
        ? Compartment.gpiAnchored
        : spans == null
        ? Compartment.unknown
        : crosses
        ? Compartment.membrane
        : Compartment.extracellular;
    // A cut that parts a piece held in the membrane from a piece that is not
    // lets the free one go at the surface. Every other cut on the way out is
    // made after the Golgi, in the vesicle, where a convertase cuts at the
    // basic sites R3.5 names.
    final bool shed = cut && crosses && _sheds(evidence.pieces, spans);
    return TraffickingRoute._(evidence, <RouteStep>[
      const RouteStep(Compartment.cytosol),
      RouteStep(Compartment.er, <RouteEvent>[
        if (signal) RouteEvent.signalPeptideCleaved,
        if (crosses) RouteEvent.membraneInserted,
        if (bridged) RouteEvent.disulfidesFormed,
        if (gpi) RouteEvent.gpiAnchorAttached,
      ]),
      const RouteStep(Compartment.golgi),
      RouteStep(Compartment.vesicle, <RouteEvent>[
        if (cut && !shed) RouteEvent.proproteinCut,
      ]),
      RouteStep(destination, <RouteEvent>[if (shed) RouteEvent.proproteinCut]),
    ], destination == Compartment.unknown ? Unresolved.topology : null);
  }

  /// What the route was derived from.
  final RouteEvidence evidence;

  /// The compartments in the order the chain reaches them, the first always
  /// the cytosol.
  final List<RouteStep> steps;

  /// Why the route stops at [Compartment.unknown], or null where it does not.
  final Unresolved? unresolved;

  bool get resolved => unresolved == null;

  /// Where the route ends.
  Compartment get destination => steps.last.compartment;

  List<Compartment> get compartments => <Compartment>[
    for (final RouteStep step in steps) step.compartment,
  ];

  /// The compartment [event] happens in, or null where it does not happen.
  Compartment? whereOf(RouteEvent event) => steps
      .where((RouteStep step) => step.events.contains(event))
      .firstOrNull
      ?.compartment;

  /// Whether some piece holds a transmembrane span and some piece does not.
  static bool _sheds(List<ConstraintRegion> pieces, List<(int, int)> spans) {
    bool held(ConstraintRegion piece) => spans.any(
      ((int, int) span) => span.$1 <= piece.end && span.$2 >= piece.start,
    );
    return pieces.any(held) && !pieces.every(held);
  }

  @override
  String toString() => 'TraffickingRoute($steps)';
}
