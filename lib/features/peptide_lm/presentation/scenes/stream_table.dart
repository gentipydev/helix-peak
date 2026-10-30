import 'package:flutter/material.dart';

import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'embedding_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';

/// The residual stream as Embedding leaves it, for the stages after it: a
/// row a place, each number written on a soft tile of its colour, the tile
/// naming the place at the row's left, a tag at the top left and a note over
/// it all, on Embedding's own layout, so each stage opens where the one
/// before it ended.
final class StreamTable {
  StreamTable(this.size, this.view) : layout = EmbeddingLayout(size, view);

  final Size size;
  final LmView view;
  final EmbeddingLayout layout;

  TrainingTrace get trace => view.trace;

  int get places => view.focus.inputs;

  int get width => trace.model.width;

  /// The stream's colour scale: the same at every point, so a colour means
  /// one size of number throughout.
  double get scale => streamScales(view).$1;

  /// Place [i]'s numbers at stream [point]: x0 as Embedding wrote it, then
  /// as the run kept each point.
  List<double> values(int point, int i) => <double>[
    for (int d = 0; d < width; d++)
      point == 0
          ? EmbeddingScene.value(view, i, d)
          : trace.stream(view.checkpoint, point, view.peptide, i, d),
  ];

  /// What place [i] gained from point [from] to point [to]: a part's own
  /// output, added to the stream.
  List<double> gained(int from, int to, int i) {
    final List<double> before = values(from, i);
    final List<double> after = values(to, i);
    return <double>[for (int d = 0; d < width; d++) after[d] - before[d]];
  }

  /// The colour scale of what the places in focus gained from [from] to
  /// [to], on its own, as Embedding draws the position rows alone.
  double gainScale(int from, int to) => view.kit.memo<double>(
    ('stream-gain', view.step, view.peptide, from, to),
    () => percentileScale(<double>[for (int i = 0; i < places; i++) ...gained(from, to, i)]),
  );

  /// Row [i]'s place: its full width, as the table writes it.
  Rect row(int i) => layout.row(i);

  /// Row [i] squeezed [squeeze] of the way to [narrow] wide, from the
  /// numbers' left edge.
  Rect squeezed(int i, double narrow, double squeeze) {
    final Rect full = layout.row(i);
    return Rect.fromLTWH(full.left, full.top, full.width + (narrow - full.width) * squeeze, full.height);
  }

  /// [numbers] across [rect], each on a soft tile of its colour on [scale],
  /// written out at [text] where the layout writes numbers; the tiles'
  /// corners and gaps shrinking with them as the row narrows.
  void drawRow(
    Canvas canvas,
    Rect rect,
    List<double> numbers, {
    required double scale,
    double text = 1,
    double fill = 1,
    List<Color>? colors,
  }) {
    final double share = (rect.width / layout.row(0).width).clamp(0.0, 1.0);
    if (fill > 0) {
      layout.fill(
        canvas,
        rect,
        <Color>[
          for (int d = 0; d < numbers.length; d++)
            Color.lerp(
              view.inks.ground,
              colors == null ? view.inks.cell(numbers[d] / scale) : colors[d],
              fill,
            )!,
        ],
        gap: EmbeddingLayout.gap * (0.5 + 0.5 * share),
        radius: EmbeddingLayout.radius * share.clamp(0.4, 1.0),
      );
    }
    final TextStyle? style = layout.numberStyle;
    if (style != null && text > 0) {
      layout.write(
        canvas,
        rect,
        <String>[for (final double v in numbers) fixed(v, EmbeddingLayout.digits)],
        text >= 1 ? style : style.copyWith(color: style.color!.withValues(alpha: (text * 8).round() / 8)),
      );
    }
  }

  /// The tiles that name the places, at the rows' left.
  void drawTiles(Canvas canvas, {double alpha = 1}) {
    for (int i = 0; i < places; i++) {
      drawToken(canvas, view, layout.label(i), trace.inputAt(view.peptide, i), alpha: alpha);
    }
  }

  /// Place [i]'s row outlined, as Embedding marks a row, from its tile to
  /// [right].
  void outline(Canvas canvas, int i, double right, double alpha) {
    if (alpha <= 0) {
      return;
    }
    final Rect row = layout.row(i);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(layout.label(i).left - 3, row.top, right + 1, row.bottom),
        const Radius.circular(3),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.signal.withValues(alpha: 0.85 * alpha),
    );
  }

  /// The tag at the table's top left, as Embedding names its matrix.
  void tag(Canvas canvas, String text, double alpha) {
    if (alpha > 0) {
      drawTag(canvas, view, text, Offset(layout.left, layout.tagTop), alpha: alpha);
    }
  }

  /// How long a note takes to come and go, in beats.
  static const double _turn = 0.25;

  /// The note over the table: each part, (from, to, text), fading in and out
  /// at its turns, sitting on the foot of the band Embedding keeps for its
  /// own notes, a line a thought.
  void note(Canvas canvas, List<(double, double, String)> notes, double beat, {double alpha = 1}) {
    final double band = layout.right - layout.noteLeft;
    final double foot = layout.noteTop + EmbeddingScene.noteHeight(view, band);
    for (final (double from, double to, String text) in notes) {
      final double shown = through(beat, from, from + _turn) * (1 - through(beat, to - _turn, to)) * alpha;
      if (shown <= 0) {
        continue;
      }
      final TextPainter lines = view.kit.paragraph(text, EmbeddingScene.whyStyle(view, alpha: shown), band);
      lines.paint(canvas, Offset(layout.noteLeft, foot - lines.height));
    }
  }

  /// The place under [at], by its row.
  int? placeAt(Offset at) => layout.placeAt(at);

  /// A place as the captions name it: `<bos>`, or its residue and place,
  /// `C11`.
  static String placeName(LmView view, int i) =>
      i == 0 ? '<bos>' : '${view.focus.sequence[i - 1]}$i';
}
