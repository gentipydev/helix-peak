import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'replication_molecules.dart';

/// Topoisomerase II lying along the DNA it cuts, after its structure: a
/// dimer whose two monomers meet across the DNA gate. The G-segment runs
/// through the gate; the N-gate, the ATPase domains' cavity, is on the left,
/// and the C-gate on the right. Each monomer is recorded once per colour and
/// drawn apart as the gate opens.
class TopoisomerasePictures {
  final Map<(Color, bool), ui.Picture> _pictures = <(Color, bool), ui.Picture>{};

  /// Design size of the whole dimer.
  static const Size size = Size(84, 64);

  // The cut face through the DNA gate, just wide enough to show the
  // G-segment inside.
  static final Path _pore = Path()
    ..moveTo(-10, -60)
    ..cubicTo(-12, -30, -10.5, -14, -11.5, 0)
    ..cubicTo(-10.5, 14, -12, 30, -10, 60)
    ..lineTo(10, 60)
    ..cubicTo(12, 30, 10.5, 14, 11.5, 0)
    ..cubicTo(10.5, -14, 12, -30, 10, -60)
    ..close();

  void draw(
    Canvas canvas,
    Offset centre, {
    required Color upper,
    required Color lower,
    required Color site,
    double gate = 0,
    double sites = 0,
    double opacity = 1,
  }) {
    if (opacity <= 0) {
      return;
    }
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(size.width / 100, size.height / 76);
    if (opacity < 1) {
      canvas.saveLayer(
        const Rect.fromLTWH(-62, -60, 124, 120),
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }
    // The gate opens the two monomers apart across the cut G-segment.
    final double apart = 7 * gate;
    for (final bool top in <bool>[true, false]) {
      final ui.Picture picture = _pictures.putIfAbsent(
        (top ? upper : lower, top),
        () => _record(top ? upper : lower, top),
      );
      canvas.save();
      canvas.translate(0, top ? -apart : apart);
      canvas.drawPicture(picture);
      // The active-site tyrosine beside the G-segment, which holds the cut
      // end while the gate is open.
      final Offset tyrosine = Offset(top ? -8.5 : 8.5, top ? -4 : 4);
      canvas.drawCircle(
        tyrosine,
        2.2 + 1.2 * sites,
        Paint()
          ..color = Color.lerp(
            Color.lerp(site, Colors.black, 0.55)!,
            Color.lerp(site, Colors.white, 0.2)!,
            sites,
          )!,
      );
      if (sites > 0) {
        canvas.drawCircle(
          tyrosine,
          9,
          Paint()
            ..shader = ui.Gradient.radial(tyrosine, 9, <Color>[
              site.withValues(alpha: 0.45 * sites),
              site.withValues(alpha: 0),
            ]),
        );
      }
      canvas.restore();
    }
    if (opacity < 1) {
      canvas.restore();
    }
    canvas.restore();
  }

  /// One monomer: the upper (y < 0) or the lower, lit from the top left
  /// either way.
  static ui.Picture _record(Color color, bool top) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final math.Random random = math.Random(top ? 71 : 73);
    final double s = top ? -1 : 1;
    // N-terminal ATPase domains (left), the core over the DNA gate, and the
    // C-terminal arm that closes the C-gate (right).
    final List<(Offset, double)> parts = <(Offset, double)>[
      (Offset(-38, 11 * s), 12),
      (Offset(-30, 21 * s), 13),
      (Offset(-19, 27 * s), 11),
      (Offset(-7, 30 * s), 12),
      (Offset(7, 30 * s), 12),
      (Offset(-15, 12 * s), 11),
      (Offset(15, 12 * s), 11),
      (Offset(0, 17 * s), 10),
      (Offset(22, 24 * s), 11),
      (Offset(34, 17 * s), 10),
      (Offset(42, 8 * s), 9),
      (Offset(-26, 12 * s), 12),
      (Offset(24, 12 * s), 11),
    ];
    Path shell = Path();
    for (final (Offset at, double radius) in parts) {
      shell = Path.combine(
        PathOperation.union,
        shell,
        ReplicationMolecules.lobe(at, radius, random),
      );
    }
    // Only this monomer's side of the interface, then the N-gate and C-gate
    // cavities the two monomers enclose between them, and the DNA gate.
    shell = Path.combine(
      PathOperation.intersect,
      shell,
      Path()..addRect(
        top
            ? const Rect.fromLTRB(-60, -60, 60, 0.5)
            : const Rect.fromLTRB(-60, -0.5, 60, 60),
      ),
    );
    for (final (Offset at, double radius) in <(Offset, double)>[
      (const Offset(-29, 0), 9.5),
      (const Offset(29, 0), 11),
    ]) {
      shell = Path.combine(
        PathOperation.difference,
        shell,
        Path()..addOval(Rect.fromCircle(center: at, radius: radius)),
      );
    }
    shell = Path.combine(PathOperation.difference, shell, _pore);
    ReplicationMolecules.paintFolded(canvas, shell, color, random, pore: _pore);
    return recorder.endRecording();
  }

  void dispose() {
    for (final ui.Picture picture in _pictures.values) {
      picture.dispose();
    }
    _pictures.clear();
  }
}
