import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../voronoi.dart';
import 'tongue_anatomy.dart';
import 'tongue_style.dart';

/// The tongue as the zoom's organ scene draws it: cut across at the lower
/// first molars between the two halves of its mandible, every part in the
/// scene's units at its real size, the middle of the body's outline of it
/// at the origin.
///
/// It is drawn in its own frame ([TongueAnatomy]) and laid on the body's
/// outline of it, the anatomogram's mouth, which stands in for the tongue
/// the figure does not draw, so that the place it is gone into in the
/// anatomy ([TongueAnatomy.site]) lies on the place the body goes in
/// ([site]). The figure is drawn at a person's size, and so is the tongue
/// ([real]): the step from the body draws the body's outline in toward the
/// outline of the soft tissue between the mandible's halves ([pathAt]). The
/// intrinsic muscle is where the zoom's cell lives, whatever the cell: the
/// myonucleus is the one cell the Atlas names with the tongue as its home.
/// Everything here is geometry: what it is drawn in is `TongueArt`'s.
final class TongueForm {
  TongueForm({
    required List<Offset> diagram,
    required this.site,
    required this.view,
  }) : scale = real * 0.001 / view {
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(TongueStyle.outlineSpan)
        .points;
    final List<Offset> placed = _placed(_softMm);
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(placed).sign != _area(diagramDense).sign
        ? placed.reversed.toList()
        : placed;
    outlinePoints = template;
    outline = Path()..addPolygon(template, true);
    box = _bounds(template);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: template,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: TongueStyle.morphPoints,
      bed: mm(TongueStyle.bed),
      marks: marks,
      start: topMiddle,
    );
  }

  /// The tongue where the body draws it as [part], in a view [view] metres
  /// across.
  factory TongueForm.place({required AnatomyPart part, required double view}) {
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return TongueForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      view: view,
    );
  }

  /// How many times the size the body draws it at the tongue really is:
  /// the figure is drawn at a person's size, and its mouth about as wide as
  /// a tongue.
  static const double real = 1;

  /// Where the body goes into the tongue, in the scene: its transverse
  /// fibres on the body's right.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The soft tissue's outline, the points it is followed by and its box:
  /// what the step from the body draws in to.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - TongueAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => TongueAnatomy.site + (p - site) / scale;

  /// How far the soft tissue's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  List<List<Offset>> _placedAll(List<List<Offset>> lines) => <List<Offset>>[
    for (final List<Offset> l in lines) _placed(l),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the soft tissue's at 1, and [bed] of the way on toward the
  /// bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the soft tissue's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // Where the step from the body meets the two outlines.

  /// The point at the middle of an outline's top: the median sulcus on the
  /// tongue's back, the top of the body's oval.
  static int topMiddle(List<Offset> points) =>
      _middleOf(points, from: 0, to: 0.25);

  /// The point at the middle of an outline's foot: the mylohyoid's raphe,
  /// the foot of the body's oval.
  static int bottomMiddle(List<Offset> points) =>
      _middleOf(points, from: 0.75, to: 1);

  static int _middleOf(
    List<Offset> points, {
    required double from,
    required double to,
  }) {
    final Rect b = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      final double down = (points[i].dy - b.top) / b.height;
      if (down < from || down > to) {
        continue;
      }
      if (best < 0 ||
          (points[i].dx - b.center.dx).abs() <
              (points[best].dx - b.center.dx).abs()) {
        best = i;
      }
    }
    return best;
  }

  /// The places the two outlines are met at after the top: the tongue's
  /// margins, the outermost points in an outline's upper third, and the
  /// middle of its foot.
  static final List<int Function(List<Offset>)> marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0, 0.3),
        bottomMiddle,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0, 0.3),
      ];

  /// The points of the soft tissue's own outline where the step from the
  /// body meets the body's, for tests: the top's middle, then the rest in
  /// the order round it from there.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[topMiddle(points)],
    for (final int Function(List<Offset>) mark in marks) points[mark(points)],
  ];

  // The anatomy in millimetres, built once for every tongue.

  /// The soft tissue's outline, both halves, followed closely.
  static final List<Offset> _softMm = Contour(_whole(TongueAnatomy.soft))
      .sampled(TongueStyle.outlineSpan)
      .points;

  /// The tongue's free surface, followed closely, from where it meets the
  /// floor on the body's right over its back to where it meets it on the
  /// body's left; how far along it each point lies from the middle of the
  /// back, on its own side; and which way is into the tongue at each.
  static final List<Offset> _surfaceMm = () {
    final List<Offset> right = _open(TongueAnatomy.surface);
    return <Offset>[
      for (final Offset p in right.reversed) Offset(-p.dx, p.dy),
      ...right.skip(1),
    ];
  }();
  static final List<double> _fromBack = () {
    final List<Offset> right = _open(TongueAnatomy.surface);
    final List<double> along = <double>[0];
    for (int i = 1; i < right.length; i++) {
      along.add(along.last + (right[i] - right[i - 1]).distance);
    }
    return <double>[...along.reversed, ...along.skip(1)];
  }();
  static final List<Offset> _inwardMm = <Offset>[
    for (int i = 0; i < _surfaceMm.length; i++)
      () {
        final Offset t =
            _surfaceMm[math.min(_surfaceMm.length - 1, i + 1)] -
            _surfaceMm[math.max(0, i - 1)];
        final double length = t.distance;
        return length <= 0 ? Offset.zero : Offset(-t.dy, t.dx) / length;
      }(),
  ];

  /// How far along the surface the back's margin lies, and where along it
  /// the side meets the molar's crown, and where the underside ends.
  static final double _marginAlong = _alongKnot(TongueAnatomy.back - 1);
  static final double _crownAlong = _alongKnot(TongueAnatomy.crown);
  static final double _undersideEnd = _alongKnot(
    TongueAnatomy.surface.length - 1,
  );

  static double _alongKnot(int knot) {
    final List<Offset> right = _open(TongueAnatomy.surface);
    final Offset target = TongueAnatomy.surface[knot];
    double along = 0;
    double best = double.infinity;
    double at = 0;
    for (int i = 0; i < right.length; i++) {
      if (i > 0) {
        along += (right[i] - right[i - 1]).distance;
      }
      final double d = (right[i] - target).distance;
      if (d < best) {
        best = d;
        at = along;
      }
    }
    return at;
  }

  /// How much of the back's thickness a point of the surface [along] it
  /// from the middle has: 1 over the back, 0 down its side.
  static double _backShare(double along) =>
      1 - _smooth((along - (_marginAlong - 4)) / 4);

  /// How deep under the surface the intrinsic muscle begins.
  static double _muscleDepth(double along) {
    final double back = _backShare(along);
    return back * (TongueAnatomy.mucosaBack + TongueAnatomy.aponeurosis) +
        (1 - back) * TongueAnatomy.mucosaSide;
  }

  /// How thick the superior longitudinal layer is under a point of the
  /// back [x] from the midline.
  static double _superiorAt(double x) {
    final double a = x.abs();
    if (a <= TongueAnatomy.superiorKeeps) {
      return TongueAnatomy.superior;
    }
    final double t =
        (a - TongueAnatomy.superiorKeeps) /
        (TongueAnatomy.superiorEnds - TongueAnatomy.superiorKeeps);
    return TongueAnatomy.superior * (1 - _smooth(t));
  }

  /// The surface drawn in by [depth] millimetres at each point, over the
  /// points where [keep] holds.
  static List<Offset> _under(
    double Function(int) depth, {
    bool Function(int)? keep,
  }) => <Offset>[
    for (int i = 0; i < _surfaceMm.length; i++)
      if (keep == null || keep(i)) _surfaceMm[i] + _inwardMm[i] * depth(i),
  ];

  /// The intrinsic muscle's top, over the back and down the sides to the
  /// hyoglossus.
  static double _sheetStartAlong() =>
      _crownAlong + (_undersideEnd - _crownAlong) * TongueAnatomy.sheetFrom;
  static double _sheetEndAlong() =>
      _crownAlong + (_undersideEnd - _crownAlong) * TongueAnatomy.sheetTo;

  /// The intrinsic muscle: under the back's mucosa and aponeurosis, in from
  /// the margins' mucosa, inside the hyoglossus, over the genioglossus.
  static final List<Offset> _homeMm = () {
    final double start = _sheetStartAlong();
    final double end = _sheetEndAlong();
    const double inner = TongueAnatomy.sheetIn + TongueAnatomy.sheet;
    final List<Offset> right = <Offset>[];
    final int middle = _surfaceMm.length ~/ 2;
    for (int i = middle; i < _surfaceMm.length; i++) {
      final double along = _fromBack[i];
      if (along > end) {
        break;
      }
      final double depth = along < start
          ? _muscleDepth(along)
          : _muscleDepth(along) +
                (inner - _muscleDepth(along)) * _smooth((along - start) / 1.2);
      right.add(_surfaceMm[i] + _inwardMm[i] * depth);
    }
    right.addAll(_open(TongueAnatomy.intrinsicFloor).skip(1));
    return _whole(right);
  }();

  /// The superior longitudinal layer: under the muscle's top over the back.
  static final List<Offset> _superiorMm = () {
    bool back(int i) =>
        _fromBack[i] <= _marginAlong &&
        _surfaceMm[i].dx.abs() <= TongueAnatomy.superiorEnds;
    final List<Offset> top = _under(
      (int i) => _muscleDepth(_fromBack[i]),
      keep: back,
    );
    final List<Offset> bottom = _under(
      (int i) => _muscleDepth(_fromBack[i]) + _superiorAt(_surfaceMm[i].dx),
      keep: back,
    );
    return <Offset>[...top, ...bottom.reversed];
  }();

  /// The superior longitudinal layer's foot at [x] from the midline.
  static double superiorFoot(double x) {
    final int middle = _surfaceMm.length ~/ 2;
    for (int i = middle; i < _surfaceMm.length - 1; i++) {
      final Offset a = _surfaceMm[i];
      final Offset b = _surfaceMm[i + 1];
      if (a.dx <= x.abs() && b.dx > x.abs()) {
        return (a.dy + b.dy) / 2 + _muscleDepth(_fromBack[i]) + _superiorAt(x);
      }
    }
    return TongueAnatomy.superior;
  }

  /// The hyoglossus and the styloglossus along each underside: the
  /// styloglossus outside, the hyoglossus inside it.
  static List<Offset> _sheetMm(double from, double to) {
    final double start = _sheetStartAlong();
    final double end = _sheetEndAlong();
    bool on(int i) =>
        _surfaceMm[i].dx > 0 && _fromBack[i] >= start && _fromBack[i] <= end;
    final List<Offset> outer = _under((int _) => from, keep: on);
    final List<Offset> inner = _under((int _) => to, keep: on);
    return <Offset>[...outer, ...inner.reversed];
  }

  static final List<Offset> _styloglossusMm = _sheetMm(
    TongueAnatomy.sheetIn,
    TongueAnatomy.sheetIn + TongueAnatomy.sheet * 0.45,
  );
  static final List<Offset> _hyoglossusMm = _sheetMm(
    TongueAnatomy.sheetIn + TongueAnatomy.sheet * 0.45,
    TongueAnatomy.sheetIn + TongueAnatomy.sheet,
  );

  /// The inferior longitudinal, cut across.
  static final List<Offset> _inferiorMm = _ellipse(
    TongueAnatomy.inferior,
    TongueAnatomy.inferiorHalf,
  );

  /// The transverse sheets, from the septum out to the margin, the upper
  /// following the back's curve, the lower sweeping up to their insertion.
  static final List<List<Offset>> _transverseMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    final double top0 = superiorFoot(0) + TongueAnatomy.transverseTop;
    final double drop7 = superiorFoot(7) - superiorFoot(0);
    final double drop15 = superiorFoot(15) - superiorFoot(0);
    const int n = TongueAnatomy.transverse;
    for (int k = 0; k < n; k++) {
      final double t = k / (n - 1);
      final double d = top0 + (TongueAnatomy.transverseBottom - top0) * t;
      final double e =
          TongueAnatomy.insertTop +
          (TongueAnatomy.insertBottom - TongueAnatomy.insertTop) * t;
      out.add(
        _cubic(
          Offset(0.3, d),
          Offset(7, d + drop7 * (1 - t)),
          Offset(15, d + (e - d) * 0.55 + drop15 * (1 - t) * 0.6),
          Offset(21.5, e),
        ),
      );
    }
    return _bothSides(out);
  }();

  /// The vertical fibres, from under the superior longitudinal layer down
  /// to the underside, the outer bowing out with the margin.
  static final List<List<Offset>> _verticalMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    for (
      double x = TongueAnatomy.verticalFrom;
      x <= TongueAnatomy.verticalTo + 1e-6;
      x += TongueAnatomy.verticalPitch
    ) {
      final double share =
          (x - TongueAnatomy.verticalFrom) /
          (TongueAnatomy.verticalTo - TongueAnatomy.verticalFrom);
      final double bow = TongueAnatomy.verticalBow * share;
      final double top = superiorFoot(x) - 0.2;
      const double foot = 16.6;
      out.add(
        _cubic(
          Offset(x, top),
          Offset(x + bow, top + (foot - top) * 0.35),
          Offset(x + bow * 0.7, top + (foot - top) * 0.7),
          Offset(x - bow * 0.4, foot),
        ),
      );
    }
    return _bothSides(out);
  }();

  /// The genioglossus's fibres, rising from below either side of the
  /// septum and fanning up through the tongue to its back.
  static final List<List<Offset>> _genioMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    const int n = TongueAnatomy.genioFibres;
    for (int k = 0; k < n; k++) {
      final double t = (k + 0.5) / n;
      final double footX = 0.7 + (TongueAnatomy.genioFootTo - 0.7) * t;
      final double entryX = 0.7 + (TongueAnatomy.genioEntryTo - 0.7) * t;
      final double topX = 0.9 + (TongueAnatomy.genioTopTo - 0.9) * t;
      out.add(
        _cubic(
          Offset(footX, TongueAnatomy.genioFoot),
          Offset(footX + (entryX - footX) * 0.5, 22),
          Offset(entryX, 16),
          Offset(topX, superiorFoot(topX) + 0.3),
        ),
      );
    }
    return _bothSides(out);
  }();

  /// The septum, down the midline from under the back to the geniohyoids.
  static final List<Offset> _septumMm = <Offset>[
    Offset(0, superiorFoot(0) - TongueAnatomy.superior + 0.4),
    Offset(0, TongueAnatomy.genioglossus.last.dy),
  ];

  /// The genioglossus, both sides, where it enters the tongue.
  static final List<Offset> _genioglossusMm = Contour(
    _whole(TongueAnatomy.genioglossus),
  ).sampled(6).points;

  /// The geniohyoids, cut across, either side of the midline.
  static final List<List<Offset>> _geniohyoidsMm = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      _ellipse(
        Offset(side * TongueAnatomy.geniohyoid.dx, TongueAnatomy.geniohyoid.dy),
        TongueAnatomy.geniohyoidHalf,
      ),
  ];

  /// The mylohyoid, the sling from one mylohyoid line to the other.
  static final List<Offset> _mylohyoidMm = () {
    final List<Offset> upper = _open(TongueAnatomy.mylohyoidUpper);
    final List<Offset> lower = _open(TongueAnatomy.mylohyoidLower);
    return <Offset>[
      for (final Offset p in upper.reversed) Offset(-p.dx, p.dy),
      ...upper.skip(1),
      ...lower.reversed,
      for (final Offset p in lower.skip(1)) Offset(-p.dx, p.dy),
    ];
  }();

  /// The mylohyoid's middle line, from one side to the other: where it is
  /// named and its fibres run.
  static double _mylohyoidMiddle(double x) {
    double at(List<Offset> knots) {
      final List<Offset> line = _open(knots);
      for (int i = 0; i + 1 < line.length; i++) {
        final Offset a = line[i];
        final Offset b = line[i + 1];
        if (a.dx <= x.abs() && b.dx >= x.abs()) {
          final double t = b.dx == a.dx ? 0 : (x.abs() - a.dx) / (b.dx - a.dx);
          return a.dy + (b.dy - a.dy) * t;
        }
      }
      return line.last.dy;
    }

    return (at(TongueAnatomy.mylohyoidUpper) +
            at(TongueAnatomy.mylohyoidLower)) /
        2;
  }

  /// The mylohyoid's fibres: two lines along the sling.
  static final List<List<Offset>> _mylohyoidFibresMm = () {
    final List<Offset> upper = _open(TongueAnatomy.mylohyoidUpper);
    final List<Offset> lower = _open(TongueAnatomy.mylohyoidLower);
    final int n = math.min(upper.length, lower.length);
    List<Offset> line(double t) {
      final List<Offset> right = <Offset>[
        for (int i = 0; i < n; i++)
          Offset.lerp(
            upper[(i * (upper.length - 1) / (n - 1)).round()],
            lower[(i * (lower.length - 1) / (n - 1)).round()],
            t,
          )!,
      ];
      return <Offset>[
        for (final Offset p in right.reversed) Offset(-p.dx, p.dy),
        ...right.skip(1),
      ];
    }

    return <List<Offset>>[line(0.33), line(0.67)];
  }();

  /// The sublingual glands, either side, and their lobules.
  static final List<Offset> _glandRightMm = const Contour(TongueAnatomy.gland)
      .sampled(6)
      .points;
  static final List<List<Offset>> _glandsMm = _bothClosed(_glandRightMm);
  static final List<List<Offset>> _lobulesMm = _bothSides(
    _cells(_glandRightMm, TongueAnatomy.lobule, 1),
  );

  /// The cobbles of the fibres cut across: the superior and inferior
  /// longitudinal and the geniohyoids.
  static final List<List<Offset>> _superiorCellsMm = _cells(
    _superiorMm,
    1.05,
    2,
  );
  static final List<List<Offset>> _inferiorCellsMm = _bothSides(
    _cells(_inferiorMm, 0.95, 3),
  );
  static final List<List<Offset>> _geniohyoidCellsMm = _bothSides(
    _cells(_geniohyoidsMm[1], 1.25, 4),
  );

  /// The sulcus's cleft either side, and the lining of its outer wall and
  /// floor.
  static final List<Offset> _sulcusRightMm = const Contour(TongueAnatomy.sulcus)
      .sampled(5)
      .points;
  static final List<List<Offset>> _sulciMm = _bothClosed(_sulcusRightMm);
  static final List<List<Offset>> _sulcusWallsMm = _bothSides(<List<Offset>>[
    _open(TongueAnatomy.sulcus.sublist(TongueAnatomy.sulcusTongue - 1)),
  ]);

  /// The papillae over the back: each filiform a narrow cone, each
  /// fungiform a knob on a stalk.
  static final List<List<Offset>> _papillaeMm = () {
    final List<List<Offset>> out = <List<Offset>>[];
    final int middle = _surfaceMm.length ~/ 2;
    for (final int side in <int>[-1, 1]) {
      double next = TongueAnatomy.filiformFrom;
      double along = 0;
      int k = 0;
      for (int i = middle; i > 0 && i < _surfaceMm.length - 1; i += side, k++) {
        if (i != middle) {
          along += (_surfaceMm[i] - _surfaceMm[i - side]).distance;
        }
        final double x = _surfaceMm[i].dx.abs();
        if (_fromBack[i] > _marginAlong || x > TongueAnatomy.filiformTo) {
          break;
        }
        if (along < next) {
          continue;
        }
        next += TongueAnatomy.filiformPitch;
        final Offset foot = _surfaceMm[i];
        final Offset out0 = -_inwardMm[i];
        final Offset across = Offset(-out0.dy, out0.dx);
        final double fungus = (x - TongueAnatomy.fungiformAt).abs();
        if (fungus < TongueAnatomy.filiformPitch * 0.8) {
          if (fungus < TongueAnatomy.filiformPitch / 2) {
            out.add(_knob(foot, out0, across));
          }
          continue;
        }
        final double taper = 1 - _smooth((x - 16.5) / 4);
        final double height =
            TongueAnatomy.filiformHeight *
            (0.35 + 0.65 * taper) *
            (0.82 + 0.36 * _hash(k * 3.1 + side));
        const double half = TongueAnatomy.filiformFoot / 2;
        final Offset lean = across * (0.12 * (_hash(k * 7.3 + side) - 0.5));
        out.add(<Offset>[
          foot + across * half + out0 * -0.15,
          foot + across * (half * 0.45) + out0 * (height * 0.6),
          foot + lean + out0 * height,
          foot - across * (half * 0.45) + out0 * (height * 0.6),
          foot - across * half + out0 * -0.15,
        ]);
      }
    }
    return out;
  }();

  static List<Offset> _knob(Offset foot, Offset out, Offset across) {
    const double h = TongueAnatomy.fungiformHeight;
    const double w = TongueAnatomy.fungiformWidth / 2;
    return <Offset>[
      foot + across * 0.28 + out * -0.15,
      foot + across * 0.24 + out * (h * 0.4),
      foot + across * w + out * (h * 0.62),
      foot + across * (w * 0.8) + out * (h * 0.92),
      foot + out * h,
      foot - across * (w * 0.8) + out * (h * 0.92),
      foot - across * w + out * (h * 0.62),
      foot - across * 0.24 + out * (h * 0.4),
      foot - across * 0.28 + out * -0.15,
    ];
  }

  /// The mandible's halves, cut across, and their spongy bone; the
  /// trabeculae in it; the canals.
  static final List<List<Offset>> _bonesMm = _bothClosed(
    const Contour(TongueAnatomy.bone).sampled(6).points,
  );
  static final List<Offset> _spongyRightMm = const Contour(
    TongueAnatomy.cancellous,
  ).sampled(6).points;
  static final List<List<Offset>> _spongyMm = _bothClosed(_spongyRightMm);

  /// The spongy bone's marrow spaces: each cell drawn in toward its middle
  /// by its own share, the trabeculae the bone left round them.
  static final List<List<Offset>> _trabeculaeMm = _bothSides(<List<Offset>>[
    for (final (int, List<Offset>) cell in _cells(
      _spongyRightMm,
      TongueAnatomy.trabecula,
      5,
      relax: 0,
      jitter: 0.95,
    ).indexed)
      () {
        final Offset middle = polygonCentroid(cell.$2);
        final double share =
            TongueStyle.spaceLeast +
            (TongueStyle.spaceMost - TongueStyle.spaceLeast) *
                _hash(cell.$1 * 1.7 + 0.3);
        return <Offset>[
          for (final Offset p in cell.$2) middle + (p - middle) * share,
        ];
      }(),
  ]);

  /// The molars: the crown's outline closed across its neck, the dentine
  /// under the enamel and in the root, the root alone, the pulp, the
  /// canals.
  static final List<Offset> _crownRightMm = _open(TongueAnatomy.crownOutline);
  static final List<List<Offset>> _crownsMm = _bothClosed(_crownRightMm);
  static final List<List<Offset>> _dentinesMm = _bothClosed(<Offset>[
    ..._open(TongueAnatomy.enamelFloor),
    ..._open(TongueAnatomy.root).skip(1),
  ]);
  static final List<List<Offset>> _rootsMm = _bothClosed(
    _open(TongueAnatomy.root),
  );
  static final List<List<Offset>> _pulpsMm = _bothClosed(
    const Contour(TongueAnatomy.pulp).sampled(5).points,
  );
  static final List<List<Offset>> _canalsMm = _bothSides(<List<Offset>>[
    for (final List<Offset> c in TongueAnatomy.canals) _open(c),
  ]);
  static final List<List<Offset>> _gingivaeMm = _bothClosed(
    const Contour(TongueAnatomy.buccalGingiva).sampled(5).points,
  );

  /// Everything the section covers, for its shadow and its edge: the soft
  /// tissue, the mandible's halves, the crowns and the buccal gingivae, in
  /// one outline.
  static final Path _wholeMm = () {
    Path path = Path()..addPolygon(_softMm, true);
    for (final List<Offset> part in <List<Offset>>[
      ..._bonesMm,
      ..._crownsMm,
      ..._rootsMm,
      ..._gingivaeMm,
    ]) {
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addPolygon(part, true),
      );
    }
    return path;
  }();

  // The parts, laid in the scene.

  /// The intrinsic muscle, its superior longitudinal layer and its inferior
  /// longitudinal bundles, either side; their fibres and cobbles.
  late final List<Offset> home = _placed(_homeMm);
  late final List<Offset> superior = _placed(_superiorMm);
  late final List<List<Offset>> inferiors = _placedAll(
    _bothClosed(_inferiorMm),
  );
  late final List<List<Offset>> transverse = _placedAll(_transverseMm);
  late final List<List<Offset>> vertical = _placedAll(_verticalMm);
  late final List<List<Offset>> genioFibres = _placedAll(_genioMm);
  late final List<List<Offset>> superiorCells = _placedAll(_superiorCellsMm);
  late final List<List<Offset>> inferiorCells = _placedAll(_inferiorCellsMm);
  late final List<Offset> septum = _placed(_septumMm);

  /// The extrinsic muscles and the floor's: the genioglossus, the
  /// hyoglossus and the styloglossus either side, the geniohyoids and their
  /// cobbles, the mylohyoid and its fibres.
  late final List<Offset> genioglossus = _placed(_genioglossusMm);
  late final List<List<Offset>> hyoglossi = _placedAll(
    _bothClosed(_hyoglossusMm),
  );
  late final List<List<Offset>> styloglossi = _placedAll(
    _bothClosed(_styloglossusMm),
  );
  late final List<List<Offset>> geniohyoids = _placedAll(_geniohyoidsMm);
  late final List<List<Offset>> geniohyoidCells = _placedAll(
    _geniohyoidCellsMm,
  );
  late final List<Offset> mylohyoid = _placed(_mylohyoidMm);
  late final List<List<Offset>> mylohyoidFibres = _placedAll(
    _mylohyoidFibresMm,
  );

  /// The sublingual glands and their lobules; the sulci and the lining of
  /// their outer walls and floors.
  late final List<List<Offset>> glands = _placedAll(_glandsMm);
  late final List<List<Offset>> lobules = _placedAll(_lobulesMm);
  late final List<List<Offset>> sulci = _placedAll(_sulciMm);
  late final List<List<Offset>> sulcusWalls = _placedAll(_sulcusWallsMm);

  /// The tongue's free surface, the back's share of it, and the papillae
  /// on its back.
  late final List<Offset> surface = _placed(_surfaceMm);
  late final List<Offset> back = _placed(<Offset>[
    for (int i = 0; i < _surfaceMm.length; i++)
      if (_fromBack[i] <= _marginAlong) _surfaceMm[i],
  ]);
  late final List<List<Offset>> papillae = _placedAll(_papillaeMm);

  /// The mandible's halves, their spongy bone and trabeculae; the molars:
  /// crowns, dentine, roots, pulps and canals; the buccal gingivae.
  late final List<List<Offset>> bones = _placedAll(_bonesMm);
  late final List<List<Offset>> spongy = _placedAll(_spongyMm);
  late final List<List<Offset>> trabeculae = _placedAll(_trabeculaeMm);
  late final List<List<Offset>> crowns = _placedAll(_crownsMm);
  late final List<List<Offset>> dentines = _placedAll(_dentinesMm);
  late final List<List<Offset>> roots = _placedAll(_rootsMm);
  late final List<List<Offset>> pulps = _placedAll(_pulpsMm);
  late final List<List<Offset>> canals = _placedAll(_canalsMm);
  late final List<List<Offset>> gingivae = _placedAll(_gingivaeMm);

  /// What runs along under the tongue and in the floor, and in each
  /// mandible's canal, cut across, either side: each its middle and radius
  /// in the scene.
  late final List<(Offset, double)> arteries = _discs(TongueAnatomy.artery);
  late final List<(Offset, double)> veins = <(Offset, double)>[
    ..._discs(TongueAnatomy.vein),
    ..._discs(TongueAnatomy.comitans),
  ];
  late final List<(Offset, double)> ducts = _discs(TongueAnatomy.duct);
  late final List<(Offset, double)> nerves = <(Offset, double)>[
    ..._discs(TongueAnatomy.lingualNerve),
    ..._discs(TongueAnatomy.hypoglossal),
  ];
  late final List<(Offset, double)> alveolarCanals = _discs(
    TongueAnatomy.canal,
  );
  late final List<(Offset, double)> alveolarNerves = _discs(
    TongueAnatomy.alveolarNerve,
  );
  late final List<(Offset, double)> alveolarArteries = _discs(
    TongueAnatomy.alveolarArtery,
  );
  late final List<(Offset, double)> alveolarVeins = _discs(
    TongueAnatomy.alveolarVein,
  );

  List<(Offset, double)> _discs((Offset, double) disc) => <(Offset, double)>[
    for (final double side in <double>[-1, 1])
      (place(Offset(side * disc.$1.dx, disc.$1.dy)), mm(disc.$2)),
  ];

  /// Everything the section covers, in one outline.
  late final Path whole = _wholeMm.transform(
    Float64List.fromList(<double>[
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      site.dx - TongueAnatomy.site.dx * scale,
      site.dy - TongueAnatomy.site.dy * scale,
      0,
      1,
    ]),
  );

  /// The box round all of it, the papillae included.
  late final Rect extent = () {
    Rect b = whole.getBounds();
    for (final List<Offset> p in papillae) {
      b = b.expandToInclude(_bounds(p));
    }
    return b;
  }();

  // Where the parts are named.

  /// The intrinsic muscle at the site; the genioglossus on the body's left,
  /// the hyoglossus on its right; the sublingual gland on its left, the
  /// mylohyoid on its right, and the mandible on its left, high in its
  /// buccal cortex.
  Offset get homeName => site;
  late final Offset genioglossusName = place(TongueAnatomy.genioglossusName);
  late final Offset hyoglossusName = () {
    final List<Offset> h = _hyoglossusMm;
    Offset best = h.first;
    for (final Offset p in h) {
      if ((p.dy - TongueAnatomy.hyoglossusName.dy).abs() <
          (best.dy - TongueAnatomy.hyoglossusName.dy).abs()) {
        best = p;
      }
    }
    // The strip's middle at that height, on the body's right.
    final List<Offset> level = <Offset>[
      for (final Offset p in h)
        if ((p.dy - best.dy).abs() < 0.6) p,
    ];
    final double x =
        level.map((Offset p) => p.dx).reduce(math.min) / 2 +
        level.map((Offset p) => p.dx).reduce(math.max) / 2;
    return place(Offset(-x, best.dy));
  }();
  late final Offset glandName = place(TongueAnatomy.glandName);
  late final Offset mylohyoidName = place(
    Offset(
      TongueAnatomy.mylohyoidName.dx,
      _mylohyoidMiddle(TongueAnatomy.mylohyoidName.dx),
    ),
  );
  late final Offset mandibleName = () {
    // Midway through the buccal cortex at that height.
    final double y = TongueAnatomy.mandibleName.dy;
    final double outer = _crossing(_bonesMm[1], y, outermost: true);
    final double inner = _crossing(_spongyMm[1], y, outermost: true);
    return place(Offset((outer + inner) / 2, y));
  }();

  static double _crossing(
    List<Offset> polygon,
    double y, {
    required bool outermost,
  }) {
    double best = outermost ? double.negativeInfinity : double.infinity;
    for (int i = 0; i < polygon.length; i++) {
      final Offset a = polygon[i];
      final Offset b = polygon[(i + 1) % polygon.length];
      if ((a.dy <= y) == (b.dy <= y)) {
        continue;
      }
      final double x = a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
      best = outermost ? math.max(best, x) : math.min(best, x);
    }
    return best;
  }

  /// The points the names are set round: the whole section's outline and
  /// the papillae's tips.
  late final List<Offset> namedPoints = () {
    final List<Offset> out = <Offset>[];
    for (final List<Offset> part in <List<Offset>>[
      _softMm,
      ..._bonesMm,
      ..._crownsMm,
      ..._gingivaeMm,
    ]) {
      for (int i = 0; i < part.length; i += 3) {
        out.add(place(part[i]));
      }
    }
    for (final List<Offset> p in _papillaeMm) {
      out.add(place(p[p.length ~/ 2]));
    }
    return out;
  }();

  // For tests: the anatomy in millimetres.

  static List<Offset> get softMm => _softMm;
  static List<Offset> get homeMm => _homeMm;
  static List<Offset> get superiorMm => _superiorMm;
  static List<Offset> get inferiorMm => _inferiorMm;
  static List<Offset> get genioglossusMm => _genioglossusMm;
  static List<List<Offset>> get transverseMm => _transverseMm;
  static List<List<Offset>> get verticalMm => _verticalMm;
  static List<List<Offset>> get genioFibresMm => _genioMm;
  static List<List<Offset>> get bonesMm => _bonesMm;
  static List<List<Offset>> get spongyMm => _spongyMm;
  static List<List<Offset>> get crownsMm => _crownsMm;
  static List<List<Offset>> get rootsMm => _rootsMm;
  static List<List<Offset>> get glandsMm => _glandsMm;
  static List<Offset> get mylohyoidMm => _mylohyoidMm;
  static List<List<Offset>> get papillaeMm => _papillaeMm;
  static List<Offset> get septumMm => _septumMm;
  static List<Offset> get surfaceMm => _surfaceMm;

  /// Whether [p] lies inside [polygon]. For tests.
  static bool inside(List<Offset> polygon, Offset p) => _inside(polygon, p);
}

// Geometry, in the anatomy's millimetres.

/// A half laid from the midline's top round to the midline's foot, and its
/// mirror back up, in one closed outline.
List<Offset> _whole(List<Offset> half) => <Offset>[
  ...half,
  for (final Offset p in half.reversed.skip(1).take(half.length - 2))
    Offset(-p.dx, p.dy),
];

/// A closed outline on the body's left and its mirror on the right.
List<List<Offset>> _bothClosed(List<Offset> left) => <List<Offset>>[
  <Offset>[for (final Offset p in left.reversed) Offset(-p.dx, p.dy)],
  left,
];

/// Lines on the body's left and their mirrors on the right.
List<List<Offset>> _bothSides(List<List<Offset>> left) => <List<Offset>>[
  for (final List<Offset> l in left)
    <Offset>[for (final Offset p in l) Offset(-p.dx, p.dy)],
  ...left,
];

/// A smooth open curve through [knots], followed every
/// `TongueStyle.step` millimetres or so.
List<Offset> _open(List<Offset> knots) {
  final int n = knots.length;
  if (n < 2) {
    return List<Offset>.of(knots);
  }
  Offset knot(int i) => knots[i.clamp(0, n - 1)];
  final List<Offset> out = <Offset>[knots.first];
  for (int i = 0; i < n - 1; i++) {
    final Offset p0 = knot(i - 1);
    final Offset p1 = knot(i);
    final Offset p2 = knot(i + 1);
    final Offset p3 = knot(i + 2);
    final Offset c1 = p1 + (p2 - p0) / 6;
    final Offset c2 = p2 - (p3 - p1) / 6;
    final int steps = math.max(
      1,
      ((p2 - p1).distance / TongueStyle.step).ceil(),
    );
    for (int k = 1; k <= steps; k++) {
      final double t = k / steps;
      final double u = 1 - t;
      out.add(
        p1 * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            p2 * (t * t * t),
      );
    }
  }
  return out;
}

/// A cubic from [a] to [d], followed every `TongueStyle.step` or so.
List<Offset> _cubic(Offset a, Offset b, Offset c, Offset d) {
  final double length = (b - a).distance + (c - b).distance + (d - c).distance;
  final int steps = math.max(2, (length / TongueStyle.step).ceil());
  return <Offset>[
    for (int k = 0; k <= steps; k++)
      () {
        final double t = k / steps;
        final double u = 1 - t;
        return a * (u * u * u) +
            b * (3 * u * u * t) +
            c * (3 * u * t * t) +
            d * (t * t * t);
      }(),
  ];
}

/// An ellipse round [middle] with half-widths [half], followed closely.
List<Offset> _ellipse(Offset middle, Size half) => <Offset>[
  for (int i = 0; i < 64; i++)
    middle +
        Offset(
          half.width * math.cos(2 * math.pi * i / 64),
          half.height * math.sin(2 * math.pi * i / 64),
        ),
];

/// Cells packed into [polygon], about [size] across: each a closed outline,
/// laid by seed [seed]. Their borders may run past the polygon; they are
/// drawn clipped to it.
List<List<Offset>> _cells(
  List<Offset> polygon,
  double size,
  int seed, {
  int relax = 2,
  double jitter = 0.5,
}) {
  final Rect b = _bounds(polygon);
  final math.Random random = math.Random(TongueStyle.seed * 31 + seed);
  final List<Offset> seeds = <Offset>[];
  for (double y = b.top - size; y <= b.bottom + size; y += size * 0.87) {
    final double shift = ((y - b.top) / (size * 0.87)).round().isOdd
        ? size / 2
        : 0;
    for (double x = b.left - size + shift; x <= b.right + size; x += size) {
      final Offset p =
          Offset(x, y) +
          Offset(
            (random.nextDouble() - 0.5) * size * jitter,
            (random.nextDouble() - 0.5) * size * jitter,
          );
      if (_inside(polygon, p) || _toPolygon(polygon, p) < size * 0.7) {
        seeds.add(p);
      }
    }
  }
  final List<Offset> relaxed = relaxedSeeds(seeds, size * 1.5, times: relax);
  final List<List<Offset>> cells = voronoiCells(relaxed, size * 1.5);
  // Only the cells of seeds inside it: those outside close it off.
  return <List<Offset>>[
    for (int i = 0; i < cells.length; i++)
      if (cells[i].length >= 3 && _inside(polygon, relaxed[i])) cells[i],
  ];
}

double _toPolygon(List<Offset> polygon, Offset p) {
  double best = double.infinity;
  for (int i = 0; i < polygon.length; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % polygon.length];
    final Offset ab = b - a;
    final double l = ab.distanceSquared;
    final double t = l <= 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l).clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}

/// A number from 0 to 1 that stays with a place.
double _hash(double v) {
  final double h = math.sin(v * 12.9898 + 78.233) * 43758.5453;
  return h - h.floorToDouble();
}

double _smooth(double t) {
  final double c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

bool _inside(List<Offset> polygon, Offset p) {
  bool odd = false;
  final int n = polygon.length;
  for (int i = 0; i < n; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % n];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy)) {
      odd = !odd;
    }
  }
  return odd;
}

double _area(List<Offset> points) {
  double sum = 0;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
}

Rect _bounds(List<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset p in points) {
    left = math.min(left, p.dx);
    right = math.max(right, p.dx);
    top = math.min(top, p.dy);
    bottom = math.max(bottom, p.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}
