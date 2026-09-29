import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/gene_query.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/screens/gene_screen.dart';
import 'package:helixpeek/shared/share/gene_link.dart';
import 'package:helixpeek/shared/share/share_action.dart';

import '../../support/catalog_api.dart';
import '../../support/test_catalog.dart';

void main() {
  final ProteinTarget insulin = TestCatalog.insulin;

  test('the link is the app\'s scheme and the walk\'s own path', () {
    expect(geneLink(insulin).toString(), 'helixpeek://open/gene/insulin');
    expect(geneLink(insulin).path, '/gene/insulin');
    expect(
      posterText(insulin),
      'Insulin in Helix Peek: $geneLinkScheme://open/gene/insulin',
    );
  });

  testWidgets('the link opens the walk when the platform delivers it', (
    WidgetTester tester,
  ) async {
    final ProteinCatalogRepository catalog = ProteinCatalogRepository(
      CatalogApi(),
      null,
    );
    addTearDown(catalog.dispose);
    await catalog.refresh();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
          RepositoryProvider<FetchGene>.value(value: FetchGene(_Records())),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    expect(find.byType(GeneScreen), findsNothing);
    // What Flutter's embedding sends when the app is opened by the link.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', <String, Object?>{
          'location': geneLink(insulin).toString(),
          'state': null,
        }),
      ),
      (ByteData? _) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GeneScreen), findsOneWidget);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      '/gene/insulin',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });
}

/// Never answers, so a walk stays on its own loading page: still `GeneScreen`.
class _Records implements GeneRepository {
  @override
  Future<GeneRecord> fetchGene(GeneQuery query) =>
      Completer<GeneRecord>().future;
}
