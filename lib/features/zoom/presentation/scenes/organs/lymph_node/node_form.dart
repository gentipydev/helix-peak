import 'dart:math' as math;
import 'dart:ui';

import '../../tube_course.dart';
import 'node_anatomy.dart';
import 'node_style.dart';

/// Where in the lymph node the zoom's cell lives, which its drawing lights
/// in the mark, by the Atlas's name for the cell. By the kind of cell,
/// never by gene.
enum NodeHome {
  /// The sinuses, under the capsule, along the trabeculae and between the
  /// medullary cords: their lymphatic endothelium.
  sinuses,

  /// The follicles of the cortex: its B cells and follicular dendritic
  /// cells.
  follicles,

  /// The paracortex: its T cells and dendritic cells.
  paracortex,

  /// The medullary cords: their plasma cells.
  cords,

  /// The cortex: every other cell, with no part of the node of its own to
  /// be drawn at its size.
  cortex;

  /// Where a cell the Atlas calls [cell] lives.
  static NodeHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    bool has(String word) => name.contains(word);
    if (has('lymphatic endothelial') || has('sinus')) {
      return sinuses;
    }
    if (has('b-cell') ||
        has('b cell') ||
        has('germinal') ||
        has('follicular')) {
      return follicles;
    }
    if (has('t-cell') || has('t cell') || has('dendritic')) {
      return paracortex;
    }
    if (has('plasma')) {
      return cords;
    }
    return cortex;
  }

  /// What its name says.
  String get word => switch (this) {
    sinuses => 'sinuses',
    follicles => 'follicles',
    paracortex => 'paracortex',
    cords => 'medullary cords',
    cortex => 'cortex',
  };
}

/// A follicle of the cortex: its middle, how wide, and, for one with a
/// germinal centre, the centre's middle and how wide.
typedef NodeFollicle = ({
  Offset centre,
  double radius,
  Offset? germ,
  double germRadius,
});

/// The lymph node as the zoom's organ scene draws it, cut in two through
/// its hilum: every part in the scene's units at its real size, its middle
/// at the origin.
///
/// It is drawn from general anatomy ([NodeAnatomy]) on its own, as a
/// section is read: the body has no outline of one node that shows it, so
/// the scene comes up over the body's drawing of its chain of nodes.
/// Everything here is geometry: what it is drawn in is `NodeArt`'s.
final class NodeForm {
  NodeForm({required this.view, this.home = NodeHome.sinuses})
    : scale = 1e-3 / view;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final NodeHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => mm * scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  // The anatomy in millimetres, built once for every node.

  /// The outline, the capsule, round from the hilum's notch: an oval drawn
  /// in at its foot.
  static final List<Offset> _outlineMm = <Offset>[
    for (int i = 0; i < NodeStyle.outlinePoints; i++) _at(_angle(i)),
  ];

  static double _angle(int i) =>
      math.pi / 2 + 2 * math.pi * i / NodeStyle.outlinePoints;

  static Offset _at(double t) {
    final double from = math.atan2(
      math.sin(t - math.pi / 2),
      math.cos(t - math.pi / 2),
    );
    final double notch = math.exp(
      -(from * from) / (NodeAnatomy.hilumWidth * NodeAnatomy.hilumWidth),
    );
    return Offset(
      math.cos(t) * NodeAnatomy.length / 2,
      math.sin(t) * NodeAnatomy.width / 2 - NodeAnatomy.hilumDepth * notch,
    );
  }

  /// The way into the node at each point of the outline, a unit.
  static final List<Offset> _inMm = () {
    final int n = _outlineMm.length;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t =
              _outlineMm[(i + 1) % n] - _outlineMm[(i - 1 + n) % n];
          final Offset left = Offset(t.dy, -t.dx) / t.distance;
          return _inside(_outlineMm, _outlineMm[i] + left * 0.05)
              ? left
              : -left;
        }(),
    ];
  }();

  /// The run of the outline the cortex lies under: all of it but the
  /// hilum, where the medulla reaches the surface; by the outline's points.
  static final int _runFrom = (NodeStyle.outlinePoints * NodeAnatomy.bare)
      .round();
  static final int _runTo =
      NodeStyle.outlinePoints -
      (NodeStyle.outlinePoints * NodeAnatomy.bare).round();

  /// The run [depth] in from the capsule on the node's convex side, the
  /// depth tapering to nothing toward the hilum.
  static List<Offset> _runAt(double depth) => <Offset>[
    for (int i = _runFrom; i <= _runTo; i++)
      _outlineMm[i % _outlineMm.length] +
          _inMm[i % _inMm.length] * (depth * _taper(i)),
  ];

  /// How much of their depth the bands under the capsule keep at the
  /// outline's [i]th point: all of it on the convex side, none where the
  /// cortex ends by the hilum.
  static double _taper(int i) {
    final double run = (_runTo - _runFrom).toDouble();
    final double from = (i - _runFrom) / run;
    final double end = math.min(from, 1 - from) / NodeAnatomy.taper;
    final double x = end.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// The band between [from] and [to] in from the capsule, closed.
  static List<Offset> _band(double from, double to) => <Offset>[
    ..._runAt(from),
    ..._runAt(to).reversed,
  ];

  /// The follicles: along the middle of the cortex, evenly, each a little
  /// wider or narrower, every other with a germinal centre set toward the
  /// medulla under a mantle cap.
  static final List<NodeFollicle> _folliclesMm = () {
    final math.Random random = math.Random(NodeStyle.seed);
    final List<Offset> line = _runAt(NodeAnatomy.cortex / 2);
    final List<double> along = _along(line);
    const int count = NodeAnatomy.follicles;
    return <NodeFollicle>[
      for (int k = 0; k < count; k++)
        () {
          final int i = _indexAt(
            along,
            along.last *
                (NodeAnatomy.spread +
                    (1 - 2 * NodeAnatomy.spread) * (k + 0.5) / count),
          );
          final Offset c = line[i];
          final Offset inward = _inMm[(i + _runFrom) % _inMm.length];
          final double r =
              NodeAnatomy.follicleLeast +
              (NodeAnatomy.follicleMost - NodeAnatomy.follicleLeast) *
                  random.nextDouble();
          final bool germ = k.isEven;
          return (
            centre: c,
            radius: r,
            germ: germ ? c + inward * (r * 0.22) : null,
            germRadius: r * NodeAnatomy.germinal,
          );
        }(),
    ];
  }();

  /// The trabeculae: from the capsule inward between the follicles.
  static final List<(Offset, Offset)> _trabeculaeMm = () {
    final List<double> along = _along(_runAt(0));
    const int count = NodeAnatomy.trabeculae;
    return <(Offset, Offset)>[
      for (int k = 0; k < count; k++)
        () {
          final int i =
              _indexAt(
                along,
                along.last *
                    (NodeAnatomy.spread / 2 +
                        (1 - NodeAnatomy.spread) * (k + 1) / (count + 1)),
              ) +
              _runFrom;
          final Offset a = _outlineMm[i % _outlineMm.length];
          final Offset way = _inMm[i % _inMm.length];
          return (a, a + way * (NodeAnatomy.trabecula * _taper(i)));
        }(),
    ];
  }();

  /// The hilum's middle, where the cords and the sinuses gather.
  static const Offset _hilumMm = Offset(
    0,
    NodeAnatomy.width / 2 - NodeAnatomy.hilumDepth - 0.4,
  );

  /// The medullary cords, from the paracortex's inner edge, evenly across
  /// it, wandering down to the hilum; and the sinuses between them, each
  /// half way between two cords, point for point.
  static final List<List<Offset>> _cordsMm = () {
    final math.Random random = math.Random(NodeStyle.seed + 1);
    final List<Offset> edge = _runAt(NodeAnatomy.paracortex);
    final List<double> along = _along(edge);
    const int count = NodeAnatomy.cords + 1;
    return <List<Offset>>[
      for (int k = 0; k <= count; k++)
        () {
          final Offset a =
              edge[_indexAt(along, along.last * (0.06 + 0.88 * k / count))];
          final Offset b = _hilumMm + Offset(a.dx * 0.1, 0);
          final double phase = random.nextDouble() * 2 * math.pi;
          final double sway =
              NodeAnatomy.cordSway * (0.6 + random.nextDouble());
          final Offset way = b - a;
          final Offset across =
              Offset(-way.dy, way.dx) / math.max(way.distance, 1e-9);
          final Offset c = Offset((a.dx + b.dx) / 2, (a.dy + 3 * b.dy) / 4);
          return <Offset>[
            for (int s = 0; s <= 24; s++)
              () {
                final double t = s / 24;
                return _quadratic(a, c, b, t) +
                    across *
                        (sway *
                            math.sin(math.pi * t) *
                            math.sin(2.4 * math.pi * t + phase));
              }(),
          ];
        }(),
    ];
  }();

  /// The cords proper, the first and last laid only to bound the sinuses
  /// beside them.
  static final List<List<Offset>> _cordsShownMm = _cordsMm.sublist(
    1,
    _cordsMm.length - 1,
  );

  static final List<List<Offset>> _medullarySinusesMm = <List<Offset>>[
    for (int k = 0; k + 1 < _cordsMm.length; k++)
      <Offset>[
        for (int s = 0; s < _cordsMm[k].length; s++)
          Offset.lerp(_cordsMm[k][s], _cordsMm[k + 1][s], 0.5)!,
      ],
  ];

  // The parts, laid in the scene.

  /// The node's outline and the points it is followed by.
  late final List<Offset> outlinePoints = _placed(_outlineMm);
  late final Path outline = Path()..addPolygon(outlinePoints, true);
  late final Rect box = _bounds(outlinePoints);

  /// The bands under the capsule: the cortex and the paracortex, each
  /// closed; the subcapsular sinus's middle line.
  late final List<Offset> cortexBand = _placed(_band(0, NodeAnatomy.cortex));
  late final List<Offset> paracortexBand = _placed(
    _band(NodeAnatomy.cortex, NodeAnatomy.paracortex),
  );
  late final List<Offset> subcapsular = _placed(_runAt(NodeAnatomy.sinus / 2));

  /// The cut face's edge under the capsule and the line it turns away to,
  /// point for point, all the way round.
  late final List<Offset> rimInner = _placed(<Offset>[
    for (int i = 0; i < _outlineMm.length; i++)
      _outlineMm[i] + _inMm[i] * NodeStyle.rim,
  ]);

  /// Whether the outline's [i]th point lies where the cortex is missing,
  /// at the hilum.
  bool atHilum(int i) => i < _runFrom || i > _runTo;

  late final List<NodeFollicle> follicles = <NodeFollicle>[
    for (final NodeFollicle f in _folliclesMm)
      (
        centre: place(f.centre),
        radius: mm(f.radius),
        germ: f.germ == null ? null : place(f.germ!),
        germRadius: mm(f.germRadius),
      ),
  ];

  late final List<(Offset, Offset)> trabeculae = <(Offset, Offset)>[
    for (final (Offset a, Offset b) in _trabeculaeMm) (place(a), place(b)),
  ];

  late final List<List<Offset>> cords = <List<Offset>>[
    for (final List<Offset> c in _cordsShownMm) _placed(c),
  ];
  late final List<List<Offset>> medullarySinuses = <List<Offset>>[
    for (final List<Offset> s in _medullarySinusesMm) _placed(s),
  ];

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(NodeStyle.edgeStep), bend: 0.9);

  /// The afferent lymphatics, and at the hilum the efferent, the artery and
  /// the vein.
  late final List<TubeCourse> afferents = <TubeCourse>[
    for (final AnatomyTube t in NodeAnatomy.afferents) _tube(t),
  ];
  late final TubeCourse efferent = _tube(NodeAnatomy.efferent);
  late final TubeCourse artery = _tube(NodeAnatomy.artery);
  late final TubeCourse vein = _tube(NodeAnatomy.vein);

  late final List<TubeCourse> beside = <TubeCourse>[
    ...afferents,
    efferent,
    artery,
    vein,
  ];

  /// Where the body goes in: in the subcapsular sinus at the crown.
  late final Offset site = place(NodeAnatomy.site);

  // Where the parts are named.

  /// The follicle nearest the node's crown on the left, where the follicles
  /// are named; the paracortex, the medulla, an afferent lymphatic and the
  /// efferent.
  late final Offset folliclesName =
      follicles[NodeAnatomy.follicles ~/ 3].centre;
  late final Offset paracortexName = place(NodeAnatomy.paracortexName);
  late final Offset medullaName = place(NodeAnatomy.medullaName);
  late final Offset cordName = cords[NodeAnatomy.cords ~/ 2][10];
  late final Offset afferentName =
      afferents[2].centres[afferents[2].length ~/ 2];
  late final Offset efferentName = efferent.centres[efferent.length * 2 ~/ 3];

  /// Where the zoom's cell's home is named.
  Offset get homeName => switch (home) {
    NodeHome.sinuses || NodeHome.cortex => site,
    NodeHome.follicles =>
      follicles
          .reduce(
            (NodeFollicle a, NodeFollicle b) =>
                (a.centre - site).distanceSquared <=
                    (b.centre - site).distanceSquared
                ? a
                : b,
          )
          .centre,
    NodeHome.paracortex => paracortexName,
    NodeHome.cords => cordName,
  };

  /// Whether [p] lies inside the node's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  /// For tests: the cortex's run of the outline's points.
  static (int, int) get runIndices => (_runFrom, _runTo);
}

/// The distance along [line] at each of its points.
List<double> _along(List<Offset> line) {
  final List<double> out = <double>[0];
  for (int i = 1; i < line.length; i++) {
    out.add(out.last + (line[i] - line[i - 1]).distance);
  }
  return out;
}

/// The point of [along] nearest [d].
int _indexAt(List<double> along, double d) {
  int best = 0;
  for (int i = 1; i < along.length; i++) {
    if ((along[i] - d).abs() < (along[best] - d).abs()) {
      best = i;
    }
  }
  return best;
}

Offset _quadratic(Offset a, Offset c, Offset b, double t) {
  final double u = 1 - t;
  return a * (u * u) + c * (2 * u * t) + b * (t * t);
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
