import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'replication_topo.dart';

/// The same lit, folded surface language as the Ribosome cutaway. Pictures are
/// recorded once per screen and reused while DNA and active sites move.
/// These are illustrative envelopes, not atom coordinates or PDB surfaces.
class ReplicationMolecules {
  final Map<(Color, int, bool), ui.Picture> _pictures =
      <(Color, int, bool), ui.Picture>{};

  final TopoisomerasePictures topo = TopoisomerasePictures();

  void draw(
    Canvas canvas,
    Offset centre,
    Size size,
    Color color, {
    int seed = 11,
    bool channel = true,
    double angle = 0,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    final ui.Picture picture = _pictures.putIfAbsent((
      color,
      seed,
      channel,
    ), () => _record(color, seed, channel));
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);
    canvas.scale(size.width / 100, size.height / 100);
    if (opacity < 1) {
      canvas.saveLayer(
        const Rect.fromLTWH(-60, -60, 120, 120),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    canvas.drawPicture(picture);
    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  static ui.Picture _record(Color color, int seed, bool channel) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final math.Random random = math.Random(seed);
    Path shell = lobe(Offset.zero, 46, random, points: 18);
    for (int i = 0; i < 16; i++) {
      final double a = i * math.pi / 8;
      shell = Path.combine(
        PathOperation.union,
        shell,
        lobe(Offset(math.cos(a), math.sin(a)) * 40, 8, random),
      );
    }
    // An open longitudinal cut face exposes the DNA through the enzyme.
    final Path pore = Path()
      ..moveTo(-9, -55)
      ..cubicTo(-14, -25, -17, -12, -13, 4)
      ..cubicTo(-10, 22, -8, 35, -11, 55)
      ..lineTo(12, 55)
      ..cubicTo(8, 31, 22, 18, 15, 0)
      ..cubicTo(8, -19, 14, -31, 10, -55)
      ..close();
    if (channel) {
      shell = Path.combine(PathOperation.difference, shell, pore);
    }
    paintFolded(canvas, shell, color, random, pore: channel ? pore : null);
    return recorder.endRecording();
  }

  /// Paints [shell] in the lit, folded surface every replication protein
  /// wears: a shadow, a gradient lit from the top left, rounded lobes with
  /// faint ridges, and the rim of a cut face along [pore].
  static void paintFolded(
    Canvas canvas,
    Path shell,
    Color color,
    math.Random random, {
    Path? pore,
  }) {
    canvas.drawShadow(shell, Colors.black.withValues(alpha: 0.65), 5, true);
    canvas.drawPath(
      shell,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-40, -40),
          const Offset(40, 45),
          <Color>[color, Color.lerp(color, Colors.black, 0.65)!],
        ),
    );
    canvas.save();
    canvas.clipPath(shell);
    for (int row = 0; row < 8; row++) {
      for (int column = 0; column < 8; column++) {
        final Offset at = Offset(
          -49 + column * 14 + random.nextDouble() * 9,
          -49 + row * 14 + random.nextDouble() * 9,
        );
        final double radius = 7 + random.nextDouble() * 8;
        final Color tint = Color.lerp(
          color,
          Colors.black,
          0.08 + random.nextDouble() * 0.22,
        )!;
        canvas.drawPath(
          lobe(at, radius, random),
          Paint()
            ..shader = ui.Gradient.radial(
              at - Offset(radius * 0.3, radius * 0.4),
              radius * 1.6,
              <Color>[
                Color.lerp(tint, Colors.white, 0.22)!,
                tint,
                Color.lerp(tint, Colors.black, 0.63)!,
              ],
              const <double>[0, 0.4, 1],
            ),
        );
        for (int ridge = 0; ridge < 2; ridge++) {
          final double y = at.dy - 3 + ridge * 4;
          canvas.drawPath(
            Path()
              ..moveTo(at.dx - radius * 0.65, y)
              ..cubicTo(
                at.dx - 3,
                y - 4,
                at.dx + 2,
                y + 5,
                at.dx + radius * 0.55,
                y - 1,
              ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.09),
          );
        }
      }
    }
    if (pore != null) {
      canvas.drawPath(
        pore,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Colors.black.withValues(alpha: 0.28),
      );
      canvas.drawPath(
        pore,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = color.withValues(alpha: 0.6),
      );
    }
    canvas.restore();
  }

  static Path lobe(
    Offset centre,
    double radius,
    math.Random random, {
    int points = 9,
  }) {
    final List<Offset> edge = <Offset>[
      for (int i = 0; i < points; i++)
        centre +
            Offset(
                  math.cos(i * math.pi * 2 / points),
                  math.sin(i * math.pi * 2 / points),
                ) *
                radius *
                (0.78 + random.nextDouble() * 0.3),
    ];
    final Offset start = (edge.first + edge.last) / 2;
    final Path path = Path()..moveTo(start.dx, start.dy);
    for (int i = 0; i < points; i++) {
      final Offset next = (edge[i] + edge[(i + 1) % points]) / 2;
      path.quadraticBezierTo(edge[i].dx, edge[i].dy, next.dx, next.dy);
    }
    return path..close();
  }

  void dispose() {
    for (final ui.Picture picture in _pictures.values) {
      picture.dispose();
    }
    _pictures.clear();
    topo.dispose();
  }
}
