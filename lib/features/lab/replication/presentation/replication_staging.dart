import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../domain/genome_replication.dart';
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

/// PCNA, the sliding clamp, around the new duplex.
final class StagedClamp extends StagedItem {
  const StagedClamp(super.key, super.centre, super.opacity);
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

  /// Primase–Pol α on lagging fragment [k]: it arrives as its primer starts,
  /// and leaves once Pol δ has taken the primer end.
  _Enzyme _primase(int k) {
    final double start = ReplicationFrame.primedAt(k);
    final double arrival = _eased(_s, start - 1, start);
    final double departure = _eased(_s, start + 12, start + 14);
    // Where Pol α left its primer end: the tip, held once Pol δ takes over.
    final Offset site = g.centre(
      ReplicationFrame(math.min(_s, start + 12)).tipOf(k),
      leading: false,
    );
    return _Enzyme(
      site: site,
      centre:
          site + Offset(24 * (1 - arrival + departure), -13 * (1 - arrival)),
      opacity: arrival * (1 - departure),
    );
  }

  /// Where lagging fragment [k] is growing: its 3′ end, or during primer
  /// replacement the displacement front.
  double _laggingTip(int k) =>
      k == 1 && _s >= ReplicationFrame.replaceStart
      ? 99.5 - _f.replacedBases
      : _f.tipOf(k);

  static double _deltaEnd(int k) => k == 0 ? 46 : 100;

  /// Pol δ on lagging fragment [k], with its clamp.
  _Enzyme _delta(int k) {
    final double handoff = ReplicationFrame.primedAt(k) + 12;
    final double end = _deltaEnd(k);
    final double arrival = _eased(_s, handoff, handoff + 2);
    final double departure = _eased(_s, end, end + 2);
    final Offset site = g.centre(_laggingTip(k), leading: false);
    return _Enzyme(
      site: site,
      centre: site + Offset(-25 * (1 - arrival + departure), 0),
      opacity: arrival * (1 - departure),
      working: arrival * (1 - _eased(_s, end - 0.6, end)),
      // RFC loads PCNA at the primer end as Pol α finishes.
      clamp:
          _eased(_s, ReplicationFrame.primedAt(k) + 10, handoff - 0.5) *
          (1 - departure),
    );
  }

  /// How clearly fragment [k]'s RNA primer is there to be named: once a
  /// few nucleotides are made, and until Pol δ has replaced it.
  double _primerShown(int k) {
    final double fivePrime = (k + 1) * 100 - 0.5;
    final double made =
        fivePrime - math.max(_f.tipOf(k), fivePrime - 10);
    final double replaced = k == 0 ? _eased(_s, 88.5, 94) : 0;
    return ReplicationGeometry.ease((made - 2) / 5) * (1 - replaced);
  }

  double get _fen1 =>
      _eased(_s, 87, 88.5) * (1 - _eased(_s, 100, 101.5));

  _Enzyme get _ligase {
    final double entry = _eased(_s, 102, 104);
    final double exit = _eased(_s, 110, 114);
    final Offset site = g.centre(89.5, leading: false);
    return _Enzyme(
      site: site,
      centre: site + Offset(35 * (1 - entry + exit), 0),
      opacity: entry * (1 - exit),
    );
  }

  void _machinery() {
    final double forkY = g.forkY;
    // Topoisomerase lies on duplex DNA ahead of the fork.
    items.add(
      StagedMolecule(
        'topoisomerase',
        SceneInk.topoisomerase,
        Offset(180, forkY - 108),
        const Size(51, 46),
        seed: 18,
      ),
    );
    // The pore follows the leading template. The excluded lagging template
    // passes outside the helicase's right edge, not through the ring.
    items.add(
      StagedMolecule(
        'helicase',
        SceneInk.helicase,
        Offset(164, forkY + 9),
        const Size(79, 81),
        seed: 37,
      ),
    );
    items
      ..add(
        const StagedTrace(
          'leading-through-helicase',
          leading: true,
          from: -17,
          to: 15,
        ),
      )
      ..add(
        const StagedTrace(
          'lagging-past-helicase',
          leading: false,
          from: -25,
          to: 0,
        ),
      );

    final Offset leading = g.leadingEnzyme;
    items
      ..add(StagedClamp('pcna-leading', leading + const Offset(0, 25), 1))
      ..add(
        StagedMolecule(
          'pol-epsilon',
          SceneInk.polymerase,
          leading,
          const Size(77, 77),
          seed: 7,
          angle: -0.18,
        ),
      )
      ..add(StagedGlow('pol-epsilon-site', leading, SceneInk.newDna, _pulse, 1));

    final List<_Enzyme> primases = <_Enzyme>[_primase(0), _primase(1)];
    final List<_Enzyme> deltas = <_Enzyme>[_delta(0), _delta(1)];

    // RPA holds bare lagging template: it binds as the fork exposes it and
    // gives way as an enzyme or a new strand reaches it.
    for (int i = 15; i < _f.fork - 20; i += 26) {
      if (i < g.firstVisible - 20) {
        continue;
      }
      final double index = i.toDouble();
      final Offset at =
          g.template(index, leading: false) + const Offset(5, 0);
      double opacity =
          ReplicationGeometry.ease((_f.fork - 24 - index) / 4) *
          (1 - g.presence(index, leading: false));
      for (final _Enzyme enzyme in <_Enzyme>[...primases, ...deltas]) {
        opacity *= _clear(at, enzyme.centre, enzyme.opacity);
      }
      if (opacity > 0.002) {
        items.add(
          StagedMolecule(
            'rpa-$i',
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

    for (int k = 0; k < 2; k++) {
      final _Enzyme p = primases[k];
      if (p.opacity > 0) {
        items
          ..add(
            StagedMolecule(
              'primase-$k',
              SceneInk.primase,
              p.centre,
              const Size(65, 64),
              seed: 28,
              opacity: p.opacity,
            ),
          )
          ..add(
            StagedGlow('primase-$k-site', p.centre, SceneInk.rna, _pulse, p.opacity),
          );
      }
    }
    for (int k = 0; k < 2; k++) {
      final _Enzyme d = deltas[k];
      if (d.clamp > 0) {
        items.add(
          StagedClamp('pcna-$k', d.site + const Offset(0, -24), d.clamp),
        );
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
    if (_fen1 > 0) {
      items.add(
        StagedMolecule(
          'fen1',
          SceneInk.nuclease,
          _fen1Centre,
          const Size(40, 39),
          seed: 83,
          channel: false,
          opacity: _fen1,
        ),
      );
    }
    final _Enzyme ligase = _ligase;
    if (ligase.opacity > 0) {
      items.add(
        StagedMolecule(
          'ligase',
          SceneInk.ligase,
          ligase.centre,
          const Size(69, 63),
          seed: 92,
          opacity: ligase.opacity,
        ),
      );
    }
  }

  Offset get _fen1Centre =>
      g.centre(_laggingTip(1), leading: false) + const Offset(-33, 24);

  /// How clear of an enzyme at [centre] an RPA at [at] is.
  static double _clear(Offset at, Offset centre, double opacity) =>
      1 -
      opacity *
          (1 - ReplicationGeometry.ease(((at - centre).distance - 30) / 10));

  void _overlays() {
    // Each stroke's flap keeps its identity from the moment Pol δ starts to
    // displace it until FEN1 has taken the cut piece up.
    for (int k = 0; k < 3; k++) {
      final ({double length, double taken})? flap = _f.flapOf(k);
      if (flap == null) {
        continue;
      }
      final double base = 99.5 - ReplicationFrame.flapCut * (k + 1);
      final Offset at = flap.taken > 0
          ? Offset.lerp(
              g.daughter(base, leading: false),
              _fen1Centre,
              0.6 * flap.taken,
            )!
          : g.daughter(99.5 - _f.replacedBases, leading: false);
      final double length = flap.length * (1 - flap.taken);
      flaps.add(
        StagedFlap(
          'flap-$k',
          at,
          _fen1Centre,
          length,
          _fen1 *
              (1 - flap.taken) *
              ReplicationGeometry.ease(flap.length / 0.6),
        ),
      );
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
    if (overview > 0) {
      _overviewWords(overview);
    }
    final double closeUp = 1 - overview;
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
      'Topoisomerase',
      p(Offset(16, forkY - 133)),
      p(Offset(153, forkY - 109)),
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
      p(lead + const Offset(-14, 26)),
      SceneInk.quiet,
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

  /// A close-up label's line may only land inside the frame; near its edge
  /// the label fades rather than vanishing.
  static double _inside(Offset projected) => ReplicationGeometry.ease(
    math.min(
          math.min(projected.dx - 16, 344 - projected.dx),
          math.min(projected.dy - 45, 565 - projected.dy),
        ) /
        24,
  );

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

    void direction(Offset site, {required bool leading, double o = 1}) {
      final Offset p = camera.project(site) + const Offset(112, 0);
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
    switch (chapter) {
      case ReplicationChapter.overview:
      case ReplicationChapter.result:
        break;
      case ReplicationChapter.helicase:
        label(
          'CMG helicase',
          const Offset(220, 452),
          Offset(191, g.forkY + 30),
          SceneInk.helicase,
        );
        label(
          'Parental DNA',
          const Offset(225, 80),
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
        label(
          'Topoisomerase',
          below,
          Offset(162, g.forkY - 96),
          SceneInk.topoisomerase,
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
          _primase(k).opacity,
        );
        label(
          'Pol δ',
          below,
          site + const Offset(-20, 16),
          SceneInk.ink,
          delta.opacity,
        );
        label(
          'RNA primer',
          const Offset(218, 112),
          g.daughter(k == 0 ? 95 : 195, leading: false),
          SceneInk.rna,
          _primerShown(k),
        );
        label(
          'PCNA',
          const Offset(255, 192),
          site + const Offset(0, -24),
          SceneInk.quiet,
          delta.clamp,
        );
        direction(site, leading: false);
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
          g.leadingEnzyme + const Offset(0, 25),
          SceneInk.quiet,
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
        label(
          'Okazaki fragment',
          above,
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
        final double replaced = _eased(_s, 99.4, 100.4);
        final Offset front = g.daughter(
          99.5 - _f.replacedBases,
          leading: false,
        );
        label(
          'RNA flap',
          const Offset(242, 430),
          front,
          SceneInk.rna,
          1 - replaced,
        );
        label(
          'RNA replaced',
          const Offset(242, 430),
          front,
          SceneInk.rna,
          replaced,
        );
      case ReplicationChapter.ligase:
        label(
          'DNA ligase I',
          below,
          g.centre(89.5, leading: false) + const Offset(-20, 12),
          SceneInk.ligase,
          _ligase.opacity,
        );
        final double joined = _eased(_s, 109.5, 110.5);
        label('Nick', above, g.nick, SceneInk.quiet, 1 - joined);
        label('Joined backbone', above, g.nick, SceneInk.newDna, joined);
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
