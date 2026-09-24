import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/entities/gene_record.dart';
import '../../domain/entities/protein_target.dart';
import '../anatomy/anatomy_screen.dart';
import '../cubit/gene_lookup_cubit.dart';
import '../cubit/gene_lookup_state.dart';

/// The `/gene` route: fetch, then hand the record to the anatomy screen.
///
/// The screen owns no chrome of its own once the record lands — the app bar and
/// the loading and error states below belong to the wait, and [AnatomyScreen]
/// replaces all of it the moment the record arrives.
///
/// All of it is drawn in [AppTheme.analysis], the warm ground the Protein
/// Analyses flow is set on. It goes around the wait as well as the walk, so the
/// ground does not change under the reader at the moment the record lands.
class GeneScreen extends StatelessWidget {
  const GeneScreen({required this.target, super.key});

  /// Which protein is being walked. The record arrives from the cubit, but the
  /// two assets the walk reads on its own — the constraint track and the model
  /// — are named here, and the screen is the last place that knows both.
  final ProteinTarget target;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.analysis,
      child: BlocBuilder<GeneLookupCubit, GeneLookupState>(
        builder: (BuildContext context, GeneLookupState state) {
          if (state case GeneLookupSuccess(:final GeneRecord record)) {
            return AnatomyScreen(record: record, target: target);
          }
          final ThemeData theme = Theme.of(context);
          return Scaffold(
            // The same 44 the anatomy header's own row is, so the chrome does
            // not resize under the reader at the moment the record lands —
            // and the same title, set the same way: the symbol, then the name
            // in small type. Set in the symbol's size here, the name shrank
            // under the reader as the walk arrived. The walk adds its ⓘ at the
            // row's end, so nothing already here moves when it does.
            appBar: AppBar(
              toolbarHeight: 44,
              titleSpacing: AppSpacing.lg,
              title: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(target.gene, style: theme.textTheme.titleLarge),
                    Flexible(
                      child: Text(
                        '  ·  ${target.display}',
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: SafeArea(
              child: switch (state) {
                GeneLookupInitial() => const LoadingView(label: 'STARTING'),
                GeneLookupLoading(:final query) => LoadingView(
                  label: 'FETCHING ${query.accession}',
                ),
                GeneLookupFailure(:final String message) => ErrorView(
                  title: 'Fetch failed',
                  message: message,
                  onRetry: () => context.read<GeneLookupCubit>().retry(),
                ),
                GeneLookupSuccess() => const SizedBox.shrink(),
              },
            ),
          );
        },
      ),
    );
  }
}
