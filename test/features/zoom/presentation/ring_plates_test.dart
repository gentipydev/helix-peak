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

/// No two of the lines from [plates] to what [names] name cross.
void _expectUncrossed(List<ZoomCallout> names, Map<String, RingPlate> plates) {
  for (int i = 0; i < names.length; i++) {
    for (int j = i + 1; j < names.length; j++) {
      expect(
        linesCross(
          lineFrom(plates[names[i].key]!.plate, names[i].target),
          lineFrom(plates[names[j].key]!.plate, names[j].target),
        ),
        isFalse,
        reason: '${names[i].key} and ${names[j].key}',
      );
    }
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

  testWidgets('round a shape, each name is set in the corner nearer what it '
      'names: above or below it, out at the canvas\'s edge on its side, off '
      'it, on the canvas, clear of the others', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    final Offset middle = size.center(Offset.zero);
    final List<Offset> outline = _round(middle, 130);
    final List<ZoomCallout> names = _names(outline, <(String, Offset)>[
      ('high left', middle + const Offset(-60, -40)),
      ('high right', middle + const Offset(70, -20)),
      ('low left', middle + const Offset(-80, 10)),
      ('low right', middle + const Offset(30, 75)),
    ]);
    final Map<String, RingHold> held = ringHolds(names, _labels, inks, size);
    final Map<String, RingPlate> plates = ringPlates(
      names,
      _labels,
      inks,
      size,
    );
    expect(held['high left']!.side, RingSide.above);
    expect(held['high right']!.side, RingSide.above);
    expect(held['low left']!.side, RingSide.below);
    expect(held['low right']!.side, RingSide.below);
    const double margin = ZoomOverlayPainter.margin;
    final List<Rect> placed = <Rect>[];
    for (final ZoomCallout c in names) {
      final Rect plate = plates[c.key]!.plate;
      _expectOff(plate, outline, c.key);
      expect(plate.top, greaterThanOrEqualTo(margin), reason: c.key);
      expect(plate.bottom, lessThanOrEqualTo(size.height - 50), reason: c.key);
      // Against the canvas's edge on its side.
      if (c.key.endsWith('left')) {
        expect(plate.left, closeTo(margin, 1e-6), reason: c.key);
      } else {
        expect(plate.right, closeTo(size.width - margin, 1e-6), reason: c.key);
      }
      // In its band: wholly above what it names, or wholly below.
      if (held[c.key]!.side == RingSide.above) {
        expect(plate.bottom, lessThan(c.target.dy), reason: c.key);
      } else {
        expect(plate.top, greaterThan(c.target.dy), reason: c.key);
      }
      for (final Rect other in placed) {
        expect(plate.overlaps(other), isFalse, reason: c.key);
      }
      placed.add(plate);
    }
    _expectUncrossed(names, plates);
  });

  testWidgets('a name with no room on one line goes on two; a band with no '
      'room left sends a name a row further out, and a shape with no room '
      'above it sends its names below', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(320, 420);
    final Offset middle = size.center(Offset.zero);
    final List<Offset> outline = _round(middle, 100);
    // Five names over the top of the shape: one row cannot hold them.
    final List<ZoomCallout> many = _names(outline, <(String, Offset)>[
      ('secretory granules', middle + const Offset(-70, -30)),
      ('endoplasmic reticulum', middle + const Offset(-40, -50)),
      ('mitochondria', middle + const Offset(10, -60)),
      ('lysosomes', middle + const Offset(40, -40)),
      ('Golgi apparatus', middle + const Offset(60, -20)),
    ]);
    final Map<String, RingHold> held = ringHolds(many, _labels, inks, size);
    final Map<String, RingPlate> plates = ringPlates(
      many,
      _labels,
      inks,
      size,
    );
    expect(
      held.values.map((RingHold h) => h.row).reduce(math.max),
      greaterThan(0),
    );
    expect(held.values.any((RingHold h) => h.wrapped), isTrue);
    final List<Rect> placed = <Rect>[];
    for (final ZoomCallout c in many) {
      final Rect plate = plates[c.key]!.plate;
      _expectOff(plate, outline, c.key);
      expect(plate.left, greaterThanOrEqualTo(ZoomOverlayPainter.margin));
      expect(
        plate.right,
        lessThanOrEqualTo(size.width - ZoomOverlayPainter.margin),
      );
      expect(plate.top, greaterThanOrEqualTo(ZoomOverlayPainter.margin));
      for (final Rect other in placed) {
        expect(plate.overlaps(other), isFalse, reason: c.key);
      }
      placed.add(plate);
    }
    // A shape against the top of the canvas: its high names go below it.
    final List<Offset> high = _round(Offset(middle.dx, 110), 100);
    final List<ZoomCallout> under = _names(high, <(String, Offset)>[
      ('Golgi', Offset(middle.dx - 40, 80)),
    ]);
    final RingHold golgi = ringHolds(under, _labels, inks, size)['Golgi']!;
    expect(golgi.side, RingSide.below);
    _expectOff(
      ringPlates(under, _labels, inks, size)['Golgi']!.plate,
      high,
      'Golgi',
    );
  });

  testWidgets('a corner of a shape that runs on down its middle, as a '
      'neuron\'s axon does, still has room beside it for a name', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    final Offset middle = size.center(Offset.zero);
    // A body with a thin process down to the canvas's foot.
    final List<Offset> outline = <Offset>[
      for (final Offset p in _round(middle, 90))
        if (p.dy < middle.dy + 80 || (p.dx - middle.dx).abs() > 8) p,
      Offset(middle.dx + 6, size.height),
      Offset(middle.dx - 6, size.height),
    ];
    final List<ZoomCallout> names = _names(outline, <(String, Offset)>[
      ('axon', Offset(middle.dx - 2, middle.dy + 150)),
    ]);
    final Map<String, RingHold> held = ringHolds(names, _labels, inks, size);
    expect(held['axon']!.side, RingSide.below);
    final Rect plate = ringPlates(names, _labels, inks, size)['axon']!.plate;
    expect(plate.bottom, lessThanOrEqualTo(size.height - 50));
    expect(plate.left, closeTo(ZoomOverlayPainter.margin, 1e-6));
  });

  testWidgets('in a band the plates follow what they name across it, so no '
      'two lines cross', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(390, 560);
    final Offset middle = size.center(Offset.zero);
    final List<Offset> outline = _round(middle, 120);
    final List<ZoomCallout> names = _names(outline, <(String, Offset)>[
      for (int i = 0; i < 6; i++)
        ('n$i', middle + Offset(-90 + i * 36.0, -30 - (i % 3) * 25.0)),
    ]);
    final Map<String, RingPlate> plates = ringPlates(
      names,
      _labels,
      inks,
      size,
    );
    _expectUncrossed(names, plates);
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
