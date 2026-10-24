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

/// The zoom's canvas at the fat, under its card of one line and inside
/// the canvas's inset: an iPhone 17 Pro's, under a card of one line and of
/// two, and an iPhone SE 3's, as the screen gives them; the SE 3's under a
/// card of two lines; the tests' phone and their squattest canvas; and,
/// without the inset, an SE 3's, under a card of one line and of two, and a
/// first iPhone SE's.
const List<Size> _canvases = <Size>[
  Size(338, 634),
  Size(338, 559),
  Size(311, 427),
  Size(311, 407),
  Size(390, 560),
  Size(320, 420),
  Size(375, 477),
  Size(375, 421),
  Size(320, 376),
];

/// The names leptin's fat sets, in the order they are staged, and the side
/// of the canvas each is set on: the fat where the cell lives, a septum and
/// the deep fat on the left; the membranous layer and the rectus on the
/// right.
const Map<String, Map<String, double>> _sides = <String, Map<String, double>>{
  'leptin': <String, double>{
    'fat\nlobules': -1,
    'septum': -1,
    'Scarpa\u2019s\nfascia': 1,
    'deep fat': -1,
    'rectus': 1,
  },
};

ZoomStage _stage(ProteinTarget t) =>
    ZoomStage(ZoomSubject(track: locusOf(t), record: recordOf(t)));

/// The zoom's inks and the style its names are set in, as the screen has
/// them: the theme's own small labels, with the line height the app's
/// typography gives them.
Future<(ZoomInks, TextStyle)> _inks(WidgetTester tester) async {
  late ZoomInks inks;
  late TextStyle labels;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          inks = ZoomInks.of(context);
          labels = Theme.of(context).textTheme.labelSmall!;
          return const SizedBox();
        },
      ),
    ),
  );
  return (inks, labels);
}

/// Whether the line [line] runs through [plate], other than from its own.
bool _through((Offset, Offset) line, Rect plate) {
  final Rect inner = plate.deflate(1);
  for (int k = 1; k < 40; k++) {
    final Offset p = Offset.lerp(line.$1, line.$2, k / 40)!;
    if (inner.contains(p)) {
      return true;
    }
  }
  return false;
}

void main() {
  // The names are measured in the app's own type: the test font's square
  // glyphs set every word half as wide again.
  setUpAll(loadAppFonts);

  testWidgets('the fat stands whole on the canvas, its names in a '
      'column at either edge, each level with what it names on its own side '
      'or a step off it, clear of the block, of one another and of the '
      'scale bar, no line crossing another or running through another’s '
      'plate, on every phone’s canvas', (WidgetTester tester) async {
    final (ZoomInks inks, TextStyle labels) = await _inks(tester);
    for (final MapEntry<String, Map<String, double>> entry in _sides.entries) {
      for (final Size size in _canvases) {
        final ProteinTarget t = TestCatalog.bySlug(entry.key)!;
        final Map<String, double> sides = entry.value;
        final ZoomStage stage = _stage(t);
        final ZoomSubject subject = stage.subject;
        final double d = stage.depth.depthOf(ZoomStop.organ);
        final OrganScene scene =
            stage.scenes[ZoomStop.organ.index] as OrganScene;
        final ZoomFrame frame = <ZoomFrame>[
          for (final (ZoomScene s, ZoomFrame f) in stage.frames(d, size, inks))
            if (identical(s, scene)) f,
        ].single;
        final List<Offset> outline = <Offset>[
          for (final Offset p
              in OrganArt.of(subject).outline.computeMetrics().expand(
                (PathMetric m) => <Offset>[
                  for (double s = 0; s < m.length; s += m.length / 1200)
                    m.getTangentForOffset(s)!.position,
                ],
              ))
            frame.toScreen(p),
        ];
        final Path drawn = Path()..addPolygon(outline, true);
        bool covers(Offset p) => drawn.contains(p);
        final Rect whole = drawn.getBounds();
        // Whole on the canvas.
        expect(
          (Offset.zero & size).contains(whole.topLeft) &&
              (Offset.zero & size).contains(whole.bottomRight),
          isTrue,
          reason: 'at $size: $whole',
        );
        final List<ZoomCallout> callouts = <ZoomCallout>[
          for (final ZoomCallout c in stage.stage(d, size, inks).callouts)
            if (c.key.startsWith('organ:')) c,
        ];
        expect(
          <String>[for (final ZoomCallout c in callouts) c.text],
          sides.keys.toList(),
          reason: '${t.slug} at $size',
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
        final List<(Offset, Offset)> lines = <(Offset, Offset)>[];
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
          expect(c.quiet, c.text != sides.keys.first, reason: what);
          // Level with what it names on its own side, or a step off it where
          // another name is there.
          expect(anchors[c.key], inInclusiveRange(0, 2), reason: what);
          // In a column at the canvas's edge on that side.
          expect(
            sides[c.text]! < 0 ? plate.left : size.width - plate.right,
            closeTo(ZoomOverlayPainter.margin, 1e-9),
            reason: what,
          );
          // Over none of the block, no other name and not the scale bar.
          expect(
            <Offset>[
              for (int i = 0; i <= 8; i++)
                for (int j = 0; j <= 4; j++)
                  Offset(
                    plate.left + plate.width * i / 8,
                    plate.top + plate.height * j / 4,
                  ),
            ].where(covers),
            isEmpty,
            reason: what,
          );
          for (final Rect other in placed) {
            expect(plate.overlaps(other), isFalse, reason: what);
          }
          expect(plate.overlaps(scale), isFalse, reason: what);
          placed.add(plate);
          lines.add(lineFrom(plate, c.target));
        }
        for (int i = 0; i < lines.length; i++) {
          for (int j = 0; j < lines.length; j++) {
            if (i == j) {
              continue;
            }
            final String pair =
                '${t.slug} at $size: ${callouts[i].text} and ${callouts[j].text}';
            expect(_through(lines[i], placed[j]), isFalse, reason: pair);
            if (j > i) {
              expect(linesCross(lines[i], lines[j]), isFalse, reason: pair);
            }
          }
        }
      }
    }
  });
}
