import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import '../../features/gene_lookup/data/repositories/gene_repository_impl.dart';
import '../../features/gene_lookup/data/repositories/impact_explanation_repository.dart';
import '../../features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../features/gene_lookup/domain/repositories/gene_repository.dart';
import '../../features/gene_lookup/domain/usecases/fetch_gene.dart';
import '../network/api_client.dart';
import '../network/track_client.dart';
import '../network/track_source.dart';

List<RepositoryProvider<Object>> buildAppProviders({
  required ApiClient api,
  required ProteinCatalogRepository catalog,
}) {
  return <RepositoryProvider<Object>>[
    RepositoryProvider<ApiClient>.value(value: api),
    RepositoryProvider<ProteinCatalogRepository>.value(value: catalog),
    RepositoryProvider<TrackSource>(
      create: (BuildContext context) => TrackClient(context.read<ApiClient>()),
    ),
    RepositoryProvider<GeneRemoteDataSource>(
      create: (BuildContext context) =>
          TrackGeneDataSource(context.read<TrackSource>()),
    ),
    RepositoryProvider<ImpactExplanationRepository>(
      create: (BuildContext context) =>
          ImpactExplanationRepository(context.read<TrackSource>()),
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
