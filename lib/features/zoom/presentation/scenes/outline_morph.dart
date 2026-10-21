import 'dart:ui';

import 'contour.dart';

/// The body's outline of an organ drawn in toward the outline of the organ
/// as its scene draws it from anatomy, and on toward the bed the organ lies
/// on: how an organ drawn as a specimen of its own takes over the very
/// outline the body drew (`PancreasForm`).
///
/// The two outlines are met at two places they both have, their topmost
/// point and their leftmost (or, for two tall ones, their bottommost), and
/// laid with as many points between those as each is long, so the one
/// draws in to the other without turning inside out.
final class OutlineMorph {
  /// [template] is the organ's own outline and [diagram] the body's, each
  /// followed closely and both the same way round; [diagramPath] is the
  /// very curve the body draws its outline by. The morph is laid with
  /// [count] points, and the bed lies [bed] in from the organ's outline.
  /// The two are met at their tops and their leftmost points, or their
  /// bottommost where [bottoms]; or, where [marks] are given, at their tops
  /// and at the point each mark picks out of either outline, so that an
  /// organ much longer round one part than the body draws it (a femur's
  /// head) draws in part by part, no point sliding round from one part to
  /// the next.
  OutlineMorph({
    required List<Offset> template,
    required List<Offset> diagram,
    required this.diagramPath,
    required int count,
    required double bed,
    bool bottoms = false,
    List<int Function(List<Offset>)> marks =
        const <int Function(List<Offset>)>[],
  }) {
    _inward = _area(template) > 0 ? 1.0 : -1.0;
    if (marks.isNotEmpty) {
      final List<int> counts = _counts(
        template,
        _marked(template, marks),
        count,
      );
      _template = _segmented(template, _marked(template, marks), counts);
      _diagram = _segmented(diagram, _marked(diagram, marks), counts);
      _bed = _inset(_template, bed);
      return;
    }
    final (List<Offset> along, List<Offset> round) = _halves(
      template,
      bottoms: bottoms,
    );
    final double first = _length(along);
    final double second = _length(round);
    final int a = (count * first / (first + second)).round();
    final int b = count - a;
    _template = _matched(template, a, b, bottoms: bottoms);
    _diagram = _matched(diagram, a, b, bottoms: bottoms);
    _bed = _inset(_template, bed);
  }


  /// The body's outline of the organ, as the step from the body hands it
  /// over.
  final Path diagramPath;

  /// Which way into the organ the outline's left hand points: 1 or -1.
  late final double _inward;

  late final List<Offset> _template;
  late final List<Offset> _diagram;
  late final List<Offset> _bed;

  /// The outline the step from the body draws: the body's own at [settle]
  /// 0, the organ's at 1, drawn in by [bed] toward the bed it lies on.
  List<Offset> at(double settle, {double bed = 0}) {
    if (settle <= 0) {
      return _diagram;
    }
    return <Offset>[
      for (int i = 0; i < _template.length; i++)
        Offset.lerp(
          _diagram[i],
          bed <= 0 ? _template[i] : Offset.lerp(_template[i], _bed[i], bed)!,
          settle,
        )!,
    ];
  }

  /// The path [at] draws: at [settle] 0 the very curve the body's outline
  /// is drawn by.
  Path pathAt(double settle, {double bed = 0}) => settle <= 0
      ? diagramPath
      : Contour(at(settle, bed: bed)).toPath();

  /// [points] drawn in by [by] toward the inside of the outline they go
  /// round, which runs the way the organ's does.
  List<Offset> _inset(List<Offset> points, double by) {
    final int n = points.length;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t = points[(i + 1) % n] - points[(i - 1 + n) % n];
          final double length = t.distance;
          if (length <= 0) {
            return points[i];
          }
          return points[i] + Offset(-t.dy, t.dx) / length * (by * _inward);
        }(),
    ];
  }

  /// [points] cut at their topmost point and their leftmost, or their
  /// bottommost where [bottoms]: the way round from the first to the
  /// second, and on back to the first.
  static (List<Offset>, List<Offset>) _halves(
    List<Offset> points, {
    required bool bottoms,
  }) {
    final int n = points.length;
    int top = 0;
    int left = 0;
    for (int i = 1; i < n; i++) {
      if (points[i].dy < points[top].dy) {
        top = i;
      }
      if (bottoms
          ? points[i].dy > points[left].dy
          : points[i].dx < points[left].dx) {
        left = i;
      }
    }
    final List<Offset> first = <Offset>[];
    for (int i = top; ; i = (i + 1) % n) {
      first.add(points[i]);
      if (i == left) {
        break;
      }
    }
    final List<Offset> second = <Offset>[];
    for (int i = left; ; i = (i + 1) % n) {
      second.add(points[i]);
      if (i == top) {
        break;
      }
    }
    return (first, second);
  }

  /// [points], a closed outline, as [a] points evenly along it from its top
  /// to its leftmost point, or its bottommost where [bottoms], and [b] on
  /// round to its top again.
  static List<Offset> _matched(
    List<Offset> points,
    int a,
    int b, {
    required bool bottoms,
  }) {
    final (List<Offset> first, List<Offset> second) = _halves(
      points,
      bottoms: bottoms,
    );
    return <Offset>[..._even(first, a), ..._even(second, b)];
  }

  /// Where [points], a closed outline, is met: its topmost point, then the
  /// point each of [marks] picks out of it, in their order round it from
  /// the top.
  static List<int> _marked(
    List<Offset> points,
    List<int Function(List<Offset>)> marks,
  ) {
    final int n = points.length;
    int top = 0;
    for (int i = 1; i < n; i++) {
      if (points[i].dy < points[top].dy) {
        top = i;
      }
    }
    final List<int> at = <int>[
      top,
      for (final int Function(List<Offset>) mark in marks) mark(points),
    ];
    assert(at.every((int i) => i >= 0 && i < n), 'a mark outside $n points');
    return at..sort((int a, int b) => ((a - top) % n).compareTo((b - top) % n));
  }

  /// How many points each part of [points] between two of the places [at]
  /// is laid with, of [count] in all: as many as it is long.
  static List<int> _counts(List<Offset> points, List<int> at, int count) {
    final List<double> lengths = <double>[
      for (int k = 0; k < at.length; k++)
        _length(_between(points, at[k], at[(k + 1) % at.length])),
    ];
    final double total = lengths.fold(0, (double a, double b) => a + b);
    final List<double> shares = <double>[
      for (final double length in lengths) count * length / total,
    ];
    final List<int> out = <int>[
      for (final double share in shares) share.floor(),
    ];
    // The points the rounding left over, to the parts it took most from.
    final List<int> order = <int>[for (int k = 0; k < at.length; k++) k]
      ..sort(
        (int a, int b) => (shares[b] - out[b]).compareTo(shares[a] - out[a]),
      );
    for (int k = 0; out.fold(0, (int a, int b) => a + b) < count; k++) {
      out[order[k % order.length]]++;
    }
    return out;
  }

  /// [points], a closed outline, laid part by part between the places [at],
  /// each with its share of [counts].
  static List<Offset> _segmented(
    List<Offset> points,
    List<int> at,
    List<int> counts,
  ) => <Offset>[
    for (int k = 0; k < at.length; k++)
      ..._even(_between(points, at[k], at[(k + 1) % at.length]), counts[k]),
  ];

  /// [points], a closed outline, from index [from] round to index [to].
  static List<Offset> _between(List<Offset> points, int from, int to) {
    final int n = points.length;
    final List<Offset> out = <Offset>[points[from]];
    for (int i = (from + 1) % n; ; i = (i + 1) % n) {
      out.add(points[i]);
      if (i == to) {
        return out;
      }
    }
  }

  /// [count] points evenly along the open line [points], from its first
  /// point and short of its last.
  static List<Offset> _even(List<Offset> points, int count) {
    final List<double> along = <double>[0];
    for (int i = 1; i < points.length; i++) {
      along.add(along.last + (points[i] - points[i - 1]).distance);
    }
    final double total = along.last;
    final List<Offset> out = <Offset>[];
    int j = 1;
    for (int k = 0; k < count; k++) {
      final double at = total * k / count;
      while (j < points.length - 1 && along[j] < at) {
        j++;
      }
      final double span = along[j] - along[j - 1];
      final double t = span <= 0 ? 0 : (at - along[j - 1]) / span;
      out.add(Offset.lerp(points[j - 1], points[j], t)!);
    }
    return out;
  }

  static double _length(List<Offset> points) {
    double sum = 0;
    for (int i = 1; i < points.length; i++) {
      sum += (points[i] - points[i - 1]).distance;
    }
    return sum;
  }

  static double _area(List<Offset> points) {
    double sum = 0;
    for (int i = 0; i < points.length; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % points.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum / 2;
  }
}
