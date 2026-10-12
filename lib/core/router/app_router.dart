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
// Held already, it waits on the service no longer than [walkPatience].
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

/// How long the open of a protein already read in this run waits on the
/// service before it opens on what the app holds ([pinWalk]).
@visibleForTesting
const Duration walkPatience = Duration(seconds: 2);

/// A protein built on demand, read for one walk: its row and its track rows,
/// and a source that reads the walk by those rows alone, so the walk draws
/// one generation of its fold whatever the service publishes while it is
/// open. The next open reads again.
///
/// The two are asked for together. A fold published between the two answers
/// can part them (`foldCoherence`): then both are asked for once more. A fold
/// still made in another model's frame is not animated, and the walk opens on
/// the model; a row naming another model than its track holds is left for the
/// fold page, which says the model could not be loaded. Where no track rows
/// can be read at all, the walk reads as it always has.
///
/// A protein already read in this run does not wait on a service that is slow
/// to answer (asleep, or far away): after [patience] it opens on the row and
/// the rows the app holds, where those are one fold, and the answer, when it
/// comes, is kept for the next open. A service that cannot be reached at all
/// fails at once, and the same two are what
/// [ProteinCatalogRepository.protein] and [TrackClient.refresh] fall back to.
@visibleForTesting
Future<(ProteinTarget, TrackSource?)> pinWalk(
  ProteinCatalogRepository catalog,
  TrackClient client,
  String slug, {
  Duration patience = walkPatience,
}) async {
  final ProteinTarget? held = catalog.bySlug(slug);
  final Future<Map<TrackKind, TrackRef>>? kept = client.remembered(slug);
  final Future<(ProteinTarget, Map<TrackKind, TrackRef>?)> asked = _readWalk(
    catalog,
    client,
    slug,
  );
  (ProteinTarget, Map<TrackKind, TrackRef>?)? read;
  if (held != null && kept != null) {
    read = await asked
        .then<(ProteinTarget, Map<TrackKind, TrackRef>?)?>(
          ((ProteinTarget, Map<TrackKind, TrackRef>?) answer) => answer,
        )
        .timeout(patience, onTimeout: () => null);
    if (read == null) {
      try {
        final Map<TrackKind, TrackRef> rows = await kept;
        if (foldCoherence(held, rows) == FoldCoherence.whole) {
          read = (held, rows);
        }
      } on Object catch (error) {
        debugPrint('helixpeek: nothing held to open $slug on ($error)');
      }
    }
  }
  final (ProteinTarget target, Map<TrackKind, TrackRef>? rows) =
      read ?? await asked;
  if (rows == null) {
    return (target, null);
  }
  return (
    target,
    client.pinned(
      slug,
      foldCoherence(target, rows) == FoldCoherence.modelOnly
          ? <TrackKind, TrackRef>{
              ...rows,
              TrackKind.folding: const TrackRef(state: TrackState.absent),
            }
          : rows,
    ),
  );
}

/// [slug]'s row and its track rows, asked of the service together, and once
/// more where they are not one fold. Its rows are null where none can be
/// read; a row that cannot be read throws.
Future<(ProteinTarget, Map<TrackKind, TrackRef>?)> _readWalk(
  ProteinCatalogRepository catalog,
  TrackClient client,
  String slug,
) async {
  Future<(ProteinTarget, Map<TrackKind, TrackRef>?)> both() async {
    final Future<Map<TrackKind, TrackRef>?> rows = client
        .refresh(slug)
        .then<Map<TrackKind, TrackRef>?>(
          (Map<TrackKind, TrackRef> rows) => rows,
          onError: (Object error) {
            debugPrint('helixpeek: no track rows to pin $slug to ($error)');
            return null;
          },
        );
    final ProteinTarget target = await catalog.protein(slug, fresh: true);
    return (target, await rows);
  }

  final (ProteinTarget, Map<TrackKind, TrackRef>?) first = await both();
  final Map<TrackKind, TrackRef>? rows = first.$2;
  if (rows == null || foldCoherence(first.$1, rows) == FoldCoherence.whole) {
    return first;
  }
  try {
    final (ProteinTarget, Map<TrackKind, TrackRef>?) second = await both();
    return second.$2 == null ? first : second;
  } on Object catch (error) {
    debugPrint('helixpeek: $slug read once more, and not ($error)');
    return first;
  }
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
      final TrackClient? client = _client;
      final ProteinTarget target;
      TrackSource? pinned;
      if (listed || client == null) {
        target = await catalog.protein(widget.slug, fresh: !listed);
      } else {
        (target, pinned) = await pinWalk(catalog, client, widget.slug);
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
