import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/clinvar/sources_note.dart';

/// `sources` is a new parameter on a shared widget, so what it has to prove
/// is that leaving it out writes exactly what the walk has always written.
Future<void> _pump(WidgetTester tester, Widget note) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.analysis,
    home: Scaffold(body: SingleChildScrollView(child: note)),
  ),
);

void main() {
  testWidgets('left out, it is the walk’s own four sources', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const SourcesNote(snapshotDate: '2026-09-22'));

    expect(find.byKey(const ValueKey<String>('sources-note')), findsOneWidget);
    for (final String lead in <String>[
      'ESM-2',
      'AVI',
      'AVI contributions',
      'ClinVar',
    ]) {
      expect(
        find.textContaining(lead, findRichText: true),
        findsWidgets,
        reason: lead,
      );
    }
    expect(
      find.text(
        'Both models predict molecular effects. Neither is a health '
        'assessment.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('snapshot 2026-09-22', findRichText: true),
      findsOneWidget,
    );
    // Nothing in the walk's own four is a link.
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a gene with no snapshot still says so the way it did', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const SourcesNote(included: false));
    expect(
      find.textContaining(
        'Not yet included for this gene.',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('given a set of its own, it writes those instead', (
    WidgetTester tester,
  ) async {
    final List<Uri> opened = <Uri>[];
    await _pump(
      tester,
      SourcesNote(
        open: (Uri uri) async {
          opened.add(uri);
          return true;
        },
        sources: <SourceEntry>[
          SourceEntry(
            name: 'Someone et al., 2020',
            text: 'A journal, a volume, and what the paper says.',
            uri: Uri.parse('https://doi.org/10.0000/example'),
          ),
          const SourceEntry(
            name: 'A source with nowhere to go',
            text: 'Written about, and not linked.',
          ),
        ],
      ),
    );

    expect(find.byKey(const ValueKey<String>('sources-note')), findsOneWidget);
    expect(
      find.textContaining('Someone et al., 2020', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('A source with nowhere to go', findRichText: true),
      findsOneWidget,
    );
    // The walk's own paragraphs are not written as well.
    expect(find.textContaining('ESM-2', findRichText: true), findsNothing);
    expect(
      find.textContaining('Neither is a health assessment', findRichText: true),
      findsNothing,
    );

    // One link, for the one source that has somewhere to go.
    expect(find.text('https://doi.org/10.0000/example'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('source-link-Someone et al., 2020')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('source-link-A source with nowhere to go'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('source-link-Someone et al., 2020')),
    );
    await tester.pump();
    expect(opened, <Uri>[Uri.parse('https://doi.org/10.0000/example')]);
  });
}
