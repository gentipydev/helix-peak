import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../../gene_lookup/domain/entities/protein_target.dart';
import '../../../gene_lookup/presentation/format.dart';
import '../widgets/protein_card.dart';

/// Search the cached curated list. Refreshing the list never blocks typing.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  late final ProteinCatalogRepository _catalog;

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
    _controller.dispose();
    super.dispose();
  }

  void _open(ProteinTarget target) {
    // Dismissed before the push so the keyboard is not still animating down
    // over the walk's first frame.
    FocusScope.of(context).unfocus();
    context.push(RoutePaths.geneFor(target));
  }

  @override
  Widget build(BuildContext context) {
    final List<ProteinTarget> results =
        _catalog.matching(_query);
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
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (String value) =>
                          setState(() => _query = value),
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
                          : results.isEmpty
                          ? _NothingFound(
                              query: _query.trim(),
                              carried: carried,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xl,
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (BuildContext context, int index) =>
                                  ProteinCard(
                                    target: results[index],
                                    onTap: () => _open(results[index]),
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
}

/// What a query with no match in the curated list gets told.
class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.query, required this.carried});

  final String query;

  /// How many proteins the service put in the list.
  final int carried;

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
              'Search covers the ${spelled(carried)} proteins in the list.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
