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
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../cubit/built_proteins_cubit.dart';
import '../cubit/protein_suggestions_cubit.dart';
import '../widgets/build_card.dart';
import '../widgets/list_wait.dart';
import '../widgets/protein_card.dart';
import '../widgets/suggestion_tile.dart';

/// Two tabs, swiped between or chosen by name, each a search of its own with
/// its own field. Curated, which the screen opens on, searches the curated
/// list: checked by hand, every track baked in advance. Build on demand
/// searches every reviewed human protein, built from its UniProt entry and
/// MANE transcript when it is asked for. Each one found says what the app can
/// do with it: open it, build it, or why it cannot be built. With nothing
/// typed, Build on demand is its line alone.
///
/// Searching every protein needs a [ProteinResolver], which the app always
/// provides (`core/di`). Where nothing does, the screen is the curated list
/// alone, with no tabs.
///
/// Builds are the app's [ProteinBuilds], so one outlives this screen. Where
/// nothing provides them, the screen keeps its own for as long as it is open.
/// Asking for one ends the search that found it: the field is emptied and put
/// away, and the build's card shows at the top of the list. Each build is
/// pinned at the top of both tabs while it runs, until it is opened.
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
        create: (BuildContext context) {
          final ProteinBuilds builds = context.read<ProteinBuilds>();
          return BuiltProteinsCubit(
            resolver,
            ended: builds.ended,
            decided: builds.decided,
          );
        },
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

  /// Whether every reviewed human protein is searched, on a tab of its own,
  /// with the cubit and the builds above this that it takes.
  final bool everyProtein;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView>
    with TickerProviderStateMixin {
  /// The app's builds; null where only the curated list is searched.
  ProteinBuilds? _builds;

  /// The tabs; null where only the curated list is searched. Made where the
  /// reader's motion setting is known, and made again if it changes, since a
  /// controller's duration is how far `TabBarView` animates a tab chosen.
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    if (widget.everyProtein) {
      _builds = context.read<ProteinBuilds>();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.everyProtein) {
      return;
    }
    final bool still = MediaQuery.disableAnimationsOf(context);
    final TabController? before = _tabs;
    if (before != null && (before.animationDuration == Duration.zero) == still) {
      return;
    }
    _tabs = TabController(
      length: _Shelf.values.length,
      initialIndex: before?.index ?? 0,
      animationDuration: still ? Duration.zero : null,
      vsync: this,
    )..addListener(_turned);
    if (before != null) {
      before.removeListener(_turned);
      // Once the tabs and their pages hold the new one.
      WidgetsBinding.instance.addPostFrameCallback((_) => before.dispose());
    }
  }

  /// A tab turned to puts the keyboard away: what was being typed was the
  /// other tab's.
  void _turned() => FocusScope.of(context).unfocus();

  @override
  void dispose() {
    // A build that ended with nothing to open has been said here.
    _builds?.unpinEnded();
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TabController? tabs = _tabs;
    return Theme(
      data: AppTheme.analysis,
      child: Scaffold(
        // The same 44 the walk's header is, so the chrome does not resize
        // under the reader on the way in.
        appBar: AppBar(title: const Text('Proteins'), toolbarHeight: 44),
        body: SafeArea(
          child: tabs == null
              ? const _CuratedPage(builds: null)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.xs,
                        AppSpacing.screenPadding,
                        0,
                      ),
                      child: _ShelfTabs(
                        key: const ValueKey<String>('search-shelves'),
                        controller: tabs,
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: tabs,
                        children: <Widget>[
                          _CuratedPage(builds: _builds),
                          _BuildPage(builds: _builds!),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The curated list, searched by its own field, the catalog's own wait and
/// failure on it.
class _CuratedPage extends StatefulWidget {
  const _CuratedPage({required this.builds});

  /// The app's builds, pinned over the list; null where only the curated
  /// list is searched.
  final ProteinBuilds? builds;

  @override
  State<_CuratedPage> createState() => _CuratedPageState();
}

class _CuratedPageState extends State<_CuratedPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _field = TextEditingController();
  final ScrollController _list = ScrollController();
  String _query = '';

  late final ProteinCatalogRepository _catalog;

  /// Its query and its place in the list outlive a swipe to the other tab.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _catalog = context.read<ProteinCatalogRepository>();
    _catalog.rows.addListener(_refreshed);
    _catalog.status.addListener(_refreshed);
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
    _field.dispose();
    _list.dispose();
    super.dispose();
  }

  void _typed(String value) => setState(() => _query = value);

  /// A single match is what the reader was after, and opens; anything else
  /// and submitting has nothing to add to the list already on screen.
  void _submitted(List<ProteinTarget> results) {
    if (results.length == 1) {
      _openTarget(context, results.single);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final List<ProteinTarget> results = _catalog.matching(_query);
    final int carried = _catalog.all.length;
    final ProteinBuilds? builds = widget.builds;
    return _Page(
      field: _SearchField(
        controller: _field,
        hint: 'insulin, TP53, P01308',
        clearable: _query.isNotEmpty,
        onChanged: _typed,
        onSubmitted: () => _submitted(results),
      ),
      list: carried == 0 && _catalog.status.value == CatalogStatus.loading
          // Under the line the list's own caption takes, so the first card
          // lands where the first place was.
          ? const ListWait(
              label: 'LOADING PROTEINS',
              header: _Caption('The service can take up to a minute to wake.'),
            )
          : carried == 0 && _catalog.status.value == CatalogStatus.failed
          ? ErrorView(
              title: 'List unavailable',
              message: 'The service did not answer. Check the connection and try again.',
              onRetry: _catalog.refresh,
              action: 'Retry',
            )
          : builds == null
          ? _results(context, results, carried, const <ProteinBuild>[])
          : ValueListenableBuilder<Map<String, ProteinBuild>>(
              valueListenable: builds.builds,
              builder: (
                BuildContext context,
                Map<String, ProteinBuild> now,
                Widget? child,
              ) => _results(context, results, carried, _pinned(now)),
            ),
    );
  }

  Widget _results(
    BuildContext context,
    List<ProteinTarget> results,
    int carried,
    List<ProteinBuild> pinned,
  ) {
    final String query = _query.trim();
    final Widget nothing = _NothingFound(
      query: query,
      why: 'Search covers the ${spelled(carried)} proteins in the list.',
    );
    final bool none = results.isEmpty && query.isNotEmpty;
    if (none && pinned.isEmpty) {
      return nothing;
    }
    return ListView(
      controller: _list,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        if (widget.builds case final ProteinBuilds builds)
          ..._pinnedCards(context, builds, pinned),
        if (none)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: nothing,
          ),
        if (results.isNotEmpty) ...<Widget>[
          _Caption(
            '${spelledLeading(carried)} proteins, checked by hand '
            'and baked in advance.',
          ),
          for (final ProteinTarget target in results) ...<Widget>[
            ProteinCard(target: target, onTap: () => _openTarget(context, target)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

/// Every reviewed human protein, searched by its own field: each one found
/// says what can be done with it, and one that can be built is built from
/// here. With nothing typed, its line alone.
class _BuildPage extends StatefulWidget {
  const _BuildPage({required this.builds});

  final ProteinBuilds builds;

  @override
  State<_BuildPage> createState() => _BuildPageState();
}

class _BuildPageState extends State<_BuildPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _field = TextEditingController();

  /// Put back at its top when a build is asked for, where the build's card is.
  final ScrollController _list = ScrollController();
  String _query = '';

  /// What the tab says it searches, and how what it finds is built.
  static const String _caption =
      'Built from UniProt and MANE, scored with ESM-2.';

  /// Its query and its place in the list outlive a swipe to the other tab.
  @override
  bool get wantKeepAlive => true;

  /// What is built is asked for as the tab is first shown; the list asks again
  /// itself as a build ends, is kept or is discarded (`BuiltProteinsCubit`).
  @override
  void initState() {
    super.initState();
    context.read<BuiltProteinsCubit>().load();
  }

  @override
  void dispose() {
    _field.dispose();
    _list.dispose();
    super.dispose();
  }

  void _typed(String value) {
    setState(() => _query = value);
    context.read<ProteinSuggestionsCubit>().query(value);
  }

  /// Builds search found under way are watched, not offered to open: a
  /// protein is ready minutes before its ESM-2 track is.
  void _found(BuildContext context, SuggestionsState found) {
    if (found is! SuggestionsShown) {
      return;
    }
    for (final ProteinSuggestion suggestion in found.page.suggestions) {
      if (suggestion.building) {
        widget.builds.watch(suggestion);
      }
    }
  }

  /// Build [protein], which search found: what the search was for, so it
  /// ends. The field is emptied and put away (a screen reader's tap is no
  /// touch outside it), and the list goes back to its top, where the build's
  /// card is pinned; from further down the card would come in out of sight.
  void _startBuild(ProteinSuggestion protein) {
    FocusScope.of(context).unfocus();
    _field.clear();
    _typed('');
    if (_list.hasClients) {
      _list.jumpTo(0);
    }
    unawaited(widget.builds.build(protein));
  }

  /// The one protein found opens, where it opens at all. Nothing is built but
  /// by its own Build.
  void _submitted() {
    final SuggestionsState found = context.read<ProteinSuggestionsCubit>().state;
    if (found is! SuggestionsShown) {
      return;
    }
    final Map<String, ProteinBuild> now = widget.builds.builds.value;
    final List<ProteinSuggestion> others = _others(found.page, now);
    if (others.length != 1) {
      return;
    }
    final String? slug = SuggestionTile.opensAt(others.single, now[others.single.gene]);
    if (slug != null) {
      _openSlug(context, slug, others.single);
    }
  }

  /// What [page] names, but a protein pinned while it builds, which is
  /// nowhere else meanwhile.
  List<ProteinSuggestion> _others(
    SuggestionPage? page,
    Map<String, ProteinBuild> builds,
  ) => <ProteinSuggestion>[
    for (final ProteinSuggestion suggestion
        in page?.suggestions ?? const <ProteinSuggestion>[])
      if (!(builds[suggestion.gene]?.pinned ?? false)) suggestion,
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _Page(
      field: _SearchField(
        controller: _field,
        hint: 'calmodulin, BRCA1, P02753',
        clearable: _query.isNotEmpty,
        onChanged: _typed,
        onSubmitted: _submitted,
      ),
      list: BlocConsumer<ProteinSuggestionsCubit, SuggestionsState>(
        listener: _found,
        builder: (BuildContext context, SuggestionsState found) =>
            ValueListenableBuilder<Map<String, ProteinBuild>>(
              valueListenable: widget.builds.builds,
              builder: (
                BuildContext context,
                Map<String, ProteinBuild> builds,
                Widget? child,
              ) => _results(context, found, builds),
            ),
      ),
    );
  }

  Widget _results(
    BuildContext context,
    SuggestionsState found,
    Map<String, ProteinBuild> builds,
  ) {
    final String query = _query.trim();
    final bool asking = query.length >= ProteinSuggestionsCubit.shortest;
    final List<ProteinBuild> pinned = _pinned(builds);
    final SuggestionPage? page = !asking
        ? null
        : switch (found) {
            SuggestionsShown(:final SuggestionPage page) => page,
            SuggestionsLoading(:final SuggestionPage? previous) => previous,
            _ => null,
          };
    final List<ProteinSuggestion> others = _others(page, builds);
    final bool none = asking && found is SuggestionsShown && others.isEmpty;
    final Widget nothing = _NothingFound(
      query: query,
      why: 'No reviewed human protein matches it.',
    );
    if (none && pinned.isEmpty) {
      return nothing;
    }
    return ListView(
      controller: _list,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        ..._pinnedCards(context, widget.builds, pinned),
        if (none)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: nothing,
          )
        else ...<Widget>[
          _Caption(
            <String>[
              _caption,
              if (page?.release case final String release) release,
            ].join(' '),
          ),
          if (query.isNotEmpty && !asking)
            Text(
              'Type more to look through every reviewed human protein.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (asking && found is SuggestionsLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (found case SuggestionsFailed(:final String message) when asking)
            _Unreachable(
              message: message,
              onRetry: context.read<ProteinSuggestionsCubit>().retry,
            ),
          for (final ProteinSuggestion suggestion in others) ...<Widget>[
            SuggestionTile(
              suggestion: suggestion,
              built: builds[suggestion.gene],
              onOpen: (String slug) => _openSlug(context, slug, suggestion),
              onBuild: _startBuild,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (query.isEmpty)
            BlocBuilder<BuiltProteinsCubit, BuiltState>(
              builder: (BuildContext context, BuiltState built) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _built(context, built, builds),
              ),
            ),
        ],
      ],
    );
  }

  /// With nothing typed: every protein built on demand, every install's,
  /// newest first, each opening its walk. One pinned at the top is its card
  /// there, and not a row here as well. A protein built whole says nothing
  /// the tab's name does not; one whose scoring was stopped says "No ESM-2".
  List<Widget> _built(
    BuildContext context,
    BuiltState built,
    Map<String, ProteinBuild> builds,
  ) {
    final BuiltPage? page = switch (built) {
      BuiltShown(:final BuiltPage page) => page,
      BuiltLoading(:final BuiltPage? previous) => previous,
      _ => null,
    };
    return <Widget>[
      if (built is BuiltLoading && page == null)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (built case BuiltFailed(:final String message))
        _Unreachable(
          message: message,
          onRetry: context.read<BuiltProteinsCubit>().load,
        ),
      for (final ProteinSuggestion suggestion
          in page?.proteins ?? const <ProteinSuggestion>[])
        if (!(builds[suggestion.gene]?.pinned ?? false)) ...<Widget>[
          SuggestionTile(
            suggestion: suggestion,
            built: builds[suggestion.gene],
            heading: 'Built on demand',
            onOpen: (String slug) => _openSlug(context, slug, suggestion),
            // Opened from here, as it is; asking again is search's.
            onBuild: null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
    ];
  }
}

/// This phone's builds that are pinned: each while it runs, whatever is
/// typed or chosen, until it is opened.
List<ProteinBuild> _pinned(Map<String, ProteinBuild> builds) => <ProteinBuild>[
  for (final ProteinBuild build in builds.values)
    if (build.pinned) build,
];

/// The pinned builds' cards, at the top of a tab's list.
List<Widget> _pinnedCards(
  BuildContext context,
  ProteinBuilds builds,
  List<ProteinBuild> pinned,
) => <Widget>[
  if (pinned.isNotEmpty) ...<Widget>[
    const _SectionHeader(title: 'Building'),
    for (final ProteinBuild build in pinned) ...<Widget>[
      BuildCard(
        key: ValueKey<String>('build-${build.gene}'),
        job: build,
        onOpen: (String slug) {
          builds.opened(build.gene);
          _openSlug(context, slug, build.protein);
        },
        onBuild: (ProteinSuggestion protein) => unawaited(builds.build(protein)),
        onStop: (ProteinBuild build) => unawaited(_stop(context, builds, build)),
        onKeep: (ProteinBuild build) =>
            unawaited(_said(context, builds.keep(build.gene))),
        onDiscard: (ProteinBuild build) =>
            unawaited(_said(context, builds.discard(build.gene))),
      ),
      const SizedBox(height: AppSpacing.sm),
    ],
    const SizedBox(height: AppSpacing.md),
  ],
];

/// Stop a build this phone asked for; where the service would not, say why.
Future<void> _stop(
  BuildContext context,
  ProteinBuilds builds,
  ProteinBuild build,
) => _said(context, builds.stop(build.gene));

/// What the service said where it would not do what a card asked, in a
/// snackbar; nothing where it did.
Future<void> _said(BuildContext context, Future<String?> asked) async {
  final String? said = await asked;
  if (said != null && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(said)));
  }
}

void _openTarget(BuildContext context, ProteinTarget target) =>
    _openAt(context, RoutePaths.geneFor(target));

/// Open the walk of a protein outside the catalog, handing it what this
/// screen already calls it: its walk's wait is headed by that while its row
/// is read, as a curated protein's is by its row.
void _openSlug(BuildContext context, String slug, ProteinSuggestion named) => _openAt(
  context,
  '${RoutePaths.gene}/$slug',
  names: switch (named.gene) {
    final String gene => RoutePaths.walkNames(gene: gene, display: named.title),
    null => null,
  },
);

void _openAt(BuildContext context, String location, {Map<String, String>? names}) {
  // Dismissed before the push so the keyboard is not still animating down
  // over the walk's first frame.
  FocusScope.of(context).unfocus();
  context.push(location, extra: names);
}

/// A tab's page: its field, and under it its list.
class _Page extends StatelessWidget {
  const _Page({required this.field, required this.list});

  final Widget field;
  final Widget list;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        field,
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: list),
      ],
    ),
  );
}

/// A tab's search field.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.clearable,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;

  /// Whether something is typed, which Clear takes away.
  final bool clearable;

  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        hintText: hint,
        // The cursor already shows where typing goes; the accent ring on
        // focus only drew the eye away from the list.
        focusedBorder: theme.inputDecorationTheme.enabledBorder,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        suffixIcon: !clearable
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
      onChanged: onChanged,
      // Flutter keeps a field focused when a touch lands outside it; the
      // reader expects the cursor to go.
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

/// The two tabs.
enum _Shelf {
  curated('Curated'),
  build('Build on demand');

  const _Shelf(this.label);

  final String label;
}

/// The two tabs over the pages: plain names, the chosen one bright over an
/// accent line, as the walk's page bar marks the page on screen. Not the
/// walk's `StageBar` itself, which a screen reader hears as stages of a walk.
/// Each name's ink and line follow [controller]'s animation, so a swipe
/// carries the mark from one name to the other under the finger.
class _ShelfTabs extends StatelessWidget {
  const _ShelfTabs({required this.controller, super.key});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Animation<double> turning = controller.animation!;
    return AnimatedBuilder(
      animation: turning,
      builder: (BuildContext context, Widget? child) => Row(
        children: <Widget>[
          for (final _Shelf shelf in _Shelf.values) ...<Widget>[
            if (shelf != _Shelf.values.first) const SizedBox(width: AppSpacing.xl),
            // Large text gives a name less room, never more than the row.
            Flexible(
              child: _tab(
                shelf,
                colors,
                theme.textTheme.titleSmall!,
                // 1 on its own page, 0 a page or more away.
                (1 - (turning.value - shelf.index).abs()).clamp(0.0, 1.0),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tab(_Shelf shelf, ColorScheme colors, TextStyle style, double on) {
    final bool chosen = shelf.index == controller.index;
    return Semantics(
      button: true,
      selected: chosen,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: chosen ? null : () => controller.animateTo(shelf.index),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: IntrinsicWidth(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  shelf.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(
                    color: Color.lerp(colors.onSurfaceVariant, colors.onSurface, on),
                  ),
                ),
                const SizedBox(height: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: on),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: const SizedBox(height: 2),
                ),
              ],
            ),
          ),
        ),
      ),
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
    child: Text(text, style: Theme.of(context).caption),
  );
}

/// The name of one part of the list, and a line on what is in it where its
/// name does not say enough.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// The service did not answer a search of every protein: this says the
/// proteins could not be looked through, and offers to ask again.
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

/// What a query with no match on its tab gets told.
class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.query, required this.why});

  final String query;

  /// What the tab looked through, which nothing in matches.
  final String why;

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
              why,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
