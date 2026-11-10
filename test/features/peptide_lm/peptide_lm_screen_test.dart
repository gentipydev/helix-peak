import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/peptide_lm/data/training_run_repository.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_timeline.dart';
import 'package:helixpeek/features/peptide_lm/domain/training_trace.dart';
import 'package:helixpeek/features/peptide_lm/presentation/cubit/peptide_lm_cubit.dart';
import 'package:helixpeek/features/peptide_lm/presentation/peptide_lm_screen.dart';

import 'support/toy_trace.dart';

void main() {
  final TrainingTrace trace = toyTrace();

  Future<PeptideLmCubit> host(
    WidgetTester tester, {
    RowReader? readRow,
    bool reducedMotion = false,
  }) async {
    final PeptideLmCubit cubit = PeptideLmCubit(
      TrainingRunRepository(readRow ?? (String path) async => toyBytes(), run: 'toy'),
    );
    addTearDown(cubit.close);
    if (readRow == null) {
      cubit.emit(PeptideLmReady(trace));
    }
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        // App-wide, as the platform sets it, so a menu's route sees it too.
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: BlocProvider<PeptideLmCubit>.value(
          value: cubit,
          child: const PeptideLmScreen(),
        ),
      ),
    );
    await tester.pump();
    return cubit;
  }

  String caption(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey<String>('peptide-lm-caption'))).data!;

  /// Taps [label]'s stage on the bar, scrolled into view first as a reader
  /// would.
  Future<void> tapStage(WidgetTester tester, String label) async {
    final Finder stage = find.byKey(ValueKey<String>('stage-$label'));
    await tester.ensureVisible(stage);
    await tester.pump();
    await tester.tap(stage);
  }

  testWidgets('the run plays from its first stage, every stage named once', (
    WidgetTester tester,
  ) async {
    await host(tester);
    expect(find.text(PeptideLmScreen.title), findsOneWidget);
    expect(find.text('Recorded run · 2,015 parameters'), findsOneWidget);
    for (final LmStage stage in LmStage.values) {
      expect(find.byKey(ValueKey<String>('stage-${stage.label}')), findsOneWidget);
    }
    // The stage's own player: no stepping between stages, and one speed.
    expect(find.byKey(const ValueKey<String>('transport-phase')), findsNothing);
    expect(find.byTooltip('Replay'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    for (final String control in <String>[
      'Reset',
      'Step back',
      'Step forward',
      'Playback speed',
    ]) {
      expect(find.byTooltip(control), findsNothing);
    }
    expect(find.byKey(const ValueKey<String>('peptide-lm-canvas')), findsOneWidget);
    expect(caption(tester), startsWith('Two peptides'));
    // Playing: a few beats on, the light has crossed the peptides.
    await tester.pump(TrainingRunView.beat * 7);
    expect(caption(tester), isNot(startsWith('Two peptides')));
  });

  testWidgets('a stage plays once, at the one slow speed, and holds on its last frame', (
    WidgetTester tester,
  ) async {
    await host(tester);
    // Two seconds a beat: at eleven seconds Tokenise's eleven beats are half
    // played, the peptides still being framed.
    await tester.pump(const Duration(seconds: 11));
    expect(caption(tester), startsWith('<bos> (<) and <eos> (>) frame each one'));
    await tester.pump(TrainingRunView.beat * (LmStage.tokenise.beats + 20));
    expect(caption(tester), startsWith('The vocabulary, counted: '));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('the player pauses the stage on screen, and plays it on to its end', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.pump(TrainingRunView.beat * 3);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.pump(TrainingRunView.beat * 20);
    expect(caption(tester), startsWith('Two peptides'));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);
    // On from where it stood: five and a half beats in, the peptides are
    // being framed (from the start, two and a half would still be scanning).
    await tester.pump(TrainingRunView.beat * 2.5);
    expect(caption(tester), startsWith('<bos> (<) and <eos> (>) frame each one'));
    await tester.pump(TrainingRunView.beat * 20);
    expect(caption(tester), startsWith('The vocabulary, counted: '));
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('the player plays the stage on screen again, and only it', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tapStage(tester, 'Loss');
    await tester.pump();
    final String start = caption(tester);
    await tester.pump(TrainingRunView.beat * (LmStage.loss.beats + 5));
    expect(caption(tester), isNot(start));
    await tester.tap(find.byTooltip('Replay'));
    await tester.pump();
    expect(caption(tester), start);
    // Played through, Play plays it again from its start too.
    await tester.pump(TrainingRunView.beat * (LmStage.loss.beats + 5));
    expect(caption(tester), isNot(start));
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(caption(tester), start);
  });

  testWidgets('the stage on screen, tapped again, plays again from its start', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.pump(TrainingRunView.beat * (LmStage.tokenise.beats + 1));
    expect(caption(tester), startsWith('The vocabulary, counted: '));
    await tapStage(tester, 'Tokenise');
    await tester.pump();
    expect(caption(tester), startsWith('Two peptides'));
    await tester.pump(TrainingRunView.beat * 7);
    expect(caption(tester), isNot(startsWith('Two peptides')));
  });

  testWidgets("the info button opens the stage's own page, every stage's", (
    WidgetTester tester,
  ) async {
    await host(tester);
    final Finder info = find.byKey(const ValueKey<String>('peptide-lm-info'));
    final Finder sheet = find.byKey(const ValueKey<String>('peptide-lm-info-sheet'));
    Finder inSheet(String text) => find.descendant(of: sheet, matching: find.text(text));

    Finder scroll() => find.descendant(of: sheet, matching: find.byType(Scrollable));

    // The place the page opens on in focus, named as the canvas names it.
    final int middle = trace.peptides.first.inputs ~/ 2;
    final String place = '${trace.peptides.first.sequence[middle - 1]}$middle';
    // Every stage, from Tokenise, which the page opens on: its ⓘ is named for
    // it, and opens its own page, every section of it.
    final Map<String, List<String>> pages = <String, List<String>>{
      'Tokenise': <String>['Token ids', 'Special tokens', 'Batch 2D matrix', 'Token counts'],
      'Shift': <String>['Input x', 'Target y'],
      'Embedding': <String>['Token embedding', 'Position embedding', 'x0 = token + position'],
      'Scores': <String>['Query, key and value', 'Head 1 and head 2'],
      'Attention': <String>['Values', 'Shares'],
      'Feed-forward': <String>["What block 1's feed-forward adds"],
      'Forward': <String>["$place's row, layer to layer"],
      'Predict': <String>['Output layer'],
      'Loss': <String>['Even guess', 'Mean'],
      'Backward': <String>["$place's gradient, layer to layer", 'Gradient at x0'],
      'Update': <String>['Rate', 'Step'],
      'Loop': <String>['Next-token probabilities', '${trace.steps.count} steps', 'This run'],
    };
    for (final MapEntry<String, List<String>> page in pages.entries) {
      if (page.key != 'Tokenise') {
        await tapStage(tester, page.key);
        await tester.pump();
      }
      expect(tester.widget<IconButton>(info).tooltip, 'About ${page.key}', reason: page.key);
      await tester.tap(info);
      await tester.pumpAndSettle();
      for (final String title in <String>[page.key, ...page.value]) {
        await tester.scrollUntilVisible(inSheet(title), 120, scrollable: scroll());
        expect(inSheet(title), findsOneWidget, reason: title);
      }
      // Put away, the stage playing on.
      Navigator.of(tester.element(sheet)).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(sheet, findsNothing);
    }
  });

  testWidgets('a stage on the bar plays from its start', (WidgetTester tester) async {
    await host(tester);
    await tapStage(tester, 'Loss');
    await tester.pump();
    expect(caption(tester), startsWith('Loss reads one share a place, p(y)'));
    await tapStage(tester, 'Loop');
    await tester.pump();
    expect(caption(tester), startsWith('Step 1 of 20'));
  });

  testWidgets('the stage bar scrolls, and a stage played comes whole into view', (
    WidgetTester tester,
  ) async {
    await host(tester);
    final double width = tester.getSize(find.byType(Scaffold)).width;
    final Finder loop = find.byKey(const ValueKey<String>('stage-Loop'));
    // Every stage at its full size: more than a phone is wide.
    expect(tester.getRect(loop).left, greaterThan(width));
    await tester.drag(find.byKey(const ValueKey<String>('peptide-lm-stages')), const Offset(-2000, 0));
    await tester.pump();
    expect(tester.getRect(loop).right, lessThanOrEqualTo(width));
    await tester.tap(loop);
    await tester.pump();
    expect(caption(tester), startsWith('Step 1 of 20'));

    // Back at the start, a stage cut by the edge is scrolled in once played.
    await tester.drag(find.byKey(const ValueKey<String>('peptide-lm-stages')), const Offset(2000, 0));
    await tester.pump();
    final LmStage cut = LmStage.values.firstWhere((LmStage stage) {
      final Rect rect = tester.getRect(find.byKey(ValueKey<String>('stage-${stage.label}')));
      return rect.left < width - 8 && rect.right > width;
    });
    final Finder name = find.byKey(ValueKey<String>('stage-${cut.label}'));
    final Rect before = tester.getRect(name);
    await tester.tapAt(Offset((before.left + width) / 2, before.center.dy));
    // The frame that plays it, then the scroll's own.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    expect(caption(tester), isNot(startsWith('Step 1 of 20')));
    final Rect after = tester.getRect(name);
    expect(after.left, greaterThanOrEqualTo(0));
    expect(after.right, lessThanOrEqualTo(width));
    // Just far enough: its right edge at the bar's.
    expect(after.right, closeTo(width, 1));
  });

  testWidgets('a checkpoint is picked from the menu, by step and loss', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.tap(find.byKey(const ValueKey<String>('peptide-lm-checkpoint')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (final TraceCheckpoint c in trace.checkpoints) {
      expect(find.textContaining('Step ${c.step} · '), findsOneWidget);
    }
    await tester.tap(find.textContaining('Step 20 · '));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('peptide-lm-checkpoint'))).data,
      'Step 20',
    );
  });

  testWidgets("a caption's first line holds still while its stage plays", (WidgetTester tester) async {
    await host(tester);
    final Finder caption = find.byKey(const ValueKey<String>('peptide-lm-caption'));
    final Set<double> tops = <double>{};
    final Set<double> heights = <double>{};
    for (int i = 0; i <= 2 * LmStage.tokenise.beats; i++) {
      final Rect at = tester.getRect(caption);
      tops.add(at.top);
      heights.add(at.height);
      await tester.pump(TrainingRunView.beat * 0.5);
    }
    // Captions of more than one height came and went, each from one top.
    expect(heights.length, greaterThan(1));
    expect(tops, hasLength(1));
  });

  testWidgets("the header keeps the page's name whole, and still as the step changes", (
    WidgetTester tester,
  ) async {
    await host(tester);
    final Finder title = find.text(PeptideLmScreen.title);
    final Finder subtitle = find.textContaining('Recorded run · ');
    final Finder menu = find.byType(PopupMenuButton<int>);
    // In the test's square glyphs the name is wider than its room: shrunk,
    // never cut, and ending before the step's menu.
    void whole() {
      for (final Finder line in <Finder>[title, subtitle]) {
        expect(tester.renderObject<RenderParagraph>(line).didExceedMaxLines, isFalse);
        expect(tester.getRect(line).right, lessThanOrEqualTo(tester.getRect(menu).left));
      }
    }

    whole();
    final Rect name = tester.getRect(title);
    final Size room = tester.getSize(menu);
    await tester.tap(find.byKey(const ValueKey<String>('peptide-lm-checkpoint')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.textContaining('Step 20 · '));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    whole();
    expect(tester.getSize(menu), room);
    expect(tester.getRect(title), name);
  });

  testWidgets('with reduced motion each stage is one still, played through', (
    WidgetTester tester,
  ) async {
    await host(tester, reducedMotion: true);
    await tester.pump(const Duration(seconds: 3));
    expect(caption(tester), startsWith('The vocabulary, counted: '));
    // Nothing to play: the player is off.
    for (final IconData icon in <IconData>[Icons.replay_rounded, Icons.play_arrow_rounded]) {
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon)).onPressed, isNull);
    }
  });

  testWidgets('while the run is on its way, the page says so', (WidgetTester tester) async {
    final Completer<Uint8List> never = Completer<Uint8List>();
    final PeptideLmCubit cubit = await host(tester, readRow: (String path) => never.future);
    unawaited(cubit.load());
    await tester.pump();
    expect(find.text('LOADING THE TRAINING RUN'), findsOneWidget);
  });

  testWidgets('a run that cannot be had says why, and can be asked for again', (
    WidgetTester tester,
  ) async {
    int asked = 0;
    final PeptideLmCubit cubit = await host(
      tester,
      readRow: (String path) async {
        asked++;
        throw const ServerApiException(statusCode: 404);
      },
    );
    await cubit.load();
    await tester.pump();
    expect(find.text('The service holds no recorded run yet.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(asked, 2);
  });
}
