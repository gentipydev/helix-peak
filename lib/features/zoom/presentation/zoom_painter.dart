import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/zoom_camera.dart';
import '../domain/zoom_depth.dart';
import 'scenes/band_scene.dart';
import 'scenes/body_scene.dart';
import 'scenes/cell_scene.dart';
import 'scenes/chromosome_scene.dart';
import 'scenes/dna_scene.dart';
import 'scenes/nucleus_scene.dart';
import 'scenes/organ_scene.dart';
import 'scenes/tissue_scene.dart';
import 'scenes/zoom_scene.dart';
import 'scenes/zoom_subject.dart';
import 'zoom_inks.dart';

/// The eight scenes of one protein's zoom, and the camera that nests them.
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

  /// The frames the scenes on screen at depth [d] are drawn with, the
  /// ones too faint to see left out.
  List<(ZoomScene, ZoomFrame)> frames(
    double d,
    Size size,
    ZoomInks inks, {
    double clock = 0,
    double dwell = ZoomFrame.settled,
    double unzip = 0,
    TextStyle labels = const TextStyle(fontSize: 12),
  }) => <(ZoomScene, ZoomFrame)>[
    for (final (ZoomScene scene, ZoomView view, double opacity) in visible(
      d,
      size,
    ))
      if (opacity >= 0.005)
        (
          scene,
          ZoomFrame(
            view: view,
            size: size,
            opacity: opacity,
            inks: inks,
            clock: clock,
            dwell: dwell,
            unzip: unzip,
            labels: labels,
          ),
        ),
  ];

  /// What the view shows at depth [d], by key, without drawing it.
  ZoomStaging stage(double d, Size size, ZoomInks inks, {double clock = 0}) {
    final ZoomStaging staging = ZoomStaging();
    for (final (ZoomScene scene, ZoomFrame frame) in frames(
      d,
      size,
      inks,
      clock: clock,
    )) {
      scene.stage(frame, staging);
    }
    return staging;
  }

  /// Whether anything on screen at depth [d] moves on its own, [dwell]
  /// seconds after the depth came to rest.
  bool wantsClock(double d, Size size, ZoomInks inks, {required double dwell}) {
    for (final (ZoomScene scene, ZoomFrame frame) in frames(
      d,
      size,
      inks,
      dwell: dwell,
    )) {
      if (scene.wantsClock(frame)) {
        return true;
      }
    }
    return false;
  }

  final Set<ZoomStop> _prepared = <ZoomStop>{};

  /// Whether every scene has built what it caches.
  bool get prepared => _prepared.length == scenes.length;

  /// Builds what the scene at [stop] caches, the first time it is asked.
  void prepare(ZoomStop stop, ZoomInks inks) {
    if (_prepared.add(stop)) {
      scenes[stop.index].prepare(inks);
    }
  }

  /// The stop nearest [from] whose scene has not built what it caches, the
  /// deeper first of two as near; null once every scene has.
  ZoomStop? unprepared(ZoomStop from) {
    for (int reach = 0; reach < scenes.length; reach++) {
      for (final int i in <int>[from.index + reach, from.index - reach]) {
        if (i >= 0 &&
            i < scenes.length &&
            !_prepared.contains(ZoomStop.values[i])) {
          return ZoomStop.values[i];
        }
      }
    }
    return null;
  }

  /// How much of the body's credit shows at depth [d]: at the body, and
  /// going over the first stretch of the way out, as a name does.
  double creditAt(double d) {
    final (int k, double s) = depth.segmentAt(d);
    return k == ZoomStop.body.index ? 1 - smoothstep(s / around) : 0;
  }
}

/// A continuous zoom from a body to its DNA: the stop being left and the
/// one being entered, nested where the next one lies. Drawn again only when
/// the depth moves: what moves on its own, and the names, are
/// [ZoomOverlayPainter]'s, on the layer above.
class ZoomPainter extends CustomPainter {
  ZoomPainter({
    required this.stage,
    required this.at,
    required this.inks,
    required this.labels,
    this.unzip,
    super.repaint,
  });

  final ZoomStage stage;
  final double Function() at;

  /// How far the helix is unzipped as the walk opens.
  final double Function()? unzip;
  final ZoomInks inks;
  final TextStyle labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
      at(),
      size,
      inks,
      labels: labels,
      unzip: unzip?.call() ?? 0,
    )) {
      if (frame.opacity < 0.995) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, frame.opacity),
        );
        scene.paint(canvas, frame);
        canvas.restore();
      } else {
        scene.paint(canvas, frame);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ZoomPainter old) =>
      old.stage != stage || old.inks != inks || old.labels != labels;
}

/// What lies over the scenes: what moves on its own at rest (each scene's
/// [ZoomScene.paintAmbient], which fades itself with its scene), the names
/// of what the zoom follows, the scale bar, and at the body the credit for
/// what it is drawn from.
class ZoomOverlayPainter extends CustomPainter {
  ZoomOverlayPainter({
    required this.stage,
    required this.at,
    required this.inks,
    required this.labels,
    required this.caption,
    required this.credit,
    this.clock,
    this.dwell,
    this.unzip,
    super.repaint,
  });

  final ZoomStage stage;
  final double Function() at;
  final double Function()? clock;
  final double Function()? dwell;
  final double Function()? unzip;
  final ZoomInks inks;
  final TextStyle labels;

  /// The style the credit is set in: the app's small print.
  final TextStyle caption;

  /// The body's credit: who drew it and whose data lights it.
  final String credit;

  /// How far a name, the scale bar and the credit keep from the canvas's
  /// edges.
  static const double margin = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final double d = at();
    for (final (ZoomScene scene, ZoomFrame frame) in stage.frames(
      d,
      size,
      inks,
      clock: clock?.call() ?? 0,
      dwell: dwell?.call() ?? ZoomFrame.settled,
      unzip: unzip?.call() ?? 0,
      labels: labels,
    )) {
      scene.paintAmbient(canvas, frame);
    }
    final ZoomStaging staging = stage.stage(d, size, inks);
    final List<Rect> placed = <Rect>[];
    for (final ZoomCallout callout in staging.callouts) {
      placed.add(_callout(canvas, size, callout, placed));
    }
    final Rect bar = _scaleBar(canvas, size, d);
    _credit(canvas, size, d, bar);
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

  /// The scale bar at the lower left, and the box it takes.
  Rect _scaleBar(Canvas canvas, Size size, double d) {
    final (double pixels, String label) = scaleBarAt(stage.depth, d, size);
    const double left = scaleBarLeft;
    final double y = size.height - 18;
    final TextPainter measure = TextPainter(
      text: TextSpan(
        text: label,
        // Its figures count as the bar glides: each as wide as the next, so
        // the words do not shuffle.
        style: labels.copyWith(
          color: inks.label,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Rect box = scaleBarBox(pixels, measure.size, size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(6)),
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
    return box;
  }

  /// The credit at the lower right while the body shows, on a second line
  /// where one would meet the scale bar.
  void _credit(Canvas canvas, Size size, double d, Rect bar) {
    final double shown = stage.creditAt(d);
    if (shown <= 0 || credit.isEmpty) {
      return;
    }
    final Rect box = creditBox(credit, caption, size, bar);
    final TextPainter text = creditText(credit, caption, size, bar, shown);
    text.paint(canvas, box.topLeft);
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant ZoomOverlayPainter old) =>
      old.stage != stage ||
      old.inks != inks ||
      old.labels != labels ||
      old.caption != caption ||
      old.credit != credit;
}

/// Where the scale bar starts, from the canvas's left edge.
const double scaleBarLeft = 16;

/// The scale bar's length in pixels and its label at depth [d] on a canvas
/// of [size].
///
/// At a stop it is the round length [scaleBar] picks for the view there.
/// Between two stops it glides from the one stop's length on screen to the
/// next one's as the depth moves, and reads the length it spans as it goes,
/// to two figures. Held to round lengths all the way, it shrank with the
/// view and sprang back long at every 1, 2 and 5 it passed, as many as
/// nineteen times in one step.
(double, String) scaleBarAt(ZoomDepth depth, double d, Size size) {
  double roundAt(ZoomStop stop) {
    final (double _, double pixels, String _) = scaleBar(
      depth.widthOf(stop),
      size.width,
      unit: ZoomDepth.unitOf(stop),
    );
    return pixels;
  }

  final (int k, double s) = depth.segmentAt(d);
  final double from = roundAt(ZoomStop.values[k]);
  final double to = roundAt(ZoomStop.values[k + 1]);
  final double pixels = from + (to - from) * smoothstep(s);
  return (pixels, depth.labelAt(d, pixels / size.width * depth.widthAt(d)));
}

/// The box the scale bar's plate takes on a canvas of [size]: a bar
/// [pixels] long under a label of [label] size.
Rect scaleBarBox(double pixels, Size label, Size size) {
  final double y = size.height - 18;
  return Rect.fromLTRB(
    scaleBarLeft - 8,
    y - 14 - label.height,
    scaleBarLeft + math.max(pixels, label.width) + 8,
    y + 10,
  );
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

/// The credit's words, laid out right-aligned in the room the scale bar
/// [bar] leaves on a canvas of [size], at most two lines.
TextPainter creditText(
  String credit,
  TextStyle caption,
  Size size,
  Rect bar, [
  double opacity = 1,
]) => TextPainter(
  text: TextSpan(
    text: credit,
    style: caption.copyWith(
      color: caption.color?.withValues(
        alpha: (caption.color?.a ?? 1) * opacity,
      ),
    ),
  ),
  textDirection: TextDirection.ltr,
  textAlign: TextAlign.right,
  maxLines: 2,
)..layout(maxWidth: size.width - bar.right - 2 * ZoomOverlayPainter.margin);

/// Where the credit goes: its lines' box against the lower right corner,
/// level with the scale bar's foot.
Rect creditBox(String credit, TextStyle caption, Size size, Rect bar) {
  final TextPainter text = creditText(credit, caption, size, bar);
  final Size box = text.size;
  text.dispose();
  return Rect.fromLTWH(
    size.width - ZoomOverlayPainter.margin - box.width,
    bar.bottom - box.height,
    box.width,
    box.height,
  );
}

/// Where a callout's plate goes for words of [text] size naming [target] on
/// a canvas of [size]: up and to the right where there is room, else at the
/// first corner that keeps it on the canvas, clear of the plates already
/// [placed].
Rect placePlate(Offset target, Size text, Size size, List<Rect> placed) {
  final double plateW = text.width + 2 * plateTextPadding;
  final double plateH = text.height + plateTextPadding;
  final double right = size.width - ZoomOverlayPainter.margin;
  final double bottom = size.height - 40;
  Rect at(double dx, double dy) {
    final double x = (dx >= 0 ? target.dx + dx : target.dx + dx - plateW).clamp(
      ZoomOverlayPainter.margin,
      math.max(ZoomOverlayPainter.margin, right - plateW),
    );
    final double y = (target.dy + dy - plateH / 2).clamp(
      ZoomOverlayPainter.margin,
      math.max(ZoomOverlayPainter.margin, bottom - plateH),
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
