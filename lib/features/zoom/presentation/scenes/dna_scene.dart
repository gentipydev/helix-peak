import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/helix/dna_helix_painter.dart';
import '../../../../shared/helix/helix_geometry.dart';
import '../../domain/chromatin_layout.dart';
import '../../domain/dna_dive.dart';
import '../../domain/gene_layout.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'body_scene.dart';
import 'chromatin_beads.dart';
import 'gene_strand.dart';
import 'nucleosome_art.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's DNA from the gene's stop down to its first bases: one DNA all
/// the way, seen closer and closer (the user's choice of 2026-10-15,
/// evening, over a gene that gave way to beads and a helix that came up
/// from nowhere).
///
/// It reads 5′ to 3′, left to right, whatever the gene's strand, as the
/// gene's stop does, and from that stop on it is this scene's: it draws the
/// gene's line and exons as the gene's scene did a frame before
/// ([GeneStrand]), so nothing changes at the stop. Then, as the view closes
/// in on the gene's 5′ end:
/// - the exons sink into the DNA, each a stretch of it in its colour, and
///   the DNA either side of the gene comes up;
/// - the DNA winds onto its histones ([ChromatinLayout]): each nucleosome's
///   stretch coils round a core that grows in its turns, and the linkers
///   draw the cores together, so the line is seen to be beads on a string;
///   the stretch round the start, which a gene being read keeps bare, stays
///   where it is, and the first of them is named;
/// - the bare start thickens to the home screen's own double helix
///   ([DnaHelixPainter]), a twisted rope at first that shows its grooves as
///   it grows, its bases coming in as they can be told apart, the record's
///   first bases in their own colours.
///
/// At its stop the helix lies along the gene with its 5′ end at the left,
/// turning as the home screen's does, whole, every base paired: nothing
/// reads it. As the walk opens it unzips into the walk's rows, its turn
/// easing until they lie flat.
final class DnaScene extends ZoomScene {
  DnaScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.dna;

  /// One base pair along the axis, in the scene's units.
  static const double pitch = 1 / ZoomDepth.dnaBasePairs;

  static const ChromatinLayout chromatin = ChromatinLayout();

  /// The home screen's helix as its painter draws it, in the painter's own
  /// pixels: its radius, and its length for each base pair.
  static const double helixRadius = HelixModel.defaultRadius;
  static const double helixPerBase =
      HelixModel.defaultPitch / HelixModel.basePairsPerTurn;

  /// How thick the helix's painter draws the duplex, in base pairs'
  /// lengths, and so how thick the DNA is drawn wherever it is a tube:
  /// 2.1 nm, about the 2 nm it is.
  static const double thickness = 2 * helixRadius / helixPerBase;

  /// How long a turn takes, as on the home screen.
  static const double turnSeconds = 24;

  /// How much narrower the view gets, from where the DNA starts to wind,
  /// before every nucleosome is wound.
  static const double windsOver = 4;

  /// How wide the view is, in base pairs, when the gene's exons are gone
  /// from its DNA: the bases come up below it.
  static const double exonsGone = 230;

  // Every stage of the way is keyed to how wide the view is: a function of
  // the depth, however the step spends it.
  double get _gene => subject.depth.widthOf(ZoomStop.gene);
  double get _winds => DnaDive.windsFrom(_gene);
  double get _sinks => math.min(_gene, 10 * _winds);

  /// How far the exons have sunk into the DNA, where the view is [span]
  /// base pairs wide: from the gene's stop, or a decade above where the DNA
  /// winds, to where it does.
  double sunkAt(double span) => _between(span, _sinks, _winds);

  /// How far the DNA is wound onto its histones.
  double woundAt(double span) => _between(span, _winds, _winds / windsOver);

  /// How much of the exons' colours the DNA still wears.
  static double tintAt(double span) => 1 - _fall(span, 500, exonsGone);

  /// How much of the DNA either side of the gene shows: all of it from the
  /// gene's stop, where the gene is a stretch of chromatin, and none once
  /// the bases come up, the record holding none of them.
  double contextAt(double span) => 1 - _fall(span, 600, 250);

  /// How much of the bare start is the helix's: its tube hands over to the
  /// painter's duplex, a twisted rope as thick as it.
  static double helixAt(double span) => _fall(span, 800, 300);

  /// How much of the helix's bases show, and the least width its backbones
  /// are drawn at, on screen: thin strands far out, its own at its stop.
  static double basesAt(double span) => _fall(span, 220, 40);
  static double floorAt(double span) => 1.4 * smoothstep((span - 16) / 24);

  /// 0 where the view is [from] base pairs wide or wider, 1 where it is
  /// [to] or narrower, evenly in its log between: every stage of the way is
  /// spread over the step's depth as it narrows.
  static double _fall(double span, double from, double to) =>
      smoothstep(math.log(from / span) / math.log(from / to));

  static double _between(double span, double from, double to) {
    if (from <= to) {
      return span <= to ? 1 : 0;
    }
    return smoothstep(math.log(from / span) / math.log(from / to));
  }

  /// How much of the gene's exons show on its DNA at [frame]: whole at the
  /// gene's stop, gone by [exonsGone].
  @visibleForTesting
  double exonsShown(ZoomFrame frame) => tintAt(_span(frame));

  /// How far the DNA is wound at [frame].
  @visibleForTesting
  double woundShown(ZoomFrame frame) => woundAt(_span(frame));

  /// How many halvings short of room for every bead the gene's beads are
  /// chosen at [frame] ([ChromatinBeads.levelAt]): as many as the gene's
  /// stop has at its stop, none by where the DNA starts to wind, and evenly
  /// over the step's depth between. As the view's own width would, a long
  /// gene's empty decades, which go by in a rush, would bring them up in
  /// one.
  @visibleForTesting
  double beadLevel(ZoomFrame frame) {
    final double atStop = ChromatinBeads.levelAt(frame.size.width / _gene);
    final double winds = subject.depth.dive.spentAt(_winds);
    return atStop * (1 - smoothstep(frame.progress / math.max(winds, 1e-6)));
  }

  /// How much of the helix shows at [frame], and of its bases.
  @visibleForTesting
  (double, double) helixShown(ZoomFrame frame) {
    final double span = _span(frame);
    return (helixAt(span), basesAt(span));
  }

  // From the gene's stop on, this scene draws the gene's DNA, so it is all
  // there from the first: its parts come and go by the view's width.
  @override
  double asChild(double progress) => 1;

  final ProxyAnimation _rotation = ProxyAnimation(kAlwaysDismissedAnimation);
  static const Animation<double> _still = AlwaysStoppedAnimation<double>(0);

  DnaHelixPainter? _painter;
  (ZoomInks, double, double, double)? _painted;

  /// The painter for the helix in [inks], [unzip] of the way unzipped, its
  /// strands no thinner than [floor] painter pixels and [bases] of its bases
  /// showing, made again only when one of them changes.
  DnaHelixPainter? _helix(
    ZoomInks inks,
    double unzip, {
    double floor = 0,
    double bases = 1,
  }) {
    final int count = subject.dnaBases;
    if (count < 4) {
      return null;
    }
    final double quantised = (unzip * 60).roundToDouble() / 60;
    final (ZoomInks, double, double, double) now = (
      inks,
      quantised,
      floor,
      bases,
    );
    if (_painter == null || _painted != now) {
      final String sequence = subject.record.sequence;
      _painter = DnaHelixPainter(
        repaint: _rotation,
        rotation: _rotation,
        drift: _still,
        transcription: null,
        model: _models[quantised] ??= HelixModel(
          rungCount: count,
          sampleCount: 3 * count,
          unzip: quantised,
          // The 3′ end first: the painter's first rung comes to lie at the
          // right, the gene's 3′ side.
          bases: Uint8List.fromList(<int>[
            for (int i = count - 1; i >= 0; i--)
              HelixPalette.ofBase(sequence[i]),
          ]),
        ),
        backbone: inks.label,
        adenine: inks.bases.adenine,
        thymine: inks.bases.thymine,
        guanine: inks.bases.guanine,
        cytosine: inks.bases.cytosine,
        transcript: inks.mark,
        background: inks.ground,
        // Laid along the gene from its 5′ end, at its own pitch: no fade at
        // either end of its own; its 3′ side runs off the canvas's edge.
        topFade: 0,
        bottomFade: 0,
        overscan: 0,
        strandFloor: floor,
        bases: bases,
      );
      _painted = now;
    }
    return _painter;
  }

  /// The helix's models, by how far unzipped: the turn into the walk's rows
  /// builds each once.
  final Map<double, HelixModel> _models = <double, HelixModel>{};

  /// How many base pairs of the genome a base pair of the record's gene
  /// lies along: the gene's scene lays the record's parts along the span
  /// MANE gives the gene, which for a few genes is a little shorter, and
  /// the DNA lays the gene's parts as the gene's scene does.
  double get _scale => subject.track.geneLengthBp / subject.layout.length;

  /// Where the point [offset] base pairs into the record's gene lies across
  /// the screen at [frame], as the gene's scene lays it.
  @visibleForTesting
  double screenX(ZoomFrame frame, double offset) => _x(frame, offset * _scale);

  /// A point [offset] base pairs from the 5′ end, in the scene's units: the
  /// scene's middle is the middle of its view ([ZoomSubject.dnaView]).
  double unitAlong(double offset) => (offset - subject.dnaView) * pitch;

  double _x(ZoomFrame frame, double offset) =>
      frame.toScreen(Offset(unitAlong(offset), 0)).dx;

  /// Where along the fibre the screen's [x] lies, in base pairs' lengths
  /// from the 5′ end.
  double _along(ZoomFrame frame, double x) =>
      frame.view.fromScreen(Offset(x, 0), frame.size).dx / pitch +
      subject.dnaView;

  /// How many base pairs the view spans.
  double _span(ZoomFrame frame) =>
      frame.size.width / frame.view.pixelsPerUnit / pitch;

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset five = Offset(_x(frame, 0), frame.size.height / 2);
    final double named = calloutPresence(frame);
    out.item('dna:5', five, named);
    out.callout('dna', '5′', five, named);
    final (Offset core, double reach, double shown) = _firstCore(frame);
    if (shown > 0) {
      out.callout(
        'dna:nucleosome',
        'nucleosome',
        core,
        shown,
        // Below its core, clear of its DNA: nothing hangs from the gene
        // there by now.
        anchors: <Offset>[core.translate(0, reach + 10)],
        quiet: true,
      );
    }
  }

  /// The first nucleosome past the gene's start, the one named: its core's
  /// middle on screen, how far its DNA reaches round it there, and how much
  /// of its name shows. Named once wound and big enough to read as a bead,
  /// until the bases come up beside it.
  (Offset, double, double) _firstCore(ZoomFrame frame) {
    final double span = _span(frame);
    final double wound = woundAt(span);
    final double perBase = frame.size.width / span;
    final double centre =
        chromatin.axisAt(ChromatinLayout.first, wound) +
        ChromatinLayout.across / 2;
    final Offset at = Offset(_x(frame, centre), frame.size.height / 2);
    final double reach = (ChromatinLayout.radius + thickness) * perBase;
    // Keyed to the view's width alone, over windows wide enough in its log
    // for the step to take its time over them: in as the beads grow from a
    // dozen pixels to some twenty, wound by then; out before the bases.
    final double shown =
        smoothstep(math.log(900 / span) / math.log(900 / 350)) *
        (1 - smoothstep(math.log(330 / span) / math.log(330 / 150)));
    return (at, reach, math.min(shown, frame.opacity));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double span = _span(frame);
    final double w = frame.size.width;
    final double mid = frame.size.height / 2;
    final double perBase = w / span;
    final double wound = woundAt(span);
    final double sunk = sunkAt(span);
    // The line the gene's stop draws, thickening to the DNA's own width as
    // the exons sink into it.
    final double thick =
        GeneStrand.line +
        math.max(0, thickness * perBase - GeneStrand.line) * sunk;
    final ZoomInks inks = frame.inks;
    final double around = contextAt(span);
    if (wound <= 0 && helixAt(span) <= 0) {
      // The gene's DNA as its stop draws it, beaded with its nucleosomes and
      // going on either side of it, its exons sinking into it.
      final double end = subject.layout.length * _scale;
      GeneStrand.flanks(
        canvas,
        inks,
        start: _x(frame, 0),
        end: _x(frame, end),
        mid: mid,
        width: w,
        thick: thick,
        alpha: around,
      );
      GeneStrand.paint(
        canvas,
        inks,
        subject.layout,
        x: (double offset) => screenX(frame, offset),
        mid: mid,
        width: w,
        sink: sunk,
        thick: thick,
        blocks: false,
      );
      ChromatinBeads.paint(
        canvas,
        inks,
        x: (double offset) => _x(frame, offset),
        mid: mid,
        from: _along(frame, -24),
        to: _along(frame, w + 24),
        perBase: perBase,
        level: beadLevel(frame),
        alphaAt: (double at) => at < 0 || at > end ? around : 1,
      );
      GeneStrand.paint(
        canvas,
        inks,
        subject.layout,
        x: (double offset) => screenX(frame, offset),
        mid: mid,
        width: w,
        sink: sunk,
        thick: thick,
        line: false,
      );
      return;
    }
    _fibre(canvas, frame, span, wound, thick, perBase, mid, around);
    if (sunk < 1) {
      GeneStrand.paint(
        canvas,
        inks,
        subject.layout,
        x: (double offset) => screenX(frame, offset),
        mid: mid,
        width: w,
        sink: sunk,
        thick: thick,
        line: false,
      );
    }
  }

  /// The genome's offset whose place along the fibre is [along], [wound] of
  /// the way wound: the layout only ever draws the DNA in, so it is found
  /// by halving.
  double _offsetOf(double along, double wound) {
    double low = along - 4 * math.max(along.abs(), 400);
    double high = along + 4 * math.max(along.abs(), 400);
    for (int i = 0; i < 60; i++) {
      final double mid = (low + high) / 2;
      if (chromatin.axisAt(mid, wound) < along) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  /// The DNA as chromatin, [wound] of the way wound, in view.
  void _fibre(
    Canvas canvas,
    ZoomFrame frame,
    double span,
    double wound,
    double thick,
    double perBase,
    double mid,
    double around,
  ) {
    final ZoomInks inks = frame.inks;
    final double w = frame.size.width;
    final GeneLayout layout = subject.layout;
    final double scale = _scale;
    final double end = layout.length * scale;
    const double reach = ChromatinLayout.across + thickness;
    final double from = _offsetOf(_along(frame, 0) - reach, wound);
    final double to = _offsetOf(_along(frame, w) + reach, wound);
    final List<(double, double)> beads = chromatin.nucleosomesWithin(from, to);
    final double tint = tintAt(span);
    final double helix = helixAt(span);
    final int bare = subject.dnaBases;
    // As the bare start becomes the helix the rest of the DNA shows its
    // twist too: two strands round its grooves, as the helix's own are.
    final double twist = helix;
    // Steps along the DNA fine enough to follow its turns where they show,
    // and coarse where it is a line.
    final double step = twist > 0
        ? (1.2 / perBase).clamp(0.25, 3.0)
        : double.infinity;

    Offset screen(FibrePoint p) =>
        Offset(_x(frame, p.along), mid + p.across * perBase);

    // The DNA's colour at [offset]: the gene's, its exons tinted as they
    // fade; the DNA either side of it as it comes and goes; the bare start
    // giving way to the helix.
    Color colourAt(double offset) {
      final GenePieceKind kind = _kindAt(layout, offset / scale);
      final Color ink = GeneStrand.ink(inks, kind, tint);
      double alpha = 1;
      if (offset < 0 || offset > end) {
        alpha = around;
      } else if (offset < bare) {
        alpha = 1 - helix;
      }
      return ink.withValues(alpha: ink.a * alpha);
    }

    // Where each piece of the gene starts and ends, to split the DNA's
    // colour at.
    final List<double> marks = <double>[
      0,
      end,
      bare.toDouble(),
      for (final GenePiece piece in layout.pieces) ...<double>[
        piece.start * scale,
        piece.end * scale,
      ],
    ];
    List<double> splitAt(double a, double b, int samples) {
      final int fine = step.isFinite
          ? math.max(samples, ((b - a) / step).ceil())
          : samples;
      return <double>[
        for (int i = 0; i <= fine; i++) a + (b - a) * i / fine,
        for (final double m in marks)
          if (m > a && m < b) m,
      ]..sort();
    }

    // Lays the DNA over [offsets] (in order), its points from [at], into
    // [into], or a wound stretch's into [behind] where it passes behind its
    // core: one stroke for each run of a colour, so it turns without seams.
    void lay(
      List<double> offsets,
      FibrePoint Function(double) at,
      _Strokes into, [
      _Strokes? behind,
    ]) {
      FibrePoint? last;
      for (int i = 0; i + 1 < offsets.length; i++) {
        final double a = offsets[i];
        final double b = offsets[i + 1];
        if (b - a < 1e-9) {
          continue;
        }
        final double m = (a + b) / 2;
        final Color colour = colourAt(m);
        final FibrePoint pa = last ?? at(a);
        final FibrePoint pb = at(b);
        last = pb;
        if (colour.a <= 0.002) {
          continue;
        }
        final _Strokes target = behind != null && at(m).depth < 0
            ? behind
            : into;
        target.add(colour, screen(pa), screen(pb), a, b);
      }
    }

    // The runs between nucleosomes, straight from where one lets its DNA go
    // to where the next takes it up; the bare start along the axis, where
    // the helix lies.
    final _Strokes runs = _Strokes();
    double runFrom = from;
    FibrePoint runStart = FibrePoint(chromatin.axisAt(from, wound), 0, 0);
    void run(double a, double b, FibrePoint pa, FibrePoint pb) {
      if (b <= a) {
        return;
      }
      final bool holdsStart = a <= 0 && b >= bare;
      FibrePoint at(double offset) {
        if (holdsStart) {
          if (offset >= 0 && offset <= bare) {
            return FibrePoint(offset, 0, 0);
          }
          // Either side of the bare start's fixed stretch, straight to it.
          if (offset < 0) {
            final double t = (offset - a) / (0 - a);
            return FibrePoint(
              pa.along + (0 - pa.along) * t,
              pa.across * (1 - t),
              pa.depth * (1 - t),
            );
          }
          final double t = (offset - bare) / (b - bare);
          return FibrePoint(
            bare + (pb.along - bare) * t,
            pb.across * t,
            pb.depth * t,
          );
        }
        final double t = (offset - a) / (b - a);
        return FibrePoint(
          pa.along + (pb.along - pa.along) * t,
          pa.across + (pb.across - pa.across) * t,
          pa.depth + (pb.depth - pa.depth) * t,
        );
      }

      lay(splitAt(a, b, 1), at, runs);
    }

    for (final (double start, double end) in beads) {
      run(runFrom, start, runStart, chromatin.woundAt(start, start, wound));
      runFrom = end;
      runStart = chromatin.woundAt(start, end, wound);
    }
    run(runFrom, to, runStart, FibrePoint(chromatin.axisAt(to, wound), 0, 0));
    runs.paint(canvas, inks, thick, perBase, twist);

    // Each nucleosome: the DNA behind its core, the core, the DNA in front.
    // The cores are the beads the gene's stop drew, whole from the first;
    // the DNA's front turns come over them as it winds, from under them.
    final double level = beadLevel(frame);
    final double over = smoothstep((wound - 0.05) / 0.35);
    for (final (double start, double end) in beads) {
      final _Strokes behind = _Strokes();
      final _Strokes inFront = _Strokes();
      lay(
        splitAt(start, end, 56),
        (double offset) => chromatin.woundAt(start, offset, wound),
        inFront,
        behind,
      );
      behind.paint(canvas, inks, thick, perBase, twist, shaded: true);
      if (over < 1) {
        inFront.paint(canvas, inks, thick, perBase, twist, alpha: 1 - over);
      }
      final double centre =
          chromatin.axisAt(start, wound) + ChromatinLayout.across / 2;
      final double side = start < 0 || start > end ? around : 1;
      NucleosomeArt.paint(
        canvas,
        Offset(_x(frame, centre), mid),
        perBase,
        inks,
        alpha:
            ChromatinBeads.shownAt(ChromatinBeads.indexOf(start), level) * side,
        least: ChromatinBeads.least,
      );
      if (over > 0) {
        inFront.paint(canvas, inks, thick, perBase, twist, alpha: over);
      }
    }
  }

  /// What the gene is at [offset] base pairs from its 5′ end: an exon's
  /// coding or untranslated part, or an intron, as the DNA either side of
  /// it is drawn.
  static GenePieceKind _kindAt(GeneLayout layout, double offset) {
    final List<GenePiece> pieces = layout.pieces;
    int low = 0;
    int high = pieces.length - 1;
    while (low <= high) {
      final int m = (low + high) >> 1;
      final GenePiece piece = pieces[m];
      if (offset < piece.start) {
        high = m - 1;
      } else if (offset >= piece.end) {
        low = m + 1;
      } else {
        return piece.kind;
      }
    }
    return GenePieceKind.intron;
  }

  @override
  void prepare(ZoomInks inks) => _helix(inks, 0);

  @override
  bool wantsClock(ZoomFrame frame) => helixAt(_span(frame)) > 0;

  // The helix turns at rest, so it is drawn over the scene on the ambient
  // clock, and fades there with the scene itself.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    final double helix = helixAt(_span(frame));
    if (helix <= 0) {
      return;
    }
    _drawHelix(canvas, frame, helix * frame.opacity);
  }

  void _drawHelix(Canvas canvas, ZoomFrame frame, double alpha) {
    final double span = _span(frame);
    // The painter's helix in screen pixels: its own pixels at the camera's
    // scale.
    final double scale = frame.view.pixelsPerUnit * pitch / helixPerBase;
    final DnaHelixPainter? painter = _helix(
      frame.inks,
      frame.unzip,
      floor: floorAt(span) / scale,
      bases: basesAt(span),
    );
    if (painter == null) {
      return;
    }
    // The home screen's turn, eased to the nearest flat as it unzips.
    final double turn =
        (HelixModel.staticRotationTurns + frame.clock / turnSeconds) % 1;
    final double flat = turn < 0.5 ? 0 : 1;
    _rotation.parent = AlwaysStoppedAnimation<double>(
      turn + (flat - turn) * smoothstep(frame.unzip),
    );
    // The painter's helix stands along its canvas's height, its middle at
    // the canvas's, its first rung at the top: turned to lie along the gene
    // with its first rung, the 3′ end, at the right, its middle on the
    // record's middle base, at the camera's scale.
    final double length = subject.dnaBases * helixPerBase;
    final Size page = Size(helixRadius * 4.4, length * 1.3);
    final double mid = frame.size.height / 2;
    final double w = frame.size.width;
    // Its 3′ side runs off into the ground at the canvas's right edge, as
    // the home screen's runs off its own. Where nothing of the DNA lies
    // under that fade (at the stop, and closing in on it) it is drawn as it
    // always was, the ground painted over it, with no layer to pay for at
    // every turn; elsewhere it is erased on a layer of its own, so the DNA
    // under it on the way in still shows.
    final bool alone =
        alpha >= 0.995 &&
        _x(frame, subject.dnaBases.toDouble()) >= w &&
        contextAt(span) <= 0;
    if (!alone) {
      canvas.saveLayer(
        Offset.zero & frame.size,
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
      );
    }
    canvas.save();
    canvas.translate(_x(frame, subject.dnaMiddle), mid);
    canvas.scale(scale);
    canvas.rotate(math.pi / 2);
    canvas.translate(-page.width / 2, -page.height / 2);
    painter.paint(canvas, page);
    canvas.restore();
    final Rect fade = Rect.fromLTRB(w * 0.72, 0, w, frame.size.height);
    canvas.drawRect(
      fade,
      Paint()
        ..blendMode = alone ? BlendMode.srcOver : BlendMode.dstOut
        ..shader = LinearGradient(
          colors: <Color>[
            frame.inks.ground.withValues(alpha: 0),
            frame.inks.ground,
          ],
        ).createShader(fade),
    );
    if (!alone) {
      canvas.restore();
    }
  }
}

/// The DNA's strokes by colour, laid as it runs: a run of one colour is one
/// stroke, so the DNA turns without seams; and its two strands, where it is
/// thick enough to show them, by which side of the duplex they are on.
final class _Strokes {
  final Map<Color, Path> _body = <Color, Path>{};
  final Map<Color, Offset> _ends = <Color, Offset>{};

  /// Each stretch laid: its colour, its ends on screen and in base pairs.
  final List<(Color, Offset, Offset, double, double)> _laid =
      <(Color, Offset, Offset, double, double)>[];

  void add(Color colour, Offset a, Offset b, double from, double to) {
    final Path path = _body[colour] ??= Path();
    final Offset? end = _ends[colour];
    if (end == null || (end - a).distanceSquared > 0.01) {
      path.moveTo(a.dx, a.dy);
    }
    path.lineTo(b.dx, b.dy);
    _ends[colour] = b;
    _laid.add((colour, a, b, from, to));
  }

  /// Draws the DNA [thick] pixels thick, [perBase] pixels a base pair along
  /// it, its strands showing [twist] of the way; in shade behind a core;
  /// [alpha] of it.
  void paint(
    Canvas canvas,
    ZoomInks inks,
    double thick,
    double perBase,
    double twist, {
    bool shaded = false,
    double alpha = 1,
  }) {
    Color shade(Color c, double by) =>
        Color.lerp(c, inks.ground, by)!.withValues(alpha: c.a * alpha);
    for (final MapEntry<Color, Path> body in _body.entries) {
      // A tube, giving way to its strands as they come up, as the helix
      // is its strands and its bases alone.
      final Color colour = shade(body.key, shaded ? 0.4 : 0);
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
    final Map<Color, Path> back = <Color, Path>{};
    final Map<Color, Path> front = <Color, Path>{};
    // Each strand one stroke for as long as it stays on one side and in one
    // colour: translucent strokes joined end to end would double where they
    // meet.
    for (final double groove in <double>[0, HelixModel.grooveOffset]) {
      Offset? last;
      Path? open;
      bool? side;
      Color? ink;
      Offset? stretchEnd;
      for (final (Color colour, Offset a, Offset b, double from, double to)
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
    double strength(Color c) => math.min(1, c.a / GeneStrand.lineInk) * twist;
    for (final MapEntry<Color, Path> s in back.entries) {
      canvas.drawPath(
        s.value,
        paint
          ..color = shade(
            s.key,
            shaded ? 0.7 : 0.45,
          ).withValues(alpha: strength(s.key) * (shaded ? 0.7 : 1) * alpha),
      );
    }
    for (final MapEntry<Color, Path> s in front.entries) {
      canvas.drawPath(
        s.value,
        paint
          ..color = shade(
            s.key,
            shaded ? 0.35 : 0,
          ).withValues(alpha: strength(s.key) * alpha),
      );
    }
  }
}
