import 'package:flutter/material.dart';

import '../../../../core/catalog/protein_builds.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import 'protein_card.dart';

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
    this.heading,
    super.key,
  });

  final ProteinSuggestion suggestion;

  /// This protein's build, once it has ended and left the top of search.
  final ProteinBuild? built;

  /// Opens the walk at a slug.
  final ValueChanged<String> onOpen;

  /// Asks for it to be built, or a stopped one scored again. Null offers
  /// neither: a list of what is built opens each one, and asking again is
  /// search's.
  final ValueChanged<ProteinSuggestion>? onBuild;

  /// The name of the list it is in, where that says what it is: a status line
  /// that would only repeat it is left out ("Built on demand" under the tab of
  /// that name), and one that says something else stays. Null, the default,
  /// shows every status line.
  final String? heading;

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
        BuildStage.stopped => built.opens
            ? 'Stopped before ESM-2 finished'
            : 'Stopped before it was built',
      };
    }
    if (suggestion.building) {
      return 'Building';
    }
    if (suggestion.stopped) {
      return 'Stopped before ESM-2 finished';
    }
    return switch (suggestion.status) {
      SuggestionStatus.listed => 'Curated walk',
      SuggestionStatus.ready => 'Built on demand',
      SuggestionStatus.buildable => 'Not built yet',
      SuggestionStatus.unavailable =>
        suggestion.reason ?? 'It cannot be built.',
    };
  }

  /// The slug [suggestion] opens at, where it opens at all; [built] is its
  /// build, as for [statusOf]. Search's Search key reads the same rule.
  static String? opensAt(ProteinSuggestion suggestion, ProteinBuild? built) {
    if (built != null) {
      return built.opens ? built.slug : null;
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
    final String? opens = opensAt(suggestion, built);
    final String? gene = suggestion.gene;
    final String status = statusOf(suggestion, built);

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
                style: AppTypography.spec(colors.onSurfaceVariant),
              ),
              if (status != heading) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.cardBody,
                ),
              ],
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
          decoration: ProteinCard.surface(colors),
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
    // Never built, or stopped: Build asks for what is missing, a stopped
    // protein's ESM-2 scores included.
    final bool stopped = build?.stage == BuildStage.stopped ||
        (build == null && suggestion.stopped);
    final ValueChanged<ProteinSuggestion>? ask = onBuild;
    if (ask != null &&
        suggestion.gene != null &&
        !suggestion.building &&
        (stopped ||
            (suggestion.status == SuggestionStatus.buildable &&
                (build == null || build.stage == BuildStage.failed)))) {
      return TextButton(
        onPressed: () => ask(suggestion),
        child: Text(build?.stage == BuildStage.failed ? 'Try again' : 'Build'),
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
