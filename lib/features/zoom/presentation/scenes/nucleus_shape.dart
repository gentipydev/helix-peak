import 'dart:ui';

import '../../domain/cell_archetypes.dart';
import 'contour.dart';

/// How a nucleus of a kind of cell is drawn, at the origin: round in most
/// cells, a lens in a flat cell, pressed thin against a fat cell's rim,
/// lobed in a megakaryocyte. The cell's scene and the nucleus's draw it from
/// here, so the nucleus keeps its shape across the step between them.
final class NucleusShape {
  const NucleusShape(this.shape);

  final CellShape shape;

  /// How far the outline reaches across and down, as fractions of the
  /// nucleus's radius.
  (double, double) get axes => switch (shape) {
    CellShape.endothelial || CellShape.spindle => (1.55, 0.55),
    CellShape.myofibre => (1.6, 0.5),
    CellShape.adipocyte => (1.45, 0.48),
    _ => (1, 1),
  };

  /// The outline for a nucleus of [radius], at the origin.
  Contour outline(double radius) {
    final (double ax, double ay) = axes;
    return switch (shape) {
      CellShape.megakaryocyte => Contour.blob(
        const Offset(0, 0),
        radius,
        radius,
        count: 128,
        wobble: 0.22,
        seed: 7,
      ),
      CellShape.leukocyte => Contour.blob(
        const Offset(0, 0),
        radius,
        radius * 0.92,
        count: 128,
        wobble: 0.1,
        seed: 3,
      ),
      _ => Contour.blob(
        const Offset(0, 0),
        radius * ax,
        radius * ay,
        count: 128,
        wobble: 0.03,
        seed: 1,
      ),
    };
  }

  /// [unit] (a point in a disc of radius 1) placed in the nucleus.
  Offset place(Offset unit, double radius) {
    final (double ax, double ay) = axes;
    return Offset(unit.dx * ax * radius, unit.dy * ay * radius);
  }
}
