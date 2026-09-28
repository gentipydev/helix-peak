part of 'translation_painter.dart';

/// A reusable vector picture: the many surface lobes and rRNA folds are
/// recorded once, then replayed by the GPU. No bitmap assets or random
/// changes between animation frames. Coordinates are illustrative, not PDB.
final class _MolecularShell {
  _MolecularShell({
    required this.large,
    required this.color,
    required this.ground,
  });
  final bool large;
  final Color color;
  final Color ground;
  late final ui.Picture _picture = _record();

  void draw(Canvas canvas, Rect bounds, double opacity) {
    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    canvas.scale(bounds.width / 300, bounds.height / (large ? 205 : 70));
    if (opacity < 0.999) {
      canvas.saveLayer(
        Rect.fromLTWH(-12, -12, 324, large ? 229 : 94),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    canvas.drawPicture(_picture);
    if (opacity < 0.999) canvas.restore();
    canvas.restore();
  }

  Path _outline() => large
      ? (Path()
          ..moveTo(21, 173)
          ..cubicTo(4, 161, 13, 145, 7, 129)
          ..cubicTo(-5, 112, 15, 101, 11, 85)
          ..cubicTo(1, 66, 27, 66, 28, 47)
          ..cubicTo(27, 31, 56, 33, 64, 20)
          ..cubicTo(69, 6, 91, 15, 103, 8)
          ..cubicTo(114, -3, 134, 6, 149, 3)
          ..cubicTo(167, -4, 175, 12, 193, 9)
          ..cubicTo(215, 3, 223, 25, 241, 23)
          ..cubicTo(263, 20, 257, 43, 277, 49)
          ..cubicTo(296, 53, 280, 76, 294, 88)
          ..cubicTo(310, 103, 291, 121, 298, 135)
          ..cubicTo(305, 153, 290, 155, 288, 175)
          ..cubicTo(286, 196, 263, 190, 248, 198)
          ..cubicTo(220, 210, 194, 196, 169, 201)
          ..cubicTo(143, 210, 123, 196, 96, 201)
          ..cubicTo(73, 207, 65, 188, 46, 193)
          ..cubicTo(24, 201, 29, 180, 21, 173)
          ..close())
      : (Path()
          ..moveTo(6, 21)
          ..cubicTo(0, 5, 32, -4, 48, 4)
          ..cubicTo(65, -3, 75, 9, 96, 4)
          ..cubicTo(120, -3, 137, 9, 157, 5)
          ..cubicTo(179, 0, 195, 11, 211, 4)
          ..cubicTo(230, -3, 238, 6, 255, 4)
          ..cubicTo(274, 0, 297, 9, 294, 24)
          ..cubicTo(306, 36, 286, 40, 280, 52)
          ..cubicTo(276, 68, 251, 59, 242, 67)
          ..cubicTo(227, 79, 209, 65, 191, 68)
          ..cubicTo(170, 76, 150, 64, 132, 70)
          ..cubicTo(111, 77, 99, 66, 79, 68)
          ..cubicTo(61, 73, 51, 59, 35, 60)
          ..cubicTo(17, 60, 20, 44, 10, 42)
          ..cubicTo(-4, 39, 10, 29, 6, 21)
          ..close());

  Path get _window => Path()
    ..moveTo(66, 201)
    ..cubicTo(57, 175, 62, 162, 57, 141)
    ..cubicTo(50, 110, 69, 100, 83, 84)
    ..cubicTo(105, 65, 123, 67, 147, 72)
    ..cubicTo(169, 75, 185, 66, 206, 85)
    ..cubicTo(231, 104, 239, 113, 234, 144)
    ..cubicTo(231, 163, 246, 182, 234, 206)
    ..close();

  ui.Picture _record() {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    Path outline = _outline();
    final math.Random edgeRandom = math.Random(large ? 91 : 13);
    final ui.PathMetric boundary = outline.computeMetrics().first;
    // Smaller protrusions break up the silhouette as well as its interior.
    for (double along = 0; along < boundary.length; along += 11) {
      final Offset centre = boundary.getTangentForOffset(along)!.position;
      outline = Path.combine(
        PathOperation.union,
        outline,
        _lobe(centre, 2.5 + edgeRandom.nextDouble() * 3.5, edgeRandom),
      );
    }
    final Rect bounds = Rect.fromLTWH(0, 0, 300, large ? 205 : 70);
    final Paint fill = Paint();
    canvas.drawShadow(outline, Colors.black.withValues(alpha: 0.6), 7, true);
    fill.shader = ui.Gradient.linear(
      bounds.topLeft,
      bounds.bottomRight,
      <Color>[
        Color.lerp(color, ground, 0.38)!,
        Color.lerp(color, ground, 0.77)!,
      ],
    );
    canvas.drawPath(outline, fill);
    canvas.save();
    canvas.clipPath(outline);

    // Packed, irregular lobes at several scales suggest the interlocking
    // rRNA and proteins. A fixed seed makes scrubbing perfectly repeatable.
    final math.Random random = math.Random(large ? 73 : 41);
    final int rows = large ? 10 : 4;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < 15; col++) {
        final Offset centre = Offset(
          col * 22.0 + (row.isOdd ? 10 : 0) + random.nextDouble() * 19 - 9,
          row * 22.0 + random.nextDouble() * 17 - 7,
        );
        final double radius = 9 + random.nextDouble() * 12;
        final Path lobe = _lobe(centre, radius, random);
        final Color tint = Color.lerp(
          color,
          ground,
          0.2 + random.nextDouble() * 0.35,
        )!;
        fill.shader = ui.Gradient.radial(
          centre.translate(-radius * 0.35, -radius * 0.4),
          radius * 1.6,
          <Color>[
            Color.lerp(tint, Colors.white, 0.13)!,
            tint,
            Color.lerp(tint, ground, 0.72)!,
          ],
          const <double>[0, 0.38, 1],
        );
        canvas.drawPath(lobe, fill);
        // Fine folded ridges, following each domain instead of atom dots.
        final Paint ridge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            tint,
            Colors.white,
            0.35,
          )!.withValues(alpha: 0.2);
        for (int k = 0; k < 1 + (row + col) % 3; k++) {
          final double y =
              centre.dy - radius * 0.3 + k * 5 + random.nextDouble() * 3;
          canvas.drawPath(
            Path()
              ..moveTo(centre.dx - radius * 0.58, y)
              ..cubicTo(
                centre.dx - 6,
                y - 6,
                centre.dx + 2,
                y + 7,
                centre.dx + radius * 0.48,
                y - 2,
              ),
            ridge,
          );
        }
      }
    }
    // A shadowed cut face makes the centre read as open space, while a faint
    // translucent rear wall keeps the two subunits visually connected.
    if (large) {
      final Path window = _window;
      fill.shader = null;
      fill.color = ground.withValues(alpha: 0.95);
      canvas.drawPath(window, fill);
      final Paint rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = Colors.black.withValues(alpha: 0.16);
      canvas.drawPath(window, rim);
      rim
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.28);
      canvas.drawPath(window, rim);
      fill.shader = ui.Gradient.radial(const Offset(155, 150), 97, <Color>[
        color.withValues(alpha: 0.055),
        color.withValues(alpha: 0),
      ]);
      canvas.drawPath(window, fill);
    } else {
      // The decoding channel is a shallow groove across the small subunit.
      fill.shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, 42),
        <Color>[ground.withValues(alpha: 0.8), ground.withValues(alpha: 0.05)],
      );
      canvas.drawRect(bounds, fill);
    }
    canvas.restore();
    return recorder.endRecording();
  }

  static Path _lobe(Offset centre, double radius, math.Random random) {
    final List<Offset> points = <Offset>[
      for (int i = 0; i < 10; i++)
        centre +
            Offset(math.cos(i * math.pi / 5), math.sin(i * math.pi / 5)) *
                radius *
                (0.72 + random.nextDouble() * 0.36),
    ];
    final Offset start = (points.last + points.first) / 2;
    final Path path = Path()..moveTo(start.dx, start.dy);
    for (int i = 0; i < points.length; i++) {
      final Offset end = (points[i] + points[(i + 1) % points.length]) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, end.dx, end.dy);
    }
    return path..close();
  }
}
