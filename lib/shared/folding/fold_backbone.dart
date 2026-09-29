import 'dart:typed_data';

import 'fold_geometry.dart';
import 'fold_timeline.dart';
import 'folding_track.dart';

/// Where the chain's backbone runs at one moment of the fold, in the scene's
/// frame, which is the model's with its z turned round (see [FoldMesh]).
///
/// Everything that draws the chain runs through these points: the thread of
/// the residues the model never places, and the model's own mesh carried by
/// the chain ([FoldSkin]). Both have to, or the one would part from the other
/// where they meet.
final class FoldBackbone {
  FoldBackbone(this.geometry)
    : native = Float64List(3 * geometry.length),
      centres = Float64List(3 * geometry.length),
      settled = Float64List(geometry.length);

  final FoldGeometry geometry;

  /// Each drawn residue's CA, three doubles apiece.
  final Float64List native;

  /// Where the ribbon passes each drawn residue, three doubles apiece: its CA
  /// until it settles, and then where the model's ribbon was measured to pass
  /// it. A strand the ribbon was not measured by is smoothed of its pleat
  /// instead, as PyMOL's flat sheets are.
  final Float64List centres;

  /// How settled each drawn residue is: 0 as the chain lies after the
  /// collapse, 1 in the model's place. A loose residue never settles.
  final Float64List settled;

  /// Moves everything to [frame].
  void update(FoldFrame frame) {
    final FoldGeometry g = geometry;
    final Float64List p = frame.positions;
    for (int i = 0; i < g.length; i++) {
      native
        ..[3 * i] = p[3 * i]
        ..[3 * i + 1] = p[3 * i + 1]
        ..[3 * i + 2] = -p[3 * i + 2];
      settled[i] = settledIn(g.drawn[i], frame);
    }
    final double held = frame.closure.isEmpty ? 0 : 1 - frame.closure.first;
    for (final (int start, int end) in g.chainRuns) {
      for (int i = start; i < end; i++) {
        final FoldResidue r = g.drawn[i];
        final double s = settled[i];
        final ModelPoint? on = r.ribbonAt;
        final bool smooth =
            on == null &&
            r.isOrdered &&
            r.shape == FoldShape.strand &&
            i > start &&
            i + 1 < end &&
            g.drawn[i - 1].isOrdered &&
            g.drawn[i + 1].isOrdered;
        for (int a = 0; a < 3; a++) {
          final double here = native[3 * i + a];
          final double there = on == null
              ? (smooth
                    ? (native[3 * (i - 1) + a] +
                              2 * here +
                              native[3 * (i + 1) + a]) /
                          4
                    : here)
              : (a == 0 ? on.$1 : (a == 1 ? on.$2 : -on.$3)) +
                    // The measured ribbon is a rest position. Carry it with
                    // its CA while the bridge still holds that residue apart,
                    // or the ribbon would lock early and the beads and rods
                    // move independently of the backbone in the last step.
                    g.hold[3 * i + a] * held * (a == 2 ? -1 : 1);
          centres[3 * i + a] = here + s * (there - here);
        }
      }
    }
  }

  /// How settled [residue] is at [frame]: a helix settles as the helices
  /// coil, the rest as the strands pair.
  static double settledIn(FoldResidue residue, FoldFrame frame) {
    if (!residue.isOrdered) {
      return 0;
    }
    return residue.shape == FoldShape.helix ? frame.coil : frame.pair;
  }
}

/// The point [u] of the way from control point [k] to the next, and the
/// direction the curve runs there: a uniform Catmull–Rom spline through the
/// [m] points of [c] that start at point [from], which passes through every
/// one of them, with its ends continued straight.
void catmullRom(
  Float64List c,
  int from,
  int m,
  int k,
  double u,
  List<double> point,
  List<double> tangent,
) {
  final double u2 = u * u;
  final double u3 = u2 * u;
  final int o = 3 * from;
  for (int a = 0; a < 3; a++) {
    final double p1 = c[o + 3 * k + a];
    final double p2 = c[o + 3 * (k + 1) + a];
    final double p0 = k > 0 ? c[o + 3 * (k - 1) + a] : 2 * p1 - p2;
    final double p3 = k + 2 < m ? c[o + 3 * (k + 2) + a] : 2 * p2 - p1;
    point[a] =
        0.5 *
        (2 * p1 +
            (-p0 + p2) * u +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * u3);
    tangent[a] =
        0.5 *
        ((-p0 + p2) +
            2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * u +
            3 * (-p0 + 3 * p1 - 3 * p2 + p3) * u2);
  }
}
