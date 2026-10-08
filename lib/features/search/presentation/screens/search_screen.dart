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
      child: const _SearchView(everyProtein: true),
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
    super.dispose();
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
                      // A single result is what the reader was after; anything
                      // else and submitting has nothing to add to the list
                      // already on screen.
                      onSubmitted: (_) {
                        if (results.length == 1) {
                          _open(results.single);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: carried == 0 && _catalog.status.value == CatalogStatus.loading
                          ? const Column(children: <Widget>[
                              Text('The service can take up to a minute to wake.'),
                              Expanded(child: LoadingView(label: 'LOADING PROTEINS')),
                            ])
                          : carried == 0 && _catalog.status.value == CatalogStatus.failed
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
    final Set<String> building = <String>{
      for (final ProteinBuild build in pinned) build.gene,
    };
    final SuggestionPage? page = switch (found) {
      SuggestionsShown(:final SuggestionPage page) => page,
      SuggestionsLoading(:final SuggestionPage? previous) => previous,
      _ => null,
    };
    // A curated protein the list already shows is not shown twice.
    final List<ProteinSuggestion> others = <ProteinSuggestion>[
      for (final ProteinSuggestion suggestion
          in page?.suggestions ?? const <ProteinSuggestion>[])
        if (!shown.contains(suggestion.slug) &&
            !building.contains(suggestion.gene))
          suggestion,
    ];
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
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
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
        if (nothing)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: nothingFound,
          ),
        if (results.isNotEmpty) ...<Widget>[
          _SectionHeader(
            title: 'Curated',
            caption:
                '${spelledLeading(carried)} proteins, checked by hand '
                'and baked in advance.',
          ),
          for (final ProteinTarget target in results) ...<Widget>[
            ProteinCard(target: target, onTap: () => _open(target)),
            const SizedBox(height: AppSpacing.sm),
          ],
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
              onBuild: (ProteinSuggestion protein) =>
                  unawaited(_builds!.build(protein)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
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
