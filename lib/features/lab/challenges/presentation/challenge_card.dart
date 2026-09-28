import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/share/gene_link.dart';
import '../domain/daily_puzzle.dart';
import 'challenge_ledger.dart';

/// The link a shared result carries: the day's challenge, on the app's own
/// scheme, which opens the lab where it is built in.
Uri challengeLink() => Uri(
  scheme: geneLinkScheme,
  host: 'open',
  path: '${RoutePaths.lab}/challenges',
);

/// A result as a reader shares it, the way Wordle's are: a square a round, a
/// square a codon, and the link. Right is green, anything else black; the
/// squares say how the day went and nothing about what was asked.
String shareText(DailyPuzzle puzzle, DayResult result) {
  String squares(Iterable<bool> right) =>
      right.map((bool r) => r ? '🟩' : '⬛').join();
  return 'Helix Peek daily ${puzzle.day}: '
      '${result.right}/${puzzle.rounds.length}\n'
      '${squares(result.rounds)}\n'
      '${squares(result.codons)}\n'
      '${challengeLink()}';
}

/// The same result as a card: the poster's own way of making a picture (a
/// canvas recorded, drawn once to an image, and encoded as PNG), in the lab's
/// theme, square, so feeds show it whole.
Future<Uint8List> shareCard({
  required ThemeData theme,
  required DailyPuzzle puzzle,
  required DayResult result,
  double side = 1080,
}) async {
  final ColorScheme scheme = theme.colorScheme;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(
    recorder,
  )..drawRect(Offset.zero & Size.square(side), Paint()..color = scheme.surface);
  final double margin = side * 0.08;

  double write(String text, TextStyle? style, double top) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style?.copyWith(color: scheme.onSurface),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: side - 2 * margin);
    painter.paint(canvas, Offset(margin, top));
    final double height = painter.height;
    painter.dispose();
    return top + height;
  }

  double top = margin;
  top = write(
    'Helix Peek daily',
    theme.textTheme.displaySmall?.copyWith(fontSize: side * 0.06),
    top,
  );
  top = write(
    '${puzzle.day} · ${result.right} of ${puzzle.rounds.length}',
    theme.textTheme.titleLarge?.copyWith(fontSize: side * 0.04),
    top + side * 0.01,
  );

  void squares(List<bool> right, double y, double size) {
    final double gap = size * 0.18;
    for (int i = 0; i < right.length; i++) {
      final Rect square = Rect.fromLTWH(
        margin + i * (size + gap),
        y,
        size,
        size,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(square, Radius.circular(size * 0.16)),
        Paint()
          ..color = right[i] ? scheme.primary : scheme.surfaceContainerHighest,
      );
    }
  }

  final double rounds = (side - 2 * margin) / 5;
  squares(result.rounds, top + side * 0.06, rounds);
  top += side * 0.06 + rounds;
  final double codons = (side - 2 * margin) / 9.5;
  squares(result.codons, top + side * 0.05, codons);
  top += side * 0.05 + codons;
  write(
    challengeLink().toString(),
    theme.textTheme.titleMedium?.copyWith(fontSize: side * 0.03),
    side - margin - side * 0.04,
  );

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(side.round(), side.round());
  picture.dispose();
  try {
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (png == null) {
      throw StateError('the card could not be encoded');
    }
    return png.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
