import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../features/gene_lookup/domain/entities/protein_catalog.dart';
import '../../features/gene_lookup/domain/entities/protein_target.dart';
import '../../features/gene_lookup/domain/usecases/fetch_gene.dart';
import '../../features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import '../../features/gene_lookup/presentation/format.dart';
import '../../features/gene_lookup/presentation/screens/gene_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../shared/widgets/error_view.dart';
import 'walk_route.dart';

export 'walk_route.dart' show walkPage, walkRoute;

abstract final class RoutePaths {
  static const String home = '/';
  static const String search = '/search';
  static const String gene = '/gene';

  /// The walk for one protein. `/gene` with nothing after it is still the
  /// insulin walk, so every link that predates the catalog keeps working.
  static String geneFor(ProteinTarget target) => '$gene/${target.slug}';
}

GoRoute _walk(String path) => GoRoute(
  path: path,
  pageBuilder: (BuildContext context, GoRouterState state) => walkPage(
    context: context,
    key: state.pageKey,
    child: _walkBody(context, state),
  ),
);

// The cubit is created per visit and starts fetching immediately, so a deep
// link to a protein behaves the same as picking it off the search screen.
Widget _walkBody(BuildContext context, GoRouterState state) {
  // Null where nothing provided one — the bundled seed answers in its place,
  // so a deep link resolves on the first frame whether or not the catalog
  // refresh has landed, and whether or not there is a service to refresh from.
  final ProteinCatalogRepository? catalog =
      context.read<ProteinCatalogRepository?>();
  final String? slug = state.pathParameters['slug'];
  final ProteinTarget? target = slug == null
      ? (catalog?.fallback ?? ProteinCatalog.fallback)
      // A slug this build bundles but the served catalog has not caught up to
      // still opens: the seed is asked second rather than not at all.
      : (catalog?.bySlug(slug) ?? ProteinCatalog.bySlug(slug));
  if (target == null) {
    final int carried = catalog?.all.length ?? ProteinCatalog.all.length;
    return Scaffold(
      body: ErrorView(
        title: 'No such protein',
        message:
            'This build ships ${spelled(carried)} proteins, '
            'and $slug is not one of them.',
        onRetry: () => context.go(RoutePaths.search),
        action: 'Browse proteins',
        actionIcon: Icons.list_rounded,
      ),
    );
  }
  return BlocProvider<GeneLookupCubit>(
    create: (BuildContext context) =>
        GeneLookupCubit(context.read<FetchGene>())..load(target.query),
    child: GeneScreen(target: target),
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.home,
  debugLogDiagnostics: kDebugMode,
  routes: <RouteBase>[
    GoRoute(
      path: RoutePaths.home,
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: RoutePaths.search,
      builder: (BuildContext context, GoRouterState state) =>
          const SearchScreen(),
    ),
    _walk('${RoutePaths.gene}/:slug'),
    _walk(RoutePaths.gene),
  ],
  errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
    body: ErrorView(
      title: 'Page not found',
      message: 'No route matches ${state.uri}.',
      onRetry: () => context.go(RoutePaths.home),
      action: 'Go home',
      actionIcon: Icons.home_outlined,
    ),
  ),
);
