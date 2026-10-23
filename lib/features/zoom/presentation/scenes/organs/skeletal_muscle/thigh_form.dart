import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'thigh_anatomy.dart';
import 'thigh_style.dart';

/// A muscle of the thigh as laid in the scene: its outline, and its
/// fascicles, each a line across it from where its fibres start to where
/// they end, running past its outline to be cut by it.
final class ThighMuscle {
  const ThighMuscle(this.outline, this.fascicles);

  final List<Offset> outline;
  final List<List<Offset>> fascicles;
}

/// The front of the right thigh as the zoom's organ scene draws it for
/// skeletal muscle, every part in the scene's units at its real size.
///
/// The thigh is drawn from general anatomy ([ThighAnatomy]) in the very
/// thigh the body draws: the figure is a person 1.70 m tall, drawn at a
/// person's size, so nothing is grown, and every muscle is laid in shares
/// of the figure's own right thigh, across between its outline's edges and
/// down the femur the figure draws (on its left leg, mirrored). The knee's
/// bones and tendons are laid in millimetres over the femur's condyles.
/// The body follows the vastus lateralis's outline, the outermost of the
/// five it draws, and goes in where the vastus lateralis is biopsied
/// ([site]), which is the body's; the step from the body draws that
/// outline in toward the vastus lateralis's own ([pathAt]). Everything
/// here is geometry: what it is drawn in is `ThighArt`'s.
final class ThighForm {
  ThighForm._({
    required AnatomyPart part,
    required AnatomyPart femur,
    required List<Offset> silhouette,
    required this.view,
  }) : scale = 1e-3 / view,
       _centre = part.centre,
       _silhouette = List<Offset>.unmodifiable(silhouette),
       _femur = <Offset>[
         for (final Offset p in femur.followed) Offset(-p.dx, p.dy),
       ] {
    final Rect bone = _bounds(_femur);
    _top = bone.top;
    _length = bone.height;
    final List<double> condyles = _crossings(
      _femur,
      bone.top + bone.height * 0.975,
    );
    _patella = Offset(
      (condyles.first + condyles.last) / 2,
      bone.bottom - ThighAnatomy.patellaHeight * 1e-3,
    );
    site = _toScene(part.site);
    others = <List<Offset>>[
      for (final List<Offset> other in part.others)
        <Offset>[for (final Offset p in other) _toScene(p)],
    ];
    final List<Offset> diagram = <Offset>[
      for (final Offset p in part.followed) _toScene(p),
    ];
    final List<Offset> template = List<Offset>.of(vastusLateralis.outline);
    if (_area(template).sign != _area(diagram).sign) {
      template.setAll(0, template.reversed.toList());
    }
    _morph = OutlineMorph(
      template: template,
      diagram: Contour(diagram).sampled(ThighStyle.morphSpan).points,
      diagramPath: Contour(diagram).toPath(),
      count: ThighStyle.morphPoints,
      bed: mm(ThighStyle.bed),
      marks: _marks,
    );
  }

  /// The thigh where [figure] draws skeletal muscle as [part], in a view
  /// [view] metres across.
  factory ThighForm.place({
    required AnatomyPart part,
    required AnatomyFigure figure,
    required double view,
  }) => ThighForm._(
    part: part,
    femur: figure.parts[tissueAnatomy['bone marrow']!.uberon]!,
    silhouette: figure.silhouette,
    view: view,
  );

  /// How many times the size the body draws it at the thigh really is: the
  /// figure is drawn at a person's size.
  static const double real = 1;

  /// How many metres the scene's unit is.
  final double view;

  /// How long a millimetre is in the scene.
  final double scale;

  final Offset _centre;
  final List<Offset> _silhouette;

  /// The figure's femur, mirrored onto the right leg.
  final List<Offset> _femur;
  late final double _top;
  late final double _length;

  /// The patella's middle, in the figure's metres.
  late final Offset _patella;

  late final OutlineMorph _morph;

  /// Where the body goes into the thigh, in the scene: in the vastus
  /// lateralis.
  late final Offset site;

  /// The body's other outlines of skeletal muscle, beside the one it
  /// follows, in the scene.
  late final List<List<Offset>> others;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  Offset _toScene(Offset figure) => (figure - _centre) / view;

  /// Where the thigh's edges lie at the figure's height [y], in metres: the
  /// outline's crossings either side of the femur, the midline above the
  /// crotch, each the skin's depth in.
  (double, double) _edges(double y) {
    final List<double> bone = _crossings(
      _femur,
      y.clamp(_top + 1e-3, _top + _length - 1e-3),
    );
    final double core = (bone.first + bone.last) / 2;
    final List<double> crossings = _crossings(_silhouette, y);
    double lateral = double.negativeInfinity;
    double medial = 0;
    for (final double x in crossings) {
      if (x < core) {
        lateral = math.max(lateral, x);
      } else {
        medial = math.min(medial, x);
      }
    }
    const double skin = ThighAnatomy.skin * 1e-3;
    return (lateral + skin, medial - skin);
  }

  /// A point of the thigh given in shares, [uv].dx across from its lateral
  /// edge to its medial and [uv].dy down the femur from its head's top, in
  /// the figure's metres.
  Offset _share(Offset uv) {
    final double y = _top + uv.dy * _length;
    final (double lateral, double medial) = _edges(y);
    return Offset(lateral + uv.dx * (medial - lateral), y);
  }

  /// A point of the thigh given in shares, in the scene.
  Offset place(Offset uv) => _toScene(_share(uv));

  /// A point of the knee given in millimetres from the patella's middle, x
  /// lateral and y down, in the scene.
  Offset knee(Offset millimetres) => _toScene(
    _patella + Offset(-millimetres.dx * 1e-3, millimetres.dy * 1e-3),
  );

  /// How far down the femur, a share of its length from its head's top,
  /// the scene's point [p] lies.
  double downOf(Offset p) => (p.dy * view + _centre.dy - _top) / _length;

  /// How wide the thigh is at the scene's point [p]'s height, in the
  /// scene.
  double widthAt(Offset p) {
    final (double lateral, double medial) = _edges(p.dy * view + _centre.dy);
    return (medial - lateral) / view;
  }

  /// A smooth outline through [knots], given in shares.
  List<Offset> _outline(List<Offset> knots) =>
      Contour(<Offset>[for (final Offset k in knots) place(k)])
          .sampled(ThighStyle.knotSpan)
          .points;

  // The muscles.

  late final ThighMuscle vastusLateralis = _ruled(
    ThighAnatomy.vastusLateralis,
    <(List<Offset>, List<Offset>)>[
      (ThighAnatomy.lateralisFrom, ThighAnatomy.lateralisTo),
    ],
  );
  late final ThighMuscle rectusFemoris = _ruled(
    ThighAnatomy.rectusFemoris,
    <(List<Offset>, List<Offset>)>[
      (ThighAnatomy.rectusTendon, ThighAnatomy.rectusLateral),
      (ThighAnatomy.rectusTendon, ThighAnatomy.rectusMedial),
    ],
  );
  late final ThighMuscle vastusMedialis = _ruled(
    ThighAnatomy.vastusMedialis,
    <(List<Offset>, List<Offset>)>[
      (ThighAnatomy.medialisFrom, ThighAnatomy.medialisTo),
    ],
  );
  late final ThighMuscle tensor = _ruled(
    ThighAnatomy.tensor,
    <(List<Offset>, List<Offset>)>[
      (ThighAnatomy.tensorFrom, ThighAnatomy.tensorTo),
    ],
  );
  late final ThighMuscle adductorLongus = _ruled(
    ThighAnatomy.adductorLongus,
    <(List<Offset>, List<Offset>)>[
      (ThighAnatomy.adductorFrom, ThighAnatomy.adductorTo),
    ],
  );
  late final ThighMuscle pectineus = _ruled(
    ThighAnatomy.pectineus,
    <(List<Offset>, List<Offset>)>[
      (ThighAnatomy.pectineusFrom, ThighAnatomy.pectineusTo),
    ],
  );
  late final ThighMuscle iliopsoas = _ruled(
    ThighAnatomy.iliopsoas,
    <(List<Offset>, List<Offset>)>[
      (ThighAnatomy.iliopsoasFrom, ThighAnatomy.iliopsoasTo),
    ],
  );
  late final ThighMuscle sartorius = _strap(
    ThighAnatomy.sartorius,
    ThighAnatomy.sartoriusWidth,
  );
  late final ThighMuscle gracilis = _strap(
    ThighAnatomy.gracilis,
    ThighAnatomy.gracilisWidth,
  );

  /// The muscle outlined by [knots], its fascicles in [families], each run
  /// from one line to the other.
  ThighMuscle _ruled(
    List<Offset> knots,
    List<(List<Offset>, List<Offset>)> families,
  ) {
    final List<Offset> outline = _outline(knots);
    final double area = _area(outline).abs();
    return ThighMuscle(outline, <List<Offset>>[
      for (final (List<Offset> from, List<Offset> to) in families)
        ..._fascicles(
          <Offset>[for (final Offset k in from) place(k)],
          <Offset>[for (final Offset k in to) place(k)],
          area / families.length,
        ),
    ]);
  }

  /// Lines from [from] to [to], at matching shares of the way along each,
  /// as many as cover [area] a fascicle apart.
  List<List<Offset>> _fascicles(
    List<Offset> from,
    List<Offset> to,
    double area,
  ) {
    double length = 0;
    for (int k = 0; k <= 8; k++) {
      length += (_along(to, k / 8) - _along(from, k / 8)).distance / 9;
    }
    final int count = math.max(
      2,
      (area / (length * mm(ThighStyle.fascicle))).round(),
    );
    return <List<Offset>>[
      for (int k = 0; k < count; k++)
        <Offset>[
          _along(from, (k + 0.5) / count),
          _along(to, (k + 0.5) / count),
        ],
    ];
  }

  /// The strap whose middle runs through [knots], [widths] each side of it
  /// there, in millimetres; its fascicles along it.
  ThighMuscle _strap(List<Offset> knots, List<double> widths) {
    final TubeCourse course = _course(knots, widths);
    final int n = course.length;
    double widest = 0;
    for (int i = 0; i < n; i++) {
      widest = math.max(widest, course.plus[i] + course.minus[i]);
    }
    final int count = math.max(2, (widest / mm(ThighStyle.fascicle)).round());
    return ThighMuscle(
      <Offset>[
        for (int i = 0; i < n; i++) course.at(i, 1),
        for (int i = n - 1; i >= 0; i--) course.at(i, -1),
      ],
      <List<Offset>>[
        for (int k = 0; k < count; k++)
          <Offset>[
            for (int i = 0; i < n; i++)
              course.at(i, -1 + 2 * (k + 0.5) / count),
          ],
      ],
    );
  }

  TubeCourse _course(
    List<Offset> knots,
    List<double> widths, {
    double fadeOut = 0,
  }) => TubeCourse(
    AnatomyTube(knots, widths, fadeOut: fadeOut),
    place,
    scale,
    mm(1.5),
    bend: 0.9,
  );

  /// What lies deeper, seen in shade where the muscles part.
  late final List<Offset> deep = _outline(ThighAnatomy.deep);

  // The tendons and the bone.

  /// The iliotibial tract: down the lateral edge, its width in from it, and
  /// forward over the knee.
  late final TubeCourse tract = () {
    const double half = ThighAnatomy.tract / 2;
    final List<Offset> knots = <Offset>[
      for (final double v in ThighAnatomy.tractDown)
        Offset(half * 1e-3 / _widthAtShare(v), v),
      ...ThighAnatomy.tractKnee,
    ];
    return _course(knots, <double>[
      for (int k = 0; k < ThighAnatomy.tractDown.length; k++) half,
      ...ThighAnatomy.tractKneeWidth,
    ]);
  }();

  double _widthAtShare(double v) {
    final (double lateral, double medial) = _edges(_top + v * _length);
    return medial - lateral;
  }

  late final List<Offset> tractOutline = <Offset>[
    for (int i = 0; i < tract.length; i++) tract.at(i, 1),
    for (int i = tract.length - 1; i >= 0; i--) tract.at(i, -1),
  ];

  late final List<Offset> retinacula = _outline(ThighAnatomy.retinacula);

  late final List<Offset> quadricepsTendon = _outline(
    ThighAnatomy.quadricepsTendon,
  );

  late final List<Offset> patella = Contour(<Offset>[
    for (final Offset p in ThighAnatomy.patella) knee(p),
  ]).sampled(ThighStyle.knotSpan).points;

  late final List<Offset> patellarLigament = <Offset>[
    for (final Offset p in ThighAnatomy.patellarLigament) knee(p),
  ];

  // The femoral triangle's nerve, artery and vein.

  late final TubeCourse nerve = _course(
    ThighAnatomy.nerve,
    ThighAnatomy.nerveWidth,
  );
  late final List<TubeCourse> nerveBranches = <TubeCourse>[
    for (int k = 0; k < ThighAnatomy.nerveBranches.length; k++)
      _course(
        ThighAnatomy.nerveBranches[k],
        ThighAnatomy.nerveBranchWidths[k],
        fadeOut: ThighStyle.tubeFade,
      ),
  ];
  late final TubeCourse artery = _course(
    ThighAnatomy.artery,
    ThighAnatomy.arteryWidth,
    fadeOut: ThighStyle.tubeFade,
  );
  late final TubeCourse vein = _course(
    ThighAnatomy.vein,
    ThighAnatomy.veinWidth,
    fadeOut: ThighStyle.tubeFade,
  );

  // The outline.

  /// Every muscle, from the deepest.
  late final List<ThighMuscle> muscles = <ThighMuscle>[
    pectineus,
    iliopsoas,
    adductorLongus,
    gracilis,
    vastusMedialis,
    vastusLateralis,
    rectusFemoris,
    tensor,
    sartorius,
  ];

  /// The thigh's outline, all of it: its muscles, what lies deeper between
  /// them, its tendons and the patella.
  ///
  /// Their union is taken in millimetres: in the scene's units, where a
  /// millimetre is a few thousandths, the long edges the muscles share lie
  /// too close for it, and it loses part of the thigh.
  late final List<Offset> outlinePoints = <Offset>[
    for (final Offset p in _outerOf(
      _union(<List<Offset>>[
        for (final List<Offset> part in <List<Offset>>[
          deep,
          for (final ThighMuscle m in muscles) m.outline,
          tractOutline,
          retinacula,
          quadricepsTendon,
          patella,
          patellarLigament,
        ])
          <Offset>[for (final Offset q in part) q / scale],
      ]),
      ThighStyle.outlineStep,
    ))
      p * scale,
  ];
  late final Path outline = Path()..addPolygon(outlinePoints, true);
  late final Rect box = _bounds(outlinePoints);

  /// The flat shape the step from the body draws: the body's outline of
  /// the vastus lateralis at [settle] 0, the vastus lateralis's own at 1,
  /// and [bed] of the way on toward the bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Where the thigh's outline lies furthest to either side at [at]'s
  /// height: where a name in a column at the canvas's edge keeps clear of
  /// it.
  (Offset, Offset) edgesAt(Offset at) {
    final List<double> crossings = _crossings(outlinePoints, at.dy);
    if (crossings.isEmpty) {
      return (at, at);
    }
    return (Offset(crossings.first, at.dy), Offset(crossings.last, at.dy));
  }

  // Where the names point.

  late final Offset rectusName = place(ThighAnatomy.rectusName);
  late final Offset sartoriusName = place(ThighAnatomy.sartoriusName);
  late final Offset medialisName = place(ThighAnatomy.medialisName);

  /// Where the step from the body meets the vastus lateralis's outline and
  /// the body's, besides their tops: down either side at a quarter, a half
  /// and three quarters, and at the medial end of the foot, each picked out
  /// of either outline alike.
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.level(p, -1, 0.25),
        (List<Offset> p) => OutlineMarks.level(p, -1, 0.5),
        (List<Offset> p) => OutlineMarks.level(p, -1, 0.75),
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.95, 1),
        (List<Offset> p) => OutlineMarks.level(p, 1, 0.75),
        (List<Offset> p) => OutlineMarks.level(p, 1, 0.5),
        (List<Offset> p) => OutlineMarks.level(p, 1, 0.25),
      ];

  /// The points of [points] where the step from the body meets the other
  /// outline, for tests.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

/// The point [t] of the way along the open line [points].
Offset _along(List<Offset> points, double t) {
  double total = 0;
  for (int i = 1; i < points.length; i++) {
    total += (points[i] - points[i - 1]).distance;
  }
  double left = t.clamp(0.0, 1.0) * total;
  for (int i = 1; i < points.length; i++) {
    final double step = (points[i] - points[i - 1]).distance;
    if (left <= step || i == points.length - 1) {
      return Offset.lerp(
        points[i - 1],
        points[i],
        step <= 0 ? 0 : (left / step).clamp(0.0, 1.0),
      )!;
    }
    left -= step;
  }
  return points.last;
}

/// Where the closed outline [points] crosses the height [y], from left to
/// right.
List<double> _crossings(List<Offset> points, double y) {
  final List<double> out = <double>[];
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    if ((a.dy > y) != (b.dy > y)) {
      out.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
    }
  }
  return out..sort();
}

/// The shapes of [polygons] as one.
Path _union(List<List<Offset>> polygons) {
  Path out = Path();
  for (final List<Offset> p in polygons) {
    out = Path.combine(PathOperation.union, out, Path()..addPolygon(p, true));
  }
  return out;
}

/// The outside of [path], its largest contour, laid with points [step]
/// apart along it.
List<Offset> _outerOf(Path path, double step) {
  List<Offset> best = <Offset>[];
  double largest = 0;
  for (final PathMetric metric in path.computeMetrics()) {
    final List<Offset> points = <Offset>[
      for (double s = 0; s < metric.length; s += step)
        metric.getTangentForOffset(s)!.position,
    ];
    final double area = _area(points).abs();
    if (area > largest) {
      largest = area;
      best = points;
    }
  }
  return best;
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
