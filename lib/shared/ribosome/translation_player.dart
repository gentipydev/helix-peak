import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../anatomy/sequence_scrubber.dart';
import '../format.dart';
import '../motion/timeline_controller.dart';
import '../motion/transport_bar.dart';
import 'caption_generator.dart';
import 'director.dart';
import 'translation_painter.dart';
import 'translation_timeline.dart';

/// The whole coding sequence translated, from the cap to the stop codon.
///
/// Played on the shared transport bar, paced by the [TranslationDirector]
/// (slow where something happens once, fast in between) beside a cell-time
/// readout that never warps, and scrubbed with the walk's own
/// [SequenceScrubber] as a minimap of the mRNA, its landmarks the timeline's
/// own events. A caption, built from the record by the [CaptionGenerator],
/// says what is happening; where none can be built, none is shown.
///
/// The caller owns the [controller], and says with [ending] what takes the
/// canvas's place once translation is over.
class TranslationPlayer extends StatelessWidget {
  const TranslationPlayer({
    required this.translation,
    required this.director,
    required this.captions,
    required this.controller,
    this.ending,
    this.canvasKey = const ValueKey<String>('ribosome-canvas'),
    super.key,
  });

  final TranslationTimeline translation;
  final TranslationDirector director;
  final CaptionGenerator captions;
  final TimelineController controller;

  /// Drawn in place of the canvas and its minimap once `t` reaches 1, or null
  /// to leave the last frame standing.
  final WidgetBuilder? ending;

  /// The canvas's key. A caller that needs the canvas's box passes a
  /// [GlobalKey].
  final Key canvasKey;

  /// How long one beat takes at speed 1, where the director plays slowly.
  static const Duration beat = Duration(milliseconds: 1200);

  /// The minimap's landmarks: the moments the timeline itself names.
  static List<(double, String)> _landmarks(TranslationTimeline translation) {
    final List<(double, String)> marks = <(double, String)>[
      (translation.beatStart(TranslationTimeline.scanBeats), 'Start codon'),
      for (final ({int junction, double t}) passed in translation.ejcKnockoff)
        (passed.t, 'Exon junction'),
      if (translation.firstExit case final double exit)
        (exit, 'First residue out'),
      if (translation.srpWindow case (final double opens, _))
        (opens, 'Signal peptide out'),
      (translation.beatStart(translation.firstTerminationBeat), 'Stop codon'),
    ];
    return marks
      ..sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? playing) =>
                controller.t >= 1 && ending != null
                ? ending!(context)
                : playing!,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (BuildContext context, Widget? painted) =>
                        Semantics(
                          label: TranslationPainter.describe(
                            translation,
                            translation.stateAt(controller.t),
                          ),
                          child: painted,
                        ),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: canvasKey,
                        size: Size.infinite,
                        painter: TranslationPainter(
                          timeline: translation,
                          at: () => controller.t,
                          inks: TranslationInks.of(context),
                          repaint: controller,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: SequenceScrubber.width,
                  child: TimelineScrubber(
                    controller: controller,
                    landmarks: _landmarks(translation),
                    labelAt: (double t) {
                      final TranslationState s = translation.stateAt(t);
                      return s.codon <= translation.protein.length
                          ? 'Codon ${grouped(s.codon)}'
                          : 'Stop codon';
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, _) {
            final TranslationState state = translation.stateAt(controller.t);
            final String? caption = captions.captionFor(state);
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: 88,
                    child: caption == null
                        ? null
                        : Text(
                            caption,
                            key: const ValueKey<String>('ribosome-caption'),
                            style: theme.textTheme.bodyMedium,
                            maxLines: 4,
                            overflow: TextOverflow.fade,
                          ),
                  ),
                  Text(
                    'In a cell: '
                    '${director.cellSeconds(state).toStringAsFixed(1)} s of '
                    '${director.cellTotal.toStringAsFixed(1)} s, at '
                    '${TranslationDirector.residuesPerSecond} residues a '
                    'second',
                    key: const ValueKey<String>('ribosome-cell-time'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TransportBar(controller: controller),
        ),
      ],
    );
  }
}
