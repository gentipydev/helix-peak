import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import '../../core/network/track_client.dart';
import '../../core/network/track_source.dart';
import '../../core/theme/app_theme.dart';
import '../gene_lookup/data/datasources/gene_remote_data_source.dart';
import '../gene_lookup/data/repositories/gene_repository_impl.dart';
import '../gene_lookup/domain/usecases/fetch_gene.dart';

/// Everything the lab's routes share, provided once above all of them.
///
/// Chiefly its own [TrackClient]: a cache directory and a budget of its own.
/// The walk's 200 MB budget was sized as five times what the twenty proteins
/// come to, and a lab sharing it could evict a walk track while exploring,
/// which is a walk regression with no walk code changed. Below this point
/// [TrackSource] and [FetchGene] are provided again over the lab's client, so a
/// lab screen, or a shared widget one embeds, reads through the lab's cache
/// without knowing it. The walk's own routes are not below this point and keep
/// theirs.
///
/// The lab draws genes and proteins as the walk does, so it wears the walk's
/// [AppTheme.analysis].
class LabScope extends StatelessWidget {
  const LabScope({required this.child, super.key});

  final Widget child;

  /// Where under the application cache directory the lab's payloads go. Its
  /// rows go beside them, in `lab/track_rows/`, apart from the walk's.
  static const String folder = 'lab/tracks';

  /// Half the walk's: the lab reads the same records and folds, plus kinds the
  /// walk never fetches, and a reader exploring it should lose the lab's oldest
  /// files first, never the walk's.
  static const int budget = 100 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: labProviders(),
      child: Theme(data: AppTheme.analysis, child: child),
    );
  }
}

/// The lab's dependencies, each over the lab's own [TrackClient].
///
/// Reads the app's [ApiClient] from above; everything else it makes.
List<RepositoryProvider<Object>> labProviders() => <RepositoryProvider<Object>>[
  RepositoryProvider<TrackClient>(
    create: (BuildContext context) => TrackClient(
      context.read<ApiClient>(),
      folder: LabScope.folder,
      budget: LabScope.budget,
    ),
  ),
  RepositoryProvider<TrackSource>(
    create: (BuildContext context) => context.read<TrackClient>(),
  ),
  RepositoryProvider<FetchGene>(
    create: (BuildContext context) => FetchGene(
      GeneRepositoryImpl(TrackGeneDataSource(context.read<TrackSource>())),
    ),
  ),
];
