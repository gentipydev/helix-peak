import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import '../brain/brain_anatomy.dart';
import 'pituitary_anatomy.dart';
import 'pituitary_style.dart';

/// Where in the pituitary the zoom's cell lives, which its drawing lights
/// in the mark, by the Atlas's name for the cell. By the kind of cell,
/// never by gene.
enum PituitaryHome {
  /// The anterior lobe: its somatotropes, lactotropes, corticotropes,
  /// thyrotropes and gonadotropes, and every cell that has no part of the
  /// gland of its own to be drawn at its size.
  anterior,

  /// The posterior lobe: its pituicytes.
  posterior;

  /// Where a cell the Atlas calls [cell] lives.
  static PituitaryHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('pituicyte') || name.contains('posterior')) {
      return posterior;
    }
    return anterior;
  }

  /// What its name says.
  String get word => switch (this) {
    anterior => 'anterior lobe',
    posterior => 'posterior lobe',
  };
}

/// The pituitary gland as the zoom's organ scene draws it, cut down its
/// middle as the brain's stop cuts the brain: every part in the scene's
/// units at its real size, the middle of the body's outline of it at the
/// origin.
///
/// The gland is drawn from general anatomy ([PituitaryAnatomy]), in the
/// brain's own millimetres, and laid on the body's outline of it so that
/// the place it is gone into lies on the place the body goes in ([site]).
/// The step from the body draws the body's outline in toward the gland's
/// own ([pathAt]). Everything here is geometry: what it is drawn in is
/// `PituitaryArt`'s.
final class PituitaryForm {
  PituitaryForm({
    required List<Offset> diagram,
    required this.site,
    required this.view,
    this.home = PituitaryHome.anterior,
  }) : scale = 1e-3 / view {
    final List<Offset> knots = _placed(PituitaryAnatomy.outline);
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(PituitaryStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(knots).sign != _area(diagramDense).sign
        ? knots.reversed.toList()
        : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template)
        .sampled(PituitaryStyle.outlineSpan)
        .points;
    box = _bounds(outlinePoints);
    _diagramBox = _bounds(diagramDense);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: PituitaryStyle.morphPoints,
      bed: mm(PituitaryStyle.bed),
    );
  }

  /// The gland where the body draws it as [part], in a view [view] metres
  /// across, its cells' [home] in it.
  factory PituitaryForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    PituitaryHome home = PituitaryHome.anterior,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return PituitaryForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the gland, in the scene: in its anterior
  /// lobe.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final PituitaryHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The gland's outline, its two lobes as one, and the points it is
  /// followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - PituitaryAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => PituitaryAnatomy.site + (p - site) / scale;

  /// How far the gland's box lies from the body's outline's, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  List<Offset> _closed(List<Offset> mm) =>
      Contour(_placed(mm)).sampled(PituitaryStyle.outlineSpan).points;

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

  // How much shows where.

  /// How much of what lies above the third ventricle's floor shows at [p]
  /// in the scene: none above it, all of it from the chiasm down.
  double brainShownAt(Offset p) {
    final double y = toMm(p).dy;
    return _smooth(
      (y - PituitaryAnatomy.topGone) /
          (PituitaryAnatomy.topWhole - PituitaryAnatomy.topGone),
    );
  }

  /// How much of the bone and its sinus shows at [p] in the scene: all of
  /// it round the fossa, fading out below and in front.
  double boneShownAt(Offset p) {
    final Offset q = toMm(p);
    return _smooth(
          (PituitaryAnatomy.footShown + PituitaryAnatomy.footFade - q.dy) /
              PituitaryAnatomy.footFade,
        ) *
        _smooth(
          (q.dx - PituitaryAnatomy.frontShown + PituitaryAnatomy.frontFade) /
              PituitaryAnatomy.frontFade,
        );
  }

  // The parts, laid in the scene.

  /// The two lobes, the cleft between the pars anterior and the pars
  /// intermedia.
  late final List<Offset> anterior = _closed(PituitaryAnatomy.anterior);
  late final List<Offset> posterior = _closed(PituitaryAnatomy.posterior);
  late final List<Offset> cleft = _placed(PituitaryAnatomy.cleft);

  /// The stalk, as wide as the brain draws it at either end, from the
  /// tuber cinereum to the gland.
  late final List<Offset> stalk = _placed(
    _band(
      BrainAnatomy.infundibulum,
      BrainAnatomy.infundibulumTop,
      BrainAnatomy.infundibulumFoot,
    ),
  );

  /// The hypothalamus, the chiasm and the mammillary body, the brain's own.
  late final List<Offset> hypothalamus = _closed(BrainAnatomy.hypothalamus);
  late final List<Offset> chiasm = _closed(BrainAnatomy.chiasm);
  late final List<Offset> mammillary = _placed(<Offset>[
    for (int k = 0; k < 32; k++)
      BrainAnatomy.mammillary.center +
          Offset(
            math.cos(2 * math.pi * k / 32) * BrainAnatomy.mammillary.width / 2,
            math.sin(2 * math.pi * k / 32) * BrainAnatomy.mammillary.height / 2,
          ),
  ]);

  /// The sphenoid bone cut round the fossa, and the sinus in it.
  late final List<Offset> bone = _placed(PituitaryAnatomy.bone);
  late final List<Offset> sinus = _closed(PituitaryAnatomy.sinus);

  /// The sinus's edges, along which its rim is drawn.
  late final List<Offset> sinusEdge = sinus;

  /// The diaphragma sellae, either side of the stalk.
  late final List<Offset> diaphragmFront = _placed(
    PituitaryAnatomy.diaphragmFront,
  );
  late final List<Offset> diaphragmBack = _placed(
    PituitaryAnatomy.diaphragmBack,
  );

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(PituitaryStyle.edgeStep), bend: 0.9);

  /// The portal vessels down the stalk.
  late final List<TubeCourse> portalVessels = <TubeCourse>[
    for (final AnatomyTube t in PituitaryAnatomy.portalVessels) _tube(t),
  ];

  // Where the parts are named.

  late final Offset posteriorName = place(PituitaryAnatomy.posteriorName);
  late final Offset stalkName = place(PituitaryAnatomy.stalkName);
  late final Offset chiasmName = place(PituitaryAnatomy.chiasmName);
  late final Offset sinusName = place(PituitaryAnatomy.sinusName);
  late final Offset hypothalamusName = place(PituitaryAnatomy.hypothalamusName);

  /// Where the zoom's cell's home is named: the anterior lobe at the site,
  /// or the posterior lobe at its middle.
  Offset get homeName => home == PituitaryHome.anterior ? site : posteriorName;

  /// Every part drawn round the gland, where it shows: what its names keep
  /// clear of.
  late final List<Offset> drawn = <Offset>[
    for (final List<Offset> part in <List<Offset>>[
      stalk,
      chiasm,
      mammillary,
      hypothalamus,
    ])
      for (final Offset p in part)
        if (brainShownAt(p) > 0.1) p,
    // The bone sampled a millimetre apart, inside it, where it shows.
    for (double y = _bounds(bone).top; y <= _bounds(bone).bottom; y += mm(1))
      for (double x = _bounds(bone).left; x <= _bounds(bone).right; x += mm(1))
        if (_inside(bone, Offset(x, y)) && boneShownAt(Offset(x, y)) > 0.1)
          Offset(x, y),
  ];
}

/// A band round an open curve through [points], [from] wide to either side
/// at its start and [to] at its end, closed, as the brain lays its stalk.
List<Offset> _band(List<Offset> points, double from, double to) {
  final List<Offset> line = _curve(points);
  final int n = line.length;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset t = line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)];
    final Offset across = Offset(-t.dy, t.dx) / t.distance;
    final double half = from + (to - from) * i / (n - 1);
    left.add(line[i] + across * half);
    right.add(line[i] - across * half);
  }
  return <Offset>[...left, ...right.reversed];
}

/// An open Catmull-Rom curve through [knots], closely followed.
List<Offset> _curve(List<Offset> knots) {
  final int n = knots.length;
  Offset knot(int i) => i < 0
      ? knots[0] * 2 - knots[1]
      : i >= n
      ? knots[n - 1] * 2 - knots[n - 2]
      : knots[i];
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < n - 1; i++) {
    final Offset p0 = knot(i - 1);
    final Offset p1 = knot(i);
    final Offset p2 = knot(i + 1);
    final Offset p3 = knot(i + 2);
    final Offset c1 = p1 + (p2 - p0) / 6;
    final Offset c2 = p2 - (p3 - p1) / 6;
    for (int k = 0; k < 8; k++) {
      final double t = k / 8;
      final double u = 1 - t;
      out.add(
        p1 * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            p2 * (t * t * t),
      );
    }
  }
  out.add(knots.last);
  return out;
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
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
