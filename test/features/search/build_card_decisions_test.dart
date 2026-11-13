import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_suggestion.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/search/presentation/widgets/build_card.dart';

/// [BuildCard] once its build is stopped: what the reader may do with it
/// (Discard, Keep, Resume), who may discard it, and the moment a decision is
/// on its way to the service.

const ProteinSuggestion _brca1 = ProteinSuggestion(
  uniprot: 'P38398',
  gene: 'BRCA1',
  name: 'Breast cancer type 1 susceptibility protein',
  display: null,
  length: 1863,
  slug: 'brca1',
  status: SuggestionStatus.ready,
  reason: null,
);

const BuildReport _stopped = BuildReport(
  step: BuildStep.scoring,
  elapsed: Duration(minutes: 8),
  scored: 0,
  residues: 1863,
  reason: 'Stopped before a residue was scored.',
  stopped: true,
);

Future<List<String>> _pump(WidgetTester tester, ProteinBuild job) async {
  final List<String> asked = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Scaffold(
        body: BuildCard(
          job: job,
          onOpen: (String slug) => asked.add('open $slug'),
          onBuild: (ProteinSuggestion protein) => asked.add('resume ${protein.gene}'),
          onStop: (ProteinBuild build) => asked.add('stop ${build.gene}'),
          onKeep: (ProteinBuild build) => asked.add('keep ${build.gene}'),
          onDiscard: (ProteinBuild build) => asked.add('discard ${build.gene}'),
        ),
      ),
    ),
  );
  return asked;
}

TextButton _button(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

void main() {
  testWidgets('stopped with something built: Discard, Keep and Resume, in that order', (
    WidgetTester tester,
  ) async {
    final List<String> asked = await _pump(tester, const ProteinBuild(
      protein: _brca1, stage: BuildStage.stopped, report: _stopped, slug: 'brca1', mine: true));
    expect(find.text('Stopped after 8 min'), findsOneWidget);
    final List<double> lefts = <double>[
      for (final String label in <String>['Discard', 'Keep', 'Resume'])
        tester.getTopLeft(find.widgetWithText(TextButton, label)).dx,
    ];
    expect(lefts, orderedEquals(<double>[...lefts]..sort()));
    expect(find.text('Open'), findsNothing);

    await tester.tap(find.text('Keep'));
    await tester.tap(find.text('Resume'));
    expect(asked, <String>['keep BRCA1', 'resume BRCA1']);
  });

  testWidgets("another phone's stopped build offers Keep and Resume, never Discard", (
    WidgetTester tester,
  ) async {
    await _pump(tester, const ProteinBuild(
      protein: _brca1, stage: BuildStage.stopped, report: _stopped, slug: 'brca1'));
    expect(find.text('Discard'), findsNothing);
    expect(find.text('Keep'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('a decision on its way says so, and nothing else can be asked meanwhile', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const ProteinBuild(protein: _brca1, stage: BuildStage.stopped,
        report: _stopped, slug: 'brca1', mine: true, keeping: true));
    expect(find.text('Keep'), findsNothing);
    for (final String label in <String>['Discard', 'Keeping', 'Resume']) {
      expect(_button(tester, label).onPressed, isNull, reason: label);
    }

    await _pump(tester, const ProteinBuild(protein: _brca1, stage: BuildStage.stopped,
        report: _stopped, slug: 'brca1', mine: true, discarding: true));
    for (final String label in <String>['Discarding', 'Keep', 'Resume']) {
      expect(_button(tester, label).onPressed, isNull, reason: label);
    }
  });

  testWidgets('a card pinned again before its report is read still offers the decisions', (
    WidgetTester tester,
  ) async {
    // Restored from the list of this phone's stopped builds, its steps not
    // read yet (or not readable): one line, and the same three.
    await _pump(tester, const ProteinBuild(
      protein: _brca1, stage: BuildStage.stopped, slug: 'brca1', mine: true));
    expect(find.text('Stopped'), findsOneWidget);
    for (final String label in <String>['Discard', 'Keep', 'Resume']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
