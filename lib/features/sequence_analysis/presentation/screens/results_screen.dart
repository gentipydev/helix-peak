import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../domain/entities/analysis_result.dart';
import '../bloc/analysis_bloc.dart';
import '../bloc/analysis_event.dart';
import '../bloc/analysis_state.dart';

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
              'Submit a sequence to see its analysis.',
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
        Text(result.summary, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.generatedAt.toIso8601String(),
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        StatCard(label: 'Analysis', value: result.id, caption: 'Result id'),
      ],
    );
  }
}
