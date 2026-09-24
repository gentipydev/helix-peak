import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/gene_lookup/data/datasources/catalog_local_data_source.dart';
import '../../features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import '../../features/gene_lookup/data/repositories/gene_repository_impl.dart';
import '../../features/gene_lookup/data/repositories/impact_explanation_repository.dart';
import '../../features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../features/gene_lookup/domain/repositories/gene_repository.dart';
import '../../features/gene_lookup/domain/usecases/fetch_gene.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../network/dio_api_client.dart';
import '../network/mock_api_client.dart';

List<RepositoryProvider<Object>> buildAppProviders() {
  return <RepositoryProvider<Object>>[
    // The only line mock mode touches. Everything below is the same object
    // graph either way, which is what makes the mock build worth trusting:
    // the data source, the DTO parsing and the repository are not stood in for.
    RepositoryProvider<ApiClient>(
      create: (BuildContext context) => Env.useMockData
          ? MockApiClient()
          : DioApiClient(baseUrl: Env.apiBaseUrl, timeout: Env.apiTimeout),
    ),
    RepositoryProvider<CatalogLocalDataSource>(
      create: (BuildContext context) => const CatalogLocalDataSource(),
    ),
    // Built already holding the bundled twenty, so the router and the search
    // screen can read it synchronously on the first frame. The refresh it
    // starts here replaces them when it lands; nothing waits for it.
    RepositoryProvider<ProteinCatalogRepository>(
      create: (BuildContext context) {
        final ProteinCatalogRepository catalog = ProteinCatalogRepository(
          context.read<ApiClient>(),
          context.read<CatalogLocalDataSource>(),
        );
        unawaited(catalog.load());
        return catalog;
      },
    ),
    RepositoryProvider<GeneRemoteDataSource>(
      create: (BuildContext context) =>
          GeneRemoteDataSourceImpl(context.read<ApiClient>()),
    ),
    RepositoryProvider<ImpactExplanationRepository>(
      create: (BuildContext context) =>
          ImpactExplanationRepository(context.read<ApiClient>()),
    ),
    RepositoryProvider<GeneRepository>(
      create: (BuildContext context) =>
          GeneRepositoryImpl(context.read<GeneRemoteDataSource>()),
    ),
    RepositoryProvider<FetchGene>(
      create: (BuildContext context) =>
          FetchGene(context.read<GeneRepository>()),
    ),
  ];
}
