import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../../gene_lookup/anatomy/anatomy_fixture.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas at the heart, under its card and inside the canvas's
/// inset: the tests' phone and their squattest canvas, an iPhone 17 Pro's
/// and an iPhone SE 3's, measured on the zoom's own screen.
const List<Size> _canvases = <Size>[
  Size(390, 560),
  Size(320, 420),
  Size(338, 559),
  Size(311, 407),
];

/// The names the heart's stop sets for a cardiomyocyte, and the side of the
/// canvas each of the chambers' is set on: the heart's right on the left,
/// as the body shows it.
const List<String> _words = <String>[
  'right atrium',
  'left atrium',
  'right ventricle',
  'left ventricle',
  'myocardium',
];
const Map<String, double> _sides = <String, double>{
  'right atrium': -1,
  'right ventricle': -1,
  'left atrium': 1,
  'left ventricle': 1,
};

ZoomStage _stage(ProteinTarget t) =>
    ZoomStage(ZoomSubject(track: locusOf(t), record: recordOf(t)));

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

void main() {
  // The names are measured in the app's own type: the test font's square
  // glyphs set every word half as wide again.
  setUpAll(loadAppFonts);

  testWidgets('the heart’s names are set round it, the atria’s above and '
      'the ventricles’ below, the right heart’s on the left, clear of the '
      'heart, of one another and of the scale bar, their lines never '
      'crossing, on every phone’s canvas', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    final ProteinTarget t = TestCatalog.bySlug('phospholamban')!;
    for (final Size size in _canvases) {
      final ZoomStage stage = _stage(t);
      final double d = stage.depth.depthOf(ZoomStop.organ);
      final OrganScene scene = stage.scenes[ZoomStop.organ.index] as OrganScene;
      final ZoomFrame frame = <ZoomFrame>[
        for (final (ZoomScene s, ZoomFrame f) in stage.frames(d, size, inks))
          if (identical(s, scene)) f,
      ].single;
      final List<Offset> outline = <Offset>[
        for (final Offset p
            in OrganArt.of(stage.subject).outline.computeMetrics().expand(
              (PathMetric m) => <Offset>[
                for (double s = 0; s < m.length; s += m.length / 600)
                  m.getTangentForOffset(s)!.position,
              ],
            ))
          frame.toScreen(p),
      ];
      final Path drawn = Path()..addPolygon(outline, true);
      final Rect heart = drawn.getBounds();
      final List<ZoomCallout> callouts = <ZoomCallout>[
        for (final ZoomCallout c in stage.stage(d, size, inks).callouts)
          if (c.key.startsWith('organ:')) c,
      ];
      expect(
        <String>[for (final ZoomCallout c in callouts) c.text],
        _words,
        reason: '$size',
      );
      final Map<String, RingPlate> rings = stage.ringsAt(d, size, inks, labels);
      final (double pixels, String reads) = scaleBarAt(stage.depth, d, size);
      final TextPainter bar = TextPainter(
        text: TextSpan(text: reads, style: labels),
        textDirection: TextDirection.ltr,
      )..layout();
      final Rect scale = scaleBarBox(pixels, bar.size, size);
      bar.dispose();
      final List<Rect> placed = <Rect>[];
      final List<(Offset, Offset)> lines = <(Offset, Offset)>[];
      for (final ZoomCallout c in callouts) {
        final Rect plate = rings[c.key]!.plate;
        final String what = '$size: ${c.text}, $plate';
        expect(c.opacity, 1, reason: what);
        expect(c.quiet, c.text != 'myocardium', reason: what);
        // In a band above or below the heart, never over it.
        expect(
          plate.bottom <= heart.top + 1 || plate.top >= heart.bottom - 1,
          isTrue,
          reason: what,
        );
        expect(
          <Offset>[
            for (int i = 0; i <= 8; i++)
              for (int j = 0; j <= 4; j++)
                Offset(
                  plate.left + plate.width * i / 8,
                  plate.top + plate.height * j / 4,
                ),
          ].where(drawn.contains),
          isEmpty,
          reason: what,
        );
        // The atria above it, the ventricles below; the right heart's on
        // the left.
        if (c.text.contains('atrium')) {
          expect(plate.bottom, lessThanOrEqualTo(heart.top + 1), reason: what);
        }
        if (c.text.contains('ventricle')) {
          expect(
            plate.top,
            greaterThanOrEqualTo(heart.bottom - 1),
            reason: what,
          );
        }
        final double? side = _sides[c.text];
        if (side != null) {
          expect(
            (plate.center.dx - size.width / 2) * side,
            greaterThan(0),
            reason: what,
          );
        }
        // On the canvas, clear of its edges, of the other names and of the
        // scale bar.
        expect(plate.left, greaterThanOrEqualTo(0), reason: what);
        expect(plate.top, greaterThanOrEqualTo(0), reason: what);
        expect(
          plate.right,
          lessThanOrEqualTo(size.width - ZoomOverlayPainter.margin),
          reason: what,
        );
        expect(plate.bottom, lessThanOrEqualTo(size.height), reason: what);
        for (final Rect other in placed) {
          expect(plate.overlaps(other), isFalse, reason: what);
        }
        expect(plate.overlaps(scale), isFalse, reason: what);
        placed.add(plate);
        lines.add(lineFrom(plate, c.target));
      }
      for (int i = 0; i < lines.length; i++) {
        for (int j = i + 1; j < lines.length; j++) {
          expect(
            linesCross(lines[i], lines[j]),
            isFalse,
            reason: '$size: ${callouts[i].text} and ${callouts[j].text}',
          );
        }
      }
    }
  });
}
