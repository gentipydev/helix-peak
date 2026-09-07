import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/nucleotide_colors.dart';
import 'dna_helix_painter.dart';
import 'helix_geometry.dart';

class DnaHelix extends StatefulWidget {
  const DnaHelix({
    super.key,
    this.radius = HelixModel.defaultRadius,
    this.pitch = HelixModel.defaultPitch,
    this.rotationDuration = defaultRotationDuration,
    this.rungCount = HelixModel.defaultRungCount,
  });

  final double radius;

  final double pitch;

  final Duration rotationDuration;

  final int rungCount;

  static const Duration defaultRotationDuration = Duration(seconds: 24);

  @override
  State<DnaHelix> createState() => _DnaHelixState();
}

class _DnaHelixState extends State<DnaHelix> with TickerProviderStateMixin {
  static const Duration _driftPeriod = Duration(seconds: 140);

  // The heads travel a transcript span past each end of the model, so the
  // period is stretched by the same factor to keep the on-screen pace.
  static const Duration _transcriptionPeriod = Duration(seconds: 144);

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

    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation
        ..stop()
        ..value = HelixModel.staticRotationTurns;
      _drift
        ..stop()
        ..value = 0;
      _transcription
        ..stop()
        ..value = HelixModel.staticTranscriptionTurns;
    } else {
      if (!_rotation.isAnimating) {
        unawaited(_rotation.repeat());
      }
      if (!_drift.isAnimating) {
        unawaited(_drift.repeat());
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
            transcript: theme.colorScheme.primary,
            background: theme.colorScheme.surface,
          ),
          willChange: true,
          size: Size.infinite,
        ),
      ),
    );
  }
}
