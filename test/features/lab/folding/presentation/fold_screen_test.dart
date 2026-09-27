import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/lab/folding/domain/fold_captions.dart';
import 'package:helixpeek/features/lab/folding/domain/fold_timeline.dart';
import 'package:helixpeek/features/lab/folding/presentation/fold_screen.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';

import '../../../../support/test_catalog.dart';
import '../folding_fixtures.dart';

Future<void> _host(
  WidgetTester tester,
  ProteinTarget protein, {
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: FoldScreen(
          target: withFolding(protein, TrackState.ready),
          geometry: geometryOf(protein),
        ),
      ),
    ),
  );
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

void main() {
  testWidgets('one screen serves all twenty, a caption for every step', (
    WidgetTester tester,
  ) async {
    for (final ProteinTarget protein in TestCatalog.all) {
      await _host(tester, protein);
      final FoldCaptions captions = FoldCaptions(geometryOf(protein));
      expect(find.text(FoldScreen.titleOf(protein)), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('fold-canvas')), findsOneWidget);
      for (final FoldStep step in FoldStep.values) {
        if (step != FoldStep.collapse) {
          await tester.tap(find.byTooltip('Step forward'));
          await tester.pump();
        }
        expect(
          _text(tester, 'fold-caption'),
          captions.captionOf(step),
          reason: '${protein.slug}, $step',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('it calls itself an illustration, on every step', (
    WidgetTester tester,
  ) async {
    await _host(tester, TestCatalog.insulin);
    for (int step = 0; step < FoldStep.values.length; step++) {
      expect(
        _text(tester, 'fold-illustration'),
        startsWith('An illustration, not a simulation.'),
      );
      await tester.tap(find.byTooltip('Step forward'));
      await tester.pump();
    }
  });

  testWidgets('the prion protein says its loose residues stay loose', (
    WidgetTester tester,
  ) async {
    await _host(tester, target('prion'));
    expect(
      _text(tester, 'fold-loose'),
      startsWith('98 residues have no fixed shape and stay loose throughout'),
    );
    // Still loose at the end: nothing about the last step places them.
    for (int step = 0; step < FoldStep.values.length; step++) {
      await tester.tap(find.byTooltip('Step forward'));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey<String>('fold-loose')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _host(tester, target('lysozyme'));
    expect(find.byKey(const ValueKey<String>('fold-loose')), findsNothing);
  });

  testWidgets('the fold turns under a drag, as the fold page’s does', (
    WidgetTester tester,
  ) async {
    await _host(tester, target('prion'));
    expect(find.byType(TurnZone), findsOneWidget);
    await tester.drag(find.byType(TurnZone), const Offset(80, 20));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion, nothing moves unless asked', (
    WidgetTester tester,
  ) async {
    await _host(tester, target('prion'), reducedMotion: true);
    // No clock of its own to keep the loose residues moving: it settles.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('fold-canvas')), findsOneWidget);
  });

  test('without a fold, it says which kind of without', () {
    expect(
      FoldScreen.unavailable(TrackState.absent, null),
      'Its fold, residue by residue, is not published yet.',
    );
    expect(
      FoldScreen.unavailable(TrackState.pending, null),
      'Its fold, residue by residue, is on its way.',
    );
    expect(
      FoldScreen.unavailable(TrackState.refused, 'no structure covers it'),
      'Its fold, residue by residue, is not published: no structure covers it.',
    );
  });
}
