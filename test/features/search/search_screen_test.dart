import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/format.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/search/presentation/widgets/protein_card.dart';

/// Tall enough that the lazy list builds the whole catalog at once.
///
/// `ListView.separated` only builds what is on screen, which is right and is
/// also why the default 800x600 surface finds five: a count taken off a lazy
/// list is a count of what fits, not of what is there. A card runs to about
/// 190pt in the test font, whose every glyph is a square, so each is given 260.
final Size _tall = Size(400, 260.0 * ProteinCatalog.all.length);

Future<void> _pump(WidgetTester tester, {Size? size}) async {
  await tester.binding.setSurfaceSize(size ?? _tall);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the whole catalog rather than an empty state', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    // Twenty is few enough to show, and a reader who does not know what is
    // here should not have to guess a name to find out.
    expect(find.byType(ProteinCard), findsNWidgets(ProteinCatalog.all.length));
    expect(find.text('Insulin'), findsOneWidget);
    expect(find.text('Dystrophin'), findsOneWidget);
  });

  testWidgets('filters by name, by gene symbol and by case', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    for (final String query in <String>['TP53', 'tp53', 'p53']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(find.byType(ProteinCard), findsOneWidget, reason: query);
      expect(find.text('p53'), findsWidgets);
    }
  });

  testWidgets('a protein it does not carry is told so, not left empty', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'titin');
    await tester.pumpAndSettle();

    expect(find.byType(ProteinCard), findsNothing);
    expect(find.textContaining('Nothing here for "titin"'), findsOneWidget);
    // The one place the app says out loud that there is no service behind it.
    expect(
      find.textContaining('${spelled(ProteinCatalog.all.length)} proteins'),
      findsOneWidget,
    );
  });

  testWidgets('clearing the field brings the whole list back', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'lysozyme');
    await tester.pumpAndSettle();
    expect(find.byType(ProteinCard), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.byType(ProteinCard), findsNWidgets(ProteinCatalog.all.length));
  });

  testWidgets('every card is one tap to that protein and reads as a button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<ProteinTarget> opened = <ProteinTarget>[];
    await tester.binding.setSurfaceSize(_tall);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              for (final ProteinTarget target in ProteinCatalog.all)
                ProteinCard(target: target, onTap: () => opened.add(target)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final ProteinTarget target in ProteinCatalog.all) {
      // One label carrying the name, the symbol, the figures and the
      // sentence: a reader who cannot see the card still hears all of it.
      expect(
        find.bySemanticsLabel(
          '${target.display}, gene ${target.gene}. '
          '${ProteinCard.specOf(target)}. ${target.summary}',
        ),
        findsOneWidget,
        reason: target.slug,
      );
    }

    await tester.tap(find.byType(ProteinCard).first);
    expect(opened, <ProteinTarget>[ProteinCatalog.all.first]);
    // Not `addTearDown`: the framework checks for leaked handles before tear
    // downs run, so a handle disposed there is still a handle it complains at.
    handle.dispose();
  });

  test('a card leads with the figures, and search reaches accessions', () {
    expect(
      ProteinCard.specOf(ProteinCatalog.insulin),
      'P01308 · 110 aa · 3 exons · 3 chains · 3 S\u2013S',
    );
    // One chain and no bridges say nothing, and are left out.
    expect(
      ProteinCard.specOf(ProteinCatalog.hemoglobin),
      'P68871 · 147 aa · 3 exons',
    );
    expect(ProteinCatalog.matching('p01308'), <ProteinTarget>[ProteinCatalog.insulin]);
    expect(ProteinCatalog.matching('NG_012232'), <ProteinTarget>[ProteinCatalog.dystrophin]);
  });

  testWidgets('a card gives its summary two lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: const SearchScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text(ProteinCatalog.insulin.summary)).maxLines,
      2,
    );
  });
}
