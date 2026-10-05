import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/zoom_camera.dart';
import '../../domain/zoom_depth.dart';
import '../../domain/zoom_path.dart';
import 'organ_scene.dart';
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
/// figure (EMBL-EBI, CC BY 4.0), its organs faint inside it, and lit the
/// ones the Atlas finds the gene's RNA raised in, each as bright as its
/// level against the highest. The one the zoom goes into is ringed.
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
  /// least a little, whether or not the Atlas calls the gene raised there.
  Map<String, double> get lit => _levels;

  late final Map<String, double> _levels = () {
    final Map<String, double> out = <String, double>{};
    final List<(String, double)> specific = subject.track.tissue.specific;
    double top = 0;
    for (final (String _, double level) in specific) {
      top = math.max(top, level);
    }
    for (final (String name, double level) in specific) {
      final String? part = tissueAnatomy[ZoomPath.tissueName(name)]?.uberon;
      if (part != null && _figure.parts.containsKey(part)) {
        out[part] = math.max(out[part] ?? 0, top <= 0 ? 1 : level / top);
      }
    }
    final String? own = subject.anatomy?.uberon;
    if (own != null && _figure.parts.containsKey(own)) {
      out.putIfAbsent(own, () => 0.5);
    }
    return out;
  }();

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

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final String? tissue = subject.path.tissue;
    final AnatomyPart? part = subject.bodyPart;
    out.item('body:target', frame.toScreen(portal), frame.opacity);
    if (tissue != null && part != null) {
      // The name's line lands inside the organ, wherever its middle is.
      out.callout(
        'body',
        tissue,
        frame.toScreen(place(part.site)),
        calloutPresence(frame),
      );
    }
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final Color organ = frame.inks.scale.organ;
    final Color edge = frame.inks.scale.organEdge;
    // How far the body is seen through, on the way in.
    final double seen = frame.isChild ? 0 : smoothstep(frame.progress / 0.5);
    // How far the organ's own scene has taken over the part it follows.
    final double handed = frame.isChild
        ? 0
        : OrganScene.entering(frame.progress);
    final String? own = subject.bodyPart == null
        ? null
        : subject.anatomy?.uberon;

    canvas.drawPath(_silhouette, Paint()..color = frame.inks.scale.bodyFill);
    // The organs, faint; then the ones the gene is raised in.
    final Paint ghost = Paint()
      ..color = organ.withValues(alpha: 0.13 + 0.2 * seen);
    for (final MapEntry<String, Path> part in _parts.entries) {
      if (!_levels.containsKey(part.key) && !_notGhosted.contains(part.key)) {
        canvas.drawPath(part.value, ghost);
      }
    }
    for (final MapEntry<String, double> lit in _levels.entries) {
      final double shown = lit.key == own ? 1 - handed : 1;
      final double strength = (0.35 + 0.6 * lit.value) * shown;
      if (lit.key == _skin) {
        // The skin is the figure's own edge.
        canvas.drawPath(
          _silhouette,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2 * pixel
            ..color = organ.withValues(alpha: strength),
        );
        continue;
      }
      final Path path = _parts[lit.key]!;
      canvas.drawPath(path, Paint()..color = organ.withValues(alpha: strength));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * pixel
          ..color = edge.withValues(alpha: 0.7 * strength),
      );
    }
    canvas.drawPath(
      _lines,
      Paint()
        ..color = frame.inks.scale.bodyEdge.withValues(alpha: 0.9 - 0.5 * seen),
    );
    // What the zoom follows: ringed, and found by a mark while it is too
    // small to see.
    final AnatomyPart? part = subject.bodyPart;
    if (part != null) {
      final Color mark = frame.inks.mark;
      final Offset at = place(part.site);
      if (own != _skin) {
        canvas.drawPath(
          _followed!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8 * pixel
            ..strokeJoin = StrokeJoin.round
            ..color = mark.withValues(alpha: 1 - handed),
        );
      }
      final double across = part.extent / _width * frame.view.pixelsPerUnit;
      final double lost = own == _skin
          ? 1 - handed
          : 1 - smoothstep((across - 14) / 26);
      if (lost > 0) {
        canvas.drawCircle(
          at,
          9 * pixel,
          Paint()..color = mark.withValues(alpha: 0.3 * lost),
        );
        canvas.drawCircle(
          at,
          3.2 * pixel,
          Paint()..color = mark.withValues(alpha: lost),
        );
      }
    }
    canvas.restore();
  }
}
