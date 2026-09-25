import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_query.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/screens/gene_screen.dart';

import '../../support/catalog_api.dart';

class _Records implements GeneRepository {
  final List<GeneQuery> asked = [];
  @override
  Future<GeneRecord> fetchGene(GeneQuery query) {
    asked.add(query);
    return Completer<GeneRecord>().future;
  }
}

void main() {
  late CatalogApi api;
  late ProteinCatalogRepository catalog;
  late _Records records;
  setUp(() {
    api = CatalogApi();
    catalog = ProteinCatalogRepository(api, null);
    records = _Records();
    appRouter.go('/');
  });
  tearDown(() => catalog.dispose());

  Future<void> host(WidgetTester tester, String path) async {
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
        RepositoryProvider<FetchGene>.value(value: FetchGene(records)),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go(path);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  }

  testWidgets('an in-memory slug opens directly without a detail fetch', (tester) async {
    await catalog.refresh();
    await host(tester, '/gene/insulin');
    expect(find.byType(GeneScreen), findsOneWidget);
    expect(records.asked.single.slug, 'insulin');
    expect(api.asked, ['/catalog']);
    await finish(tester);
  });

  testWidgets('a cold deep link waits for the catalog then uses its row', (tester) async {
    await host(tester, '/gene/insulin');
    expect(find.text('LOADING INSULIN'), findsOneWidget);
    expect(api.asked, isEmpty);
    await catalog.refresh();
    await tester.pump();
    expect(find.byType(GeneScreen), findsOneWidget);
    expect(api.asked, ['/catalog']);
    await finish(tester);
  });

  testWidgets('a slug outside the list fetches a detail with nullable chrome', (tester) async {
    await catalog.refresh();
    final row = Map<String, dynamic>.from((catalogFixture()['proteins'] as List).first as Map)
      ..['slug'] = 'new-protein'
      ..['structure'] = null;
    api.answer = (_, _) async => row;
    await host(tester, '/gene/new-protein');
    await tester.pump();
    expect(tester.widget<GeneScreen>(find.byType(GeneScreen)).target.structure, isNull);
    expect(records.asked.single.slug, 'new-protein');
    expect(api.asked.last, '/protein/new-protein');
    await finish(tester);
  });

  testWidgets('404 shows a browse action', (tester) async {
    await catalog.refresh();
    api.answer = (_, _) async => throw const ServerApiException(statusCode: 404);
    await host(tester, '/gene/nonesuch');
    expect(find.text('No such protein'), findsOneWidget);
    expect(find.text('The service holds no protein called "nonesuch".'), findsOneWidget);
    expect(find.text('Browse proteins'), findsOneWidget);
    await tester.tap(find.text('Browse proteins'));
    await tester.pump();
    expect(appRouter.routeInformationProvider.value.uri.path, '/search');
    await finish(tester);
  });

  testWidgets('a network failure offers retry and recovers', (tester) async {
    await catalog.refresh();
    api.answer = (_, _) async => throw const NetworkApiException();
    await host(tester, '/gene/new-protein');
    expect(find.text('Fetch failed'), findsOneWidget);
    final row = Map<String, dynamic>.from((catalogFixture()['proteins'] as List).first as Map)
      ..['slug'] = 'new-protein';
    api.answer = (_, _) async => row;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(GeneScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('bare /gene waits then opens the fallback slug', (tester) async {
    await host(tester, '/gene');
    expect(find.text('LOADING INSULIN'), findsOneWidget);
    await catalog.refresh();
    await tester.pump();
    expect(records.asked.single.slug, 'insulin');
    await finish(tester);
  });
}
