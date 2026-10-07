import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'organ_art.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The organ the path's tissue is in, seen whole, with the place the tissue
/// is sampled ringed in it.
///
/// It is the outline the body drew for it ([OrganArt]), so the step from
/// the body is one shape seen closer: this scene comes up over the body's
/// own drawing of the organ early in the step, then grows the organ from
/// the size the anatomogram draws it to the size it is, as the body gives
/// way round it. The scale bar is then true of it.
final class OrganScene extends ZoomScene {
  OrganScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.organ;

  late final OrganArt _art = OrganArt.of(subject);

  /// Whether the organ is the body's own outline of it, seen closer.
  bool get followsBody => _art.followsBody;

  /// How much of the organ's own scene shows, [progress] of the way in from
  /// the body: it takes the organ over from the body's drawing early.
  static double entering(double progress) =>
      smoothstep((progress - 0.1) / 0.45);

  @override
  double asChild(double progress) => entering(progress);

  // It stays under the loupe until the eyepiece's dark has covered it.
  @override
  double asParent(double progress) => 1 - smoothstep((progress - 0.7) / 0.3);

  /// How large the organ is drawn at [frame], against its real size: the
  /// anatomogram's size while the body still shows, its own by the stop.
  double _grown(ZoomFrame frame) => frame.isChild
      ? math
            .pow(_art.real, smootherstep((frame.progress - 0.45) / 0.55) - 1)
            .toDouble()
      : 1;

  // The tissue is sampled where the organ's drawing says, not at its
  // middle.
  @override
  Offset get portal => _art.site;

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    out.item(
      'organ:target',
      frame.toScreen(_art.site * _grown(frame)),
      frame.opacity,
    );
    out.callout(
      'organ',
      subject.path.tissue ?? 'an organ, any',
      frame.toScreen(_art.named * _grown(frame)),
      calloutPresence(frame),
    );
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double grown = _grown(frame);
    _art.paint(canvas, frame.inks, frame.pixel, grown);
    // Where the tissue is sampled.
    canvas.drawCircle(
      _art.site * grown,
      0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * frame.pixel
        ..color = frame.inks.mark,
    );
    canvas.restore();
  }
}
