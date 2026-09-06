import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/nucleotide_colors.dart';
import 'dna_helix_painter.dart';
import 'helix_geometry.dart';

/// The rotating double helix on the home screen, with RNA polymerases
/// transcribing it.
///
/// Owns the animation lifecycle and the precomputed geometry; all drawing
/// lives in [DnaHelixPainter]. Everything here is slow on purpose — this is
/// ambient, an instrument idling in a lab, and it must not read as a loading
/// spinner. If it looks like something is happening urgently, it is too fast.
class DnaHelix extends StatefulWidget {
  const DnaHelix({
    super.key,
    this.radius = HelixModel.defaultRadius,
    this.pitch = HelixModel.defaultPitch,
    this.rotationDuration = defaultRotationDuration,
    this.rungCount = HelixModel.defaultRungCount,
  });

  /// Radius of the cylinder the backbones wind around, in logical pixels.
  final double radius;

  /// Rise per full revolution, in logical pixels. With [radius] this sets how
  /// stretched or squat the helix looks.
  final double pitch;

  /// Time for one full revolution.
  final Duration rotationDuration;

  /// Base pairs in the model.
  ///
  /// At B-DNA's 10.5 base pairs per turn the default is a column roughly twice
  /// a phone's height, so the helix runs off the top and bottom of the frame
  /// and fades out. That is deliberate: it reads as a section of a longer
  /// molecule rather than an object floating in a box.
  final int rungCount;

  /// One full revolution. Inside the 20-30 second band that reads as ambient.
  static const Duration defaultRotationDuration = Duration(seconds: 24);

  @override
  State<DnaHelix> createState() => _DnaHelixState();
}

class _DnaHelixState extends State<DnaHelix> with TickerProviderStateMixin {
  /// A second, far slower cycle driving a faint vertical drift, so the
  /// structure feels alive rather than mechanically looping. Deliberately not
  /// a multiple of the rotation period — the two only realign every few
  /// minutes, which is long enough that the loop is never visible.
  static const Duration _driftPeriod = Duration(seconds: 70);

  /// One polymerase's traversal of the whole molecule.
  ///
  /// The model is about twice the height of the viewport, so a full traversal
  /// spends well under half its time on screen. Two enzymes half a cycle apart
  /// come off this one controller, which is both what keeps the frame occupied
  /// and what a real gene looks like — transcription is not a solo act.
  static const Duration _transcriptionPeriod = Duration(seconds: 45);

  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: widget.rotationDuration,
  );

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: _driftPeriod,
  );

  late final AnimationController _transcription = AnimationController(
    vsync: this,
    duration: _transcriptionPeriod,
  );

  /// Handed to the painter as its repaint signal, so the tickers drive the
  /// canvas directly and this widget never rebuilds for a frame.
  late final Listenable _repaint = Listenable.merge(
    <Listenable>[_rotation, _drift, _transcription],
  );

  late HelixModel _model = _buildModel();

  HelixModel _buildModel() => HelixModel(
        radius: widget.radius,
        pitch: widget.pitch,
        rungCount: widget.rungCount,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Checked here rather than in initState: MediaQuery is not available
    // during initState, and the accessibility setting can be toggled while the
    // app is running.
    if (MediaQuery.disableAnimationsOf(context)) {
      // A composed still frame rather than a stalled animation: a
      // three-quarter view, with a polymerase parked mid-frame, its bubble
      // open and a length of transcript already run off. The static frame is
      // stronger than the moving one is at any single instant, because the
      // angle and the enzyme's position were both chosen rather than sampled.
      _rotation
        ..stop()
        ..value = HelixModel.staticRotationTurns;
      _drift
        ..stop()
        ..value = 0.5;
      _transcription
        ..stop()
        ..value = HelixModel.staticTranscriptionTurns;
    } else {
      if (!_rotation.isAnimating) {
        unawaited(_rotation.repeat());
      }
      if (!_drift.isAnimating) {
        unawaited(_drift.repeat(reverse: true));
      }
      if (!_transcription.isAnimating) {
        unawaited(_transcription.repeat());
      }
    }
  }

  @override
  void didUpdateWidget(DnaHelix oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rotationDuration != oldWidget.rotationDuration) {
      _rotation.duration = widget.rotationDuration;
      if (_rotation.isAnimating) {
        unawaited(_rotation.repeat());
      }
    }

    // The model is the expensive part, so it is rebuilt only when the geometry
    // it was derived from actually changed. build() runs straight after this,
    // so no setState is needed.
    if (widget.radius != oldWidget.radius ||
        widget.pitch != oldWidget.pitch ||
        widget.rungCount != oldWidget.rungCount) {
      _model = _buildModel();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    _drift.dispose();
    _transcription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NucleotideColors bases = context.nucleotideColors;

    return Semantics(
      label: 'Illustration of a slowly rotating DNA double helix, '
          'with RNA polymerases transcribing it',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: CustomPaint(
          // Constructed here, not per frame: the painter repaints from the
          // animations directly, so this build method runs only when the theme
          // or the widget's parameters change.
          painter: DnaHelixPainter(
            repaint: _repaint,
            rotation: _rotation,
            drift: _drift,
            transcription: _transcription,
            model: _model,
            backbone: theme.colorScheme.onSurfaceVariant,
            adenine: bases.adenine,
            thymine: bases.thymine,
            guanine: bases.guanine,
            cytosine: bases.cytosine,
            // The transcript is the product of the reaction, so it carries the
            // app's one accent. Nothing else on this screen competes for it.
            transcript: theme.colorScheme.primary,
            background: theme.colorScheme.surface,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
