import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../anatomy/sequence_scrubber.dart';
import '../format.dart';
import '../motion/timeline_controller.dart';
import '../motion/transport_bar.dart';
import 'translation_painter.dart';
import 'translation_timeline.dart';

/// The whole coding sequence translated, from the cap to the stop codon.
///
/// Played on the shared transport bar, under the name of the phase on screen,
/// at the pace the caller's [controller] sets, and scrubbed with the walk's
/// own [SequenceScrubber] as a minimap of the mRNA, its landmarks the
/// timeline's own events.
///
/// The caller owns the [controller]. At t = 1 the last frame stands, for the
/// caller to move on from.
class TranslationPlayer extends StatelessWidget {
  const TranslationPlayer({
    required this.translation,
    required this.controller,
    this.canvasKey = const ValueKey<String>('ribosome-canvas'),
    super.key,
  });

  final TranslationTimeline translation;
  final TimelineController controller;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
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
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TransportBar(controller: controller),
        ),
      ],
    );
  }
}
