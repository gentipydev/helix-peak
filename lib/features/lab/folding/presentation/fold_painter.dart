import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../shared/format.dart';
import '../../../../shared/structure/structure_model.dart';
import '../domain/fold_geometry.dart';
import '../domain/fold_timeline.dart';
import '../domain/folding_track.dart';

/// The colours a fold is drawn in: its chains' own, as the fold page paints
/// them, and its bridges in the colour that page gives its `bonds` node.
@immutable
final class FoldInks {
  const FoldInks({
    required this.chains,
    required this.bridge,
    required this.background,
    required this.loose,
    required this.anatomy,
  });

  factory FoldInks.of(BuildContext context, ProteinTarget target) {
    final AnatomyColors anatomy = context.anatomyColors;
    final Map<String, Color> chains = <String, Color>{
      for (final StructureChain chain in target.chains)
        chain.node: chain.tint.of(anatomy),
    };
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FoldInks(
      chains: chains,
      bridge: chains['bonds'] ?? ChainTint.cysteine.of(anatomy),
      background: scheme.surface,
      loose: scheme.onSurfaceVariant,
      anatomy: anatomy,
    );
  }

  /// Each chain's colour, by the model node it is drawn as.
  final Map<String, Color> chains;
  final Color bridge;

  /// What the far side of the fold fades towards.
  final Color background;

  /// A residue with no place.
  final Color loose;

  /// For the water-avoiding residues, marked in the colours the grid gave
  /// them.
  final AnatomyColors anatomy;
}

/// The fold page's own lens on a box: [structureCamera] on the model's
/// bounds, which the `folding` track carries, so a point of the model lands
/// where the page draws it.
final class FoldProjector {
  FoldProjector(FoldingTrack track, this.size)
    : camera = structureCamera(
        vm.Aabb3.minMax(
          vm.Vector3(
            track.boundsMin.$1,
            track.boundsMin.$2,
            track.boundsMin.$3,
          ),
          vm.Vector3(
            track.boundsMax.$1,
            track.boundsMax.$2,
            track.boundsMax.$3,
          ),
        ),
      );

  final Size size;
  final PerspectiveCamera camera;

  /// Where [point], turned by [rotation] as the page turns its model, lands
  /// in the box, or null behind the camera.
  Offset? screenOf(vm.Vector3 point, vm.Quaternion rotation) =>
      camera.worldToScreen(rotation.rotated(point), size);

  /// How far [point], turned, is from the eye.
  double depthOf(vm.Vector3 point, vm.Quaternion rotation) =>
      (rotation.rotated(point) - camera.position).length;

  /// How many logical pixels one model unit spans, [depth] from the eye.
  double pixelsPerUnit(double depth) =>
      size.height / 2 / (depth * math.tan(camera.fovRadiansY / 2));
}

/// Draws one frame of a [FoldTimeline]: each chain as the line through its
/// CA atoms, nearest last, loose residues thin and faint, and the bridges as
/// they close.
class FoldPainter extends CustomPainter {
  FoldPainter({
    required this.timeline,
    required this.at,
    required this.inks,
    this.idle,
    this.rotation,
    super.repaint,
  });

  final FoldTimeline timeline;
  final double Function() at;
  final FoldInks inks;

  /// Seconds of the screen's own clock, which keep the loose residues moving
  /// once the timeline has stopped. Null holds them still.
  final double Function()? idle;

  /// How the reader has turned the fold. Null is the page's opening view.
  final vm.Quaternion Function()? rotation;

  /// How thick a chain is drawn, and a loose stretch of it, in angstroms.
  static const double chainWidth = 2;
  static const double looseWidth = 0.8;

  /// A bridge, and a water-avoiding residue's mark, in angstroms.
  static const double bridgeWidth = 1.2;
  static const double markRadius = 1;

  /// What a screen reader hears for [frame].
  static String describe(FoldTimeline timeline, FoldFrame frame) {
    final FoldGeometry geometry = timeline.geometry;
    final int placed = geometry.drawn
        .where((FoldResidue r) => r.isOrdered)
        .length;
    final int loose = geometry.length - placed;
    final String name = timeline.phaseAt(frame.t)?.name ?? '';
    return '$name. An illustration of ${grouped(placed)} residues folding, '
        'drawn as the chain through their alpha carbons'
        '${loose == 0 ? '' : ', with ${grouped(loose)} loose'}'
        '${frame.t >= 1 ? '. Folded, as the structure page draws it.' : '.'}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final FoldGeometry g = timeline.geometry;
    final FoldFrame frame = timeline.frameAt(at(), idle: idle?.call() ?? 0);
    final FoldProjector lens = FoldProjector(g.track, size);
    final vm.Quaternion turn = rotation?.call() ?? vm.Quaternion.identity();

    final int n = g.length;
    final List<Offset?> points = List<Offset?>.filled(n, null);
    final Float64List depths = Float64List(n);
    double near = double.infinity;
    double far = 0;
    for (int i = 0; i < n; i++) {
      final vm.Vector3 p = vm.Vector3(
        frame.positions[3 * i],
        frame.positions[3 * i + 1],
        frame.positions[3 * i + 2],
      );
      points[i] = lens.screenOf(p, turn);
      depths[i] = lens.depthOf(p, turn);
      near = math.min(near, depths[i]);
      far = math.max(far, depths[i]);
    }
    final double span = math.max(far - near, 1e-9);

    // Every segment of every chain, the far ones first.
    final List<(double, int)> segments = <(double, int)>[];
    for (final (int start, int end) in g.chainRuns) {
      for (int i = start; i + 1 < end; i++) {
        if (points[i] != null && points[i + 1] != null) {
          segments.add(((depths[i] + depths[i + 1]) / 2, i));
        }
      }
    }
    segments.sort(((double, int) a, (double, int) b) => b.$1.compareTo(a.$1));

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Map<int, String> nodeOf = <int, String>{};
    for (int c = 0; c < g.chainRuns.length; c++) {
      final (int start, int end) = g.chainRuns[c];
      for (int i = start; i < end; i++) {
        nodeOf[i] = g.track.chains[c].node;
      }
    }
    for (final (double depth, int i) in segments) {
      final bool loose = !g.drawn[i].isOrdered || !g.drawn[i + 1].isOrdered;
      final Color base = loose
          ? inks.loose
          : inks.chains[nodeOf[i]] ?? inks.loose;
      final double fog = 0.45 * (depth - near) / span;
      stroke
        ..color = Color.lerp(
          base,
          inks.background,
          fog,
        )!.withValues(alpha: loose ? 0.55 : 1)
        ..strokeWidth = math.max(
          loose ? 0.75 : 1.25,
          (loose ? looseWidth : chainWidth) *
              g.unit *
              lens.pixelsPerUnit(depth),
        );
      canvas.drawLine(points[i]!, points[i + 1]!, stroke);
    }

    // The water-avoiding residues, marked while they move in: each in the
    // colour the grid gave it, ringed so it stands clear of the chain.
    if (frame.emphasis > 0) {
      final Paint mark = Paint();
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = inks.background.withValues(alpha: frame.emphasis);
      for (int i = 0; i < n; i++) {
        final FoldResidue residue = g.drawn[i];
        if (!residue.isOrdered ||
            !isWaterAvoiding(residue.letter) ||
            points[i] == null) {
          continue;
        }
        final double radius = math.max(
          1.5,
          markRadius * g.unit * lens.pixelsPerUnit(depths[i]),
        );
        mark.color = inks.anatomy
            .forProperty(AminoAcids.propertyOf(residue.letter))
            .withValues(alpha: frame.emphasis);
        canvas
          ..drawCircle(points[i]!, radius, mark)
          ..drawCircle(points[i]!, radius, ring);
      }
    }

    // The bridges, each end reaching for the other until they meet.
    final Paint bridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = inks.bridge;
    for (int b = 0; b < g.bridges.length; b++) {
      final double closure = frame.closure[b];
      final (int i, int j) = g.bridges[b];
      final Offset? a = points[i];
      final Offset? c = points[j];
      if (closure <= 0 || a == null || c == null) {
        continue;
      }
      final Offset middle = Offset.lerp(a, c, 0.5)!;
      bridge.strokeWidth = math.max(
        1,
        bridgeWidth * g.unit * lens.pixelsPerUnit((depths[i] + depths[j]) / 2),
      );
      canvas
        ..drawLine(a, Offset.lerp(a, middle, closure)!, bridge)
        ..drawLine(c, Offset.lerp(c, middle, closure)!, bridge);
    }
  }

  @override
  bool shouldRepaint(FoldPainter old) =>
      old.timeline != timeline || old.inks != inks || old.at() != at();
}
