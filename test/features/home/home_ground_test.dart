import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/app.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/home/presentation/screens/home_screen.dart';
import 'package:helixpeek/features/home/presentation/widgets/dna_helix.dart';

void main() {
  testWidgets('home is on the ground every screen it leads to is on', (
    WidgetTester tester,
  ) async {
    // Pumped inside the cool theme the app began on, which is how the render
    // baseline pumps it: the screen brings its own ground, as each flow does.
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
    );
    await tester.pump();

    final ThemeData worn = Theme.of(tester.element(find.byType(Scaffold)));
    expect(worn.scaffoldBackgroundColor, AppColorTokens.warm.surfaceBase);
    expect(
      worn.scaffoldBackgroundColor,
      AppTheme.analysis.scaffoldBackgroundColor,
      reason: 'search, the walk, replication and the zoom are on this one',
    );
  });

  testWidgets('its helix keeps the bases at full strength', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
    );
    await tester.pump();

    final ThemeData worn = Theme.of(tester.element(find.byType(DnaHelix)));
    expect(worn.extension<NucleotideColors>(), NucleotideColors.dark);
    // The helix is drawn on its ground and nothing else: it mixes its colours
    // toward it, and knocks its nodes out in it.
    expect(worn.colorScheme.surface, AppColorTokens.warm.surfaceBase);
  });

  testWidgets('the app itself is on that ground, from its first screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HelixPeekApp());
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    // What the app gives a page with no flow of its own, the not-found page
    // among them.
    final ThemeData app = Theme.of(tester.element(find.byType(HomeScreen)));
    expect(app.scaffoldBackgroundColor, AppColorTokens.warm.surfaceBase);
  });
}
