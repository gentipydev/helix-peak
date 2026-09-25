import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_canvas.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_screen.dart';
import 'package:helixpeek/features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import 'package:helixpeek/features/gene_lookup/presentation/screens/gene_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/test_catalog.dart';
import 'anatomy/anatomy_fixture.dart';

// GeneLookupCubit is a final class and cannot be mocked directly, so the screen
// is driven by a real cubit over a stubbed repository. Nothing is loaded: the
// wait is part of the flow too, and it is what is on screen first.
class _MockGeneRepository extends Mock implements GeneRepository {}

void main() {
  testWidgets('the Protein Analyses flow is set on its own warm ground', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<GeneLookupCubit>(
          create: (BuildContext context) =>
              GeneLookupCubit(FetchGene(_MockGeneRepository())),
          child: GeneScreen(target: TestCatalog.insulin),
        ),
      ),
    );

    // The app around the route keeps the near-black the home screen is on...
    final ThemeData outside = Theme.of(tester.element(find.byType(GeneScreen)));
    expect(outside.colorScheme.surface, AppColorTokens.dark.surfaceBase);

    // ...and everything the route shows is drawn on the warm one, lettered in
    // the muted bases and filled through the Kaleido filter.
    final ThemeData inside = Theme.of(tester.element(find.byType(Scaffold)));
    expect(inside.colorScheme.surface, AppColorTokens.warm.surfaceBase);
    expect(inside.scaffoldBackgroundColor, AppColorTokens.warm.surfaceBase);
    expect(inside.extension<NucleotideColors>(), NucleotideColors.muted);
    expect(inside.extension<AnatomyColors>(), AnatomyColors.kaleido);
  });

  testWidgets('the wait is set out as the walk it waits for', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider<GeneLookupCubit>(
          create: (BuildContext context) =>
              GeneLookupCubit(FetchGene(_MockGeneRepository())),
          child: GeneScreen(target: TestCatalog.insulin),
        ),
      ),
    );
    // The walk's title, set as the walk sets it: the symbol, then the name in
    // small type, which used to arrive a size larger and shrink.
    final TextStyle symbol = tester.widget<Text>(find.text('INS')).style!;
    final TextStyle name = tester.widget<Text>(find.text('  ·  Insulin')).style!;
    expect(name.fontSize, lessThan(symbol.fontSize!));
    final Rect map = tester.getRect(
      find.byKey(const ValueKey<String>('loading-map')),
    );

    // And the walk that replaces it: its title is the same, and its gene map
    // starts where the placeholder's did, across the same width.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.analysis,
        home: AnatomyScreen(target: TestCatalog.insulin, record: insulin()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('INS')).style, symbol);
    expect(tester.widget<Text>(find.text('  ·  Insulin')).style, name);
    final Rect canvas = tester.getRect(find.byType(AnatomyCanvas));
    expect(map.top, canvas.top);
    expect(map.left, canvas.left);
    expect(map.width, canvas.width);
  });
}
