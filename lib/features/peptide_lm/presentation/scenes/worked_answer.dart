import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/training_trace.dart';
import '../lm_format.dart';
import 'attention_scene.dart';
import 'lm_drawing.dart';
import 'lm_scene.dart';
import 'scores_scene.dart';
import 'stream_table.dart';
import 'weight_flow.dart';

/// Number 1 of head 1's answer for the place in focus, worked out: where
/// each place's value comes from, and what each brings to the answer.
/// Attention plays it once the heads' answers stand side by side, before
/// they go through the output weights, and it opens and ends on that frame.
///
/// The answers' column goes to the bench's right edge, its other numbers
/// gone and their tiles faint, its first an empty slot. A copy of the place
/// in focus's row lifts off and stands up where Scores stood it, evened; the
/// 16 value weights into number 1 run from it, a string each, into a cell on
/// its row: number 1 of its value, as Scores made it. `<bos>`'s row takes its
/// place and runs through the same weights into its own cell, and every
/// other place's comes, each on its row. Each is multiplied by its share,
/// what it brings written beside it; those run, a string each, into the
/// empty slot and make it. The answers' other numbers come back, and the
/// column goes back to where it stood.
///
/// Every number is the run's: the evened rows, the value weights, each
/// value and each share, whole.
abstract final class WorkedAnswer {
  /// How long it plays, in beats.
  static const double beats = 7;

  /// The head and the number worked out: head 1's, number 1.
  static const int _head = 0;

  // The goal: the column's names and its other numbers go, their tiles go
  // faint; it goes to the bench's right edge, and its first number empties
  // into a slot.
  static const (double, double) _namesOut = (0.0, 0.2);
  static const (double, double) _faint = (0.0, 0.3);
  static const (double, double) _park = (0.15, 0.6);
  static const (double, double) _empty = (0.45, 0.7);

  // The place in focus's value, number 1, as Scores made it: a copy of its
  // row lifts off and stands up where Scores stood it; every place's cell
  // comes, empty, on its row, and the weights' plate; the row runs through
  // the 16 weights into its cell, slowly.
  static const (double, double) _liftOwn = (0.8, 1.1);
  static const (double, double) _standOwn = (1.0, 1.4);
  static const (double, double) _cellsIn = (1.2, 1.45);
  static const (double, double) _plateIn = (1.3, 1.55);
  static const WeightFlow _ownFlow = WeightFlow(
    alone: <(double, double)>[(1.55, 2.05)],
    // One number is made: there is no rest.
    cascade: (2.05, 2.05),
    webOut: (3.4, 3.6),
    firstRelax: 0.3,
  );

  // `<bos>`'s: its row takes the place of the first and runs through the
  // same weights into its own cell.
  static const (double, double) _liftFirst = (2.2, 2.45);
  static const (double, double) _standFirst = (2.35, 2.75);
  static const WeightFlow _firstFlow = WeightFlow(
    alone: <(double, double)>[(2.85, 3.25)],
    cascade: (3.25, 3.25),
    webOut: (3.4, 3.6),
    firstRelax: 0.3,
  );

  // The bench clears, and every other place's comes, top to bottom.
  static const (double, double) _benchOut = (3.4, 3.6);
  static const (double, double) _others = (3.5, 4.0);

  // Each times its share: the shares come, then what each brings, one after
  // another, top to bottom; the two places the caption names are marked.
  static const (double, double) _sharesIn = (4.1, 4.35);
  static const (double, double) _brings = (4.4, 5.1);
  static const (double, double) _marked = (5.0, 5.2);

  // What each brings runs into the empty slot, a string each, and makes it.
  static const WeightFlow _sumFlow = WeightFlow(
    alone: <(double, double)>[(5.35, 5.85)],
    cascade: (5.85, 5.85),
    webOut: (6.1, 6.3),
    firstRelax: 0.3,
  );

  // The table goes, the column's other numbers come back, and it goes back
  // to where it stood, named again.
  static const (double, double) _tableOut = (6.1, 6.3);
  static const (double, double) _refill = (6.1, 6.4);
  static const (double, double) _unpark = (6.35, 6.8);
  static const (double, double) _namesIn = (6.75, 6.95);

  /// How long a cell of every other place takes to fill, and what one place
  /// brings to be written.
  static const double _each = 0.15;

  static double _span(double local, (double, double) span) => through(local, span.$1, span.$2);

  /// The place whose row goes through the weights after the place in focus:
  /// `<bos>`, the first every place reads; none when it is the place in
  /// focus.
  static int? second(LmView view) => view.position == 0 ? null : 0;

  // ------------------------------------------------------------------ data

  /// The value weight from number [d] of an evened row into number 1 of its
  /// value.
  static double _weight(LmView view, int d) =>
      view.trace.projection(view.checkpoint, AttentionScene.block, 2, _head, d);

  /// Place [j]'s row, evened out as attention reads it.
  static List<double> evened(LmView view, int j) => <double>[
    for (int d = 0; d < view.trace.model.width; d++)
      view.trace.attnInput(view.checkpoint, AttentionScene.block, view.peptide, j, d),
  ];

  /// Number 1 of each place's value, up to the place in focus: what the run
  /// kept, whole.
  static List<double> values(LmView view) => view.kit.memo<List<double>>(
    ('worked-values', view.step, view.peptide, view.position),
    () => <double>[
      for (int j = 0; j <= view.position; j++)
        view.trace.value(view.checkpoint, AttentionScene.block, _head, view.peptide, j, 0),
    ],
  );

  /// What each place up to the place in focus brings to number 1 of the
  /// answer: its share times number 1 of its value.
  static List<double> brought(LmView view) => view.kit.memo<List<double>>(
    ('worked-brought', view.step, view.peptide, view.position),
    () {
      final List<double> shares = AttentionScene.shares(view, _head);
      final List<double> numbers = values(view);
      return <double>[for (int j = 0; j < numbers.length; j++) shares[j] * numbers[j]];
    },
  );

  /// Number 1 of head 1's answer, as the run kept it: their sum.
  static double answer(LmView view) =>
      view.trace.mixed(view.checkpoint, AttentionScene.block, _head, view.peptide, view.position, 0);

  /// The place that brings most, by size, and the place with the largest
  /// share: the first of each, where two are level.
  static (int, int) named(LmView view) {
    final List<double> shares = AttentionScene.shares(view, _head);
    final List<double> each = brought(view);
    int most = 0;
    int largest = 0;
    for (int j = 1; j < each.length; j++) {
      if (each[j].abs() > each[most].abs()) {
        most = j;
      }
      if (shares[j] > shares[largest]) {
        largest = j;
      }
    }
    return (most, largest);
  }

  /// The largest of the value weights: the scale their strings are drawn on,
  /// as Scores draws the value's.
  static double _weightReach(LmView view) => view.kit.memo<double>(
    ('worked-weight-reach', view.step),
    () => weightReach(
      view.trace.model.width,
      view.trace.model.width,
      (int out, int d) => view.trace.projection(view.checkpoint, AttentionScene.block, 2, out, d),
    ),
  );

  /// The largest of what the strings into number 1 carry from either row
  /// that goes through them, so the two are drawn on one scale.
  static double _productReach(LmView view) => view.kit.memo<double>(
    ('worked-product-reach', view.step, view.peptide, view.position),
    () {
      double most = 1e-9;
      for (final int j in <int>[view.position, ?second(view)]) {
        final List<double> row = evened(view, j);
        for (int d = 0; d < row.length; d++) {
          most = math.max(most, (_weight(view, d) * row[d]).abs());
        }
      }
      return most;
    },
  );

  /// The largest of what the places bring, never quite zero.
  static double _broughtReach(LmView view) =>
      brought(view).fold<double>(1e-9, (double most, double b) => math.max(most, b.abs()));

  // ----------------------------------------------------------------- timing

  /// How far place [j]'s cell has filled at [local]: the place in focus's and
  /// `<bos>`'s as their strings land, every other place's after, top to
  /// bottom.
  static double made(LmView view, int j, double local) {
    if (j == view.position) {
      return _ownFlow.madeAt(0, 1, local);
    }
    if (j == second(view)) {
      return _firstFlow.madeAt(0, 1, local);
    }
    final double start = _otherStart(view, j);
    return through(local, start, start + _each);
  }

  /// How far number 1 of place [j]'s value is written beside its cell.
  static double _written(LmView view, int j, double local) {
    if (j == view.position) {
      return _ownFlow.written(0, 1, local);
    }
    if (j == second(view)) {
      return _firstFlow.written(0, 1, local);
    }
    final double start = _otherStart(view, j);
    return through(local, start + 0.05, start + _each + 0.05);
  }

  /// When the cell of place [j], one of the others, starts to fill.
  static double _otherStart(LmView view, int j) {
    final int? first = second(view);
    final int count = view.position - (first == null ? 0 : 1);
    final int rank = j - (first != null && j > first ? 1 : 0);
    final double room = _others.$2 - _others.$1 - _each;
    return _others.$1 + (count < 2 ? 0 : room * rank / (count - 1));
  }

  /// How far what place [j] brings is written: one after another, top to
  /// bottom.
  static double _bringsAt(LmView view, int j, double local) {
    final double room = _brings.$2 - _brings.$1 - _each;
    final double start = _brings.$1 + (view.position < 1 ? 0 : room * j / view.position);
    return through(local, start, start + _each);
  }

  /// How far the answer's number 1 is made again, as the strings of what
  /// every place brings land in its slot.
  static double answerMade(double local) => _sumFlow.madeAt(0, 1, local);

  // ------------------------------------------------------------------ paint

  /// The frame [local] beats in.
  static void paint(Canvas canvas, Size size, LmView view, double local) {
    final WorkedLayout at = WorkedLayout(size, view);
    _strings(canvas, view, at, local);
    _copies(canvas, view, at, local);
    _table(canvas, view, at, local);
    _plate(canvas, view, at, local);
    _sum(canvas, view, at, local);
    _answers(canvas, view, at, local);
  }

  /// The value weights' strings into number 1, from each row that goes
  /// through them into its cell: lit with what they carry as the row runs
  /// through, then left faint, a weight on each, until the bench clears.
  static void _strings(Canvas canvas, LmView view, WorkedLayout at, double local) {
    final int width = view.trace.model.width;
    Offset from(int d) => at.bench.tileAt(at.bench.inputX, d, 0).centerRight;
    double weight(int out, int d) => _weight(view, d);
    for (final (WeightFlow flow, int j) in <(WeightFlow, int)>[
      (_ownFlow, view.position),
      if (second(view) case final int first) (_firstFlow, first),
    ]) {
      final double web = flow.webShown(1, local);
      if (web <= 0) {
        continue;
      }
      Offset to(int out) => at.cell(j).centerLeft;
      drawWeights(
        canvas,
        view,
        flow,
        inputs: width,
        outputs: 1,
        weight: weight,
        from: from,
        to: to,
        most: _weightReach(view),
        beat: local,
        alpha: web,
      );
      drawFans(
        canvas,
        view,
        flow,
        input: evened(view, j),
        outputs: 1,
        weight: weight,
        from: from,
        to: to,
        most: _productReach(view),
        beat: local,
        alpha: web,
      );
    }
  }

  /// The rows that go through the weights, a copy of each lifted off its row
  /// and stood up on the bench, evened: the place in focus's, then `<bos>`'s
  /// in its place, its row outlined as it lifts.
  static void _copies(Canvas canvas, LmView view, WorkedLayout at, double local) {
    final double cleared = _span(local, _benchOut);
    if (local < _liftOwn.$1 || cleared >= 1) {
      return;
    }
    final int? first = second(view);
    if (first == null) {
      _copy(canvas, view, at, view.position, local, _liftOwn, _standOwn, 1 - cleared);
      return;
    }
    // The place in focus's goes as `<bos>`'s comes into its place, so the
    // strings always start from a row; its numbers first, before `<bos>`'s
    // row crosses them.
    _copy(
      canvas,
      view,
      at,
      view.position,
      local,
      _liftOwn,
      _standOwn,
      1 - through(local, _standFirst.$1 + 0.1, _standFirst.$2),
      numbers: 1 - _span(local, _liftFirst),
    );
    final double outlined = through(local, _liftFirst.$1 - 0.15, _liftFirst.$1) * (1 - cleared);
    at.rows.table.outline(canvas, first, at.rows.stream(first, 1).right, outlined, dx: at.rows.slide(1));
    if (local >= _liftFirst.$1) {
      _copy(canvas, view, at, first, local, _liftFirst, _standFirst, 1 - cleared);
    }
  }

  /// A copy of place [j]'s row, lifted off it over [lift] and stood up over
  /// [stand] where Scores stood the row in focus, going from x0's colours to
  /// the evened row's; once standing, outlined, its numbers at its left and
  /// its place named over it.
  static void _copy(
    Canvas canvas,
    LmView view,
    WorkedLayout at,
    int j,
    double local,
    (double, double) lift,
    (double, double) stand,
    double alpha, {
    double numbers = 1,
  }) {
    if (alpha <= 0) {
      return;
    }
    final StreamTable table = at.rows.table;
    final double up = _span(local, lift);
    final double f = _span(local, stand);
    final List<double> row = evened(view, j);
    final List<double> x0 = table.values(0, j);
    final double evenScale = ScoresScene.evenScale(view);
    final List<Color> colours = <Color>[
      for (int d = 0; d < row.length; d++)
        Color.lerp(view.inks.cell(x0[d] / table.scale), view.inks.cell(row[d] / evenScale), f)!,
    ];
    final ScoresLayout bench = at.bench;
    final Rect column = bench.columnAt(bench.inputX, 0);
    if (f < 1) {
      table.strip(
        canvas,
        from: at.rows.stream(j, 1).shift(Offset(0, -table.layout.pitch * 0.55 * up)),
        to: column,
        f: f,
        colors: colours,
        alpha: (0.2 + 0.8 * up) * alpha,
        outlined: true,
      );
      return;
    }
    Rect tile(int d) => bench.tileAt(bench.inputX, d, 0);
    drawColumn(canvas, tile, <Color>[for (final Color c in colours) c.withValues(alpha: c.a * alpha)]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(column.inflate(1), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = view.inks.signal.withValues(alpha: 0.85 * alpha),
    );
    drawColumnNumbers(
      canvas,
      view,
      tile,
      row,
      through(local, stand.$2 - 0.05, stand.$2 + 0.1) * alpha * numbers,
      textSize: bench.textSize,
      writes: bench.writes,
      left: true,
    );
    drawColumnTitle(canvas, view, StreamTable.placeName(view, j), alpha, x: bench.inputX, top: column.top);
  }

  /// The table on the places' rows, up to the place in focus: number 1 of
  /// each value in its cell, written beside it; then each share before it,
  /// and what each brings after it; the places after the one in focus
  /// struck through, never read; the two places the caption names marked.
  static void _table(Canvas canvas, LmView view, WorkedLayout at, double local) {
    final double shown = _span(local, _cellsIn) * (1 - _span(local, _tableOut));
    if (shown <= 0) {
      return;
    }
    final int focus = view.position;
    final int n = view.focus.inputs;
    final List<double> numbers = values(view);
    final List<double> shares = AttentionScene.shares(view, _head);
    final List<double> each = brought(view);
    final double scale = AttentionScene.qkvScale(view, _head);
    final double sharesShown = _span(local, _sharesIn) * shown;
    if (focus < n - 1) {
      AttentionScene.hatch(
        canvas,
        view,
        Rect.fromLTRB(at.shareLeft, at.rows.table.row(focus + 1).top, at.productRight, at.rows.table.row(n - 1).bottom),
        sharesShown,
      );
    }
    final Paint slot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final Paint fill = Paint();
    TextStyle face(double alpha) => inked(view.kit.mono, at.textSize, view.inks.ink, alpha: alpha);
    for (int j = 0; j <= focus; j++) {
      final Rect cell = at.cell(j);
      final double filled = made(view, j, local);
      if (filled < 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(cell.deflate(1), const Radius.circular(1.5)),
          slot..color = view.inks.quiet.withValues(alpha: 0.6 * shown * (1 - filled)),
        );
      }
      if (filled > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(cell.deflate(0.5), const Radius.circular(1.5)),
          fill..color = Color.lerp(view.inks.ground, view.inks.signed(numbers[j] / scale), filled * shown)!,
        );
      }
      final double written = _written(view, j, local) * shown;
      if (written > 0) {
        view.kit.draw(
          canvas,
          _column(numbers[j], 2),
          face(written),
          Offset(at.valueLeft, cell.center.dy),
          anchor: const Offset(0, 0.5),
        );
      }
      if (sharesShown > 0) {
        view.kit.draw(
          canvas,
          '${tenth(shares[j])} ×',
          face(sharesShown),
          Offset(at.shareRight, cell.center.dy),
          anchor: const Offset(1, 0.5),
        );
      }
      final double brings = _bringsAt(view, j, local) * shown;
      if (brings > 0) {
        view.kit.draw(
          canvas,
          '= ${_column(each[j], 3)}',
          face(brings),
          Offset(at.productLeft, cell.center.dy),
          anchor: const Offset(0, 0.5),
        );
      }
    }
    // Named over the values' numbers, a column's heading, clear of x0's tag.
    view.kit.draw(
      canvas,
      'value 1',
      inked(view.kit.sans, 9, view.inks.quiet, alpha: shown),
      Offset(at.valueLeft, at.cell(0).top - 3),
      anchor: const Offset(0, 1),
    );
    final double marked = _span(local, _marked) * shown;
    if (marked > 0) {
      final (int most, int largest) = named(view);
      final Paint line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = view.inks.signal.withValues(alpha: 0.85 * marked);
      for (final int j in <int>{most, largest}) {
        canvas.drawRRect(RRect.fromRectAndRadius(at.line(j), const Radius.circular(2.5)), line);
      }
    }
  }

  /// The value weights named on a plate under their strings, as Scores names
  /// them, and where they stand.
  static void _plate(Canvas canvas, LmView view, WorkedLayout at, double local) {
    final double shown = _span(local, _plateIn) * (1 - _span(local, _benchOut));
    if (shown <= 0) {
      return;
    }
    final int width = view.trace.model.width;
    final String name = 'value weights · $width × $width';
    final Rect plate = at.bench.plateAt(tagSize(view, name));
    drawTag(canvas, view, name, plate.topLeft, alpha: shown);
    drawPlateStatus(
      canvas,
      view,
      plate,
      ScoresScene.weightsStatus(view),
      shown,
      left: at.bench.benchLeft,
      right: at.bench.right,
    );
  }

  /// What each place brings, a string each from where it is written into the
  /// answer's empty slot: each carries its share times its value, in that
  /// product's colour and as strong as it against the most.
  static void _sum(Canvas canvas, LmView view, WorkedLayout at, double local) {
    final double web = _sumFlow.webShown(1, local);
    if (web <= 0) {
      return;
    }
    final List<double> shares = AttentionScene.shares(view, _head);
    final Rect slot = at.bench.tileAt(at.parkX, 0, 1);
    drawFans(
      canvas,
      view,
      _sumFlow,
      input: values(view),
      outputs: 1,
      weight: (int out, int j) => shares[j],
      from: (int j) => Offset(at.productRight + 3, at.cell(j).center.dy),
      to: (int out) => slot.centerLeft,
      most: _broughtReach(view),
      beat: local,
      alpha: web,
    );
  }

  /// The heads' answers, side by side: their names and every number but the
  /// first going, the other tiles faint; to the bench's right edge, the
  /// first an empty slot, marked, until what every place brings makes it;
  /// then the rest back, and back to where they stood, named again.
  static void _answers(Canvas canvas, LmView view, WorkedLayout at, double local) {
    final double x = at.columnX(_span(local, _park) - _span(local, _unpark));
    final double faint = _span(local, _faint) * (1 - _span(local, _refill));
    final double emptied = _span(local, _empty);
    final double remade = answerMade(local);
    final double names = 1 - _span(local, _namesOut) + _span(local, _namesIn);
    final double rest = 1 - _span(local, _namesOut) + _span(local, _refill);
    final double first = (1 - emptied) + remade;
    final double firstNumber = (1 - emptied) + _sumFlow.written(0, 1, local);
    AttentionScene.drawJoined(
      canvas,
      view,
      at.bench,
      x: x,
      tile: (int d) => d == 0 ? first : 1 - 0.82 * faint,
      number: (int d) => d == 0 ? firstNumber : rest,
      title: names,
      labels: names,
    );
    final Rect slot = at.bench.tileAt(x, 0, 1);
    drawSlots(canvas, view, (int out) => slot, emptied, <double>[remade]);
    if (faint > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(slot.inflate(1.5), const Radius.circular(2.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = view.inks.signal.withValues(alpha: 0.85 * faint),
      );
    }
  }

  // --------------------------------------------------------------- captions

  /// A share as the table writes it: a percentage to a tenth, always, so a
  /// share times its value reads right.
  static String tenth(double share) => '${(share * 100).toStringAsFixed(1)}%';

  /// A term of the sum to [digits] places, its sign always shown, as the
  /// terms of a sum are; but no sign on one that rounds to nothing, as
  /// [fixed] writes it: `+0.007`, `−1.22`, `0.000`.
  static String term(double value, int digits) =>
      double.parse(value.abs().toStringAsFixed(digits)) == 0 ? fixed(value, digits) : signed(value, digits);

  /// [term] in a column of them: one that rounds to nothing takes a space
  /// where the others have their sign, so the points line up.
  static String _column(double value, int digits) {
    final String text = term(value, digits);
    return text.startsWith('+') || text.startsWith('−') ? text : ' $text';
  }

  /// Why each part happens, over the table, a line a thought, in beats from
  /// its start.
  static List<(double, double, String)> notes(LmView view) {
    final int width = view.trace.model.width;
    final double summed = _sumFlow.fanAt(0, 1).$1;
    return <(double, double, String)>[
      (
        0,
        _benchOut.$1,
        "a value is made as a query is: a place's evened row × weights\n"
            'the value weights are one $width × $width, the same for every place',
      ),
      (
        _benchOut.$1,
        summed,
        'the shares are weights too, made fresh at each place\n'
            'from its query and the keys, not learned like the matrices',
      ),
      (
        summed,
        beats,
        'the shares add to 100%: the sum is an average of the values\n'
            "number by number: answer number 1 mixes only the values' 1s",
      ),
    ];
  }

  /// The caption [local] beats in.
  static String caption(LmView view, double local) {
    final TrainingTrace trace = view.trace;
    final int width = trace.model.width;
    final int focus = view.position;
    final int? first = second(view);
    final List<double> numbers = values(view);
    // Its bias, where training has given it one: every bias starts at 0.
    final String bias = trace.projectionBias(view.checkpoint, AttentionScene.block, 2, _head) != 0 ? ', + bias' : '';
    if (local < _liftOwn.$1) {
      return "Number 1 of head 1's answer, ${fixed(answer(view), 2)}, worked out";
    }
    if (first == null ? local < _sharesIn.$1 : local < _liftFirst.$1) {
      return "${StreamTable.placeName(view, focus)}'s value 1, as in Scores: "
          'its row × $width weights$bias: ${term(numbers[focus], 2)}';
    }
    if (first != null && local < _benchOut.$1) {
      return "${StreamTable.placeName(view, first)}'s value 1: its own row, "
          'the same $width weights$bias: ${term(numbers[first], 2)}';
    }
    if (local < _sharesIn.$1) {
      return 'Every place the same: its own row, the same weights';
    }
    if (local < _sumFlow.fanAt(0, 1).$1) {
      return _bringsCaption(view);
    }
    if (local < _tableOut.$1) {
      return "Summed: ${fixed(answer(view), 2)}, number 1 of head 1's answer";
    }
    return 'Numbers 2–$width the same way, each head with its own shares';
  }

  /// What the places bring, share times value: the one that brings most and
  /// the one read most, which need not be the same place.
  static String _bringsCaption(LmView view) {
    final List<double> each = brought(view);
    if (each.length == 1) {
      return 'Share × value: ${StreamTable.placeName(view, 0)} alone, 100%, brings ${term(each[0], 3)}';
    }
    final (int most, int largest) = named(view);
    final String mostName = StreamTable.placeName(view, most);
    if (most == largest) {
      return 'Share × value: $mostName, read most, also brings most: ${term(each[most], 3)}';
    }
    return 'Share × value: $mostName brings most, ${term(each[most], 3)}; '
        '${StreamTable.placeName(view, largest)}, read most, ${term(each[largest], 3)}';
  }
}

/// Where number 1 of head 1's answer is worked out: on Scores' bench, the
/// rows standing where Scores stood the row in focus; on the table's rows,
/// at the place's row, each value's cell where Scores stood the query, its
/// share written before it and what it brings after it; the answers'
/// column at the bench's right edge.
final class WorkedLayout {
  WorkedLayout(Size size, LmView view) : bench = ScoresLayout(size, view) {
    textSize = rows.textSize;
    final TextStyle face = inked(view.kit.mono, textSize, view.inks.ink);
    double wide(String text) => view.kit.layout(text, face).width;
    valueX = bench.outputX[0];
    shareRight = valueX - bench.column / 2 - 4;
    shareLeft = shareRight - wide('100.0% ×');
    valueLeft = valueX + bench.column / 2 + 4;
    productLeft = valueLeft + wide('+8.88') + 8;
    productRight = productLeft + wide('= +8.888');
    parkX = bench.right - bench.column / 2 - 2;
  }

  final ScoresLayout bench;

  /// Attention's canvas, which the bench is laid on.
  AttentionLayout get rows => bench.attention;

  /// The size the table's numbers are written at: Attention's, on the rows.
  late final double textSize;

  /// The values' cells' middle; where the shares end and start; where the
  /// values' numbers start; where what each brings starts and ends.
  late final double valueX;
  late final double shareRight;
  late final double shareLeft;
  late final double valueLeft;
  late final double productLeft;
  late final double productRight;

  /// Where the answers' column stands at the bench's right edge.
  late final double parkX;

  /// Number 1 of place [j]'s value: its cell on the place's row.
  Rect cell(int j) {
    final Rect band = rows.kv(j);
    return Rect.fromLTRB(valueX - bench.column / 2, band.top, valueX + bench.column / 2, band.bottom);
  }

  /// Place [j]'s line of the table, from its share to what it brings.
  Rect line(int j) {
    final Rect band = rows.kv(j);
    return Rect.fromLTRB(shareLeft - 3, band.top, productRight + 3, band.bottom);
  }

  /// Where the answers' column stands, [park] of the way from where it stood
  /// to the bench's right edge.
  double columnX(double park) => bench.inputX + (parkX - bench.inputX) * park;
}
