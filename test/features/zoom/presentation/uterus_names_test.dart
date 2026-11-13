import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/uterus/uterus_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../../gene_lookup/anatomy/anatomy_fixture.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas at the uterus, under its card and inside the canvas's
/// inset: the tests' phone and their squattest canvas, an iPhone 17 Pro's
/// and an iPhone SE 3's; and, without the inset, an iPhone SE 3's under a
/// card of two lines and of three, and the first iPhone SE's.
const List<Size> _canvases = <Size>[
  Size(390, 560),
  Size(320, 420),
  Size(338, 559),
  Size(311, 407),
  Size(375, 477),
  Size(375, 421),
  Size(320, 376),
];

/// The names the uterus's stop sets for glycodelin, in the order they are
/// staged.
const List<String> _words = <String>[
  'endometrial glands',
  'myometrium',
  'fallopian tube',
  'cervical canal',
  'uterine artery',
];

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

  testWidgets('the uterus’s names are set round it, out at the canvas’s '
      'corners, above it and below it, clear of the uterus, its tubes, its '
      'ligaments and its arteries, of one another and of the scale bar, no '
      'line crossing another or running through another’s plate, on every '
      'phone’s canvas', (WidgetTester tester) async {
    final (ZoomInks inks, TextStyle labels) = await _inks(tester);
    final ProteinTarget t = TestCatalog.bySlug('glycodelin')!;
    for (final Size size in _canvases) {
      final ZoomStage stage = _stage(t);
      final ZoomSubject subject = stage.subject;
      final double d = stage.depth.depthOf(ZoomStop.organ);
      final OrganScene scene = stage.scenes[ZoomStop.organ.index] as OrganScene;
      final ZoomFrame frame = <ZoomFrame>[
        for (final (ZoomScene s, ZoomFrame f) in stage.frames(d, size, inks))
          if (identical(s, scene)) f,
      ].single;
      final UterusForm form = UterusForm.place(
        part: subject.bodyPart!,
        anatomy: subject.anatomy!,
        view: subject.depth.widthOf(ZoomStop.organ),
        home: UterusHome.of(subject.path.cellName),
      );
      List<Offset> screen(List<Offset> points) => <Offset>[
        for (final Offset p in points) frame.toScreen(p),
      ];
      // The uterus, as drawn.
      final Path drawn = Path()..addPolygon(screen(form.outlinePoints), true);
      final Rect uterus = drawn.getBounds();
      // Its tubes, ligaments and arteries, round their courses, as they
      // show.
      final double unit =
          frame.toScreen(const Offset(1, 0)).dx -
          frame.toScreen(Offset.zero).dx;
      final List<(Offset, double)> beside = <(Offset, double)>[
        for (final TubeCourse tube in form.beside)
          for (int i = 0; i < tube.length; i++)
            if (tube.shown[i] > 0.3)
              (frame.toScreen(tube.centres[i]), tube.radius[i] * unit),
      ];
      final Rect reach = beside.fold<Rect>(
        uterus,
        (Rect r, (Offset, double) c) =>
            r.expandToInclude(Rect.fromCircle(center: c.$1, radius: c.$2)),
      );
      bool covers(Offset p) =>
          drawn.contains(p) ||
          beside.any(((Offset, double) c) => (p - c.$1).distance < c.$2);
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
      final List<Rect> plates = <Rect>[
        for (final ZoomCallout c in callouts) rings[c.key]!.plate,
      ];
      final List<(Offset, Offset)> lines = <(Offset, Offset)>[
        for (int i = 0; i < callouts.length; i++)
          lineFrom(plates[i], callouts[i].target),
      ];
      for (int i = 0; i < callouts.length; i++) {
        final ZoomCallout c = callouts[i];
        final Rect plate = plates[i];
        final String what = '$size: ${c.text}, $plate';
        expect(c.opacity, 1, reason: what);
        expect(c.quiet, c.text != 'endometrial glands', reason: what);
        // Above its middle or below it, out at the canvas's corners: a row
        // below it may come up beside the cervix where the cervix is narrow,
        // but never over anything drawn.
        expect(
          plate.bottom <= reach.center.dy || plate.top >= reach.center.dy,
          isTrue,
          reason: what,
        );
        expect(
          <Offset>[
            for (int a = 0; a <= 8; a++)
              for (int b = 0; b <= 4; b++)
                Offset(
                  plate.left + plate.width * a / 8,
                  plate.top + plate.height * b / 4,
                ),
          ].where(covers),
          isEmpty,
          reason: what,
        );
        // On the canvas, clear of its edges, of the other names and of the
        // scale bar; what it names on the canvas too.
        expect(plate.left, greaterThanOrEqualTo(0), reason: what);
        expect(plate.top, greaterThanOrEqualTo(0), reason: what);
        expect(
          plate.right,
          lessThanOrEqualTo(size.width - ZoomOverlayPainter.margin),
          reason: what,
        );
        expect(plate.bottom, lessThanOrEqualTo(size.height), reason: what);
        expect(plate.overlaps(scale), isFalse, reason: what);
        expect((Offset.zero & size).contains(c.target), isTrue, reason: what);
        for (int j = 0; j < callouts.length; j++) {
          if (j == i) {
            continue;
          }
          final String pair = '$what and ${callouts[j].text}';
          expect(plate.overlaps(plates[j]), isFalse, reason: pair);
          expect(_through(lines[i], plates[j]), isFalse, reason: pair);
          if (j > i) {
            expect(linesCross(lines[i], lines[j]), isFalse, reason: pair);
          }
        }
      }
    }
  });
}
