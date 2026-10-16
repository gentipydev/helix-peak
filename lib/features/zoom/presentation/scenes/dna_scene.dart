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
import 'chromatin_fibre.dart';
import 'gene_strand.dart';
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
/// - its nucleosomes, each a histone core with its DNA wound round it, as
///   the gene's stop draws them ([ChromatinFibre]), come up between the
///   ones the stop shows, grow from larger than life to their own size,
///   and wind in the DNA between them, so the line is seen to be beads on a
///   string ([ChromatinLayout]); the stretch round the start, which a gene
///   being read keeps bare, stays where it is, and the first of them is
///   named;
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

  /// How much narrower the view gets, from where the nucleosomes start to
  /// wind in the DNA between them, before the fibre is packed.
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

  /// How far the fibre is packed: the nucleosomes winding in the DNA
  /// between them ([ChromatinLayout]).
  double packedAt(double span) => _between(span, _winds, _winds / windsOver);

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

  /// How far the fibre is packed at [frame].
  @visibleForTesting
  double packedShown(ZoomFrame frame) => packedAt(_span(frame));

  /// How much of nucleosome [index] shows at [frame]
  /// ([ChromatinBeads.shownAt]): the ones the gene's stop shows whole, the
  /// ones between coming up as the view closes in.
  @visibleForTesting
  double beadShown(int index, ZoomFrame frame) => ChromatinBeads.shownAt(
    index,
    frame.progress,
    gene: _gene,
    width: frame.size.width,
    dive: subject.depth.dive,
  );

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
  /// of its name shows. Named once it is packed and big enough to read as
  /// a bead, until the bases come up beside it.
  (Offset, double, double) _firstCore(ZoomFrame frame) {
    final double span = _span(frame);
    final double perBase = frame.size.width / span;
    final double centre = chromatin.coreAt(
      ChromatinLayout.first,
      packedAt(span),
    );
    final Offset at = Offset(_x(frame, centre), frame.size.height / 2);
    // How far below its middle the bead reaches: about its superhelix's
    // radius, as large as it is drawn.
    final double reach =
        ChromatinLayout.radius * ChromatinFibre.magnified(perBase) * perBase;
    // Keyed to the view's width alone, over windows wide enough in its log
    // for the step to take its time over them: in as the beads grow from a
    // dozen pixels to some twenty, packed by then; out before the bases.
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
    final double sunk = sunkAt(span);
    // The line the gene's stop draws, thickening to the DNA's own width as
    // the exons sink into it.
    final double thick =
        GeneStrand.line +
        math.max(0, thickness * perBase - GeneStrand.line) * sunk;
    final ZoomInks inks = frame.inks;
    final GeneLayout layout = subject.layout;
    final double scale = _scale;
    final double end = layout.length * scale;
    final double around = contextAt(span);
    // The exons' colours, taken on as they sink and given up before the
    // bases come.
    final double tint = sunk * tintAt(span);
    final double helix = helixAt(span);
    final int bare = subject.dnaBases;
    ChromatinFibre.paint(
      canvas,
      inks,
      x: (double along) => _x(frame, along),
      perBase: perBase,
      mid: mid,
      width: w,
      packed: packedAt(span),
      thick: thick,
      // As the bare start becomes the helix the rest of the DNA shows its
      // twist too: two strands round its grooves, as the helix's own are.
      twist: helix,
      marks: <double>[...subject.fibreMarks, bare.toDouble()],
      // The gene's, its exons tinted as they fade; the DNA either side of it
      // as it comes and goes; the bare start giving way to the helix.
      colourAt: (double offset) {
        final Color ink = GeneStrand.ink(
          inks,
          layout.kindAt(offset / scale),
          tint,
        );
        double alpha = 1;
        if (offset < 0 || offset > end) {
          alpha = around;
        } else if (offset < bare) {
          alpha = 1 - helix;
        }
        return ink.withValues(alpha: ink.a * alpha);
      },
      depth: ChromatinBeads.depthShownAt(
        frame.progress,
        gene: _gene,
        width: w,
        dive: subject.depth.dive,
      ),
      shownOf: (int index) {
        final double place = ChromatinBeads.placeOf(index);
        return beadShown(index, frame) *
            (place < 0 || place > end ? around : 1);
      },
    );
    if (sunk < 1) {
      GeneStrand.paint(
        canvas,
        inks,
        layout,
        x: (double offset) => screenX(frame, offset),
        mid: mid,
        width: w,
        sink: sunk,
        thick: thick,
      );
    }
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
