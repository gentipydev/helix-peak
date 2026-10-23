import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/esophagus/esophagus_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../../gene_lookup/anatomy/anatomy_fixture.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas at the esophagus, under its card and inside the
/// canvas's inset: the tests' phone and their squattest canvas, an iPhone
/// 17 Pro's and an iPhone SE 3's; and, without the inset, an iPhone SE 3's
/// under a card of two lines, the esophagus's. Squatter canvases still
/// (an SE 3's under a card of three lines, the first iPhone SE's) are
/// shorter than the esophagus stands, and its names at either end step off
/// their level there.
const List<Size> _canvases = <Size>[
  Size(390, 560),
  Size(320, 420),
  Size(338, 559),
  Size(311, 407),
  Size(375, 477),
];

/// The names cystatin B's esophagus sets, in the order they are staged, and
/// the side of the canvas each is set on: what lies on the body's right,
/// the left as the body shows it, on the left.
const Map<String, double> _sides = <String, double>{
  'mucosa': -1,
  'pharynx': -1,
  'upper sphincter': 1,
  'cervical': -1,
  'aortic arch': 1,
  'thoracic': -1,
  'diaphragm': -1,
  'lower sphincter': 1,
  'abdominal': 1,
  'Z-line': -1,
  'stomach': 1,
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

  testWidgets('the esophagus stands whole on the canvas, its names in a '
      'column at either edge, each level with what it names on its own '
      'side, clear of the esophagus and what is drawn beside it, of one '
      'another and of the scale bar, no line crossing another or running '
      'through another’s plate, on every phone’s canvas', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    final ProteinTarget t = TestCatalog.bySlug('cystatinb')!;
    for (final Size size in _canvases) {
      final ZoomStage stage = _stage(t);
      final ZoomSubject subject = stage.subject;
      final double d = stage.depth.depthOf(ZoomStop.organ);
      final OrganScene scene = stage.scenes[ZoomStop.organ.index] as OrganScene;
      final ZoomFrame frame = <ZoomFrame>[
        for (final (ZoomScene s, ZoomFrame f) in stage.frames(d, size, inks))
          if (identical(s, scene)) f,
      ].single;
      final List<Offset> outline = <Offset>[
        for (final Offset p
            in OrganArt.of(subject).outline.computeMetrics().expand(
              (PathMetric m) => <Offset>[
                for (double s = 0; s < m.length; s += m.length / 800)
                  m.getTangentForOffset(s)!.position,
              ],
            ))
          frame.toScreen(p),
      ];
      final Path drawn = Path()..addPolygon(outline, true);
      // What is drawn beside it: the pharynx, the stomach, the aorta and
      // the diaphragm, round their courses, as they show.
      final EsophagusForm form = EsophagusForm.place(
        part: subject.bodyPart!,
        anatomy: subject.anatomy!,
        view: subject.depth.widthOf(ZoomStop.organ),
        home: EsophagusHome.of(subject.path.cellName),
      );
      final double unit =
          frame.toScreen(const Offset(1, 0)).dx -
          frame.toScreen(Offset.zero).dx;
      final List<(Offset, double)> beside = <(Offset, double)>[
        for (final TubeCourse tube in form.beside)
          for (int i = 0; i < tube.length; i++)
            if (tube.shown[i] > 0.1)
              (frame.toScreen(tube.centres[i]), tube.radius[i] * unit),
      ];
      bool covers(Offset p) =>
          drawn.contains(p) ||
          beside.any(((Offset, double) c) => (p - c.$1).distance < c.$2);
      Rect whole = drawn.getBounds();
      for (final (Offset c, double r) in beside) {
        whole = whole.expandToInclude(Rect.fromCircle(center: c, radius: r));
      }
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
      expect(<String>[
        for (final ZoomCallout c in callouts) c.text,
      ], _sides.keys.toList());
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
        final String what = 'at $size: ${c.text}, $plate';
        expect(c.opacity, 1, reason: what);
        expect(c.flush, isTrue, reason: what);
        expect(c.quiet, c.text != 'mucosa', reason: what);
        // Level with what it names on its own side, or a step off it where
        // another name is there.
        expect(anchors[c.key], inInclusiveRange(0, 2), reason: what);
        // In a column at the canvas's edge on that side.
        expect(
          _sides[c.text]! < 0 ? plate.left : size.width - plate.right,
          closeTo(ZoomOverlayPainter.margin, 1e-9),
          reason: what,
        );
        // Over none of the esophagus or what is drawn beside it, no other
        // name and not the scale bar.
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
              '$size: ${callouts[i].text} and ${callouts[j].text}';
          expect(_through(lines[i], placed[j]), isFalse, reason: pair);
          if (j > i) {
            expect(linesCross(lines[i], lines[j]), isFalse, reason: pair);
          }
        }
      }
    }
  });
}
