import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../gene_lookup/domain/entities/protein_catalog.dart';
import '../../../gene_lookup/domain/entities/protein_target.dart';
import '../../../gene_lookup/presentation/format.dart';
import '../widgets/protein_card.dart';

/// Pick a protein to walk.
///
/// The field searches the proteins this build ships and nothing else. There
/// is no request behind it — the backend has no search endpoint yet, and one
/// that hung for twenty-five seconds on an unreachable host before saying so
/// would be worse than none. So typing filters the list, and a name that is not
/// on it gets told that plainly and immediately.
///
/// That is also why the list is the screen's resting state rather than
/// something the field reveals. A reader who does not already know what they
/// are looking for should not have to guess a name to find out what is here,
/// and twenty is few enough to simply show.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
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
    final List<ProteinTarget> results = ProteinCatalog.matching(_query);

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
                      child: results.isEmpty
                          ? _NothingFound(query: _query.trim())
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

/// What a query with no match gets told.
///
/// Not "no results": the reader has almost certainly typed a real protein, and
/// the honest answer is that this build cannot fetch one it was not built with.
/// Saying so is also the only place the app admits the backend is not there,
/// which is worth one sentence.
class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.query});

  final String query;

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
              'This build carries ${spelled(ProteinCatalog.all.length)} proteins '
              'and does not go looking for others. Searching every gene arrives '
              'with the service behind it.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
