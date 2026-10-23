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

/// The zoom's canvas at the thigh, under its card and inside the canvas's
/// inset: the tests' phone and their squattest canvas, an iPhone 17 Pro's,
/// an iPhone SE 3's, and a first iPhone SE's.
const List<Size> _canvases = <Size>[
  Size(390, 560),
  Size(320, 420),
  Size(338, 559),
  Size(311, 407),
  Size(288, 344),
];

/// The names the thigh's stop sets, and the side of the canvas each is set
/// on: the lateral muscles' on the left, as the body shows its right
/// thigh.
const Map<String, double> _sides = <String, double>{
  'vastus\nlateralis': -1,
  'rectus\nfemoris': -1,
  'sartorius': 1,
  'vastus\nmedialis': 1,
};

/// The curated proteins whose zoom goes into skeletal muscle.
final List<ProteinTarget> _muscle = <ProteinTarget>[
  for (final String slug in <String>['myoglobin', 'dystrophin'])
    TestCatalog.bySlug(slug)!,
];

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

  testWidgets('the thigh stands whole on the canvas, its names in a column '
      'at either edge, each level with what it names on its own side, clear '
      'of the thigh, of one another and of the scale bar, for every protein '
      'that goes into skeletal muscle', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in _canvases) {
      for (final ProteinTarget t in _muscle) {
        final ZoomStage stage = _stage(t);
        final double d = stage.depth.depthOf(ZoomStop.organ);
        final OrganScene scene =
            stage.scenes[ZoomStop.organ.index] as OrganScene;
        final ZoomFrame frame = <ZoomFrame>[
          for (final (ZoomScene s, ZoomFrame f) in stage.frames(d, size, inks))
            if (identical(s, scene)) f,
        ].single;
        final List<Offset> outline = <Offset>[
          for (final Offset p
              in OrganArt.of(stage.subject).outline.computeMetrics().expand(
                (PathMetric m) => <Offset>[
                  for (double s = 0; s < m.length; s += m.length / 400)
                    m.getTangentForOffset(s)!.position,
                ],
              ))
            frame.toScreen(p),
        ];
        final Path drawn = Path()..addPolygon(outline, true);
        // Whole on the canvas.
        expect(
          (Offset.zero & size).contains(drawn.getBounds().topLeft) &&
              (Offset.zero & size).contains(drawn.getBounds().bottomRight),
          isTrue,
          reason: '${t.slug} at $size: ${drawn.getBounds()}',
        );
        final List<ZoomCallout> callouts = stage.stage(d, size, inks).callouts;
        expect(
          <String>[for (final ZoomCallout c in callouts) c.text],
          _sides.keys.toList(),
          reason: t.slug,
        );
        final Map<String, int> anchors = stage.restingAnchors(
          d,
          size,
          inks,
          labels,
        );
        final (double pixels, String reads) = scaleBarAt(stage.depth, d, size);
        final TextPainter bar = TextPainter(
          text: TextSpan(text: reads, style: labels),
          textDirection: TextDirection.ltr,
        )..layout();
        final Rect scale = scaleBarBox(pixels, bar.size, size);
        bar.dispose();
        final List<Rect> placed = <Rect>[];
        for (final ZoomCallout c in callouts) {
          final TextPainter text = calloutText(c, labels, inks, size);
          final Rect plate = calloutPlate(
            stage,
            d,
            c,
            text.size,
            size,
            placed,
            inks,
            labels,
          );
          text.dispose();
          final String what = '${t.slug} at $size: ${c.text}, $plate';
          expect(c.opacity, 1, reason: what);
          expect(c.flush, isTrue, reason: what);
          expect(c.quiet, c.text != 'vastus\nlateralis', reason: what);
          // Level with what it names on its own side, or a step off it
          // where another name is there.
          expect(anchors[c.key], inInclusiveRange(0, 2), reason: what);
          // In a column at the canvas's edge on that side.
          expect(
            _sides[c.text]! < 0 ? plate.left : size.width - plate.right,
            closeTo(ZoomOverlayPainter.margin, 1e-9),
            reason: what,
          );
          // Over none of the thigh, no other name and not the scale bar.
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
          for (final Rect other in placed) {
            expect(plate.overlaps(other), isFalse, reason: what);
          }
          expect(plate.overlaps(scale), isFalse, reason: what);
          placed.add(plate);
        }
      }
    }
  });
}
