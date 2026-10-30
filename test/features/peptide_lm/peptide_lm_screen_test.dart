import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  testWidgets('the run plays from its first stage, every stage named once', (
    WidgetTester tester,
  ) async {
    await host(tester);
    expect(find.text(PeptideLmScreen.title), findsOneWidget);
    expect(find.text('Recorded run · 2,015 parameters'), findsOneWidget);
    for (final LmStage stage in LmStage.values) {
      expect(find.byKey(ValueKey<String>('stage-${stage.label}')), findsOneWidget);
    }
    // The stage bar names the stage; the transport does not name it again.
    expect(find.byKey(const ValueKey<String>('transport-phase')), findsNothing);
    expect(find.byKey(const ValueKey<String>('peptide-lm-canvas')), findsOneWidget);
    expect(caption(tester), startsWith('Two peptides'));
    // Playing: a few seconds on, the light has crossed the peptides.
    await tester.pump(const Duration(seconds: 7));
    expect(caption(tester), isNot(startsWith('Two peptides')));
  });

  testWidgets('a stage on the bar plays from its start', (WidgetTester tester) async {
    await host(tester);
    await tester.tap(find.byKey(const ValueKey<String>('stage-Loss')));
    await tester.pump();
    expect(caption(tester), contains('−ln p'));
    await tester.tap(find.byKey(const ValueKey<String>('stage-Loop')));
    await tester.pump();
    expect(caption(tester), startsWith('Step 1 of 20'));
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

  testWidgets('with reduced motion each stage is one still, played through', (
    WidgetTester tester,
  ) async {
    await host(tester, reducedMotion: true);
    await tester.pump(const Duration(seconds: 3));
    expect(caption(tester), startsWith('One batch: '));
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
