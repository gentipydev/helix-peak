import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/helix/helix_geometry.dart';
import '../../../../shared/ribosome/molecular_material.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The DNA at the gene's 5′ end, as chromatin packs it and as the double
/// helix holds its bases.
///
/// From a view a few thousand base pairs wide, the gene's line is a fibre of
/// nucleosomes: 147 base pairs wrapped round each histone core, one every
/// 200, drawn as the textbook packs a gene and not measured for this one. The
/// stretch at the 5′ end is drawn bare, as the start of a gene that is read
/// usually is. Closer in, the bare end resolves into the double helix with
/// the record's own first bases, turning slowly; as the walk opens it unzips
/// into the walk's rows.
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

  @override
  double asChild(double progress) => smoothstep((progress - 0.08) / 0.45);

  HelixModel? _model;
  double _unzipped = -1;

  HelixModel? _helix(double unzip) {
    final int count = subject.dnaBases;
    if (count < 4) {
      return null;
    }
    final double quantised = (unzip * 60).roundToDouble() / 60;
    if (_model == null || quantised != _unzipped) {
      final String bases = subject.record.sequence;
      _model = HelixModel(
        rungCount: count,
        sampleCount: 3 * count,
        unzip: quantised,
        bases: Uint8List.fromList(<int>[
          for (int i = 0; i < count; i++) HelixPalette.ofBase(bases[i]),
        ]),
      );
      _unzipped = quantised;
    }
    return _model;
  }

  /// A point [offset] base pairs from the 5′ end, in the scene's units.
  double unitAlong(double offset) => (offset - subject.dnaMiddle) * pitch;

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
    // The fibre's line gives way to the helix as the bases come up.
    final double helix = smoothstep((420 - span) / 260);
    final double line = 1 - smoothstep((180 - span) / 100);
    if (line > 0) {
      canvas.drawLine(
        Offset(0, mid),
        Offset(w, mid),
        Paint()
          ..strokeWidth = 2
          ..color = frame.inks.scale.backbone.withValues(alpha: 0.7 * line),
      );
    }
    _nucleosomes(canvas, frame, perBase, mid);
    if (helix > 0) {
      _drawHelix(canvas, frame, helix);
    }
  }

  void _nucleosomes(Canvas canvas, ZoomFrame frame, double perBase, double mid) {
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
        frame.inks.scale.backbone,
        0.55,
      )!.withValues(alpha: show);
      canvas.drawPath(behind, dna);
      canvas.drawRRect(
        RRect.fromRectAndRadius(core, Radius.circular(height * 0.42)),
        Paint()
          ..shader = MolecularMaterial.residueShader(
            core,
            frame.inks.scale.histone.withValues(alpha: show),
          ),
      );
      dna.color = frame.inks.scale.backbone.withValues(alpha: show);
      canvas.drawPath(front, dna);
    }
  }

  /// The wrap of DNA round [core], from where it comes in at [a] to where it
  /// leaves at [b]: a coil of 1.65 turns about the core's long axis, split
  /// into the strokes that pass behind the core and those that pass in front.
  void _wrap(Rect core, double a, double b, double mid, Path behind, Path front) {
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
    final HelixModel? model = _helix(frame.unzip);
    if (model == null) {
      return;
    }
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    const double turn = pitch * HelixModel.basePairsPerTurn;
    const double radius = turn / (2 * HelixModel.pitchPerDiameter);
    final double length = subject.dnaBases * pitch;
    // A slow turn about the axis, stilled as the strands lay flat.
    final double phase =
        2 * math.pi * frame.clock / 16 * (1 - smoothstep(frame.unzip));
    final double cosPhase = math.cos(phase);
    final double sinPhase = math.sin(phase);
    final List<(double, Offset, Offset, int, int)> parts =
        <(double, Offset, Offset, int, int)>[];
    double depthOf(int i) =>
        model.pointSin[i] * cosPhase + model.pointCos[i] * sinPhase;
    Offset place(int i) => Offset(
      model.pointAxial[i] * length,
      (model.pointCos[i] * cosPhase - model.pointSin[i] * sinPhase) * radius,
    );
    for (int p = 0; p < model.primitiveCount; p++) {
      final int kind = model.primKind[p];
      if (kind == HelixPrimitiveKind.transcriptSegment ||
          kind == HelixPrimitiveKind.transcriptNode) {
        continue;
      }
      final int a = model.primStart[p];
      final int z = model.primEnd[p];
      parts.add((
        (depthOf(a) + depthOf(z)) / 2,
        place(a),
        place(z),
        kind,
        model.primPalette[p],
      ));
    }
    parts.sort(
      (
        (double, Offset, Offset, int, int) x,
        (double, Offset, Offset, int, int) y,
      ) => x.$1.compareTo(y.$1),
    );
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Color far = frame.inks.ground;
    for (final (double depth, Offset a, Offset z, int kind, int slot)
        in parts) {
      final double shade = 0.45 + 0.55 * (depth + 1) / 2;
      final Color colour = switch (slot) {
        HelixPalette.adenine => frame.inks.bases.adenine,
        HelixPalette.thymine => frame.inks.bases.thymine,
        HelixPalette.guanine => frame.inks.bases.guanine,
        HelixPalette.cytosine => frame.inks.bases.cytosine,
        _ => frame.inks.scale.backbone,
      };
      final Color lit = Color.lerp(far, colour, shade)!.withValues(alpha: alpha);
      if (kind == HelixPrimitiveKind.node) {
        canvas.drawCircle(a, 3.2 * pixel, Paint()..color = lit);
        continue;
      }
      stroke
        ..color = lit
        ..strokeWidth =
            (kind == HelixPrimitiveKind.strandSegment ? 2.4 : 3.2) * pixel;
      canvas.drawLine(a, z, stroke);
    }
    canvas.restore();
  }
}
