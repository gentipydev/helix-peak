import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/gene_lookup/domain/entities/protein_catalog.dart';
import '../../features/gene_lookup/domain/entities/protein_target.dart';
import '../../features/gene_lookup/domain/usecases/fetch_gene.dart';
import '../../features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import '../../features/gene_lookup/presentation/format.dart';
import '../../features/gene_lookup/presentation/screens/gene_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../shared/widgets/error_view.dart';

abstract final class RoutePaths {
  static const String home = '/';
  static const String search = '/search';
  static const String gene = '/gene';

  /// The walk for one protein. `/gene` with nothing after it is still the
  /// insulin walk, so every link that predates the catalog keeps working.
  static String geneFor(ProteinTarget target) => '$gene/${target.slug}';
}

/// The page a walk is shown on.
///
/// On iOS a page slides in, and a drag from the left edge normally slides it
/// back out — which on the walk is exactly the drag a reader makes to go back
/// a stage, and it threw away their place in the walk. So the walk keeps the
/// platform's slide and gives up the edge gesture; the back button, Back and
/// Escape still leave it. Elsewhere it is an ordinary page.
Page<void> walkPage({
  required BuildContext context,
  required LocalKey key,
  required Widget child,
}) {
  final TargetPlatform platform = Theme.of(context).platform;
  if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
    return MaterialPage<void>(key: key, child: child);
  }
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) => CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: false,
          child: child,
        ),
  );
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
  final String? slug = state.pathParameters['slug'];
  final ProteinTarget? target = slug == null
      ? ProteinCatalog.fallback
      : ProteinCatalog.bySlug(slug);
  if (target == null) {
    return Scaffold(
      body: ErrorView(
        title: 'No such protein',
        message:
            'This build ships ${spelled(ProteinCatalog.all.length)} proteins, '
            'and $slug is not one of them.',
        onRetry: () => context.go(RoutePaths.search),
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
    ),
  ),
);
