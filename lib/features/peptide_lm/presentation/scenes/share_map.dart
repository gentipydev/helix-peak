import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'predict_scene.dart';

/// Predict's map of every place's guess, on any rows: a row a place, named by
/// its token's tile at the left; a column a token that can come next, named
/// by a tile under the last row; and at the right the answer key, each row's
/// next token on a tile and the share its guess gave it. Predict lays it on
/// the table's rows; Loop on rows of its own, under its curve.
final class ShareMapLayout {
  ShareMapLayout({
    required LmView view,
    required this.top,
    required this.pitch,
    required this.chipSide,
    required this.labelLeft,
    required this.dx,
    required this.mapLeft,
    required this.right,
  }) : _view = view {
    // The answer key, from the canvas's side in: the shares given, clear of
    // the place in focus's outline; then the tiles; then the map.
    final TextStyle? given = _givenStyle(view, pitch);
    givenStyle = given;
    givenRight = right - _outlineRoom;
    if (given == null) {
      answerLeft = givenRight - chipSide;
    } else {
      // Room for the widest share, 100%, right of the tiles; and for the
      // shares' name over them, clear of the tiles' own, which can be the
      // wider where the rows, and so the numbers, are small.
      final TextStyle named = PredictScene.titleStyle(view);
      final double numbers = view.kit.layout('100%', given).width + _givenGap + chipSide;
      final double names = view.kit.layout(PredictScene.givenTitle, named).width +
          _titleGap +
          view.kit.layout(PredictScene.answerTitle, named).width / 2 +
          chipSide / 2;
      answerLeft = givenRight - math.max(numbers, names);
    }
    mapRight = answerLeft - _answerGap;
    mapColumn = (mapRight - mapLeft) / view.trace.allowed.length;
  }

  final LmView _view;

  /// The first row's top, and a row's height.
  final double top;
  final double pitch;

  /// A tile's side, naming a row, a column or an answer.
  final double chipSide;

  /// Where the tiles naming the rows sit, and how far along they are drawn:
  /// Predict's are the table's own, slid over the gutter Embedding wrote its
  /// ids in.
  final double labelLeft;
  final double dx;

  /// Where the map's cells start, and the canvas's side the key comes up to.
  final double mapLeft;
  final double right;

  /// From the map to the answer key's tiles, from a tile to its share, and
  /// from the shares to the canvas's side, where the outline of the place in
  /// focus runs.
  static const double _answerGap = 6;
  static const double _givenGap = 3;
  static const double _outlineRoom = 2;

  /// Between the answer key's two names.
  static const double _titleGap = 4;

  /// Where the map ends, and how wide its columns are.
  late final double mapRight;
  late final double mapColumn;

  /// The answer key: where its tiles start, where the shares given end, and
  /// what those are written in, or null where the rows are too small for a
  /// number.
  late final double answerLeft;
  late final double givenRight;
  late final TextStyle? givenStyle;

  /// The shares given to what came next are written as the table's rows
  /// write their numbers: at most 9 points, and not below the least a number
  /// is written.
  static TextStyle? _givenStyle(LmView view, double pitch) {
    final double points = (math.min(9, pitch * 0.62) * 2).floorToDouble() / 2;
    return points < EmbeddingLayout.leastNumber
        ? null
        : inked(view.kit.mono, points, view.inks.ink).copyWith(letterSpacing: 0);
  }

  /// Place [i]'s row, from the cells' start to the canvas's side.
  Rect row(int i) => Rect.fromLTRB(mapLeft, top + i * pitch, right, top + (i + 1) * pitch);

  /// The tile naming place [i]'s row, at its left.
  Rect rowTile(int i) =>
      Rect.fromLTWH(labelLeft, top + i * pitch + (pitch - chipSide) / 2, chipSide, chipSide).shift(Offset(dx, 0));

  /// The map's cell at row [i], column [k]: what place [i] gives the [k]th
  /// token that can come next.
  Rect cell(int i, int k) {
    final Rect r = row(i);
    final double x = mapLeft + k * mapColumn;
    return Rect.fromLTRB(x, r.top, x + mapColumn, r.bottom);
  }

  /// Place [i]'s row of the map, every column of it.
  Rect mapRow(int i) => Rect.fromLTRB(mapLeft, row(i).top, mapRight, row(i).bottom);

  /// The tile of what came next after place [i], at its row's end: as large
  /// as the tile naming the row, centred on it.
  Rect answerTile(int i) {
    final Rect r = row(i);
    return Rect.fromLTWH(answerLeft, r.center.dy - chipSide / 2, chipSide, chipSide);
  }

  /// The tile naming the map's column [k], under its last row, as Attention
  /// names the places read.
  Rect columnTile(int k) {
    final Rect last = cell(_view.focus.inputs - 1, k);
    final double wide = math.max(1.0, math.min(chipSide, last.width - 1));
    return Rect.fromLTWH(last.center.dx - wide / 2, last.bottom + 4, wide, chipSide);
  }

  /// Where the answer key's names stand, over its first row.
  double get titleTop => top - 4;

  /// The place whose row lies under [at], on the map or its tiles.
  int? placeAt(Offset at) {
    if (at.dx < labelLeft + dx - 3 || at.dx > right + 1) {
      return null;
    }
    final int i = ((at.dy - top) / pitch).floor();
    return i >= 0 && i < _view.focus.inputs ? i : null;
  }
}

/// How Predict's map is drawn, on any [ShareMapLayout].
abstract final class ShareMap {
  /// The tiles naming the places, at the rows' left.
  static void drawRowTiles(Canvas canvas, LmView view, ShareMapLayout layout, {double alpha = 1}) {
    for (int i = 0; i < view.focus.inputs; i++) {
      drawToken(canvas, view, layout.rowTile(i), view.trace.inputAt(view.peptide, i), alpha: alpha);
    }
  }

  /// The tiles naming the tokens that can come next, under the columns.
  static void drawColumnTiles(Canvas canvas, LmView view, ShareMapLayout layout, {double alpha = 1}) {
    final List<int> allowed = view.trace.allowed;
    for (int k = 0; k < allowed.length; k++) {
      drawToken(canvas, view, layout.columnTile(k), allowed[k], alpha: alpha);
    }
  }

  /// Every place's guess, [rows] a share a column: each cell its slot, lit
  /// [lit] of the way where it is what came next, and the share's square in
  /// it, grown as far as its row has, [shown] as strongly as asked.
  static void drawCells(
    Canvas canvas,
    LmView view,
    ShareMapLayout layout,
    List<List<double>> rows, {
    required double Function(int i) grown,
    required double Function(int i, int k, bool answer) shown,
    required double Function(int i) lit,
  }) {
    final TrainingTrace trace = view.trace;
    final int columns = trace.allowed.length;
    for (int i = 0; i < view.focus.inputs; i++) {
      final double filled = grown(i);
      final int answer = trace.allowedIndex(trace.targetAt(view.peptide, i));
      final double light = lit(i);
      for (int k = 0; k < columns; k++) {
        PredictScene.drawShare(
          canvas,
          view,
          layout.cell(i, k),
          share: rows[i][k],
          grown: filled,
          shown: shown(i, k, k == answer),
          lit: k == answer ? light : 0,
        );
      }
    }
  }

  /// Place [i]'s row outlined, from its tile to the canvas's side, as the
  /// table outlines the place in focus.
  static void drawOutline(Canvas canvas, LmView view, ShareMapLayout layout, int i, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final Rect row = layout.row(i);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(layout.labelLeft + layout.dx - 3, row.top, layout.right + 1, row.bottom),
        const Radius.circular(3),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.signal.withValues(alpha: 0.85 * alpha),
    );
  }

  /// The answer key at the map's right, as Shift's y: each place's next
  /// token on a tile at its row's end, [tiles] strong, and the share its
  /// guess gave it, [given] of the place, written [numbers] strong where the
  /// rows have room; their names over them with the numbers.
  static void drawAnswerKey(
    Canvas canvas,
    LmView view,
    ShareMapLayout layout, {
    required double tiles,
    required double numbers,
    required double Function(int i) given,
  }) {
    final TrainingTrace trace = view.trace;
    final TextStyle? style = layout.givenStyle;
    final TextStyle? written = style?.copyWith(color: style.color!.withValues(alpha: (numbers * 8).round() / 8));
    for (int i = 0; i < view.focus.inputs; i++) {
      final int next = trace.targetAt(view.peptide, i);
      drawToken(canvas, view, layout.answerTile(i), next, alpha: tiles);
      if (written != null && numbers > 0) {
        view.kit.draw(
          canvas,
          percent(given(i)),
          written,
          Offset(layout.givenRight, layout.row(i).center.dy),
          anchor: const Offset(1, 0.5),
        );
      }
    }
    // Named as a column is (`drawColumnTitle`), the shares' name flush with
    // their right edge.
    if (numbers <= 0) {
      return;
    }
    final TextStyle named = PredictScene.titleStyle(view, alpha: numbers);
    view.kit.draw(
      canvas,
      PredictScene.answerTitle,
      named,
      Offset(layout.answerTile(0).center.dx, layout.titleTop),
      anchor: const Offset(0.5, 1),
    );
    if (written != null) {
      view.kit.draw(canvas, PredictScene.givenTitle, named, Offset(layout.givenRight, layout.titleTop), anchor: const Offset(1, 1));
    }
  }
}
