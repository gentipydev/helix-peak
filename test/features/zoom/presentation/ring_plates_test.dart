import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

/// The zoom's names, in the app's own type, as the screen sets them.
final TextStyle _labels = AppTheme.analysis.textTheme.labelSmall!;

Future<void> _loadFont(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(File(path).readAsBytesSync().buffer),
      ),
    );
  }
  await loader.load();
}

Future<ZoomInks> _inks(WidgetTester tester) async {
  late ZoomInks inks;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          inks = ZoomInks.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return inks;
}

/// A round shape of [radius] about [centre], as points.
List<Offset> _round(Offset centre, double radius) =>
    Contour.blob(centre, radius, radius * 0.95, count: 128).points;

/// Names round [outline], each at its target, in order.
List<ZoomCallout> _names(List<Offset> outline, List<(String, Offset)> names) {
  final ZoomRing ring = ZoomRing('shape', outline);
  return <ZoomCallout>[
    for (final (String text, Offset target) in names)
      ZoomCallout(
        key: text,
        text: text,
        target: target,
        opacity: 1,
        quiet: true,
        ring: ring,
      ),
  ];
}

/// [plate] keeps off [outline]: none of its points lies in the plate, and
/// neither do the plate's corners and middle lie inside it.
void _expectOff(Rect plate, List<Offset> outline, String reason) {
  final Path inside = Contour(outline).toPath();
  for (final Offset p in outline) {
    expect(plate.contains(p), isFalse, reason: reason);
  }
  for (final Offset corner in <Offset>[
    plate.topLeft,
    plate.topRight,
    plate.bottomLeft,
    plate.bottomRight,
    plate.center,
  ]) {
    expect(inside.contains(corner), isFalse, reason: reason);
  }
}

void main() {
  setUpAll(
    () => _loadFont(AppTypography.sansFamily, <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
    ]),
  );

  test('a name is broken onto two lines at the space nearest its middle', () {
    expect(twoLines('secretory granules'), 'secretory\ngranules');
    expect(twoLines('Golgi apparatus, cytosol'), 'Golgi apparatus,\ncytosol');
    expect(twoLines('axon hillock'), 'axon\nhillock');
    expect(twoLines('nucleolus'), 'nucleolus');
  });

  testWidgets('round a shape, each name is set beside it on the side nearer '
      'what it names, off it, on the canvas, clear of the others', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    final Offset middle = size.center(Offset.zero);
    final List<Offset> outline = _round(middle, 80);
    final List<ZoomCallout> names = _names(outline, <(String, Offset)>[
      ('left', middle + const Offset(-40, -20)),
      ('right', middle + const Offset(50, 10)),
      ('high', middle + const Offset(-20, -60)),
      ('low', middle + const Offset(30, 55)),
    ]);
    final Map<String, RingHold> held = ringHolds(names, _labels, inks, size);
    final Map<String, RingPlate> plates = ringPlates(
      names,
      _labels,
      inks,
      size,
    );
    expect(held['left']!.side, RingSide.left);
    expect(held['high']!.side, RingSide.left);
    expect(held['right']!.side, RingSide.right);
    expect(held['low']!.side, RingSide.right);
    final List<Rect> placed = <Rect>[];
    for (final ZoomCallout c in names) {
      final Rect plate = plates[c.key]!.plate;
      _expectOff(plate, outline, c.key);
      expect(plate.left, greaterThanOrEqualTo(ZoomOverlayPainter.margin));
      expect(
        plate.right,
        lessThanOrEqualTo(size.width - ZoomOverlayPainter.margin),
      );
      for (final Rect other in placed) {
        expect(plate.overlaps(other), isFalse, reason: c.key);
      }
      placed.add(plate);
      // Beside: level with what it names, its plate hugging the outline.
      expect((plate.center.dy - c.target.dy).abs(), lessThan(14));
      final double gap = held[c.key]!.side == RingSide.left
          ? outline.map((Offset p) => p.dx).reduce(math.min) - plate.right
          : plate.left - outline.map((Offset p) => p.dx).reduce(math.max);
      expect(gap, lessThanOrEqualTo(ringGap + 0.5), reason: c.key);
    }
  });

  testWidgets('a name with no room beside the shape on one line goes on two '
      'there, and one with room on neither goes to the row above or below '
      'it, the nearer first', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(320, 420);
    final Offset middle = size.center(Offset.zero);
    // A shape that leaves 78 px beside it, past its gap and the margin:
    // room for 'secretory' (a 75 px plate), not for 'mitochondrion'.
    final List<Offset> outline = _round(middle, 64);
    final List<ZoomCallout> names = _names(outline, <(String, Offset)>[
      // Two lines of 'secretory' fit beside it; one line does not.
      ('secretory granules', middle + const Offset(40, 0)),
      // One word, too wide for the side: above, its target being high.
      ('mitochondrion', middle + const Offset(-30, -40)),
      // And below, its target being low, but not so low that the shape
      // narrows enough to leave it room beside it.
      ('peroxisomes', middle + const Offset(-30, 25)),
    ]);
    final Map<String, RingHold> held = ringHolds(names, _labels, inks, size);
    final Map<String, RingPlate> plates = ringPlates(
      names,
      _labels,
      inks,
      size,
    );
    expect(held['secretory granules']!.side, RingSide.right);
    expect(held['secretory granules']!.wrapped, isTrue);
    expect(plates['secretory granules']!.wrapped, isTrue);
    expect(held['mitochondrion']!.side, RingSide.above);
    expect(held['peroxisomes']!.side, RingSide.below);
    final double top = outline.map((Offset p) => p.dy).reduce(math.min);
    final double bottom = outline.map((Offset p) => p.dy).reduce(math.max);
    expect(plates['mitochondrion']!.plate.bottom, lessThanOrEqualTo(top));
    expect(plates['peroxisomes']!.plate.top, greaterThanOrEqualTo(bottom));
    for (final RingPlate r in plates.values) {
      _expectOff(r.plate, outline, '${r.plate}');
    }
  });

  testWidgets('names on one side are stacked in the order of what they name, '
      'so no two lines cross', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    final Offset middle = size.center(Offset.zero);
    final List<Offset> outline = _round(middle, 90);
    final List<ZoomCallout> names = _names(outline, <(String, Offset)>[
      for (int i = 0; i < 6; i++)
        ('n$i', middle + Offset(40 + (i % 2) * 10, -50 + i * 6.0)),
    ]);
    final Map<String, RingPlate> plates = ringPlates(
      names,
      _labels,
      inks,
      size,
    );
    for (int i = 1; i < 6; i++) {
      final Rect above = plates['n${i - 1}']!.plate;
      final Rect below = plates['n$i']!.plate;
      expect(below.top, greaterThanOrEqualTo(above.bottom + ringStack - 1e-6));
    }
  });

  testWidgets('held, the plates move as the shape is scaled about a point, '
      'as though drawn on it, never jumping, and are at rest where they '
      'were set', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    final Offset middle = size.center(Offset.zero);
    final List<Offset> outline = _round(middle, 85);
    final List<(String, Offset)> at = <(String, Offset)>[
      ('Golgi', middle + const Offset(-40, -30)),
      ('rough ER', middle + const Offset(-55, 20)),
      ('secretory granules', middle + const Offset(60, 5)),
      ('mitochondria', middle + const Offset(10, 70)),
      ('nucleolus', middle + const Offset(-10, -15)),
    ];
    final Map<String, RingHold> held = ringHolds(
      _names(outline, at),
      _labels,
      inks,
      size,
    );
    Map<String, Rect> platesAt(double k) {
      Offset scaled(Offset p) => middle + (p - middle) * k;
      return <String, Rect>{
        for (final MapEntry<String, RingPlate> e in ringPlates(
          _names(
            <Offset>[for (final Offset p in outline) scaled(p)],
            <(String, Offset)>[
              for (final (String name, Offset p) in at) (name, scaled(p)),
            ],
          ),
          _labels,
          inks,
          size,
          held: held,
        ).entries)
          e.key: e.value.plate,
      };
    }

    final Map<String, RingPlate> rest = ringPlates(
      _names(outline, at),
      _labels,
      inks,
      size,
    );
    final Map<String, Rect> one = platesAt(1);
    for (final String key in rest.keys) {
      expect(one[key]!.center.dx, closeTo(rest[key]!.plate.center.dx, 1e-6));
      expect(one[key]!.center.dy, closeTo(rest[key]!.plate.center.dy, 1e-6));
    }
    Map<String, Rect> before = platesAt(0.6);
    for (int i = 1; i <= 1000; i++) {
      final Map<String, Rect> now = platesAt(0.6 + i / 1000);
      for (final String key in now.keys) {
        expect(
          (now[key]!.center - before[key]!.center).distance,
          lessThan(1),
          reason: '$key at ${0.6 + i / 1000}',
        );
      }
      before = now;
    }
  });
}
