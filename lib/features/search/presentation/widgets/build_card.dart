import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/catalog/protein_builds.dart';
import '../../../../core/catalog/protein_suggestion.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import 'protein_card.dart';
import 'suggestion_tile.dart';

/// A protein being built on demand, pinned at the top of search while it is:
/// what it is, each step it goes through and where it stands, the residues
/// ESM-2 has scored with the time the scorer says is left, and Open once it
/// is built.
///
/// Every figure is the service's (`BuildReport`); between two answers the
/// clock runs on from the last, and the bar glides at the scorer's own rate,
/// never past the line it prints next. Built, the steps have done their work
/// and the card says how long it took; declined or stopped, the step it ended
/// at says why. The phone that asked may stop it while it is queued or
/// scoring.
class BuildCard extends StatefulWidget {
  const BuildCard({
    required this.job,
    required this.onOpen,
    required this.onBuild,
    required this.onStop,
    super.key,
  });

  final ProteinBuild job;

  /// Opens the walk at a slug.
  final ValueChanged<String> onOpen;

  /// Asks for the build again: after it broke, or to score what was stopped.
  final ValueChanged<ProteinSuggestion> onBuild;

  /// Stops it, once the reader has said so.
  final ValueChanged<ProteinBuild> onStop;

  /// `01:37`, `1:04:52`.
  static String clock(Duration span) {
    final int seconds = math.max(span.inSeconds, 0);
    final String minutes = ((seconds ~/ 60) % 60).toString().padLeft(2, '0');
    final String rest = (seconds % 60).toString().padLeft(2, '0');
    return seconds >= 3600 ? '${seconds ~/ 3600}:$minutes:$rest' : '$minutes:$rest';
  }

  /// `45 s`, `9 min`.
  static String span(Duration span) => span.inSeconds < 60
      ? '${span.inSeconds} s'
      : '${(span.inSeconds / 60).round()} min';

  /// `450 / 838`.
  static String scored(int done, int total) =>
      '${grouped(done)} / ${grouped(total)}';

  /// The scorer prints a line every this many residues (`score_protein.py`),
  /// and the bar never runs further ahead of the last one than that.
  static const int lineEvery = 25;

  /// How long a residue takes, by the scorer's own estimate: the run's whole
  /// length, what it has run and what it says is left, over its residues.
  /// That stays put between two of its lines, where what is left alone runs
  /// down. Null where the report has no estimate.
  static Duration? perResidue(BuildReport report) {
    final int total = report.residues ?? 0;
    final int done = report.scored ?? 0;
    final Duration? left = report.left;
    final Duration? ran = report.ran;
    if (total <= 0 || left == null) {
      return null;
    }
    if (ran != null) {
      return (ran + left) ~/ total;
    }
    return done >= total ? null : left ~/ (total - done);
  }

  /// The residues to show [dt] after [shown]: carried on at
  /// [perResidue], never below the count the scorer gave, never past its
  /// next line nor the last residue.
  static double advance(double shown, BuildReport report, Duration dt) {
    final int done = report.scored ?? 0;
    final int total = report.residues ?? 0;
    final double from = math.max(shown, done.toDouble());
    if (total <= 0 || done >= total) {
      return math.min(from, math.max(total, 0).toDouble());
    }
    final Duration? per = perResidue(report);
    if (per == null || per <= Duration.zero) {
      return from;
    }
    final double next = from + dt.inMicroseconds / per.inMicroseconds;
    return math.min(next, math.min(done + lineEvery, total).toDouble());
  }

  @override
  State<BuildCard> createState() => _BuildCardState();
}

class _BuildCardState extends State<BuildCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_ticked);

  /// The ticker's time now, and when the report on screen was had.
  Duration _now = Duration.zero;
  Duration _had = Duration.zero;

  /// The ticker's time, each frame, for the sheen; and the whole seconds
  /// since the report on screen was had, for the figures.
  final ValueNotifier<Duration> _time = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<int> _seconds = ValueNotifier<int>(0);

  /// The residues the bar shows, and the share of them, each frame.
  double _shown = 0;
  final ValueNotifier<double> _share = ValueNotifier<double>(0);

  ProteinBuild get _job => widget.job;

  bool get _running => _job.stage.underway && _job.report != null;

  @override
  void initState() {
    super.initState();
    _counted(null);
    _follow();
  }

  @override
  void didUpdateWidget(BuildCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.job.report, _job.report)) {
      _had = _now;
      _seconds.value = 0;
      _counted(old.job.report);
    }
    _follow();
  }

  /// A new report: the bar takes up its count, and goes back only for a run
  /// that started over.
  void _counted(BuildReport? was) {
    final BuildReport? report = _job.report;
    final int? done = report?.scored;
    final int? total = report?.residues;
    if (report == null || done == null || total == null || total <= 0) {
      _shown = 0;
      _share.value = 0;
      return;
    }
    final int? before = was?.scored;
    _shown = before == null || done < before ? done.toDouble() : math.max(_shown, done.toDouble());
    _share.value = _shown / total;
  }

  void _follow() {
    if (_running && !_ticker.isActive) {
      unawaited(_ticker.start());
    } else if (!_running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _ticked(Duration elapsed) {
    final Duration dt = elapsed - _now;
    _now = elapsed;
    _time.value = elapsed;
    final int seconds = (elapsed - _had).inSeconds;
    if (seconds != _seconds.value) {
      _seconds.value = seconds;
    }
    final BuildReport? report = _job.report;
    final int? total = report?.residues;
    if (report != null && total != null && total > 0 && report.scored != null &&
        !MediaQuery.disableAnimationsOf(context)) {
      _shown = BuildCard.advance(_shown, report, dt);
      _share.value = _shown / total;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _seconds.dispose();
    _share.dispose();
    super.dispose();
  }

  Future<void> _confirmStop() async {
    final ProteinBuild job = _job;
    final BuildReport? report = job.report;
    final Duration? ran = report?.ran;
    final String lost = report?.step == BuildStep.queued
        ? 'Nothing has been built yet.'
        : ran == null
        ? 'ESM-2 has not started; its gene record stays.'
        : '${BuildCard.span(ran)} of ESM-2 scoring is lost.';
    final bool? stop = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Stop ${job.gene}?'),
        content: Text(lost),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep building'),
          ),
          // The one of the two that loses work, and so the one marked.
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if ((stop ?? false) && mounted) {
      widget.onStop(_job);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final ProteinBuild job = _job;
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
                style: AppTypography.spec(colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _action(opens, report),
      ],
    );

    final bool built = job.stage == BuildStage.ready && report?.reason == null;
    final List<Widget> body = <Widget>[
      if (report == null || built)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            _line(report),
            style: theme.cardBody,
          ),
        )
      else ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        _Steps(
          job: job,
          report: report,
          bar: (BuildReport measured) => _LiveBar(
            report: measured,
            share: _share,
            time: _time,
            seconds: _seconds,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _footer(theme, report),
      ],
    ];

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: opens == null ? null : () => widget.onOpen(opens),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: ProteinCard.surface(colors),
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
      return 'Built in ${BuildCard.span(report.elapsed)}';
    }
    return switch (_job.stage) {
      BuildStage.asking => 'Asking the service',
      BuildStage.building => 'Building',
      BuildStage.ready => 'Built, ready to walk',
      BuildStage.refused => _job.message ?? 'The service declined to build it.',
      BuildStage.failed => _job.message ?? 'The build failed.',
      BuildStage.capped => _job.message ?? "Today's builds are taken.",
      BuildStage.stopped => 'Stopped',
    };
  }

  /// Under the steps: the time since it was asked for, running, while it is
  /// under way; how long it took once built; how long it ran once stopped,
  /// with what can be done next.
  Widget _footer(ThemeData theme, BuildReport report) {
    final ProteinBuild job = _job;
    final TextStyle? style = theme.caption;
    if (job.stage == BuildStage.stopped) {
      final String? slug = job.opens ? job.slug : null;
      return Row(
        children: <Widget>[
          Expanded(
            child: Text('Stopped after ${BuildCard.span(report.elapsed)}', style: style),
          ),
          if (slug != null)
            TextButton(onPressed: () => widget.onOpen(slug), child: const Text('Open')),
          TextButton(
            onPressed: () => widget.onBuild(job.protein),
            child: const Text('Build'),
          ),
        ],
      );
    }
    if (job.stage == BuildStage.ready) {
      return Text('Built in ${BuildCard.span(report.elapsed)}', style: style);
    }
    if (!job.stage.underway) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: _seconds,
      builder: (BuildContext context, int seconds, Widget? child) {
        final Duration? still = job.unchangedFor;
        return Text(
          <String>[
            '${BuildCard.clock(report.elapsed + Duration(seconds: seconds))} elapsed',
            if (still != null) 'no change for ${still.inMinutes} min',
            if (job.unheard) 'the service is not answering',
          ].join(' · '),
          style: style,
        );
      },
    );
  }

  Widget _action(String? opens, BuildReport? report) {
    final ProteinBuild job = _job;
    if (opens != null) {
      return TextButton(onPressed: () => widget.onOpen(opens), child: const Text('Open'));
    }
    if (job.stage == BuildStage.failed) {
      return TextButton(
        onPressed: () => widget.onBuild(job.protein),
        child: const Text('Try again'),
      );
    }
    if (job.stopping) {
      return const TextButton(onPressed: null, child: Text('Stopping'));
    }
    if (job.stoppable) {
      return TextButton(onPressed: _confirmStop, child: const Text('Stop'));
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

/// The five steps a build goes through, each marked where it stands, and its
/// fold beside them where the service makes one.
class _Steps extends StatelessWidget {
  const _Steps({required this.job, required this.report, required this.bar});

  final ProteinBuild job;
  final BuildReport report;

  /// The residues bar, for the step that counts them.
  final Widget Function(BuildReport report) bar;

  static const List<(BuildStep, String)> _shown = <(BuildStep, String)>[
    (BuildStep.queued, 'Queued'),
    (BuildStep.record, 'Gene record'),
    (BuildStep.evidence, 'AlphaGenome and ClinVar'),
    (BuildStep.scoring, 'ESM-2 650M'),
    (BuildStep.check, 'Alignment check'),
  ];

  /// The step the report is at ended without its result: the request was
  /// declined or broke, the ESM-2 track was not made, or it was stopped.
  bool get _declined =>
      job.stage == BuildStage.refused ||
      job.stage == BuildStage.failed ||
      job.stage == BuildStage.stopped ||
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
    final TrackState? fold = report.fold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (BuildStep step, String title) in _shown) ...<Widget>[
          _StepRow(
            title: title,
            mark: _markOf(step),
            detail: _detail(step, _markOf(step)),
            // The transcript is an accession, set as the app sets them.
            accession: step == BuildStep.record,
            counted: step == BuildStep.scoring &&
                    _markOf(step) == _Mark.active &&
                    report.fraction != null
                ? bar(report)
                : null,
            reason: _markOf(step) == _Mark.declined
                ? report.reason ?? job.message
                : null,
          ),
          // Its fold is made once its record is, beside the rest: marked by
          // its own state, and not shown where none is made.
          if (step == BuildStep.record && fold != null)
            _StepRow(title: 'Structure', mark: _foldMark(fold)),
        ],
      ],
    );
  }

  static _Mark _foldMark(TrackState fold) => switch (fold) {
    TrackState.pending => _Mark.active,
    TrackState.refused => _Mark.declined,
    TrackState.ready || TrackState.absent => _Mark.done,
  };

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
    this.counted,
    this.reason,
  });

  final String title;
  final _Mark mark;
  final String? detail;

  /// Whether [detail] is an accession, set in the sequence face.
  final bool accession;

  /// The residues counted under it, where this step counts them.
  final Widget? counted;

  /// Why this step ended without its result.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? titleStyle = theme.cardBody?.copyWith(
      color: mark == _Mark.waiting ? colors.onSurfaceVariant : colors.onSurface,
    );
    final Widget? bar = counted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 18,
            child: Center(child: _icon(context, bar != null)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // Wraps rather than overflows: "AlphaGenome and ClinVar"
                    // is longer than a narrow card allows at a large text size.
                    Flexible(child: Text(title, style: titleStyle)),
                    if (detail case final String detail) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: accession
                              ? AppTypography.sequenceSmall(colors.onSurfaceVariant)
                              : theme.caption,
                        ),
                      ),
                    ],
                  ],
                ),
                if (bar != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  bar,
                ],
                if (reason case final String reason) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(reason, style: theme.caption),
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

/// The residues scored, as a bar that glides between the scorer's lines with
/// a sheen running along it, and beneath it the count the scorer gave and the
/// time it says is left, running down.
class _LiveBar extends StatelessWidget {
  const _LiveBar({
    required this.report,
    required this.share,
    required this.time,
    required this.seconds,
  });

  final BuildReport report;

  /// The share of residues the bar shows, each frame.
  final ValueListenable<double> share;

  /// The ticker's time, each frame, for the sheen.
  final ValueListenable<Duration> time;

  /// Whole seconds since the report was had, for the time left.
  final ValueListenable<int> seconds;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int done = report.scored!;
    final int total = report.residues!;
    final bool still = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          container: true,
          label: 'ESM-2, $done of $total residues scored',
          excludeSemantics: true,
          child: SizedBox(
            height: 4,
            child: CustomPaint(
              painter: _BarPainter(
                share: share,
                time: time,
                still: still,
                track: colors.surfaceContainerHighest,
                fill: colors.primary,
                sheen: colors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Text(
              BuildCard.scored(done, total),
              style: AppTypography.spec(colors.onSurfaceVariant),
            ),
            const Spacer(),
            if (report.left case final Duration left)
              ValueListenableBuilder<int>(
                valueListenable: seconds,
                builder: (BuildContext context, int seconds, Widget? child) => Text(
                  '${BuildCard.clock(left - Duration(seconds: seconds))} left',
                  style: theme.caption,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.share,
    required this.time,
    required this.still,
    required this.track,
    required this.fill,
    required this.sheen,
  }) : super(repaint: Listenable.merge(<Listenable>[share, time]));

  final ValueListenable<double> share;
  final ValueListenable<Duration> time;

  /// Reduced motion: the reported count, and no sheen.
  final bool still;

  final Color track;
  final Color fill;
  final Color sheen;

  /// One pass of the sheen along the fill.
  static const Duration _sweep = Duration(milliseconds: 1800);

  @override
  void paint(Canvas canvas, Size size) {
    final Radius round = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, round),
      Paint()..color = track,
    );
    final double width = size.width * share.value.clamp(0.0, 1.0);
    if (width <= 0) {
      return;
    }
    final RRect filled = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, size.height),
      round,
    );
    canvas.drawRRect(filled, Paint()..color = fill);
    if (still) {
      return;
    }
    // A soft band of light crossing the fill, so a bar at 1% still lives.
    final double band = math.max(size.width * 0.12, 24);
    final double phase = (time.value.inMicroseconds % _sweep.inMicroseconds) /
        _sweep.inMicroseconds;
    final double left = -band + phase * (width + band);
    canvas.save();
    canvas.clipRRect(filled);
    canvas.drawRect(
      Rect.fromLTWH(left, 0, band, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            sheen.withValues(alpha: 0),
            sheen.withValues(alpha: 0.35),
            sheen.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(left, 0, band, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      !identical(old.share, share) ||
      old.still != still ||
      old.track != track ||
      old.fill != fill ||
      old.sheen != sheen;
}
