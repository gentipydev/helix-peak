import 'dart:math' as math;
import 'dart:ui';

import 'coloured_mesh.dart';
import 'specimen_light.dart';

/// A specimen's cut face, laid between two of its edges point for point, as
/// the zoom's specimens cut through are drawn: the eye's coats, cut level
/// through its nerve.
///
/// Its columns say, at each of them across the face from its first edge to
/// its second, how far the face turns toward the first edge there (toward
/// the second where it is negative), and how far it is shut in: a cut face
/// cushioned a little across, or one whose outer edge is the organ's own
/// surface curving away.
final class CutFace {
  const CutFace(this.light, this.palette, {required this.sheen});

  final SpecimenLight light;
  final SpecimenPalette palette;

  /// How much a cut face shines, a share of a fresh surface's sheen.
  final double sheen;

  /// Lays a cut face in [mesh] between two edges in the scene, [a] and [b],
  /// point for point: at each of [columns] across from a to b, lit as the
  /// face there turns, in [tone] for its row, shut in by its share of
  /// [shut] for its row, at [alpha] for its row.
  void lay(
    ColouredMesh mesh,
    List<Offset> a,
    List<Offset> b,
    SpecimenTone Function(int) tone,
    List<(double, double, double)> columns, {
    double brightness = 1,
    double Function(int)? shut,
    double Function(int)? alpha,
  }) {
    final int n = a.length;
    final int around = columns.length;
    if (n < 2) {
      return;
    }
    mesh.begin(n * around);
    final int first = mesh.next;
    for (int i = 0; i < n; i++) {
      final Offset d = a[i] - b[i];
      final double length = d.distance;
      final Offset out = length <= 0 ? Offset.zero : d / length;
      final SpecimenTone t = tone(i);
      final double closed = shut == null ? 0 : shut(i);
      final double shown = alpha == null ? 1 : alpha(i);
      for (final (double u, double turn, double occlusion) in columns) {
        final Offset p = Offset.lerp(a[i], b[i], u)!;
        final double nz = math.sqrt(math.max(0, 1 - turn * turn));
        final double nx = out.dx * turn;
        final double ny = out.dy * turn;
        mesh.vertex(
          p.dx,
          p.dy,
          palette.colour(
            t,
            light.light(nx, ny, nz, form: nz) * brightness,
            occlusion: occlusion * closed,
            sheen: light.sheen(nx, ny, nz) * sheen * brightness,
            alpha: shown,
          ),
        );
      }
    }
    for (int i = 0; i + 1 < n; i++) {
      final int r = first + i * around;
      final int s = r + around;
      for (int k = 0; k + 1 < around; k++) {
        mesh
          ..triangle(r + k, r + k + 1, s + k)
          ..triangle(r + k + 1, s + k + 1, s + k);
      }
    }
  }
}
