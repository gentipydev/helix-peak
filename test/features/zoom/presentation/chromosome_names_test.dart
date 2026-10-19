import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/chromosome_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../../gene_lookup/anatomy/anatomy_fixture.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card; on
/// an iPhone SE under the card's tallest words; and on a narrow one.
const List<Size> _canvases = <Size>[
  Size(390, 560),
  Size(375, 421),
  Size(320, 420),
];

/// Each part the chromosome names, and the side of it its name is set on.
const Map<String, double> _sides = <String, double>{
  'p arm': -1,
  'centromere': -1,
  'q arm': -1,
  'chromatid': 1,
  'telomere': 1,
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

  testWidgets('the chromosome names its parts beside it, each level with '
      'what it names on its own side, clear of the drawing, for every '
      'curated protein', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in _canvases) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        final double d = stage.depth.depthOf(ZoomStop.chromosome);
        final ChromosomeScene scene =
            stage.scenes[ZoomStop.chromosome.index] as ChromosomeScene;
        final ZoomFrame frame = <ZoomFrame>[
          for (final (ZoomScene s, ZoomFrame f) in stage.frames(d, size, inks))
            if (identical(s, scene)) f,
        ].single;
        final List<Offset> rim = <Offset>[
          for (final Offset p in scene.form.outline().points)
            frame.toScreen(p),
        ];
        final Path drawn = Path()..addPolygon(rim, true);
        final List<ZoomCallout> callouts = stage
            .stage(d, size, inks)
            .callouts;
        expect(
          <String>[
            for (final ZoomCallout c in callouts)
              if (c.quiet) c.text,
          ],
          _sides.keys.toList(),
          reason: t.slug,
        );
        final Map<String, int> anchors = stage.restingAnchors(
          d,
          size,
          inks,
          labels,
        );
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
          placed.add(plate);
          if (!c.quiet) {
            continue;
          }
          final String what = '${t.slug} at $size: ${c.text}, $plate';
          expect(c.opacity, 1, reason: what);
          expect(drawn.contains(c.target), isTrue, reason: what);
          // Level with what it names on its own side, or a step off it
          // where another name is there.
          expect(anchors[c.key], inInclusiveRange(0, 2), reason: what);
          expect(
            (plate.center.dx - frame.toScreen(Offset.zero).dx).sign,
            _sides[c.text],
            reason: what,
          );
          // Over none of the chromosome.
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
          expect(rim.where(plate.contains), isEmpty, reason: what);
        }
      }
    }
  });
}
