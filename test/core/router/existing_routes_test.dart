import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/router/app_router.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_query.dart';
import 'package:helixpeek/features/gene_lookup/domain/repositories/gene_repository.dart';
import 'package:helixpeek/features/gene_lookup/domain/usecases/fetch_gene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/screens/gene_screen.dart';
import 'package:helixpeek/features/home/presentation/screens/home_screen.dart';
import 'package:helixpeek/features/lab/lab_routes.dart';
import 'package:helixpeek/features/lab/presentation/lab_index_screen.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';

import '../../support/catalog_api.dart';

/// Never answers, so a walk stays on its own loading page: still `GeneScreen`.
class _Records implements GeneRepository {
  @override
  Future<GeneRecord> fetchGene(GeneQuery query) =>
      Completer<GeneRecord>().future;
}

/// The routes that existed before the lab, and the widget each one lands on.
const Map<String, Type> _existing = <String, Type>{
  '/': HomeScreen,
  '/search': SearchScreen,
  '/gene': GeneScreen,
  '/gene/insulin': GeneScreen,
};

void main() {
  Future<void> land(
    WidgetTester tester,
    GoRouter router,
    String path,
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(path);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> leave(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.go('/');
  }

  group('without the lab, the walk’s own router', () {
    for (final MapEntry<String, Type> route in _existing.entries) {
      testWidgets('${route.key} lands on ${route.value}', (
        WidgetTester tester,
      ) async {
        await land(tester, appRouter, route.key);
        expect(find.byType(route.value), findsOneWidget);
        await leave(tester, appRouter);
      });
    }

    testWidgets('/lab is not a page', (WidgetTester tester) async {
      await land(tester, appRouter, RoutePaths.lab);
      expect(find.byType(LabIndexScreen), findsNothing);
      expect(find.text('Page not found'), findsOneWidget);
      await leave(tester, appRouter);
    });
  });

  group('with the lab spread in', () {
    late GoRouter router;
    setUp(() => router = buildAppRouter(extra: buildLabRoutes()));
    tearDown(() => router.dispose());

    for (final MapEntry<String, Type> route in _existing.entries) {
      testWidgets('${route.key} still lands on ${route.value}', (
        WidgetTester tester,
      ) async {
        await land(tester, router, route.key);
        expect(find.byType(route.value), findsOneWidget);
        expect(find.byType(LabIndexScreen), findsNothing);
        await leave(tester, router);
      });
    }

    testWidgets('/lab lands on the lab’s index', (WidgetTester tester) async {
      await land(tester, router, RoutePaths.lab);
      expect(find.byType(LabIndexScreen), findsOneWidget);
      await leave(tester, router);
    });
  });
}
