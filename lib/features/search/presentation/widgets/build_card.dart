import 'package:flutter/material.dart';

import '../../../../core/catalog/protein_builds.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import 'suggestion_tile.dart';

/// A protein being built on demand, pinned at the top of search while it is:
/// what it is, each step it goes through and where it stands, the residues
/// ESM-2 has scored with the time the scorer says is left, and Open once it
/// is built.
///
/// Every figure is the service's (`BuildReport`). Built, the steps have done
/// their work and the card says how long it took; declined, the step that
/// declined says why.
class BuildCard extends StatelessWidget {
  const BuildCard({
    required this.job,
    required this.onOpen,
    required this.onRetry,
    super.key,
  });

  final ProteinBuild job;

  /// Opens the walk at a slug.
  final ValueChanged<String> onOpen;

  /// Asks for the build again, after it broke.
  final ValueChanged<ProteinSuggestion> onRetry;

  /// `Asked 40 s ago`, `Asked 5 min ago`.
  static String asked(Duration elapsed) => elapsed.inSeconds < 60
      ? 'Asked ${elapsed.inSeconds} s ago'
      : 'Asked ${elapsed.inMinutes} min ago';

  /// `Built in 45 s`, `Built in 9 min`.
  static String took(Duration elapsed) => elapsed.inSeconds < 60
      ? 'Built in ${elapsed.inSeconds} s'
      : 'Built in ${(elapsed.inSeconds / 60).round()} min';

  /// `< 1 min left`, `4 min left`.
  static String left(Duration left) => left.inSeconds < 60
      ? '< 1 min left'
      : '${(left.inSeconds / 60).round()} min left';

  /// `450 / 838`.
  static String scored(int done, int total) =>
      '${grouped(done)} / ${grouped(total)}';

  /// The card's small print, in the app's own face: the theme defines no
  /// `bodySmall`, and Material's would set it in the platform's.
  static TextStyle? small(ThemeData theme) => theme.textTheme.bodyMedium?.copyWith(
    fontSize: 12,
    height: 1.35,
    color: theme.colorScheme.onSurfaceVariant,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final ProteinSuggestion protein = job.protein;
    final BuildReport? report = job.report;
    final String? opens = job.stage == BuildStage.ready ? job.slug : null;

    final Widget header = Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      protein.title,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    job.gene,
                    style: AppTypography.sequenceSmall(colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                SuggestionTile.specOf(protein),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sequenceSmall(colors.onSurfaceVariant)
                    .copyWith(fontSize: 11, letterSpacing: 0),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _action(context, opens, report),
      ],
    );

    final bool built = job.stage == BuildStage.ready && report?.reason == null;
    final List<Widget> body = <Widget>[
      if (report == null || built)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            _line(report),
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.35),
          ),
        )
      else ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        _Steps(job: job, report: report),
        if (_footer(report) case final String footer) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            footer,
            style: BuildCard.small(theme),
          ),
        ],
      ],
    ];

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[header, ...body],
          ),
        ),
      ),
    );
  }

  /// The one line a card with no steps to show carries.
  String _line(BuildReport? report) {
    if (report != null) {
      return took(report.elapsed);
    }
    return switch (job.stage) {
      BuildStage.asking => 'Asking the service',
      BuildStage.building => 'Building',
      BuildStage.ready => 'Built, ready to walk',
      BuildStage.refused => job.message ?? 'The service declined to build it.',
      BuildStage.failed => job.message ?? 'The build failed.',
      BuildStage.capped => job.message ?? "Today's builds are taken.",
    };
  }

  /// Under the steps: since when, while it is under way, and how long it
  /// took once built.
  String? _footer(BuildReport report) {
    if (job.stage == BuildStage.ready) {
      return took(report.elapsed);
    }
    if (!job.stage.underway) {
      return null;
    }
    final Duration? still = job.unchangedFor;
    return <String>[
      asked(report.elapsed),
      if (still != null) 'no change for ${still.inMinutes} min',
      if (job.unheard) 'the service is not answering',
    ].join(' · ');
  }

  Widget _action(BuildContext context, String? opens, BuildReport? report) {
    if (opens != null) {
      return TextButton(onPressed: () => onOpen(opens), child: const Text('Open'));
    }
    if (job.stage == BuildStage.failed) {
      return TextButton(
        onPressed: () => onRetry(job.protein),
        child: const Text('Try again'),
      );
    }
    if (report == null && job.stage.underway) {
      return Semantics(
        label: 'Building',
        child: const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

enum _Mark { waiting, active, done, declined }

/// The four steps a build goes through, each marked where it stands.
class _Steps extends StatelessWidget {
  const _Steps({required this.job, required this.report});

  final ProteinBuild job;
  final BuildReport report;

  static const List<(BuildStep, String)> _shown = <(BuildStep, String)>[
    (BuildStep.queued, 'Queued'),
    (BuildStep.record, 'Gene record'),
    (BuildStep.scoring, 'ESM-2 650M'),
    (BuildStep.check, 'Alignment check'),
  ];

  /// The step the report is at ended without its result: the request was
  /// declined or broke, or the ESM-2 track was not made.
  bool get _declined =>
      job.stage == BuildStage.refused ||
      job.stage == BuildStage.failed ||
      (job.stage == BuildStage.ready && report.reason != null);

  _Mark _markOf(BuildStep step) {
    final int at = report.step.index;
    if (step.index < at || report.step == BuildStep.done) {
      return _Mark.done;
    }
    if (step.index > at) {
      return _Mark.waiting;
    }
    return _declined ? _Mark.declined : _Mark.active;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (BuildStep step, String title) in _shown)
          _StepRow(
            title: title,
            mark: _markOf(step),
            detail: _detail(step, _markOf(step)),
            // The transcript is an accession, set as the app sets them.
            accession: step == BuildStep.record,
            measured: step == BuildStep.scoring && _markOf(step) == _Mark.active
                ? report
                : null,
            reason: _markOf(step) == _Mark.declined
                ? report.reason ?? job.message
                : null,
          ),
      ],
    );
  }

  /// What sits beside a step's name: the data it has, where it has any.
  String? _detail(BuildStep step, _Mark mark) {
    switch ((step, mark)) {
      case (BuildStep.queued, _Mark.active):
        return _turn(report.ahead);
      case (BuildStep.record, _Mark.done):
        return report.transcript;
      case (BuildStep.scoring, _Mark.active) when report.scored == null:
        return report.ahead != null ? _turn(report.ahead) : 'Loading the model';
      default:
        return null;
    }
  }

  static String? _turn(int? ahead) => switch (ahead) {
    null => null,
    0 => 'Next',
    1 => '1 protein ahead',
    final int n => '$n proteins ahead',
  };
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.mark,
    this.detail,
    this.accession = false,
    this.measured,
    this.reason,
  });

  final String title;
  final _Mark mark;
  final String? detail;

  /// Whether [detail] is an accession, set in the sequence face.
  final bool accession;

  /// The report, where this step has residues to count.
  final BuildReport? measured;

  /// Why this step ended without its result.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.35,
      color: mark == _Mark.waiting ? colors.onSurfaceVariant : colors.onSurface,
    );
    final BuildReport? report = measured;
    final double? fraction = report?.fraction;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 18,
            child: Center(child: _icon(context, fraction != null)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(title, style: titleStyle),
                    if (detail case final String detail) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: accession
                              ? AppTypography.sequenceSmall(colors.onSurfaceVariant)
                              : BuildCard.small(theme),
                        ),
                      ),
                    ],
                  ],
                ),
                if (report != null && fraction != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  _Bar(fraction: fraction, report: report),
                ],
                if (reason case final String reason) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: BuildCard.small(theme),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(BuildContext context, bool measuring) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    switch (mark) {
      case _Mark.done:
        return Icon(Icons.check_rounded, size: 16, color: colors.primary);
      case _Mark.declined:
        return Icon(Icons.close_rounded, size: 16, color: colors.onSurfaceVariant);
      case _Mark.waiting:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.onSurfaceVariant),
          ),
        );
      case _Mark.active:
        // A bar already moves under a step that is counting; a step that
        // cannot be measured turns, where motion is wanted.
        if (measuring || MediaQuery.disableAnimationsOf(context)) {
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primary),
          );
        }
        return const SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );
    }
  }
}

/// The residues scored, as a bar that glides to each new count, with the
/// count and the time the scorer says is left beneath it.
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.report});

  final double fraction;
  final BuildReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int done = report.scored!;
    final int total = report.residues!;
    final Duration? remaining = report.left;
    final String count = BuildCard.scored(done, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: fraction),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (BuildContext context, double value, Widget? child) =>
              LinearProgressIndicator(
                value: value,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: colors.surfaceContainerHighest,
                // The value stays the bar's own percentage, which is all a
                // progress bar's semantics may carry; the count is in words.
                semanticsLabel: 'ESM-2, $done of $total residues scored',
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Text(
              count,
              style: AppTypography.sequenceSmall(colors.onSurfaceVariant)
                  .copyWith(fontSize: 11, letterSpacing: 0),
            ),
            const Spacer(),
            if (remaining != null)
              Text(
                BuildCard.left(remaining),
                style: BuildCard.small(theme),
              ),
          ],
        ),
      ],
    );
  }
}
