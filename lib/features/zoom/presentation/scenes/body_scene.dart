import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../zoom_inks.dart';
import 'organ_scene.dart';
import 'sculpt.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// How much a scene's callout shows at [frame]: around its own stop only,
/// coming up over the last [around] of the way in and going over the first
/// [around] of the way out, and never more than the scene itself shows.
///
/// It runs on how far along the segment the view is, not on how big the
/// scene is drawn: across a segment that narrows six-hundredfold the scene's
/// size races, while the depth eases in and out of every stop.
double calloutPresence(ZoomFrame frame) {
  final double s = frame.progress;
  final double near = frame.isChild
      ? smoothstep((s - (1 - around)) / around)
      : 1 - smoothstep(s / around);
  return math.min(frame.opacity, near);
}

/// How much of a segment either side of a stop its name is shown for.
const double around = 0.35;

/// The body, standing facing the reader: the Expression Atlas anatomogram's
/// figure (EMBL-EBI, CC BY 4.0), sculpted in the app's neutrals and seen
/// through, its organs faint inside it. The ones the Atlas finds the gene's
/// RNA raised in glow in the mark, each as bright as its level against the
/// highest, and the one the zoom goes into is ringed. As the body is
/// reached a scan passes down it, lighting them as it goes.
///
/// On the way in the body is seen through: its line art gives way, the
/// organs come up, and the one the zoom follows is handed to the organ's own
/// scene, which draws the same outline.
final class BodyScene extends ZoomScene {
  BodyScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.body;

  static const double _width = ZoomDepth.bodyMetres;

  /// The anatomogram's part for the skin: the figure's own outline.
  static const String _skin = 'UBERON_0000014';

  /// Parts left out of the faint organs: the skin is the figure itself,
  /// and fat lies over everything.
  static const Set<String> _notGhosted = <String>{_skin, 'UBERON_0001013'};

  /// A point of the figure, metres across from its midline and down from
  /// the top of its head, in the scene's units: the figure's middle at the
  /// middle of the view.
  static Offset place(Offset metres) => Offset(
    metres.dx / _width,
    (metres.dy - AnatomyFigure.height / 2) / _width,
  );

  static Path _closed(List<Offset> outline) {
    final Path path = Path();
    for (int i = 0; i < outline.length; i++) {
      final Offset p = place(outline[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  static Path _all(List<List<Offset>> outlines) {
    final Path path = Path();
    for (final List<Offset> outline in outlines) {
      path.addPath(_closed(outline), Offset.zero);
    }
    return path;
  }

  AnatomyFigure get _figure => subject.body;

  late final Path _silhouette = _closed(_figure.silhouette);

  late final Path _lines = _all(_figure.lines)..fillType = PathFillType.evenOdd;

  /// How strongly each part is lit, by UBERON id, from 0 to 1: the gene's
  /// level there against its highest, and the part the zoom goes into at
  /// least half ([ZoomSubject.litLevels]).
  Map<String, double> get lit => _levels;

  Map<String, double> get _levels => subject.litLevels;

  /// Every part's shape, by UBERON id.
  late final Map<String, Path> _parts = <String, Path>{
    for (final MapEntry<String, AnatomyPart> part in _figure.parts.entries)
      part.key: _all(part.value.contours),
  };

  late final Path? _followed = subject.bodyPart == null
      ? null
      : _closed(subject.bodyPart!.followed);

  // The view closes on the organ's middle, so the organ's scene has it
  // whole.
  @override
  Offset get portal {
    final AnatomyPart? part = subject.bodyPart;
    return place(part?.centre ?? const Offset(0, 0.55));
  }

  // The organ is not named here: the card names it.
  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final AnatomyPart? part = subject.bodyPart;
    out.item('body:target', frame.toScreen(portal), frame.opacity);
    if (part != null) {
      // The place inside the organ the zoom goes in by, wherever its
      // middle is.
      out.item(
        'body:site',
        frame.toScreen(place(part.site)),
        calloutPresence(frame),
      );
    }
  }

  /// The figure's box in the scene's units, and the silhouette's.
  late final Rect _box = _silhouette.getBounds();

  /// Each part's box, for its glow.
  late final Map<String, Rect> _partBoxes = <String, Rect>{
    for (final MapEntry<String, Path> part in _parts.entries)
      part.key: part.value.getBounds(),
  };

  /// How long the scan takes to pass from head to foot, and the ping that
  /// follows on the organ the zoom goes into, in seconds.
  static const double scanTime = 1.1;
  static const double pingTime = 0.9;

  /// How far the scan has come down the figure, from 0 to 1, [dwell]
  /// seconds after the body was reached.
  static double scanned(double dwell) => smoothstep(dwell / scanTime);

  // The figure: sculpted in the app's neutrals, seen through to the organs
  // inside it, faint. What the gene lights is drawn over it, on the ambient
  // layer, where the scan passes over it as the body is reached.
  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final ZoomInks inks = frame.inks;
    // How far the body is seen through, on the way in.
    final double seen = frame.isChild ? 0 : smoothstep(frame.progress / 0.5);
    canvas.drawPath(
      _silhouette,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[inks.lit(0.07), inks.shade(0.74), inks.shade(0.5)],
          stops: const <double>[0, 0.45, 1],
        ).createShader(_box),
    );
    // Every organ, a faint shape in the figure.
    final Paint ghost = Paint()
      ..color = inks.lit(0.14).withValues(alpha: 0.42 + 0.25 * seen);
    final Paint ghostEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * pixel
      ..color = inks.lit(0.32).withValues(alpha: 0.45 + 0.3 * seen);
    for (final MapEntry<String, Path> part in _parts.entries) {
      if (_notGhosted.contains(part.key)) {
        continue;
      }
      canvas.drawPath(part.value, ghost);
      canvas.drawPath(part.value, ghostEdge);
    }
    // The figure's line art, giving way as it is seen through.
    canvas.drawPath(
      _lines,
      Paint()..color = inks.label.withValues(alpha: 0.3 * (1 - 0.6 * seen)),
    );
    Sculpt.rim(
      canvas,
      _silhouette,
      _box,
      inks,
      width: 1.4 * pixel,
      strength: 0.42 * (1 - 0.5 * seen),
    );
    canvas.restore();
  }

  @override
  void prepare(ZoomInks inks) => <Object?>[
    _silhouette,
    _lines,
    _parts,
    _partBoxes,
    _followed,
    _box,
  ];

  @override
  bool wantsClock(ZoomFrame frame) =>
      !frame.isChild && frame.dwell < scanTime + pingTime;

  // What the gene lights, the scan passing over it as the body is reached,
  // and the organ the zoom goes into, ringed. Each fades with the body.
  @override
  void paintAmbient(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final ZoomInks inks = frame.inks;
    final double opacity = frame.opacity;
    // How far the organ's own scene has taken over the part it follows.
    final double handed = frame.isChild
        ? 0
        : OrganScene.entering(frame.progress);
    final String? own = subject.bodyPart == null
        ? null
        : subject.anatomy?.uberon;
    final double scan = scanned(frame.dwell);
    final double reach = _box.top + (_box.height * 1.08) * scan;
    for (final MapEntry<String, double> lit in _levels.entries) {
      final double shown = (lit.key == own ? 1 - handed : 1) * opacity;
      if (shown <= 0.002) {
        continue;
      }
      final double level = lit.value;
      if (lit.key == _skin) {
        // The skin is the figure's own edge.
        canvas.drawPath(
          _silhouette,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * pixel
            ..color = inks.glow((0.35 + 0.55 * level) * shown),
        );
        continue;
      }
      final Path path = _parts[lit.key]!;
      final Rect box = _partBoxes[lit.key]!;
      Sculpt.glow(
        canvas,
        box.center,
        box.longestSide * 0.85 + 10 * pixel,
        inks,
        (0.16 + 0.22 * level) * shown,
      );
      canvas.drawPath(
        path,
        Paint()..color = inks.glow((0.2 + 0.55 * level) * shown),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * pixel
          ..strokeJoin = StrokeJoin.round
          ..color = inks.glow((0.5 + 0.5 * level) * shown),
      );
    }
    // The scan: a band of the mark passing down the figure, over organs
    // already lit, so it may pass again each time the body is reached.
    final double sweeping =
        smoothstep(scan / 0.12) * (1 - smoothstep((scan - 0.86) / 0.14));
    if (sweeping > 0) {
      final double band = 46 * pixel;
      final Rect sweep = Rect.fromLTRB(
        _box.left,
        reach - band,
        _box.right,
        reach + band * 0.25,
      );
      canvas.save();
      canvas.clipPath(_silhouette);
      canvas.drawRect(
        sweep,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              inks.glow(0),
              inks.glow(0.2 * opacity * sweeping),
              inks.glow(0.5 * opacity * sweeping),
              inks.glow(0),
            ],
            stops: const <double>[0, 0.7, 0.8, 1],
          ).createShader(sweep),
      );
      canvas.restore();
    }
    // What the zoom follows: ringed, and found by a reticle while it is too
    // small to see, which pings once the scan has passed it.
    final AnatomyPart? part = subject.bodyPart;
    if (part != null) {
      final Offset at = place(part.site);
      if (own != _skin) {
        canvas.drawPath(
          _followed!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8 * pixel
            ..strokeJoin = StrokeJoin.round
            ..color = inks.glow((1 - handed) * opacity),
        );
      }
      final double across = part.extent / _width * frame.view.pixelsPerUnit;
      final double lost = own == _skin
          ? 1 - handed
          : 1 - smoothstep((across - 14) / 26);
      if (lost > 0) {
        Sculpt.reticle(
          canvas,
          at,
          8 * pixel,
          pixel,
          inks,
          opacity: lost * opacity,
        );
      }
      // The ping: a ring that spreads and fades once the scan reaches it.
      final double reached =
          (at.dy - _box.top) / (_box.height * 1.08) * scanTime;
      final double ping = ((frame.dwell - reached) / pingTime).clamp(0.0, 1.0);
      if (ping > 0 && ping < 1) {
        canvas.drawCircle(
          at,
          (8 + 30 * Curves.easeOut.transform(ping)) * pixel,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * pixel
            ..color = inks.glow((1 - ping) * 0.8 * opacity),
        );
      }
    }
    canvas.restore();
  }
}
