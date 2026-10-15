import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/chromatin_layout.dart';

void main() {
  const ChromatinLayout chromatin = ChromatinLayout();
  const List<double> windings = <double>[0, 0.2, 0.5, 0.8, 1];

  test('the bare stretch round the gene’s start never moves, so its 5′ end '
      'stays where it is however far the DNA is wound', () {
    for (final double wound in windings) {
      for (
        double o = ChromatinLayout.bareUpstream;
        o <= ChromatinLayout.first;
        o += 5
      ) {
        expect(chromatin.axisAt(o, wound), closeTo(o, 1e-9));
      }
      expect(chromatin.axisAt(0, wound), 0);
    }
  });

  test('lies along the genome unwound, and in order along the fibre however '
      'far it is wound', () {
    for (final double wound in windings) {
      double last = double.negativeInfinity;
      for (double o = -3000; o <= 3000; o += 1.5) {
        final double at = chromatin.axisAt(o, wound);
        if (wound == 0) {
          expect(at, o);
        }
        expect(at, greaterThan(last), reason: 'at $o, $wound wound');
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

  test('wound, a nucleosome takes the length its core does, its DNA going '
      '1.65 times round the core, left-handed, from where the gene’s stop '
      'laid it', () {
    const double start = 440;
    expect(
      chromatin.axisAt(start + ChromatinLayout.wrapped, 1) -
          chromatin.axisAt(start, 1),
      closeTo(ChromatinLayout.across, 1e-9),
    );
    // Unwound, its stretch is the line the gene's stop lays it on.
    for (double o = start; o <= start + ChromatinLayout.wrapped; o += 7) {
      final FibrePoint p = chromatin.woundAt(start, o, 0);
      expect(p.along, o);
      expect(p.across, 0);
      expect(p.depth, 0);
    }
    // Wound, its points go round the core's axis: count the turns, seen
    // down the axis, from the in-plane angle.
    final double centre =
        chromatin.axisAt(start, 1) + ChromatinLayout.across / 2;
    const double tilt = ChromatinLayout.tilt;
    double? last;
    double turned = 0;
    const int steps = 2000;
    for (int i = 0; i <= steps; i++) {
      final double o = start + ChromatinLayout.wrapped * i / steps;
      final FibrePoint p = chromatin.woundAt(start, o, 1);
      // Back into the core's frame: along its face, and round it.
      final double x = p.along - centre;
      final double round = p.across * math.cos(tilt) + p.depth * math.sin(tilt);
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
      // Every point is the superhelix's radius from the core's axis.
      expect(
        math.sqrt(x * x + round * round),
        closeTo(ChromatinLayout.radius, 1e-6),
      );
    }
    expect(turned / (2 * math.pi), closeTo(ChromatinLayout.turns, 1e-3));
    // Left-handed: going round, it steps down the core's axis.
    double up(double o) {
      final FibrePoint p = chromatin.woundAt(start, o, 1);
      return -p.across * math.sin(tilt) + p.depth * math.cos(tilt);
    }

    expect(up(start + ChromatinLayout.wrapped), lessThan(up(start)));
  });

  test('a stretch winds without a jump: its points move a little for a '
      'little more winding, and its ends meet the DNA either side', () {
    // The second nucleosome past the start: as the first winds, it is drawn
    // in, by at most the bases the two of them and their linker hold for
    // each share of the winding.
    const double start = 240;
    const double most =
        3 * ChromatinLayout.wrapped / 100 + ChromatinLayout.radius / 10;
    for (double o = start; o <= start + ChromatinLayout.wrapped; o += 3) {
      for (int i = 0; i < 100; i++) {
        final FibrePoint a = chromatin.woundAt(start, o, i / 100);
        final FibrePoint b = chromatin.woundAt(start, o, (i + 1) / 100);
        final double moved = math.sqrt(
          math.pow(b.along - a.along, 2) + math.pow(b.across - a.across, 2),
        );
        expect(moved, lessThan(most), reason: 'at $o, ${i / 100}');
      }
    }
    // Its first point is where the DNA before it reaches it.
    for (final double wound in windings) {
      final FibrePoint p = chromatin.woundAt(start, start, wound);
      expect(p.along, closeTo(chromatin.axisAt(start, wound), 1e-9));
    }
  });
}
