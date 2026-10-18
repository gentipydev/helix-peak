import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'body_scene.dart';
import 'organ_art.dart';
import 'sculpt.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The organ the path's tissue is in, seen whole and sculpted, the figure's
/// parts faint round it, the gene's place in it glowing and the place the
/// tissue is sampled marked.
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

  /// What it names at its stop: where the zoom's cell lives, and the
  /// neighbours drawn round it.
  List<OrganName> get names => _art.names;

  /// How much of its names shows at [frame]: coming in as every stop's do
  /// ([calloutPresence]), and gone by [leaving] of the step on to the
  /// tissue, before the view's narrowing carries their plates off the
  /// canvas and leaves their lines across the field opening there.
  static double namesShown(ZoomFrame frame) => frame.isChild
      ? calloutPresence(frame)
      : math.min(frame.opacity, 1 - smoothstep(frame.progress / leaving));

  static const double leaving = 0.24;

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
  @visibleForTesting
  double grownAt(ZoomFrame frame) => _grown(frame);

  double _grown(ZoomFrame frame) => frame.isChild
      ? math
            .pow(_art.real, smootherstep((frame.progress - 0.45) / 0.55) - 1)
            .toDouble()
      : 1;

  // The tissue is sampled where the organ's drawing says, not at its
  // middle.
  @override
  Offset get portal => _art.site;

  // The organ is not named here: the card names it. What is named is where
  // the zoom's cell lives in it, its line in the mark, and the neighbours
  // drawn round it, in the quiet ink: set round all of it, out at the
  // canvas's corners, so they hide none of it.
  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final double grown = _grown(frame);
    out.item('organ:target', frame.toScreen(_art.site * grown), frame.opacity);
    final double shown = namesShown(frame);
    if (shown <= 0 || _art.names.isEmpty) {
      return;
    }
    final ZoomRing ring = ZoomRing('organ', <Offset>[
      for (final Offset p in _art.named) frame.toScreen(p * grown),
    ]);
    for (final OrganName name in _art.names) {
      out.callout(
        'organ:${name.key}',
        name.word,
        frame.toScreen(name.at * grown),
        shown,
        quiet: !name.home,
        ring: ring,
      );
    }
  }

  @override
  void prepare(ZoomInks inks) => _art.prepare(inks);

  @override
  bool wantsClock(ZoomFrame frame) => !frame.isChild && frame.dwell < 2;

  // As it is reached, a band of light passes over the organ, and the place
  // its tissue is sampled pings.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    if (frame.isChild) {
      return;
    }
    final double here = frame.opacity * (1 - smoothstep(frame.progress / 0.15));
    final double light = Sculpt.beat(frame.dwell, delay: 0.05, length: 1.2);
    final double ping = Sculpt.beat(frame.dwell, delay: 0.75, length: 1.1);
    if (here <= 0 || ((light <= 0 || light >= 1) && (ping <= 0 || ping >= 1))) {
      return;
    }
    canvas.save();
    frame.enter(canvas);
    final double grown = _grown(frame);
    final Path outline = _art.outline;
    canvas.save();
    canvas.scale(grown);
    canvas.clipPath(outline);
    Sculpt.sweep(canvas, outline.getBounds(), light, frame.inks, opacity: here);
    canvas.restore();
    Sculpt.ping(
      canvas,
      _art.site * grown,
      Sculpt.beaconRadius * frame.pixel,
      30 * frame.pixel,
      ping,
      frame.pixel,
      frame.inks,
      opacity: here,
    );
    canvas.restore();
  }

  /// How far the organ has become its own, from the body's drawing of it:
  /// its sculpting and what lies inside it come up once it is growing.
  static double detailAt(ZoomFrame frame) =>
      frame.isChild ? smoothstep((frame.progress - 0.5) / 0.4) : 1;

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double grown = _grown(frame);
    final double detail = detailAt(frame);
    _art.paint(canvas, frame.inks, frame.pixel, grown, detail: detail);
    // Where the tissue is sampled, once the organ is its own, until the
    // loupe opening there takes its place.
    final double opening = frame.isChild
        ? 0
        : smoothstep(frame.progress / 0.25);
    Sculpt.beacon(
      canvas,
      _art.site * grown,
      frame.pixel,
      frame.inks,
      opacity: detail * (1 - opening),
    );
    canvas.restore();
  }
}
