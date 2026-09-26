import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

final class _Three extends AnimationTimeline<double> {
  const _Three();

  @override
  int get beats => 3;

  @override
  List<PhaseMark> get phases => const <PhaseMark>[
    PhaseMark(name: 'Scanning', t: 0, captionKey: 'scan'),
    PhaseMark(name: 'Peptide bond', t: 1 / 3, captionKey: 'bond'),
    PhaseMark(name: 'A very long phase name that has to wrap', t: 2 / 3,
        captionKey: 'long'),
  ];

  @override
  double stateAt(double t) => t;
}

void main() {
  late TimelineController controller;

  setUp(() {
    controller = TimelineController(
      vsync: const TestVSync(),
      timeline: const _Three(),
      beat: const Duration(milliseconds: 100),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> host(
    WidgetTester tester, {
    double textScale = 1,
    bool disableAnimations = false,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 200,
                  child: TimelineScrubber(
                    controller: controller,
                    landmarks: const <(double, String)>[
                      (0, 'Start'),
                      (0.5, 'Middle'),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TransportBar(controller: controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the phase by name, never as a number', (
    WidgetTester tester,
  ) async {
    await host(tester);
    expect(find.text('Scanning'), findsOneWidget);
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(find.text('Peptide bond'), findsOneWidget);
    expect(controller.t, 1 / 3);
    final RegExp number = RegExp(r'^[0-9.]+$');
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Text && number.hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );
  });

  testWidgets('every control is labelled and at least 44 pixels square', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await host(tester);
    for (final String label in <String>[
      'Reset',
      'Step back',
      'Play',
      'Step forward',
      'Playback speed',
    ]) {
      final Size size = tester.getSize(find.byTooltip(label));
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('announces each phase change to a screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await host(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey<String>('transport-phase'))),
      matchesSemantics(isLiveRegion: true, label: 'Scanning'),
    );
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const ValueKey<String>('transport-phase'))),
      matchesSemantics(isLiveRegion: true, label: 'Peptide bond'),
    );
    semantics.dispose();
  });

  testWidgets('play and pause swap, and the label says which it will do', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(controller.isPlaying, isTrue);
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(controller.isPlaying, isFalse);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('step back, reset and the speed all reach the controller', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.tap(find.byTooltip('Step forward'));
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(controller.t, 2 / 3);
    await tester.tap(find.byTooltip('Step back'));
    await tester.pump();
    expect(controller.t, 1 / 3);
    await tester.tap(find.byTooltip('Reset'));
    await tester.pump();
    expect(controller.t, 0);

    expect(find.text('1×'), findsOneWidget);
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2×').last);
    await tester.pumpAndSettle();
    expect(controller.speed, 2);
    expect(find.text('2×'), findsOneWidget);
  });

  testWidgets('stays whole at the largest text scale', (
    WidgetTester tester,
  ) async {
    await host(tester, textScale: 3.2, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Step forward'));
    await tester.tap(find.byTooltip('Step forward'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final Finder phase = find.byKey(const ValueKey<String>('transport-phase'));
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      phase,
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    // Every control is still on screen, however the row wrapped.
    for (final String label in <String>[
      'Reset',
      'Step back',
      'Play',
      'Step forward',
      'Playback speed',
    ]) {
      final Rect box = tester.getRect(find.byTooltip(label));
      expect(box.right, lessThanOrEqualTo(320), reason: label);
      expect(box.bottom, lessThanOrEqualTo(640), reason: label);
    }
  });

  testWidgets('reduced motion reaches the controller', (
    WidgetTester tester,
  ) async {
    await host(tester, disableAnimations: true);
    await tester.pump();
    expect(controller.reducedMotion, isTrue);
  });

  testWidgets('dragging the scrubber pauses and seeks; playing moves it', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.pump();
    final Finder scrubber = find.byKey(
      const ValueKey<String>('sequence-scrubber'),
    );
    expect(scrubber, findsOneWidget);
    controller.play();
    await tester.pump();
    await tester.drag(scrubber, const Offset(0, 200));
    await tester.pump();
    expect(controller.isPlaying, isFalse);
    expect(controller.t, greaterThan(0));

    final Finder thumb = find.byKey(
      const ValueKey<String>('sequence-scrubber-thumb'),
    );
    controller.seek(0);
    await tester.pump();
    final double top = tester.getTopLeft(thumb).dy;
    controller.seek(1);
    await tester.pump();
    expect(tester.getTopLeft(thumb).dy, greaterThan(top + 100));
  });
}
