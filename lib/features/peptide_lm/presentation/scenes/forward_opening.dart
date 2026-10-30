import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/training_trace.dart';
import 'embedding_scene.dart';
import 'forward_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

/// Forward's first beat, from Embedding's last frame to the stream: `x0`, a
/// row of numbers a place, stands up as the residual stream, each row
/// turning upright and landing as its place's column, its first number at
/// the top, its numbers going as it narrows; the tiles that labelled the
/// rows come down to the token row; and the rail, the head maps, faint as
/// they are before any block has run, and the place in focus come up.
///
/// Its first frame is Embedding's last.
final class ForwardOpening {
  ForwardOpening(this.size, this.view, this.layout) : embedding = EmbeddingLayout(size, view);

  /// The opening's share of Forward, in beats.
  static const double beats = 1;

  // The rows stand up in place order, each in its own flight, its numbers
  // gone in the first part of it.
  static const double _stagger = 0.3;
  static const double _flight = 0.5;
  static const (double, double) _numbersOut = (0.0, 0.35);
  static const (double, double) _tokensDown = (0.15, 0.75);
  static const (double, double) _tagOut = (0.0, 0.3);
  static const (double, double) _rail = (0.45, 0.9);
  static const (double, double) _settle = (0.6, 1.0);

  final Size size;
  final LmView view;
  final ForwardLayout layout;
  final EmbeddingLayout embedding;

  static double _span(double beat, (double, double) span) => through(beat, span.$1, span.$2);

  /// How much of the rail shows.
  static double railShown(double beat) => _span(beat, _rail);

  /// How far the stage has settled into the blocks' first frame: the head
  /// maps and the place in focus.
  static double settled(double beat) => _span(beat, _settle);

  TrainingTrace get _trace => view.trace;

  /// Place [i]'s column of the stream, as Forward's grid lays it.
  Rect _column(int i) {
    final double w = layout.grid.width / view.focus.inputs;
    return Rect.fromLTWH(layout.grid.left + i * w, layout.grid.top, math.max(0.5, w - 1), layout.grid.height);
  }

  /// How far place [i]'s row has stood up.
  double _standOf(int i, double beat) {
    final int n = view.focus.inputs;
    final double start = n < 2 ? 0 : i / (n - 1) * _stagger;
    return through(beat, start, start + _flight);
  }

  void paint(Canvas canvas, double beat) {
    const EmbeddingScene().paintEnd(
      canvas,
      size,
      view,
      EmbeddingFade(rows: false, chrome: 1 - _span(beat, _tagOut)),
    );
    _stream(canvas, beat);
    _tokens(canvas, beat);
  }

  /// Each place's row: as Embedding left it, then standing up, then landed
  /// as its column of the stream, drawn as the stream is.
  void _stream(Canvas canvas, double beat) {
    final int inputs = view.focus.inputs;
    final int width = _trace.model.width;
    final double scale = ForwardScene.scales(view).$1;
    final GridMesh grid = GridMesh(layout.grid, inputs, width, columnGap: 1);
    bool landed = false;
    for (int i = 0; i < inputs; i++) {
      final bool down = _standOf(i, beat) >= 1;
      landed = landed || down;
      for (int d = 0; d < width; d++) {
        grid.cell(
          i,
          d,
          down
              ? view.inks.signed(_trace.stream(view.checkpoint, 0, view.peptide, i, d) / scale)
              : view.inks.ground.withValues(alpha: 0),
        );
      }
    }
    if (landed) {
      grid.draw(canvas);
    }
    for (int i = 0; i < inputs; i++) {
      final double f = _standOf(i, beat);
      if (f >= 1) {
        continue;
      }
      final Rect from = embedding.row(i);
      if (f <= 0) {
        EmbeddingScene.drawX0Row(canvas, view, embedding, from, i);
        continue;
      }
      final Rect to = _column(i);
      final Offset centre = Offset.lerp(from.center, to.center, f)!;
      final double length = from.width + (to.height - from.width) * f;
      final double thick = from.height + (to.width - from.height) * f;
      final Rect strip = Rect.fromCenter(center: Offset.zero, width: length, height: thick);
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(math.pi / 2 * f);
      embedding.fill(
        canvas,
        strip,
        <Color>[
          for (int d = 0; d < width; d++)
            Color.lerp(
              view.inks.cell(
                (_trace.tokenEmbedding(view.checkpoint, _trace.inputAt(view.peptide, i), d) +
                        _trace.positionEmbedding(view.checkpoint, i, d)) /
                    scale,
              ),
              view.inks.signed(_trace.stream(view.checkpoint, 0, view.peptide, i, d) / scale),
              f,
            )!,
        ],
        gap: EmbeddingLayout.gap * (1 - f),
        radius: EmbeddingLayout.radius * (1 - f),
      );
      final double numbers = 1 - through(f, _numbersOut.$1, _numbersOut.$2);
      if (numbers > 0) {
        EmbeddingScene.drawX0Row(canvas, view, embedding, strip, i, textAlpha: numbers, fills: false);
      }
      canvas.restore();
    }
  }

  /// The tiles that labelled x0's rows, coming down to the token row.
  void _tokens(Canvas canvas, double beat) {
    final double down = _span(beat, _tokensDown);
    for (int i = 0; i < view.focus.inputs; i++) {
      drawToken(
        canvas,
        view,
        Rect.lerp(embedding.label(i), layout.tokens.at(i), down)!,
        _trace.inputAt(view.peptide, i),
      );
    }
  }

  // ------------------------------------------------------------------ taps

  /// Once the token row has landed, a token puts its place in focus.
  LmHit? hit(Offset at, double beat) {
    if (beat >= _tokensDown.$2) {
      final int? i = layout.tokens.indexAt(at);
      return i == null ? null : FocusPosition(i);
    }
    return null;
  }

  // -------------------------------------------------------------- caption

  /// What the opening shows.
  static String caption(LmView view, double beat) => 'x0 stands up as the residual stream: a column a place';
}
