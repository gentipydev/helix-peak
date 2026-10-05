import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The organ the path's tissue is in, seen whole, with the place the tissue
/// level closes on marked at its centre.
final class OrganScene extends ZoomScene {
  OrganScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.organ;

  late final Path _shape = () {
    final Path shape = Path();
    const int points = 90;
    for (int i = 0; i <= points; i++) {
      final double a = 2 * math.pi * i / points;
      final double r =
          0.3 +
          0.035 * math.sin(3 * a + 0.4) +
          0.02 * math.sin(5 * a + 1.3) +
          0.012 * math.sin(9 * a);
      final Offset p = Offset(r * math.cos(a) * 1.15, r * math.sin(a) * 0.85);
      i == 0 ? shape.moveTo(p.dx, p.dy) : shape.lineTo(p.dx, p.dy);
    }
    return shape..close();
  }();

  // It stays under the loupe until the eyepiece's dark has covered it.
  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.7) / 0.3);

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset target = frame.toScreen(Offset.zero);
    out.item('organ:target', target, frame.opacity);
    final String? tissue = subject.path.tissue;
    out.callout(
      'organ',
      tissue ?? 'an organ, any',
      frame.toScreen(const Offset(0, -0.3)),
      calloutPresence(frame),
    );
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    canvas.drawPath(_shape, Paint()..color = frame.inks.scale.organ);
    canvas.drawPath(
      _shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * pixel
        ..color = frame.inks.scale.organEdge,
    );
    final Paint lobule = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * pixel
      ..color = frame.inks.scale.organEdge.withValues(alpha: 0.5);
    for (int ring = 1; ring <= 3; ring++) {
      for (int k = 0; k < ring * 6; k++) {
        final double a = 2 * math.pi * k / (ring * 6) + ring;
        final Offset c = Offset(
          math.cos(a) * ring * 0.075 * 1.1,
          math.sin(a) * ring * 0.075 * 0.8,
        );
        canvas.drawCircle(c, 0.028, lobule);
      }
    }
    canvas.drawCircle(
      Offset.zero,
      0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = frame.inks.mark,
    );
    canvas.restore();
  }
}
