import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/lung/lung_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

import '../../../support/test_catalog.dart';
import '../../gene_lookup/anatomy/anatomy_fixture.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas at the lungs, under its card and inside the canvas's
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

/// The names the lungs' stop sets for SP-D's alveolar type 2 cell, in the
/// order they are staged.
const List<String> _words = <String>[
  'alveoli',
  'trachea',
  'bronchus',
  'pulmonary\nartery',
  'upper lobe',
  'lower lobe',
  'right lung',
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

  testWidgets('the lungs’ names are set round them, out at the canvas’s '
      'corners, clear of both lungs and the trachea, of one another and of '
      'the scale bar, no line crossing another or running through another’s '
      'plate, on every phone’s canvas', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final String slug in <String>['surfactantd']) {
      final ProteinTarget t = TestCatalog.bySlug(slug)!;
      for (final Size size in _canvases) {
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
                  for (double s = 0; s < m.length; s += m.length / 600)
                    m.getTangentForOffset(s)!.position,
                ],
              ))
            frame.toScreen(p),
        ];
        // The left lung, and the right lung and the trachea beside it.
        final LungForm form = LungForm.place(
          part: subject.bodyPart!,
          anatomy: subject.anatomy!,
          view: subject.depth.widthOf(ZoomStop.organ),
        );
        final List<Offset> trachea = <Offset>[
          for (int i = 0; i < form.trachea.length; i++)
            frame.toScreen(form.trachea.at(i, 1)),
          for (int i = form.trachea.length - 1; i >= 0; i--)
            frame.toScreen(form.trachea.at(i, -1)),
        ];
        final Path drawn = Path()
          ..addPolygon(outline, true)
          ..addPolygon(<Offset>[
            for (final Offset p in form.rightPoints) frame.toScreen(p),
          ], true)
          ..addPolygon(trachea, true);
        final Rect lungs = drawn.getBounds();
        final List<ZoomCallout> callouts = <ZoomCallout>[
          for (final ZoomCallout c in stage.stage(d, size, inks).callouts)
            if (c.key.startsWith('organ:')) c,
        ];
        expect(
          <String>[for (final ZoomCallout c in callouts) c.text],
          _words,
          reason: '$slug at $size',
        );
        final Map<String, RingPlate> rings = stage.ringsAt(
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
          final String what = '$slug at $size: ${c.text}, $plate';
          expect(c.opacity, 1, reason: what);
          expect(c.quiet, c.text != 'alveoli', reason: what);
          // In a band above the lungs or below them, never over them.
          expect(
            plate.bottom <= lungs.top + 1 || plate.top >= lungs.bottom - 1,
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
            ].where(drawn.contains),
            isEmpty,
            reason: what,
          );
          // On the canvas, clear of its edges, of the other names and of
          // the scale bar.
          expect(plate.left, greaterThanOrEqualTo(0), reason: what);
          expect(plate.top, greaterThanOrEqualTo(0), reason: what);
          expect(
            plate.right,
            lessThanOrEqualTo(size.width - ZoomOverlayPainter.margin),
            reason: what,
          );
          expect(plate.bottom, lessThanOrEqualTo(size.height), reason: what);
          expect(plate.overlaps(scale), isFalse, reason: what);
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
    }
  });
}
