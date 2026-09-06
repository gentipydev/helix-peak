import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/entities/analysis_result.dart';
import '../bloc/analysis_bloc.dart';
import '../bloc/analysis_event.dart';
import '../bloc/analysis_state.dart';
import '../widgets/composition_bar.dart';
import '../widgets/sequence_view.dart';
import '../widgets/stat_card.dart';

/// Analysis output, in all of its states.
///
/// The `switch` below is the project's loading/error/data convention in
/// practice. Because [AnalysisState] is a sealed union, adding a state without
/// handling it here fails to compile — the exhaustiveness is enforced by the
/// language rather than remembered by the author.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              context.read<AnalysisBloc>().add(const AnalysisEvent.cleared());
              context.pop();
            },
            child: const Text('New'),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<AnalysisBloc, AnalysisState>(
          builder: (BuildContext context, AnalysisState state) {
            return switch (state) {
              AnalysisInitial() => const _EmptyState(),
              AnalysisLoading() => const LoadingView(
                  label: 'ANALYSING SEQUENCE',
                ),
              AnalysisSuccess(:final AnalysisResult result) =>
                _ResultsBody(result: result),
              AnalysisFailure(:final String message) => ErrorView(
                  message: message,
                  // Retry is a re-dispatched event, not a callback carrying
                  // the payload: the bloc still holds the last input, so this
                  // screen never needs to know what was submitted.
                  onRetry: () => context
                      .read<AnalysisBloc>()
                      .add(const AnalysisEvent.retried()),
                ),
            };
          },
        ),
      ),
    );
  }
}

/// Reached by deep-linking straight to this route with nothing submitted.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Nothing analysed yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Submit a sequence to see composition statistics and '
              'predicted properties.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Enter a sequence'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: <Widget>[
        Text(
          result.input.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${result.input.sequenceType.label} · ${result.lengthBases} bases',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xl),

        Row(
          children: <Widget>[
            Expanded(
              child: StatCard(
                label: 'GC content',
                value: '${result.gcContentPercent.toStringAsFixed(1)}%',
                caption: 'Guanine + cytosine',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Melting point',
                value: '${result.meltingTemperatureCelsius.toStringAsFixed(1)}°C',
                caption: 'Estimated Tm',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        StatCard(
          label: 'Molecular weight',
          value: '${(result.molecularWeightDaltons / 1000).toStringAsFixed(2)} kDa',
          caption: 'Single-stranded, approximate',
        ),

        const SizedBox(height: AppSpacing.xxl),
        const _SectionHeader(title: 'Base composition'),
        const SizedBox(height: AppSpacing.lg),
        CompositionBar(counts: result.counts),

        if (result.predictions.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          const _SectionHeader(title: 'Predicted properties'),
          const SizedBox(height: AppSpacing.sm),
          for (final PropertyPrediction prediction in result.predictions)
            _PredictionRow(prediction: prediction),
        ],

        if (result.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          const _SectionHeader(title: 'Notes'),
          const SizedBox(height: AppSpacing.sm),
          for (final String warning in result.warnings)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('— $warning', style: theme.textTheme.bodyMedium),
            ),
        ],

        const SizedBox(height: AppSpacing.xxl),
        const _SectionHeader(title: 'Sequence'),
        const SizedBox(height: AppSpacing.lg),
        SequenceView(bases: result.input.bases),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Text(title.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Divider(color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.prediction});

  final PropertyPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(prediction.label, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(prediction.value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // A prediction without a stated confidence is not a useful
          // prediction, so it is shown alongside every value.
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${(prediction.confidence * 100).round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: prediction.confidence.clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
