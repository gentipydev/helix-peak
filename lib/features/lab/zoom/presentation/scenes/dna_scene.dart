import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../shared/helix/helix_geometry.dart';
import '../../domain/zoom_depth.dart';
import 'body_scene.dart';
import 'zoom_scene.dart';
import 'zoom_subject.dart';

/// The gene's first bases on the shared double helix, across a view 12 nm
/// wide: a base pair is 0.34 nm thick and the helix 2 nm across.
final class DnaScene extends ZoomScene {
  DnaScene(this.subject);

  final ZoomSubject subject;

  @override
  ZoomStop get stop => ZoomStop.dna;

  /// One base pair along the axis, in the scene's units.
  static const double pitch = 1 / ZoomDepth.dnaBasePairs;

  late final HelixModel? _model = () {
    final int count = subject.dnaBases;
    if (count < 4) {
      return null;
    }
    final String bases = subject.record.sequence;
    return HelixModel(
      rungCount: count,
      sampleCount: 3 * count,
      bases: Uint8List.fromList(<int>[
        for (int i = 0; i < count; i++) HelixPalette.ofBase(bases[i]),
      ]),
    );
  }();

  double get _length => subject.dnaBases * pitch;

  @override
  void stage(ZoomFrame frame, ZoomStaging out) {
    final Offset five = frame.toScreen(Offset(-_length / 2, 0));
    out.item('dna:5', five, frame.opacity);
    out.callout('dna', '5′', five, calloutPresence(frame));
  }

  @override
  void paint(Canvas canvas, ZoomFrame frame) {
    final HelixModel? model = _model;
    if (model == null) {
      return;
    }
    canvas.save();
    frame.enter(canvas);
    final double pixel = frame.pixel;
    const double turn = pitch * HelixModel.basePairsPerTurn;
    const double radius = turn / (2 * HelixModel.pitchPerDiameter);
    final double length = _length;
    final List<(double, Offset, Offset, int, int)> parts =
        <(double, Offset, Offset, int, int)>[];
    Offset place(int i) =>
        Offset(model.pointAxial[i] * length, model.pointCos[i] * radius);
    for (int p = 0; p < model.primitiveCount; p++) {
      final int kind = model.primKind[p];
      if (kind == HelixPrimitiveKind.transcriptSegment ||
          kind == HelixPrimitiveKind.transcriptNode) {
        continue;
      }
      final int a = model.primStart[p];
      final int z = model.primEnd[p];
      parts.add((
        (model.pointSin[a] + model.pointSin[z]) / 2,
        place(a),
        place(z),
        kind,
        model.primPalette[p],
      ));
    }
    parts.sort(
      (
        (double, Offset, Offset, int, int) x,
        (double, Offset, Offset, int, int) y,
      ) => x.$1.compareTo(y.$1),
    );
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Color far = frame.inks.ground;
    for (final (double depth, Offset a, Offset z, int kind, int slot)
        in parts) {
      final double shade = 0.45 + 0.55 * (depth + 1) / 2;
      final Color colour = switch (slot) {
        HelixPalette.adenine => frame.inks.bases.adenine,
        HelixPalette.thymine => frame.inks.bases.thymine,
        HelixPalette.guanine => frame.inks.bases.guanine,
        HelixPalette.cytosine => frame.inks.bases.cytosine,
        _ => frame.inks.scale.backbone,
      };
      final Color lit = Color.lerp(far, colour, shade)!;
      if (kind == HelixPrimitiveKind.node) {
        canvas.drawCircle(a, 3.2 * pixel, Paint()..color = lit);
        continue;
      }
      stroke
        ..color = lit
        ..strokeWidth =
            (kind == HelixPrimitiveKind.strandSegment ? 2.4 : 3.2) * pixel;
      canvas.drawLine(a, z, stroke);
    }
    canvas.restore();
  }
}
