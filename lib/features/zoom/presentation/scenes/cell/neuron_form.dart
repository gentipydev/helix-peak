import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contour.dart';

/// One stretch of a neuron's process: from [from] to [to], [fromWidth] wide
/// where it starts and [toWidth] where it ends, the trunk [generation] 0,
/// its branches 1, theirs 2.
@immutable
final class NeuronBranch {
  const NeuronBranch(
    this.from,
    this.to,
    this.fromWidth,
    this.toWidth, {
    this.generation = 0,
  });

  final Offset from;
  final Offset to;
  final double fromWidth;
  final double toWidth;
  final int generation;

  double get length => (to - from).distance;

  /// The way it runs, as a unit vector.
  Offset get along => (to - from) / length;

  /// Square to the way it runs, to its right on screen.
  Offset get across => Offset(-along.dy, along.dx);

  /// The point [t] of the way along it.
  Offset at(double t) => Offset.lerp(from, to, t)!;

  /// How wide it is [t] of the way along it.
  double widthAt(double t) => fromWidth + (toWidth - fromWidth) * t;

  /// It as a closed shape: narrowing from one end to the other, each end
  /// round. Every part of it runs clockwise on screen, as the ovals at its
  /// ends do, so overlapping it with others only ever adds to the shape.
  Path get path {
    final Offset a = across;
    return Path()
      ..moveTo(from.dx - a.dx * fromWidth / 2, from.dy - a.dy * fromWidth / 2)
      ..lineTo(to.dx - a.dx * toWidth / 2, to.dy - a.dy * toWidth / 2)
      ..lineTo(to.dx + a.dx * toWidth / 2, to.dy + a.dy * toWidth / 2)
      ..lineTo(from.dx + a.dx * fromWidth / 2, from.dy + a.dy * fromWidth / 2)
      ..close()
      ..addOval(Rect.fromCircle(center: from, radius: fromWidth / 2))
      ..addOval(Rect.fromCircle(center: to, radius: toWidth / 2));
  }
}

/// A neuron's form, in its cell's units, for a neuron of half-size [r]: a
/// rounded body; five dendrites leaving it, each narrowing as it goes and
/// branching twice; and below, a hillock narrowing into one axon of even
/// width, running down out of the cell's view. The cell's scene draws its
/// parts on it, and the tissue lays its outline in the brain's slide.
///
/// It reaches no further than the neuron always did: its dendrites a
/// little over its half-size from its middle, its axon 1.82 times it, so
/// the slide that lays copies of it among others keeps its spacing.
final class NeuronForm {
  NeuronForm(this.r) {
    _grow();
  }

  final double r;

  /// The body's radius: room round the nucleus for its Nissl bodies.
  double get soma => r * 0.42;

  /// The dendrites, trunks first, each followed by its branches.
  final List<NeuronBranch> dendrites = <NeuronBranch>[];

  /// The hillock: from its foot on the body to where the axon begins.
  late final NeuronBranch hillock;

  /// The axon, from the hillock on, of even width.
  late final NeuronBranch axon;

  /// Where each trunk leaves the body, as an angle on screen.
  static const List<double> trunks = <double>[-2.6, -1.72, -0.86, 0.05, 2.8];

  void _grow() {
    final math.Random random = math.Random(41);
    for (final double angle in trunks) {
      final Offset way = Offset(math.cos(angle), math.sin(angle));
      final Offset foot = way * (soma * 0.8);
      final NeuronBranch trunk = NeuronBranch(
        foot,
        foot + way * (r * (0.28 + 0.06 * random.nextDouble())),
        r * 0.16,
        r * 0.075,
      );
      dendrites.add(trunk);
      for (final double side in <double>[-1, 1]) {
        final double turn = angle + side * (0.38 + 0.14 * random.nextDouble());
        final Offset next = Offset(math.cos(turn), math.sin(turn));
        final NeuronBranch branch = NeuronBranch(
          trunk.to,
          trunk.to + next * (r * (0.2 + 0.05 * random.nextDouble())),
          r * 0.065,
          r * 0.035,
          generation: 1,
        );
        dendrites.add(branch);
        // The outer of each pair branches once more.
        if (side > 0 || random.nextDouble() < 0.5) {
          for (final double fork in <double>[-1, 1]) {
            final double bend =
                turn + fork * (0.32 + 0.1 * random.nextDouble());
            final Offset end = Offset(math.cos(bend), math.sin(bend));
            dendrites.add(
              NeuronBranch(
                branch.to,
                branch.to + end * (r * (0.1 + 0.05 * random.nextDouble())),
                r * 0.03,
                r * 0.012,
                generation: 2,
              ),
            );
          }
        }
      }
    }
    hillock = NeuronBranch(
      Offset(0, soma * 0.82),
      Offset(0, soma * 0.82 + r * 0.2),
      r * 0.3,
      r * 0.065,
    );
    axon = NeuronBranch(hillock.to, Offset(0, r * 1.82), r * 0.065, r * 0.06);
  }

  /// The body's own outline.
  late final Contour body = Contour.blob(
    Offset.zero,
    soma,
    soma * 0.96,
    count: 96,
    wobble: 0.05,
    seed: 4,
  );

  /// The whole neuron as one outline: its body, every branch, the hillock
  /// and the axon, as one shape, [count] points round it from its top,
  /// clockwise on screen.
  Contour outline({int count = 520}) {
    final Path all = Path()..addPath(body.toPath(), Offset.zero);
    for (final NeuronBranch b in <NeuronBranch>[...dendrites, hillock, axon]) {
      all.addPath(b.path, Offset.zero);
    }
    final Path union = Path.combine(PathOperation.union, all, Path());
    PathMetric? longest;
    for (final PathMetric m in union.computeMetrics()) {
      if (longest == null || m.length > longest.length) {
        longest = m;
      }
    }
    final PathMetric loop = longest!;
    final List<Offset> points = <Offset>[
      for (int i = 0; i < count; i++)
        loop.getTangentForOffset(loop.length * i / count)!.position,
    ];
    // Clockwise on screen, as every other outline runs.
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % points.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    return Contour(area < 0 ? points.reversed.toList() : points)
        .resampled(count);
  }
}
