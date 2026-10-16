import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/chromatin_layout.dart';

void main() {
  const ChromatinLayout chromatin = ChromatinLayout();
  const List<double> packings = <double>[0, 0.2, 0.5, 0.8, 1];

  test('the bare stretch round the gene’s start never moves, so its 5′ end '
      'stays where it is however far the fibre is packed', () {
    for (final double packed in packings) {
      for (
        double o = ChromatinLayout.bareUpstream;
        o <= ChromatinLayout.first;
        o += 5
      ) {
        expect(chromatin.axisAt(o, packed), closeTo(o, 1e-9));
      }
      expect(chromatin.axisAt(0, packed), 0);
    }
  });

  test('lies along the genome unpacked, and in order along the fibre however '
      'far it is packed', () {
    for (final double packed in packings) {
      double last = double.negativeInfinity;
      for (double o = -3000; o <= 3000; o += 1.5) {
        final double at = chromatin.axisAt(o, packed);
        if (packed == 0) {
          expect(at, o);
        }
        expect(at, greaterThan(last), reason: 'at $o, $packed packed');
        last = at;
      }
    }
  });

  test('a nucleosome every 200 bp from 40 bp into the gene, the promoter’s '
      'upstream of its bare start, each winding 147 bp', () {
    final List<(double, double)> beads = chromatin.nucleosomesWithin(
      -1000,
      1000,
    );
    double? last;
    for (final (double start, double end) in beads) {
      expect(end - start, ChromatinLayout.wrapped);
      if (last != null) {
        expect(start, greaterThan(last));
      }
      last = start;
      if (start >= 0) {
        expect((start - ChromatinLayout.first) % ChromatinLayout.period, 0);
      } else {
        expect(
          (ChromatinLayout.bareUpstream - end) % ChromatinLayout.period,
          0,
        );
      }
    }
    expect(
      beads.map(((double, double) b) => b.$1),
      containsAll(<double>[40, 240, 440, 640, 840]),
    );
    expect(beads.map(((double, double) b) => b.$2), contains(-220));
    // None lies across the bare stretch round the start.
    for (final (double start, double end) in beads) {
      expect(
        end <= ChromatinLayout.bareUpstream || start >= ChromatinLayout.first,
        isTrue,
      );
    }
  });

  test('packed, a nucleosome takes the length its core does, and the place '
      'along the fibre finds the point laid there at any packing', () {
    const double start = 440;
    expect(
      chromatin.axisAt(start + ChromatinLayout.wrapped, 1) -
          chromatin.axisAt(start, 1),
      closeTo(ChromatinLayout.across, 1e-9),
    );
    for (final double packed in packings) {
      for (double o = -3000; o <= 3000; o += 0.75) {
        expect(
          chromatin.offsetAt(chromatin.axisAt(o, packed), packed),
          closeTo(o, 1e-6),
          reason: 'at $o, $packed packed',
        );
      }
    }
  });

  test('a core sits where its DNA starts winding, the first past the start '
      'never moving and the others drawn in without a jump', () {
    for (final double packed in packings) {
      expect(
        chromatin.coreAt(ChromatinLayout.first, packed),
        ChromatinLayout.first + ChromatinLayout.across / 2,
      );
    }
    for (int i = 0; i < 100; i++) {
      final double a = chromatin.coreAt(640, i / 100);
      final double b = chromatin.coreAt(640, (i + 1) / 100);
      // Drawn in by the three nucleosomes before it.
      expect(a - b, inInclusiveRange(0, 3 * 122.3 / 100 + 1e-9));
    }
  });

  test('a nucleosome’s DNA goes 1.65 times round its core on the superhelix, '
      'left-handed', () {
    const double tilt = ChromatinLayout.tilt;
    final double from = ChromatinLayout.wayIn;
    final double to = 1 - ChromatinLayout.wayOut;
    // Back into the core's frame: along its face, round it, and up its axis.
    (double, double, double) inCore(FibrePoint p) => (
      p.along,
      p.across * math.cos(tilt) + p.depth * math.sin(tilt),
      -p.across * math.sin(tilt) + p.depth * math.cos(tilt),
    );
    double? last;
    double turned = 0;
    const int steps = 4000;
    for (int i = 0; i <= steps; i++) {
      final (double x, double round, double _) = inCore(
        ChromatinLayout.coilAt(from + (to - from) * i / steps),
      );
      final double angle = math.atan2(round, x);
      if (last != null) {
        double d = angle - last;
        if (d > math.pi) {
          d -= 2 * math.pi;
        }
        if (d < -math.pi) {
          d += 2 * math.pi;
        }
        turned += d;
      }
      last = angle;
      expect(
        math.sqrt(x * x + round * round),
        closeTo(ChromatinLayout.radius, 1e-6),
      );
    }
    expect(turned.abs() / (2 * math.pi), closeTo(ChromatinLayout.turns, 1e-3));
    // Left-handed: it steps along the core's axis the other way to its turn,
    // as the superhelix of Luger et al. (1997) does.
    final (double _, double _, double up0) = inCore(
      ChromatinLayout.coilAt(from),
    );
    final (double _, double _, double up1) = inCore(ChromatinLayout.coilAt(to));
    expect(turned * (up1 - up0), lessThan(0));
  });

  test('a nucleosome’s DNA leaves the fibre’s axis before its core and comes '
      'back to it after, along it, and is one line all the way round', () {
    final FibrePoint first = ChromatinLayout.coilAt(0);
    final FibrePoint last = ChromatinLayout.coilAt(1);
    expect(first.along, closeTo(-ChromatinLayout.reach, 1e-9));
    expect(last.along, closeTo(ChromatinLayout.reach, 1e-9));
    for (final FibrePoint p in <FibrePoint>[first, last]) {
      expect(p.across, closeTo(0, 1e-9));
      expect(p.depth, closeTo(0, 1e-9));
    }
    // Along the axis where it leaves it and where it comes back.
    for (final (double a, double b) in <(double, double)>[
      (0, 1e-4),
      (1 - 1e-4, 1),
    ]) {
      final FibrePoint p = ChromatinLayout.coilAt(a);
      final FibrePoint q = ChromatinLayout.coilAt(b);
      final double dx = q.along - p.along;
      expect(dx, greaterThan(0));
      expect((q.across - p.across).abs() / dx, lessThan(0.01));
      expect((q.depth - p.depth).abs() / dx, lessThan(0.01));
    }
    // No break: neighbouring points a small step apart all the way round,
    // over the joins between its way in, its turns and its way out.
    const int steps = 4000;
    double longest = 0;
    double whole = 0;
    FibrePoint? before;
    for (int i = 0; i <= steps; i++) {
      final FibrePoint p = ChromatinLayout.coilAt(i / steps);
      if (before != null) {
        final double d = math.sqrt(
          math.pow(p.along - before.along, 2) +
              math.pow(p.across - before.across, 2) +
              math.pow(p.depth - before.depth, 2),
        );
        longest = math.max(longest, d);
        whole += d;
      }
      before = p;
    }
    expect(longest, lessThan(4 * whole / steps));
  });
}
