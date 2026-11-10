import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/peptide_lm/presentation/lm_info_sheet.dart';

void main() {
  Future<void> show(WidgetTester tester, LmInfo info) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: LmInfoSheet(info: info)),
      ),
    ),
  );

  testWidgets("a page's lead is in the bright ink, its sections' paragraphs in the quiet", (WidgetTester tester) async {
    await show(
      tester,
      const LmInfo(
        title: 'Stage',
        lead: 'What it takes, and what it gives.',
        sections: <LmInfoSection>[
          LmInfoSection('A part', <String>['First.', 'Second.']),
          LmInfoSection('Another part', <String>['Last.']),
        ],
      ),
    );
    final ThemeData theme = AppTheme.analysis;
    expect(tester.widget<Text>(find.text('What it takes, and what it gives.')).style?.color, theme.colorScheme.onSurface);
    for (final String paragraph in <String>['First.', 'Second.', 'Last.']) {
      expect(tester.widget<Text>(find.text(paragraph)).style?.color, theme.textTheme.bodyMedium?.color, reason: paragraph);
    }
    expect(theme.textTheme.bodyMedium?.color, isNot(theme.colorScheme.onSurface));
  });
}
