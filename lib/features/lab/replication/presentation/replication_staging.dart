import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../domain/genome_replication.dart';
import '../domain/monotone_curve.dart';
import '../domain/replication_tour.dart';
import 'replication_camera.dart';
import 'replication_geometry.dart';
import 'replication_inks.dart';

/// Something on the fork at one moment: where it is, and how present. Every
/// value is a continuous function of the moment, so nothing on the stage can
/// jump or blink from one frame to the next; `replication_smoothness_test`
/// holds the scene to that.
@immutable
sealed class StagedItem {
  const StagedItem(this.key, this.centre, this.opacity);

  /// The same thing on every frame it appears in.
  final String key;

  /// In the scene's own coordinates, before the camera.
  final Offset centre;
  final double opacity;
}

/// A folded protein envelope, drawn from a recorded picture.
final class StagedMolecule extends StagedItem {
  const StagedMolecule(
    String key,
    this.ink,
    Offset centre,
    this.size, {
    this.seed = 11,
    this.channel = true,
    this.angle = 0,
    double opacity = 1,
  }) : super(key, centre, opacity);
  final SceneInk ink;
  final Size size;
  final int seed;
  final bool channel;
  final double angle;
}

/// Which ring of domains a [StagedRing] is.
enum RingKind { pcna, mcmN, mcmC, rfc, orc, cdc6 }

/// A ring of protein domains around the DNA: PCNA, a tier of the CMG
/// helicase's MCM2–7 motor, or RFC, the clamp loader, on top of PCNA.
final class StagedRing extends StagedItem {
  const StagedRing(
    String key,
    this.kind,
    Offset centre, {
    this.rotation = 0,
    this.open = 0,
    this.axis = 0,
    this.atp = 0,
    this.partners = 1,
    double opacity = 1,
  }) : super(key, centre, opacity);
  final RingKind kind;

  /// Turn about the DNA, radians, as the ring slides along the helix.
  final double rotation;

  /// How far one subunit interface is held open, radians.
  final double open;

  /// The DNA's direction through the ring, radians from vertical.
  final double axis;

  /// Where the wave of ATP hydrolysis is around the ring, in turns.
  final double atp;

  /// How present the CMG's Cdc45 and GINS are.
  final double partners;
}

/// Topoisomerase II, and how far through its cycle it is: [gate] opens the
/// cut G-segment, [sites] lights the tyrosines that hold its ends.
final class StagedTopo extends StagedItem {
  const StagedTopo(
    String key,
    Offset centre, {
    this.gate = 0,
    this.sites = 0,
    double opacity = 1,
  }) : super(key, centre, opacity);
  final double gate;
  final double sites;
}

/// A soft band behind the origin's A/T-rich stretch, [length] nt long.
final class StagedBand extends StagedItem {
  const StagedBand(String key, Offset centre, this.length, double opacity)
    : super(key, centre, opacity);
  final double length;
}

/// A duplex seen end-on: the T-segment topoisomerase II passes through the
/// G-segment. [turn] spins its strands as it goes.
final class StagedDuplexEnd extends StagedItem {
  const StagedDuplexEnd(String key, Offset centre, this.turn, double opacity)
    : super(key, centre, opacity);
  final double turn;
}

/// The soft light of a working active site.
final class StagedGlow extends StagedItem {
  const StagedGlow(super.key, super.centre, this.ink, this.pulse, super.opacity);
  final SceneInk ink;
  final double pulse;
}

/// A stretch of template drawn again over the protein it passes through,
/// from [from] to [to] nucleotides relative to the fork.
final class StagedTrace extends StagedItem {
  const StagedTrace(
    String key, {
    required this.leading,
    required this.from,
    required this.to,
  }) : super(key, Offset.zero, 1);
  final bool leading;
  final double from;
  final double to;
}

/// Words on the screen: at [at] in screen space, with a line to [target]
/// when they name something.
@immutable
class StagedLabel {
  const StagedLabel(
    this.key,
    this.text,
    this.at,
    this.ink, {
    this.target,
    this.size = 12,
    this.centred = false,
    this.opacity = 1,
  });
  final String key;
  final String text;
  final Offset at;
  final Offset? target;
  final SceneInk ink;
  final double size;
  final bool centred;
  final double opacity;
}

@immutable
class StagedArrow {
  const StagedArrow(this.key, this.from, this.to, this.ink, this.opacity);
  final String key;
  final Offset from;
  final Offset to;
  final SceneInk ink;
  final double opacity;
}

/// A displaced RNA 5′ end: [length] nucleotides hanging from [base] towards
/// FEN1 at [towards].
@immutable
class StagedFlap {
  const StagedFlap(this.key, this.base, this.towards, this.length, this.opacity);
  final String key;
  final Offset base;
  final Offset towards;
  final double length;
  final double opacity;
}

/// A nick in a new backbone, and how far ligase has sealed it.
@immutable
class StagedNick {
  const StagedNick(this.key, this.centre, this.sealed, this.opacity);
  final String key;
  final Offset centre;
  final double sealed;
  final double opacity;
}

/// Everything the fork shows at [moment], through [camera].
class ReplicationStaging {
  ReplicationStaging(
    this.moment,
    this.g,
    this.camera, {
    this.showLabels = true,
    this.reducedMotion = false,
  }) {
    _machinery();
    _overlays();
    _words();
  }

  final ReplicationMoment moment;
  final ReplicationGeometry g;
  final ReplicationCamera camera;
  final bool showLabels;
  final bool reducedMotion;

  final List<StagedItem> items = <StagedItem>[];

  /// Rings, drawn in two halves: behind the DNA and in front of it.
  final List<StagedRing> rings = <StagedRing>[];

  /// What belongs to the origin rather than a fork: drawn once, not turned
  /// about the origin with the lower fork.
  final List<StagedItem> shared = <StagedItem>[];
  final List<StagedLabel> labels = <StagedLabel>[];
  final List<StagedArrow> arrows = <StagedArrow>[];
  final List<StagedFlap> flaps = <StagedFlap>[];
  final List<StagedNick> nicks = <StagedNick>[];

  ReplicationFrame get _f => g.frame;
  double get _s => _f.seconds;

  static double _eased(double t, double start, double end) =>
      ReplicationFrame.eased(t, start, end);

  double get _pulse => 0.5 + 0.5 * math.sin(_s * 2.4);

  // --- The enzymes' states, shared by the molecules, RPA and the words. ---

  static const double _origin = GenomeReplication.origin;

  // How fast the fork runs as the origin finishes melting, so the CMG that
  // passed its partner joins the fork at the fork's own pace.
  static final double _paceAtFiring =
      (const ReplicationFrame(-29.999).fork -
          const ReplicationFrame(-30.001).fork) /
      0.002;

  static final MonotoneCurve _cmgRise = MonotoneCurve(
    <(double, double)>[
      (-36, _origin - 12),
      (-30, const ReplicationFrame(-30).fork - 6.1),
    ],
    startSlope: 0,
    endSlope: _paceAtFiring,
  );

  /// The upper fork's CMG. It is loaded as the lower ring of the double
  /// hexamer, below the origin, its N-terminal tier facing its partner; at
  /// firing it leaves dsDNA for the leading-strand template, passes its
  /// partner, and from then on travels with the fork.
  ({Offset centre, double opacity, double open}) get _cmg {
    final double index;
    if (_s >= -30) {
      index = _f.fork - 6.1;
    } else if (_s > -36) {
      index = _cmgRise.at(_s);
    } else {
      index = _origin - 12 - 10 * (1 - _f.mcmDocked);
    }
    return (
      centre:
          Offset(180 - 16 * _f.cmgOnStrand, g.yOf(index)) +
          const Offset(-44, 26) * (1 - _f.mcmArrive),
      opacity: _f.mcmArrive,
      open: 1.1 * (1 - _f.mcmClosed),
    );
  }

  /// Primase–Pol α on lagging fragment [k] (−1, 0 or 1): it arrives as its
  /// primer starts, and leaves once Pol δ has taken the primer end.
  _Enzyme _primase(int k) {
    final double start = ReplicationFrame.primedAt(k);
    final double handoff = ReplicationFrame.handoffAt(k);
    final double arrival = _eased(_s, start - 1, start);
    final double departure = _eased(_s, handoff, handoff + 2);
    // Where Pol α left its primer end: the tip, held once Pol δ takes over.
    final Offset site = g.centre(
      ReplicationFrame(math.min(_s, handoff)).tipOf(k),
      leading: false,
    );
    return _Enzyme(
      site: site,
      centre:
          site + Offset(24 * (1 - arrival + departure), -13 * (1 - arrival)),
      opacity: arrival * (1 - departure),
    );
  }

  /// Primase–Pol α starting the leading strand at the origin.
  _Enzyme get _leadingPrimase {
    final double arrival = _eased(_s, -30, -29);
    final double departure = _eased(_s, -23, -21);
    final Offset site = g.centre(
      ReplicationFrame(math.min(_s, -23)).leadingTip,
      leading: true,
    );
    return _Enzyme(
      site: site,
      centre:
          site + Offset(-24 * (1 - arrival + departure), -13 * (1 - arrival)),
      opacity: arrival * (1 - departure),
    );
  }

  /// Pol ε takes the leading strand from Pol α, with its PCNA.
  _Enzyme get _epsilon {
    final double arrival = _eased(_s, -23, -21);
    final Offset site = g.leadingEnzyme;
    return _Enzyme(
      site: site,
      centre: site + Offset(-25 * (1 - arrival), 0),
      opacity: arrival,
      working: arrival,
      clamp: _eased(_s, -25, -23.5),
    );
  }

  /// Where lagging fragment [k] is growing: its 3′ end, or while it replaces
  /// the primer ahead of it, the displacement front.
  double _laggingTip(int k) => switch (k) {
    -1 => _f.tipOf(-1) - ReplicationFrame.atOrigin.replaced(_s),
    0 => _f.tipOf(0) - ReplicationFrame.earlier.replaced(_s),
    _ =>
      _s >= ReplicationFrame.replaceStart
          ? 99.5 - _f.replacedBases
          : _f.tipOf(1),
  };

  /// Pol δ leaves fragment [k] once it has replaced the primer ahead.
  static double _deltaEnd(int k) => switch (k) {
    -1 => -2,
    0 => 54,
    _ => 100,
  };

  /// RFC's visit with PCNA to fragment [k]'s primer end: arrive, close,
  /// leave, as model seconds.
  static (double, double, double, double, double, double) _loading(int k) {
    final double start = ReplicationFrame.primedAt(k);
    return k < 0
        ? (
            start + 1.2,
            start + 2.2,
            start + 2.3,
            start + 2.9,
            start + 2.9,
            start + 4.2,
          )
        : (
            start + 9,
            start + 10,
            start + 10.2,
            start + 11.2,
            start + 11.6,
            start + 12.6,
          );
  }

  /// Pol δ on lagging fragment [k], with its clamp.
  _Enzyme _delta(int k) {
    final double handoff = ReplicationFrame.handoffAt(k);
    final double end = _deltaEnd(k);
    final double arrival = _eased(_s, handoff, handoff + 2);
    final double departure = _eased(_s, end, end + 2);
    final Offset site = g.centre(_laggingTip(k), leading: false);
    final (double arrive, double arrived, _, _, _, _) = _loading(k);
    return _Enzyme(
      site: site,
      centre: site + Offset(-25 * (1 - arrival + departure), 0),
      opacity: arrival * (1 - departure),
      working: arrival * (1 - _eased(_s, end - 0.6, end)),
      clamp: _eased(_s, arrive, arrived) * (1 - departure),
    );
  }

  /// How far fragment [k]'s RNA primer is under way: 0 before primase
  /// starts it, 1 once a few nucleotides are made.
  double _primerMade(int k) {
    final double fivePrime = ReplicationFrame.fivePrimeOf(k);
    final double made = fivePrime - math.max(_f.tipOf(k), fivePrime - 10);
    return ReplicationGeometry.ease((made - 2) / 5);
  }

  /// How clearly fragment [k]'s RNA primer is there to be named: once a
  /// few nucleotides are made, and until Pol δ has replaced it.
  double _primerShown(int k) =>
      _primerMade(k) * (1 - (k == 0 ? _eased(_s, 88.5, 94) : 0));

  /// FEN1 at fragment 1's replacement (the tour's), or fragment 0's.
  double _fen1Of(int k) => k == 0
      ? _eased(_s, 49.5, 50.5) * (1 - _eased(_s, 54.5, 55.5))
      : _eased(_s, 87, 88.5) * (1 - _eased(_s, 100, 101.5));

  double get _fen1 => _fen1Of(1);

  Offset _fen1CentreOf(int k) =>
      g.centre(_laggingTip(k), leading: false) + const Offset(-33, 24);

  Offset get _fen1Centre => _fen1CentreOf(1);

  /// DNA ligase I at the nick fragment [k] leaves behind.
  _Enzyme _ligaseOf(int k) {
    final (double enter, double entered, double exit, double exited, double nick) =
        k == 0
        ? (54, 55, 56, 57.5, -10.5)
        : (102, 104, 110, 114, 89.5);
    final double entry = _eased(_s, enter, entered);
    final double leave = _eased(_s, exit, exited);
    final Offset site = g.centre(nick, leading: false);
    return _Enzyme(
      site: site,
      centre: site + Offset(35 * (1 - entry + leave), 0),
      opacity: entry * (1 - leave),
    );
  }

  _Enzyme get _ligase => _ligaseOf(1);

  void _machinery() {
    // The origin's A/T-rich unwinding element, until it melts, and ORC with
    // Cdc6 on the duplex beside it. Neither belongs to one fork, so neither
    // is turned about the origin.
    shared
      ..add(
        StagedBand(
          'origin-band',
          Offset(180, g.yOf(_origin)),
          GenomeReplication.unwindingHalf * 2 + 1.5,
          _f.originShown,
        ),
      )
      ..addAll(<StagedRing>[
        if (_f.orc > 0)
          StagedRing(
            'orc',
            RingKind.orc,
            Offset(180 + 40 * (1 - _f.orc), g.yOf(_origin + 34)),
            opacity: _f.orc,
          ),
        if (_f.cdc6 > 0)
          StagedRing(
            'cdc6',
            RingKind.cdc6,
            Offset(180 + 30 * (1 - _f.cdc6), g.yOf(_origin + 34)),
            opacity: _f.cdc6 * _f.orc,
          ),
      ]);

    // Topoisomerase II waits on the duplex ahead of the fork. It captures a
    // crossing duplex in its N-gate, cuts the duplex it holds, passes the
    // captured one through into its C-gate and releases it.
    final Offset topo = _topoCentre;
    if (_f.topoShown > 0) {
      items.add(
        StagedTopo(
          'topoisomerase',
          topo,
          gate: _f.topoGate,
          sites: _f.topoSites,
          opacity: _f.topoShown,
        ),
      );
    }
    final double carried = _f.transportShown;
    if (carried > 0) {
      final double t = _f.transport;
      final double x = t <= 1
          ? -72 + 48 * t
          : t <= 2
          ? -24 + 48 * (t - 1)
          : 24 + 48 * (t - 2);
      items.add(
        StagedDuplexEnd('t-segment', topo + Offset(x, 0), t * math.pi, carried),
      );
    }

    // CMG: the MCM2–7 motor's two tiers encircle the leading template, the
    // N-terminal tier leading. Its six ATPase sites fire in turn as it
    // unwinds, one sweep of the ring every eight nucleotides. The excluded
    // lagging template passes outside the ring.
    final ({Offset centre, double opacity, double open}) cmg = _cmg;
    if (cmg.opacity > 0) {
      rings
        ..add(
          StagedRing(
            'cmg-c',
            RingKind.mcmC,
            cmg.centre + const Offset(0, 6),
            open: cmg.open,
            atp: _f.fork / 8,
            opacity: cmg.opacity,
          ),
        )
        ..add(
          StagedRing(
            'cmg-n',
            RingKind.mcmN,
            cmg.centre - const Offset(0, 6),
            open: cmg.open,
            partners: _f.cmgPartners,
            opacity: cmg.opacity,
          ),
        );
    }
    if (_f.cdt1 > 0) {
      items.add(
        StagedMolecule(
          'cdt1',
          SceneInk.cdt1,
          cmg.centre + const Offset(34, 10),
          const Size(24, 22),
          seed: 17,
          channel: false,
          opacity: _f.cdt1,
        ),
      );
    }
    items.add(
      const StagedTrace(
        'lagging-past-helicase',
        leading: false,
        from: -25,
        to: 0,
      ),
    );

    final _Enzyme epsilon = _epsilon;
    if (epsilon.clamp > 0) {
      rings.add(
        _pcna(
          'pcna-leading',
          _f.leadingTip - 16,
          leading: true,
          opacity: epsilon.clamp,
        ),
      );
    }
    if (epsilon.opacity > 0) {
      items
        ..add(
          StagedMolecule(
            'pol-epsilon',
            SceneInk.polymerase,
            epsilon.centre,
            const Size(77, 77),
            seed: 7,
            angle: -0.18,
            opacity: epsilon.opacity,
          ),
        )
        ..add(
          StagedGlow(
            'pol-epsilon-site',
            epsilon.centre,
            SceneInk.newDna,
            _pulse,
            epsilon.working,
          ),
        );
    }

    const List<int> fragments = <int>[-1, 0, 1];
    final Map<int, _Enzyme> primases = <int, _Enzyme>{
      for (final int k in fragments) k: _primase(k),
    };
    final Map<int, _Enzyme> deltas = <int, _Enzyme>{
      for (final int k in fragments) k: _delta(k),
    };
    final _Enzyme leadingPrimase = _leadingPrimase;
    final List<_Enzyme> busy = <_Enzyme>[
      ...primases.values,
      ...deltas.values,
      leadingPrimase,
      epsilon,
    ];

    // RPA holds bare template: it binds as the fork exposes it and gives way
    // as an enzyme or a new strand reaches it. The leading template is only
    // bare for long before its primer is made.
    for (final bool leading in <bool>[false, true]) {
      final int phase = leading ? 2 : 15;
      final double behind = leading ? 40 : 24;
      for (
        int i = ((_origin - phase) / 26).ceil() * 26 + phase;
        i < _f.fork - behind + 4;
        i += 26
      ) {
        if (i < g.firstVisible - 20) {
          continue;
        }
        final double index = i.toDouble();
        final Offset at =
            g.template(index, leading: leading) +
            Offset(leading ? -5 : 5, 0);
        // The bubble opens template several times faster than the tour's
        // fork does, so its RPA binds over a longer stretch.
        final double reach = 4 + 10 * (1 - _eased(_s, -3, 0));
        double opacity =
            ReplicationGeometry.ease((_f.fork - behind - index) / reach) *
            (1 - g.presence(index, leading: leading));
        for (final _Enzyme enzyme in busy) {
          opacity *= _clear(at, enzyme.centre, enzyme.opacity, reach / 4 * 10);
        }
        if (opacity > 0.002) {
          items.add(
            StagedMolecule(
              leading ? 'rpa-l-$i' : 'rpa-$i',
              SceneInk.rpa,
              at,
              const Size(23, 27) * (0.85 + 0.15 * opacity),
              seed: 61,
              channel: false,
              opacity: opacity,
            ),
          );
        }
      }
    }

    void primase(String key, _Enzyme p) {
      if (p.opacity > 0) {
        items
          ..add(
            StagedMolecule(
              key,
              SceneInk.primase,
              p.centre,
              const Size(65, 64),
              seed: 28,
              opacity: p.opacity,
            ),
          )
          ..add(StagedGlow('$key-site', p.centre, SceneInk.rna, _pulse, p.opacity));
      }
    }

    primase('primase-lead', leadingPrimase);
    for (final int k in fragments) {
      primase('primase-$k', primases[k]!);
    }
    for (final int k in fragments) {
      final _Enzyme d = deltas[k]!;
      _loadClamp(k, d);
      if (d.opacity > 0) {
        items
          ..add(
            StagedMolecule(
              'pol-delta-$k',
              SceneInk.polymerase,
              d.centre,
              const Size(77, 72),
              seed: 42,
              angle: 0.13,
              opacity: d.opacity,
            ),
          )
          ..add(
            StagedGlow(
              'pol-delta-$k-site',
              d.centre,
              SceneInk.newDna,
              _pulse,
              d.working,
            ),
          );
      }
    }
    for (final int k in <int>[0, 1]) {
      final double fen1 = _fen1Of(k);
      if (fen1 > 0) {
        items.add(
          StagedMolecule(
            k == 1 ? 'fen1' : 'fen1-0',
            SceneInk.nuclease,
            _fen1CentreOf(k),
            const Size(40, 39),
            seed: 83,
            channel: false,
            opacity: fen1,
          ),
        );
      }
      final _Enzyme ligase = _ligaseOf(k);
      if (ligase.opacity > 0) {
        items.add(
          StagedMolecule(
            k == 1 ? 'ligase' : 'ligase-0',
            SceneInk.ligase,
            ligase.centre,
            const Size(69, 63),
            seed: 92,
            opacity: ligase.opacity,
          ),
        );
      }
    }
  }

  /// PCNA on the new duplex [index]: it turns once per helical turn as it
  /// slides, so it stops when synthesis stops.
  StagedRing _pcna(
    String key,
    double index, {
    required bool leading,
    double open = 0,
    double turn = 0,
    Offset offset = Offset.zero,
    double opacity = 1,
  }) {
    final Offset at = g.centre(index, leading: leading);
    final Offset along =
        g.centre(index + 1, leading: leading) -
        g.centre(index - 1, leading: leading);
    return StagedRing(
      key,
      RingKind.pcna,
      at + offset,
      rotation: turn - index * math.pi * 2 / 38,
      open: open,
      axis: math.atan2(along.dx, -along.dy),
      opacity: opacity,
    );
  }

  /// RFC brings PCNA, held open, to the primer end Pol α has made, closes it
  /// around the DNA and leaves; the clamp then travels with Pol δ.
  void _loadClamp(int k, _Enzyme delta) {
    final (
      double arrive,
      double arrived,
      double close,
      double closed,
      double leave,
      double left,
    ) = _loading(k);
    final double present = delta.clamp;
    if (present <= 0) {
      return;
    }
    final double arriving = _eased(_s, arrive, arrived);
    final double closing = _eased(_s, close, closed);
    final double leaving = _eased(_s, leave, left);
    // The clamp sits on the new duplex just behind the primer end; loaded
    // with its open interface facing the DNA it arrives beside.
    final double index = _laggingTip(k) + 16;
    final double loadedAt = ReplicationFrame(arrived).tipOf(k) + 16;
    final Offset approach = Offset(26 * (1 - arriving), -12 * (1 - arriving));
    rings.add(
      _pcna(
        'pcna-$k',
        index,
        leading: false,
        open: 1.1 * (1 - closing),
        turn: math.pi + loadedAt * math.pi * 2 / 38,
        offset: approach,
        opacity: present,
      ),
    );
    final double rfc = arriving * (1 - leaving);
    if (rfc > 0) {
      rings.add(
        StagedRing(
          'rfc-$k',
          RingKind.rfc,
          g.centre(index, leading: false) +
              approach +
              Offset(20 * leaving, -14 - 10 * leaving),
          rotation: math.pi,
          open: 1.2,
          opacity: rfc,
        ),
      );
    }
  }

  Offset get _topoCentre => Offset(180, g.yOf(_f.topoIndex));

  /// How clear of an enzyme at [centre] an RPA at [at] is: it gives way
  /// over [reach] scene units as the enzyme comes within 30.
  static double _clear(
    Offset at,
    Offset centre,
    double opacity,
    double reach,
  ) =>
      1 -
      opacity *
          (1 -
              ReplicationGeometry.ease(((at - centre).distance - 30) / reach));

  void _overlays() {
    // Each stroke's flap keeps its identity from the moment Pol δ starts to
    // displace it until FEN1 has taken the cut piece up.
    for (final int fragment in <int>[0, 1]) {
      final PrimerReplacement replacement = fragment == 1
          ? ReplicationFrame.later
          : ReplicationFrame.earlier;
      final double fivePrime = fragment == 1 ? 99.5 : -0.5;
      final double fen1 = _fen1Of(fragment);
      final Offset fen1Centre = _fen1CentreOf(fragment);
      for (int k = 0; k < 3; k++) {
        final ({double length, double taken})? flap = replacement.flap(_s, k);
        if (flap == null) {
          continue;
        }
        final double base = fivePrime - ReplicationFrame.flapCut * (k + 1);
        final Offset at = flap.taken > 0
            ? Offset.lerp(
                g.daughter(base, leading: false),
                fen1Centre,
                0.6 * flap.taken,
              )!
            : g.daughter(
                fivePrime - replacement.replaced(_s),
                leading: false,
              );
        flaps.add(
          StagedFlap(
            fragment == 1 ? 'flap-$k' : 'flap-e-$k',
            at,
            fen1Centre,
            flap.length * (1 - flap.taken),
            fen1 *
                (1 - flap.taken) *
                ReplicationGeometry.ease(flap.length / 1.6),
          ),
        );
      }
    }
    final double nick = _eased(_s, 100, 101) * (1 - _eased(_s, 110, 113));
    if (nick > 0) {
      nicks.add(StagedNick('nick', g.nick, _f.sealing, nick));
    }
  }

  // --- Words ---

  /// Labels drawn at the overview's zoom, fading as the camera leaves it.
  double get _overview =>
      1 - ReplicationGeometry.ease((camera.zoom - 1).abs() / 0.2);

  /// How present [chapter]'s close-up labels are: they arrive as the camera
  /// settles on the chapter and leave as it starts to move on.
  double _chapter(ReplicationChapter chapter) {
    final double t = moment.seconds;
    const List<ReplicationChapter> all = ReplicationChapter.values;
    final bool last = chapter.index + 1 >= all.length;
    final double end = last
        ? double.infinity
        : all[chapter.index + 1].second;
    if (t < chapter.second - 0.4 || t >= end) {
      return 0;
    }
    if (reducedMotion) {
      return t >= chapter.second ? 1 : 0;
    }
    final double arrive = chapter.index == 0
        ? 1
        : _eased(t, chapter.second - 0.4, chapter.second);
    final double leave = last
        ? 0
        : _eased(
            t,
            end - ReplicationCamera.transitionSeconds,
            end - ReplicationCamera.transitionSeconds + 0.5,
          );
    return arrive * (1 - leave);
  }

  void _words() {
    final double overview = _overview;
    // The fork's overview words belong to the tour, not to the origin.
    final double tour = _eased(_s, -1, 0);
    if (overview * tour > 0) {
      _overviewWords(overview * tour);
    }
    // Before the tour a zoom near 1 is only the bubble passing through it.
    final double closeUp = 1 - overview * tour;
    if (closeUp > 0) {
      final ReplicationChapter chapter = moment.chapter;
      _closeUpWords(chapter, closeUp * _chapter(chapter));
      if (chapter.index + 1 < ReplicationChapter.values.length) {
        final ReplicationChapter next =
            ReplicationChapter.values[chapter.index + 1];
        _closeUpWords(next, closeUp * _chapter(next));
      }
    }
  }

  void _text(
    String key,
    String text,
    Offset at,
    SceneInk ink,
    double opacity, {
    double size = 12,
    bool centred = true,
  }) {
    if (!showLabels || opacity <= 0) {
      return;
    }
    labels.add(
      StagedLabel(
        key,
        text,
        at,
        ink,
        size: size,
        centred: centred,
        opacity: opacity,
      ),
    );
  }

  void _callout(
    String key,
    String text,
    Offset at,
    Offset target,
    SceneInk ink,
    double opacity,
  ) {
    if (!showLabels || opacity <= 0) {
      return;
    }
    labels.add(
      StagedLabel(key, text, at, ink, target: target, opacity: opacity),
    );
  }

  void _arrow(String key, Offset from, Offset to, SceneInk ink, double opacity) {
    if (opacity > 0) {
      arrows.add(StagedArrow(key, from, to, ink, opacity));
    }
  }

  void _overviewWords(double o) {
    Offset p(Offset scene) => camera.project(scene);
    final double forkY = g.forkY;
    _arrow(
      'leading-strand',
      const Offset(78, 577),
      const Offset(78, 562),
      SceneInk.newDna,
      o,
    );
    _arrow(
      'lagging-strand',
      const Offset(281, 562),
      const Offset(281, 577),
      SceneInk.newDna,
      o,
    );
    _text(
      'leading-strand',
      'Leading strand',
      const Offset(78, 583),
      SceneInk.ink,
      o,
      size: 12.5,
    );
    _text(
      'lagging-strand',
      'Lagging strand',
      const Offset(281, 583),
      SceneInk.ink,
      o,
      size: 12.5,
    );
    _text('leading-5-3', '5′ → 3′', const Offset(78, 548), SceneInk.quiet, o,
        size: 10);
    _text('lagging-5-3', '5′ → 3′', const Offset(281, 548), SceneInk.quiet, o,
        size: 10);
    _text('parental', 'Parental DNA', const Offset(180, 4), SceneInk.ink, o,
        size: 13);
    _text('parental-5', '5′', const Offset(154, 25), SceneInk.quiet, o, size: 10);
    _text('parental-3', '3′', const Offset(205, 25), SceneInk.quiet, o, size: 10);

    // Physical direction of travel, beside the working tips.
    final Offset lead = g.leadingEnzyme;
    _arrow(
      'leading-tip',
      p(lead + const Offset(-43, 12)),
      p(lead + const Offset(-43, -9)),
      SceneInk.newDna,
      o,
    );
    final int k = _f.activeFragment;
    final _Enzyme delta = _delta(k);
    final Offset lag = g.laggingEnzyme;
    _arrow(
      'lagging-tip',
      p(lag + const Offset(44, -10)),
      p(lag + const Offset(44, 11)),
      SceneInk.newDna,
      o * delta.working,
    );

    _callout(
      'overview-topoisomerase',
      'Topoisomerase II',
      p(Offset(16, forkY - 133)),
      p(_topoCentre + const Offset(-30, -1)),
      SceneInk.topoisomerase,
      o,
    );
    _callout(
      'overview-helicase',
      'CMG helicase',
      p(Offset(230, forkY - 48)),
      p(Offset(193, forkY - 11)),
      SceneInk.helicase,
      o,
    );
    _text(
      'overview-pol-epsilon',
      'Pol ε',
      p(lead + const Offset(-9, -54)),
      SceneInk.ink,
      o,
      size: 13,
    );
    _callout(
      'overview-pcna',
      'PCNA',
      p(lead + const Offset(-80, 29)),
      p(g.centre(_f.leadingTip - 16, leading: true) + const Offset(-14, 0)),
      SceneInk.clamp,
      o,
    );
    final _Enzyme primase = _primase(k);
    _callout(
      'overview-primase',
      'Primase · Pol α',
      p(Offset(156, primase.site.dy + 44)),
      p(primase.site + const Offset(-20, 18)),
      SceneInk.rna,
      o * primase.opacity,
    );
    _text(
      'overview-pol-delta',
      'Pol δ',
      p(Offset(lag.dx - 60, math.min(510, lag.dy - 22))),
      SceneInk.ink,
      o * delta.opacity,
      size: 13,
    );
    final Offset rpa = g.template(41, leading: false);
    _callout(
      'overview-rpa',
      'RPA',
      p(Offset(208, rpa.dy - 21)),
      p(rpa),
      SceneInk.rpa,
      o * (1 - _eased(_s, 7.2, 8)),
    );
    final Offset primer = g.daughter(95, leading: false);
    _callout(
      'overview-primer',
      'RNA primer',
      p(Offset(155, primer.dy - 22)),
      p(primer),
      SceneInk.rna,
      o * _eased(_s, 19.2, 20) * (1 - _eased(_s, 87.2, 88)),
    );
    _text(
      'overview-fen1',
      'FEN1',
      p(g.laggingEnzyme + const Offset(-48, 49)),
      SceneInk.nuclease,
      o * _fen1,
    );
    _callout(
      'overview-ligase',
      'DNA ligase I',
      p(Offset(144, g.nick.dy - 36)),
      p(g.centre(89.5, leading: false) - const Offset(25, 13)),
      SceneInk.ligase,
      o * _ligase.opacity,
    );
    final double joined = o * _eased(_s, 111.5, 112.5);
    _text(
      'overview-joined',
      'Joined DNA',
      p(const Offset(230, 471)),
      SceneInk.newDna,
      joined,
    );
    _text(
      'overview-old-new',
      'One old + one new',
      p(const Offset(180, 519)),
      SceneInk.quiet,
      joined,
      size: 11,
    );
  }

  /// The origin between two forks, each marked with the way it travels.
  void _bubbleWords(String c, double alpha) {
    final Offset origin = camera.project(Offset(180, g.yOf(_origin)));
    // The word sits at the origin, between the sister duplexes, once they
    // are far enough apart to hold it and the primases priming both leading
    // strands there have gone.
    final double room =
        2 *
        (camera.project(g.centre(_origin, leading: false)).dx -
            origin.dx -
            16 * camera.zoom);
    _text(
      '$c:origin',
      'Origin',
      origin + const Offset(0, -7),
      SceneInk.quiet,
      // The whole bubble comes into view quickly as the camera pulls back.
      alpha *
          _inside(origin, 90) *
          ReplicationGeometry.ease((room - 46) / 16) *
          _eased(_s, -23, -21),
    );
    for (final bool upper in <bool>[true, false]) {
      final Offset fork = camera.project(
        Offset(180, g.yOf(upper ? _f.fork : _f.lowerFork)),
      );
      final double sign = upper ? -1 : 1;
      final Offset p = fork + Offset(46, 6 * sign);
      final double shown = alpha * _inside(p, 40);
      _arrow(
        '$c:fork-${upper ? 'up' : 'down'}',
        p,
        p + Offset(0, 26 * sign),
        SceneInk.newDna,
        shown,
      );
      _text(
        '$c:fork-${upper ? 'up' : 'down'}-text',
        'Fork',
        p + Offset(16, upper ? -8 : 10),
        SceneInk.ink,
        shown,
        size: 11,
        centred: false,
      );
    }
  }

  /// A close-up label's line may only land inside the frame; near its edge
  /// the label fades rather than vanishing.
  static double _inside(Offset projected, [double soft = 24]) =>
      ReplicationGeometry.ease(
        math.min(
              math.min(projected.dx - 16, 344 - projected.dx),
              math.min(projected.dy - 45, 565 - projected.dy),
            ) /
            soft,
      );

  /// Two names that share a place take turns: each shows only while its
  /// enzyme is more than half there.
  static double _alone(double opacity) =>
      ReplicationGeometry.ease(opacity * 2 - 1);

  void _closeUpWords(ReplicationChapter chapter, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final String c = chapter.name;
    void label(String text, Offset at, Offset target, SceneInk ink, [double o = 1]) {
      final Offset projected = camera.project(target);
      _callout(
        '$c:$text',
        text,
        at,
        projected,
        ink,
        alpha * o * _inside(projected),
      );
    }

    // [across] puts the arrow beside the working enzyme, on whichever side
    // the template leaves clear.
    void direction(
      Offset site, {
      required bool leading,
      double o = 1,
      double across = 112,
    }) {
      final Offset p = camera.project(site) + Offset(across, 0);
      final double edge = ReplicationGeometry.ease(
        math.min(
              math.min(p.dx - 20, 320 - p.dx),
              math.min(p.dy - 80, 490 - p.dy),
            ) /
            20,
      );
      _arrow(
        '$c:direction',
        p + Offset(0, leading ? 24 : -24),
        p + Offset(0, leading ? -24 : 24),
        SceneInk.newDna,
        alpha * o * edge,
      );
      _text(
        '$c:direction-text',
        '5′ → 3′',
        p + const Offset(0, 34),
        SceneInk.quiet,
        alpha * o * edge,
        size: 11,
      );
    }

    const Offset below = Offset(24, 450);
    const Offset above = Offset(24, 112);
    Offset rung(double index) =>
        (g.template(index, leading: true) +
            g.template(index, leading: false)) /
        2;
    switch (chapter) {
      case ReplicationChapter.origin:
        final double shown = _f.originShown;
        label(
          'A/T-rich origin',
          below,
          Offset(180 - 24, g.yOf(_origin - 6)),
          SceneInk.quiet,
          shown,
        );
        label(
          'A·T pair: 2 H-bonds',
          const Offset(220, 356),
          rung(_origin + 5),
          SceneInk.quiet,
          shown,
        );
        label(
          'G·C pair: 3 H-bonds',
          const Offset(220, 150),
          rung(_origin + 20),
          SceneInk.quiet,
          shown,
        );
      case ReplicationChapter.licensing:
        final Offset orc = Offset(180, g.yOf(_origin + 34));
        final Offset cmg = _cmg.centre;
        label('ORC', const Offset(246, 112), orc + const Offset(22, -3), SceneInk.orc, _f.orc);
        label(
          'Cdc6',
          const Offset(246, 156),
          orc + const Offset(18, 8),
          SceneInk.orc,
          _f.cdc6,
        );
        label(
          'Cdt1',
          const Offset(246, 470),
          cmg + const Offset(34, 10),
          SceneInk.cdt1,
          _f.cdt1,
        );
        // The longest name: it starts further left to clear the duplex.
        label(
          'MCM2–7 double hexamer',
          const Offset(12, 450),
          cmg + const Offset(-18, 0),
          SceneInk.helicase,
          _f.mcmDocked,
        );
      case ReplicationChapter.firing:
        final Offset cmg = _cmg.centre;
        label(
          'Cdc45 · GINS',
          above,
          cmg + const Offset(-40, 2),
          SceneInk.helicase,
          _f.cmgPartners,
        );
        label(
          'CMG helicase',
          below,
          cmg + const Offset(18, 4),
          SceneInk.helicase,
          _f.cmgPartners,
        );
      case ReplicationChapter.bubble:
      case ReplicationChapter.result:
        _bubbleWords(c, alpha);
      case ReplicationChapter.overview:
        break;
      case ReplicationChapter.helicase:
        label(
          'CMG helicase',
          const Offset(220, 452),
          Offset(191, g.forkY + 30),
          SceneInk.helicase,
        );
        // Below topoisomerase II, which waits at the top of this view.
        label(
          'Parental DNA',
          const Offset(238, 124),
          g.template(_f.fork + 30, leading: false),
          SceneInk.quiet,
        );
      case ReplicationChapter.binding:
        label(
          'RPA · human SSB',
          below,
          g.template(67, leading: false) + const Offset(5, 8),
          SceneInk.rpa,
        );
        label(
          'Exposed template',
          above,
          g.template(85, leading: false),
          SceneInk.quiet,
        );
      case ReplicationChapter.topoisomerase:
        // The enzyme is above the overwound stretch it relieves, so each
        // name sits on its own side and neither line crosses the enzyme.
        label(
          'Topoisomerase II',
          above,
          _topoCentre + const Offset(-24, -14),
          SceneInk.topoisomerase,
        );
        label(
          'Overwound DNA',
          below,
          rung(_f.fork + 22),
          SceneInk.quiet,
          _f.overwinding / 0.7,
        );
      case ReplicationChapter.primase:
      case ReplicationChapter.nextPrimer:
      case ReplicationChapter.polymerase:
        final int k = chapter == ReplicationChapter.nextPrimer ? 1 : 0;
        final Offset site = g.centre(_f.tipOf(k), leading: false);
        final _Enzyme delta = _delta(k);
        label(
          'Primase · Pol α',
          below,
          site + const Offset(-20, 16),
          SceneInk.rna,
          _alone(_primase(k).opacity),
        );
        label(
          'Pol δ',
          below,
          site + const Offset(-20, 16),
          SceneInk.ink,
          _alone(delta.opacity),
        );
        label(
          'RNA primer',
          const Offset(218, 112),
          g.daughter(k == 0 ? 95 : 195, leading: false),
          SceneInk.rna,
          _primerShown(k),
        );
        final Offset clamp = g.centre(_laggingTip(k) + 16, leading: false);
        label('PCNA', const Offset(255, 192), clamp, SceneInk.clamp, delta.clamp);
        final double start = ReplicationFrame.primedAt(k);
        label(
          'RFC',
          const Offset(255, 150),
          clamp + const Offset(0, -16),
          SceneInk.rfc,
          _eased(_s, start + 9, start + 10) *
              (1 - _eased(_s, start + 11.2, start + 12)),
        );
        // Near the fork the template runs down to the right of the primer.
        // The direction shows once synthesis is under way.
        direction(site, leading: false, o: _primerMade(k), across: -130);
      case ReplicationChapter.leading:
        label(
          'Pol ε',
          below,
          g.leadingEnzyme + const Offset(-22, 14),
          SceneInk.ink,
        );
        label(
          'PCNA',
          const Offset(236, 430),
          g.centre(_f.leadingTip - 16, leading: true),
          SceneInk.clamp,
        );
        direction(g.leadingEnzyme, leading: true);
      case ReplicationChapter.lagging:
      case ReplicationChapter.fragments:
        final int k = chapter == ReplicationChapter.lagging ? 0 : 1;
        final Offset site = g.centre(_f.tipOf(k), leading: false);
        final _Enzyme delta = _delta(k);
        label(
          'Pol δ',
          below,
          site + const Offset(-20, 14),
          SceneInk.ink,
          delta.opacity,
        );
        // The second fragment starts nearer the fork, where the duplex
        // crosses the top left of the view.
        label(
          'Okazaki fragment',
          k == 0 ? above : const Offset(236, 112),
          g.daughter(_f.tipOf(k) + 38, leading: false),
          SceneInk.newDna,
        );
        direction(site, leading: false, o: delta.working);
      case ReplicationChapter.replacement:
        label(
          'Pol δ',
          above,
          g.laggingEnzyme + const Offset(-20, -12),
          SceneInk.ink,
        );
        label('FEN1', below, _fen1Centre, SceneInk.nuclease, _fen1);
        final Offset front = g.daughter(
          99.5 - _f.replacedBases,
          leading: false,
        );
        // One name gives way to the next in the same place: the first fades
        // out before the second fades in.
        label(
          'RNA flap',
          const Offset(254, 430),
          front,
          SceneInk.rna,
          1 - _eased(_s, 99.4, 99.9),
        );
        label(
          'RNA replaced',
          const Offset(254, 430),
          front,
          SceneInk.rna,
          _eased(_s, 99.9, 100.4),
        );
      case ReplicationChapter.ligase:
        label(
          'DNA ligase I',
          below,
          g.centre(89.5, leading: false) + const Offset(-20, 12),
          SceneInk.ligase,
          _ligase.opacity,
        );
        label('Nick', above, g.nick, SceneInk.quiet, 1 - _eased(_s, 109.5, 110));
        label(
          'Joined backbone',
          above,
          g.nick,
          SceneInk.newDna,
          _eased(_s, 110, 110.5),
        );
    }
  }
}

/// Where an enzyme works ([site]), where it is drawn ([centre], which slides
/// in and out), and how present it, its active site and its clamp are.
@immutable
class _Enzyme {
  const _Enzyme({
    required this.site,
    required this.centre,
    required this.opacity,
    this.working = 0,
    this.clamp = 0,
  });
  final Offset site;
  final Offset centre;
  final double opacity;
  final double working;
  final double clamp;
}
