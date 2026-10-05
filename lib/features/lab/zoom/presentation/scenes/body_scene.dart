import 'package:flutter/material.dart';

import '../../domain/anatomy_tables.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// How much a scene's callout shows at [frame]: only while the scene is
/// drawn near its own size, so a name reads at its own stop and is gone
/// long before its scene fills the screen or shrinks to a speck.
double calloutPresence(ZoomFrame frame) {
  final double near = frame.view.pixelsPerUnit / frame.size.width;
  final double rise = smoothstep((near - 0.45) / 0.25);
  final double fall = 1 - smoothstep((near - 1.6) / 0.6);
  return frame.opacity * rise * fall;
}

/// The body, standing facing the reader, with the place the path's tissue
/// lies marked.
final class BodyScene extends ZoomScene {
  const BodyScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.body;

  static const double _width = 2.2;

  /// Metres from the top of the head and across the midline, as the body's
  /// units: centred on the view, the head up.
  static Offset inBody(double down, double across) =>
      Offset(across / _width, (down - 0.85) / _width);

  (double, double)? get _place {
    final String? tissue = subject.path.tissue;
    return tissue == null ? null : placeOf(tissue);
  }

  @override
  Offset get portal {
    final (double, double)? place = _place;
    return place == null ? inBody(0.55, 0) : inBody(place.$1, place.$2);
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final String? tissue = subject.path.tissue;
    final Offset target = frame.toScreen(portal);
    out.item('body:target', target, frame.opacity);
    if (tissue != null && _place != null) {
      out.callout('body', tissue, target, calloutPresence(frame));
    }
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final Paint limb = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = frame.inks.scale.bodyFill;
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * pixel
      ..color = frame.inks.scale.bodyEdge;
    void capsule(double d1, double a1, double d2, double a2, double thick) {
      limb.strokeWidth = thick / _width;
      canvas.drawLine(inBody(d1, a1), inBody(d2, a2), limb);
    }

    for (final double side in <double>[-1, 1]) {
      capsule(0.32, side * 0.19, 0.84, side * 0.27, 0.085);
      capsule(0.92, side * 0.085, 1.66, side * 0.11, 0.13);
    }
    final RRect torso = RRect.fromRectAndRadius(
      Rect.fromPoints(inBody(0.27, -0.2), inBody(0.95, 0.2)),
      const Radius.circular(0.07 / _width),
    );
    canvas.drawRRect(torso, Paint()..color = frame.inks.scale.bodyFill);
    canvas.drawRRect(torso, edge);
    capsule(0.19, 0, 0.28, 0, 0.1);
    final Offset head = inBody(0.11, 0);
    canvas.drawCircle(
      head,
      0.1 / _width,
      Paint()..color = frame.inks.scale.bodyFill,
    );
    canvas.drawCircle(head, 0.1 / _width, edge);

    if (_place != null) {
      final Offset at = portal;
      canvas.drawCircle(
        at,
        9 * pixel,
        Paint()..color = frame.inks.mark.withValues(alpha: 0.3),
      );
      canvas.drawCircle(at, 4.5 * pixel, Paint()..color = frame.inks.mark);
    }
    canvas.restore();
  }
}
