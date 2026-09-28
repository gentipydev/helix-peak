import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A lit, borderless residue. The same material fades into the protein grid
/// during the flight, so the handoff does not flash from a sphere to a disc.
abstract final class MolecularMaterial {
  static Shader residueShader(Rect bounds, Color color, {double depth = 1}) =>
      ui.Gradient.radial(
        bounds.center + Offset(-bounds.width * 0.18, -bounds.height * 0.2),
        bounds.width * 0.73,
        <Color>[
          Color.lerp(color, Colors.white, 0.46 * depth)!,
          color,
          Color.lerp(color, Colors.black, 0.52 * depth)!,
        ],
        const <double>[0, 0.42, 1],
      );
}
