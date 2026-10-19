import 'dart:math' as math;
import 'dart:ui';

import 'coloured_mesh.dart';
import 'lobules.dart';
import 'relief.dart';
import 'specimen_light.dart';

/// A gland's lobules drawn as a fresh specimen's are under the zoom's one
/// lamp: each a lit dome with a moist sheen, its edge turning away into the
/// crevice round it, deeper where it meets another lobe, each lobe rounding
/// off toward its own edge, and each lobe and lobule a little lighter or
/// darker than the next.
abstract final class LobuleDomes {
  /// Lays [lobules] into [mesh], as [style] has them, on the gland's
  /// [relief], lit by [light] in [tone] through [palette], [wash] of the
  /// way into the mark; [mm] is a millimetre of the real gland in the
  /// scene's units, and [seed] the seed their tones are strewn by.
  static void lay(
    ColouredMesh mesh,
    Iterable<Lobule> lobules, {
    required LobuleStyle style,
    required Relief relief,
    required double Function(double millimetres) mm,
    required SpecimenLight light,
    required SpecimenPalette palette,
    required SpecimenTone tone,
    required double wash,
    required int seed,
  }) {
    const int rays = Lobule.rays;
    final List<double> rings = style.rings;
    final math.Random random = math.Random(seed);
    final double feather = style.feather * mm(style.spacing);
    final double lobeRadius = mm(style.lobe) / 2;
    final List<int> rim = List<int>.filled(rays, 0);
    for (final Lobule lobule in lobules) {
      // Each lobe a little lighter or darker than the next, and each lobule
      // than the next in its lobe.
      final double shade =
          (1 + style.lobeTone * _jitter(lobule.lobeIndex)) *
          (1 + style.lobuleTone * (2 * random.nextDouble() - 1));
      // The lobe's own rounding, toward its edge.
      (double, double, double) rounded(
        Offset p,
        double nx,
        double ny,
        double nz,
        double tx,
        double ty,
      ) {
        Offset off = (p - lobule.lobe) / lobeRadius;
        if (off.distance > 1) {
          off = off / off.distance;
        }
        return _unit(
          nx + style.lobeTilt * off.dx + tx,
          ny + style.lobeTilt * off.dy + ty,
          nz,
        );
      }

      mesh.begin(1 + rays * (rings.length + 1));
      final int first = mesh.next;
      // Its top, nudged toward the light, where its sheen is.
      final (double, double, double) up = relief.normalAt(lobule.centre);
      final (double ux, double uy, double uz) = rounded(
        lobule.centre,
        up.$1,
        up.$2,
        up.$3,
        0,
        0,
      );
      final Offset top =
          lobule.centre + light.screen * (style.nudge * lobule.radius);
      mesh.vertex(
        top.dx,
        top.dy,
        palette.colour(
          tone,
          light.light(ux, uy, uz, form: up.$3) * shade,
          sheen: light.sheen(ux, uy, uz),
          wash: wash,
        ),
      );
      for (int ring = 0; ring < rings.length; ring++) {
        final bool outer = ring == rings.length - 1;
        for (int k = 0; k < rays; k++) {
          final double depth = lobule.depth[k];
          final double tilt =
              (style.tilt + (style.cleftTilt - style.tilt) * depth) *
              style.tilts[ring];
          final Offset p = lobule.at(k, rings[ring]);
          final Offset out = Lobule.direction(k);
          final (double nx, double ny, double nz) = relief.normalAt(p);
          final (double tx, double ty, double tz) = rounded(
            p,
            nx,
            ny,
            nz,
            tilt * out.dx,
            tilt * out.dy,
          );
          final int colour = palette.colour(
            tone,
            light.light(tx, ty, tz, form: nz) * shade,
            occlusion: outer ? style.rimShade * depth : 0,
            sheen: light.sheen(tx, ty, tz),
            wash: wash,
          );
          if (outer) {
            rim[k] = colour;
          }
          mesh.vertex(p.dx, p.dy, colour);
        }
      }
      // A feathered edge: the rim fading out across the crevice.
      for (int k = 0; k < rays; k++) {
        final Offset p =
            lobule.centre + Lobule.direction(k) * (lobule.reach[k] + feather);
        mesh.vertex(p.dx, p.dy, _clear(rim[k]));
      }
      for (int k = 0; k < rays; k++) {
        final int a = first + 1 + k;
        final int b = first + 1 + (k + 1) % rays;
        mesh.triangle(first, a, b);
        for (int band = 0; band < rings.length; band++) {
          final int a0 = a + band * rays;
          final int b0 = b + band * rays;
          mesh.triangle(a0, b0, a0 + rays);
          mesh.triangle(b0, b0 + rays, a0 + rays);
        }
      }
    }
  }
}

(double, double, double) _unit(double x, double y, double z) {
  final double length = math.sqrt(x * x + y * y + z * z);
  return length <= 0 ? (0, 0, 1) : (x / length, y / length, z / length);
}

int _clear(int colour) => colour & ((1 << 24) - 1);

/// A number from -1 to 1 that is the same for [i] every time, and unlike
/// its neighbours'.
double _jitter(int i) {
  final double x = math.sin(i * 12.9898 + 78.233) * 43758.5453;
  return 2 * (x - x.floorToDouble()) - 1;
}
