import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/clinvar/sources_note.dart';

/// `also` is a new parameter on a shared widget, so what it has to prove is
/// that leaving it out writes exactly what the walk has always written, and
/// that what it adds comes after all of that.
Future<void> _pump(WidgetTester tester, Widget note) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.analysis,
    home: Scaffold(body: SingleChildScrollView(child: note)),
  ),
);

const String _closing =
    'Both models predict molecular effects. Neither is a health assessment.';

List<Widget> _written(WidgetTester tester) => tester
    .widget<Column>(find.byKey(const ValueKey<String>('sources-note')))
    .children;

void main() {
  testWidgets('left out, the note ends on its closing line, as it did', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const SourcesNote(snapshotDate: '2026-09-22'));

    expect(const SourcesNote().also, isEmpty);
    // The walk's four paragraphs and the line that closes them: nothing after.
    final List<Widget> written = _written(tester);
    expect(written, hasLength(5));
    expect((written.last as Text).data, _closing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a source named beside the four is written after them all', (
    WidgetTester tester,
  ) async {
    final List<Uri> opened = <Uri>[];
    final Uri entry = Uri.parse('https://alphafold.ebi.ac.uk/entry/P61769');
    await _pump(
      tester,
      SourcesNote(
        snapshotDate: '2026-09-22',
        open: (Uri uri) async {
          opened.add(uri);
          return true;
        },
        also: <SourceEntry>[
          SourceEntry(
            name: 'AlphaFold',
            text: 'Predicted structure, CC BY 4.0.',
            uri: entry,
          ),
        ],
      ),
    );

    // The four and their closing line are untouched, and still in place.
    final List<Widget> written = _written(tester);
    expect(written, hasLength(7));
    expect((written[4] as Text).data, _closing);
    for (final String lead in <String>['ESM-2', 'AVI', 'ClinVar']) {
      expect(find.textContaining(lead, findRichText: true), findsWidgets);
    }
    expect(
      find.textContaining(
        'AlphaFold  Predicted structure, CC BY 4.0.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // Below the closing line, which is about the two models above it.
    expect(
      tester.getTopLeft(find.textContaining('AlphaFold  ', findRichText: true)).dy,
      greaterThan(tester.getBottomLeft(find.text(_closing)).dy),
    );

    await tester.tap(find.byKey(const ValueKey<String>('source-link-AlphaFold')));
    expect(opened, <Uri>[entry]);
  });
}
