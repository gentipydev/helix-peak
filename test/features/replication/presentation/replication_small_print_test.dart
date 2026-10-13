import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/replication/presentation/replication_screen.dart';
import 'package:helixpeek/shared/motion/transport_bar.dart';

/// Replication's small print: what the sequence is, under its name; the key
/// to its three strands; and, in its sheet, where each claim comes from.
/// Each read a style the theme did not name, which a phone set in the
/// platform's face and in the bright ink, louder than the caption under the
/// scene.
void main() {
  Future<void> host(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: const ReplicationScreen(),
      ),
    );
    await tester.pump();
    // Held still: the tour plays from the first frame.
    tester.widget<TransportBar>(find.byType(TransportBar)).controller.pause();
    await tester.pump();
  }

  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  /// Whether [style] is the app's small print: its face, its smallest body
  /// size, and the quiet ink.
  void expectSmallPrint(TextStyle style, {String? reason}) {
    final ThemeData theme = AppTheme.analysis;
    expect(style.fontFamily, AppTypography.sansFamily, reason: reason);
    expect(style.fontSize, 12, reason: reason);
    expect(style.color, theme.colorScheme.onSurfaceVariant, reason: reason);
  }

  testWidgets('is in the app\'s face and its quiet ink', (
    WidgetTester tester,
  ) async {
    await host(tester);

    expectSmallPrint(styleOf(tester, 'Human DNA · 200 bp'));
    for (final String strand in <String>['Parental', 'New DNA', 'RNA']) {
      expectSmallPrint(styleOf(tester, strand), reason: strand);
    }

    // Quieter than the name over it, as the caption under the scene is.
    final TextStyle name = DefaultTextStyle.of(
      tester.element(find.text('Replication')),
    ).style;
    expect(name.color, AppTheme.analysis.colorScheme.onSurface);
  });

  testWidgets('a source\'s second line is too, in its sheet', (
    WidgetTester tester,
  ) async {
    await host(tester);
    await tester.tap(find.byTooltip('About this replication model'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.scrollUntilVisible(
      find.text('Remus et al., 2009 · Cell'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expectSmallPrint(styleOf(tester, 'Remus et al., 2009 · Cell'));
  });
}
