import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/zoom_scene.dart';
import 'package:helixpeek/features/lab/zoom/presentation/scenes/zoom_subject.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_inks.dart';
import 'package:helixpeek/features/lab/zoom/presentation/zoom_painter.dart';

import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom's canvas on a phone, under the app bar and above the card.
const Size _canvas = Size(390, 560);

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

bool _onCanvas(Offset p) =>
    p.dx > -_canvas.width &&
    p.dx < 2 * _canvas.width &&
    p.dy > -_canvas.height &&
    p.dy < 2 * _canvas.height;

/// Walks [depths] in order, staging each without drawing, and fails on a
/// pop (something appearing or vanishing at more than [pop] opacity), a
/// blink (opacity changing by more than [pop] in one step) or a jump (a
/// position's second difference past [jerk] pixels) of anything on or near
/// the canvas.
void _expectSmooth(
  ZoomStage stage,
  ZoomInks inks,
  List<double> depths, {
  double pop = 0.08,
  double jerk = 1.5,
  required String what,
}) {
  Map<String, (Offset, double)>? before;
  Map<String, (Offset, double)>? last;
  for (final double d in depths) {
    final Map<String, (Offset, double)> now = stage
        .stage(d, _canvas, inks)
        .items;
    if (last != null) {
      for (final String key in <String>{...now.keys, ...last.keys}) {
        final double a = last[key]?.$2 ?? 0;
        final double b = now[key]?.$2 ?? 0;
        expect(
          (b - a).abs(),
          lessThanOrEqualTo(pop),
          reason: '$what: $key blinks or pops at depth $d ($a → $b)',
        );
      }
      if (before != null) {
        for (final String key in now.keys) {
          final (Offset, double)? p0 = before[key];
          final (Offset, double)? p1 = last[key];
          final (Offset, double) p2 = now[key]!;
          if (p0 == null || p1 == null) {
            continue;
          }
          if (p2.$2 < 0.02 || !_onCanvas(p0.$1) || !_onCanvas(p2.$1)) {
            continue;
          }
          final Offset second = p2.$1 - p1.$1 * 2 + p0.$1;
          final Offset centre = _canvas.center(Offset.zero);
          final bool focus = (p1.$1 - centre).distance < 160;
          // Near the focus nothing may jolt. Further out, things fly outward
          // as the view narrows, faster the further they are, so there the
          // check is for a break: a step that is not of a piece with the
          // last.
          final double allowed = focus
              ? jerk
              : math.max(jerk, 0.3 * (p2.$1 - p1.$1).distance + 2);
          expect(
            second.distance,
            lessThanOrEqualTo(allowed),
            reason: '$what: $key jumps at depth $d',
          );
        }
      }
    }
    before = last;
    last = now;
  }
}

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

void main() {
  setUpAll(
    () => _loadFont(AppTypography.sansFamily, <String>[
      'assets/fonts/SpaceGrotesk-Regular.ttf',
      'assets/fonts/SpaceGrotesk-Medium.ttf',
    ]),
  );

  testWidgets('every protein’s dive moves without a pop, a blink or a jump, '
      'at fine steps of depth', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProteinTarget t in TestCatalog.all) {
      final ZoomStage stage = _stage(t);
      final ZoomDepth depth = stage.depth;
      const int steps = 6000;
      _expectSmooth(stage, inks, <double>[
        for (int i = 0; i <= steps; i++) depth.total * i / steps,
      ], what: t.slug);
    }
  });

  testWidgets('Play moves without a pop, a blink or a jump, at 60 fps', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    // The longest glide of all: the protein whose organ lies farthest from
    // the middle of the body.
    final ProteinTarget farthest = TestCatalog.all.reduce(
      (ProteinTarget a, ProteinTarget b) =>
          _stage(a).scenes.first.portal.distance >=
              _stage(b).scenes.first.portal.distance
          ? a
          : b,
    );
    for (final ProteinTarget t in <ProteinTarget>{
      TestCatalog.hemoglobin,
      TestCatalog.dystrophin,
      TestCatalog.amylase,
      farthest,
    }) {
      final ZoomStage stage = _stage(t);
      final PlaySchedule play = PlaySchedule(stage.depth, from: 0);
      final int frames = (play.length.inMicroseconds / 1e6 * 60).ceil();
      _expectSmooth(stage, inks, <double>[
        for (int f = 0; f <= frames; f++)
          play.at(Duration(microseconds: (f * 1e6 / 60).round())),
      ], what: '${t.slug} playing');
    }
  });

  testWidgets('no two names overlap, and none lies under the rail, at any '
      'stop, at two widths', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final TextStyle labels = AppTheme.analysis.textTheme.labelSmall!;
    for (final Size size in <Size>[_canvas, const Size(320, 420)]) {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomStage stage = _stage(t);
        for (final ZoomStop stop in ZoomStop.values) {
          final ZoomStaging staging = stage.stage(
            stage.depth.depthOf(stop),
            size,
            inks,
          );
          final List<Rect> placed = <Rect>[];
          for (final ZoomCallout callout in staging.callouts) {
            final TextPainter text = calloutText(callout, labels, inks, size);
            final Rect plate = placePlate(
              callout.target,
              text.size,
              size,
              placed,
            );
            text.dispose();
            for (final Rect other in placed) {
              expect(
                plate.overlaps(other),
                isFalse,
                reason: '${t.slug} at ${stop.name}: ${callout.text} overlaps',
              );
            }
            expect(
              plate.right,
              lessThanOrEqualTo(size.width - ZoomPainter.railStrip),
              reason: '${t.slug} at ${stop.name}: ${callout.text} under rail',
            );
            expect(plate.left, greaterThanOrEqualTo(0));
            expect(plate.top, greaterThanOrEqualTo(0));
            placed.add(plate);
          }
          // Each stop names what it follows.
          expect(
            staging.callouts.where((ZoomCallout c) => c.opacity > 0.5),
            isNotEmpty,
            reason: '${t.slug} at ${stop.name} names nothing',
          );
        }
      }
    }
  });

  test('the callout plate lands where its line can reach its target', () {
    const Size size = Size(390, 560);
    const Offset target = Offset(200, 300);
    final Rect plate = placePlate(target, const Size(60, 16), size, <Rect>[]);
    expect(plate.left, greaterThan(target.dx));
    expect(plate.bottom, lessThan(target.dy));
    final Rect second = placePlate(
      target,
      const Size(60, 16),
      size,
      <Rect>[plate],
    );
    expect(second.overlaps(plate), isFalse);
    expect(math.max(second.top - plate.bottom, plate.top - second.bottom),
        greaterThan(-1));
  });
}
