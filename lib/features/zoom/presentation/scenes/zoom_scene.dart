import 'package:flutter/material.dart';

import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';

/// What one scene is drawn with at one moment: where the camera has it, on
/// what size of view, how much of it shows, and in what inks.
@immutable
final class ZoomFrame {
  const ZoomFrame({
    required this.view,
    required this.size,
    required this.opacity,
    required this.inks,
    required this.clock,
    this.labels = const TextStyle(fontSize: 12),
    this.unzip = 0,
  });

  /// How far the helix is unzipped into the walk's rows, as the walk opens:
  /// 0 until then.
  final double unzip;

  final ZoomView view;
  final Size size;

  /// The style a scene sets its own small words in: a ruler's numbers.
  final TextStyle labels;

  /// How much of the scene shows, from 0 to 1.
  final double opacity;
  final ZoomInks inks;

  /// Seconds of ambient time, for motion that plays at rest: 0 in tests and
  /// under reduced motion.
  final double clock;

  /// One pixel on screen, in the scene's units.
  double get pixel => 1 / view.pixelsPerUnit;

  /// How far along the segment showing the scene the view is.
  double get progress => view.progress;

  /// Whether the scene is the stop being entered rather than the one left.
  bool get isChild => view.isChild;

  /// How far into its own stop the scene is, from 0 (just appearing inside
  /// the scene before it) to 1 (at its stop) and on to 2 (leaving it for the
  /// next): one number a scene can ease its own beats on.
  double get arrival => isChild ? progress : 1 + progress;

  /// The scene's point [p] on screen.
  Offset toScreen(Offset p) => view.toScreen(p, size);

  /// Moves [canvas] into the scene's units: its origin where the camera has
  /// it and one unit [ZoomView.pixelsPerUnit] pixels.
  void enter(Canvas canvas) {
    final Offset origin = toScreen(Offset.zero);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(view.pixelsPerUnit);
  }
}

/// A label the painter sets in screen space, with a line to what it names.
@immutable
final class ZoomCallout {
  const ZoomCallout({
    required this.key,
    required this.text,
    required this.target,
    required this.opacity,
  });

  final String key;
  final String text;

  /// What it names, on screen.
  final Offset target;
  final double opacity;
}

/// What a scene shows, by key: where each thing it names is on screen and
/// how much of it shows, and the callouts to set. The painter sets the
/// callouts; the smoothness and targets tests read the rest without drawing.
final class ZoomStaging {
  final Map<String, (Offset, double)> items = <String, (Offset, double)>{};
  final List<ZoomCallout> callouts = <ZoomCallout>[];

  void item(String key, Offset at, double opacity) =>
      items[key] = (at, opacity);

  void callout(String key, String text, Offset target, double opacity) {
    if (opacity <= 0) {
      return;
    }
    callouts.add(
      ZoomCallout(key: key, text: text, target: target, opacity: opacity),
    );
    item('callout:$key', target, opacity);
  }
}

/// One stop of the zoom, drawn in its own units: the width of the view at
/// its stop is one unit, and its origin is the middle of that view.
abstract class ZoomScene {
  const ZoomScene();

  ZoomStop get stop;

  /// Where the next stop lies in this scene, in its units.
  Offset get portal => Offset.zero;

  /// How much of the scene shows across the segment that leaves it, at
  /// [progress] along it: by default it gives way to the next stop between a
  /// third and four fifths of the way.
  double asParent(double progress) => 1 - crossfade(progress);

  /// How much of the scene shows across the segment that enters it.
  double asChild(double progress) => crossfade(progress);

  /// What the scene names at [frame], by key and on screen.
  void stage(ZoomFrame frame, ZoomStaging out) {}

  /// Draws the scene. The canvas is the view's, untransformed: a scene
  /// drawn in its units calls [ZoomFrame.enter]; one drawn in base pairs
  /// places its own points through [ZoomFrame.toScreen].
  void paint(Canvas canvas, ZoomFrame frame);
}

/// How much of the stop being entered shows across a segment, while the
/// scenes are crossfaded: none until a third of the way, all by four
/// fifths, so each is seen whole at its own stop.
double crossfade(double progress) => smoothstep((progress - 0.35) / 0.45);
