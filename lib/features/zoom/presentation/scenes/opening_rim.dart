import 'dart:math' as math;
import 'dart:ui';

import 'coloured_mesh.dart';
import 'specimen_light.dart';

/// The rim of an opening a specimen is cut through, as the zoom's
/// specimens draw their emptied cavities and lumens (the heart's chambers
/// and great vessels): a shadow just inside its edges that face the lamp,
/// and light just inside those that turn from it.
final class OpeningRim {
  const OpeningRim({
    required this.toward,
    required this.shadow,
    required this.light,
    required this.shadowWidth,
    required this.lightWidth,
    required this.shadowAlpha,
    required this.lightAlpha,
    required this.probe,
  });

  /// The way toward the lamp, on the screen.
  final Offset toward;

  /// The inks the rim is drawn in where it faces the lamp, and where it
  /// turns from it.
  final Color shadow;
  final Color light;

  /// How far in from the edge each reaches, in the scene's units, and how
  /// strong each is where the edge faces the lamp, or turns from it, full
  /// on.
  final double shadowWidth;
  final double lightWidth;
  final double shadowAlpha;
  final double lightAlpha;

  /// How far out from the edge it is looked for the opening, in the
  /// scene's units, to tell its inside from its outside.
  final double probe;

  /// Lays the rim along [rim], an edge of the opening [inside], in [mesh],
  /// coming up over [fadeIn] from its start.
  void lay(
    ColouredMesh mesh,
    List<Offset> rim,
    Path inside, {
    double fadeIn = 0,
  }) {
    final int n = rim.length;
    if (n < 2) {
      return;
    }
    double along = 0;
    mesh.begin(2 * n);
    final int first = mesh.next;
    for (int i = 0; i < n; i++) {
      final Offset t = rim[math.min(n - 1, i + 1)] - rim[math.max(0, i - 1)];
      final double length = t.distance;
      Offset out = length <= 0 ? Offset.zero : Offset(t.dy, -t.dx) / length;
      if (inside.contains(rim[i] + out * probe)) {
        out = -out;
      }
      if (i > 0) {
        along += (rim[i] - rim[i - 1]).distance;
      }
      final double shown = fadeIn <= 0
          ? 1
          : math.min(1, along / fadeIn) * math.min(1, along / fadeIn);
      final double facing = (out.dx * toward.dx + out.dy * toward.dy) * shown;
      final double width = facing > 0 ? shadowWidth : lightWidth;
      final int colour = facing > 0
          ? SpecimenPalette.packColour(shadow, shadowAlpha * facing)
          : SpecimenPalette.packColour(light, lightAlpha * -facing);
      final Offset inner = rim[i] - out * width;
      mesh.vertex(rim[i].dx, rim[i].dy, colour);
      mesh.vertex(inner.dx, inner.dy, colour & ((1 << 24) - 1));
    }
    for (int i = 0; i + 1 < n; i++) {
      final int a = first + 2 * i;
      final int b = a + 2;
      mesh
        ..triangle(a, b, a + 1)
        ..triangle(b, b + 1, a + 1);
    }
  }
}
