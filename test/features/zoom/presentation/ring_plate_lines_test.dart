import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_painter.dart';

/// The names set round a shape (a cell's), on two lines at the most and never
/// wider than the canvas (the user's decision of 2026-11-13): TEKT4's
/// spermatid names six places of its tail, 93 letters.
void main() {
  setUpAll(() async {
    final FontLoader loader = FontLoader(AppTypography.sansFamily);
    for (final String path in <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
    ]) {
      loader.addFont(
        Future<ByteData>.value(
          ByteData.view(File(path).readAsBytesSync().buffer),
        ),
      );
    }
    await loader.load();
  });

  final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;

  // A cell 160 wide in the middle of the canvas.
  ZoomCallout named(String text, Size size, {String key = 'cell'}) {
    final Offset middle = size.center(Offset.zero);
    return ZoomCallout(
      key: key,
      text: text,
      target: middle + const Offset(30, -20),
      opacity: 1,
      ring: ZoomRing('cell', <Offset>[
        for (int i = 0; i < 24; i++)
          middle +
              Offset(
                80 * math.cos(2 * math.pi * i / 24),
                70 * math.sin(2 * math.pi * i / 24),
              ),
      ]),
    );
  }

  const String tail =
      'perinuclear theca, connecting piece, flagellar centriole, principal '
      'piece, end piece, annulus';

  for (final Size size in const <Size>[Size(358, 560), Size(343, 470)]) {
    final String at = '${size.width.toInt()} wide';

    testWidgets('a name too long for one line goes on two, across the canvas '
        'at the most, $at', (WidgetTester tester) async {
      final ZoomInks inks = await _inks(tester);
      final ZoomCallout callout = named(tail, size);
      final TextPainter text = calloutText(
        callout,
        labels,
        inks,
        size,
        wrapped: true,
      );
      expect(text.width, lessThanOrEqualTo(ringTextWidth(size)), reason: at);
      expect(text.computeLineMetrics().length, lessThanOrEqualTo(2));
      expect(text.didExceedMaxLines, isFalse, reason: at);
      text.dispose();
      final Rect plate = ringPlates(
        <ZoomCallout>[callout],
        labels,
        inks,
        size,
      )['cell']!.plate;
      expect(plate.left, greaterThanOrEqualTo(0), reason: at);
      expect(
        plate.right,
        lessThanOrEqualTo(size.width - ZoomOverlayPainter.margin),
        reason: at,
      );
    });

    testWidgets('a name too long for two lines loses its third to an '
        'ellipsis, never the canvas, $at', (WidgetTester tester) async {
      final ZoomInks inks = await _inks(tester);
      final ZoomCallout callout = named('$tail, $tail, $tail', size);
      expect(calloutElided(callout, labels, inks, size, wrapped: true), isTrue);
      final TextPainter text = calloutText(
        callout,
        labels,
        inks,
        size,
        wrapped: true,
      );
      expect(text.width, lessThanOrEqualTo(ringTextWidth(size)));
      expect(text.computeLineMetrics().length, 2);
      text.dispose();
    });
  }

  testWidgets('a name whose halves fit is broken at its middle space, as '
      'before', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(358, 560);
    const String words = 'Golgi apparatus, actin filaments';
    final TextPainter text = calloutText(
      named(words, size),
      labels,
      inks,
      size,
      wrapped: true,
    );
    expect((text.text! as TextSpan).text, twoLines(words));
    expect(
      calloutElided(named(words, size), labels, inks, size, wrapped: true),
      isFalse,
    );
    text.dispose();
  });

  testWidgets('a name that fits on one line is laid on one', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    const Size size = Size(358, 560);
    final TextPainter text = calloutText(
      named('cytosol', size),
      labels,
      inks,
      size,
    );
    expect(text.computeLineMetrics().length, 1);
    text.dispose();
  });
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
