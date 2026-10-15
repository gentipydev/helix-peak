import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/helix/dna_helix_painter.dart';
import '../../../../shared/helix/helix_geometry.dart';
import '../../../../shared/ribosome/molecular_material.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'body_scene.dart';
import 'gene_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The DNA at the gene's 5′ end, as chromatin packs it and as the double
/// helix holds its bases: what the gene's stop opens into as the view closes
/// in on its 5′ end, its exons giving way ([GeneScene.exonsShownAt]).
///
/// It reads 5′ to 3′, left to right, as the walk does, whatever the gene's
/// strand, as the gene's stop does. From a view a few thousand base pairs
/// wide, the gene's line is a fibre of nucleosomes: 147 base pairs wrapped
/// round each histone core, one every 200, drawn as the textbook packs a gene
/// and not measured for this one. The stretch at the 5′ end is drawn bare, as
/// the start of a gene that is read usually is. Closer in, the bare end
/// resolves into the home screen's own double helix ([DnaHelixPainter]),
/// lying along the gene with its 5′ end at the left, carrying the record's
/// first bases in the bases' own colours, turning as the home screen's does.
/// Unlike the home screen's, nothing reads it: no bubble opens and no
/// transcript trails from it, so the helix stays whole, every base paired. As
/// the walk opens it unzips into the walk's rows, its turn easing until they
/// lie flat.
final class DnaScene extends ZoomScene {
  DnaScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.dna;

  /// One base pair along the axis, in the scene's units.
  static const double pitch = 1 / ZoomDepth.dnaBasePairs;

  /// Where nucleosomes sit, in base pairs from the 5′ end: the first a
  /// little way into the gene, one every [period] after it, and one before
  /// the bare stretch at its start.
  static const double first = 40;
  static const double period = 200;
  static const double wrapped = 147;

  // The chromatin comes up as soon as the step from the gene begins: for a
  // short gene its beads are already big enough to read there.
  @override
  double asChild(double progress) => smoothstep((progress - 0.02) / 0.45);

  /// The home screen's helix as its painter draws it, in the painter's own
  /// pixels: its radius, and its length for each base pair.
  static const double helixRadius = HelixModel.defaultRadius;
  static const double helixPerBase =
      HelixModel.defaultPitch / HelixModel.basePairsPerTurn;

  /// How long a turn takes, as on the home screen.
  static const double turnSeconds = 24;

  final ProxyAnimation _rotation = ProxyAnimation(kAlwaysDismissedAnimation);
  static const Animation<double> _still = AlwaysStoppedAnimation<double>(0);

  DnaHelixPainter? _painter;
  ZoomInks? _painted;
  double _unzipped = -1;

  /// The painter for the helix in [inks], [unzip] of the way unzipped, made
  /// again only when it unzips a step further or the inks change.
  DnaHelixPainter? _helix(ZoomInks inks, double unzip) {
    final int count = subject.dnaBases;
    if (count < 4) {
      return null;
    }
    final double quantised = (unzip * 60).roundToDouble() / 60;
    if (_painter == null || quantised != _unzipped || _painted != inks) {
      final String bases = subject.record.sequence;
      _painter = DnaHelixPainter(
        repaint: _rotation,
        rotation: _rotation,
        drift: _still,
        transcription: null,
        model: HelixModel(
          rungCount: count,
          sampleCount: 3 * count,
          unzip: quantised,
          // The 3′ end first: the painter's first rung comes to lie at the
          // right, the gene's 3′ side.
          bases: Uint8List.fromList(<int>[
            for (int i = count - 1; i >= 0; i--) HelixPalette.ofBase(bases[i]),
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
      );
      _painted = inks;
      _unzipped = quantised;
    }
    return _painter;
  }

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
    out.item('dna:5', five, frame.opacity);
    out.callout('dna', '5′', five, calloutPresence(frame));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final double w = frame.size.width;
    final double mid = frame.size.height / 2;
    final double span = _span(frame);
    final double perBase = w / span;
    // The fibre's line comes up with its beads and as the gene's exons,
    // which lie over it, give way, and gives way to the helix as the bases
    // come up.
    final double line =
        smoothstep((wrapped * perBase - 2) / 10) *
        (1 - GeneScene.exonsShownAt(span, subject.depth)) *
        (1 - smoothstep((180 - span) / 100));
    if (line > 0) {
      canvas.drawLine(
        Offset(0, mid),
        Offset(w, mid),
        Paint()
          ..strokeWidth = 2
          ..color = frame.inks.label.withValues(alpha: 0.7 * line),
      );
    }
    _nucleosomes(canvas, frame, perBase, mid);
  }

  /// How much of the helix shows at [frame]: it comes up as its bases
  /// grow big enough to tell apart.
  double _helixShown(ZoomFrame frame) => smoothstep((420 - _span(frame)) / 260);

  @override
  void prepare(ZoomInks inks) => _helix(inks, 0);

  @override
  bool wantsClock(ZoomFrame frame) => _helixShown(frame) > 0;

  // The helix turns at rest, so it is drawn over the scene on the ambient
  // clock, and fades there with the scene itself.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    final double helix = _helixShown(frame);
    if (helix <= 0) {
      return;
    }
    _drawHelix(canvas, frame, helix * frame.opacity);
  }

  void _nucleosomes(
    Canvas canvas,
    ZoomFrame frame,
    double perBase,
    double mid,
  ) {
    final double width = wrapped * perBase;
    // Beads come up once they are big enough to read as beads, and give way
    // to the helix's own bases before one fills the view.
    final double show =
        smoothstep((width - 4) / 12) * (1 - smoothstep((width - 220) / 220));
    if (show <= 0) {
      return;
    }
    final double w = frame.size.width;
    final double gene = subject.layout.length;
    final List<double> starts = <double>[
      first - period - wrapped - 60,
      for (double at = first; at < gene; at += period) at,
    ];
    // A core seen side on: a disc about twice as wide as it is thick.
    final double height = math.min(width * 0.52, frame.size.height * 0.36);
    final double strand = math.max(1.6, height * 0.075);
    for (final double start in starts) {
      final double a = _x(frame, start);
      final double b = _x(frame, start + wrapped);
      if (b < -width || a > w + width) {
        continue;
      }
      final Rect core = Rect.fromCenter(
        center: Offset((a + b) / 2, mid),
        width: (b - a).abs() * 0.86,
        height: height,
      );
      // The DNA's 1.65 turns round the core: the half behind it first, then
      // the core, then the half in front.
      final Path behind = Path();
      final Path front = Path();
      if (width > 24) {
        _wrap(core, a, b, mid, behind, front);
      }
      final Paint dna = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strand
        ..strokeCap = StrokeCap.round;
      dna.color = Color.lerp(
        frame.inks.ground,
        frame.inks.label,
        0.55,
      )!.withValues(alpha: show);
      canvas.drawPath(behind, dna);
      canvas.drawRRect(
        RRect.fromRectAndRadius(core, Radius.circular(height * 0.42)),
        Paint()
          ..shader = MolecularMaterial.residueShader(
            core,
            frame.inks.lit(0.42).withValues(alpha: show),
          ),
      );
      dna.color = frame.inks.label.withValues(alpha: show);
      canvas.drawPath(front, dna);
    }
  }

  /// The wrap of DNA round [core], from where it comes in at [a] to where it
  /// leaves at [b]: a coil of 1.65 turns about the core's long axis, split
  /// into the strokes that pass behind the core and those that pass in front.
  void _wrap(
    Rect core,
    double a,
    double b,
    double mid,
    Path behind,
    Path front,
  ) {
    const int steps = 80;
    const double turns = 1.65;
    final double left = math.min(a, b);
    final double right = math.max(a, b);
    final double reach = core.height * 0.62;
    Offset at(int i) {
      final double t = i / steps;
      final double phase = 2 * math.pi * turns * t - math.pi / 2;
      return Offset(left + (right - left) * t, mid + math.sin(phase) * reach);
    }

    bool inFront(int i) {
      final double t = (i + 0.5) / steps;
      return math.cos(2 * math.pi * turns * t - math.pi / 2) > 0;
    }

    Offset previous = at(0);
    for (int i = 0; i < steps; i++) {
      final Offset next = at(i + 1);
      final Path path = inFront(i) ? front : behind;
      path
        ..moveTo(previous.dx, previous.dy)
        ..lineTo(next.dx, next.dy);
      previous = next;
    }
  }

  void _drawHelix(Canvas canvas, ZoomFrame frame, double alpha) {
    final DnaHelixPainter? painter = _helix(frame.inks, frame.unzip);
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
    final double scale = frame.view.pixelsPerUnit * pitch / helixPerBase;
    final double length = subject.dnaBases * helixPerBase;
    final Size page = Size(helixRadius * 4.4, length * 1.3);
    final double mid = frame.size.height / 2;
    final double w = frame.size.width;
    final bool fading = alpha < 0.995;
    if (fading) {
      canvas.saveLayer(
        Offset.zero & frame.size,
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
    }
    canvas.save();
    canvas.translate(_x(frame, subject.dnaMiddle), mid);
    canvas.scale(scale);
    canvas.rotate(math.pi / 2);
    canvas.translate(-page.width / 2, -page.height / 2);
    painter.paint(canvas, page);
    canvas.restore();
    // Its 3′ side runs off into the ground at the canvas's right edge, as
    // the home screen's runs off its own.
    final Rect fade = Rect.fromLTRB(w * 0.72, 0, w, frame.size.height);
    canvas.drawRect(
      fade,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            frame.inks.ground.withValues(alpha: 0),
            frame.inks.ground,
          ],
        ).createShader(fade),
    );
    if (fading) {
      canvas.restore();
    }
  }
}
