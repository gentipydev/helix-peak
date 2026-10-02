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
    this.firing = 0,
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

  /// How hard the ATPase sites work, 0 to 1: they rest when the fork stops.
  final double firing;

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
/// when they name something. A [note] under the name says what it is.
@immutable
class StagedLabel {
  const StagedLabel(
    this.key,
    this.text,
    this.at,
    this.ink, {
    this.target,
    this.note,
    this.names,
    this.size = 12,
    this.centred = false,
    this.opacity = 1,
  });
  final String key;
  final String text;
  final Offset at;
  final Offset? target;
  final SceneInk ink;

  /// What the named thing is, in a few words, drawn smaller under the name.
  final String? note;

  /// The colour of what [target] lands on, when it is not [ink]: a
  /// polymerase is named in the text colour but drawn in its own.
  final SceneInk? names;
  final double size;
  final bool centred;
  final double opacity;

  /// The size a note is set in.
  static const double noteSize = 10;

  /// How far a line keeps from the words it leaves.
  static const double margin = 3;

  /// Where the words lie, given the measured sizes of the name and the
  /// note: the note under the name, both aligned as the name is.
  Rect block(Size name, Size? note) {
    final double width = math.max(name.width, note?.width ?? 0);
    final double height = name.height + (note?.height ?? 0);
    return Rect.fromLTWH(
      at.dx - (centred ? width / 2 : 0),
      at.dy,
      width,
      height,
    );
  }

  /// Where a line to [target] leaves the words in [block]: on the side
  /// facing it, a [margin] off, along the way from the words' middle to the
  /// target. It never crosses the words, and it slides round them as the
  /// target moves.
  static Offset exit(Rect block, Offset target) {
    final Rect box = block.inflate(margin);
    final Offset towards = target - box.center;
    final double across = towards.dx.abs() < 1e-9
        ? double.infinity
        : box.width / 2 / towards.dx.abs();
    final double down = towards.dy.abs() < 1e-9
        ? double.infinity
        : box.height / 2 / towards.dy.abs();
    return box.center + towards * math.min(1, math.min(across, down));
  }
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
      // Solid early in its slide in, so it is never long see-through.
      opacity: _eased(_s, -49.5, -49.05),
      open: 1.1 * (1 - _f.mcmClosed),
    );
  }

  /// How hard the CMG's ATPase sites work: with the fork's speed, so they
  /// rest before the origin fires and slow as the fork does.
  double get _firing {
    final double speed =
        (ReplicationFrame(_s + 0.1).fork - ReplicationFrame(_s - 0.1).fork) /
        0.2;
    return ReplicationGeometry.ease(speed / 1.2);
  }

  /// Primase–Pol α on lagging fragment [k] (−1, 0 or 1): it arrives as its
  /// primer starts, and lets the primer end go once its DNA is made, so RFC
  /// can take it.
  _Enzyme _primase(int k) {
    final double start = ReplicationFrame.primedAt(k);
    final double done = ReplicationFrame.primerDoneAt(k);
    final double arrival = _eased(_s, start - 1, start);
    final double departure = _eased(_s, done, done + (k < 0 ? 2 : 0.9));
    // Where Pol α left its primer end: the tip, held once it lets go.
    final Offset site = g.centre(
      ReplicationFrame(math.min(_s, done)).tipOf(k),
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

  /// RFC's visit with PCNA to fragment [k]'s primer end: it arrives as Pol α
  /// lets the end go, closes the clamp round the DNA and leaves as Pol δ
  /// comes. Arrive, close, leave, as model seconds. The bubble's first
  /// fragment is primed and handed over too fast to show RFC at its work:
  /// there the clamp slides in by itself while Pol α works, as the leading
  /// strand's does.
  static (double, double, double, double, double, double) _loading(int k) {
    if (k < 0) {
      final double start = ReplicationFrame.primedAt(k);
      return (
        start + 1.2,
        start + 2.2,
        start + 2.3,
        start + 2.9,
        start + 2.9,
        start + 4.2,
      );
    }
    // RFC comes in as Pol α has all but gone.
    final double done = ReplicationFrame.primerDoneAt(k);
    final double handoff = ReplicationFrame.handoffAt(k);
    return (
      done + 0.7,
      done + 1.7,
      done + 1.9,
      done + 2.6,
      handoff - 0.6,
      handoff + 0.2,
    );
  }

  /// Fragment [k]'s primer end while it changes hands, from Pol α letting it
  /// go until Pol δ has it, so no RPA rebinds the template there meanwhile.
  _Enzyme _primerEnd(int k) {
    final double done = ReplicationFrame.primerDoneAt(k);
    final double handoff = ReplicationFrame.handoffAt(k);
    final Offset site = g.centre(_laggingTip(k), leading: false);
    return _Enzyme(
      site: site,
      centre: site,
      opacity:
          _eased(_s, done - 0.5, done) *
          (1 - _eased(_s, handoff + 1.5, handoff + 2)),
    );
  }

  /// When fragment [k]'s clamp comes off the DNA: PCNA holds FEN1 and DNA
  /// ligase I in turn, and is unloaded only once the nick is sealed.
  static (double, double) _unloading(int k) => switch (k) {
    -1 => (-2, 0),
    0 => (56.5, 58),
    _ => (110.5, 112),
  };

  /// Pol δ on lagging fragment [k], with its clamp, which stays on the DNA
  /// after Pol δ has gone.
  _Enzyme _delta(int k) {
    final double handoff = ReplicationFrame.handoffAt(k);
    final double end = _deltaEnd(k);
    final double arrival = _eased(_s, handoff, handoff + 2);
    final double departure = _eased(_s, end, end + 2);
    final Offset site = g.centre(_laggingTip(k), leading: false);
    final (double arrive, double arrived, _, _, _, _) = _loading(k);
    final (double unload, double unloaded) = _unloading(k);
    return _Enzyme(
      site: site,
      centre: site + Offset(-25 * (1 - arrival + departure), 0),
      opacity: arrival * (1 - departure),
      working: arrival * (1 - _eased(_s, end - 0.6, end)),
      clamp: _eased(_s, arrive, arrived) * (1 - _eased(_s, unload, unloaded)),
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
      // Each ring is solid soon after it starts to slide in, and goes only
      // at the end of its slide out, so it is never long see-through.
      ..addAll(<StagedRing>[
        if (_f.orc > 0)
          StagedRing(
            'orc',
            RingKind.orc,
            Offset(180 + 40 * (1 - _f.orc), g.yOf(_origin + 34)),
            opacity:
                _eased(_s, -51.5, -51.05) * (1 - _eased(_s, -40.95, -40.5)),
          ),
        if (_f.cdc6 > 0)
          StagedRing(
            'cdc6',
            RingKind.cdc6,
            Offset(180 + 30 * (1 - _f.cdc6), g.yOf(_origin + 34)),
            opacity: _eased(_s, -50, -49.55) * (1 - _eased(_s, -40.95, -40.5)),
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
    // unwinds, two nucleotides a subunit, so one sweep of the ring every
    // twelve. The excluded lagging template passes outside the ring.
    final ({Offset centre, double opacity, double open}) cmg = _cmg;
    if (cmg.opacity > 0) {
      rings
        ..add(
          StagedRing(
            'cmg-c',
            RingKind.mcmC,
            cmg.centre + const Offset(0, 6),
            open: cmg.open,
            atp: _f.fork / 12,
            firing: _firing,
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
          opacity: _eased(_s, -25, -24.1),
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
      // The bubble's first fragment changes hands without a pause.
      for (final int k in <int>[0, 1]) _primerEnd(k),
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
      for (final StagedRing? ring in <StagedRing?>[_clampOf(k), _loaderOf(k)]) {
        if (ring != null) rings.add(ring);
      }
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
    return StagedRing(
      key,
      RingKind.pcna,
      g.centre(index, leading: leading) + offset,
      rotation: turn - index * math.pi * 2 / 38,
      open: open,
      axis: _axis(index, leading: leading),
      opacity: opacity,
    );
  }

  /// The DNA's direction through a ring at [index], radians from vertical.
  double _axis(double index, {required bool leading}) {
    final Offset along =
        g.centre(index + 1, leading: leading) -
        g.centre(index - 1, leading: leading);
    return math.atan2(along.dx, -along.dy);
  }

  /// RFC brings PCNA, held open, to the primer end Pol α has made on
  /// fragment [k], closes it around the DNA and leaves; the clamp then
  /// travels with Pol δ, and stays on the DNA until the nick Pol δ leaves is
  /// sealed. This is the clamp, or null while it is not there.
  StagedRing? _clampOf(int k) {
    final (
      double arrive,
      double arrived,
      double close,
      double closed,
      double _,
      double _,
    ) = _loading(k);
    if (_delta(k).clamp <= 0) {
      return null;
    }
    // The clamp sits on the new duplex just behind the primer end; loaded
    // with its open interface facing the DNA it arrives beside.
    final double loadedAt = ReplicationFrame(arrived).tipOf(k) + 16;
    // Both rings are solid soon after they start to slide in and go only at
    // the end of their slide out, so neither is long see-through. The fast
    // bubble act gives a fade more model time for the same time on screen.
    final double fade = k < 0 ? 0.9 : 0.45;
    final double gone = _unloading(k).$2;
    return _pcna(
      'pcna-$k',
      _laggingTip(k) + 16,
      leading: false,
      open: 1.1 * (1 - _eased(_s, close, closed)),
      turn: math.pi + loadedAt * math.pi * 2 / 38,
      offset: _approach(k),
      opacity:
          _eased(_s, arrive, arrive + fade) *
          (1 - _eased(_s, gone - fade, gone)),
    );
  }

  /// RFC on fragment [k]'s clamp while it loads it, or null. It holds the
  /// primer end, on the clamp's front face, the face Pol δ binds next: on
  /// the lagging strand, below the clamp.
  StagedRing? _loaderOf(int k) {
    final (
      double arrive,
      double arrived,
      double _,
      double _,
      double leave,
      double left,
    ) = _loading(k);
    final double leaving = _eased(_s, leave, left);
    if (k < 0 ||
        _delta(k).clamp <= 0 ||
        _eased(_s, arrive, arrived) * (1 - leaving) <= 0) {
      return null;
    }
    const double fade = 0.45;
    final double index = _laggingTip(k) + 5;
    return StagedRing(
      'rfc-$k',
      RingKind.rfc,
      g.centre(index, leading: false) +
          _approach(k) +
          Offset(20 * leaving, 10 * leaving),
      rotation: math.pi,
      open: 1.2,
      axis: _axis(index, leading: false),
      opacity:
          _eased(_s, arrive, arrive + fade) *
          (1 - _eased(_s, left - fade, left)),
    );
  }

  /// How near RFC is to fragment [k]'s primer end, 0 to 1: from a moment
  /// before it slides in until a moment after it has gone.
  double _loaderNear(int k) {
    final (double arrive, _, _, _, _, double left) = _loading(k);
    return _eased(_s, arrive - 0.6, arrive) * (1 - _eased(_s, left, left + 0.6));
  }

  /// How far RFC still has to bring fragment [k]'s clamp in.
  Offset _approach(int k) {
    final (double arrive, double arrived, _, _, _, _) = _loading(k);
    final double arriving = _eased(_s, arrive, arrived);
    return Offset(26 * (1 - arriving), -12 * (1 - arriving));
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
    // Close-up words wait until the whole fork's have mostly gone, so the
    // two sets never lie over each other at half strength.
    final double closeUp = ReplicationGeometry.ease(
      (0.5 - overview * tour) / 0.5,
    );
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
    double opacity, {
    String? note,
    SceneInk? names,
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
        target: target,
        note: note,
        names: names,
        opacity: opacity,
      ),
    );
  }

  // --- Where a label's line lands: on the thing itself, wherever it is. ---

  /// A point on [enzyme]'s body, [into] from its middle: it rides with the
  /// enzyme as it slides in and out.
  static Offset _body(_Enzyme enzyme, Offset into) => enzyme.centre + into;

  /// The front of the CMG's N-terminal tier, on top of the ring: never lit
  /// by the ATP wave, which runs round the C-terminal tier below it.
  Offset get _cmgFace => _cmg.centre + const Offset(0, -2.6);

  /// GINS and Cdc45, on the CMG's side.
  Offset get _gins => _cmg.centre + const Offset(-40, -12);
  Offset get _cdc45 => _cmg.centre + const Offset(-39, 16);

  /// The front of a ring's top face, [angle] round from its right, turned
  /// with the ring about the DNA's axis.
  static Offset _ringFace(
    StagedRing ring, {
    required double radius,
    required double height,
    double tilt = 0.42,
    double angle = math.pi / 2,
  }) {
    final Offset local = Offset(
      math.cos(angle) * radius,
      math.sin(angle) * radius * tilt - height / 2,
    );
    final double c = math.cos(ring.axis);
    final double s = math.sin(ring.axis);
    return ring.centre +
        Offset(local.dx * c - local.dy * s, local.dx * s + local.dy * c);
  }

  /// The drawn base of fragment [k]'s RNA primer nearest its 5′ end.
  double _primerBase(int k) => ReplicationFrame.fivePrimeOf(k) - 4.5;

  /// On that base, beside the primer's backbone.
  Offset _primerSpot(int k) {
    final double index = _primerBase(k);
    final Offset backbone = g.daughter(index, leading: false);
    return Offset.lerp(
      backbone,
      g.template(index, leading: false),
      0.2,
    )!;
  }

  /// How far fragment [k]'s primer has come out of primase, 0 to 1. Primase
  /// makes it inside itself; Pol α's DNA then carries it out, and its 5′
  /// base is in sight once about 13 nucleotides are made.
  double _primerOut(int k) => ReplicationGeometry.ease(
    (ReplicationFrame.fivePrimeOf(k) - _f.tipOf(k) - 13) / 2,
  );

  /// Fragment [k]'s DNA, halfway between its clamp and its RNA primer.
  Offset _fragmentSpot(int k) {
    final double top =
        ReplicationFrame.fivePrimeOf(k) - GenomeReplication.rnaBases - 2;
    final double bottom = math.min(_f.tipOf(k) + 24, top);
    return g.daughter((bottom + top) / 2, leading: false);
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
    // The parental strands' ends, either side of their name: topoisomerase
    // II covers the ends themselves.
    _text('parental-5', '5′', const Offset(126, 7), SceneInk.quiet, o, size: 10);
    _text('parental-3', '3′', const Offset(234, 7), SceneInk.quiet, o, size: 10);

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

    // Every enzyme is named by a line to its own body, so a name is never
    // read as the next protein's.
    _callout(
      'overview-topoisomerase',
      'Topoisomerase II',
      p(Offset(230, forkY - 140)),
      p(_topoCentre + const Offset(24, -15)),
      SceneInk.topoisomerase,
      o,
    );
    _callout(
      'overview-helicase',
      'CMG helicase',
      p(Offset(230, forkY - 48)),
      p(_cmgFace),
      SceneInk.helicase,
      o,
    );
    final _Enzyme epsilon = _epsilon;
    _callout(
      'overview-pol-epsilon',
      'Pol ε',
      p(lead + const Offset(-86, -72)),
      p(_body(epsilon, const Offset(-22, 6))),
      SceneInk.ink,
      o * epsilon.opacity,
      names: SceneInk.polymerase,
    );
    _callout(
      'overview-pcna',
      'PCNA',
      p(lead + const Offset(-80, 29)),
      p(
        _ringFace(
          _pcna('pcna-leading', _f.leadingTip - 16, leading: true),
          radius: 20,
          height: 10,
          angle: math.pi * 0.8,
        ),
      ),
      SceneInk.clamp,
      o,
    );
    final _Enzyme primase = _primase(k);
    _callout(
      'overview-primase',
      'Primase · Pol α',
      p(Offset(156, primase.site.dy + 44)),
      p(_body(primase, const Offset(17, 16))),
      SceneInk.primase,
      o * primase.opacity,
    );
    _callout(
      'overview-pol-delta',
      'Pol δ',
      p(Offset(lag.dx - 75, math.min(510, lag.dy - 22))),
      p(_body(delta, const Offset(-22, 6))),
      SceneInk.ink,
      o * delta.opacity,
      names: SceneInk.polymerase,
    );
    final Offset rpa = g.template(41, leading: false);
    _callout(
      'overview-rpa',
      'RPA',
      p(Offset(208, rpa.dy - 21)),
      p(rpa + const Offset(5, 0)),
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
    _callout(
      'overview-fen1',
      'FEN1',
      p(g.laggingEnzyme + const Offset(-62, 49)),
      p(_fen1Centre),
      SceneInk.nuclease,
      o * _fen1,
    );
    final _Enzyme ligase = _ligase;
    _callout(
      'overview-ligase',
      'DNA ligase I',
      p(Offset(144, g.nick.dy - 36)),
      p(_body(ligase, const Offset(-20, 6))),
      SceneInk.ligase,
      o * ligase.opacity,
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
      // Each fork's arrow is on the side its CMG leaves clear: the lower
      // fork is the upper one turned, so its arrow is on the left.
      final double sign = upper ? -1 : 1;
      final Offset p = fork + Offset(46 * -sign, 6 * sign);
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
        p + Offset(upper ? 16 : -30, upper ? -8 : 10),
        SceneInk.ink,
        shown,
        size: 11,
        centred: !upper,
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

  // What a machine is, said the same way in every chapter that names it.
  static const String _cmgIs = 'unwinds the DNA';
  static const String _pcnaIs = 'sliding clamp';
  static const String _deltaIs = 'lagging-strand polymerase';
  static const String _primaseIs = 'makes the RNA–DNA primer';
  static const String _primerIs = '${GenomeReplication.rnaBases} nt';

  void _closeUpWords(ReplicationChapter chapter, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final String c = chapter.name;
    void label(
      String text,
      Offset at,
      Offset target,
      SceneInk ink, [
      double o = 1,
      String? note,
      SceneInk? names,
    ]) {
      final Offset projected = camera.project(target);
      _callout(
        '$c:$text',
        text,
        at,
        projected,
        ink,
        alpha * o * _inside(projected),
        note: note,
        names: names,
      );
    }

    // [across] and [down] put the arrow beside the working enzyme, where the
    // template and the other proteins leave room.
    void direction(
      Offset site, {
      required bool leading,
      double o = 1,
      double across = 112,
      double down = 0,
    }) {
      final Offset p = camera.project(site) + Offset(across, down);
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
    // A base pair, pointed at on one of its bases, so the dot never covers
    // the bonds between them.
    Offset pair(double index) {
      final Offset base = g.template(index, leading: false);
      final Offset middle =
          (g.template(index, leading: true) + base) / 2;
      return Offset.lerp(middle, base, 0.6)!;
    }
    switch (chapter) {
      case ReplicationChapter.origin:
        final double shown = _f.originShown;
        label(
          'A/T-rich origin',
          below,
          g.template(_origin + 6, leading: true),
          SceneInk.quiet,
          shown,
          '${GenomeReplication.unwindingHalf * 2 + 1}-bp unwinding element',
          SceneInk.parental,
        );
        label(
          'A·T pair: 2 H-bonds',
          const Offset(220, 356),
          pair(_origin + 5),
          SceneInk.quiet,
          shown,
          null,
          SceneInk.parental,
        );
        label(
          'G·C pair: 3 H-bonds',
          const Offset(220, 150),
          pair(_origin + 20),
          SceneInk.quiet,
          shown,
          null,
          SceneInk.parental,
        );
      case ReplicationChapter.licensing:
        // ORC and Cdc6 are named where they are, as they slide in.
        final Offset orc = Offset(
          180 + 40 * (1 - _f.orc),
          g.yOf(_origin + 34),
        );
        final Offset cdc6 = Offset(
          180 + 30 * (1 - _f.cdc6),
          g.yOf(_origin + 34),
        );
        final Offset cmg = _cmg.centre;
        label(
          'ORC',
          const Offset(222, 100),
          orc + const Offset(22, -3),
          SceneInk.orc,
          _f.orc,
          'origin recognition complex',
        );
        // Right of ORC's line, and named once the MCM ring sliding in past
        // it has arrived.
        label(
          'Cdc6',
          const Offset(264, 196),
          cdc6 + const Offset(18, 8),
          SceneInk.cdc6,
          _f.cdc6 * ReplicationGeometry.ease((_f.mcmArrive - 0.6) / 0.4),
          'MCM loader',
        );
        label(
          'Cdt1',
          const Offset(246, 470),
          cmg + const Offset(34, 10),
          SceneInk.cdt1,
          _f.cdt1,
          'MCM chaperone',
        );
        // The longest name: it starts further left to clear the duplex.
        label(
          'MCM2–7 double hexamer',
          const Offset(12, 450),
          cmg + const Offset(-18, 0),
          SceneInk.helicase,
          _f.mcmDocked,
          'inactive helicase',
        );
      case ReplicationChapter.firing:
        // GINS sits above Cdc45: each is named from its own side, so neither
        // line crosses the other protein.
        label(
          'GINS',
          above,
          _gins,
          SceneInk.helicase,
          _f.cmgPartners,
          'the G in CMG',
        );
        label(
          'Cdc45',
          below,
          _cdc45,
          SceneInk.helicase,
          _f.cmgPartners,
          'the C in CMG',
        );
        label(
          'CMG helicase',
          const Offset(226, 452),
          _cmgFace,
          SceneInk.helicase,
          _f.cmgPartners,
          _cmgIs,
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
          _cmgFace,
          SceneInk.helicase,
          1,
          _cmgIs,
        );
        // Below topoisomerase II, which waits at the top of this view.
        label(
          'Parental DNA',
          const Offset(238, 124),
          g.template(_f.fork + 30, leading: false),
          SceneInk.quiet,
          1,
          null,
          SceneInk.parental,
        );
      case ReplicationChapter.binding:
        label(
          'RPA',
          below,
          g.template(67, leading: false) + const Offset(5, 8),
          SceneInk.rpa,
          1,
          'ssDNA-binding protein',
        );
        label(
          'Exposed template',
          above,
          g.template(85, leading: false),
          SceneInk.quiet,
          1,
          null,
          SceneInk.parental,
        );
      case ReplicationChapter.topoisomerase:
        // The enzyme is above the overwound stretch it relieves, so each
        // name sits on its own side and neither line crosses the enzyme.
        label(
          'Topoisomerase II',
          above,
          _topoCentre + const Offset(-24, -14),
          SceneInk.topoisomerase,
          1,
          'relaxes overwound DNA',
        );
        label(
          'Overwound DNA',
          below,
          g.template(_f.fork + 22, leading: false),
          SceneInk.quiet,
          _f.overwinding / 0.7,
          'positive supercoils',
          SceneInk.parental,
        );
        // The duplex passed through the cut, named along its way.
        final double t = _f.transport;
        final double x = t <= 1
            ? -72 + 48 * t
            : t <= 2
            ? -24 + 48 * (t - 1)
            : 24 + 48 * (t - 2);
        // Named from the side it comes in from, until it leaves the C-gate.
        label(
          'T-segment',
          const Offset(24, 386),
          _topoCentre + Offset(x, -11),
          SceneInk.quiet,
          _f.transportShown * (1 - ReplicationGeometry.ease((t - 2) / 0.3)),
          'duplex passed through',
          SceneInk.parental,
        );
      case ReplicationChapter.primase:
      case ReplicationChapter.nextPrimer:
      case ReplicationChapter.polymerase:
        final int k = chapter == ReplicationChapter.nextPrimer ? 1 : 0;
        final _Enzyme primase = _primase(k);
        final _Enzyme delta = _delta(k);
        // Low on its right lobe: near the fork the CMG covers its left one,
        // and the template crosses the top of its right. The name leaves as
        // Pol α lets the primer end go.
        final double done = ReplicationFrame.primerDoneAt(k);
        label(
          'Primase · Pol α',
          below,
          _body(primase, const Offset(17, 16)),
          SceneInk.primase,
          _alone(primase.opacity) * (1 - _eased(_s, done - 0.4, done)),
          _primaseIs,
        );
        label(
          'Pol δ',
          below,
          _body(delta, const Offset(-22, 6)),
          SceneInk.ink,
          _alone(delta.opacity),
          _deltaIs,
          SceneInk.polymerase,
        );
        // RFC covers the primer while it brings the clamp: the name gives way
        // before it arrives and comes back once it has gone.
        final StagedRing? loader = _loaderOf(k);
        label(
          'RNA primer',
          const Offset(218, 112),
          _primerSpot(k),
          SceneInk.rna,
          _primerShown(k) * _primerOut(k) * (1 - _loaderNear(k)),
          _primerIs,
        );
        final (
          double _,
          double arrived,
          double _,
          double _,
          double leave,
          double _,
        ) = _loading(k);
        // Named where they land, once they have: the rings slide in under
        // these words. RFC is below the clamp, on the face Pol δ binds next.
        final double landed = _eased(_s, arrived - 0.25, arrived + 0.2);
        final StagedRing? clamp = _clampOf(k);
        if (clamp != null) {
          label(
            'PCNA',
            const Offset(255, 192),
            _ringFace(clamp, radius: 20, height: 10),
            SceneInk.clamp,
            delta.clamp * landed,
            _pcnaIs,
          );
        }
        if (loader != null) {
          label(
            'RFC',
            const Offset(255, 262),
            _ringFace(loader, radius: 13, height: 8),
            SceneInk.rfc,
            landed * (1 - _eased(_s, leave - 0.4, leave + 0.4)),
            'clamp loader',
          );
        }
        // Near the fork the template runs down to the right of the primer.
        // The direction shows once synthesis is under way.
        // Near the fork the CMG is beside the second primer, and the
        // template and RPA run down its other side: the arrow goes below.
        direction(
          g.centre(_f.tipOf(k), leading: false),
          leading: false,
          o: _primerMade(k),
          across: k == 0 ? -130 : -100,
          down: k == 0 ? 0 : 70,
        );
      case ReplicationChapter.leading:
        final _Enzyme epsilon = _epsilon;
        label(
          'Pol ε',
          above,
          _body(epsilon, const Offset(-22, 6)),
          SceneInk.ink,
          1,
          'leading-strand polymerase',
          SceneInk.polymerase,
        );
        label(
          'PCNA',
          const Offset(236, 430),
          _ringFace(
            _pcna('pcna-leading', _f.leadingTip - 16, leading: true),
            radius: 20,
            height: 10,
          ),
          SceneInk.clamp,
          1,
          _pcnaIs,
        );
        direction(g.leadingEnzyme, leading: true);
      case ReplicationChapter.lagging:
      case ReplicationChapter.fragments:
        final int k = chapter == ReplicationChapter.lagging ? 0 : 1;
        final _Enzyme delta = _delta(k);
        label(
          'Pol δ',
          below,
          _body(delta, const Offset(-22, 6)),
          SceneInk.ink,
          delta.opacity,
          _deltaIs,
          SceneInk.polymerase,
        );
        // The second fragment starts nearer the fork, where the duplex
        // crosses the top left of the view.
        label(
          'Okazaki fragment',
          k == 0 ? above : const Offset(236, 112),
          _fragmentSpot(k),
          SceneInk.newDna,
          1 - _loaderNear(k),
          '${GenomeReplication.fragmentBases} nt',
        );
        final StagedRing? clamp = _clampOf(k);
        if (clamp != null) {
          label(
            'PCNA',
            const Offset(250, 200),
            _ringFace(clamp, radius: 20, height: 10),
            SceneInk.clamp,
            delta.clamp,
            _pcnaIs,
          );
        }
        if (k == 0) {
          label(
            'RNA primer',
            const Offset(236, 112),
            _primerSpot(0),
            SceneInk.rna,
            _primerShown(0) * _primerOut(0),
            _primerIs,
          );
        }
        direction(
          g.centre(_f.tipOf(k), leading: false),
          leading: false,
          o: delta.working,
        );
      case ReplicationChapter.replacement:
        final _Enzyme delta = _delta(1);
        label(
          'Pol δ',
          above,
          _body(delta, const Offset(-22, 6)),
          SceneInk.ink,
          1,
          _deltaIs,
          SceneInk.polymerase,
        );
        label(
          'FEN1',
          below,
          _fen1Centre,
          SceneInk.nuclease,
          _fen1,
          'flap endonuclease',
        );
        final StagedRing? clamp = _clampOf(1);
        if (clamp != null) {
          label(
            'PCNA',
            const Offset(292, 112),
            _ringFace(clamp, radius: 20, height: 10),
            SceneInk.clamp,
            delta.clamp,
            _pcnaIs,
          );
        }
        final double front = 99.5 - _f.replacedBases;
        // One name gives way to the next in the same place: the first fades
        // out before the second fades in.
        label(
          'RNA flap',
          const Offset(254, 430),
          g.daughter(front - 1.5, leading: false),
          SceneInk.rna,
          1 - _eased(_s, 99.4, 99.9),
        );
        label(
          'RNA replaced',
          const Offset(254, 430),
          g.daughter(front, leading: false),
          SceneInk.rna,
          _eased(_s, 99.9, 100.4),
          null,
          SceneInk.newDna,
        );
      case ReplicationChapter.ligase:
        final _Enzyme ligase = _ligase;
        label(
          'DNA ligase I',
          below,
          _body(ligase, const Offset(-20, 6)),
          SceneInk.ligase,
          ligase.opacity,
          'seals the nick',
        );
        // PCNA stays above the ligase until the nick is sealed, so the nick
        // is named from below, on the right, where only the ligase lies
        // between the words and it.
        const Offset right = Offset(254, 430);
        label(
          'Nick',
          right,
          g.nick,
          SceneInk.quiet,
          1 - _eased(_s, 109.5, 110),
          'unsealed backbone',
          SceneInk.newDna,
        );
        label(
          'Joined backbone',
          right,
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
