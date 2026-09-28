import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/biology/amino_acids.dart';
import '../../core/theme/anatomy_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/nucleotide_colors.dart';
import '../anatomy/anatomy_motion.dart';
import '../format.dart';
import 'molecular_material.dart';
import 'translation_timeline.dart';

part 'translation_geometry.dart';
part 'translation_molecules.dart';

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

/// An illustrative cutaway of the human translation machinery. Surface
/// lobes suggest the rRNA/protein envelope; they are not atomic coordinates.
/// Geometry and motion come from the same state for playback and chain flight.
class TranslationPainter extends CustomPainter {
  TranslationPainter({
    required this.timeline,
    required this.at,
    required this.inks,
    super.repaint,
    this.trailing = 48,
  });

  final TranslationTimeline timeline;
  final double Function() at;
  final TranslationInks inks;
  final int trailing;

  static const double pitch = 21;
  static const double tile = 20;
  static const double utrTile = 0.2;
  static const double utrInk = 0.67;
  static const double residueRadius = 8;
  static const double beadRadius = 2.8;

  /// Playback and the flight use the same apparent residue size on small
  /// viewports, so a sphere does not jump in size at the handoff.
  static double viewportScale(Size size) => size.isEmpty
      ? 1
      : math.min(1.0, math.min(size.width / 340, size.height / 420));

  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Map<(String, int, int), ui.Paragraph> _glyphs =
      <(String, int, int), ui.Paragraph>{};
  late final Float32List _beads = Float32List(
    2 * (TranslationTimeline.tunnelCapacity + trailing + 3),
  );
  late final _MolecularShell _large = _MolecularShell(
    large: true,
    color: Color.lerp(
      inks.anatomy.aminoPolar,
      inks.nucleotides.cytosine,
      0.42,
    )!,
    ground: inks.background,
  );
  late final _MolecularShell _small = _MolecularShell(
    large: false,
    color: Color.lerp(
      inks.anatomy.aminoPositive,
      inks.anatomy.aminoSpecial,
      0.3,
    )!,
    ground: inks.background,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final TranslationState s = timeline.stateAt(at());
    final _Frame f = _Frame(size, s);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(f.origin.dx, f.origin.dy);
    canvas.scale(f.scale);
    _drawSubunits(canvas, f, s);
    _drawMrna(canvas, f);
    _drawJunctions(canvas, f, s);
    _drawTrna(canvas, f, s, s.e);
    _drawTrna(canvas, f, s, s.p);
    _drawTrna(canvas, f, s, s.a);
    _drawReleaseFactor(canvas, f, s);
    _drawChain(canvas, f, s);
    _drawLabels(canvas, f, s);
    canvas.restore();
  }

  void _drawSubunits(Canvas canvas, _Frame f, TranslationState s) {
    if (s.largeSubunit > 0) {
      _large.draw(
        canvas,
        f.largeSubunit.shift(Offset(0, -f.lift)),
        s.largeSubunit,
      );
      // The narrow channel remains visible through the cut face. It leads
      // from the catalytic centre to the large subunit's exterior.
      final Path tunnel = f.tunnelPath.shift(Offset(0, -f.lift));
      _line
        ..shader = null
        ..color = inks.background.withValues(alpha: 0.82 * s.largeSubunit)
        ..strokeWidth = 15;
      canvas.drawPath(tunnel, _line);
      _line
        ..color = inks.anatomy.aminoPolar.withValues(
          alpha: 0.14 * s.largeSubunit,
        )
        ..strokeWidth = 1;
      canvas.drawOval(
        Rect.fromCenter(
          center: f.tunnelExit.translate(0, -f.lift),
          width: 20,
          height: 9,
        ),
        _line,
      );
    }
    if (s.smallSubunit > 0) {
      _small.draw(
        canvas,
        f.smallSubunit.shift(Offset(0, (1 - s.smallSubunit) * 40)),
        s.smallSubunit,
      );
    }
  }

  void _drawMrna(Canvas canvas, _Frame f) {
    // A continuous sugar-phosphate backbone with a gentle bend outside the
    // decoding groove; the three codons in the groove stay aligned.
    final Path backbone = Path();
    for (double x = 0; x <= f.width + 4; x += 4) {
      final double y = f.baseY(x) + 12;
      if (x == 0) {
        backbone.moveTo(x, y);
      } else {
        backbone.lineTo(x, y);
      }
    }
    _line
      ..shader = null
      ..strokeWidth = 3
      ..color = Color.lerp(inks.nucleotides.cytosine, inks.background, 0.48)!;
    canvas.drawPath(backbone, _line);
    final int first = math.max(0, f.baseAt(0).floor() - 1);
    final int last = math.min(
      timeline.mrna.length - 1,
      f.baseAt(f.width).ceil() + 1,
    );
    for (int i = first; i <= last; i++) {
      final String base = rnaLetter(timeline.mrna[i]);
      final bool translated =
          i >= timeline.cdsStart && i < timeline.stopCodonStart + 3;
      final bool start = i >= timeline.cdsStart && i < timeline.cdsStart + 3;
      final bool stop =
          i >= timeline.stopCodonStart && i < timeline.stopCodonStart + 3;
      final double x = f.xOf(i);
      final Rect box = Rect.fromCenter(
        center: Offset(x, f.baseY(x)),
        width: tile,
        height: tile,
      );
      _fill
        ..shader = null
        ..color = start
            ? inks.anatomy.roleStartCodon
            : stop
            ? inks.anatomy.roleStopCodon
            : Color.lerp(
                inks.background,
                inks.anatomy.baseTile,
                translated ? 1 : utrTile,
              )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        _fill,
      );
      final Color color = start || stop
          ? inks.ink
          : Color.lerp(
              inks.background,
              inks.nucleotides.forBase(base),
              translated ? 1 : utrInk,
            )!;
      _letter(canvas, base, color, box.center, 12);
    }
  }

  void _drawJunctions(Canvas canvas, _Frame f, TranslationState s) {
    for (final int junction in timeline.junctions) {
      final double x = f.xOf(junction) - pitch / 2;
      if (x < -pitch || x > f.width + pitch) continue;
      final double alpha = 1 - (s.ribosome - junction + 3).clamp(0.0, 3.0) / 3;
      if (alpha <= 0) continue;
      _fill
        ..shader = null
        ..color = inks.anatomy.roleExon.withValues(alpha: alpha);
      canvas.drawPath(
        Path()
          ..moveTo(x, f.baseY(x) - 25)
          ..lineTo(x + 4, f.baseY(x) - 19)
          ..lineTo(x, f.baseY(x) - 13)
          ..lineTo(x - 4, f.baseY(x) - 19)
          ..close(),
        _fill,
      );
    }
  }

  static TrnaSlot? _holder(TranslationState s) {
    for (final TrnaSlot? slot in <TrnaSlot?>[s.p, s.a]) {
      if (slot != null && slot.charged && slot.codon == s.residues) return slot;
    }
    return null;
  }

  void _drawTrna(Canvas canvas, _Frame f, TranslationState s, TrnaSlot? slot) {
    if (slot == null || slot.presence <= 0) return;
    final int codonStart = timeline.cdsStart + 3 * (slot.codon - 1);
    final _Trna shape = f.trna(slot);
    final double alpha = slot.presence;
    final bool scanning = s.phase == TranslationPhase.scanning;
    final Color color = Color.lerp(
      inks.anatomy.aminoPositive,
      inks.anatomy.aminoPolar,
      ((shape.centre - f.cx) / (3 * pitch) * 0.25 + 0.5).clamp(0.0, 1.0),
    )!;
    _drawFoldedRna(canvas, shape, color, alpha);

    // Anticodon (3′ → 5′ here) faces the mRNA (5′ → 3′). Only the
    // accommodated tRNA gets contact light, never the scanning initiator.
    final double paired = scanning ? 0 : ((alpha - 0.8) / 0.2).clamp(0.0, 1.0);
    for (int i = 0; i < 3; i++) {
      final double x = shape.centre + (i - 1) * pitch;
      final String base = anticodonBase(timeline.mrna[codonStart + i]);
      if (paired > 0) {
        canvas.save();
        canvas.translate(x, shape.bottom + 5);
        canvas.scale(1, 0.56);
        _fill
          ..color = Colors.white
          ..shader = ui.Gradient.radial(
            Offset.zero,
            9,
            <Color>[
              Colors.white.withValues(alpha: 0.62 * paired),
              Colors.white.withValues(alpha: 0.18 * paired),
              Colors.white.withValues(alpha: 0),
            ],
            const <double>[0, 0.3, 1],
          );
        canvas.drawCircle(Offset.zero, 9, _fill);
        _fill.shader = null;
        canvas.restore();
      }
      _letter(
        canvas,
        base,
        Color.lerp(
          inks.nucleotides.forBase(base),
          inks.ink,
          0.24,
        )!.withValues(alpha: alpha),
        Offset(x, shape.bottom - 5),
        11,
      );
    }
    if (!slot.charged || slot.codon > timeline.protein.length) return;
    if (identical(slot, _holder(s))) {
      // A short ester linkage at the 3′ acceptor tip, kept attached while
      // the chain transfers toward the incoming amino acid.
      final Offset attached = f.chainAt(s.chainShift);
      _line
        ..shader = null
        ..color = color.withValues(
          alpha:
              alpha *
              (1 -
                  (s.phase == TranslationPhase.peptideBond ? s.chainShift : 0)),
        )
        ..strokeWidth = 2.2;
      canvas.drawLine(shape.acceptor, attached, _line);
    } else if (slot.codon > s.residues) {
      _residue(
        canvas,
        shape.acceptor,
        residueRadius,
        timeline.protein[slot.codon - 1],
        alpha,
      );
    }
  }

  void _drawFoldedRna(Canvas canvas, _Trna t, Color color, double alpha) {
    // Paired helical stems meet at an elbow. The folded D/T loops are
    // suggested by two curls; this is the tertiary L, not a cloverleaf icon.
    final Path envelope = Path()
      ..moveTo(t.centre - 17, t.bottom - 15)
      ..quadraticBezierTo(
        t.centre - 32,
        t.bottom - 52,
        t.elbow.dx - 13,
        t.elbow.dy,
      )
      ..quadraticBezierTo(
        t.elbow.dx - 22,
        t.elbow.dy - 30,
        t.elbow.dx + 2,
        t.elbow.dy - 24,
      )
      ..quadraticBezierTo(
        t.elbow.dx + 17,
        t.elbow.dy - 37,
        t.acceptor.dx,
        t.acceptor.dy - 1,
      )
      ..quadraticBezierTo(
        t.elbow.dx + 25,
        t.elbow.dy + 2,
        t.elbow.dx + 11,
        t.elbow.dy + 13,
      )
      ..quadraticBezierTo(
        t.centre + 23,
        t.bottom - 46,
        t.centre + 17,
        t.bottom - 15,
      )
      ..close();
    _fill.color = Colors.white;
    _fill.shader = ui.Gradient.linear(
      Offset(t.centre - 25, t.bottom - 105),
      Offset(t.centre + 20, t.bottom),
      <Color>[
        color.withValues(alpha: 0.26 * alpha),
        color.withValues(alpha: 0.08 * alpha),
      ],
    );
    canvas.drawPath(envelope, _fill);
    _fill.shader = null;

    final Offset bottom = Offset(t.centre, t.bottom - 19);
    final List<Offset> centres = <Offset>[
      for (int i = 0; i <= 24; i++)
        if (i <= 15)
          Offset.lerp(bottom, t.elbow, i / 15)!
        else
          Offset.lerp(t.elbow, t.acceptor.translate(-2, 6), (i - 15) / 9)!,
    ];
    final List<List<Offset>> strands = <List<Offset>>[<Offset>[], <Offset>[]];
    for (int i = 0; i < centres.length; i++) {
      final Offset tangent =
          centres[math.min(i + 1, centres.length - 1)] -
          centres[math.max(i - 1, 0)];
      final double length = math.max(1, tangent.distance);
      final Offset normal = Offset(-tangent.dy / length, tangent.dx / length);
      final double wave = math.sin(i * 0.92) * 5.5;
      final Offset a = centres[i] + normal * wave;
      final Offset b = centres[i] - normal * wave;
      strands[0].add(a);
      strands[1].add(b);
      if (i.isEven) {
        _line
          ..shader = null
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.52 * alpha);
        canvas.drawLine(a, b, _line);
      }
    }
    for (final List<Offset> strand in strands) {
      final Path ribbon = Path()..moveTo(strand.first.dx, strand.first.dy);
      for (int i = 1; i < strand.length - 1; i++) {
        final Offset end = (strand[i] + strand[i + 1]) / 2;
        ribbon.quadraticBezierTo(strand[i].dx, strand[i].dy, end.dx, end.dy);
      }
      ribbon.lineTo(strand.last.dx, strand.last.dy);
      _tube(canvas, ribbon, color, alpha, 4.2);
    }
    for (final double sign in <double>[-1, 1]) {
      final Path loop = Path()
        ..moveTo(t.elbow.dx, t.elbow.dy + 7)
        ..cubicTo(
          t.elbow.dx + sign * 17,
          t.elbow.dy + 4,
          t.elbow.dx + sign * 15,
          t.elbow.dy - 20,
          t.elbow.dx + sign * 8,
          t.elbow.dy - 20,
        )
        ..quadraticBezierTo(
          t.elbow.dx - sign * 4,
          t.elbow.dy - 6,
          t.elbow.dx + 7,
          t.elbow.dy - 2,
        );
      _tube(canvas, loop, color, alpha * 0.85, 3.5);
    }
    final Path anticodon = Path()
      ..moveTo(t.centre - 8, t.bottom - 28)
      ..cubicTo(
        t.centre - 36,
        t.bottom - 28,
        t.centre - 33,
        t.bottom - 15,
        t.centre - 21,
        t.bottom - 14,
      )
      ..quadraticBezierTo(t.centre, t.bottom - 10, t.centre + 21, t.bottom - 14)
      ..cubicTo(
        t.centre + 33,
        t.bottom - 15,
        t.centre + 31,
        t.bottom - 28,
        t.centre + 8,
        t.bottom - 28,
      );
    _tube(canvas, anticodon, color, alpha, 3.2);
    _tube(
      canvas,
      Path()
        ..moveTo(t.acceptor.dx - 2, t.acceptor.dy + 7)
        ..lineTo(t.acceptor.dx, t.acceptor.dy),
      color,
      alpha,
      2.5,
    );
  }

  void _tube(
    Canvas canvas,
    Path path,
    Color color,
    double alpha,
    double width,
  ) {
    _line
      ..shader = null
      ..strokeWidth = width + 2
      ..color = inks.background.withValues(alpha: 0.6 * alpha);
    canvas.drawPath(path, _line);
    _line
      ..strokeWidth = width
      ..color = color.withValues(alpha: alpha);
    canvas.drawPath(path, _line);
    _line
      ..strokeWidth = 1
      ..color = Color.lerp(
        color,
        Colors.white,
        0.55,
      )!.withValues(alpha: 0.65 * alpha);
    canvas.drawPath(path.shift(const Offset(-0.6, -0.7)), _line);
  }

  void _drawReleaseFactor(Canvas canvas, _Frame f, TranslationState s) {
    if (s.releaseFactor <= 0) return;
    final double alpha = s.releaseFactor;
    final double x = f.siteCentre(2) + (1 - alpha) * 35;
    final double y = f.mrnaY - 26 - (1 - alpha) * 65;
    final Color color = Color.lerp(
      inks.anatomy.roleStopCodon,
      inks.anatomy.aminoNegative,
      0.65,
    )!;
    final Path fold = Path()
      ..moveTo(x - 10, y)
      ..cubicTo(x - 32, y - 12, x + 9, y - 28, x - 11, y - 48)
      ..cubicTo(x - 31, y - 69, x - 6, y - 90, f.ptc.dx + 5, f.ptc.dy + 8);
    _tube(canvas, fold, color, alpha, 12);
    for (int i = 0; i < 6; i++) {
      final Offset c = Offset(x + math.sin(i * 2.2) * 7, y - i * 10);
      _sphere(canvas, c, 8 + (i % 2) * 2, color, alpha);
    }
    _letter(
      canvas,
      'RF',
      inks.ink.withValues(alpha: alpha),
      Offset(x, y - 20),
      10,
    );
  }

  void _drawChain(Canvas canvas, _Frame f, TranslationState s) {
    if (s.residues == 0) return;
    final int shown = f.shownPast(trailing);
    int drawn = 0;
    int hidden = 0;
    for (int r = s.residues - 1; r >= 0; r--) {
      final double depth = s.depthOf(r);
      if (depth > TranslationTimeline.tunnelCapacity + shown) {
        hidden = r + 1;
        break;
      }
      final Offset point = f.chainAt(depth);
      _beads[2 * drawn] = point.dx;
      _beads[2 * drawn + 1] = point.dy;
      drawn++;
    }
    _line
      ..shader = null
      ..color = inks.ink.withValues(alpha: 0.3)
      ..strokeWidth = 2.4;
    for (int i = 1; i < drawn; i++) {
      canvas.drawLine(
        Offset(_beads[2 * i - 2], _beads[2 * i - 1]),
        Offset(_beads[2 * i], _beads[2 * i + 1]),
        _line,
      );
    }
    for (int i = drawn - 1; i >= 0; i--) {
      final int r = s.residues - 1 - i;
      _residue(
        canvas,
        Offset(_beads[2 * i], _beads[2 * i + 1]),
        radiusAt(s.depthOf(r)),
        timeline.protein[r],
        1,
      );
    }
    if (hidden > 0) {
      final Offset end = f.trail(shown.toDouble());
      _letter(
        canvas,
        '+${grouped(hidden)}',
        inks.quiet,
        end.translate(0, -20),
        10,
      );
    }
  }

  void _drawLabels(Canvas canvas, _Frame f, TranslationState s) {
    final Color quiet = inks.quiet.withValues(alpha: 0.8);
    _letter(canvas, '5′', quiet, Offset(15, f.mrnaY + 37), 10);
    _letter(canvas, '3′', quiet, Offset(f.width - 15, f.mrnaY + 37), 10);
    _label(canvas, 'mRNA', quiet, Offset(f.cx, f.mrnaY + 80), 10);
    if (s.largeSubunit > 0.5) {
      for (int site = 0; site < 3; site++) {
        final bool active =
            site == 2 &&
            (s.phase == TranslationPhase.decoding ||
                s.phase == TranslationPhase.releaseFactor);
        _letter(
          canvas,
          const <String>['E', 'P', 'A'][site],
          (active ? inks.ink : inks.quiet).withValues(alpha: s.largeSubunit),
          Offset(f.siteCentre(site), f.mrnaY + 33),
          11,
        );
      }
      _label(
        canvas,
        '60S',
        inks.quiet.withValues(alpha: s.largeSubunit * 0.8),
        Offset(f.largeSubunit.right - 19, f.largeSubunit.top + 23 - f.lift),
        9,
      );
    }
    if (s.smallSubunit > 0.5) {
      _label(
        canvas,
        '40S',
        inks.quiet.withValues(alpha: s.smallSubunit * 0.8),
        Offset(f.smallSubunit.right - 24, f.mrnaY + 60),
        9,
      );
    }
    if (s.phase == TranslationPhase.scanning) {
      _label(
        canvas,
        'Initiator tRNA',
        quiet,
        Offset(f.cx + 5, f.mrnaY - 169),
        11,
      );
    } else if (s.residues > TranslationTimeline.tunnelCapacity) {
      _label(canvas, 'Growing peptide', quiet, Offset(f.cx, 16), 11);
    }
  }

  static List<Offset?> chainPositions(
    Size size,
    TranslationState s, {
    int trailing = 48,
  }) {
    if (size.isEmpty) return List<Offset?>.filled(s.residues, null);
    final _Frame f = _Frame(size, s);
    final int shown = f.shownPast(trailing);
    return <Offset?>[
      for (int r = 0; r < s.residues; r++)
        if (s.depthOf(r) > TranslationTimeline.tunnelCapacity + shown)
          null
        else
          f.toScreen(f.chainAt(s.depthOf(r))),
    ];
  }

  static double radiusAt(double depth) {
    // No size pop at the tunnel mouth: beads expand over the final two
    // compressed positions as they emerge into the free chain.
    if (depth >= TranslationTimeline.tunnelCapacity - 2) {
      final double u = ((depth - TranslationTimeline.tunnelCapacity + 2) / 2)
          .clamp(0.0, 1.0);
      return beadRadius + (residueRadius - beadRadius) * u;
    }
    return residueRadius +
        (beadRadius - residueRadius) * ((depth - 1.5).clamp(0.0, 1.0));
  }

  void _sphere(
    Canvas canvas,
    Offset centre,
    double radius,
    Color color,
    double alpha,
  ) {
    final Rect bounds = Rect.fromCircle(center: centre, radius: radius);
    _fill
      ..color = Colors.white.withValues(alpha: alpha)
      ..shader = MolecularMaterial.residueShader(bounds, color);
    canvas.drawCircle(centre, radius, _fill);
    _fill.shader = null;
  }

  void _residue(
    Canvas canvas,
    Offset centre,
    double radius,
    String residue,
    double alpha,
  ) {
    _sphere(canvas, centre, radius, inks.anatomy.forResidue(residue), alpha);
    if (radius >= residueRadius - 0.5) {
      _letter(
        canvas,
        residue,
        inks.background.withValues(alpha: alpha),
        centre.translate(0, 0.5),
        radius * 1.2,
      );
    }
  }

  /// Display conversion only: stored GenBank transcript coordinates and
  /// letters remain unchanged, and no sequence length can change.
  static String rnaLetter(String base) => base == 'T' ? 'U' : base;
  static String anticodonBase(String base) => switch (base) {
    'A' => 'U',
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
  ) => _label(canvas, text, ink, centre, size, mono: true);

  void _label(
    Canvas canvas,
    String text,
    Color ink,
    Offset centre,
    double size, {
    bool mono = false,
  }) {
    // Bound the cache through alpha quantisation: arrivals do not allocate
    // a paragraph for every distinct animation tick.
    final Color quantized = ink.withValues(alpha: (ink.a * 24).round() / 24);
    final int style = (size * 2).round() * 2 + (mono ? 1 : 0);
    final ui.Paragraph paragraph = _glyphs.putIfAbsent(
      (text, quantized.toARGB32(), style),
      () {
        final ui.ParagraphBuilder builder =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textAlign: TextAlign.center,
                  fontFamily: mono
                      ? AppTypography.monoFamily
                      : AppTypography.sansFamily,
                  fontSize: size,
                ),
              )
              ..pushStyle(
                ui.TextStyle(color: quantized, fontWeight: FontWeight.w500),
              )
              ..addText(text);
        return builder.build()
          ..layout(const ui.ParagraphConstraints(width: 160));
      },
    );
    canvas.drawParagraph(
      paragraph,
      Offset(centre.dx - 80, centre.dy - paragraph.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant TranslationPainter old) =>
      old.timeline != timeline ||
      old.inks != inks ||
      old.trailing != trailing ||
      old.at() != at();

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
        'Codon ${s.codon}, ${AminoAcids.nameOf(timeline.protein[s.codon - 1])}',
    };
    return '$where. ${s.residues} of ${timeline.protein.length} residues made.';
  }
}
