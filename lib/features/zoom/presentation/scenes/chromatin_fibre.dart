import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/helix/helix_geometry.dart';
import '../../domain/chromatin_layout.dart';
import '../zoom_inks.dart';
import 'chromatin_beads.dart';
import 'gene_strand.dart';
import 'nucleosome_art.dart';

/// A gene's DNA as chromatin, drawn the same from the gene's stop down to
/// its first bases: a line along the fibre, and on it the nucleosomes
/// [ChromatinBeads] picks, each a histone core with its DNA wound round it
/// ([ChromatinLayout.coilAt]), never smaller than [ChromatinBeads.least]:
/// larger than life where the gene is far, its own size close in.
///
/// The gene's scene draws it on the step that reaches the gene and the
/// DNA's from the gene's stop on, so the stop is one picture from either
/// side. Where a nucleosome is drawn, its DNA leaves the line to wind round
/// its core and comes back to it, and the line is not drawn between: a
/// nucleosome coming up takes over the line there as it does, so the DNA
/// is never drawn twice. As the fibre packs, the line between the cores is
/// drawn in.
abstract final class ChromatinFibre {
  static const ChromatinLayout _layout = ChromatinLayout();

  /// How many stretches a nucleosome's DNA is laid in at the least, and at
  /// the most where its strands do not show.
  static const int _samples = 12;
  static const int _most = 160;

  /// How much wider than the DNA the ground is laid under it where it
  /// crosses a core, in pixels.
  static const double casing = 1.2;

  /// How much larger than life a nucleosome is drawn, where a base pair's
  /// length is [perBase] pixels: its core no smaller than
  /// [ChromatinBeads.least] across from its middle, or [grown] of that where
  /// there is not yet room for it.
  static double magnified(double perBase, [double grown = 1]) => math.max(
    1,
    ChromatinBeads.least * grown / (NucleosomeArt.radius * perBase),
  );

  /// Draws the DNA on the line at [mid], on a canvas [width] wide: the place
  /// [along] base pairs' lengths along the fibre from the gene's 5′ end at
  /// screen x [x] (a base pair's length [perBase] pixels), [packed] of the
  /// way packed, [thick] pixels thick with [twist] of its strands showing.
  /// [colourAt] is the DNA's colour at a point, in base pairs from the
  /// gene's 5′ end, changing only at [marks]; [shownOf] how much of a
  /// nucleosome shows, by its index, none below [depth] looked at; [grown]
  /// how far grown to its least size each is ([magnified]).
  static void paint(
    Canvas canvas,
    ZoomInks inks, {
    required double Function(double along) x,
    required double perBase,
    required double mid,
    required double width,
    required double packed,
    required double thick,
    required double twist,
    required List<double> marks,
    required Color Function(double offset) colourAt,
    required int depth,
    required double Function(int index) shownOf,
    double grown = 1,
  }) {
    final double m = magnified(perBase, grown);
    final double scale = m * perBase;
    final double reach = ChromatinLayout.reach * m;
    final double origin = x(0);
    double alongOf(double screenX) => (screenX - origin) / perBase;
    final double lineFrom = _layout.offsetAt(alongOf(-thick - 8), packed);
    final double lineTo = _layout.offsetAt(alongOf(width + thick + 8), packed);

    // The nucleosomes drawn: each one's core along the fibre, where its DNA
    // leaves the line and comes back to it, in base pairs, and how much of
    // it shows.
    final List<(double, double, double, double)> beads =
        <(double, double, double, double)>[];
    for (final int index in ChromatinBeads.within(
      _layout.offsetAt(alongOf(0) - reach, packed) - ChromatinLayout.wrapped,
      _layout.offsetAt(alongOf(width) + reach, packed) + ChromatinLayout.wrapped,
      depth,
    )) {
      final double shown = shownOf(index);
      if (shown <= 0.002) {
        continue;
      }
      final double core = _layout.coreAt(ChromatinBeads.startOf(index), packed);
      final double left = x(core - reach);
      final double right = x(core + reach);
      if (right < -thick || left > width + thick) {
        continue;
      }
      beads.add((
        core,
        _layout.offsetAt(core - reach, packed),
        _layout.offsetAt(core + reach, packed),
        shown,
      ));
    }

    // The line: straight along the fibre, broken at each change of colour,
    // where the fibre's packing bends its scale, and where a nucleosome takes
    // it over, there drawn at what the nucleosome leaves of it. It runs half
    // a pixel on under the nucleosome's DNA, so the two meet with no seam.
    final double overlap = 0.5 / perBase;
    final List<double> cuts = <double>[
      lineFrom,
      lineTo,
      for (final double mark in marks)
        if (mark > lineFrom && mark < lineTo) mark,
      for (final (double _, double a, double b, double _) in beads) ...<double>[
        if (a + overlap > lineFrom && a + overlap < lineTo) a + overlap,
        if (b - overlap > lineFrom && b - overlap < lineTo) b - overlap,
      ],
      if (packed > 0)
        for (final (double start, double end) in _layout.nucleosomesWithin(
          lineFrom,
          lineTo,
        )) ...<double>[
          if (start > lineFrom && start < lineTo) start,
          if (end > lineFrom && end < lineTo) end,
        ],
    ]..sort();
    final _Strokes line = _Strokes();
    for (int i = 0; i + 1 < cuts.length; i++) {
      final double a = cuts[i];
      final double b = cuts[i + 1];
      if (b - a < 1e-9) {
        continue;
      }
      final double middle = (a + b) / 2;
      double left = 1;
      for (final (double _, double from, double to, double shown) in beads) {
        if (middle > from + overlap && middle < to - overlap) {
          left = 1 - shown;
          break;
        }
      }
      if (left <= 0.002) {
        continue;
      }
      final Color colour = colourAt(middle);
      if (colour.a <= 0.002) {
        continue;
      }
      line.add(
        colour.withValues(alpha: colour.a * left),
        Offset(x(_layout.axisAt(a, packed)), mid),
        Offset(x(_layout.axisAt(b, packed)), mid),
        a,
        b,
      );
    }
    line.paint(canvas, inks, thick, twist);

    // The nucleosomes, those that show as much together on one layer: as
    // they come up with the gene, or a depth of them at a time.
    final double turnsRadius = ChromatinLayout.radius * scale;
    final double around = 1.6 * turnsRadius + thick;
    final List<(double, double, double, double)> left = beads.toList();
    while (left.isNotEmpty) {
      final double shown = left.first.$4;
      final List<(double, double, double, double)> together =
          <(double, double, double, double)>[
            for (final (double, double, double, double) bead in left)
              if (bead.$4 == shown) bead,
          ];
      left.removeWhere(
        ((double, double, double, double) bead) => bead.$4 == shown,
      );
      final bool fading = shown < 0.995;
      if (fading) {
        final double xs = x(together.first.$1);
        final double xe = x(together.last.$1);
        canvas.saveLayer(
          Rect.fromLTRB(
            math.min(xs, xe) - around,
            mid - around,
            math.max(xs, xe) + around,
            mid + around,
          ),
          Paint()..color = Color.fromRGBO(0, 0, 0, shown),
        );
      }
      for (final (double core, double from, double to, double _) in together) {
        _nucleosome(
          canvas,
          inks,
          centre: Offset(x(core), mid),
          scale: scale,
          from: from,
          to: to,
          perBase: perBase,
          thick: thick,
          twist: twist,
          colourAt: colourAt,
        );
      }
      if (fading) {
        canvas.restore();
      }
    }
  }

  /// Draws one nucleosome about [centre], a base pair's length [scale]
  /// pixels round its core: the DNA behind the core, the core, the DNA in
  /// front, its DNA the genome's [from] to [to] base pairs.
  static void _nucleosome(
    Canvas canvas,
    ZoomInks inks, {
    required Offset centre,
    required double scale,
    required double from,
    required double to,
    required double perBase,
    required double thick,
    required double twist,
    required Color Function(double offset) colourAt,
  }) {
    final _Strokes behind = _Strokes();
    final _Strokes inFront = _Strokes();
    Offset screen(FibrePoint p) =>
        centre + Offset(p.along * scale, p.across * scale);
    // About two pixels a stretch of its way round, and fine enough to
    // follow its strands where they show.
    int samples = (_length * scale / 2).round().clamp(_samples, _most);
    if (twist > 0) {
      samples = math.max(samples, ((to - from) * perBase / 1.2).ceil());
    }
    FibrePoint last = ChromatinLayout.coilAt(0);
    for (int i = 0; i < samples; i++) {
      final double u = (i + 1) / samples;
      final FibrePoint p = ChromatinLayout.coilAt(u);
      final double a = from + (to - from) * i / samples;
      final double b = from + (to - from) * u;
      final Color colour = colourAt((a + b) / 2);
      if (colour.a > 0.002) {
        final FibrePoint half = ChromatinLayout.coilAt((i + 0.5) / samples);
        (half.depth < 0 ? behind : inFront).add(
          colour,
          screen(last),
          screen(p),
          a,
          b,
        );
      }
      last = p;
    }
    // The core fills its DNA's turns, as thick as the DNA is drawn.
    final double turnsRadius = ChromatinLayout.radius * scale;
    final double coreRadius = math.max(
      turnsRadius - thick / 2,
      0.6 * turnsRadius,
    );
    behind.paint(canvas, inks, thick, twist, shaded: true);
    NucleosomeArt.paint(canvas, centre, coreRadius, inks);
    // Edged in the ground where it crosses the core, so it reads on it.
    inFront.paint(canvas, inks, thick, twist, casing: casing);
  }

  /// How long a nucleosome's DNA is from where it leaves the line to where
  /// it comes back, in base pairs' lengths, near enough.
  static const double _length = 160;
}

/// The DNA's strokes by colour, laid as it runs: a run of one colour is one
/// stroke, so the DNA turns without seams; and its two strands, where it is
/// thick enough to show them, by which side of the duplex they are on.
/// Colours are told apart as they are drawn, to the 8 bits of a pixel, so
/// two that differ by a rounding are one stroke.
final class _Strokes {
  final Map<int, Path> _body = <int, Path>{};
  final Map<int, Color> _inks = <int, Color>{};
  final Map<int, Offset> _ends = <int, Offset>{};

  /// Each stretch laid: its colour, its ends on screen and in base pairs.
  final List<(int, Offset, Offset, double, double)> _laid =
      <(int, Offset, Offset, double, double)>[];

  void add(Color colour, Offset a, Offset b, double from, double to) {
    final int key = colour.toARGB32();
    _inks.putIfAbsent(key, () => colour);
    final Path path = _body[key] ??= Path();
    final Offset? end = _ends[key];
    if (end == null || (end - a).distanceSquared > 0.01) {
      path.moveTo(a.dx, a.dy);
    }
    path.lineTo(b.dx, b.dy);
    _ends[key] = b;
    _laid.add((key, a, b, from, to));
  }

  /// Draws the DNA [thick] pixels thick, its strands showing [twist] of the
  /// way; in shade behind a core; [alpha] of it; on a [casing] of the
  /// ground that much wider.
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double thick,
    double twist, {
    bool shaded = false,
    double alpha = 1,
    double casing = 0,
  }) {
    Color shade(Color c, double by) =>
        Color.lerp(c, inks.ground, by)!.withValues(alpha: c.a * alpha);
    if (casing > 0) {
      for (final MapEntry<int, Path> body in _body.entries) {
        canvas.drawPath(
          body.value,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thick + casing
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round
            ..color = inks.ground.withValues(
              alpha: 0.8 * _inks[body.key]!.a * alpha,
            ),
        );
      }
    }
    for (final MapEntry<int, Path> body in _body.entries) {
      // A tube, giving way to its strands as they come up, as the helix
      // is its strands and its bases alone.
      final Color colour = shade(_inks[body.key]!, shaded ? 0.4 : 0);
      if (twist < 1) {
        GeneStrand.tube(
          canvas,
          body.value,
          colour.withValues(alpha: colour.a * (1 - twist)),
          thick,
          inks,
        );
      }
    }
    if (twist <= 0) {
      return;
    }
    // Its two strands, a turn every 10.5 base pairs, 127° apart across the
    // minor groove, as the helix's are: each stretch's points offset across
    // the DNA by where its strands are in their turn.
    // As thin as the helix's backbones are drawn where it is this small.
    final double strand = math.max(1.4, 0.016 * thick);
    final double out = thick / 2 - strand / 2;
    final Map<int, Path> back = <int, Path>{};
    final Map<int, Path> front = <int, Path>{};
    // Each strand one stroke for as long as it stays on one side and in one
    // colour: translucent strokes joined end to end would double where they
    // meet.
    for (final double groove in <double>[0, HelixModel.grooveOffset]) {
      Offset? last;
      Path? open;
      bool? side;
      int? ink;
      Offset? stretchEnd;
      for (final (int colour, Offset a, Offset b, double from, double to)
          in _laid) {
        final Offset along = b - a;
        final double length = along.distance;
        if (length < 1e-6) {
          continue;
        }
        if (stretchEnd == null ||
            (stretchEnd - a).distanceSquared > 0.01 ||
            ink != colour) {
          last = null;
          open = null;
        }
        stretchEnd = b;
        ink = colour;
        final Offset across = Offset(-along.dy, along.dx) / length;
        final int steps = math.max(1, (length / 2).ceil());
        for (int k = 0; k <= steps; k++) {
          final double t = k / steps;
          final double offset = from + (to - from) * t;
          final double angle =
              2 * math.pi * offset / HelixModel.basePairsPerTurn + groove;
          final Offset p = a + along * t + across * (out * math.cos(angle));
          final bool isFront = math.sin(angle) >= 0;
          if (last == null) {
            last = p;
            side = isFront;
            continue;
          }
          if (open == null || side != isFront) {
            // A new stroke: at the start, or over the edge of the duplex,
            // where the strand passes to its other side.
            open = (isFront ? front : back)[colour] ??= Path();
            open.moveTo(last.dx, last.dy);
            side = isFront;
          }
          open.lineTo(p.dx, p.dy);
          last = p;
        }
      }
    }
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strand
      ..strokeCap = StrokeCap.round;
    // In the DNA's own colour at full strength, as the helix's backbones
    // are; the far strand in shade, as the helix shades its own by depth.
    double strength(Color c) => c.a * twist;
    for (final MapEntry<int, Path> s in back.entries) {
      final Color colour = _inks[s.key]!;
      canvas.drawPath(
        s.value,
        paint
          ..color = shade(
            colour,
            shaded ? 0.7 : 0.45,
          ).withValues(alpha: strength(colour) * (shaded ? 0.7 : 1) * alpha),
      );
    }
    for (final MapEntry<int, Path> s in front.entries) {
      final Color colour = _inks[s.key]!;
      canvas.drawPath(
        s.value,
        paint
          ..color = shade(
            colour,
            shaded ? 0.35 : 0,
          ).withValues(alpha: strength(colour) * alpha),
      );
    }
  }
}
