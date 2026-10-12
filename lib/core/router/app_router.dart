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
import '../theme/app_theme.dart';
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

  /// What a list hands the walk's route, as its `extra`, when it opens a
  /// protein outside the catalog it already names: the gene's symbol and the
  /// protein's name. The walk's wait is then headed from its first frame, as
  /// a curated protein's is, before the row itself has been read. Plain
  /// strings, which the router can keep with the route.
  static Map<String, String> walkNames({
    required String gene,
    required String display,
  }) => <String, String>{_gene: gene, _display: display};

  static const String _gene = 'gene';
  static const String _display = 'display';

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
//
// Either way the page that slides in is the walk's own screen ([GeneScreen]):
// one ground, one header, and the walk landing in the places its wait held
// for it. A protein outside the catalog opened before in this run opens at
// once on what the app holds, as a curated one does, and is checked behind
// that; one not yet read is headed, while it is, by the names the list it was
// opened from hands over ([RoutePaths.walkNames]). See [_WalkLoader].
Widget _walkBody(BuildContext context, GoRouterState state) {
  final ProteinCatalogRepository catalog =
      context.read<ProteinCatalogRepository>();
  final String slug = state.pathParameters['slug'] ??
      ProteinCatalogRepository.fallbackSlug;
  final ProteinTarget? target = catalog.bySlug(slug);
  return target != null && catalog.listed(slug)
      ? _geneBody(target)
      : _WalkLoader(
          key: ValueKey<String>(slug),
          catalog: catalog,
          slug: slug,
          held: target,
          named: _named(slug, state.extra),
        );
}

/// [slug] as a list named it when it opened its walk
/// ([RoutePaths.walkNames]), or null where none did: a link from outside the
/// app, or a protein with no symbol.
///
/// It stands in for the row only while the row is read, and only the walk's
/// wait is given it, which reads the symbol and the name: the record is not
/// asked for, and nothing is walked, until the row itself is in.
ProteinTarget? _named(String slug, Object? extra) {
  if (extra is! Map<Object?, Object?>) {
    return null;
  }
  final Object? gene = extra[RoutePaths._gene];
  final Object? display = extra[RoutePaths._display];
  if (gene is! String || display is! String || gene.isEmpty) {
    return null;
  }
  return ProteinTarget(
    slug: slug,
    display: display,
    gene: gene,
    uniprot: '',
    accession: '',
    summary: '',
    facts: const ProteinFacts(residues: 0, exons: 0, chains: 0, bridges: 0),
    chains: const <StructureChain>[],
    structure: null,
  );
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
  return (target, rows == null ? null : _pin(client, target, rows));
}

/// The source [target]'s walk reads by [rows] alone. A fold made in another
/// model's frame is left out of them, so the walk opens on the model.
PinnedTrackSource _pin(
  TrackClient client,
  ProteinTarget target,
  Map<TrackKind, TrackRef> rows,
) => client.pinned(
  target.slug,
  foldCoherence(target, rows) == FoldCoherence.modelOnly
      ? <TrackKind, TrackRef>{
          ...rows,
          TrackKind.folding: const TrackRef(state: TrackState.absent),
        }
      : rows,
);

/// Whether two readings of a protein's track rows are the same tracks: each
/// family in the same state, the same bytes at the same address.
bool _sameRows(Map<TrackKind, TrackRef> a, Map<TrackKind, TrackRef> b) {
  for (final TrackKind kind in <TrackKind>{...a.keys, ...b.keys}) {
    final TrackRef? one = a[kind];
    final TrackRef? other = b[kind];
    if (one?.state != other?.state ||
        one?.sha256 != other?.sha256 ||
        one?.url != other?.url) {
      return false;
    }
  }
  return true;
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
///
/// A protein outside the catalog is a protein built on demand, read afresh at
/// every open ([pinWalk]). What its page shows meanwhile is the walk's own,
/// from its first frame, by how much is known of it when the route opens:
///
/// - **Opened before in this run** ([held], with the rows it was read by):
///   its walk opens at once on those, as a curated protein's does on its row,
///   and the service is asked behind it. Where it answers within
///   [walkPatience] with other rows (its fold published again, or a track
///   made since), the walk is opened again on them, a moment after the first,
///   unless the reader has touched it by then; where it is slower, or the
///   walk is in use, this walk stays as it opened and the next adopts.
/// - **Named by the list it was opened from** ([named]): the walk's wait
///   ([GeneScreen] over a lookup not yet asked for the record), headed by
///   those names. Once the row and its rows are in, the screen is given the
///   row, its walk the source that reads by those rows, and only then is the
///   record asked for. Nothing is swapped for anything else on the way: it is
///   the wait a curated protein's first open shows.
/// - **Nothing known** (a link from outside the app): the wait cannot be
///   headed. It keeps the walk's ground and the height of its header, so
///   neither changes under the reader when the walk's own wait takes over.
class _WalkLoader extends StatefulWidget {
  const _WalkLoader({
    required this.catalog,
    required this.slug,
    this.held,
    this.named,
    super.key,
  });

  final ProteinCatalogRepository catalog;
  final String slug;

  /// The protein's row as an earlier open in this run read it.
  final ProteinTarget? held;

  /// The protein by its names alone ([_named]), where a list handed them.
  final ProteinTarget? named;

  @override
  State<_WalkLoader> createState() => _WalkLoaderState();
}

class _WalkLoaderState extends State<_WalkLoader> {
  /// The row the walk on screen is given, and the rows it reads by: read
  /// from the service for this open, or held and opened on at once.
  ProteinTarget? _target;
  TrackSource? _pinned;
  Map<TrackKind, TrackRef>? _rows;

  Object? _error;
  bool _fetching = false;

  /// The app's track source, and the client it is where it can read a
  /// protein's rows afresh; a test may hand in a source that cannot, or none.
  TrackSource? _source;
  TrackClient? _client;

  /// The lookup the walk's screen stands over: made here where the screen is
  /// up before the row is, so that it is asked for the record once the row is
  /// in and not before. Null where the wait cannot be the walk's own.
  GeneLookupCubit? _lookup;

  /// Which walk this page is on: a second is opened where the service says,
  /// in time, that the first was opened on rows it has since replaced.
  int _walk = 0;

  /// Whether the reader has put a finger on the walk opened at once: it is
  /// theirs from then, and is not opened again under them.
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    final TrackSource? source = context.read<TrackSource?>();
    _source = source;
    final TrackClient? client = _client = source is TrackClient ? source : null;
    final ProteinTarget? held = widget.held;
    final Map<TrackKind, TrackRef>? rows = held == null
        ? null
        : client?.known(widget.slug);
    if (client != null &&
        held != null &&
        rows != null &&
        foldCoherence(held, rows) == FoldCoherence.whole) {
      // Held whole: its walk opens on it now, and the service is asked behind.
      _target = held;
      _rows = rows;
      _pinned = _pin(client, held, rows);
      _lookup = _lookupFor(held);
      unawaited(_recheck(client));
      return;
    }
    if (held != null || widget.named != null) {
      _lookup = GeneLookupCubit(context.read<FetchGene>());
    }
    widget.catalog.status.addListener(_resolve);
    _resolve();
  }

  @override
  void dispose() {
    widget.catalog.status.removeListener(_resolve);
    unawaited(_lookup?.close());
    super.dispose();
  }

  /// A lookup already asked for [target]'s record, as a curated walk's is.
  GeneLookupCubit _lookupFor(ProteinTarget target) {
    final GeneLookupCubit lookup = GeneLookupCubit(context.read<FetchGene>());
    unawaited(lookup.load(target.query));
    return lookup;
  }

  /// The walk opened on what the app held. The service is asked all the same,
  /// and where it answers within [walkPatience] with other rows than those,
  /// the walk is opened again on what it says; a slower answer is kept for
  /// the next open, and this walk stays whole as it is.
  Future<void> _recheck(TrackClient client) async {
    final (ProteinTarget, Map<TrackKind, TrackRef>?)? fresh;
    try {
      fresh = await _readWalk(widget.catalog, client, widget.slug)
          .then<(ProteinTarget, Map<TrackKind, TrackRef>?)?>(
            ((ProteinTarget, Map<TrackKind, TrackRef>?) answer) => answer,
          )
          .timeout(walkPatience, onTimeout: () => null);
    } on Object catch (error) {
      debugPrint('helixpeek: ${widget.slug} stays as it opened ($error)');
      return;
    }
    final Map<TrackKind, TrackRef>? rows = fresh?.$2;
    if (fresh == null ||
        rows == null ||
        !mounted ||
        _touched ||
        _sameRows(rows, _rows!)) {
      return;
    }
    final ProteinTarget target = fresh.$1;
    final GeneLookupCubit? before = _lookup;
    setState(() {
      _walk++;
      _target = target;
      _rows = rows;
      _pinned = _pin(client, target, rows);
      _lookup = _lookupFor(target);
    });
    unawaited(before?.close());
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
      if (!mounted) {
        return;
      }
      setState(() {
        _target = target;
        _pinned = pinned;
      });
      // The row is in, and the source its walk reads by: now the record.
      unawaited(_lookup?.load(target.query));
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProteinTarget? target = _target;
    final GeneLookupCubit? lookup = _lookup;
    final Object? error = _error;
    if (lookup != null && error == null) {
      // The walk's own screen from the first frame: its wait, then the walk.
      // The row takes the place of what was known of it, and the pinned
      // source the app's, under the screen and not in place of it.
      final Widget walk = BlocProvider<GeneLookupCubit>.value(
        value: lookup,
        child: GeneScreen(target: target ?? widget.held ?? widget.named!),
      );
      final TrackSource? source = _pinned ?? _source;
      return KeyedSubtree(
        key: ValueKey<int>(_walk),
        // Only looked at: the walk's own gestures are its own.
        child: Listener(
          onPointerDown: (PointerDownEvent event) => _touched = true,
          child: source == null
              ? walk
              : RepositoryProvider<TrackSource>.value(
                  value: source,
                  child: walk,
                ),
        ),
      );
    }
    if (target != null) return _geneBody(target, pinned: _pinned);
    final bool missing = error is ServerApiException && error.statusCode == 404;
    // The walk's ground and the 44 its header is, as [GeneScreen]'s own wait
    // and failure are set: neither changes under the reader on the way to
    // the walk, or to the page that says there is none.
    return Theme(
      data: AppTheme.analysis,
      child: Scaffold(
        appBar: AppBar(toolbarHeight: 44),
        body: SafeArea(
          child: error == null
              ? LoadingView(label: 'LOADING ${widget.slug.toUpperCase()}')
              : ErrorView(
                  title: missing ? 'No such protein' : 'Fetch failed',
                  message: missing
                      ? 'The service holds no protein called "${widget.slug}".'
                      : (error is ApiException
                            ? error.userMessage
                            : const UnknownApiException().userMessage),
                  onRetry: missing
                      ? () => context.go(RoutePaths.search)
                      : () {
                          setState(() => _error = null);
                          _resolve();
                        },
                  action: missing ? 'Browse proteins' : 'Retry',
                  actionIcon: missing
                      ? Icons.list_rounded
                      : Icons.refresh_rounded,
                ),
        ),
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
