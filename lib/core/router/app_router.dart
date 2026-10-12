import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../features/gene_lookup/domain/usecases/fetch_gene.dart';
import '../../features/gene_lookup/presentation/cubit/gene_lookup_cubit.dart';
import '../../features/gene_lookup/presentation/screens/gene_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../catalog/protein_target.dart';
import '../catalog/protein_track.dart';
import '../network/api_exception.dart';
import '../network/track_client.dart';
import '../network/track_rows.dart';
import '../network/track_source.dart';
import 'walk_route.dart';

export 'walk_route.dart' show walkPage, walkRoute;

abstract final class RoutePaths {
  static const String home = '/';
  static const String search = '/search';
  static const String gene = '/gene';

  /// Where the lab was. Nothing is there now: only links saved while
  /// replication and the zoom were lab flows still use it, and those routes
  /// redirect to where each is now.
  static const String lab = '/lab';

  /// The replication tour, in every build. Its routes are handed to
  /// [buildAppRouter] by the app.
  static const String replication = '/replication';

  /// The zoom from a body down to one protein's DNA, in every build. Like
  /// replication's, its routes are handed to [buildAppRouter] by the app.
  static const String zoom = '/zoom';

  /// The walk for one protein. `/gene` with nothing after it is still the
  /// insulin walk, so every link that predates the catalog keeps working.
  static String geneFor(ProteinTarget target) => '$gene/${target.slug}';

  /// The zoom for one protein. [overWalk] says the walk is the page under
  /// it, which is where its "Walk ›" then goes back to: the walk's gene page
  /// opens the zoom so, and nothing else does.
  static String zoomFor(ProteinTarget target, {bool overWalk = false}) =>
      '$zoom/${target.slug}${overWalk ? '?$_over=$_walk' : ''}';

  /// Whether [uri] is a zoom opened over the walk, as [zoomFor] writes one.
  static bool zoomIsOverWalk(Uri uri) => uri.queryParameters[_over] == _walk;

  static const String _over = 'over';
  static const String _walk = 'walk';
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
//
// One of the catalog's own opens on the row the list holds, at once. Any other
// is a protein built on demand, whose fold can be published again while the
// app runs: it is read afresh at every open, its row and its track rows
// together, and its walk reads that one generation of its fold ([pinWalk]).
Widget _walkBody(BuildContext context, GoRouterState state) {
  final ProteinCatalogRepository catalog =
      context.read<ProteinCatalogRepository>();
  final String slug = state.pathParameters['slug'] ??
      ProteinCatalogRepository.fallbackSlug;
  final ProteinTarget? target = catalog.bySlug(slug);
  return target != null && catalog.listed(slug)
      ? _geneBody(target)
      : _WalkLoader(key: ValueKey<String>(slug), catalog: catalog, slug: slug);
}

Widget _geneBody(ProteinTarget target, {TrackSource? pinned}) {
  final Widget walk = BlocProvider<GeneLookupCubit>(
    create: (BuildContext context) =>
        GeneLookupCubit(context.read<FetchGene>())..load(target.query),
    child: GeneScreen(target: target),
  );
  return pinned == null
      ? walk
      : RepositoryProvider<TrackSource>.value(value: pinned, child: walk);
}

/// A protein built on demand's track rows, read with its row, and a source
/// that reads its walk by them: one generation of its fold, whatever the
/// service publishes while the walk is open. The next open reads again.
///
/// The two are read one after the other, so a fold published in between can
/// part them (`foldCoherence`): then both are read once more. A fold still
/// made in another model's frame is not animated, and the walk opens on the
/// model; a row naming another model than its track holds is left for the
/// fold page, which says the model could not be loaded. Where no track rows
/// can be read at all, the walk reads as it always has.
@visibleForTesting
Future<(ProteinTarget, TrackSource?)> pinWalk(
  ProteinCatalogRepository catalog,
  TrackClient client,
  ProteinTarget target,
) async {
  Map<TrackKind, TrackRef> rows;
  try {
    rows = await client.refresh(target.slug);
  } on Object catch (error) {
    debugPrint('helixpeek: no track rows to pin ${target.slug} to ($error)');
    return (target, null);
  }
  if (foldCoherence(target, rows) != FoldCoherence.whole) {
    try {
      target = await catalog.protein(target.slug, fresh: true);
      rows = await client.refresh(target.slug);
    } on Object catch (error) {
      debugPrint('helixpeek: ${target.slug} read once more, and not ($error)');
    }
  }
  if (foldCoherence(target, rows) == FoldCoherence.modelOnly) {
    rows = <TrackKind, TrackRef>{
      ...rows,
      TrackKind.folding: const TrackRef(state: TrackState.absent),
    };
  }
  return (target, client.pinned(target.slug, rows));
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
  TrackSource? _pinned;
  Object? _error;
  bool _fetching = false;

  /// The app's track source, where it is the client that can read a
  /// protein's rows afresh; null in a test that hands its own in.
  TrackClient? _client;

  @override
  void initState() {
    super.initState();
    final TrackSource? source = context.read<TrackSource?>();
    _client = source is TrackClient ? source : null;
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
      final ProteinCatalogRepository catalog = widget.catalog;
      final bool listed = catalog.listed(widget.slug);
      ProteinTarget target = await catalog.protein(widget.slug, fresh: !listed);
      TrackSource? pinned;
      final TrackClient? client = _client;
      if (!listed && client != null) {
        (target, pinned) = await pinWalk(catalog, client, target);
      }
      if (mounted) {
        setState(() {
          _target = target;
          _pinned = pinned;
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProteinTarget? target = _target;
    if (target != null) return _geneBody(target, pinned: _pinned);
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

/// The app's routes, with [extra] spread in after the walk's own.
///
/// [extra] is how replication's and the zoom's routes arrive: `lib/app.dart`
/// hands them over, so that core names no feature it did not already name
/// (the architecture test's `layers` rule). Empty, this is [appRouter]
/// exactly.
GoRouter buildAppRouter({List<RouteBase> extra = const <RouteBase>[]}) =>
    GoRouter(
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
        ...extra,
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

final GoRouter appRouter = buildAppRouter();
