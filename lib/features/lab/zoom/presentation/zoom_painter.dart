import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/zoom_camera.dart';
import '../domain/zoom_depth.dart';
import 'scenes/band_scene.dart';
import 'scenes/body_scene.dart';
import 'scenes/cell_scene.dart';
import 'scenes/chromosome_scene.dart';
import 'scenes/dna_scene.dart';
import 'scenes/gene_scene.dart';
import 'scenes/nucleus_scene.dart';
import 'scenes/organ_scene.dart';
import 'scenes/tissue_scene.dart';
import 'scenes/zoom_scene.dart';
import 'scenes/zoom_subject.dart';
import 'zoom_inks.dart';

/// The nine scenes of one protein's zoom, and the camera that nests them.
final class ZoomStage {
  ZoomStage(this.subject)
    : scenes = <ZoomScene>[
        BodyScene(subject),
        OrganScene(subject),
        TissueScene(subject),
        CellScene(subject),
        NucleusScene(subject),
        ChromosomeScene(subject),
        BandScene(subject),
        GeneScene(subject),
        DnaScene(subject),
      ] {
    camera = ZoomCamera(
      subject.depth,
      portalOf: (ZoomStop stop) => scenes[stop.index].portal,
    );
  }

  final ZoomSubject subject;
  final List<ZoomScene> scenes;
  late final ZoomCamera camera;

  ZoomDepth get depth => subject.depth;

  /// The scenes on screen at depth [d], each with how much of it shows.
  List<(ZoomScene, ZoomView, double)> visible(double d, Size size) {
    final (ZoomView parent, ZoomView child) = camera.at(d, size);
    final ZoomScene leaving = scenes[parent.stop.index];
    final ZoomScene entering = scenes[child.stop.index];
    return <(ZoomScene, ZoomView, double)>[
      (leaving, parent, leaving.asParent(parent.progress)),
      (entering, child, entering.asChild(child.progress)),
    ];
  }

  /// What the view shows at depth [d], by key, without drawing it.
  ZoomStaging stage(double d, Size size, ZoomInks inks, {double clock = 0}) {
    final ZoomStaging staging = ZoomStaging();
    for (final (ZoomScene scene, ZoomView view, double opacity)
        in visible(d, size)) {
      if (opacity < 0.005) {
        continue;
      }
      scene.stage(
        ZoomFrame(
          view: view,
          size: size,
          opacity: opacity,
          inks: inks,
          clock: clock,
        ),
        staging,
      );
    }
    return staging;
  }
}

/// A continuous zoom from a body to its DNA: the stop being left and the
/// one being entered, nested where the next one lies, then the names of
/// what the zoom follows and a scale bar.
class ZoomPainter extends CustomPainter {
  ZoomPainter({
    required this.stage,
    required this.at,
    required this.inks,
    required this.labels,
    this.clock,
    this.unzip,
    super.repaint,
  });

  final ZoomStage stage;
  final double Function() at;
  final double Function()? clock;

  /// How far the helix is unzipped as the walk opens.
  final double Function()? unzip;
  final ZoomInks inks;
  final TextStyle labels;

  /// The strip down the right edge the rail lies in: no name is set there.
  static const double railStrip = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final double d = at();
    final double time = clock?.call() ?? 0;
    for (final (ZoomScene scene, ZoomView view, double opacity)
        in stage.visible(d, size)) {
      if (opacity < 0.005) {
        continue;
      }
      final ZoomFrame frame = ZoomFrame(
        view: view,
        size: size,
        opacity: opacity,
        inks: inks,
        clock: time,
        labels: labels,
        unzip: unzip?.call() ?? 0,
      );
      if (opacity < 0.995) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
        );
        scene.paint(canvas, frame);
        canvas.restore();
      } else {
        scene.paint(canvas, frame);
      }
    }
    final ZoomStaging staging = stage.stage(d, size, inks, clock: time);
    final List<Rect> placed = <Rect>[];
    for (final ZoomCallout callout in staging.callouts) {
      placed.add(_callout(canvas, size, callout, placed));
    }
    _scaleBar(canvas, size, d);
    canvas.restore();
  }

  /// A name on a plate, beside what it names, with a line that lands on it.
  Rect _callout(
    Canvas canvas,
    Size size,
    ZoomCallout callout,
    List<Rect> placed,
  ) {
    final TextPainter text = calloutText(callout, labels, inks, size);
    final Rect plate = placePlate(callout.target, text.size, size, placed);
    final Offset target = callout.target;
    final Offset from = Offset(
      target.dx.clamp(plate.left, plate.right),
      target.dy.clamp(plate.top, plate.bottom),
    );
    final Paint line = Paint()
      ..strokeWidth = 1.2
      ..color = inks.mark.withValues(alpha: callout.opacity);
    canvas.drawLine(from, target, line);
    canvas.drawCircle(target, 2.6, line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, const Radius.circular(6)),
      Paint()..color = inks.raised.withValues(alpha: 0.88 * callout.opacity),
    );
    text.paint(
      canvas,
      Offset(plate.left + plateTextPadding, plate.top + plateTextPadding / 2),
    );
    text.dispose();
    return plate;
  }

  void _scaleBar(Canvas canvas, Size size, double d) {
    final ZoomDepth depth = stage.depth;
    final (double _, double pixels, String label) = scaleBar(
      depth.widthAt(d),
      size.width,
      unit: depth.unitAt(d),
    );
    const double left = 16;
    final double y = size.height - 18;
    final TextPainter measure = TextPainter(
      text: TextSpan(
        text: label,
        style: labels.copyWith(color: inks.label),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          left - 8,
          y - 14 - measure.height,
          left + math.max(pixels, measure.width) + 8,
          y + 10,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = inks.ground.withValues(alpha: 0.8),
    );
    final Paint bar = Paint()
      ..strokeWidth = 2
      ..color = inks.label;
    canvas.drawLine(Offset(left, y), Offset(left + pixels, y), bar);
    canvas.drawLine(Offset(left, y - 4), Offset(left, y + 4), bar);
    canvas.drawLine(
      Offset(left + pixels, y - 4),
      Offset(left + pixels, y + 4),
      bar,
    );
    measure.paint(canvas, Offset(left, y - 8 - measure.height));
    measure.dispose();
  }

  @override
  bool shouldRepaint(covariant ZoomPainter old) =>
      old.stage != stage || old.inks != inks || old.labels != labels;
}

/// How far a callout's words sit inside its plate.
const double plateTextPadding = 6;

/// A callout's words, laid out as the painter sets them.
TextPainter calloutText(
  ZoomCallout callout,
  TextStyle labels,
  ZoomInks inks,
  Size size,
) => TextPainter(
  text: TextSpan(
    text: callout.text,
    style: labels.copyWith(color: inks.text.withValues(alpha: callout.opacity)),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 2,
)..layout(maxWidth: size.width * 0.55);

/// Where a callout's plate goes for words of [text] size naming [target] on
/// a canvas of [size]: up and to the right where there is room, else at the
/// first corner that keeps it on the canvas, clear of the rail and of the
/// plates already [placed].
Rect placePlate(Offset target, Size text, Size size, List<Rect> placed) {
  final double plateW = text.width + 2 * plateTextPadding;
  final double plateH = text.height + plateTextPadding;
  final double right = size.width - ZoomPainter.railStrip - 4;
  final double bottom = size.height - 40;
  Rect at(double dx, double dy) {
    final double x = (dx >= 0 ? target.dx + dx : target.dx + dx - plateW).clamp(
      8.0,
      math.max(8.0, right - plateW),
    );
    final double y = (target.dy + dy - plateH / 2).clamp(
      8.0,
      math.max(8.0, bottom - plateH),
    );
    return Rect.fromLTWH(x, y, plateW, plateH);
  }

  final List<Rect> choices = <Rect>[
    at(24, -30),
    at(24, 30),
    at(-24, -30),
    at(-24, 30),
    at(24, -36 - plateH),
    at(24, 36 + plateH),
    at(-24, -36 - plateH),
    at(-24, 36 + plateH),
  ];
  for (final Rect choice in choices) {
    if (placed.every((Rect r) => !r.inflate(4).overlaps(choice))) {
      return choice;
    }
  }
  return choices.first;
}

