import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../features/gene_lookup/domain/entities/protein_target.dart';
import '../../features/gene_lookup/domain/usecases/fetch_gene.dart';
import '../../features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import '../../features/gene_lookup/presentation/screens/gene_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../network/api_exception.dart';
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
  final ProteinCatalogRepository catalog =
      context.read<ProteinCatalogRepository>();
  final String slug = state.pathParameters['slug'] ??
      ProteinCatalogRepository.fallbackSlug;
  final ProteinTarget? target = catalog.bySlug(slug);
  return target == null
      ? _WalkLoader(key: ValueKey<String>(slug), catalog: catalog, slug: slug)
      : _geneBody(target);
}

Widget _geneBody(ProteinTarget target) {
  return BlocProvider<GeneLookupCubit>(
    create: (BuildContext context) =>
        GeneLookupCubit(context.read<FetchGene>())..load(target.query),
    child: GeneScreen(target: target),
  );
}

/// A deep link can arrive before the catalog, or name a protein outside it.
class _WalkLoader extends StatefulWidget {
  const _WalkLoader({required this.catalog, required this.slug, super.key});

  final ProteinCatalogRepository catalog;
  final String slug;

  @override
  State<_WalkLoader> createState() => _WalkLoaderState();
}

class _WalkLoaderState extends State<_WalkLoader> {
  ProteinTarget? _target;
  Object? _error;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    widget.catalog.status.addListener(_resolve);
    _resolve();
  }

  @override
  void dispose() {
    widget.catalog.status.removeListener(_resolve);
    super.dispose();
  }

  void _resolve() {
    if (_fetching || _target != null ||
        widget.catalog.status.value == CatalogStatus.loading) {
      return;
    }
    _fetching = true;
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    try {
      final ProteinTarget target = await widget.catalog.protein(widget.slug);
      if (mounted) setState(() => _target = target);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProteinTarget? target = _target;
    if (target != null) return _geneBody(target);
    final Object? error = _error;
    if (error == null) {
      return Scaffold(body: LoadingView(label: 'LOADING ${widget.slug.toUpperCase()}'));
    }
    final bool missing = error is ServerApiException && error.statusCode == 404;
    return Scaffold(
      body: ErrorView(
        title: missing ? 'No such protein' : 'Fetch failed',
        message: missing
            ? 'The service holds no protein called "${widget.slug}".'
            : (error is ApiException ? error.userMessage : const UnknownApiException().userMessage),
        onRetry: missing ? () => context.go(RoutePaths.search) : () {
          setState(() => _error = null);
          _resolve();
        },
        action: missing ? 'Browse proteins' : 'Retry',
        actionIcon: missing ? Icons.list_rounded : Icons.refresh_rounded,
      ),
    );
  }
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
