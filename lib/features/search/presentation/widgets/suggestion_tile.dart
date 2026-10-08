import 'package:flutter/material.dart';

import '../../../../core/catalog/protein_builds.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';

/// One protein from every reviewed human protein, below the curated list:
/// what it is called, its gene, its length, and what the app can do with it.
///
/// A protein that opens (curated, or built earlier) is tapped like a card. One
/// that can be built offers to be; asked, its build goes to the top of search
/// (`BuildCard`) until it is opened, and comes back here as what it became.
/// One that cannot be built says why, in the service's words.
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    required this.suggestion,
    required this.onOpen,
    required this.onBuild,
    this.built,
    super.key,
  });

  final ProteinSuggestion suggestion;

  /// This protein's build, once it has ended and left the top of search.
  final ProteinBuild? built;

  /// Opens the walk at a slug.
  final ValueChanged<String> onOpen;

  /// Asks for it to be built.
  final ValueChanged<ProteinSuggestion> onBuild;

  /// `P38398 · 1,863 aa`.
  static String specOf(ProteinSuggestion suggestion) =>
      '${suggestion.uniprot} · ${grouped(suggestion.length)} aa';

  /// The line under the name: where it stands, in words.
  static String statusOf(ProteinSuggestion suggestion, ProteinBuild? built) {
    if (built != null) {
      return switch (built.stage) {
        BuildStage.ready => 'Built on demand',
        BuildStage.asking || BuildStage.building => 'Building',
        BuildStage.refused =>
          built.message ?? 'The service declined to build it.',
        BuildStage.failed => built.message ?? 'The build failed.',
        BuildStage.capped => built.message ?? "Today's builds are taken.",
      };
    }
    if (suggestion.building) {
      return 'Building';
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
    final ProteinBuild? build = built;
    if (build != null) {
      return build.stage == BuildStage.ready ? build.slug : null;
    }
    if (suggestion.building) {
      return null;
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
                statusOf(suggestion, built),
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
        _action(context, opens),
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

  Widget _action(BuildContext context, String? opens) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ProteinBuild? build = built;
    if (suggestion.gene != null &&
        suggestion.status == SuggestionStatus.buildable &&
        !suggestion.building &&
        (build == null || build.stage == BuildStage.failed)) {
      return TextButton(
        onPressed: () => onBuild(suggestion),
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
