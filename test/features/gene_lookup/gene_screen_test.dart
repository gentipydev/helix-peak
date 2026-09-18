import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/theme/anatomy_colors.dart';
import 'package:helixpeak/core/theme/app_colors.dart';
import 'package:helixpeak/core/theme/app_theme.dart';
import 'package:helixpeak/core/theme/nucleotide_colors.dart';
import 'package:helixpeak/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeak/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeak/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeak/features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import 'package:helixpeak/features/gene_lookup/presentation/screens/gene_screen.dart';
import 'package:mocktail/mocktail.dart';

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
          child: const GeneScreen(target: ProteinCatalog.insulin),
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
}
