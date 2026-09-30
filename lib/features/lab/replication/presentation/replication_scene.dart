import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../../../shared/ribosome/molecular_material.dart';
import '../domain/genome_replication.dart';
import '../domain/replication_tour.dart';
import 'replication_camera.dart';
import 'replication_geometry.dart';
import 'replication_molecules.dart';

abstract final class ReplicationPalette {
  static const Color parental = Color(0xFF96A6BA);
  static const Color daughter = Color(0xFF92C6B1);
  static const Color rna = Color(0xFFD5AC76);
  static const Color helicase = Color(0xFF698D86);
  static const Color polymerase = Color(0xFF8499B5);
  static const Color primase = Color(0xFFB29974);
  static const Color rpa = Color(0xFFAA94BB);
  static const Color nuclease = Color(0xFFBE8F87);
  static const Color ligase = Color(0xFFB3A1BC);
}

class ReplicationScene extends CustomPainter {
  ReplicationScene({
    required this.timeline,
    required this.at,
    required this.molecules,
    required this.ground,
    required this.ink,
    required this.quiet,
    required this.bases,
    this.showLabels = true,
    this.followCamera = true,
    this.reducedMotion = false,
    super.repaint,
  });

  final ReplicationTimeline timeline;
  final double Function() at;
  final ReplicationMolecules molecules;
  final Color ground;
  final Color ink;
  final Color quiet;
  final NucleotideColors bases;
  final bool showLabels;
  final bool followCamera;
  final bool reducedMotion;
  final Map<(String, Color, double), TextPainter> _textCache =
      <(String, Color, double), TextPainter>{};

  final Paint _line = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final Paint _fill = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ReplicationMoment moment = timeline.stateAt(at());
    final ReplicationFrame frame = moment.frame;
    final ReplicationCamera camera = ReplicationCamera.at(
      moment,
      follow: followCamera,
      reducedMotion: reducedMotion,
    );
    final double scale = math.min(size.width / 360, size.height / 600);
    // Let a close-up fill tall phones too. Extend the DNA beyond the viewport
    // instead of showing the ends of the overview's drawing inside the zoom.
    final Rect viewport = Rect.fromCenter(
      center: const Offset(180, 300),
      width: size.width / scale,
      height: size.height / scale,
    );
    final Rect crop = Rect.lerp(
      const Rect.fromLTWH(0, 27, 360, 523),
      viewport,
      ((camera.zoom - 1) / 0.4).clamp(0.0, 1.0),
    )!;
    final ReplicationGeometry g = ReplicationGeometry(
      frame,
      top: camera.centre.dy + (crop.top - 300) / camera.zoom,
      bottom: camera.centre.dy + (crop.bottom - 300) / camera.zoom,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 600 * scale) / 2,
    );
    canvas.scale(scale);

    canvas.save();
    canvas.clipRect(crop);
    canvas.translate(180, 300);
    canvas.scale(camera.zoom);
    canvas.translate(-camera.centre.dx, -camera.centre.dy);
    _ambience(canvas, g);
    _parent(canvas, g);
    _daughter(canvas, g, leading: true);
    _daughter(canvas, g, leading: false);
    _proteins(canvas, g, frame);
    if (frame.stage == ReplicationStage.replace && frame.replacedBases < 10) {
      _flap(canvas, g, frame);
    }
    if (frame.hasNick || frame.sealed) _nick(canvas, g, frame);
    canvas.restore();
    if (camera.zoom == 1) {
      _directions(canvas, g, frame);
      if (showLabels) _labels(canvas, g, frame);
    } else {
      _closeUpLabels(canvas, g, moment, camera);
    }
    canvas.restore();
  }

  void _ambience(Canvas canvas, ReplicationGeometry g) {
    // A restrained pool of light, on the same warm ground as the Ribosome.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(180, g.forkY + 60),
        width: 320,
        height: 330,
      ),
      _fill
        ..shader = ui.Gradient.radial(Offset(180, g.forkY + 60), 190, <Color>[
          ReplicationPalette.helicase.withValues(alpha: 0.07),
          ground.withValues(alpha: 0),
        ]),
    );
    _fill.shader = null;
  }

  void _parent(Canvas canvas, ReplicationGeometry g) {
    final double top =
        g.frame.fork + (g.forkY - g.top) / ReplicationGeometry.pitch;
    // Each half-turn is one smooth tube. Painting a shadow on every tiny
    // segment made serrated edges when the camera moved close.
    final List<(Path, double)> paths = <(Path, double)>[];
    for (double start = g.frame.fork; start < top; start += 19) {
      final double end = math.min(top, start + 19);
      final bool frontLeading = ((start - g.frame.fork) / 19).round().isEven;
      for (final bool leading in <bool>[false, true]) {
        paths.add((
          _trace(start, end, (double i) => g.template(i, leading: leading)),
          leading == frontLeading ? 1 : 0.6,
        ));
      }
    }
    for (final double depth in <double>[0.6, 1]) {
      for (final (Path path, double shade) in paths) {
        if (shade == depth) {
          _backbonePath(
            canvas,
            path,
            ReplicationPalette.parental,
            depth: shade,
          );
        }
      }
    }
    for (double i = (g.frame.fork / 5).ceil() * 5; i <= top; i += 5) {
      _pair(
        canvas,
        g.template(i, leading: true),
        g.template(i, leading: false),
        GenomeReplication.templateAt(i.toInt()),
        parental: true,
      );
    }
  }

  void _daughter(
    Canvas canvas,
    ReplicationGeometry g, {
    required bool leading,
  }) {
    DaughterBase made(int index) =>
        leading ? g.frame.leadingAt(index) : g.frame.laggingAt(index);
    _backbonePath(
      canvas,
      _trace(
        g.firstVisible - 1,
        g.frame.fork,
        (double i) => g.template(i, leading: leading),
      ),
      ReplicationPalette.parental,
    );
    Path? daughter;
    DaughterBase material = DaughterBase.absent;
    void finish() {
      if (daughter != null) {
        _backbonePath(
          canvas,
          daughter!,
          material == DaughterBase.rna
              ? ReplicationPalette.rna
              : ReplicationPalette.daughter,
        );
        daughter = null;
      }
    }

    for (double i = g.firstVisible - 1; i < g.frame.fork; i += 0.6) {
      final DaughterBase current = made(i.floor());
      final double junction = 99.5 - g.frame.replacedBases;
      final bool nick =
          !leading &&
          !g.frame.sealed &&
          i >= junction - 1.6 &&
          i <= junction + 1.6;
      final bool previousJoin =
          !leading && g.frame.seconds < 50 && i.abs() < 1.3;
      if (current == DaughterBase.absent ||
          made((i + 0.6).ceil()) == DaughterBase.absent ||
          nick ||
          previousJoin) {
        finish();
        continue;
      }
      if (current != material) finish();
      material = current;
      final Offset a = g.daughter(i, leading: leading);
      final Offset b = g.daughter(i + 0.6, leading: leading);
      daughter ??= Path()..moveTo(a.dx, a.dy);
      daughter!.lineTo(b.dx, b.dy);
    }
    finish();

    for (int i = (g.firstVisible / 5).floor() * 5; i < g.frame.fork; i += 5) {
      final Offset template = g.template(i.toDouble(), leading: leading);
      final DaughterBase type = made(i);
      final String base = leading
          ? GenomeReplication.templateAt(i)
          : GenomeReplication.complement(GenomeReplication.templateAt(i));
      if (type != DaughterBase.absent) {
        final Offset daughter = g.daughter(i.toDouble(), leading: leading);
        _pair(canvas, template, daughter, base, rna: type == DaughterBase.rna);
      } else {
        final Offset end = template + Offset(leading ? 7 : -7, 0);
        _rod(canvas, template, end, bases.forBase(base), width: 2.8);
        _sphere(canvas, template, 2, ReplicationPalette.parental);
      }
    }
  }

  void _pair(
    Canvas canvas,
    Offset a,
    Offset b,
    String base, {
    bool parental = false,
    bool rna = false,
  }) {
    if ((a - b).distance < 4) return;
    final Offset middle = (a + b) / 2;
    final Offset gap = (b - a) / (a - b).distance * 1.1;
    _rod(canvas, a, middle - gap, bases.forBase(base), width: 2.8);
    _rod(
      canvas,
      middle + gap,
      b,
      rna
          ? ReplicationPalette.rna
          : bases.forBase(GenomeReplication.complement(base)),
      width: 2.8,
    );
    canvas.drawLine(
      middle - gap,
      middle + gap,
      _line
        ..strokeWidth = 0.7
        ..color = quiet.withValues(alpha: 0.45),
    );
    _sphere(canvas, a, 2.2, ReplicationPalette.parental);
    _sphere(
      canvas,
      b,
      2.2,
      parental
          ? ReplicationPalette.parental
          : rna
          ? ReplicationPalette.rna
          : ReplicationPalette.daughter,
    );
  }

  void _proteins(Canvas canvas, ReplicationGeometry g, ReplicationFrame f) {
    // Topoisomerase lies on duplex DNA ahead of the fork.
    molecules.draw(
      canvas,
      Offset(180, g.forkY - 108),
      const Size(51, 46),
      ReplicationPalette.primase,
      seed: 18,
    );

    // The pore follows the leading template. The excluded lagging template
    // passes outside the helicase's right edge, not through the ring.
    molecules.draw(
      canvas,
      Offset(164, g.forkY + 9),
      const Size(79, 81),
      ReplicationPalette.helicase,
      seed: 37,
    );
    // The leading template threads the open pore; the other exits outside it.
    _backbonePath(
      canvas,
      _trace(
        f.fork - 17,
        f.fork + 15,
        (double i) => g.template(i, leading: true),
      ),
      ReplicationPalette.parental,
    );
    _backbonePath(
      canvas,
      _trace(f.fork - 25, f.fork, (double i) => g.template(i, leading: false)),
      ReplicationPalette.parental,
    );

    final Offset leading = g.leadingEnzyme;
    _clamp(canvas, leading + const Offset(0, 25));
    molecules.draw(
      canvas,
      leading,
      const Size(77, 77),
      ReplicationPalette.polymerase,
      seed: 7,
      angle: -0.18,
    );
    _activeSite(canvas, leading, f.seconds);

    for (int i = 15; i < f.fork - 24; i += 26) {
      if (f.laggingAt(i) != DaughterBase.absent) continue;
      final Offset p = g.template(i.toDouble(), leading: false);
      // Avoid occluding the enzyme's working site as it takes over from RPA.
      final Offset active = f.priming ? g.primase : g.laggingEnzyme;
      if ((p - active).distance < 34) continue;
      molecules.draw(
        canvas,
        p + const Offset(5, 0),
        const Size(23, 27),
        ReplicationPalette.rpa,
        channel: false,
        seed: 61,
      );
    }

    final double handoff = f.activeFragment == 0 ? 20 : 62;
    final bool handingOff = f.seconds >= handoff && f.seconds < handoff + 2;
    if (f.priming || handingOff) {
      final double elapsed = f.seconds - (f.activeFragment == 0 ? 8 : 50);
      final double arrival = ReplicationFrame.progress(elapsed, 0, 0.9);
      final double departure = ReplicationFrame.progress(
        f.seconds,
        handoff,
        handoff + 2,
      );
      final Offset centre =
          (handingOff
              ? g.centre((f.activeFragment + 1) * 100 - 30, leading: false)
              : g.primase) +
          Offset(24 * (1 - arrival + departure), -13 * (1 - arrival));
      molecules.draw(
        canvas,
        centre,
        const Size(65, 64),
        ReplicationPalette.primase,
        seed: 28,
        opacity: arrival * (1 - departure),
      );
      _activeSite(canvas, centre, f.seconds, color: ReplicationPalette.rna);
      if (elapsed > 10) _clamp(canvas, centre + const Offset(0, -24));
    }
    final double deltaEnd = f.activeFragment == 0 ? 46 : 100;
    final bool deltaLeaving = f.seconds >= deltaEnd && f.seconds < deltaEnd + 2;
    if (f.deltaActive || deltaLeaving) {
      final double arrival = ReplicationFrame.progress(
        f.seconds,
        handoff,
        handoff + 2,
      );
      final double departure = ReplicationFrame.progress(
        f.seconds,
        deltaEnd,
        deltaEnd + 2,
      );
      final Offset delta =
          g.laggingEnzyme + Offset(-25 * (1 - arrival + departure), 0);
      _clamp(canvas, g.laggingEnzyme + const Offset(0, -24));
      molecules.draw(
        canvas,
        delta,
        const Size(77, 72),
        ReplicationPalette.polymerase,
        seed: 42,
        angle: 0.13,
        opacity: arrival * (1 - departure),
      );
      if (f.deltaActive) _activeSite(canvas, delta, f.seconds);
    }
    if (f.stage == ReplicationStage.replace) {
      final Offset delta = g.laggingEnzyme;
      molecules.draw(
        canvas,
        delta + const Offset(-33, 24),
        const Size(40, 39),
        ReplicationPalette.nuclease,
        seed: 83,
        channel: false,
      );
    }
    if (f.stage == ReplicationStage.seal || (f.sealed && f.seconds < 114)) {
      final double entry = ReplicationFrame.progress(f.seconds, 102, 104);
      final double exit = ReplicationFrame.progress(f.seconds, 110, 114);
      final Offset centre =
          g.centre(89.5, leading: false) + Offset(35 * (1 - entry + exit), 0);
      molecules.draw(
        canvas,
        centre,
        const Size(69, 63),
        ReplicationPalette.ligase,
        seed: 92,
        opacity: entry * (1 - exit),
      );
    }
  }

  void _clamp(Canvas canvas, Offset p) {
    final Rect rect = Rect.fromCenter(center: p, width: 36, height: 11);
    canvas.drawOval(
      rect,
      _line
        ..strokeWidth = 5
        ..color = const Color(0xFF4C655E),
    );
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      _line
        ..strokeWidth = 3
        ..color = ReplicationPalette.daughter,
    );
  }

  void _activeSite(
    Canvas canvas,
    Offset p,
    double seconds, {
    Color color = ReplicationPalette.daughter,
  }) {
    final double pulse = 0.5 + 0.5 * math.sin(seconds * 2.4);
    canvas.drawCircle(
      p,
      12,
      _fill
        ..shader = ui.Gradient.radial(p, 12, <Color>[
          color.withValues(alpha: 0.1 + pulse * 0.08),
          color.withValues(alpha: 0),
        ]),
    );
    _fill.shader = null;
  }

  void _flap(Canvas canvas, ReplicationGeometry g, ReplicationFrame f) {
    final Offset site = g.daughter(100 - f.replacedBases, leading: false);
    final Path flap = Path()
      ..moveTo(site.dx, site.dy)
      ..cubicTo(
        site.dx - 12,
        site.dy + 9,
        site.dx - 25,
        site.dy - 7,
        site.dx - 32,
        site.dy + 9,
      );
    canvas.drawPath(
      flap,
      _line
        ..strokeWidth = 2.4
        ..color = ReplicationPalette.rna,
    );
  }

  void _nick(Canvas canvas, ReplicationGeometry g, ReplicationFrame f) {
    final Offset p = g.nick;
    if (!f.sealed) {
      canvas.drawCircle(
        p,
        7,
        _line
          ..strokeWidth = 1.2
          ..color = ReplicationPalette.rna,
      );
    } else {
      final double fade = 1 - ReplicationFrame.progress(f.seconds, 111, 116);
      canvas.drawCircle(
        p,
        8 + 8 * (1 - fade),
        _line
          ..strokeWidth = 1.5
          ..color = ReplicationPalette.daughter.withValues(alpha: fade),
      );
    }
  }

  void _directions(Canvas canvas, ReplicationGeometry g, ReplicationFrame f) {
    _arrow(
      canvas,
      const Offset(78, 577),
      const Offset(78, 562),
      ReplicationPalette.daughter,
    );
    _arrow(
      canvas,
      const Offset(281, 562),
      const Offset(281, 577),
      ReplicationPalette.daughter,
    );
    if (showLabels) {
      _text(
        canvas,
        'Leading strand',
        const Offset(78, 583),
        size: 12.5,
        color: ink,
      );
      _text(
        canvas,
        'Lagging strand',
        const Offset(281, 583),
        size: 12.5,
        color: ink,
      );
      _text(canvas, '5′ → 3′', const Offset(78, 548), size: 10, color: quiet);
      _text(canvas, '5′ → 3′', const Offset(281, 548), size: 10, color: quiet);
      _text(canvas, 'Parental DNA', const Offset(180, 4), size: 13, color: ink);
      _text(canvas, '5′', const Offset(154, 25), size: 10, color: quiet);
      _text(canvas, '3′', const Offset(205, 25), size: 10, color: quiet);
    }
    // Physical direction of travel; these arrows sit beside the working tips.
    final Offset lead = g.leadingEnzyme;
    _arrow(
      canvas,
      lead + const Offset(-43, 12),
      lead + const Offset(-43, -9),
      ReplicationPalette.daughter,
    );
    if (f.deltaActive) {
      final Offset lag = g.laggingEnzyme;
      _arrow(
        canvas,
        lag + const Offset(44, -10),
        lag + const Offset(44, 11),
        ReplicationPalette.daughter,
      );
    }
  }

  void _labels(Canvas canvas, ReplicationGeometry g, ReplicationFrame f) {
    _callout(
      canvas,
      'Topoisomerase',
      Offset(16, g.forkY - 133),
      Offset(153, g.forkY - 109),
      color: ReplicationPalette.rna,
    );
    _callout(
      canvas,
      'CMG helicase',
      Offset(230, g.forkY - 48),
      Offset(193, g.forkY - 11),
      color: ReplicationPalette.daughter,
    );
    final Offset leading = g.leadingEnzyme;
    _text(
      canvas,
      'Pol ε',
      leading + const Offset(-9, -54),
      size: 13,
      color: ink,
    );
    _callout(
      canvas,
      'PCNA',
      leading + const Offset(-80, 29),
      leading + const Offset(-14, 26),
      color: quiet,
    );

    if (f.priming) {
      final Offset p = g.primase;
      _callout(
        canvas,
        'Primase · Pol α',
        Offset(156, p.dy + 44),
        p + const Offset(-20, 18),
        color: ReplicationPalette.rna,
      );
    } else if (f.deltaActive) {
      final Offset p = g.laggingEnzyme;
      _text(
        canvas,
        'Pol δ',
        Offset(p.dx - 60, math.min(510, p.dy - 22)),
        size: 13,
        color: ink,
      );
    }
    if (f.stage == ReplicationStage.unwind) {
      final Offset rpa = g.template(41, leading: false);
      _callout(
        canvas,
        'RPA',
        Offset(208, rpa.dy - 21),
        rpa,
        color: ReplicationPalette.rpa,
      );
    }
    if (f.seconds >= 20 && f.seconds < 88) {
      final Offset primer = g.daughter(95, leading: false);
      _callout(
        canvas,
        'RNA primer',
        Offset(155, primer.dy - 22),
        primer,
        color: ReplicationPalette.rna,
      );
    }
    if (f.stage == ReplicationStage.replace) {
      _text(
        canvas,
        'FEN1',
        g.laggingEnzyme + const Offset(-48, 49),
        color: ReplicationPalette.nuclease,
        size: 12,
      );
    }
    if (f.stage == ReplicationStage.seal) {
      _callout(
        canvas,
        'DNA ligase I',
        Offset(144, g.nick.dy - 36),
        g.centre(89.5, leading: false) - const Offset(25, 13),
        color: ReplicationPalette.ligase,
      );
    }
    if (f.stage == ReplicationStage.continueFork) {
      _text(
        canvas,
        'Joined DNA',
        const Offset(230, 471),
        color: ReplicationPalette.daughter,
        size: 12,
      );
      _text(
        canvas,
        'One old + one new',
        const Offset(180, 519),
        size: 11,
        color: quiet,
      );
    }
  }

  // Labels live in screen space, so magnifying an enzyme does not magnify its
  // name or leave the overview's unrelated callouts crossing the close-up.
  void _closeUpLabels(
    Canvas canvas,
    ReplicationGeometry g,
    ReplicationMoment moment,
    ReplicationCamera camera,
  ) {
    final ReplicationFrame f = moment.frame;
    void label(String text, Offset at, Offset target, Color color) {
      final Offset projected = camera.project(target);
      if (!showLabels ||
          !const Rect.fromLTWH(16, 45, 328, 520).contains(projected)) {
        return;
      }
      _callout(canvas, text, at, projected, color: color);
    }

    void direction(Offset site, {required bool leading}) {
      final Offset p = camera.project(site) + const Offset(112, 0);
      if (!const Rect.fromLTWH(20, 80, 300, 410).contains(p)) return;
      _arrow(
        canvas,
        p + Offset(0, leading ? 24 : -24),
        p + Offset(0, leading ? -24 : 24),
        ReplicationPalette.daughter,
      );
      if (showLabels) {
        _text(
          canvas,
          '5′ → 3′',
          p + const Offset(0, 34),
          color: quiet,
          size: 11,
        );
      }
    }

    const Offset below = Offset(24, 450);
    const Offset above = Offset(24, 112);
    switch (moment.chapter) {
      case ReplicationChapter.overview:
      case ReplicationChapter.result:
        break;
      case ReplicationChapter.helicase:
        label(
          'CMG helicase',
          const Offset(220, 452),
          Offset(191, g.forkY + 30),
          ReplicationPalette.daughter,
        );
        label(
          'Parental DNA',
          const Offset(225, 80),
          g.template(f.fork + 30, leading: false),
          quiet,
        );
      case ReplicationChapter.binding:
        label(
          'RPA · human SSB',
          below,
          g.template(67, leading: false) + const Offset(5, 8),
          ReplicationPalette.rpa,
        );
        label('Exposed template', above, g.template(85, leading: false), quiet);
      case ReplicationChapter.topoisomerase:
        label(
          'Topoisomerase',
          below,
          Offset(162, g.forkY - 96),
          ReplicationPalette.rna,
        );
      case ReplicationChapter.primase:
      case ReplicationChapter.nextPrimer:
      case ReplicationChapter.polymerase:
        final int fragment = moment.chapter == ReplicationChapter.nextPrimer
            ? 1
            : 0;
        final Offset site = g.centre(f.tipOf(fragment), leading: false);
        final bool delta = f.seconds >= (fragment == 0 ? 20 : 62);
        label(
          delta ? 'Pol δ' : 'Primase · Pol α',
          below,
          site + const Offset(-20, 16),
          delta ? ink : ReplicationPalette.rna,
        );
        final double primer = fragment == 0 ? 95 : 195;
        if (f.laggingAt(primer.toInt()) == DaughterBase.rna) {
          label(
            'RNA primer',
            const Offset(218, 112),
            g.daughter(primer, leading: false),
            ReplicationPalette.rna,
          );
        }
        if (delta) {
          label(
            'PCNA',
            const Offset(255, 192),
            site + const Offset(0, -24),
            quiet,
          );
        }
        direction(site, leading: false);
      case ReplicationChapter.leading:
        label('Pol ε', below, g.leadingEnzyme + const Offset(-22, 14), ink);
        label(
          'PCNA',
          const Offset(236, 430),
          g.leadingEnzyme + const Offset(0, 25),
          quiet,
        );
        direction(g.leadingEnzyme, leading: true);
      case ReplicationChapter.lagging:
      case ReplicationChapter.fragments:
        final int fragment = moment.chapter == ReplicationChapter.lagging
            ? 0
            : 1;
        final Offset site = g.centre(f.tipOf(fragment), leading: false);
        if (f.deltaActive) {
          label('Pol δ', below, site + const Offset(-20, 14), ink);
        }
        label(
          'Okazaki fragment',
          above,
          g.daughter(f.tipOf(fragment) + 38, leading: false),
          ReplicationPalette.daughter,
        );
        if (f.deltaActive) direction(site, leading: false);
      case ReplicationChapter.replacement:
        label('Pol δ', above, g.laggingEnzyme + const Offset(-20, -12), ink);
        label(
          'FEN1',
          below,
          g.laggingEnzyme + const Offset(-33, 24),
          ReplicationPalette.nuclease,
        );
        label(
          f.hasNick ? 'RNA replaced' : 'RNA flap',
          const Offset(242, 430),
          g.daughter(100 - f.replacedBases, leading: false),
          ReplicationPalette.rna,
        );
      case ReplicationChapter.ligase:
        label(
          'DNA ligase I',
          below,
          g.centre(89.5, leading: false) + const Offset(-20, 12),
          ReplicationPalette.ligase,
        );
        label(
          f.sealed ? 'Joined backbone' : 'Nick',
          above,
          g.nick,
          f.sealed ? ReplicationPalette.daughter : ReplicationPalette.rna,
        );
    }
  }

  void _callout(
    Canvas canvas,
    String label,
    Offset at,
    Offset to, {
    required Color color,
  }) {
    _text(canvas, label, at, color: color, size: 12, centred: false);
    final Offset start = at + const Offset(19, 17);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx, start.dy + 5)
        ..lineTo(to.dx, to.dy),
      _line
        ..strokeWidth = 0.8
        ..color = color.withValues(alpha: 0.45),
    );
    canvas.drawCircle(to, 1.5, _fill..color = color);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    double size = 12,
    bool centred = true,
  }) {
    final TextPainter painter = _textCache.putIfAbsent(
      (text, color, size),
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AppTypography.sansFamily,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Helvetica Neue',
              'Arial',
            ],
            fontSize: size,
            fontWeight: FontWeight.w500,
            color: color,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    painter.paint(canvas, at - Offset(centred ? painter.width / 2 : 0, 0));
  }

  static Path _trace(
    double start,
    double end,
    Offset Function(double) pointAt,
  ) {
    final Offset startPoint = pointAt(start);
    final Path path = Path()..moveTo(startPoint.dx, startPoint.dy);
    for (double i = start + 0.6; i < end; i += 0.6) {
      final Offset p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }
    final Offset endPoint = pointAt(end);
    path.lineTo(endPoint.dx, endPoint.dy);
    return path;
  }

  void _backbonePath(
    Canvas canvas,
    Path path,
    Color color, {
    double depth = 1,
  }) {
    canvas.drawPath(
      path.shift(const Offset(1, 1)),
      _line
        ..strokeWidth = 4
        ..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawPath(
      path,
      _line
        ..strokeWidth = 2.9
        ..color = color.withValues(alpha: depth),
    );
    canvas.drawPath(
      path.shift(const Offset(-0.6, 0)),
      _line
        ..strokeWidth = 0.7
        ..color = Colors.white.withValues(alpha: 0.19 * depth),
    );
  }

  void _rod(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color, {
    double width = 3,
  }) {
    canvas.drawLine(
      a,
      b,
      _line
        ..strokeWidth = width
        ..color = color,
    );
    canvas.drawLine(
      a - const Offset(0, 0.6),
      b - const Offset(0, 0.6),
      _line
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.2),
    );
  }

  void _sphere(Canvas canvas, Offset at, double radius, Color color) {
    final Rect bounds = Rect.fromCircle(center: at, radius: radius);
    canvas.drawCircle(
      at,
      radius,
      _fill..shader = MolecularMaterial.residueShader(bounds, color),
    );
    _fill.shader = null;
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final Offset direction = (to - from) / (to - from).distance;
    final Offset normal = Offset(-direction.dy, direction.dx);
    canvas.drawLine(
      from,
      to,
      _line
        ..strokeWidth = 1.5
        ..color = color,
    );
    canvas.drawPath(
      Path()
        ..moveTo(
          (to - direction * 4 + normal * 3).dx,
          (to - direction * 4 + normal * 3).dy,
        )
        ..lineTo(to.dx, to.dy)
        ..lineTo(
          (to - direction * 4 - normal * 3).dx,
          (to - direction * 4 - normal * 3).dy,
        ),
      _line,
    );
  }

  @override
  bool shouldRepaint(covariant ReplicationScene oldDelegate) =>
      oldDelegate.ground != ground ||
      oldDelegate.ink != ink ||
      oldDelegate.quiet != quiet ||
      oldDelegate.bases != bases ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.followCamera != followCamera ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.molecules != molecules ||
      oldDelegate.timeline != timeline ||
      oldDelegate.at != at;
}
