import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../lobules.dart';
import '../../outline_morph.dart';
import '../../relief.dart';
import '../../tube_course.dart';
import 'salivary_anatomy.dart';
import 'salivary_style.dart';

/// The salivary gland as the zoom's organ scene draws it: the parotid in
/// place, seen from the side, and what lies round it, every shape in the
/// scene's units at its real size.
///
/// The parotid is drawn from general anatomy ([SalivaryAnatomy]), its
/// middle the body's outline's middle; the place its tissue is sampled
/// stays the body's ([site]). The step from the body draws the body's
/// outline in toward the parotid's own ([outlineAt]). Everything here is
/// geometry: what it is drawn in is `SalivaryArt`'s.
final class SalivaryForm {
  SalivaryForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
  }) : scale = length / SalivaryAnatomy.length {
    final List<Offset> knots = _placed(SalivaryAnatomy.parotid);
    final List<Offset> dense = Contour(
      knots,
    ).sampled(SalivaryStyle.outlineSpan).points;
    final List<Offset> diagramDense = Contour(
      diagram,
    ).sampled(SalivaryStyle.outlineSpan).points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool flip = _area(dense).sign != _area(diagramDense).sign;
    final List<Offset> template = flip ? knots.reversed.toList() : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(
      template,
    ).sampled(SalivaryStyle.outlineSpan).points;
    box = _bounds(outlinePoints);
    _inward = _area(outlinePoints) > 0 ? 1.0 : -1.0;
    // The two outlines, both tall, met at their tops and their bottoms.
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: SalivaryStyle.morphPoints,
      bed: mm(SalivaryStyle.bed),
      bottoms: true,
    );
  }

  /// The form for [anatomy]'s salivary gland, where the body draws it as
  /// [part], in a view [view] metres across.
  factory SalivaryForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return SalivaryForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
    );
  }

  /// Where the tissue is sampled: the body's own place for it.
  final Offset site;

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's millimetres, in the scene's units.
  final double scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => mm * scale;

  /// A point of the scene, in the anatomy's millimetres.
  Offset toMm(Offset p) => p / scale;

  /// [millimetres] of the real gland, in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  // The parotid, and the step from the body.

  /// The parotid's outline, smooth, the points it is followed by, and
  /// their box.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// Which way into the parotid the outline's left hand points: 1 or -1.
  late final double _inward;

  late final OutlineMorph _morph;

  /// The outline the step from the body draws: the body's own at [settle]
  /// 0, the parotid's at 1, drawn in by [bed] toward the bed it lies on.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// The path [outlineAt] draws: at [settle] 0 the very curve the body's
  /// outline is drawn by.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// Whether [p] lies inside the parotid's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  /// How the parotid stands up off the page.
  late final Relief relief = _relief(
    outlinePoints,
    SalivaryStyle.glandInflation,
  );

  /// Its lobules.
  late final Lobules lobules = Lobules.lay(
    outlinePoints,
    box: box,
    inward: _inward,
    style: SalivaryStyle.lobules,
    mm: mm,
    seed: 53,
  );

  // The accessory gland.

  /// Its outline: an oval along the duct.
  late final List<Offset> accessoryPoints = () {
    const Offset c = SalivaryAnatomy.accessory;
    final double along = _ductAngleAt(c.dx);
    final double cos = math.cos(along);
    final double sin = math.sin(along);
    const double a = SalivaryAnatomy.accessoryLength / 2;
    const double b = SalivaryAnatomy.accessoryWidth / 2;
    return Contour(<Offset>[
      for (int k = 0; k < 16; k++)
        () {
          final double t = 2 * math.pi * k / 16;
          final double x = a * math.cos(t);
          final double y = b * math.sin(t);
          return place(c + Offset(x * cos - y * sin, x * sin + y * cos));
        }(),
    ]).sampled(SalivaryStyle.outlineSpan).points;
  }();
  late final Path accessoryPath = Path()..addPolygon(accessoryPoints, true);
  late final Relief accessoryRelief = _relief(
    accessoryPoints,
    SalivaryStyle.glandInflation,
  );
  late final Lobules accessoryLobules = Lobules.lay(
    accessoryPoints,
    box: _bounds(accessoryPoints),
    inward: _area(accessoryPoints) > 0 ? 1.0 : -1.0,
    style: SalivaryStyle.lobules,
    mm: mm,
    seed: 59,
  );

  /// The way the duct runs, an angle on screen, where it crosses [x]
  /// millimetres: its accessory gland lies along it.
  static double _ductAngleAt(double x) {
    final List<Offset> points = SalivaryAnatomy.duct.points;
    for (int i = 0; i + 1 < points.length; i++) {
      final Offset a = points[i];
      final Offset b = points[i + 1];
      if ((a.dx - x) * (b.dx - x) <= 0) {
        // Read front to back, so the oval's long axis is the same either
        // way.
        return math.atan2(a.dy - b.dy, a.dx - b.dx);
      }
    }
    return 0;
  }

  // What lies round it.

  /// The submandibular gland.
  late final List<Offset> submandibularPoints = _closed(
    SalivaryAnatomy.submandibular,
  );
  late final Path submandibular = Path()
    ..addPolygon(submandibularPoints, true);
  late final Relief submandibularRelief = _relief(
    submandibularPoints,
    SalivaryStyle.glandInflation,
  );
  late final Lobules submandibularLobules = Lobules.lay(
    submandibularPoints,
    box: _bounds(submandibularPoints),
    inward: _area(submandibularPoints) > 0 ? 1.0 : -1.0,
    style: SalivaryStyle.lobules,
    mm: mm,
    seed: 61,
  );

  /// The masseter.
  late final List<Offset> masseterPoints = _closed(SalivaryAnatomy.masseter);
  late final Path masseter = Path()..addPolygon(masseterPoints, true);
  late final Relief masseterRelief = _relief(
    masseterPoints,
    SalivaryStyle.masseterInflation,
  );

  /// The ear, its concha and the opening of its canal, and the groove
  /// inside the rim of its helix.
  late final List<Offset> earPoints = _closed(SalivaryAnatomy.ear);
  late final Path ear = Path()..addPolygon(earPoints, true);
  late final Relief earRelief = _relief(
    earPoints,
    SalivaryStyle.earInflation,
  );
  late final List<Offset> conchaPoints = _closed(SalivaryAnatomy.concha);
  late final Path concha = Path()..addPolygon(conchaPoints, true);
  late final Relief conchaRelief = _relief(
    conchaPoints,
    SalivaryStyle.conchaInflation,
  );
  late final Rect meatus = Rect.fromCenter(
    center: place(SalivaryAnatomy.meatus),
    width: mm(2 * SalivaryAnatomy.meatusRadii.$1),
    height: mm(2 * SalivaryAnatomy.meatusRadii.$2),
  );
  late final Path scapha = () {
    final List<Offset> line = _placed(SalivaryAnatomy.scapha);
    final Path path = Path()..moveTo(line.first.dx, line.first.dy);
    for (int i = 0; i + 1 < line.length; i++) {
      final Offset p0 = line[math.max(0, i - 1)];
      final Offset p1 = line[i];
      final Offset p2 = line[i + 1];
      final Offset p3 = line[math.min(line.length - 1, i + 2)];
      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }();

  /// A tube of the anatomy laid in the scene, its rows at most [row]
  /// millimetres apart.
  TubeCourse tube(AnatomyTube tube, {double row = SalivaryStyle.tubeRow}) =>
      TubeCourse(tube, place, scale, mm(row), bend: SalivaryStyle.bend);

  late final TubeCourse duct = tube(SalivaryAnatomy.duct);
  late final TubeCourse arch = tube(SalivaryAnatomy.arch);
  late final TubeCourse mandible = tube(SalivaryAnatomy.mandible);
  late final List<TubeCourse> nerves = <TubeCourse>[
    for (final AnatomyTube nerve in SalivaryAnatomy.nerves) tube(nerve),
  ];
  late final TubeCourse artery = tube(SalivaryAnatomy.artery);
  late final TubeCourse vein = tube(SalivaryAnatomy.vein);

  // The window, for a duct cell.

  late final Offset _windowCentre = place(
    const Offset(SalivaryStyle.windowX, SalivaryStyle.windowY),
  );
  late final double _windowRx = mm(SalivaryStyle.windowRx);
  late final double _windowRy = mm(SalivaryStyle.windowRy);

  /// The gland's superficial part cut away round the duct's way in, as one
  /// path, inside the gland.
  late final Path window = Path.combine(
    PathOperation.intersect,
    outline,
    Path()..addOval(
      Rect.fromCenter(
        center: _windowCentre,
        width: 2 * _windowRx,
        height: 2 * _windowRy,
      ),
    ),
  );

  /// The cut's edge where it lies inside the gland: each point, and the
  /// way out of the window there.
  late final List<(Offset, Offset)> windowEdge = () {
    final List<(Offset, Offset)> out = <(Offset, Offset)>[];
    const int count = 96;
    for (int k = 0; k < count; k++) {
      final double t = 2 * math.pi * k / count;
      final Offset p =
          _windowCentre +
          Offset(_windowRx * math.cos(t), _windowRy * math.sin(t));
      if (!_inside(outlinePoints, p)) {
        continue;
      }
      final Offset normal = Offset(
        math.cos(t) / _windowRx,
        math.sin(t) / _windowRy,
      );
      out.add((p, normal / normal.distance));
    }
    return out;
  }();

  /// The duct inside the gland, from its front edge to the hilum.
  late final Path innerDuct = () {
    final Offset entry = place(SalivaryAnatomy.duct.points[1]);
    final Offset hilum = place(SalivaryAnatomy.hilum);
    return Path()
      ..moveTo(entry.dx, entry.dy)
      ..quadraticBezierTo(
        (entry.dx + hilum.dx) / 2,
        (entry.dy + hilum.dy) / 2 + mm(0.6),
        hilum.dx,
        hilum.dy,
      );
  }();

  /// The ducts it branches into from the hilum, out through the gland: the
  /// interlobular ducts, forking, as one path.
  late final Path branches = () {
    final Path path = Path();
    final math.Random random = math.Random(67);
    final Offset hilum = place(SalivaryAnatomy.hilum);
    void grow(Offset from, double heading, double reach, int fork) {
      final Offset to =
          from + Offset(math.cos(heading), math.sin(heading)) * reach;
      final Offset bend =
          (from + to) / 2 +
          Offset(-math.sin(heading), math.cos(heading)) *
              (reach * 0.25 * (random.nextDouble() - 0.5));
      path
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy);
      if (fork >= SalivaryStyle.ductForks) {
        return;
      }
      for (final double turn in const <double>[-0.42, 0.42]) {
        grow(
          to,
          heading + turn + 0.2 * (random.nextDouble() - 0.5),
          reach * SalivaryStyle.ductShrink,
          fork + 1,
        );
      }
    }

    // Back through the gland, away from where the duct leaves it.
    for (int k = 0; k < SalivaryStyle.ductBranches; k++) {
      final double heading =
          -math.pi * 0.55 +
          math.pi * 1.1 * k / (SalivaryStyle.ductBranches - 1);
      grow(hilum, heading, mm(SalivaryStyle.ductReach), 1);
    }
    return path;
  }();

  /// A duct reaching the place the tissue is sampled, from the hilum.
  late final Path siteBranch = () {
    final Offset hilum = place(SalivaryAnatomy.hilum);
    final Offset middle = (hilum + site) / 2;
    final Offset way = site - hilum;
    final Offset aside = Offset(-way.dy, way.dx) * 0.12;
    return Path()
      ..moveTo(hilum.dx, hilum.dy)
      ..quadraticBezierTo(
        middle.dx + aside.dx,
        middle.dy + aside.dy,
        site.dx,
        site.dy,
      );
  }();

  // Where each part is named.

  late final Offset ductName = place(SalivaryAnatomy.ductName);
  late final Offset nerveName = place(SalivaryAnatomy.nerveName);
  late final Offset submandibularName = place(
    SalivaryAnatomy.submandibularName,
  );

  // Helpers.

  Relief _relief(List<Offset> points, double inflation) => Relief(
    points,
    cell: mm(SalivaryStyle.reliefCell),
    inflation: inflation,
    sweeps: SalivaryStyle.reliefSweeps,
  );

  /// The closed outline through [mm], followed closely, in the scene.
  List<Offset> _closed(List<Offset> mm) =>
      Contour(_placed(mm)).sampled(SalivaryStyle.outlineSpan).points;

  static double _area(List<Offset> points) {
    double sum = 0;
    for (int i = 0; i < points.length; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % points.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum / 2;
  }

  static Rect _bounds(List<Offset> points) {
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
}

/// Whether [p] lies inside the closed outline [points].
bool _inside(List<Offset> points, Offset p) {
  bool inside = false;
  final int n = points.length;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final Offset a = points[i];
    final Offset b = points[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}
