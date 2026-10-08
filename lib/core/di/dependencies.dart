import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/gene_lookup/data/datasources/gene_remote_data_source.dart';
import '../../features/gene_lookup/data/repositories/gene_repository_impl.dart';
import '../../features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../features/gene_lookup/domain/repositories/gene_repository.dart';
import '../../features/gene_lookup/domain/usecases/fetch_gene.dart';
import '../../shared/share/clip_exporter.dart';
import '../catalog/install_id.dart';
import '../catalog/protein_builds.dart';
import '../catalog/protein_resolver.dart';
import '../evidence/impact_explanation_repository.dart';
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
    RepositoryProvider<ProteinResolver>(
      create: (BuildContext context) =>
          ProteinResolver(context.read<ApiClient>()),
    ),
    // One list of builds for the whole app, so that a build outlives the
    // search that asked for it. Each ask names this install, so that only
    // this phone may stop what it started.
    RepositoryProvider<ProteinBuilds>(
      create: (BuildContext context) => ProteinBuilds(
        context.read<ProteinResolver>(),
        asker: InstallId().read,
      ),
      dispose: (ProteinBuilds builds) => builds.dispose(),
    ),
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
    // One clip at a time for the whole app, so that it outlives the page
    // that asked for it.
    RepositoryProvider<ClipExporter>(
      create: (BuildContext context) => ClipExporter(),
      dispose: (ClipExporter exporter) => exporter.dispose(),
    ),
  ];
}
