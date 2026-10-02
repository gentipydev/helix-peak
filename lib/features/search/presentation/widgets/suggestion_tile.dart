import 'package:flutter/material.dart';

import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import '../cubit/protein_build_cubit.dart';

/// One protein from every reviewed human protein, below the curated list:
/// what it is called, its gene, its length, and what the app can do with it.
///
/// A protein that opens (curated, or built earlier) is tapped like a card. One
/// that can be built carries the build: its button, then how far it has got,
/// then Open. One that cannot says why, in the service's words.
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    required this.suggestion,
    required this.progress,
    required this.onOpen,
    required this.onBuild,
    super.key,
  });

  final ProteinSuggestion suggestion;

  /// This protein's build, where this visit asked for one.
  final BuildProgress? progress;

  /// Opens the walk at a slug.
  final ValueChanged<String> onOpen;

  /// Asks for a build of a gene.
  final ValueChanged<String> onBuild;

  /// `P38398 · 1,863 aa`.
  static String specOf(ProteinSuggestion suggestion) =>
      '${suggestion.uniprot} · ${grouped(suggestion.length)} aa';

  /// The line under the name: where it stands, in words.
  static String statusOf(
    ProteinSuggestion suggestion,
    BuildProgress? progress,
  ) {
    if (progress != null) {
      return switch (progress.stage) {
        BuildStage.asking => 'Asking the service',
        BuildStage.resolving => 'Building its gene record',
        BuildStage.scoring => 'Scoring every residue with ESM-2',
        BuildStage.ready => progress.message ?? 'Built, ready to walk',
        BuildStage.refused =>
          progress.message ?? 'The service declined to build it.',
        BuildStage.failed => progress.message ?? 'The build failed.',
        BuildStage.capped => progress.message ?? "Today's builds are taken.",
      };
    }
    return switch (suggestion.status) {
      SuggestionStatus.listed => 'Curated walk',
      SuggestionStatus.ready => 'Built on demand',
      SuggestionStatus.buildable => 'Not built yet',
      SuggestionStatus.unavailable =>
        suggestion.reason ?? 'It cannot be built.',
    };
  }

  /// The slug this tile opens, where it opens at all.
  String? get _opens {
    final BuildProgress? build = progress;
    if (build != null) {
      return build.stage == BuildStage.ready ? build.slug : null;
    }
    return switch (suggestion.status) {
      SuggestionStatus.listed || SuggestionStatus.ready => suggestion.slug,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? opens = _opens;
    final String? gene = suggestion.gene;

    final Widget body = Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      suggestion.title,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (gene != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      gene,
                      style: AppTypography.sequenceSmall(colors.primary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                specOf(suggestion),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sequenceSmall(colors.onSurfaceVariant)
                    .copyWith(fontSize: 11, letterSpacing: 0),
              ),
              const SizedBox(height: 2),
              Text(
                statusOf(suggestion, progress),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _action(context, opens, gene),
      ],
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: opens == null ? null : () => onOpen(opens),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.outline, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _action(BuildContext context, String? opens, String? gene) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BuildProgress? build = progress;
    if (build != null && build.stage.busy) {
      return Semantics(
        label: 'Building',
        child: const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (build != null && build.stage == BuildStage.ready && opens != null) {
      return TextButton(
        onPressed: () => onOpen(opens),
        child: const Text('Open'),
      );
    }
    if (gene != null &&
        suggestion.status == SuggestionStatus.buildable &&
        (build == null || build.stage == BuildStage.failed)) {
      return TextButton(
        onPressed: () => onBuild(gene),
        child: Text(build == null ? 'Build' : 'Try again'),
      );
    }
    if (opens != null) {
      return Icon(
        Icons.chevron_right_rounded,
        size: 24,
        color: colors.onSurfaceVariant,
      );
    }
    return const SizedBox.shrink();
  }
}
