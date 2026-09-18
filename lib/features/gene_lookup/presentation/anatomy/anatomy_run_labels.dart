import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import 'anatomy_layout.dart';
import 'anatomy_stages.dart';

/// How big a name sets at a size: its width and its line height.
typedef MeasureLabel = Size Function(String text, double size);

/// One run of the gene, named on the band it fits.
///
/// A name that would not fit used to be set *beside* its run instead, in a pill
/// with a leader back to it. A pill dodged every other name and every other
/// pill, but nothing stopped it landing on another run: p53's third exon was
/// named over the fourth, myoglobin's 3' UTR over its last exon. A name written
/// on the wrong colour is that colour's name, and a reader has no way to know
/// otherwise. So a name now shrinks, and then abbreviates, until it fits the
/// shape it belongs to — and where even the shortest form of it will not reach
/// [runLabelFloor] inside the run's own cells the name goes unsaid, which costs
/// nothing a tap does not answer.
@immutable
final class RunLabel {
  const RunLabel({
    required this.run,
    required this.text,
    required this.size,
    required this.rect,
  });

  /// Index into [AnatomyStage.runs].
  final int run;

  /// Which of [StageRun.writtenForms] was set.
  final String text;

  /// The point size it was set at.
  final double size;

  /// The type's own box, which lies inside the run's own cells.
  final Rect rect;
}

/// The gene page's runs, named.
@immutable
final class RunLabelPlan {
  const RunLabelPlan(this.labels);

  /// In run order, and shorter than the run list wherever a run went unnamed.
  final List<RunLabel> labels;

  static final Expando<RunLabelPlan> _cache = Expando<RunLabelPlan>();

  /// The plan for [stage] in [layout], set in the app's own type.
  ///
  /// Cached on the layout, which is immutable and rebuilt whenever anything the
  /// plan depends on changes. The canvas it is drawn into no longer comes into
  /// it: a name is placed against its own run's cells and nothing else, so two
  /// pages of the same layout name their runs identically however tall the
  /// canvas around them is.
  static RunLabelPlan of(AnatomyStage stage, AnatomyLayout layout) {
    final RunLabelPlan? cached = _cache[layout];
    if (cached != null) {
      return cached;
    }
    final RunLabelPlan plan = RunLabelPlan(
      planRunLabels(stage, layout, measureLabel),
    );
    _cache[layout] = plan;
    return plan;
  }
}

/// The style every run name is set in. The painter builds its paragraphs from
/// this too, so a name is measured in exactly the type it is drawn in.
ui.ParagraphBuilder runLabelBuilder(double size, Color ink) =>
    ui.ParagraphBuilder(
      ui.ParagraphStyle(fontFamily: AppTypography.sansFamily, fontSize: size),
    )..pushStyle(
      ui.TextStyle(color: ink, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    );

Size measureLabel(String text, double size) {
  final ui.Paragraph paragraph = (runLabelBuilder(size, const Color(0xFF000000))
        ..addText(text))
      .build()
    ..layout(const ui.ParagraphConstraints(width: double.infinity));
  final Size measured = Size(paragraph.maxIntrinsicWidth, paragraph.height);
  paragraph.dispose();
  return measured;
}

/// A name is sized by how much gene it names — the square root of the run's
/// length, so the type scales with the run's *side* rather than its area and
/// a run fifty times larger gets a label seven times bigger, not fifty. Both
/// ends are clamped: below the floor a name stops being readable, and above
/// the ceiling it stops being a label and becomes a headline.
///
/// This is what a run *earns*. Eleven points is the size every run under 121
/// cells is given, and at [AnatomyLayout.geneRow] a one-row run has thirteen
/// points to give, so it is a readable size rather than merely the largest an
/// eleven point row could hold.
const double runLabelMin = 11;
const double runLabelMax = 28;

/// The smallest a name may be cut to when it is the run's *width* doing the
/// squeezing.
///
/// Eleven points is what a run earns; eight is what it may be cut to rather
/// than be written somewhere it does not belong. p53's columns are about two
/// points wide, so a fifteen-base region has thirty points of row to write
/// across, and `E3` at eight points asks for ten of them. Under eight a name
/// stops being read and starts being a texture, and a run that cannot reach
/// even this is better left to the tap that names it.
const double runLabelFloor = 8;

const double _labelInset = 5;

/// The air either side of a name inside its run, which is [_labelInset] at the
/// size a run earns and shrinks with the type below it.
///
/// Five points is a tenth of a wide run and half of a narrow one. A name cut to
/// eight points is already conceding that the run is tight; charging it the
/// full inset as well would take back most of what the cut bought.
double _insetFor(double size) =>
    _labelInset * (size / runLabelMin).clamp(0.0, 1.0);

/// How much of a run's height its name may take.
const double _labelFill = 0.8;

/// Every run of [stage] in [layout], named.
///
/// One pass, and no arrangement: every name lies inside its own run's cells and
/// runs are disjoint, so two names can no more collide than two runs can.
List<RunLabel> planRunLabels(
  AnatomyStage stage,
  AnatomyLayout layout,
  MeasureLabel measure,
) {
  final List<StageRun> runs = stage.runs;
  if (runs.isEmpty || layout.columns <= 0 || layout.cell <= 0) {
    return const <RunLabel>[];
  }

  final Map<(String, double), Size> sizes = <(String, double), Size>{};
  Size measured(String text, double size) =>
      sizes.putIfAbsent((text, size), () => measure(text, size));

  final List<RunLabel> labels = <RunLabel>[];
  for (int i = 0; i < runs.length; i++) {
    final RunLabel? label = _label(
      layout,
      runs[i],
      i,
      _Widest.of(layout, runs[i]),
      measured,
    );
    if (label != null) {
      labels.add(label);
    }
  }
  return List<RunLabel>.unmodifiable(labels);
}

/// A run's widest row, and where there are several of equal width — a tall
/// run is mostly full rows — the middle one, so the name sits in the body of
/// the shape rather than along its top edge.
///
/// That is not merely where there is room: it is the row that shows the run at
/// its fullest, so the label lands on the part of the shape a reader was
/// already looking at.
final class _Widest {
  const _Widest(this.row, this.firstRow, this.lastRow, this.a, this.b);

  factory _Widest.of(AnatomyLayout layout, StageRun run) {
    final int last = run.start + run.count - 1;
    final int firstRow = run.start ~/ layout.columns;
    final int lastRow = last ~/ layout.columns;
    int widest = -1;
    final List<int> candidates = <int>[];
    for (int row = firstRow; row <= lastRow; row++) {
      final int lo = math.max(row * layout.columns, run.start);
      final int hi = math.min(row * layout.columns + layout.columns - 1, last);
      if (hi - lo > widest) {
        widest = hi - lo;
        candidates
          ..clear()
          ..add(row);
      } else if (hi - lo == widest) {
        candidates.add(row);
      }
    }
    final int row = candidates[candidates.length ~/ 2];
    final int bestLo = math.max(row * layout.columns, run.start);
    final int bestHi = math.min(
      row * layout.columns + layout.columns - 1,
      last,
    );
    // The row runs right to left on an odd row, so the span is the two ends
    // whichever way round they came.
    return _Widest(
      row,
      firstRow,
      lastRow,
      layout.centreOf(bestLo),
      layout.centreOf(bestHi),
    );
  }

  final int row;
  final int firstRow;
  final int lastRow;
  final Offset a;
  final Offset b;

  double get centreX => (a.dx + b.dx) / 2;
}

/// The mildest form of [run]'s name that fits inside it, set as large as the
/// shape allows.
///
/// The forms come longest first, so a run wide enough for `exon 3` is never
/// given `E3`: the page abbreviates exactly as much as the shape demands and no
/// further.
RunLabel? _label(
  AnatomyLayout layout,
  StageRun run,
  int index,
  _Widest widest,
  Size Function(String, double) measured,
) {
  final double room = (widest.a.dx - widest.b.dx).abs() + layout.cell;
  if (room <= 0) {
    return null;
  }

  // ...but never taller than the run itself: a name has to sit inside the
  // shape it names, and a one-row run has only that row to give.
  final double earned = math.min(
    math.sqrt(run.count).clamp(runLabelMin, runLabelMax),
    (widest.lastRow - widest.firstRow + 1) * layout.rowHeight * _labelFill,
  );

  for (final String text in run.writtenForms) {
    if (text.isEmpty) {
      continue;
    }
    final RunLabel? label = _set(
      layout,
      run,
      index,
      widest,
      text,
      earned,
      room,
      measured,
    );
    if (label != null) {
      return label;
    }
  }
  return null;
}

/// [text] set inside [run], or null where it cannot be set there at all.
///
/// Three constraints that each move the other two: the row's width, the depth
/// of the band the name actually reaches, and the size. Shrinking for width
/// narrows the name, which lets it reach rows it could not before, which deepens
/// the band and may let it keep its height after all. The size only ever falls
/// and the band only ever grows, so this settles — on the first pass for almost
/// every run of every gene in the catalog, and four is a bound rather than a
/// budget.
RunLabel? _set(
  AnatomyLayout layout,
  StageRun run,
  int index,
  _Widest widest,
  String text,
  double earned,
  double room,
  Size Function(String, double) measured,
) {
  double size = earned;
  for (int pass = 0; pass < 4; pass++) {
    size = _widthFit(text, size, room, measured);
    if (size < runLabelFloor) {
      return null;
    }
    final Size type = measured(text, size);

    // The band stops at the first row too narrow to hold the name. That is
    // not tidiness — a name overhanging the run above or below is over a
    // different colour, and its ink was chosen against this one.
    final double half = type.width / 2 + _insetFor(size);
    int top = widest.row;
    int bottom = widest.row;
    while (top > widest.firstRow &&
        _rowHolds(layout, run, top - 1, widest.centreX, half)) {
      top--;
    }
    while (bottom < widest.lastRow &&
        _rowHolds(layout, run, bottom + 1, widest.centreX, half)) {
      bottom++;
    }

    final double depth = (bottom - top + 1) * layout.rowHeight;
    if (type.height <= depth) {
      // Dead centre of the band the name fits in, rather than of the one row
      // it was measured against. A run two rows deep is centred on the seam
      // between them and a run three rows deep on the middle one.
      final double centreY =
          (_rowCentre(layout, run, top) + _rowCentre(layout, run, bottom)) / 2;
      return RunLabel(
        run: index,
        text: text,
        size: size,
        rect: Rect.fromCenter(
          center: Offset(widest.centreX, centreY),
          width: type.width,
          height: type.height,
        ),
      );
    }

    // Too tall for the band it got. Set it again at the size that band can
    // hold and go round: the smaller type is narrower too, and may reach a row
    // it could not before.
    //
    // Four fifths of the band is what a name is meant to take, but on a row of
    // 14.1 points an eleven point name already sets 14.0, and cutting to four
    // fifths of a band it very nearly fills is a step it can take for ever
    // without ever landing. So the height it actually measured decides the cut
    // wherever that asks for less: line height is linear in point size, so one
    // step lands.
    final double shorter = _down(
      math.min(depth * _labelFill, size * depth / type.height),
    );
    if (shorter >= size) {
      return null;
    }
    size = shorter;
  }
  return null;
}

/// The largest size at or under [size] that sets [text] inside [room], or zero
/// where no size down to [runLabelFloor] does.
///
/// A name's width is all but linear in its point size, so one scaling lands
/// within a fraction of a point and a second confirms it; three passes is a
/// bound rather than a budget. Sizes step down in tenths of a point — down, so
/// that a size this settles on always fits rather than very nearly fits, and in
/// tenths so that the memo here and the painter's paragraph cache agree on one
/// key per name.
double _widthFit(
  String text,
  double size,
  double room,
  Size Function(String, double) measured,
) {
  for (int pass = 0; pass < 3; pass++) {
    final double air = room - 2 * _insetFor(size);
    if (air <= 0) {
      return 0;
    }
    final double width = measured(text, size).width;
    if (width <= air) {
      return size;
    }
    final double next = _down(size * air / width);
    if (next >= size || next < runLabelFloor) {
      return 0;
    }
    size = next;
  }
  return measured(text, size).width <= room - 2 * _insetFor(size) ? size : 0;
}

/// A point size taken down to the tenth below it.
double _down(double size) => (size * 10).floorToDouble() / 10;

/// The y of one of [run]'s rows.
double _rowCentre(AnatomyLayout layout, StageRun run, int row) =>
    layout.centreOf(math.max(row * layout.columns, run.start)).dy;

/// Whether [row] of [run] is wide enough to hold a name of half-width [half]
/// centred on [centreX].
///
/// The row runs right to left when it is odd, so its two ends are taken
/// whichever way round they came.
bool _rowHolds(
  AnatomyLayout layout,
  StageRun run,
  int row,
  double centreX,
  double half,
) {
  final int lo = math.max(row * layout.columns, run.start);
  final int hi = math.min(
    row * layout.columns + layout.columns - 1,
    run.start + run.count - 1,
  );
  final double x = layout.centreOf(lo).dx;
  final double y = layout.centreOf(hi).dx;
  return centreX - half >= math.min(x, y) - layout.cell / 2 &&
      centreX + half <= math.max(x, y) + layout.cell / 2;
}
