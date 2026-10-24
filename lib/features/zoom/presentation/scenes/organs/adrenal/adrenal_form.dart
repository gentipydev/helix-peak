import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'adrenal_anatomy.dart';
import 'adrenal_style.dart';

/// Where in the adrenal the zoom's cell lives, which its drawing lights in
/// the mark, by the Atlas's name for the cell. By the kind of cell, never
/// by gene.
enum AdrenalHome {
  /// The cortex: its cells, and every cell that has no part of the gland
  /// of its own to be drawn at its size (its endothelium, its fibroblasts,
  /// its immune cells).
  cortex,

  /// The medulla: its chromaffin cells.
  medulla;

  /// Where a cell the Atlas calls [cell] lives.
  static AdrenalHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('medull') ||
        name.contains('chromaffin') ||
        name.contains('pheochromo')) {
      return medulla;
    }
    return cortex;
  }

  /// What its name says.
  String get word => switch (this) {
    cortex => 'cortex',
    medulla => 'medulla',
  };
}

/// The anatomogram's kidney, which the adrenals sit on.
const String _kidney = 'UBERON_0002113';

/// The adrenal gland as the zoom's organ scene draws it, cut through the
/// middle of its thickness, on its kidney's upper pole: every part in the
/// scene's units at its real size, the middle of the body's outline of it
/// at the origin.
///
/// The gland is drawn from general anatomy ([AdrenalAnatomy]): the right
/// one where the body follows its right, the left one, turned over, where
/// it follows its left, each of its own shape, its medial side toward the
/// figure's midline; and laid on the body's outline of it so that the place
/// it is gone into in the anatomy lies on the place the body goes in
/// ([site]). Under it lies the body's own outline of the kidney, its upper
/// pole lit. The step from the body draws the body's outline in toward the
/// gland's own ([pathAt]). Everything here is geometry: what it is drawn in
/// is `AdrenalArt`'s.
final class AdrenalForm {
  AdrenalForm({
    required List<Offset> diagram,
    required this.site,
    required double midline,
    required this.view,
    this.home = AdrenalHome.cortex,
    List<Offset>? kidney,
  }) : scale = 1e-3 / view,
       side = midline >= site.dx ? 1 : -1 {
    final List<Offset> knots = _placed(
      right ? AdrenalAnatomy.rightOutline : AdrenalAnatomy.leftOutline,
    );
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(AdrenalStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(AdrenalStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: AdrenalStyle.morphPoints,
      bed: mm(AdrenalStyle.bed),
      marks: _marks,
    );
    this.kidney = kidney == null
        ? null
        : Contour(kidney).sampled(AdrenalStyle.outlineSpan).points;
  }

  /// The gland where the body draws it as [part] of [figure], in a view
  /// [view] metres across, its cells' [home] in it; the figure's kidney on
  /// that side under it.
  factory AdrenalForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    AnatomyFigure? figure,
    AdrenalHome home = AdrenalHome.cortex,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    final AnatomyPart? kidney = figure?.parts[_kidney];
    List<Offset>? under;
    if (kidney != null) {
      double nearest = double.infinity;
      for (final List<Offset> c in kidney.contours) {
        final double d = (_bounds(c).center - part.site).distance;
        if (d < nearest) {
          nearest = d;
          under = c;
        }
      }
    }
    return AdrenalForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      midline: placed(Offset(0, part.site.dy)).dx,
      view: view,
      home: home,
      kidney: under == null
          ? null
          : <Offset>[for (final Offset p in under) placed(p)],
    );
  }

  /// Where the body goes into the gland, in the scene: in its cortex.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final AdrenalHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Which way across the scene the gland's medial side faces: 1 to the
  /// right, the body's right gland, drawn as the anatomy is; -1 to the left,
  /// its left gland, turned over.
  final double side;

  /// Whether this is the body's right gland.
  bool get right => side > 0;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The gland's outline, its capsule, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// The body's outline of the kidney under it, closely followed; none
  /// where no figure is given.
  late final List<Offset>? kidney;

  /// Where the gland is gone into, in the anatomy's millimetres.
  Offset get _anchor =>
      right ? AdrenalAnatomy.rightSite : AdrenalAnatomy.leftSite;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) =>
      site + Offset(side * (mm.dx - _anchor.dx), mm.dy - _anchor.dy) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) {
    final Offset d = (p - site) / scale;
    return _anchor + Offset(side * d.dx, d.dy);
  }

  /// How far the gland's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the gland's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the gland's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The parts, laid in the scene.

  /// The cut face's edge under the capsule, the line it turns away to,
  /// point for point, the first closed.
  late final List<Offset> rimInner = () {
    final int n = outlinePoints.length;
    final List<Offset> normals = _normals(outlinePoints);
    final double inward =
        _inside(outlinePoints, outlinePoints[0] + normals[0] * mm(0.5))
        ? 1
        : -1;
    return <Offset>[
      for (int i = 0; i < n; i++)
        outlinePoints[i] + normals[i] * (inward * mm(AdrenalStyle.rim)),
    ];
  }();

  /// The medulla, and the zona reticularis's edge round it.
  late final List<Offset> medulla = Contour(
    _placed(right ? AdrenalAnatomy.rightMedulla : AdrenalAnatomy.leftMedulla),
  ).sampled(AdrenalStyle.outlineSpan).points;
  late final List<Offset> reticularis = () {
    final int n = medulla.length;
    final List<Offset> normals = _normals(medulla);
    final double outward = _inside(medulla, medulla[0] + normals[0] * mm(0.3))
        ? -1
        : 1;
    return <Offset>[
      for (int i = 0; i < n; i++)
        medulla[i] + normals[i] * (outward * mm(AdrenalAnatomy.reticularis)),
    ];
  }();

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(AdrenalStyle.edgeStep), bend: 0.9);

  /// The central vein: its channel through the cut, from the medulla to the
  /// hilum, and on out of it, cut short.
  late final TubeCourse channel = _tube(
    right ? AdrenalAnatomy.rightChannel : AdrenalAnatomy.leftChannel,
  );
  late final TubeCourse vein = _tube(
    right ? AdrenalAnatomy.rightVein : AdrenalAnatomy.leftVein,
  );

  /// The suprarenal arteries, each fading out toward where it comes from.
  late final List<TubeCourse> arteries = <TubeCourse>[
    for (final AnatomyTube t
        in right ? AdrenalAnatomy.rightArteries : AdrenalAnatomy.leftArteries)
      _tube(t),
  ];

  /// What is drawn beside the gland, for its names to keep clear of.
  late final List<TubeCourse> beside = <TubeCourse>[vein, ...arteries];

  /// How much of the kidney under it shows at a height [y] in the scene:
  /// its upper pole whole, fading out below.
  double kidneyShownAt(double y) {
    final List<Offset>? k = kidney;
    if (k == null) {
      return 0;
    }
    final double top = _bounds(k).top;
    final double t =
        (y - top - mm(AdrenalAnatomy.poleShown)) / mm(AdrenalAnatomy.poleFade);
    final double x = 1 - t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// The kidney's pole where it shows, closed across where it is gone.
  late final List<Offset> kidneyPole = () {
    final List<Offset>? k = kidney;
    if (k == null) {
      return const <Offset>[];
    }
    final double bottom =
        _bounds(k).top + mm(AdrenalAnatomy.poleShown + AdrenalAnatomy.poleFade);
    return _clipBelow(k, bottom);
  }();

  // Where the parts are named.

  /// Where the zoom's cell's home is named: the cortex at the site, or the
  /// medulla at its middle; and the other where it is not the home.
  late final Offset cortexName = site;
  late final Offset medullaName = _middle(medulla);
  late final Offset veinName = vein.centres[vein.length * 2 ~/ 3];

  /// The kidney named on its pole, under the gland, a little toward its
  /// lateral side; none where no kidney is drawn.
  late final Offset? kidneyName = () {
    final List<Offset>? k = kidney;
    if (k == null) {
      return null;
    }
    final Rect pole = _bounds(kidneyPole);
    final Offset at = Offset(
      pole.center.dx - side * pole.width * 0.18,
      pole.top + mm(AdrenalAnatomy.poleShown) * 0.85,
    );
    return _inside(k, at) ? at : pole.center;
  }();

  /// Where the step from the body meets the gland's outline and the body's,
  /// beside their tops: the lateral side's outermost point low down, the
  /// lowest point and the medial side's outermost, each picked out of
  /// either outline alike.
  late final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, -side, 0.3, 1),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, side, 0.15, 0.6),
      ];

  static int _lowest(List<Offset> points) {
    int best = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy > points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The points of the gland's own outline where the step from the body
  /// meets the body's, for tests: in the order round it from the top.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

/// The mean of [points].
Offset _middle(List<Offset> points) {
  Offset sum = Offset.zero;
  for (final Offset p in points) {
    sum += p;
  }
  return sum / points.length.toDouble();
}

/// The closed outline [points] cut by the level [y]: what lies above it,
/// closed along it.
List<Offset> _clipBelow(List<Offset> points, double y) {
  final List<Offset> out = <Offset>[];
  final int n = points.length;
  for (int i = 0; i < n; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    if (a.dy <= y) {
      out.add(a);
    }
    if ((a.dy <= y) != (b.dy <= y)) {
      out.add(Offset.lerp(a, b, (y - a.dy) / (b.dy - a.dy))!);
    }
  }
  return out;
}

/// The left hand of the way round the closed outline [line] at each point,
/// a unit.
List<Offset> _normals(List<Offset> line) {
  final int n = line.length;
  return <Offset>[
    for (int i = 0; i < n; i++)
      () {
        final Offset t = line[(i + 1) % n] - line[(i - 1 + n) % n];
        final double length = t.distance;
        return length <= 0 ? Offset.zero : Offset(t.dy, -t.dx) / length;
      }(),
  ];
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
