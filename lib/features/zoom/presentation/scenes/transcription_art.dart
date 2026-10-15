import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/gene_layout.dart';
import '../../domain/transcription.dart';
import '../zoom_inks.dart';
import 'sculpt.dart';

/// How a gene's transcription is drawn ([Transcription]), as an electron
/// micrograph of a gene being read shows it (Miller and Beatty 1969): each
/// polymerase a small lit body on the gene's line, its RNA hanging from it,
/// longer the further it has read, so the gene wears a fringe that lengthens
/// toward its 3′ end. The RNA is in the gene's own colours (its exons' coding
/// and untranslated parts, its introns in the quiet ink), capped at its 5′
/// end in the mark. An intron being spliced loops out at its place and
/// leaves as a lariat; a finished mRNA is cut free at the 3′ end and drifts
/// away with its poly(A) tail.
///
/// Everything is laid in screen pixels about the gene's line, through the
/// scene's own mapping of a base's place, so it lies on the gene however the
/// camera has it.
final class TranscriptionArt {
  TranscriptionArt(this.reading);

  final Transcription reading;

  /// How a fibril leans from straight down toward the gene's 5′ end, as
  /// nascent RNA trails behind its polymerase.
  static const double lean = 0.22;

  /// How wide a polymerase is drawn at the gene's stop, in pixels.
  static const double polymeraseWidth = 15;

  /// How far apart the particles along an RNA are, in pixels at the gene's
  /// stop: a nascent RNA is packed with proteins as it is made, and an
  /// electron micrograph shows it beaded.
  static const double beadEvery = 7;

  /// The least room, in pixels, under the gene's line the longest RNA is
  /// given, and the share of the room under it it takes at the most.
  static const double roomShare = 0.8;

  /// How long an intron's loop must be to be drawn whole, in pixels round:
  /// shorter ones fade as they shrink, so a long gene's dozens of small
  /// introns never turn to confetti.
  static const double loopShown = 12;

  ui.Picture? _blob;
  ZoomInks? _blobInks;

  /// Builds the polymerase's picture for [inks], ahead of the first frame.
  void prepare(ZoomInks inks) => _polymerase(inks);

  /// The polymerase as a lit, lobed body, 100 units wide about its centre.
  ui.Picture _polymerase(ZoomInks inks) {
    final ui.Picture? built = _blob;
    if (built != null && _blobInks == inks) {
      return built;
    }
    built?.dispose();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    // Two jaws round the DNA and the body behind them, as RNA polymerase II
    // is drawn at this size: a bean with a cleft.
    Path shape = Path()
      ..addOval(Rect.fromCenter(center: Offset.zero, width: 92, height: 70));
    shape = Path.combine(
      PathOperation.union,
      shape,
      Path()..addOval(
        Rect.fromCenter(center: const Offset(-22, -22), width: 52, height: 44),
      ),
    );
    shape = Path.combine(
      PathOperation.union,
      shape,
      Path()..addOval(
        Rect.fromCenter(center: const Offset(24, -18), width: 48, height: 40),
      ),
    );
    final Rect box = shape.getBounds();
    Sculpt.shadowUnder(canvas, box, inks, strength: 0.5, spread: 1.05);
    // Lit warm-neutral, as the zoom's forms are, and lighter than most of
    // them: a body small on the dark ground has to read at a glance.
    canvas.drawPath(
      shape,
      Paint()
        ..shader = RadialGradient(
          center: Sculpt.highlight,
          radius: 1.05,
          colors: <Color>[
            inks.lit(0.78),
            inks.lit(0.5),
            inks.lit(0.18),
            inks.shade(0.75),
          ],
          stops: const <double>[0, 0.35, 0.75, 1],
        ).createShader(box),
    );
    Sculpt.rim(canvas, shape, box, inks, width: 5, strength: 0.7);
    // The cleft the DNA runs through.
    canvas.drawPath(
      Path()
        ..moveTo(-2, -38)
        ..quadraticBezierTo(4, -10, -2, 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = inks.shadow.withValues(alpha: 0.45),
    );
    _blob = recorder.endRecording();
    _blobInks = inks;
    return _blob!;
  }

  /// How much RNA, as a share of the gene's own scale, is drawn in a pixel:
  /// as long as the gene draws it where the longest RNA fits under the line
  /// at the gene's stop, shorter where it would not. [perBase] is pixels a
  /// base at the stop, [room] the pixels under the line there.
  double compaction(double perBase, double room) {
    final double longest = reading.longest * perBase;
    return longest <= 0 ? 1 : math.min(1, roomShare * room / longest);
  }

  Color _ink(ZoomInks inks, GenePieceKind kind) => switch (kind) {
    GenePieceKind.cds => inks.cds,
    GenePieceKind.utr => inks.utr,
    GenePieceKind.intron => inks.label.withValues(alpha: 0.7),
  };

  /// Draws the transcription [clock] seconds in. [x] is the screen x of a
  /// place on the gene, in base pairs from its 5′ end; [line] the screen y
  /// of the gene's line; [perBase] pixels a base now, [atRest] at the gene's
  /// stop; [compaction] as above.
  void paint(
    Canvas canvas,
    ZoomInks inks, {
    required double clock,
    required double Function(double offset) x,
    required double line,
    required double perBase,
    required double atRest,
    required double compaction,
  }) {
    final TranscriptionFrame now = reading.at(clock);
    final double scale = perBase / atRest;
    final double rnaPx = compaction * perBase;
    final double width = (2.2 * scale).clamp(1.1, 3.4);
    // Where the RNA is sampled and where its particles sit are fixed along
    // it, in its bases, as it is laid at the gene's stop: as the view moves
    // they ride with the RNA and none comes or goes.
    final double restPx = compaction * atRest;
    final double sampleBases = 4 / restPx;
    final double beadBases = beadEvery / restPx;
    final double bead = width * 0.85;
    final double drop = 3.5 * scale;
    final Offset down = Offset(-math.sin(lean), math.cos(lean));
    final Offset across = Offset(math.cos(lean), math.sin(lean));

    // A fibril's point [d] pixels from its root, swaying a little as a
    // thread hanging in a slow current does: a wave running down it, no
    // more than a few pixels at its far end.
    Offset along(Offset root, double d, int lane) {
      final double reach = math.min(d / 110, 1.6);
      final double sway =
          2.4 *
          scale *
          reach *
          reach *
          math.sin(clock * 1.6 + lane * 2.3 - d / (26 * math.max(scale, 0.4)));
      return root + down * d + across * sway;
    }

    final Map<Color, Path> strokes = <Color, Path>{};
    final Map<Color, List<Offset>> beaded = <Color, List<Offset>>{};
    final List<(Offset, double, double)> loops = <(Offset, double, double)>[];
    final List<(Offset, double)> caps = <(Offset, double)>[];

    // Lays [rna] (5′ to 3′) along a fibril from [root], the 3′ end at the
    // root, and gathers its strokes, its loops and its cap; [shown] as it
    // fades.
    void lay(Offset root, List<RnaStretch> rna, int lane, double shown) {
      // In bases from the root, then on screen.
      double total = 0;
      for (final RnaStretch stretch in rna) {
        total += stretch.length;
      }
      double from = 0;
      for (int i = rna.length - 1; i >= 0; i--) {
        final RnaStretch stretch = rna[i];
        final double bases = stretch.length;
        final double d = from * rnaPx;
        final double run = bases * rnaPx;
        if (run > 0.05) {
          final Color ink = _ink(inks, stretch.kind);
          final Color faded = ink.withValues(alpha: ink.a * shown);
          final Path path = strokes.putIfAbsent(faded, Path.new);
          final int pieces = math.max(1, (bases / sampleBases).ceil());
          final Offset start = along(root, d, lane);
          path.moveTo(start.dx, start.dy);
          for (int k = 1; k <= pieces; k++) {
            final Offset p = along(root, d + run * k / pieces, lane);
            path.lineTo(p.dx, p.dy);
          }
          // Its particles, at places fixed along the RNA from its 5′ end,
          // so they ride out with it as it grows.
          if (beadEvery * scale > 2.5) {
            final List<Offset> dots = beaded.putIfAbsent(
              faded,
              () => <Offset>[],
            );
            final double from5 = total - from - bases;
            final double first = (from5 / beadBases).ceil() * beadBases;
            for (double b = first; b < from5 + bases; b += beadBases) {
              dots.add(along(root, (total - b) * rnaPx, lane));
            }
          }
        }
        if (stretch.looped > 0) {
          loops.add((
            along(root, d + run / 2, lane),
            stretch.looped * rnaPx,
            shown,
          ));
        }
        from += bases;
      }
      if (rna.isNotEmpty) {
        caps.add((along(root, total * rnaPx, lane), shown));
      }
    }

    for (final Polymerase p in now.polymerases) {
      if (p.shown <= 0.002 || p.rna.isEmpty) {
        continue;
      }
      lay(Offset(x(p.at), line + drop), p.rna, p.lane, p.shown);
    }
    for (final Release r in now.releases) {
      final double t = r.age / Transcription.releaseSeconds;
      final double shown = 1 - _smoothstep((t - 0.2) / 0.8);
      final Offset drift =
          const Offset(0.38, 0.92) * (26 * scale * r.age) +
          Offset(0, 6 * scale * _smoothstep(r.age / 0.4));
      final Offset root = Offset(x(r.from), line + drop) + drift;
      lay(root, r.rna, r.lane, shown);
      // Its poly(A) tail, coming up at its 3′ end as it is let go.
      final double tail = 9 * scale * _smoothstep(r.age / 0.4);
      if (tail > 0.3) {
        final Path polyA = Path()..moveTo(root.dx, root.dy);
        for (int k = 1; k <= 6; k++) {
          final double u = k / 6;
          final Offset p =
              root -
              down * (tail * u) +
              across * (1.2 * scale * math.sin(u * math.pi * 3));
          polyA.lineTo(p.dx, p.dy);
        }
        strokes
            .putIfAbsent(inks.label.withValues(alpha: 0.7 * shown), Path.new)
            .addPath(polyA, Offset.zero);
      }
    }

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final MapEntry<Color, Path> s in strokes.entries) {
      canvas.drawPath(s.value, stroke..color = s.key);
    }
    final Paint dot = Paint();
    for (final MapEntry<Color, List<Offset>> b in beaded.entries) {
      dot.color = b.key;
      for (final Offset at in b.value) {
        canvas.drawCircle(at, bead, dot);
      }
    }

    // An intron's loop, its two ends come together at its place on the
    // fibril, round to the 3′ side; a lariat, drifting away as it fades.
    final Color intron = inks.label;
    void loop(Offset at, double round, double shown, {double tail = 0}) {
      final double drawn = _smoothstep((round - 4) / (loopShown - 4));
      if (drawn <= 0 || shown <= 0) {
        return;
      }
      final double r = round / (2 * math.pi);
      final Offset centre = at + across * r;
      stroke.color = intron.withValues(alpha: 0.7 * shown * drawn);
      canvas.drawCircle(centre, r, stroke);
      if (tail > 0) {
        canvas.drawLine(at, at - across * tail, stroke);
      }
    }

    for (final (Offset at, double round, double shown) in loops) {
      loop(at, round, shown);
    }
    for (final Lariat l in now.lariats) {
      final double t = l.age / Transcription.lariatSeconds;
      // Where its loop was on the fibril as it was cut free, swaying as
      // the fibril does, and drifting off from there.
      final Offset born = along(
        Offset(x(l.from), line + drop),
        l.along * rnaPx,
        l.lane,
      );
      final Offset drift =
          const Offset(0.62, 0.78) * (20 * scale * l.age) +
          Offset(
            0,
            4 * scale * math.sin(l.age * 3 + l.lane) -
                4 * scale * math.sin(l.lane.toDouble()),
          );
      loop(
        born + drift,
        l.length * rnaPx * (1 - 0.3 * t),
        1 - _smoothstep((t - 0.25) / 0.75),
        tail:
            math.min(0.12 * l.length * rnaPx, 7 * scale) *
            _smoothstep(l.age / 0.3),
      );
    }

    final Paint cap = Paint()..color = inks.mark;
    for (final (Offset at, double shown) in caps) {
      canvas.drawCircle(
        at,
        (1.9 * scale).clamp(1.0, 3.0),
        cap..color = inks.glow(shown),
      );
    }

    // The polymerases over their RNA's roots, on the gene's line.
    final ui.Picture blob = _polymerase(inks);
    final double size = polymeraseWidth * scale / 100;
    for (final Polymerase p in now.polymerases) {
      if (p.shown <= 0.002) {
        continue;
      }
      canvas.save();
      canvas.translate(x(p.at), line);
      canvas.scale(size);
      if (p.shown < 0.995) {
        canvas.saveLayer(
          const Rect.fromLTWH(-70, -70, 140, 140),
          Paint()..color = Color.fromRGBO(0, 0, 0, p.shown),
        );
        canvas.drawPicture(blob);
        canvas.restore();
      } else {
        canvas.drawPicture(blob);
      }
      canvas.restore();
    }
  }

  static double _smoothstep(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  void dispose() {
    _blob?.dispose();
    _blob = null;
  }
}
