import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../../../shared/format.dart';
import '../domain/translation_timeline.dart';

/// The colours a translation is drawn in, every one from the theme: the
/// walk's nucleotide and amino palettes, and the scheme's own surfaces.
@immutable
final class TranslationInks {
  const TranslationInks({
    required this.background,
    required this.smallSubunit,
    required this.largeSubunit,
    required this.outline,
    required this.ink,
    required this.quiet,
    required this.nucleotides,
    required this.anatomy,
  });

  factory TranslationInks.of(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TranslationInks(
      background: scheme.surface,
      smallSubunit: scheme.surfaceContainerHighest,
      largeSubunit: scheme.surfaceContainerHigh,
      outline: scheme.outline,
      ink: scheme.onSurface,
      quiet: scheme.onSurfaceVariant,
      nucleotides: context.nucleotideColors,
      anatomy: context.anatomyColors,
    );
  }

  final Color background;
  final Color smallSubunit;
  final Color largeSubunit;
  final Color outline;
  final Color ink;
  final Color quiet;
  final NucleotideColors nucleotides;
  final AnatomyColors anatomy;

  @override
  bool operator ==(Object other) =>
      other is TranslationInks &&
      other.background == background &&
      other.smallSubunit == smallSubunit &&
      other.largeSubunit == largeSubunit &&
      other.outline == outline &&
      other.ink == ink &&
      other.quiet == quiet &&
      other.nucleotides == nucleotides &&
      other.anatomy == anatomy;

  @override
  int get hashCode => Object.hash(
    background,
    smallSubunit,
    largeSubunit,
    outline,
    ink,
    quiet,
    nucleotides,
    anatomy,
  );
}

/// Translation drawn schematically, at the `t` [at] reads, windowed on the
/// ribosome.
///
/// The mRNA runs across the canvas as the walk's transcript page letters it:
/// 20-point tiles at a 21-point pitch on the walk's base tile, each letter in
/// its base's colour, the untranslated ends washed back and the start and stop
/// codons in their role colours. The view follows the ribosome, whose P site
/// stays at the centre, so only the bases on the canvas are drawn: a gene of
/// any length costs the same per frame.
///
/// The two subunits are schematic shapes in the scheme's two raised surfaces,
/// the tRNAs spanning them: each stands on its codon with its anticodon paired
/// base by base against it and reaches up to the peptidyl transferase centre,
/// carrying its amino acid, or, holding the chain, linked to it. The chain
/// runs from that centre up the exit tunnel. The tunnel is compressed so that
/// its 35 residues fit the subunit (the two newest keep a residue's full size
/// and letter, the rest are beads), and past its exit the chain trails along
/// the canvas's edge, the nearest [trailing] residues drawn and the rest
/// counted.
///
/// Conventions from `AnatomyPainter`: every `Paint` is made once, glyphs are
/// laid out once per letter and ink and cached as paragraphs, residue
/// positions go through one preallocated buffer, and nothing in the per-frame
/// loops allocates.
class TranslationPainter extends CustomPainter {
  TranslationPainter({
    required this.timeline,
    required this.at,
    required this.inks,
    super.repaint,
    this.trailing = 48,
  });

  final TranslationTimeline timeline;

  /// The `t` to draw, read at paint time.
  final double Function() at;
  final TranslationInks inks;

  /// How many residues past the tunnel's exit may be drawn before the rest of
  /// the chain is only counted.
  final int trailing;

  static const double pitch = 21;
  static const double tile = 20;

  /// How much of a base's tile an untranslated one keeps, and of its letter:
  /// the walk's washed-back ends.
  static const double utrTile = 0.2;
  static const double utrInk = 0.67;

  /// A residue's radius where it is drawn whole, and where it is packed into
  /// the tunnel.
  static const double residueRadius = 8;
  static const double beadRadius = 3;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// Residue centres, x then y.
  late final Float32List _beads = Float32List(
    2 * (TranslationTimeline.tunnelCapacity + trailing + 2),
  );

  final Map<(String, int, int), ui.Paragraph> _glyphs =
      <(String, int, int), ui.Paragraph>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final TranslationState s = timeline.stateAt(at());
    final _Frame f = _Frame(size, s.ribosome);

    _drawSmallSubunit(canvas, f, s);
    _drawMrna(canvas, f);
    _drawJunctions(canvas, f, s);
    _drawLargeSubunit(canvas, f, s);
    _drawTrna(canvas, f, s, s.e);
    _drawTrna(canvas, f, s, s.p);
    _drawTrna(canvas, f, s, s.a);
    _drawReleaseFactor(canvas, f, s);
    _drawChain(canvas, f, s);
    _drawSiteLabels(canvas, f, s);
  }

  // ------------------------------------------------------------- the mRNA

  void _drawMrna(Canvas canvas, _Frame f) {
    final String mrna = timeline.mrna;
    final int first = math.max(0, f.baseAt(0).floor() - 1);
    final int last = math.min(
      mrna.length - 1,
      f.baseAt(f.size.width).ceil() + 1,
    );
    final int start = timeline.cdsStart;
    final int stop = timeline.stopCodonStart;
    for (int i = first; i <= last; i++) {
      final String base = mrna[i];
      final bool translated = i >= start && i < stop + 3;
      final bool startCodon = i >= start && i < start + 3;
      final bool stopCodon = i >= stop && i < stop + 3;
      final Rect box = Rect.fromCenter(
        center: Offset(f.xOf(i), f.mrnaY),
        width: tile,
        height: tile,
      );
      _fill.color = startCodon
          ? inks.anatomy.roleStartCodon
          : stopCodon
          ? inks.anatomy.roleStopCodon
          : translated
          ? inks.anatomy.baseTile
          : Color.lerp(inks.background, inks.anatomy.baseTile, utrTile)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        _fill,
      );
      // The frame's two ends letter white, as the walk's do; every other base
      // in its own colour, washed back off the reading frame.
      final Color ink = startCodon || stopCodon
          ? inks.ink
          : translated
          ? inks.nucleotides.forBase(base)
          : Color.lerp(
              inks.background,
              inks.nucleotides.forBase(base),
              utrInk,
            )!;
      _letter(canvas, base, ink, box.center, 12);
    }
  }

  /// A mark above each exon junction the ribosome has not reached, where the
  /// exon junction complex sits; it goes as the ribosome passes.
  void _drawJunctions(Canvas canvas, _Frame f, TranslationState s) {
    for (final int junction in timeline.junctions) {
      final double x = f.xOf(junction) - pitch / 2;
      if (x < -pitch || x > f.size.width + pitch) {
        continue;
      }
      final double strength =
          1 - (s.ribosome - junction + 3).clamp(0.0, 3.0) / 3;
      if (strength <= 0) {
        continue;
      }
      final double top = f.mrnaY - tile / 2;
      _fill.color = inks.anatomy.roleExon.withValues(alpha: strength);
      canvas.drawPath(
        Path()
          ..moveTo(x, top - 12)
          ..lineTo(x + 5, top - 6)
          ..lineTo(x, top)
          ..lineTo(x - 5, top - 6)
          ..close(),
        _fill,
      );
    }
  }

  // ---------------------------------------------------------- the subunits

  void _drawSmallSubunit(Canvas canvas, _Frame f, TranslationState s) {
    if (s.smallSubunit <= 0) {
      return;
    }
    final double drift = (1 - s.smallSubunit) * 40;
    final RRect shape = RRect.fromRectAndRadius(
      f.smallSubunit.translate(0, drift),
      const Radius.circular(18),
    );
    _fill.color = inks.smallSubunit.withValues(alpha: s.smallSubunit);
    canvas.drawRRect(shape, _fill);
    _stroke.color = inks.outline.withValues(alpha: s.smallSubunit);
    canvas.drawRRect(shape, _stroke);
  }

  void _drawLargeSubunit(Canvas canvas, _Frame f, TranslationState s) {
    if (s.largeSubunit <= 0) {
      return;
    }
    final double lift = f.lift(s);
    final RRect shape = f.largeSubunit.shift(Offset(0, -lift));
    _fill.color = inks.largeSubunit.withValues(alpha: 0.78 * s.largeSubunit);
    canvas.drawRRect(shape, _fill);
    _stroke.color = inks.outline.withValues(alpha: s.largeSubunit);
    canvas.drawRRect(shape, _stroke);
    // The exit tunnel, from the peptidyl transferase centre to the surface.
    _line
      ..color = inks.background.withValues(alpha: 0.85 * s.largeSubunit)
      ..strokeWidth = 12;
    canvas.drawLine(
      f.ptc.translate(0, -lift),
      f.tunnelExit.translate(0, -lift),
      _line,
    );
  }

  /// E, P and A, under the three codons the sites hold.
  void _drawSiteLabels(Canvas canvas, _Frame f, TranslationState s) {
    if (s.largeSubunit < 0.5) {
      return;
    }
    final Color ink = inks.quiet.withValues(alpha: s.largeSubunit);
    for (int site = 0; site < 3; site++) {
      _letter(
        canvas,
        const <String>['E', 'P', 'A'][site],
        ink,
        Offset(f.siteCentre(site), f.siteLabelY),
        11,
      );
    }
  }

  // ------------------------------------------------------------- the tRNAs

  /// Which tRNA holds the chain: the one whose codon made its newest residue.
  static TrnaSlot? _holder(TranslationState s) {
    for (final TrnaSlot? slot in <TrnaSlot?>[s.p, s.a]) {
      if (slot != null && slot.charged && slot.codon == s.residues) {
        return slot;
      }
    }
    return null;
  }

  void _drawTrna(Canvas canvas, _Frame f, TranslationState s, TrnaSlot? slot) {
    if (slot == null || slot.presence <= 0) {
      return;
    }
    final int codonStart = timeline.cdsStart + 3 * (slot.codon - 1);
    // A tRNA stands on its codon: it moves with the mRNA, and the ribosome
    // slides under it. Arriving it drops in from above, leaving it lifts off.
    final double away = (1 - slot.presence) * 90;
    final bool leaving = identical(slot, s.e);
    final double left =
        f.xOf(codonStart) - pitch / 2 + 2 - (leaving ? away * 0.5 : 0);
    final _Trna shape = _Trna(left, f.mrnaY - tile / 2 - 3 - away);
    final double alpha = slot.presence;
    _fill.color = inks.largeSubunit.withValues(alpha: alpha);
    _stroke.color = inks.quiet.withValues(alpha: alpha);
    for (final RRect part in <RRect>[shape.stem, shape.loop]) {
      canvas.drawRRect(part, _fill);
      canvas.drawRRect(part, _stroke);
    }
    // The anticodon, paired base by base with the codon under it.
    for (int i = 0; i < 3; i++) {
      final String base = _pair(timeline.mrna[codonStart + i]);
      _letter(
        canvas,
        base,
        inks.nucleotides.forBase(base).withValues(alpha: alpha),
        Offset(left + (i + 0.5) * (_Trna.width / 3), shape.loop.center.dy),
        10,
      );
    }
    if (!slot.charged || slot.codon > timeline.protein.length) {
      return;
    }
    if (identical(slot, _holder(s))) {
      // Holding the chain: linked to it at the peptidyl transferase centre.
      _line
        ..color = inks.quiet.withValues(alpha: alpha)
        ..strokeWidth = 2;
      canvas.drawLine(shape.acceptor, f.ptc.translate(0, -f.lift(s)), _line);
      return;
    }
    if (slot.codon > s.residues) {
      // Its own amino acid, still aboard. As the bond forms it is carried
      // over to the chain.
      final double bond = s.phase == TranslationPhase.peptideBond
          ? s.chainShift
          : 0;
      _residue(
        canvas,
        Offset.lerp(shape.acceptor, f.ptc, bond)!,
        residueRadius,
        timeline.protein[slot.codon - 1],
        alpha,
      );
    }
  }

  void _drawReleaseFactor(Canvas canvas, _Frame f, TranslationState s) {
    if (s.releaseFactor <= 0) {
      return;
    }
    final double away = (1 - s.releaseFactor) * 90;
    final _Trna shape = _Trna(
      f.xOf(timeline.stopCodonStart) - pitch / 2 + 2,
      f.mrnaY - tile / 2 - 3 - away,
    );
    _fill.color = inks.anatomy.roleStopCodon.withValues(
      alpha: 0.85 * s.releaseFactor,
    );
    canvas.drawRRect(shape.stem, _fill);
    canvas.drawRRect(shape.loop, _fill);
  }

  // ------------------------------------------------------------- the chain

  void _drawChain(Canvas canvas, _Frame f, TranslationState s) {
    final int residues = s.residues;
    if (residues == 0) {
      return;
    }
    final double lift = f.lift(s);
    const double capacity = TranslationTimeline.tunnelCapacity + 0.0;
    final int shown = math.min(trailing, f.trailCapacity);
    // Newest first: it sits at the centre, and each older residue is a step
    // further along.
    int drawn = 0;
    int hidden = 0;
    for (int r = residues - 1; r >= 0; r--) {
      final double depth = s.depthOf(r);
      if (depth > capacity + shown) {
        hidden = r + 1;
        break;
      }
      final Offset at = depth < capacity
          ? f.inTunnel(depth).translate(0, -lift)
          : f.trail(depth - capacity).translate(0, -lift);
      _beads[2 * drawn] = at.dx;
      _beads[2 * drawn + 1] = at.dy;
      drawn++;
    }
    // The backbone first, under the residues.
    _line
      ..color = inks.quiet.withValues(alpha: 0.7)
      ..strokeWidth = 2;
    for (int i = 1; i < drawn; i++) {
      canvas.drawLine(
        Offset(_beads[2 * i - 2], _beads[2 * i - 1]),
        Offset(_beads[2 * i], _beads[2 * i + 1]),
        _line,
      );
    }
    for (int i = drawn - 1; i >= 0; i--) {
      final int r = residues - 1 - i;
      _residue(
        canvas,
        Offset(_beads[2 * i], _beads[2 * i + 1]),
        _radiusAt(s.depthOf(r)),
        timeline.protein[r],
        1,
        ring: r < timeline.signalPeptideLength ? inks.anatomy.roleSignal : null,
      );
    }
    if (hidden > 0) {
      // The rest of the chain, too long to draw, is counted where it goes.
      final Offset end = f.trail(shown.toDouble()).translate(0, -lift);
      _letter(
        canvas,
        '+${grouped(hidden)}',
        inks.quiet,
        end.translate(-40, 0),
        10,
      );
    }
  }

  /// Whole for the two newest residues and for every residue out of the
  /// tunnel, a bead for the rest.
  static double _radiusAt(double depth) {
    if (depth >= TranslationTimeline.tunnelCapacity) {
      return residueRadius;
    }
    final double packed = (depth - _Frame.loose + 0.5).clamp(0.0, 1.0);
    return residueRadius + (beadRadius - residueRadius) * packed;
  }

  // ------------------------------------------------------------- drawing

  void _residue(
    Canvas canvas,
    Offset centre,
    double radius,
    String residue,
    double alpha, {
    Color? ring,
  }) {
    _fill.color = inks.anatomy.forResidue(residue).withValues(alpha: alpha);
    canvas.drawCircle(centre, radius, _fill);
    if (ring != null) {
      _stroke.color = ring.withValues(alpha: alpha);
      canvas.drawCircle(centre, radius + 1.5, _stroke);
    }
    if (radius >= residueRadius - 0.5) {
      // Knocked out of its colour in the ground, as the walk letters residues.
      _letter(
        canvas,
        residue,
        inks.background.withValues(alpha: alpha),
        centre,
        radius * 1.3,
      );
    }
  }

  static String _pair(String base) => switch (base) {
    'A' => 'T',
    'T' || 'U' => 'A',
    'G' => 'C',
    'C' => 'G',
    _ => 'N',
  };

  void _letter(
    Canvas canvas,
    String text,
    Color ink,
    Offset centre,
    double size,
  ) {
    final ui.Paragraph paragraph = _glyphs.putIfAbsent(
      (text, ink.toARGB32(), (size * 2).round()),
      () {
        final ui.ParagraphBuilder builder =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textAlign: TextAlign.center,
                  fontFamily: AppTypography.monoFamily,
                  fontSize: size,
                ),
              )
              ..pushStyle(ui.TextStyle(color: ink, fontWeight: FontWeight.w500))
              ..addText(text);
        return builder.build()
          ..layout(const ui.ParagraphConstraints(width: 64));
      },
    );
    canvas.drawParagraph(
      paragraph,
      Offset(centre.dx - 32, centre.dy - paragraph.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant TranslationPainter old) =>
      old.timeline != timeline ||
      old.inks != inks ||
      old.trailing != trailing ||
      old.at() != at();

  /// What a screen reader is told about [s], in place of the picture.
  static String describe(TranslationTimeline timeline, TranslationState s) {
    final String where = switch (s.phase) {
      TranslationPhase.scanning =>
        'The small subunit is scanning the 5 prime UTR',
      TranslationPhase.joining =>
        'The large subunit is joining at the start codon',
      TranslationPhase.releaseFactor ||
      TranslationPhase.release ||
      TranslationPhase.dissociation => 'Termination at the stop codon',
      _ =>
        'Codon ${s.codon}, '
            '${AminoAcids.nameOf(timeline.protein[s.codon - 1])}',
    };
    return '$where. ${s.residues} of ${timeline.protein.length} residues '
        'made.';
  }
}

/// A tRNA's two parts: the anticodon loop on the codon, the stem above it.
final class _Trna {
  _Trna(this.left, this.bottom);

  static const double width = 3 * TranslationPainter.pitch - 4;
  static const double loopHeight = 18;
  static const double stemHeight = 76;

  final double left;
  final double bottom;

  RRect get loop => RRect.fromRectAndRadius(
    Rect.fromLTRB(left, bottom - loopHeight, left + width, bottom),
    const Radius.circular(5),
  );

  RRect get stem => RRect.fromRectAndRadius(
    Rect.fromLTRB(
      left + width * 0.32,
      bottom - loopHeight - stemHeight,
      left + width * 0.68,
      bottom - loopHeight,
    ),
    const Radius.circular(6),
  );

  /// The acceptor end, where the amino acid rides.
  Offset get acceptor => Offset(
    left + width / 2,
    bottom - loopHeight - stemHeight - TranslationPainter.residueRadius,
  );
}

/// Where everything is for one canvas size and ribosome position.
final class _Frame {
  _Frame(this.size, this.ribosome)
    : mrnaY = size.height * 0.74,
      cx = size.width / 2;

  final Size size;

  /// The first base of the P-site codon, in mRNA coordinates.
  final double ribosome;
  final double mrnaY;
  final double cx;

  static const double p = TranslationPainter.pitch;

  /// x of base [i]'s centre: the P site's middle base sits at the centre.
  double xOf(num i) => cx + (i - (ribosome + 1)) * p;

  /// Which base (fractional) sits at canvas x [x].
  double baseAt(double x) => ribosome + 1 + (x - cx) / p;

  /// The centre of site [site]: 0 for E, 1 for P, 2 for A.
  double siteCentre(int site) => cx + (site - 1) * 3 * p;

  double get siteLabelY => mrnaY + TranslationPainter.tile / 2 + 18;

  Rect get smallSubunit => Rect.fromLTRB(
    siteCentre(0) - 3 * p,
    mrnaY - TranslationPainter.tile / 2 - 4,
    siteCentre(2) + 3 * p,
    mrnaY + TranslationPainter.tile / 2 + 34,
  );

  /// The top of every tRNA's acceptor end: the peptidyl transferase centre
  /// sits there, between P and A.
  double get _acceptorY =>
      mrnaY -
      TranslationPainter.tile / 2 -
      3 -
      _Trna.loopHeight -
      _Trna.stemHeight -
      TranslationPainter.residueRadius;

  Offset get ptc => Offset(cx + 1.5 * p, _acceptorY);

  /// The large subunit: over the three sites, reaching down to the middle of
  /// the tRNAs' stems, the tunnel running up through it.
  RRect get largeSubunit => RRect.fromRectAndCorners(
    Rect.fromLTRB(
      siteCentre(0) - 2.5 * p,
      _acceptorY - 190,
      siteCentre(2) + 2.8 * p,
      mrnaY - TranslationPainter.tile / 2 - 44,
    ),
    topLeft: const Radius.circular(64),
    topRight: const Radius.circular(40),
    bottomLeft: const Radius.circular(16),
    bottomRight: const Radius.circular(16),
  );

  Offset get tunnelExit => Offset(ptc.dx + 22, largeSubunit.top + 10);

  /// How far the large subunit is lifted off, while joining or parting.
  double lift(TranslationState s) => (1 - s.largeSubunit) * 60;

  /// Residues at full size before the tunnel starts packing them.
  static const double loose = 2;
  static const double looseStep = 16;

  /// Residue [depth] inside the tunnel: the newest two at a residue's own
  /// spacing, the rest packed so that all 35 fit.
  Offset inTunnel(double depth) {
    final double length = (tunnelExit - ptc).distance;
    final double packed =
        (length - loose * looseStep) /
        (TranslationTimeline.tunnelCapacity - loose);
    final double along = depth <= loose
        ? depth * looseStep
        : loose * looseStep + (depth - loose) * packed;
    return Offset.lerp(ptc, tunnelExit, (along / length).clamp(0.0, 1.0))!;
  }

  /// The spacing of residues out of the tunnel.
  static const double step = 17;

  /// The trailing chain's path: out of the tunnel's mouth, along the top and
  /// down the right edge, stopping short of the mRNA so the chain never lies
  /// over a base. What does not fit is counted.
  late final List<Offset> _trail = <Offset>[
    tunnelExit,
    tunnelExit.translate(0, -26),
    Offset(size.width - 18, tunnelExit.dy - 26),
    Offset(size.width - 18, mrnaY - TranslationPainter.tile - 24),
  ];

  /// How many residues the trailing path holds.
  int get trailCapacity {
    double length = 0;
    for (int i = 1; i < _trail.length; i++) {
      length += (_trail[i] - _trail[i - 1]).distance;
    }
    return length ~/ step;
  }

  /// [past] residues beyond the tunnel's exit, along the trailing path.
  Offset trail(double past) {
    double remaining = past * step;
    for (int i = 1; i < _trail.length; i++) {
      final Offset from = _trail[i - 1];
      final Offset to = _trail[i];
      final double length = (to - from).distance;
      if (remaining <= length) {
        return Offset.lerp(from, to, length == 0 ? 0 : remaining / length)!;
      }
      remaining -= length;
    }
    return _trail.last;
  }
}
