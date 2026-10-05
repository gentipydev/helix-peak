import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// A cell, tens of micrometres across: each of the tissue's, and the one the
/// cell level draws, so the cell the zoom closes on keeps its size.
const double cellMetres = 2e-5;

/// Its nucleus, about ten micrometres across, at every level that draws it.
const double nucleusMetres = 1e-5;

/// A slice of the tissue under the microscope: cells packed side by side at
/// their size, the one the zoom closes on at the centre.
final class TissueScene extends ZoomScene {
  TissueScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.tissue;

  (double, Path, Path)? _cells;

  /// The cells and their nuclei, packed at their size in a patch that fills
  /// the view at its level, [aspect] tall to one wide.
  (Path, Path) _cellsFor(double aspect) {
    final (double, Path, Path)? kept = _cells;
    if (kept != null && kept.$1 == aspect) {
      return (kept.$2, kept.$3);
    }
    final double cell = subject.unitsOf(stop, cellMetres);
    final double nucleus = subject.unitsOf(stop, nucleusMetres) / 2;
    final double rise = cell * 0.87;
    final double reach = 0.5 * math.sqrt(1 + aspect * aspect) + cell;
    final int cols = (reach / cell).ceil();
    final int rows = (reach / rise).ceil();
    final Path cells = Path();
    final Path nuclei = Path();
    for (int row = -rows; row <= rows; row++) {
      for (int col = -cols; col <= cols; col++) {
        final Offset c = Offset(
          (col + (row.isOdd ? 0.5 : 0)) * cell,
          row * rise,
        );
        if (c.distance > reach) {
          continue;
        }
        for (int k = 0; k < 6; k++) {
          final double a = math.pi / 6 + k * math.pi / 3;
          final Offset v = c + Offset(math.cos(a), math.sin(a)) * cell * 0.55;
          k == 0 ? cells.moveTo(v.dx, v.dy) : cells.lineTo(v.dx, v.dy);
        }
        cells.close();
        nuclei.addOval(
          Rect.fromCircle(
            center: c + Offset(math.sin(row * 1.7 + col) * cell * 0.08, 0),
            radius: nucleus,
          ),
        );
      }
    }
    _cells = (aspect, cells, nuclei);
    return (cells, nuclei);
  }

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    // The cell the zoom closes on, at the rim of the ring round it.
    final double ring = subject.unitsOf(stop, cellMetres) * 0.58;
    final Offset target = frame.toScreen(Offset(ring * 0.7, -ring * 0.7));
    out.item('tissue:target', frame.toScreen(Offset.zero), frame.opacity);
    final String? cell = subject.path.cellName;
    out.callout(
      'tissue',
      cell == null
          ? 'a cell of the ${subject.path.tissue ?? 'tissue'}'
          : (subject.path.landsIn?.cell ?? cell.toLowerCase()),
      target,
      calloutPresence(frame),
    );
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    final double aspect = frame.size.height / frame.size.width;
    final (Path cells, Path nuclei) = _cellsFor(aspect);
    // The lamp's light through the slide, round as a microscope's field is.
    canvas.drawCircle(
      Offset.zero,
      0.5 * math.sqrt(1 + aspect * aspect),
      Paint()..color = frame.inks.scale.brightfield,
    );
    canvas.drawPath(cells, Paint()..color = frame.inks.scale.eosin);
    canvas.drawPath(
      cells,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * pixel
        ..color = frame.inks.scale.eosinDeep,
    );
    canvas.drawPath(
      nuclei,
      Paint()..color = frame.inks.scale.haematoxylin.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      Offset.zero,
      subject.unitsOf(stop, cellMetres) * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * pixel
        ..color = frame.inks.mark,
    );
    canvas.restore();
  }
}
