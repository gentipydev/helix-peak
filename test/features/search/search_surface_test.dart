import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_builds.dart';
import 'package:helixpeek/core/catalog/protein_resolver.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/app_typography.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/search/presentation/widgets/build_card.dart';
import 'package:helixpeek/features/search/presentation/widgets/list_wait.dart';
import 'package:helixpeek/features/search/presentation/widgets/protein_card.dart';
import 'package:helixpeek/features/search/presentation/widgets/suggestion_tile.dart';

import '../../support/catalog_api.dart';
import '../gene_lookup/anatomy/anatomy_fixture.dart';
import 'support/resolver_api.dart';

/// How search looks, where its other tests hold what it does: one surface
/// under every row, small print in the app's own face and its quiet ink, a
/// wait that holds the cards' places, and Stop told from Keep building.

const Size _phone = Size(390, 844);

Map<String, dynamic> _suggestion(
  String uniprot,
  String gene,
  String name,
  int length,
  String status, {
  String? slug,
}) => <String, dynamic>{
  'uniprot': uniprot, 'gene': gene, 'name': name, 'display': null,
  'length': length, 'slug': slug, 'status': status, 'reason': null,
  'building': false, 'stopped': false,
};

final Map<String, dynamic> _insr = _suggestion(
  'P06213', 'INSR', 'Insulin receptor', 1382, 'buildable', slug: 'insr');
final Map<String, dynamic> _b2m = _suggestion(
  'P61769', 'B2M', 'Beta-2-microglobulin', 119, 'ready', slug: 'b2m');

Map<String, dynamic> _queued(String gene) => <String, dynamic>{
  'slug': 'insr',
  'state': 'pending',
  'reason': null,
  'build': <String, dynamic>{
    'step': 'queued', 'ahead': 0, 'scored': null, 'residues': null,
    'left': null, 'elapsed': 0.2, 'transcript': null, 'reason': null,
  },
};

ResolverApi _service() => ResolverApi(
  suggest: (String q) async => <String, dynamic>{
    'q': q,
    'release': 'UniProt 2026_03 · MANE v1.5',
    'suggestions': <Map<String, dynamic>>[_insr, _b2m],
  },
  resolve: (String gene) async => _queued(gene),
  status: (String gene) async => _queued(gene),
);

/// The search screen as the app shows it, on a phone. With [catalog] not yet
/// asked for its list, it waits.
Future<void> _pump(
  WidgetTester tester,
  ProteinCatalogRepository catalog, {
  bool reduced = false,
}) async {
  final ProteinResolver resolver = ProteinResolver(_service());
  await tester.binding.setSurfaceSize(_phone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<ProteinResolver>.value(value: resolver),
        RepositoryProvider<ProteinBuilds>(
          create: (BuildContext context) =>
              ProteinBuilds(resolver, asker: () async => 'install-a'),
          dispose: (ProteinBuilds builds) => builds.dispose(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.analysis,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: const SearchScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<ProteinCatalogRepository> _catalog({bool asked = true}) async {
  final ProteinCatalogRepository catalog =
      ProteinCatalogRepository(CatalogApi(), null);
  if (asked) {
    await catalog.refresh();
  }
  addTearDown(catalog.dispose);
  return catalog;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// The surface a row of the list is drawn on.
Decoration? _surfaceOf(WidgetTester tester, Finder row) => tester
    .widget<Ink>(find.descendant(of: row, matching: find.byType(Ink)).first)
    .decoration;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('every row of the list is on one surface', (
    WidgetTester tester,
  ) async {
    await _pump(tester, await _catalog());
    await _type(tester, 'ins');

    final ColorScheme colors = AppTheme.analysis.colorScheme;
    final BoxDecoration surface = ProteinCard.surface(colors);
    expect(surface.color, colors.surfaceContainerLow);

    // A curated card, and the two kinds of row under it: one that opens and
    // one that can be built. They were filled and outlined, on one list.
    expect(_surfaceOf(tester, find.byType(ProteinCard).first), surface);
    expect(find.byType(SuggestionTile), findsNWidgets(2));
    for (final Element tile in find.byType(SuggestionTile).evaluate()) {
      expect(_surfaceOf(tester, find.byWidget(tile.widget)), surface);
    }

    // And a build's card, pinned over them.
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BuildCard), findsOneWidget);
    expect(_surfaceOf(tester, find.byType(BuildCard)), surface);
  });

  testWidgets('small print is in the app\'s face and its quiet ink', (
    WidgetTester tester,
  ) async {
    await _pump(tester, await _catalog());
    final ThemeData theme = AppTheme.analysis;

    // The line under the tabs. Its style was one the theme did not name,
    // which Material set in the platform's face and the bright ink.
    final TextStyle shelf = tester
        .widget<Text>(find.textContaining('checked by hand'))
        .style!;
    expect(shelf.fontFamily, AppTypography.sansFamily);
    expect(shelf.color, theme.colorScheme.onSurfaceVariant);

    // A section's line, once something is typed.
    await _type(tester, 'ins');
    final TextStyle section = tester
        .widget<Text>(find.textContaining('Built on demand from its UniProt'))
        .style!;
    expect(section.fontFamily, AppTypography.sansFamily);
    expect(section.color, theme.colorScheme.onSurfaceVariant);

    // A card's lines: its figures in the sequence face, its prose in body
    // type a step down, each one style wherever it is set.
    final Finder card = find.byType(ProteinCard).first;
    final TextStyle figures = tester
        .widget<Text>(
          find.descendant(of: card, matching: find.textContaining(' aa ')),
        )
        .style!;
    expect(figures, AppTypography.spec(theme.colorScheme.onSurfaceVariant));
    final TextStyle status = tester
        .widget<Text>(find.text('Not built yet'))
        .style!;
    expect(status.fontSize, 13);
    expect(status.fontFamily, AppTypography.sansFamily);
  });

  testWidgets('the wait holds the places the cards land in', (
    WidgetTester tester,
  ) async {
    final ProteinCatalogRepository catalog = await _catalog(asked: false);
    await _pump(tester, catalog);

    expect(find.byType(ListWait), findsOneWidget);
    expect(find.text('LOADING PROTEINS'), findsOneWidget);
    expect(
      find.text('The service can take up to a minute to wake.'),
      findsOneWidget,
    );
    expect(find.byType(ProteinCard), findsNothing);

    // The first place, and the card that takes it: the same corner of the
    // screen, on the cards' own surface.
    final Finder places = find.byKey(const ValueKey<String>('list-wait'));
    final Offset held = tester.getTopLeft(places);
    final Finder place = find.descendant(
      of: places,
      matching: find.byType(DecoratedBox),
    );
    expect(
      tester.widget<DecoratedBox>(place.first).decoration,
      ProteinCard.surface(AppTheme.analysis.colorScheme),
    );
    final Size room = tester.getSize(place.first);

    await catalog.refresh();
    await tester.pump();
    expect(find.byType(ListWait), findsNothing);
    final Finder first = find.byType(ProteinCard).first;
    expect(tester.getTopLeft(first), held);
    expect(tester.getSize(first).width, room.width);
    // A card of two lines of prose, to within a line's leading.
    expect(tester.getSize(first).height, closeTo(room.height, 4));
  });

  testWidgets('the wait stands still where motion is not wanted', (
    WidgetTester tester,
  ) async {
    await _pump(tester, await _catalog(asked: false), reduced: true);
    expect(find.byType(ListWait), findsOneWidget);
    final FadeTransition place = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(ListWait),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(place.opacity.value, 1);
    final double before = place.opacity.value;
    await tester.pump(const Duration(milliseconds: 700));
    expect(place.opacity.value, before);
  });

  testWidgets('Stop is told from Keep building', (WidgetTester tester) async {
    await _pump(tester, await _catalog());
    await _type(tester, 'ins');
    await tester.tap(find.text('Build'));
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.descendant(of: find.byType(BuildCard), matching: find.text('Stop')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ThemeData theme = AppTheme.analysis;
    Color? inkOf(String label) => tester
        .widget<TextButton>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, label),
          ),
        )
        .style
        ?.foregroundColor
        ?.resolve(<WidgetState>{});

    // The one that loses work is the one marked; the other is an action like
    // any other.
    expect(inkOf('Stop'), theme.colorScheme.error);
    expect(inkOf('Keep building'), isNull);

    // And its title is set as a sheet's is, in the app's face.
    final BuildContext dialog = tester.element(find.byType(AlertDialog));
    final TextStyle title = DefaultTextStyle.of(
      tester.element(find.text('Stop INSR?')),
    ).style;
    expect(title.fontFamily, AppTypography.sansFamily);
    expect(title.fontSize, Theme.of(dialog).textTheme.titleLarge!.fontSize);
  });
}
