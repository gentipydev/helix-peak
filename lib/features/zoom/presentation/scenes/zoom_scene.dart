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
    this.dwell = settled,
  });

  /// A dwell long past every arrival's beat: where nothing moves on its own
  /// (tests, reduced motion), each stop is drawn as its beats leave it.
  static const double settled = 1e6;

  /// Seconds since the depth last came to rest at a stop: the clock a
  /// stop's arrival beats run on, once each time it is reached.
  final double dwell;

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

/// A shape whose names are set round it, outside it, each in the corner of
/// the canvas nearest what it names ([ZoomCallout.ring]): a cell, and the
/// names of its parts.
@immutable
final class ZoomRing {
  const ZoomRing(this.key, this.outline);

  /// Which shape it is: the names set round one are laid out together.
  final String key;

  /// Its outline on screen, a closed loop of points.
  final List<Offset> outline;
}

/// A label the painter sets in screen space, with a line to what it names.
@immutable
final class ZoomCallout {
  const ZoomCallout({
    required this.key,
    required this.text,
    required this.target,
    required this.opacity,
    this.anchors = const <Offset>[],
    this.flush = false,
    this.quiet = false,
    this.row,
    this.ring,
  });

  final String key;
  final String text;

  /// What it names, on screen.
  final Offset target;
  final double opacity;

  /// Where its plate may be set, on screen, in order, reaching on away from
  /// [target]: for a name that would hide what lies round its target. Where
  /// none of them has room, the plate is set beside the target.
  final List<Offset> anchors;

  /// Whether its plate is set out against the canvas's edge on the side of
  /// [target] its anchor is on, level with the anchor, rather than at it:
  /// the anchor is then as near what it names as the plate may come. For
  /// names set in a column down either side of what they name.
  final bool flush;

  /// Whether it names a landmark rather than the gene or what it makes: its
  /// line is then in the quiet ink, the mark being the gene's.
  final bool quiet;

  /// Where the top of its plate is, on screen, for a name set in a row with
  /// the others there ([rowPlates]): each as near over what it names as the
  /// others leave it, in their order along the row, so no line crosses a
  /// plate. Null for a name the painter places on its own.
  final double? row;

  /// The shape the name is set round, outside it ([ringPlates]): in the
  /// band above or below it nearer what it names, out at the canvas's edge
  /// on the side of it what it names is on, its words on two lines where
  /// one would not fit there. Null for a name set otherwise.
  final ZoomRing? ring;
}

/// Where a name set in a column at the canvas's edge ([ZoomCallout.flush])
/// may be set, for what lies on [side] of a shape, -1 its left and 1 its
/// right, whose edges level with what it names are [left] and [right] on
/// screen: 14 px off its edge on that side, level with what it names, or a
/// little below or above it where another name is there, and only then on
/// the other side.
List<Offset> columnAnchors(double side, Offset left, Offset right) {
  Offset beside(double s, double dy) =>
      (s < 0 ? left : right) + Offset(s * 14, dy);
  return <Offset>[
    beside(side, 0),
    beside(side, 34),
    beside(side, -34),
    beside(-side, 0),
  ];
}

/// What a scene shows, by key: where each thing it names is on screen and
/// how much of it shows, and the callouts to set. The painter sets the
/// callouts; the smoothness and targets tests read the rest without drawing.
final class ZoomStaging {
  final Map<String, (Offset, double)> items = <String, (Offset, double)>{};
  final List<ZoomCallout> callouts = <ZoomCallout>[];

  void item(String key, Offset at, double opacity) =>
      items[key] = (at, opacity);

  void callout(
    String key,
    String text,
    Offset target,
    double opacity, {
    List<Offset> anchors = const <Offset>[],
    bool flush = false,
    bool quiet = false,
    double? row,
    ZoomRing? ring,
  }) {
    if (opacity <= 0) {
      return;
    }
    callouts.add(
      ZoomCallout(
        key: key,
        text: text,
        target: target,
        opacity: opacity,
        anchors: anchors,
        flush: flush,
        quiet: quiet,
        row: row,
        ring: ring,
      ),
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
  ///
  /// It is drawn again only when the depth moves, so nothing here may run on
  /// [ZoomFrame.clock] or [ZoomFrame.dwell]: what moves on its own is drawn
  /// in [paintAmbient].
  void paint(Canvas canvas, ZoomFrame frame);

  /// Draws, over [paint], what moves at rest: a helix turning, vesicles
  /// crossing a cell, the beats a stop plays as it is reached. Drawn on a
  /// layer of its own, so a stop at rest repaints only this.
  void paintAmbient(Canvas canvas, ZoomFrame frame) {}

  /// Builds what the scene caches for its drawing (reading a late field
  /// builds it), ahead of its first frame: the screen calls it while nothing
  /// moves, or before a step that would draw it, so no frame of a step pays
  /// for it.
  void prepare(ZoomInks inks) {}

  /// Whether the scene, at [frame], still has something moving on its own:
  /// a loop that never ends, or a beat that has not finished. The ambient
  /// clock stops when no scene on screen wants it.
  bool wantsClock(ZoomFrame frame) => false;
}

/// How much of the stop being entered shows across a segment, while the
/// scenes are crossfaded: none until a third of the way, all by four
/// fifths, so each is seen whole at its own stop.
double crossfade(double progress) => smoothstep((progress - 0.35) / 0.45);
