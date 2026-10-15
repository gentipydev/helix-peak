import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/gene_layout.dart';
import '../../domain/transcription.dart';
import '../zoom_inks.dart';
import 'sculpt.dart';

/// The gene being read as it lies on screen at one frame: what
/// [TranscriptionArt.paint] draws, and what the tests hold it to.
@immutable
final class ReadingLaid {
  const ReadingLaid({
    required this.polymerases,
    required this.fibrils,
    required this.runs,
    required this.caps,
    required this.loop,
    required this.mrna,
    required this.tail,
    required this.width,
    required this.scale,
  });

  /// Where each polymerase sits, on the gene's line.
  final List<Offset> polymerases;

  /// Each polymerase's RNA, from its root under the polymerase to its 5′
  /// end.
  final List<(Offset, Offset)> fibrils;

  /// Every stretch of RNA drawn, the fibrils' and the mRNA's: what it is,
  /// its two ends, and whether it is the mRNA's.
  final List<(GenePieceKind, Offset, Offset, bool)> runs;

  /// Where each RNA's 5′ cap is.
  final List<Offset> caps;

  /// The loop of the intron being spliced: its centre, its radius and how
  /// much of it shows; null where no intron loops out.
  final (Offset, double, double)? loop;

  /// The finished mRNA, from its 5′ end to its 3′ end, level; null where it
  /// is too small at the gene's stop to read as one.
  final (Offset, Offset)? mrna;

  /// Its poly(A) tail, as points from the mRNA's 3′ end on.
  final List<Offset> tail;

  /// How thick the RNA is drawn.
  final double width;

  /// How many times its size at the gene's stop the gene is drawn.
  final double scale;
}

/// How a gene being read is drawn ([Transcription]), as an electron
/// micrograph of a gene being read shows it (Miller and Beatty 1969), and
/// still: each polymerase a small lit body on the gene's line, its RNA
/// hanging from it, longer the further it has read. The RNA is in the gene's
/// own colours (its exons' coding and untranslated parts, its introns in the
/// quiet ink), capped at its 5′ end in the mark. The intron being spliced
/// loops out at its place; the finished mRNA lies free below them, under
/// the gene's 3′ end, its exons joined and its poly(A) tail at its 3′ end.
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

  /// The share of the room under the gene's line the longest RNA takes at
  /// the most: the finished mRNA lies in what is left.
  static const double roomShare = 0.8;

  /// How long an intron's loop must be round, in pixels at the gene's
  /// stop, to be drawn whole: a shorter one is fainter, and one under 4 px
  /// is not drawn.
  static const double loopShown = 12;

  /// How long the finished mRNA must be, in pixels at the gene's stop, to
  /// be drawn: a long gene's is a speck beside it.
  static const double mrnaShown = 12;

  /// How far below the lowest of the RNAs hanging from the gene the finished
  /// mRNA lies, in pixels at the gene's stop.
  static const double mrnaGap = 24;

  /// The gap where two exons are joined in the finished mRNA, in pixels at
  /// the gene's stop: a third of the shorter of the two, where that is less.
  static const double junction = 1.5;

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

  /// Lays the gene being read out on screen. [x] is the screen x of a place
  /// on the gene, in base pairs from its 5′ end; [line] the screen y of the
  /// gene's line; [perBase] pixels a base now, [atRest] at the gene's stop;
  /// [compaction] as above.
  ReadingLaid lay({
    required double Function(double offset) x,
    required double line,
    required double perBase,
    required double atRest,
    required double compaction,
  }) {
    final double scale = perBase / atRest;
    final double rnaPx = compaction * perBase;
    final double width = (2.2 * scale).clamp(1.1, 3.4);
    final double drop = 3.5 * scale;
    final Offset down = Offset(-math.sin(lean), math.cos(lean));
    final Offset across = Offset(math.cos(lean), math.sin(lean));
    final List<Offset> polymerases = <Offset>[];
    final List<(Offset, Offset)> fibrils = <(Offset, Offset)>[];
    final List<(GenePieceKind, Offset, Offset, bool)> runs =
        <(GenePieceKind, Offset, Offset, bool)>[];
    final List<Offset> caps = <Offset>[];
    (Offset, double, double)? loop;
    double lowest = line + drop;
    for (final Polymerase p in reading.polymerases) {
      final Offset root = Offset(x(p.at), line + drop);
      polymerases.add(Offset(root.dx, line));
      // Its RNA from its 3′ end, at the polymerase, to its 5′ end.
      double d = 0;
      for (int i = p.rna.length - 1; i >= 0; i--) {
        final RnaStretch stretch = p.rna[i];
        final double run = stretch.length * rnaPx;
        if (run > 0) {
          runs.add((
            stretch.kind,
            root + down * d,
            root + down * (d + run),
            false,
          ));
        }
        if (stretch.looped > 0) {
          // Its two ends come together at its place, the loop round to the
          // 3′ side; whole where it is big enough at the gene's stop.
          final double r = stretch.looped * rnaPx / (2 * math.pi);
          final double atStop = stretch.looped * compaction * atRest;
          final Offset centre = root + down * (d + run / 2) + across * r;
          loop = (centre, r, _smoothstep((atStop - 4) / (loopShown - 4)));
          lowest = math.max(lowest, centre.dy + r);
        }
        d += run;
      }
      final Offset tip = root + down * d;
      fibrils.add((root, tip));
      if (p.rna.isNotEmpty) {
        caps.add(tip);
      }
      lowest = math.max(lowest, tip.dy);
    }

    // The finished mRNA, level below them, its 3′ end under the gene's.
    (Offset, Offset)? mrna;
    final List<Offset> tail = <Offset>[];
    final double bases = reading.mrna.fold<double>(
      0,
      (double sum, RnaStretch s) => sum + s.length,
    );
    if (bases * compaction * atRest >= mrnaShown) {
      final double y = lowest + mrnaGap * scale;
      final double end = x(reading.layout.length);
      final double start = end - bases * rnaPx;
      mrna = (Offset(start, y), Offset(end, y));
      final Set<double> joined = reading.junctions.toSet();
      final List<RnaStretch> parts = reading.mrna;
      // The gap either side of a junction, at most a third of the shorter
      // of the two exons' stretches there.
      double gapAt(int i) => math.min(
        junction * scale,
        math.min(parts[i - 1].length, parts[i].length) * rnaPx / 3,
      );
      double made = 0;
      for (int i = 0; i < parts.length; i++) {
        final RnaStretch stretch = parts[i];
        double a = start + made * rnaPx;
        double b = start + (made + stretch.length) * rnaPx;
        if (i > 0 && joined.contains(made)) {
          a += gapAt(i) / 2;
        }
        made += stretch.length;
        if (i + 1 < parts.length && joined.contains(made)) {
          b -= gapAt(i + 1) / 2;
        }
        if (b > a) {
          runs.add((stretch.kind, Offset(a, y), Offset(b, y), true));
        }
      }
      caps.add(Offset(start, y));
      // Its poly(A) tail, on from its 3′ end.
      final double reach = 9 * scale;
      for (int k = 0; k <= 6; k++) {
        final double u = k / 6;
        tail.add(
          Offset(end + reach * u, y + 1.2 * scale * math.sin(u * math.pi * 3)),
        );
      }
    }
    return ReadingLaid(
      polymerases: polymerases,
      fibrils: fibrils,
      runs: runs,
      caps: caps,
      loop: loop,
      mrna: mrna,
      tail: tail,
      width: width,
      scale: scale,
    );
  }

  /// Draws the gene being read as [laid] lays it.
  void paint(Canvas canvas, ZoomInks inks, ReadingLaid laid) {
    // One path for each colour, the fibrils' joined round, the mRNA's cut
    // square, so its joins show.
    final Map<Color, Path> hanging = <Color, Path>{};
    final Map<Color, Path> made = <Color, Path>{};
    for (final (GenePieceKind kind, Offset a, Offset b, bool mrna)
        in laid.runs) {
      final Path path = (mrna ? made : hanging).putIfAbsent(
        _ink(inks, kind),
        Path.new,
      );
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = laid.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final MapEntry<Color, Path> s in hanging.entries) {
      canvas.drawPath(s.value, stroke..color = s.key);
    }
    stroke.strokeCap = StrokeCap.butt;
    for (final MapEntry<Color, Path> s in made.entries) {
      canvas.drawPath(s.value, stroke..color = s.key);
    }
    stroke.strokeCap = StrokeCap.round;
    if (laid.tail.isNotEmpty) {
      final Path polyA = Path()..moveTo(laid.tail.first.dx, laid.tail.first.dy);
      for (final Offset p in laid.tail.skip(1)) {
        polyA.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(polyA, stroke..color = inks.label.withValues(alpha: 0.7));
    }
    final (Offset, double, double)? loop = laid.loop;
    if (loop != null && loop.$3 > 0) {
      final (Offset centre, double r, double shown) = loop;
      canvas.drawCircle(
        centre,
        r,
        stroke..color = inks.label.withValues(alpha: 0.7 * shown),
      );
    }
    final Paint cap = Paint()..color = inks.mark;
    final double capRadius = (1.9 * laid.scale).clamp(1.0, 3.0);
    for (final Offset at in laid.caps) {
      canvas.drawCircle(at, capRadius, cap);
    }

    // The polymerases over their RNA's roots, on the gene's line.
    final ui.Picture blob = _polymerase(inks);
    final double size = polymeraseWidth * laid.scale / 100;
    for (final Offset at in laid.polymerases) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(size);
      canvas.drawPicture(blob);
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
