import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/catalog/protein_builds.dart';
import '../../../../core/catalog/protein_resolver.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/format.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../cubit/built_proteins_cubit.dart';
import '../cubit/protein_suggestions_cubit.dart';
import '../widgets/build_card.dart';
import '../widgets/protein_card.dart';
import '../widgets/suggestion_tile.dart';

/// Search the curated list, and below it every reviewed human protein, which
/// can be built on demand. Refreshing the list never blocks typing.
///
/// The two are kept apart on purpose. The curated proteins were checked by
/// hand and every track of theirs is baked in advance; any other protein is
/// built from its UniProt entry and MANE transcript when it is asked for, and
/// says so.
///
/// Searching every protein needs a [ProteinResolver], which the app always
/// provides (`core/di`). Where nothing does, the screen is the curated list
/// alone, exactly as it was before there was anything else to search.
///
/// Builds are the app's [ProteinBuilds], so one outlives this screen. Where
/// nothing provides them, the screen keeps its own for as long as it is open.
/// Asking for one ends the search that found it: the field is emptied and put
/// away, and the build's card shows at the top of the list.
///
/// With nothing typed, two tabs sit under the field: the curated list, which
/// the screen opens on, and the proteins built on demand, every install's,
/// newest first. Typing hides them: a search covers everything, whichever tab
/// was chosen, and clearing the field goes back to that tab.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProteinResolver? resolver = context.read<ProteinResolver?>();
    if (resolver == null) {
      return const _SearchView(everyProtein: false);
    }
    final Widget view = BlocProvider<ProteinSuggestionsCubit>(
      create: (BuildContext context) => ProteinSuggestionsCubit(resolver),
      child: BlocProvider<BuiltProteinsCubit>(
        create: (BuildContext context) => BuiltProteinsCubit(
          resolver,
          ended: context.read<ProteinBuilds>().ended,
        ),
        child: const _SearchView(everyProtein: true),
      ),
    );
    if (context.read<ProteinBuilds?>() != null) {
      return view;
    }
    return RepositoryProvider<ProteinBuilds>(
      create: (BuildContext context) => ProteinBuilds(resolver),
      dispose: (ProteinBuilds builds) => builds.dispose(),
      child: view,
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({required this.everyProtein});

  /// Whether every reviewed human protein is searched below the list, with
  /// the cubit and the builds above this that it takes.
  final bool everyProtein;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  /// The tab chosen, kept while a search hides the tabs.
  _Shelf _shelf = _Shelf.curated;

  /// Put back at its top when a build is asked for, where the build's card is.
  final ScrollController _list = ScrollController();

  late final ProteinCatalogRepository _catalog;

  /// The app's builds; null where only the curated list is searched.
  ProteinBuilds? _builds;

  @override
  void initState() {
    super.initState();
    _catalog = context.read<ProteinCatalogRepository>();
    _catalog.rows.addListener(_refreshed);
    _catalog.status.addListener(_refreshed);
    if (widget.everyProtein) {
      _builds = context.read<ProteinBuilds>();
    }
  }

  void _refreshed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _catalog.rows.removeListener(_refreshed);
    _catalog.status.removeListener(_refreshed);
    // A build that ended with nothing to open has been said here.
    _builds?.unpinEnded();
    _controller.dispose();
    _list.dispose();
    super.dispose();
  }

  /// Whether the tabs show: only with nothing typed, since a search covers
  /// everything whichever tab is chosen.
  bool get _shelves => widget.everyProtein && _query.trim().isEmpty;

  /// Each time the built tab is chosen, its list is asked for again.
  void _choose(_Shelf shelf) {
    setState(() => _shelf = shelf);
    if (shelf == _Shelf.built) {
      context.read<BuiltProteinsCubit>().load();
    }
  }

  /// Builds search found under way are watched, not offered to open: a
  /// protein is ready minutes before its ESM-2 track is.
  void _found(BuildContext context, SuggestionsState found) {
    final ProteinBuilds? builds = _builds;
    if (builds == null || found is! SuggestionsShown) {
      return;
    }
    for (final ProteinSuggestion suggestion in found.page.suggestions) {
      if (suggestion.building) {
        builds.watch(suggestion);
      }
    }
  }

  void _typed(String value) {
    setState(() => _query = value);
    if (widget.everyProtein) {
      context.read<ProteinSuggestionsCubit>().query(value);
    }
  }

  /// Build [protein], which search found: what the search was for, so it
  /// ends. The field is emptied and put away (a screen reader's tap is no
  /// touch outside it), and the list goes back to its top, where the build's
  /// card is pinned; from further down the card would come in out of sight.
  void _startBuild(ProteinSuggestion protein) {
    FocusScope.of(context).unfocus();
    _controller.clear();
    _typed('');
    if (_list.hasClients) {
      _list.jumpTo(0);
    }
    unawaited(_builds!.build(protein));
  }

  /// A single result is what the reader was after: the one curated match,
  /// or, with none, the one other protein, where it opens. Anything else and
  /// submitting has nothing to add to the list already on screen, and nothing
  /// is built but by its own Build.
  void _submitted(List<ProteinTarget> results) {
    if (results.length == 1) {
      _open(results.single);
      return;
    }
    final ProteinBuilds? builds = _builds;
    if (results.isNotEmpty || builds == null) {
      return;
    }
    final SuggestionsState found = context.read<ProteinSuggestionsCubit>().state;
    if (found is! SuggestionsShown) {
      return;
    }
    final Map<String, ProteinBuild> now = builds.builds.value;
    final List<ProteinSuggestion> others = _others(found.page, const <String>{}, now);
    if (others.length != 1) {
      return;
    }
    final String? slug = SuggestionTile.opensAt(others.single, now[others.single.gene]);
    if (slug != null) {
      _openSlug(slug);
    }
  }

  /// What [page] names that is not on screen already. A curated protein the
  /// list shows ([shown], by slug) is not shown twice, and one pinned while it
  /// builds is nowhere else meanwhile.
  List<ProteinSuggestion> _others(
    SuggestionPage? page,
    Set<String> shown,
    Map<String, ProteinBuild> builds,
  ) => <ProteinSuggestion>[
    for (final ProteinSuggestion suggestion
        in page?.suggestions ?? const <ProteinSuggestion>[])
      if (!shown.contains(suggestion.slug) &&
          !(builds[suggestion.gene]?.pinned ?? false))
        suggestion,
  ];

  void _open(ProteinTarget target) => _openAt(RoutePaths.geneFor(target));

  void _openSlug(String slug) => _openAt('${RoutePaths.gene}/$slug');

  void _openBuilt(ProteinBuild build, String slug) {
    _builds?.opened(build.gene);
    _openSlug(slug);
  }

  /// Stop a build this phone asked for; where the service would not, say why.
  Future<void> _stop(ProteinBuild build) async {
    final String? said = await _builds?.stop(build.gene);
    if (said != null && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(said)));
    }
  }

  void _openAt(String location) {
    // Dismissed before the push so the keyboard is not still animating down
    // over the walk's first frame.
    FocusScope.of(context).unfocus();
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final List<ProteinTarget> results = _catalog.matching(_query);
    final int carried = _catalog.all.length;
    // The catalog's own states are the curated tab's: the built tab asks the
    // service for its list itself.
    final bool curated = !(_shelves && _shelf == _Shelf.built);

    return Theme(
      data: AppTheme.analysis,
      child: Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          return Scaffold(
            // The same 44 the walk's header is, so the chrome does not resize
            // under the reader on the way in.
            appBar: AppBar(title: const Text('Proteins'), toolbarHeight: 44),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        hintText: 'insulin, TP53, P01308',
                        // The cursor already shows where typing goes; the
                        // accent ring on focus only drew the eye away from
                        // the list.
                        focusedBorder: theme.inputDecorationTheme.enabledBorder,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Clear',
                                onPressed: () {
                                  _controller.clear();
                                  _typed('');
                                },
                              ),
                      ),
                      onChanged: _typed,
                      // Flutter keeps a field focused when a touch lands
                      // outside it; the reader expects the cursor to go.
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      onSubmitted: (_) => _submitted(results),
                    ),
                    if (_shelves) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _ShelfTabs(
                        key: const ValueKey<String>('search-shelves'),
                        chosen: _shelf,
                        onChoose: _choose,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: curated && carried == 0 && _catalog.status.value == CatalogStatus.loading
                          ? const Column(children: <Widget>[
                              Text('The service can take up to a minute to wake.'),
                              Expanded(child: LoadingView(label: 'LOADING PROTEINS')),
                            ])
                          : curated && carried == 0 && _catalog.status.value == CatalogStatus.failed
                          ? ErrorView(
                              title: 'List unavailable',
                              message: 'The service did not answer. Check the connection and try again.',
                              onRetry: _catalog.refresh,
                              action: 'Retry',
                            )
                          : !widget.everyProtein
                          ? _results(
                              context,
                              results,
                              carried,
                              const SuggestionsIdle(),
                              const <String, ProteinBuild>{},
                            )
                          : BlocConsumer<ProteinSuggestionsCubit, SuggestionsState>(
                              listener: _found,
                              builder: (BuildContext context, SuggestionsState found) =>
                                  ValueListenableBuilder<Map<String, ProteinBuild>>(
                                    valueListenable: _builds!.builds,
                                    builder: (
                                      BuildContext context,
                                      Map<String, ProteinBuild> builds,
                                      Widget? child,
                                    ) => _results(context, results, carried, found, builds),
                                  ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _results(
    BuildContext context,
    List<ProteinTarget> results,
    int carried,
    SuggestionsState found,
    Map<String, ProteinBuild> builds,
  ) {
    final String query = _query.trim();
    final bool asking =
        widget.everyProtein && query.length >= ProteinSuggestionsCubit.shortest;
    final Set<String> shown = <String>{
      for (final ProteinTarget target in results) target.slug,
    };
    // Pinned while it builds, whatever is typed, and nowhere else meanwhile.
    final List<ProteinBuild> pinned = <ProteinBuild>[
      for (final ProteinBuild build in builds.values)
        if (build.pinned) build,
    ];
    if (_shelves) {
      return switch (_shelf) {
        _Shelf.curated => _shelfList(pinned, <Widget>[
          if (results.isNotEmpty) ...<Widget>[
            _Caption(_curatedCaption(carried)),
            ..._cards(results),
          ],
        ]),
        _Shelf.built => BlocBuilder<BuiltProteinsCubit, BuiltState>(
          builder: (BuildContext context, BuiltState built) =>
              _shelfList(pinned, _builtShelf(context, built, builds)),
        ),
      };
    }
    final SuggestionPage? page = switch (found) {
      SuggestionsShown(:final SuggestionPage page) => page,
      SuggestionsLoading(:final SuggestionPage? previous) => previous,
      _ => null,
    };
    final List<ProteinSuggestion> others = _others(page, shown, builds);
    final bool settled = found is SuggestionsShown;
    final bool nothing =
        results.isEmpty && (!asking || (settled && others.isEmpty));
    final Widget nothingFound = _NothingFound(
      query: query,
      carried: carried,
      everyProtein: widget.everyProtein,
      searchedEveryProtein: asking,
    );

    if (nothing && pinned.isEmpty) {
      return nothingFound;
    }

    final bool showOthers =
        asking && !(settled && others.isEmpty) && found is! SuggestionsIdle;
    return ListView(
      controller: _list,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        ..._pinnedCards(pinned),
        if (nothing)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: nothingFound,
          ),
        if (results.isNotEmpty) ...<Widget>[
          _SectionHeader(title: 'Curated', caption: _curatedCaption(carried)),
          ..._cards(results),
        ],
        if (showOthers) ...<Widget>[
          if (results.isNotEmpty) const SizedBox(height: AppSpacing.md),
          _SectionHeader(
            title: 'Every reviewed human protein',
            caption: <String>[
              'Built on demand from its UniProt entry and MANE transcript, '
                  'then scored with ESM-2.',
              if (page?.release case final String release) release,
            ].join(' '),
          ),
          if (found is SuggestionsLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (found case SuggestionsFailed(:final String message))
            _Unreachable(
              message: message,
              onRetry: context.read<ProteinSuggestionsCubit>().retry,
            ),
          for (final ProteinSuggestion suggestion in others) ...<Widget>[
            SuggestionTile(
              suggestion: suggestion,
              built: builds[suggestion.gene],
              onOpen: _openSlug,
              onBuild: _startBuild,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  /// The list under the tabs: this phone's builds pinned at its top, then
  /// the chosen tab's.
  Widget _shelfList(List<ProteinBuild> pinned, List<Widget> shelf) => ListView(
    controller: _list,
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: <Widget>[..._pinnedCards(pinned), ...shelf],
  );

  /// Pinned while it builds, whatever is typed or chosen, until it is opened.
  List<Widget> _pinnedCards(List<ProteinBuild> pinned) => <Widget>[
    if (pinned.isNotEmpty) ...<Widget>[
      const _SectionHeader(title: 'Building'),
      for (final ProteinBuild build in pinned) ...<Widget>[
        BuildCard(
          key: ValueKey<String>('build-${build.gene}'),
          job: build,
          onOpen: (String slug) => _openBuilt(build, slug),
          onBuild: (ProteinSuggestion protein) =>
              unawaited(_builds!.build(protein)),
          onStop: (ProteinBuild build) => unawaited(_stop(build)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.md),
    ],
  ];

  String _curatedCaption(int carried) =>
      '${spelledLeading(carried)} proteins, checked by hand '
      'and baked in advance.';

  List<Widget> _cards(List<ProteinTarget> results) => <Widget>[
    for (final ProteinTarget target in results) ...<Widget>[
      ProteinCard(target: target, onTap: () => _open(target)),
      const SizedBox(height: AppSpacing.sm),
    ],
  ];

  /// The built tab: every install's builds, newest first. One of this phone's
  /// pinned at the top is its card there, and not a row here as well.
  List<Widget> _builtShelf(
    BuildContext context,
    BuiltState built,
    Map<String, ProteinBuild> builds,
  ) {
    final BuiltPage? page = switch (built) {
      BuiltShown(:final BuiltPage page) => page,
      BuiltLoading(:final BuiltPage? previous) => previous,
      _ => null,
    };
    final TextStyle? line = Theme.of(context).textTheme.bodyMedium;
    return <Widget>[
      const _Caption('Built from UniProt and MANE, scored with ESM-2.'),
      if (built is BuiltLoading)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (built case BuiltFailed(:final String message))
        _Unreachable(
          message: message,
          onRetry: context.read<BuiltProteinsCubit>().load,
        ),
      if (built is BuiltNotListed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text('This service does not list built proteins yet.', style: line),
        ),
      if (built case BuiltShown(:final BuiltPage page) when page.proteins.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'None yet. Search for any reviewed human protein and tap Build.',
            style: line,
          ),
        ),
      for (final ProteinSuggestion suggestion
          in page?.proteins ?? const <ProteinSuggestion>[])
        if (!(builds[suggestion.gene]?.pinned ?? false)) ...<Widget>[
          SuggestionTile(
            suggestion: suggestion,
            built: builds[suggestion.gene],
            heading: _Shelf.built.label,
            onOpen: _openSlug,
            // A stopped one opens unscored here; scoring it again is
            // search's, not a tap on a list of everyone's builds.
            onBuild: null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
    ];
  }
}

/// The two tabs under the field while nothing is typed.
enum _Shelf {
  curated('Curated'),
  built('Built on demand');

  const _Shelf(this.label);

  final String label;
}

/// The two tabs under the field: plain names, the chosen one bright over an
/// accent line, as the walk's page bar marks the page on screen. Not the
/// walk's `StageBar` itself, which a screen reader hears as stages of a walk.
class _ShelfTabs extends StatelessWidget {
  const _ShelfTabs({required this.chosen, required this.onChoose, super.key});

  final _Shelf chosen;
  final ValueChanged<_Shelf> onChoose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Duration motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Row(
      children: <Widget>[
        for (final _Shelf shelf in _Shelf.values) ...<Widget>[
          if (shelf != _Shelf.values.first) const SizedBox(width: AppSpacing.xl),
          // Large text gives a name less room, never more than the row.
          Flexible(
            child: Semantics(
              button: true,
              selected: shelf == chosen,
              inMutuallyExclusiveGroup: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: shelf == chosen ? null : () => onChoose(shelf),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AnimatedDefaultTextStyle(
                          duration: motion,
                          style: theme.textTheme.titleSmall!.copyWith(
                            color: shelf == chosen
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                          child: Text(
                            shelf.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: motion,
                          height: 2,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(
                              alpha: shelf == chosen ? 1 : 0,
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One line on what a tab lists, where a header would only repeat the tab's
/// name.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// The name of one part of the list, and a line on what is in it where its
/// name does not say enough.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            if (caption case final String caption) ...<Widget>[
              const SizedBox(height: 2),
              Text(caption, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// The service did not answer a search of every protein. The curated list
/// above it still works; this says the rest could not be looked through.
class _Unreachable extends StatelessWidget {
  const _Unreachable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// What a query with no match anywhere gets told.
class _NothingFound extends StatelessWidget {
  const _NothingFound({
    required this.query,
    required this.carried,
    required this.everyProtein,
    required this.searchedEveryProtein,
  });

  final String query;

  /// How many proteins the service put in the list.
  final int carried;

  /// Whether this screen searches every reviewed human protein at all.
  final bool everyProtein;

  /// Whether every reviewed human protein was looked through too, or the
  /// query was too short to ask about them.
  final bool searchedEveryProtein;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.travel_explore_rounded,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nothing here for "$query"',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              !everyProtein
                  ? 'Search covers the ${spelled(carried)} proteins in the list.'
                  : searchedEveryProtein
                  ? 'None of the ${spelled(carried)} proteins in the list '
                        'matches it, and no other reviewed human protein does.'
                  : 'None of the ${spelled(carried)} proteins in the list '
                        'matches it. Type more to look through every reviewed '
                        'human protein.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
