import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/lab_routes.dart';
import 'package:helixpeek/features/lab/presentation/lab_protein_picker.dart';
import 'package:helixpeek/features/replication/domain/replication_tour.dart';
import 'package:helixpeek/features/replication/presentation/replication_scene.dart';
import 'package:helixpeek/features/replication/presentation/replication_screen.dart';
import 'package:helixpeek/features/replication/replication_routes.dart';
import 'package:helixpeek/shared/motion/timeline_controller.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

import '../../gene_lookup/anatomy/anatomy_fixture.dart';

TimelineController controllerOf(WidgetTester tester) =>
    tester.widget<TransportBar>(find.byType(TransportBar)).controller;

Future<void> host(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  EdgeInsets safeInsets = EdgeInsets.zero,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
          padding: safeInsets,
          viewPadding: safeInsets,
        ),
        child: child!,
      ),
      home: const ReplicationScreen(),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('opens and plays locally without a catalog or a gene', (
    WidgetTester tester,
  ) async {
    await host(tester);
    expect(find.text('Replication'), findsOneWidget);
    expect(find.text('Human DNA · 200 bp'), findsOneWidget);
    expect(find.byType(LabProteinPicker), findsNothing);
    expect(controllerOf(tester).isPlaying, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(
      controllerOf(tester).t,
      closeTo(3 / ReplicationTimeline.durationSeconds, 0.001),
    );
    controllerOf(tester).pause();
    final double paused = controllerOf(tester).t;
    await tester.pump(const Duration(seconds: 2));
    expect(controllerOf(tester).t, paused);
  });

  testWidgets('its own route and old lab links open the genome animation', (
    WidgetTester tester,
  ) async {
    final GoRouter router = buildAppRouter(
      extra: <RouteBase>[...replicationRoutes, ...buildLabRoutes()],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (final String path in <String>[
      RoutePaths.replication,
      '/lab/replication',
      '/lab/replication/insulin',
    ]) {
      router.go(path);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final Finder screen = find.byType(ReplicationScreen);
      expect(screen, findsOneWidget, reason: path);
      expect(
        router.routeInformationProvider.value.uri.path,
        RoutePaths.replication,
      );
      // Out of the lab's shell, it still wears the walk's theme.
      expect(
        Theme.of(tester.element(screen)).scaffoldBackgroundColor,
        AppTheme.analysis.scaffoldBackgroundColor,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'seeking and stepping give the caption for each biological phase',
    (WidgetTester tester) async {
      await host(tester);
      final TimelineController c = controllerOf(tester)..reset();
      for (final ReplicationChapter stage in ReplicationChapter.values) {
        c.seek(stage.second / ReplicationTimeline.durationSeconds);
        await tester.pump();
        final Text caption = tester.widget(
          find.byKey(const ValueKey<String>('replication-caption')),
        );
        expect(caption.data, ReplicationMoment(stage.second).caption);
        expect(find.text(stage.title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      c.reset();
      c.stepToNextPhase();
      expect(
        c.t,
        ReplicationChapter.licensing.second /
            ReplicationTimeline.durationSeconds,
      );
      c.stepToPreviousPhase();
      expect(c.t, 0);
      c.seek(1);
      c.play();
      expect(c.atEnd, isFalse);
    },
  );

  testWidgets('reduced motion opens on a still and supports phase stepping', (
    WidgetTester tester,
  ) async {
    await host(tester, reducedMotion: true);
    final TimelineController c = controllerOf(tester);
    expect(c.isPlaying, isFalse);
    expect(c.reducedMotion, isTrue);
    c.stepToNextPhase();
    await tester.pump();
    expect(c.phase?.name, ReplicationChapter.licensing.title);
  });

  testWidgets('the side scrubber seeks without scrolling the scene', (
    WidgetTester tester,
  ) async {
    await host(tester, size: const Size(320, 568));
    final TimelineController c = controllerOf(tester);
    final Finder canvas = find.byKey(
      const ValueKey<String>('replication-canvas'),
    );
    final Offset scenePosition = tester.getTopLeft(canvas);
    final Finder scrubber = find.byKey(
      const ValueKey<String>('sequence-scrubber'),
    );
    final Rect track = tester.getRect(scrubber);
    final TestGesture drag = await tester.startGesture(
      Offset(track.center.dx, track.top + 20),
    );
    await drag.moveTo(Offset(track.center.dx, track.bottom - 20));
    await tester.pump();
    expect(c.isPlaying, isFalse);
    expect(c.t, 1);
    expect(find.textContaining('212 / 212 s'), findsOneWidget);
    expect(tester.getTopLeft(canvas), scenePosition);
    await drag.moveTo(Offset(track.center.dx, track.top + 20));
    await drag.up();
    await tester.pump();
    expect(c.t, 0);
    expect(tester.getTopLeft(canvas), scenePosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'whole fork and close-ups share the same paused synthesis state',
    (WidgetTester tester) async {
      await host(tester);
      final TimelineController c = controllerOf(tester)
        ..pause()
        ..seek(177 / ReplicationTimeline.durationSeconds);
      await tester.pump();
      ReplicationScene scene() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey<String>('replication-canvas')),
                  )
                  .painter!
              as ReplicationScene;
      final ReplicationMoment moment = scene().timeline.stateAt(scene().at());
      expect(scene().followCamera, isTrue);
      await tester.tap(find.text('Whole fork'));
      await tester.pump();
      expect(scene().followCamera, isFalse);
      expect(scene().timeline.stateAt(scene().at()), moment);
      await tester.tap(find.text('Follow steps'));
      await tester.pump();
      expect(scene().followCamera, isTrue);
      expect(c.isPlaying, isFalse);
      expect(scene().timeline.stateAt(scene().at()), moment);
      await tester.tap(find.byTooltip('Hide molecule labels'));
      await tester.pump();
      expect(scene().showLabels, isFalse);
      expect(scene().timeline.stateAt(scene().at()), moment);
    },
  );

  testWidgets(
    'phone safe areas leave playback controls visible in every phase',
    (WidgetTester tester) async {
      const Size phone = Size(390, 844);
      const EdgeInsets insets = EdgeInsets.only(top: 59, bottom: 34);
      await host(tester, size: phone, safeInsets: insets);
      final TimelineController c = controllerOf(tester)..pause();
      for (final ReplicationChapter chapter in ReplicationChapter.values) {
        c.seek((chapter.second + 3) / ReplicationTimeline.durationSeconds);
        await tester.pump();
        for (final String tooltip in <String>[
          'Reset',
          'Step back',
          'Play',
          'Step forward',
          'Playback speed',
        ]) {
          final Finder control = find.byTooltip(tooltip);
          expect(
            control.hitTestable(),
            findsOneWidget,
            reason: '${chapter.title} / $tooltip',
          );
          expect(
            tester.getRect(control).bottom,
            lessThanOrEqualTo(phone.height - insets.bottom),
            reason: '${chapter.title} / $tooltip',
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('backgrounding pauses and resumes only active playback', (
    WidgetTester tester,
  ) async {
    await host(tester);
    final TimelineController c = controllerOf(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(c.isPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(c.isPlaying, isTrue);
    c.pause();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(c.isPlaying, isFalse);
  });

  testWidgets('the science sheet pauses and resumes the animation', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.tap(find.byTooltip('About this replication model'));
    await tester.pumpAndSettle();
    expect(controllerOf(tester).isPlaying, isFalse);
    expect(find.text('From an origin to two forks'), findsOneWidget);
    Navigator.of(
      tester.element(find.text('From an origin to two forks')),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controllerOf(tester).isPlaying, isTrue);
  });

  testWidgets(
    'short, narrow and enlarged-text layouts keep controls reachable',
    (WidgetTester tester) async {
      for (final (Size size, double textScale) in <(Size, double)>[
        (const Size(320, 568), 1),
        (const Size(844, 390), 1),
        (const Size(390, 844), 2),
        (const Size(320, 568), 3.2),
      ]) {
        await host(tester, size: size, textScale: textScale);
        controllerOf(tester).pause();
        await tester.ensureVisible(find.byTooltip('Step forward'));
        await tester.pump();
        await tester.tap(find.byTooltip('Step forward'));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size / $textScale');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
