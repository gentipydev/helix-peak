import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../shared/anatomy/anatomy_layout.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/ribosome/caption_generator.dart';
import '../../../../shared/ribosome/director.dart';
import '../../../../shared/ribosome/translation_flight.dart';
import '../../../../shared/ribosome/translation_painter.dart';
import '../../../../shared/ribosome/translation_player.dart';
import '../../../../shared/ribosome/translation_timeline.dart';
import '../../../../shared/share/frame_renderer.dart';

/// The ribosome as the walk plays it from the transcript page: the record's
/// whole translation on the shared [TranslationPlayer], and then the chain it
/// made flying into its cells on the protein page, which is the walk's own.
///
/// It holds the clocks and where the chain sets off from, and nothing of the
/// walk: the screen says where the player stands, turns to the protein page
/// under the flight and lets go of this once the chain has landed.
final class WalkRibosome {
  WalkRibosome._({
    required this.timeline,
    required this.director,
    required this.captions,
    required this.controller,
    required this.flight,
  });

  /// [model] must be [TranslationTimeline.translatable].
  factory WalkRibosome({
    required TickerProvider vsync,
    required AnatomyModel model,
  }) {
    final TranslationTimeline timeline = TranslationTimeline.of(model);
    final TranslationDirector director = TranslationDirector(timeline);
    return WalkRibosome._(
      timeline: timeline,
      director: director,
      captions: CaptionGenerator(timeline, model.record),
      controller: TimelineController(
        vsync: vsync,
        timeline: timeline,
        beat: TranslationPlayer.beat,
        speedCurve: director.curve,
      ),
      flight: AnimationController(
        vsync: vsync,
        duration: TranslationFlightPainter.duration,
      ),
    );
  }

  final TranslationTimeline timeline;
  final TranslationDirector director;
  final CaptionGenerator captions;
  final TimelineController controller;

  /// The chain's flight into the protein page's cells.
  final AnimationController flight;

  /// How long one beat takes in a shared clip, before the clip is held to
  /// its five to fifteen seconds.
  static const Duration clipBeat = Duration(milliseconds: 120);

  /// How long the clip of the whole translation runs, before it is held.
  Duration get clipDuration => clipBeat * timeline.beats;

  /// The translation as a clip: the player's own painter, paced by the same
  /// director, so a clip lingers where the player does.
  FramePainter clip(BuildContext context) {
    final TranslationInks inks = TranslationInks.of(context);
    return (double wall) => TranslationPainter(
      timeline: timeline,
      at: () => director.curve.tAt(wall),
      inks: inks,
    );
  }

  /// The player's canvas, so the chain sets off from where it was drawn.
  final GlobalKey canvasKey = GlobalKey();

  /// Where each residue sets off from, once translation has ended; null while
  /// it plays.
  List<Offset?>? _starts;
  double _startRadius = TranslationPainter.residueRadius;

  /// Whether translation has ended and the chain is on its way to its cells.
  bool get flying => _starts != null;

  /// Takes the chain off the player's canvas as its last frame drew it, moved
  /// by [offset] into the frame of the page it lands on.
  void setOff(Offset offset) {
    final Size size = canvasKey.currentContext?.size ?? Size.zero;
    _startRadius =
        TranslationPainter.residueRadius *
        TranslationPainter.viewportScale(size);
    _starts = <Offset?>[
      for (final Offset? at in TranslationPainter.chainPositions(
        size,
        timeline.stateAt(1),
      ))
        at == null ? null : at + offset,
    ];
  }

  /// The chain flying into [stage]'s cells, laid out as the walk lays that
  /// page out at rest in [viewport].
  Widget flightInto(AnatomyStage stage, Size viewport) {
    final AnatomyLayout layout = AnatomyLayout.forStage(
      stage,
      Size(
        viewport.width,
        math.max(viewport.height, AnatomyLayout.heightFor(stage, viewport)),
      ),
      viewport,
    );
    return AnimatedBuilder(
      animation: flight,
      builder: (BuildContext context, _) => CustomPaint(
        key: const ValueKey<String>('walk-ribosome-flight'),
        size: viewport,
        painter: TranslationFlightPainter(
          starts: _starts ?? const <Offset?>[],
          layout: layout,
          letters: stage.letters,
          progress: flight.value,
          startRadius: _startRadius,
          anatomy: context.anatomyColors,
          ground: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  void dispose() {
    controller.dispose();
    flight.dispose();
  }
}
