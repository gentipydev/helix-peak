import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/di/dependencies.dart';
import 'package:helixpeek/core/network/api_exception.dart';
import 'package:helixpeek/features/gene_lookup/data/datasources/catalog_local_data_source.dart';
import 'package:helixpeek/features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import 'package:helixpeek/features/search/presentation/screens/search_screen.dart';
import 'package:helixpeek/features/search/presentation/widgets/protein_card.dart';

import '../../../support/catalog_api.dart';
import '../../../support/test_catalog.dart';

void main() {
  late Directory directory;
  late CatalogApi api;
  late CatalogLocalDataSource cache;
  late ProteinCatalogRepository catalog;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('helixpeek-catalog');
    api = CatalogApi();
    cache = CatalogLocalDataSource(directory: directory);
    catalog = ProteinCatalogRepository(api, cache);
  });
  tearDown(() {
    catalog.dispose();
    directory.deleteSync(recursive: true);
  });

  test('starts empty and loading; only rows and status listen', () {
    expect(catalog.all, isEmpty);
    expect(catalog.bySlug('insulin'), isNull);
    expect(catalog.status.value, CatalogStatus.loading);
    expect(catalog, isNot(isA<Listenable>()));
    expect(catalog.rows, isA<Listenable>());
    expect(catalog.status, isA<Listenable>());
    expect(ProteinCatalogRepository.fallbackSlug, 'insulin');
  });

  test('refresh restores reading order and carries served fold metadata', () async {
    int changed = 0;
    catalog.rows.addListener(() => changed++);
    await catalog.refresh();
    expect(catalog.status.value, CatalogStatus.ready);
    expect(changed, 1);
    expect(catalog.all, TestCatalog.all);
    final target = catalog.bySlug('insulin')!;
    expect(target.structure!.pdb, '3I40');
    expect(target.chains.map((c) => c.node), ['chainA', 'chainB', 'bonds']);
    expect(catalog.bySlug('p53')!.structure!.modelled, (96, 289));
    expect(catalog.bySlug('hemoglobin')!.chain, 'hemoglobin beta chain');
    expect(target.impactExplanationsAvailable, isTrue);
    expect(catalog.bySlug('p53')!.impactExplanationsAvailable, isFalse);
    for (final query in ['p01308', 'NG_012232', 'TP53', 'hormone', 'hemo', 'none']) {
      expect(catalog.matching(query), TestCatalog.matching(query));
    }
    expect(catalog.matching(''), same(catalog.all));
  });

  test('hydrate reads v2 before any network request', () async {
    await catalog.refresh();
    expect(File('${directory.path}/catalog.v2.json').existsSync(), isTrue);
    final restarted = ProteinCatalogRepository(api, cache);
    addTearDown(restarted.dispose);
    await restarted.hydrate();
    expect(api.asked, ['/catalog']);
    expect(restarted.all, TestCatalog.all);
    expect(restarted.status.value, CatalogStatus.ready);
    expect(restarted.bySlug('insulin')!.structure!.pdb, '3I40');
  });

  test('old and malformed caches cannot seed the walk', () async {
    final rows = catalogFixture()['proteins'];
    File('${directory.path}/catalog.json').writeAsStringSync(jsonEncode(rows));
    await catalog.hydrate();
    expect(catalog.all, isEmpty);
    expect(catalog.status.value, CatalogStatus.loading);
    File('${directory.path}/catalog.v2.json').writeAsStringSync('[{"slug":3}]');
    await catalog.hydrate();
    expect(catalog.all, isEmpty);
    await catalog.refresh();
    expect(catalog.status.value, CatalogStatus.ready);
  });

  test('transport and malformed-body failures preserve rows and cache', () async {
    await catalog.refresh();
    final stored = File('${directory.path}/catalog.v2.json').readAsStringSync();
    for (final error in <Object>[
      const NetworkApiException(), const TimeoutApiException(),
      const ServerApiException(statusCode: 503), StateError('bad body'),
    ]) {
      api.answer = (_, _) async => throw error;
      await catalog.refresh();
      expect(catalog.status.value, CatalogStatus.failed);
      expect(catalog.all, TestCatalog.all);
      expect(File('${directory.path}/catalog.v2.json').readAsStringSync(), stored);
    }
    api.answer = (_, _) async => {'proteins': 'not a list'};
    await catalog.refresh();
    expect(catalog.status.value, CatalogStatus.failed);
    expect(catalog.all, TestCatalog.all);
  });

  test('retry publishes loading then ready', () async {
    api.answer = (_, _) async => throw const NetworkApiException();
    await catalog.refresh();
    expect(catalog.status.value, CatalogStatus.failed);
    expect(catalog.all, isEmpty);
    final completion = Completer<Map<String, dynamic>>();
    api.answer = (_, _) => completion.future;
    final refresh = catalog.refresh();
    expect(catalog.status.value, CatalogStatus.loading);
    completion.complete(catalogFixture());
    await refresh;
    expect(catalog.status.value, CatalogStatus.ready);
  });

  test('null chrome and absent explanations are legitimate served states', () async {
    final page = catalogFixture();
    final row = (page['proteins'] as List).first as Map<String, dynamic>;
    row['structure'] = null;
    row['chains'] = <dynamic>[];
    (row['tracks'] as Map)['impact_explanations'] = 'absent';
    api.answer = (_, _) async => page;
    await catalog.refresh();
    final target = catalog.bySlug(row['slug'] as String)!;
    expect(target.structure, isNull);
    expect(target.chains, isEmpty);
    expect(target.impactExplanationsAvailable, isFalse);
    expect(catalog.all, hasLength(20));
  });

  test('details outside the list are fetched once and held only in memory', () async {
    await catalog.refresh();
    final row = Map<String, dynamic>.from((catalogFixture()['proteins'] as List).first as Map)
      ..['slug'] = 'new-protein';
    api.answer = (path, _) async {
      expect(path, '/protein/new-protein');
      return row;
    };
    final target = await catalog.protein('new-protein');
    expect(await catalog.protein('new-protein'), same(target));
    expect(catalog.bySlug('new-protein'), same(target));
    expect(catalog.all, hasLength(20));
    final restarted = ProteinCatalogRepository(api, cache);
    addTearDown(restarted.dispose);
    await restarted.hydrate();
    expect(restarted.bySlug('new-protein'), isNull);
    expect(api.asked, ['/catalog', '/protein/new-protein']);
  });

  test('pages are accumulated before adopting in reading order', () async {
    final rows = catalogFixture()['proteins'] as List;
    api.answer = (_, query) async {
      if (query?['cursor'] == null) return {'proteins': rows.take(8).toList(), 'next': 'cursor'};
      expect(query!['cursor'], 'cursor');
      return {'proteins': rows.skip(8).toList(), 'next': null};
    };
    await catalog.refresh();
    expect(catalog.all, TestCatalog.all);
    expect(api.asked, hasLength(2));
  });

  testWidgets('the app graph hands over its hydrated repository', (tester) async {
    await tester.runAsync(catalog.refresh);
    await tester.binding.setSurfaceSize(const Size(400, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: buildAppProviders(api: api, catalog: catalog),
      child: const MaterialApp(home: SearchScreen()),
    ));
    await tester.pump();
    expect(find.byType(ProteinCard), findsNWidgets(20));
    expect(find.text('Insulin'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
