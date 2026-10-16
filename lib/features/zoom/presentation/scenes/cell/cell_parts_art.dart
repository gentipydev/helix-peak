import 'dart:ui';

import '../../zoom_inks.dart';
import 'cell_parts.dart';

/// Draws a cell's [parts] in the zoom's neutrals, [pixel] one screen pixel
/// in the cell's units, [detail] of the way come up: a few strokes and
/// fills a layer, lit as the zoom lights everything, from the upper left.
///
/// What tells them apart is shape and tone: the Nissl bodies and the
/// granules' cores near black, the rough ER's sacs dark and studded, the
/// Golgi's sacs lit tubes with dark walls, the mitochondria lit with their
/// folds, the lysosomes dark, the clear vesicles rings.
void paintCellParts(
  Canvas canvas,
  CellParts parts,
  ZoomInks inks,
  double pixel,
  double detail,
) {
  if (detail <= 0) {
    return;
  }
  Color ink(Color c, double alpha) => c.withValues(alpha: alpha * detail);
  Path layer(PartLayer l) => parts.layers[l]!;
  final Paint fill = Paint();
  final Paint line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  canvas.drawPath(
    layer(PartLayer.nissl),
    fill..color = ink(inks.shade(0.16), 0.88),
  );
  canvas.drawPath(
    layer(PartLayer.neurofilaments),
    line
      ..strokeWidth = 0.7 * pixel
      ..color = ink(inks.lit(0.5), 0.3),
  );
  // The rough ER: dark sacs, studded both sides with ribosomes.
  canvas.drawPath(
    layer(PartLayer.erSacs),
    line
      ..strokeWidth = 1.3 * pixel
      ..color = ink(inks.shade(0.28), 0.95),
  );
  if (parts.ribosomes.isNotEmpty) {
    canvas.drawPoints(
      PointMode.points,
      parts.ribosomes,
      line
        ..strokeWidth = 1.5 * pixel
        ..color = ink(inks.shade(0.12), 0.95),
    );
  }
  // The Golgi: each sac a lit tube in a dark wall, swelling at its rims.
  canvas.drawPath(
    layer(PartLayer.golgiSacs),
    line
      ..strokeWidth = 3.4 * pixel
      ..color = ink(inks.shade(0.3), 0.9),
  );
  canvas.drawPath(
    layer(PartLayer.golgiSacs),
    line
      ..strokeWidth = 1.8 * pixel
      ..color = ink(inks.lit(0.36), 0.95),
  );
  canvas.drawPath(
    layer(PartLayer.golgiEnds),
    fill..color = ink(inks.lit(0.36), 0.95),
  );
  canvas.drawPath(
    layer(PartLayer.golgiEnds),
    line
      ..strokeWidth = 0.8 * pixel
      ..color = ink(inks.shade(0.3), 0.9),
  );
  // Mitochondria: a shadow under each, its body lit, its folds, its edge.
  canvas.save();
  canvas.translate(0.6 * pixel, 0.8 * pixel);
  canvas.drawPath(
    layer(PartLayer.mitochondria),
    fill..color = ink(inks.shadow, 0.4),
  );
  canvas.restore();
  canvas.drawPath(
    layer(PartLayer.mitochondria),
    fill..color = ink(inks.lit(0.27), 0.97),
  );
  canvas.drawPath(
    layer(PartLayer.cristae),
    line
      ..strokeWidth = 0.9 * pixel
      ..color = ink(inks.shade(0.36), 0.95),
  );
  canvas.drawPath(
    layer(PartLayer.mitochondria),
    line
      ..strokeWidth = 1 * pixel
      ..color = ink(inks.shade(0.3), 0.95),
  );
  // Lysosomes: dark, a thin lit edge.
  canvas.drawPath(
    layer(PartLayer.lysosomes),
    fill..color = ink(inks.shade(0.26), 0.97),
  );
  canvas.drawPath(
    layer(PartLayer.lysosomes),
    line
      ..strokeWidth = 0.8 * pixel
      ..color = ink(inks.lit(0.3), 0.7),
  );
  // Small clear vesicles: rings.
  canvas.drawPath(
    layer(PartLayer.vesicles),
    line
      ..strokeWidth = 0.8 * pixel
      ..color = ink(inks.lit(0.5), 0.8),
  );
  // Secretory granules: a dense core in a pale halo.
  canvas.drawPath(
    layer(PartLayer.granuleHalos),
    fill..color = ink(inks.lit(0.52), 0.9),
  );
  canvas.drawPath(
    layer(PartLayer.granuleCores),
    fill..color = ink(inks.shadow, 0.95),
  );
  // The centrioles.
  canvas.drawPath(
    layer(PartLayer.centrioles),
    fill..color = ink(inks.lit(0.42), 0.95),
  );
  canvas.drawPath(
    layer(PartLayer.centrioles),
    line
      ..strokeWidth = 0.8 * pixel
      ..color = ink(inks.shade(0.3), 0.95),
  );
}
