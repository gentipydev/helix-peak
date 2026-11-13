import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import '../cervix/cervix_anatomy.dart';
import '../cervix/cervix_form.dart';
import 'uterus_anatomy.dart';
import 'uterus_style.dart';

/// Where in the endometrium the zoom's cell lives, by the Atlas's name for
/// it, and the word the stop names it by: all of the endometrium is drawn
/// in the mark whichever it is, its glands, its surface and its stroma
/// being too fine to tell apart at an organ's scale, and the name says
/// which of them the cell is.
enum UterusHome {
  /// Its glands: a glandular or secretory cell, and any other.
  glands('endometrial glands'),

  /// The epithelium lining its cavity: a luminal or a ciliated cell.
  surface('surface epithelium'),

  /// Its stroma, between the glands: a stromal cell.
  stroma('endometrial stroma');

  const UterusHome(this.word);

  final String word;

  /// Where a cell the Atlas calls [cell] lives: its glands unless the name
  /// says otherwise.
  static UterusHome of(String? cell) {
    final String name = cell?.toLowerCase() ?? '';
    if (name.contains('stromal')) {
      return stroma;
    }
    if (name.contains('luminal') || name.contains('ciliated')) {
      return surface;
    }
    return glands;
  }
}

/// The uterus as the zoom's organ scene draws it, bivalved along its canal
/// to the fundus: every part in the scene's units at its real size, the
/// middle of the body's outline of the endometrium at the origin.
///
/// The uterus is drawn from general anatomy ([UterusAnatomy]), its cervix
/// the cervix specimen's ([CervixAnatomy]), and laid on the body's outline
/// of the endometrium so that the place it is gone into in the anatomy
/// ([UterusAnatomy.site]) lies on the place the body goes in ([site]). The
/// anatomogram draws the endometrium as a band round the cavity, the
/// outline running round its outside and back round its inside: the
/// outline the step from the body draws in from is the band's silhouette
/// ([silhouetteOf]), the cavity filled. Where the zoom's cell lives is
/// [home]. Everything here is geometry: what it is drawn in is
/// `UterusArt`'s.
final class UterusForm {
  UterusForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
    this.home = UterusHome.glands,
  }) : scale = length / UterusAnatomy.length,
       diagramPoints = silhouetteOf(diagram) {
    final List<Offset> diagramDense = Contour(diagramPoints)
        .sampled(UterusStyle.outlineSpan)
        .points;
    _diagramBox = _bounds(diagramDense);
    final List<Offset> placed = _placed(_outlineMm);
    outlinePoints = _area(placed).sign != _area(diagramDense).sign
        ? placed.reversed.toList()
        : placed;
    outline = Path()..addPolygon(outlinePoints, true);
    box = _bounds(outlinePoints);
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagramPoints).toPath(),
      count: UterusStyle.morphPoints,
      bed: mm(UterusStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The uterus where the body draws the endometrium as [part], in a view
  /// [view] metres across, the cell living in it at [home].
  factory UterusForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    UterusHome home = UterusHome.glands,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return UterusForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
      home: home,
    );
  }

  /// Where the body goes into the endometrium, in the scene: its
  /// functional layer on the body's right, where the cut crosses it.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Where in the endometrium the zoom's cell lives.
  final UterusHome home;

  /// The body's outline of the endometrium, its cavity filled.
  final List<Offset> diagramPoints;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The uterus's outline, where the cut crosses its outer surface, the
  /// points it is followed by, and its box.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - UterusAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => UterusAnatomy.site + (p - site) / scale;

  /// How far the uterus lies from the body's outline it draws in from, in
  /// millimetres, laid so that the site lies where the body's is: what
  /// laying it so costs.
  double get anchorShift => (box.center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the uterus's at 1, and [bed] of the way on toward the bed
  /// it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the uterus's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  /// [points], the anatomogram's outline of the endometrium, a band drawn
  /// round the outside of the cavity and back round its inside, as the
  /// shape it covers with its cavity filled: row by row, from its leftmost
  /// crossing to its rightmost, down its left side and back up its right.
  static List<Offset> silhouetteOf(List<Offset> points, {int rows = 160}) {
    final Rect box = _bounds(points);
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    final int n = points.length;
    for (int r = 0; r <= rows; r++) {
      // A hair inside the box, so the top and the bottom rows cross it.
      final double y = box.top + box.height * (0.002 + 0.996 * r / rows);
      double least = double.infinity;
      double most = double.negativeInfinity;
      for (int i = 0; i < n; i++) {
        final Offset a = points[i];
        final Offset b = points[(i + 1) % n];
        if ((a.dy <= y) != (b.dy <= y)) {
          final double x = a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
          least = math.min(least, x);
          most = math.max(most, x);
        }
      }
      if (least <= most) {
        left.add(Offset(least, y));
        right.add(Offset(most, y));
      }
    }
    final List<Offset> out = <Offset>[...left, ...right.reversed];
    // Points all but repeating the one before them go.
    final double near = 0.004 * (box.width + box.height);
    final List<Offset> kept = <Offset>[];
    for (final Offset p in out) {
      if (kept.isEmpty || (p - kept.last).distance > near) {
        kept.add(p);
      }
    }
    return kept;
  }

  // The anatomy in millimetres, built once for every uterus.

  /// The outline's own points: its right half, the body's and then the
  /// cervix's, and its left, mirrored, from the middle of the fundus round
  /// by the vaginal part's end, followed closely.
  static final List<Offset> _outlineMm = () {
    final List<Offset> half = <Offset>[
      ...UterusAnatomy.body,
      for (final Offset p in CervixAnatomy.half)
        if (p.dy >= UterusAnatomy.isthmus) p,
    ];
    return Contour(<Offset>[
      ...half,
      for (int i = half.length - 2; i >= 1; i--)
        Offset(-half[i].dx, half[i].dy),
    ]).sampled(UterusStyle.outlineSpan).points;
  }();

  /// The outline in millimetres. For tests.
  static List<Offset> get outlineMm => _outlineMm;

  /// How far the cavity, or the canal below it, reaches to either side at
  /// [y], in millimetres.
  static double widthAt(double y) => y >= UterusAnatomy.isthmus
      ? CervixForm.grooveAt(y)
      : _smoothThrough(UterusAnatomy.cavity, y);

  /// Where the cavity's fundal border runs at [x], bowed down between its
  /// angles.
  static double fundusAt(double x) {
    final double t = (x / UterusAnatomy.angle.dx).clamp(-1.0, 1.0);
    return UterusAnatomy.angle.dy + UterusAnatomy.fundalBow * (1 - t * t);
  }

  /// How thick the endometrium is at [y].
  static double thicknessAt(double y) =>
      UterusAnatomy.endometriumIsthmus +
      (UterusAnatomy.endometrium - UterusAnatomy.endometriumIsthmus) *
          _smooth((UterusAnatomy.isthmus - y) / UterusAnatomy.thinning);

  /// The cavity's edge, open at the internal orifice: up its left side from
  /// the orifice, across its fundal border and down its right side.
  static final List<Offset> _edgeMm = () {
    const double top = -47.2;
    const double bottom = UterusAnatomy.isthmus;
    final int steps = ((bottom - top) / UterusStyle.edgeStep).ceil();
    final List<Offset> right = <Offset>[
      for (int i = 0; i <= steps; i++)
        () {
          final double y = top + (bottom - top) * i / steps;
          return Offset(widthAt(y), y);
        }(),
    ];
    const double a = 15.6;
    final int across = ((2 * a) / UterusStyle.edgeStep).ceil();
    return <Offset>[
      for (final Offset p in right.reversed) Offset(-p.dx, p.dy),
      for (int i = 1; i < across; i++)
        () {
          final double x = -a + 2 * a * i / across;
          return Offset(x, fundusAt(x));
        }(),
      ...right,
    ];
  }();

  /// The cavity, closed across the internal orifice.
  static final List<Offset> _cavityMm = _edgeMm;

  /// The cavity and the canal, one opening from the fundal border down to
  /// the external orifice.
  static final List<Offset> _grooveMm = () {
    const double top = -47.2;
    const double bottom = CervixAnatomy.externalOs;
    final int steps = ((bottom - top) / UterusStyle.edgeStep).ceil();
    final List<Offset> right = <Offset>[
      for (int i = 0; i <= steps; i++)
        () {
          final double y = top + (bottom - top) * i / steps;
          return Offset(widthAt(y), y);
        }(),
    ];
    const double a = 15.6;
    final int across = ((2 * a) / UterusStyle.edgeStep).ceil();
    return <Offset>[
      for (int i = 1; i < across; i++)
        () {
          final double x = -a + 2 * a * i / across;
          return Offset(x, fundusAt(x));
        }(),
      ...right,
      for (final Offset p in right.reversed) Offset(-p.dx, p.dy),
    ];
  }();

  /// The cavity's edge and the cavity in millimetres. For tests.
  static List<Offset> get edgeMm => _edgeMm;

  /// Whether [mm] lies in the cavity, above the internal orifice.
  static bool inCavity(Offset mm) =>
      mm.dy < UterusAnatomy.isthmus && _inside(_cavityMm, mm);

  /// Whether [mm] lies in the canal, below it.
  static bool inCanal(Offset mm) =>
      mm.dy >= UterusAnatomy.isthmus &&
      mm.dy <= CervixAnatomy.externalOs &&
      mm.dx.abs() < CervixForm.grooveAt(mm.dy);

  /// The cavity's edge, each point moved out from the cavity by [by] of
  /// the endometrium's thickness there less [less]: round its angles in an
  /// arc.
  static List<Offset> _outFromEdge(double by, {double less = 0}) {
    final List<Offset> edge = _edgeMm;
    final int n = edge.length;
    // Each segment's normal, out of the cavity.
    final List<Offset> normals = <Offset>[];
    for (int i = 0; i + 1 < n; i++) {
      final Offset t = _unit(edge[i + 1] - edge[i]);
      Offset normal = Offset(t.dy, -t.dx);
      final Offset mid = (edge[i] + edge[i + 1]) / 2;
      if (_inside(_cavityMm, mid + normal * 0.05)) {
        normal = -normal;
      }
      normals.add(normal);
    }
    double distance(Offset p) => math.max(0.05, by * thicknessAt(p.dy) - less);
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < n; i++) {
      final Offset p = edge[i];
      final Offset before = normals[math.max(0, i - 1)];
      final Offset after = normals[math.min(n - 2, i)];
      final double turn = math.atan2(
        before.dx * after.dy - before.dy * after.dx,
        before.dx * after.dx + before.dy * after.dy,
      );
      if (turn.abs() < 0.3) {
        out.add(p + _unit(before + after) * distance(p));
        continue;
      }
      // Round a corner, from the one segment's normal to the other's.
      final int steps = (turn.abs() / 0.12).ceil();
      final double from = math.atan2(before.dy, before.dx);
      for (int k = 0; k <= steps; k++) {
        final double a = from + turn * k / steps;
        out.add(p + Offset(math.cos(a), math.sin(a)) * distance(p));
      }
    }
    return out;
  }

  /// The endometrium's outer edge, where it meets the muscle, and the line
  /// inside it where its basal layer meets its functional layer.
  static final List<Offset> _junctionMm = _outFromEdge(1);
  static final List<Offset> _basalMm = _outFromEdge(
    1,
    less: UterusAnatomy.basal,
  );

  /// The endometrium and the cavity it lines, closed across the internal
  /// orifice.
  static final List<Offset> _homeMm = _junctionMm;

  /// Whether [mm] lies in the endometrium, the cavity's back wall included.
  static bool inHome(Offset mm) =>
      mm.dy <= UterusAnatomy.isthmus + 0.2 && _inside(_homeMm, mm);

  /// Whether [mm] lies in the endometrium where the cut crosses it, beside
  /// the cavity.
  static bool inBand(Offset mm) => inHome(mm) && !_inside(_cavityMm, mm);

  /// The endometrium's outline in millimetres. For tests.
  static List<Offset> get homeMm => _homeMm;

  /// The glands, each from the cavity's edge out through the functional
  /// layer, coiling more toward their deep ends.
  static final List<List<Offset>> _glandsMm = () {
    final math.Random random = math.Random(UterusStyle.seed);
    final List<Offset> edge = _edgeMm;
    final List<double> along = _along(edge);
    final List<List<Offset>> out = <List<Offset>>[];
    double next = UterusAnatomy.glandApart / 2;
    for (int i = 1; i + 1 < edge.length; i++) {
      if (along[i] < next) {
        continue;
      }
      next =
          along[i] +
          UterusAnatomy.glandApart * (0.75 + 0.5 * random.nextDouble());
      final Offset p = edge[i];
      final double thick = thicknessAt(p.dy);
      final double reach =
          thick -
          UterusAnatomy.basal * thick / UterusAnatomy.endometrium -
          UterusAnatomy.glandShort * random.nextDouble() * 0.6;
      if (reach < 0.8) {
        continue;
      }
      final Offset t = _unit(edge[i + 1] - edge[i - 1]);
      Offset normal = Offset(t.dy, -t.dx);
      if (_inside(_cavityMm, p + normal * 0.05)) {
        normal = -normal;
      }
      // Clear of the angles, where the glands of the two borders meet.
      if ((p - UterusAnatomy.angle).distance < 1.6 ||
          (p - Offset(-UterusAnatomy.angle.dx, UterusAnatomy.angle.dy))
                  .distance <
              1.6) {
        continue;
      }
      final double phase = random.nextDouble() * 2 * math.pi;
      final int steps = math.max(3, (reach / 0.12).ceil());
      out.add(<Offset>[
        for (int k = 0; k <= steps; k++)
          () {
            final double s = reach * k / steps;
            final double coil =
                UterusAnatomy.glandCoil *
                (0.35 + 0.65 * s / reach) *
                _smooth(s / 0.5) *
                math.sin(2 * math.pi * s / UterusAnatomy.glandTurn + phase);
            return p + normal * s + t * coil;
          }(),
      ]);
    }
    return out;
  }();

  /// The glands in millimetres. For tests.
  static List<List<Offset>> get glandsMm => _glandsMm;

  /// The openings of the glands on the cavity's back wall: each one's
  /// middle.
  static final List<Offset> _pitsMm = () {
    final math.Random random = math.Random(UterusStyle.seed + 1);
    final List<Offset> out = <Offset>[];
    const double apart = UterusAnatomy.pitApart;
    for (double y = -47; y < UterusAnatomy.isthmus; y += apart * 0.87) {
      final double shift = ((y / (apart * 0.87)).round().isOdd) ? apart / 2 : 0;
      for (double x = -17 + shift; x < 17; x += apart) {
        final Offset p = Offset(
          x + (random.nextDouble() - 0.5) * 0.5,
          y + (random.nextDouble() - 0.5) * 0.5,
        );
        if (!_inside(_cavityMm, p) || _toLine(_cavityMm, p) < 0.7) {
          continue;
        }
        out.add(p);
      }
    }
    return out;
  }();

  /// The pits in millimetres. For tests.
  static List<Offset> get pitsMm => _pitsMm;

  /// The tubes' intramural parts, the right as the anatomy has it and the
  /// left mirrored, each from the cavity's angle out through its cornu.
  static final List<List<Offset>> _intramuralMm = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      _openSampled(<Offset>[
        for (final Offset p in UterusAnatomy.rightIntramural)
          Offset(side * p.dx, p.dy),
      ], 6),
  ];

  /// The tubes' intramural parts in millimetres. For tests.
  static List<List<Offset>> get intramuralMm => _intramuralMm;

  /// The vessels of the muscle's middle layer, cut across: each one's
  /// middle, its radii and how it lies.
  static final List<(Offset, double, double, double)> _vesselsMm = () {
    final math.Random random = math.Random(UterusStyle.seed + 2);
    final List<(Offset, double, double, double)> out =
        <(Offset, double, double, double)>[];
    // The layer they lie in: part way out from the endometrium to the
    // serosa, through the body above the isthmus.
    final List<Offset> layer = <Offset>[];
    for (final Offset o in _outlineMm) {
      if (o.dy > -20) {
        continue;
      }
      Offset nearest = _junctionMm.first;
      for (final Offset e in _junctionMm) {
        if ((e - o).distanceSquared < (nearest - o).distanceSquared) {
          nearest = e;
        }
      }
      layer.add(Offset.lerp(nearest, o, UterusAnatomy.vascularLayer)!);
    }
    double travelled = 0;
    double next = random.nextDouble() * UterusAnatomy.vesselApart;
    for (int i = 1; i < layer.length; i++) {
      final double step = (layer[i] - layer[i - 1]).distance;
      // Where the layer jumps, from the body's one side to the other.
      if (step > 3) {
        continue;
      }
      travelled += step;
      if (travelled < next) {
        continue;
      }
      next =
          travelled +
          UterusAnatomy.vesselApart * (0.7 + 0.6 * random.nextDouble());
      final Offset t = _unit(layer[i] - layer[i - 1]);
      final Offset across = Offset(-t.dy, t.dx);
      final Offset at = layer[i] + across * ((random.nextDouble() - 0.5) * 2.2);
      final double rx =
          UterusAnatomy.vesselLeast +
          (UterusAnatomy.vesselMost - UterusAnatomy.vesselLeast) *
              random.nextDouble();
      final double ry = rx * (0.55 + 0.35 * random.nextDouble());
      final double turn = math.atan2(t.dy, t.dx) + (random.nextDouble() - 0.5);
      // Clear of the endometrium, the serosa, the tubes and one another.
      if (_inside(_homeMm, at) ||
          _toLine(_homeMm, at) < rx + 0.8 ||
          _toLine(_outlineMm, at) < rx + 1 ||
          _intramuralMm.any(
            (List<Offset> tube) => _toOpenLine(tube, at) < rx + 1.2,
          ) ||
          out.any(
            ((Offset, double, double, double) v) =>
                (v.$1 - at).distance < v.$2 + rx + 0.4,
          )) {
        continue;
      }
      out.add((at, rx, ry, turn));
    }
    return out;
  }();

  /// The vessels in millimetres. For tests.
  static List<(Offset, double, double, double)> get vesselsMm => _vesselsMm;

  // The parts, laid in the scene.

  /// The cavity, the canal and the two as one opening; the cavity's edge.
  late final List<Offset> cavity = _placed(_cavityMm);
  late final List<Offset> canal = _placed(CervixForm.canalMm);
  late final List<Offset> groove = _placed(_grooveMm);

  /// The internal orifice, across the opening at the isthmus.
  late final (Offset, Offset) internalOsLine = (
    place(Offset(-widthAt(UterusAnatomy.isthmus), UterusAnatomy.isthmus)),
    place(Offset(widthAt(UterusAnatomy.isthmus), UterusAnatomy.isthmus)),
  );

  /// The endometrium, the cavity's back wall included; its edge against the
  /// muscle; the line its basal layer meets its functional layer at.
  late final List<Offset> endometrium = _placed(_homeMm);
  late final List<Offset> junction = _placed(_junctionMm);
  late final List<Offset> basalLine = _placed(_basalMm);

  /// The glands as the creases cut along them, tapering in from their ends;
  /// the openings of the glands on the cavity's back wall.
  late final Path glandCreases = _creases(
    _glandsMm,
    UterusStyle.gland,
    UterusStyle.creaseTaper / 3,
  );
  late final List<Offset> pits = _placed(_pitsMm);

  /// The vessels of the muscle's middle layer: each one's middle, its radii
  /// in the scene and how it lies.
  late final List<(Offset, double, double, double)> vessels =
      <(Offset, double, double, double)>[
        for (final (Offset at, double rx, double ry, double turn) in _vesselsMm)
          (place(at), mm(rx), mm(ry), turn),
      ];

  /// The tubes' intramural parts.
  late final List<List<Offset>> intramural = <List<Offset>>[
    for (final List<Offset> tube in _intramuralMm) _placed(tube),
  ];

  /// The canal's palmate folds and the ridge they run from, the crypts and
  /// the Nabothian cysts, as the cervix specimen lays them.
  late final Path foldCreases = _creases(
    CervixForm.foldsMm,
    UterusStyle.crease,
    UterusStyle.creaseTaper,
  );
  late final List<Offset> column = _placed(<Offset>[
    const Offset(CervixAnatomy.columnX, CervixAnatomy.columnTop),
    const Offset(CervixAnatomy.columnX, CervixAnatomy.columnBottom),
  ]);
  late final Path columnCrease = _creases(
    <List<Offset>>[
      <Offset>[
        for (int i = 0; i <= 40; i++)
          Offset(
            CervixAnatomy.columnX,
            CervixAnatomy.columnTop +
                (CervixAnatomy.columnBottom - CervixAnatomy.columnTop) * i / 40,
          ),
      ],
    ],
    UterusStyle.crease,
    2,
  );
  late final Path cryptCreases = _creases(
    CervixForm.cryptsMm,
    UterusStyle.crypt,
    UterusStyle.creaseTaper / 2,
  );
  late final List<(Offset, double)> cysts = <(Offset, double)>[
    for (final (Offset at, double r) in CervixAnatomy.cysts) (place(at), mm(r)),
  ];

  /// The squamous epithelium of the vaginal part, its line a little in from
  /// its surface.
  late final List<Offset> epithelium = () {
    final List<Offset> surface = CervixForm.surfaceMm;
    final List<Offset> normals = _normals(surface);
    final double inward =
        _inside(
          _outlineMm,
          surface[surface.length ~/ 2] + normals[surface.length ~/ 2] * 0.2,
        )
        ? 1
        : -1;
    return _placed(<Offset>[
      for (int i = 0; i < surface.length; i++)
        surface[i] + normals[i] * (UterusStyle.epithelium * inward),
    ]);
  }();

  Path _creases(List<List<Offset>> lines, double width, double taper) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      path.addPolygon(_placed(_tapered(line, width / 2, taper)), true);
    }
    return path;
  }

  // The tubes.

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(UterusStyle.edgeStep), bend: 0.9);

  /// [tube] as it runs on the body's right, mirrored.
  static AnatomyTube _mirrored(AnatomyTube tube) => AnatomyTube(
    <Offset>[for (final Offset p in tube.points) Offset(-p.dx, p.dy)],
    tube.radii,
    fadeIn: tube.fadeIn,
    fadeOut: tube.fadeOut,
    cutStart: tube.cutStart,
    cutEnd: tube.cutEnd,
  );

  static List<AnatomyTube> _paired(AnatomyTube right) => <AnatomyTube>[
    _mirrored(right),
    right,
  ];

  /// The tubes' isthmus and the ovarian ligaments, running out from the
  /// cornua: the body's right's and left's, in turn.
  late final List<TubeCourse> tubes = <TubeCourse>[
    for (final AnatomyTube t in _paired(UterusAnatomy.rightTube)) _tube(t),
  ];
  late final List<TubeCourse> ligaments = <TubeCourse>[
    for (final AnatomyTube t in _paired(UterusAnatomy.rightLigament)) _tube(t),
  ];

  static final List<AnatomyTube> _arteriesMm = <AnatomyTube>[
    for (final AnatomyTube t in <AnatomyTube>[
      CervixAnatomy.rightUterine,
      UterusAnatomy.rightAscending,
      UterusAnatomy.rightTubal,
      UterusAnatomy.rightOvarian,
      UterusAnatomy.rightCervicovaginal,
    ])
      ..._paired(t),
  ];

  /// The uterine arteries, each with its branches, cut short or fading
  /// out: the body's right's and left's, in turn.
  late final List<TubeCourse> arteries = <TubeCourse>[
    for (final AnatomyTube t in _arteriesMm) _tube(t),
  ];

  /// The uterine artery on the body's left, where it comes in to the
  /// isthmus, which is named.
  late final TubeCourse namedArtery = arteries[1];

  /// The arteries' small branches into the wall, each running in under it.
  late final List<TubeCourse> branches = <TubeCourse>[
    for (final AnatomyTube t in _branchesMm) _tube(t),
  ];

  static final List<AnatomyTube> _branchesMm = () {
    final List<AnatomyTube> out = <AnatomyTube>[];
    final math.Random random = math.Random(UterusStyle.seed + 3);
    // From the ascending branches, into the body's wall.
    for (final AnatomyTube artery in _arteriesMm.sublist(2, 4)) {
      final TubeCourse course = TubeCourse(
        artery,
        (Offset p) => p,
        1,
        UterusStyle.edgeStep,
        bend: 0.9,
      );
      double next = UterusAnatomy.branchApart / 2;
      for (int i = 0; i < course.length; i++) {
        if (course.arc[i] < next) {
          continue;
        }
        final Offset c = course.centres[i];
        final Offset way = Offset(course.across[i].dy, -course.across[i].dx);
        final Offset aim =
            c +
            way * (UterusAnatomy.branchLean * (2 * random.nextDouble() - 1));
        Offset edge = _outlineMm.first;
        for (final Offset q in _outlineMm) {
          if ((q - aim).distanceSquared < (edge - aim).distanceSquared) {
            edge = q;
          }
        }
        final Offset to = edge - c;
        final double reach = to.distance;
        if (reach > UterusAnatomy.branchReach || reach <= 0) {
          continue;
        }
        next =
            course.arc[i] +
            UterusAnatomy.branchApart +
            UterusAnatomy.branchJitter * (2 * random.nextDouble() - 1);
        out.add(
          AnatomyTube(
            <Offset>[c, edge + to / reach * UterusAnatomy.branchUnder],
            const <double>[UterusAnatomy.branch, UterusAnatomy.branch],
          ),
        );
      }
    }
    return out;
  }();

  /// What runs on beside the uterus.
  late final List<TubeCourse> beside = <TubeCourse>[
    ...tubes,
    ...ligaments,
    ...arteries,
  ];

  // Where the parts are named.

  /// Where the zoom's cell lives: the site, in the functional layer, for a
  /// cell of its glands or its stroma, or the cavity's back wall beside it
  /// for one of its surface; the muscle, over the fundus; the canal; a tube,
  /// where it leaves its cornu; and the uterine artery on the body's
  /// left, where it comes in, below the middle of the uterus, so that its
  /// name goes below it with the canal's, clear of the scale bar.
  late final Offset homeName = home == UterusHome.surface
      ? place(UterusAnatomy.surfaceName)
      : site;
  late final Offset muscleName = place(UterusAnatomy.muscleName);
  late final Offset canalName = place(UterusAnatomy.canalName);
  late final Offset tubeName = place(UterusAnatomy.tubeName);
  late final Offset arteryName = namedArtery.centres[namedArtery.length ~/ 2];

  /// The points its names are set round: its outline, and what runs beside
  /// it where it shows, with room to either side and past where each ends.
  late final List<Offset> namedPoints = () {
    final double clear = mm(UterusStyle.nameClear);
    return <Offset>[
      for (int i = 0; i < outlinePoints.length; i += 4) outlinePoints[i],
      for (final TubeCourse tube in beside)
        for (int i = 0; i < tube.length; i++)
          if ((i % 4 == 0 || i == tube.length - 1) &&
              tube.shown[i] > UterusStyle.nameShown) ...<Offset>[
            tube.centres[i] + tube.across[i] * (tube.plus[i] + clear),
            tube.centres[i] - tube.across[i] * (tube.minus[i] + clear),
          ],
    ];
  }();

  // The step from the body.

  /// Where the step from the body meets the uterus's outline and the
  /// body's: the middle of the top, which is nearly level, in place of the
  /// topmost point; each side's outermost point in its upper part, the
  /// cornua and the anatomogram's horns; and the lowest.
  static int _topMiddle(List<Offset> points) {
    final Rect box = _bounds(points);
    int best = -1;
    for (int i = 0; i < points.length; i++) {
      final Offset p = points[i];
      if (p.dy > box.top + box.height * 0.2) {
        continue;
      }
      if (best < 0 ||
          (p.dx - box.center.dx).abs() <
              (points[best].dx - box.center.dx).abs()) {
        best = i;
      }
    }
    return best;
  }

  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0, 0.45),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0, 0.45),
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

  /// The points of an outline where the step from the body meets the
  /// uterus's and the body's, for tests: the top's middle, then the rest
  /// in the order round it from there.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    points[_topMiddle(points)],
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

// Geometry, in the anatomy's millimetres.

/// A value smooth through [knots] (height, value), each knot's slope the
/// one between its neighbours: held at the ends beyond them.
double _smoothThrough(List<(double, double)> knots, double y) {
  final int n = knots.length;
  if (y <= knots.first.$1) {
    return knots.first.$2;
  }
  if (y >= knots.last.$1) {
    return knots.last.$2;
  }
  int i = 0;
  while (i < n - 2 && y > knots[i + 1].$1) {
    i++;
  }
  double slope(int k) {
    final int a = math.max(0, k - 1);
    final int b = math.min(n - 1, k + 1);
    return (knots[b].$2 - knots[a].$2) / (knots[b].$1 - knots[a].$1);
  }

  final double y0 = knots[i].$1;
  final double y1 = knots[i + 1].$1;
  final double h = y1 - y0;
  final double t = (y - y0) / h;
  final double t2 = t * t;
  final double t3 = t2 * t;
  return (2 * t3 - 3 * t2 + 1) * knots[i].$2 +
      (t3 - 2 * t2 + t) * h * slope(i) +
      (-2 * t3 + 3 * t2) * knots[i + 1].$2 +
      (t3 - t2) * h * slope(i + 1);
}

/// A smooth open curve through [knots], [perSpan] points from each to the
/// next, its ends at the first and the last.
List<Offset> _openSampled(List<Offset> knots, int perSpan) {
  final int n = knots.length;
  Offset knot(int i) => knots[i.clamp(0, n - 1)];
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < n - 1; i++) {
    final Offset p0 = knot(i - 1);
    final Offset p1 = knot(i);
    final Offset p2 = knot(i + 1);
    final Offset p3 = knot(i + 2);
    final Offset c1 = p1 + (p2 - p0) / 6;
    final Offset c2 = p2 - (p3 - p1) / 6;
    for (int k = 0; k < perSpan; k++) {
      final double t = k / perSpan;
      final double u = 1 - t;
      out.add(
        p1 * (u * u * u) +
            c1 * (3 * u * u * t) +
            c2 * (3 * u * t * t) +
            p2 * (t * t * t),
      );
    }
  }
  return out..add(knots.last);
}

/// How far along [line] each of its points lies.
List<double> _along(List<Offset> line) {
  final List<double> out = <double>[0];
  for (int i = 1; i < line.length; i++) {
    out.add(out.last + (line[i] - line[i - 1]).distance);
  }
  return out;
}

/// The shape of a line [half] wide to either side, narrowing to nothing
/// over [taper] at each end.
List<Offset> _tapered(List<Offset> line, double half, double taper) {
  final List<double> along = _along(line);
  final double total = along.last;
  final int n = line.length;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = 0; i < n; i++) {
    final Offset t = _unit(
      line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)],
    );
    final Offset across = Offset(-t.dy, t.dx);
    final double w =
        half * _smooth(along[i] / taper) * _smooth((total - along[i]) / taper);
    left.add(line[i] + across * w);
    right.add(line[i] - across * w);
  }
  return <Offset>[...left, ...right.reversed];
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

Offset _unit(Offset p) {
  final double length = p.distance;
  return length <= 0 ? Offset.zero : p / length;
}

/// The left hand of the way along [line] at each point, a unit.
List<Offset> _normals(List<Offset> line) {
  final int n = line.length;
  return <Offset>[
    for (int i = 0; i < n; i++)
      () {
        final Offset t = _unit(
          line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)],
        );
        return Offset(t.dy, -t.dx);
      }(),
  ];
}

double _toSegment(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double length = ab.distanceSquared;
  final double t = length <= 0
      ? 0
      : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// How far [p] lies from the closed outline [polygon].
double _toLine(List<Offset> polygon, Offset p) {
  double best = double.infinity;
  for (int i = 0; i < polygon.length; i++) {
    best = math.min(
      best,
      _toSegment(p, polygon[i], polygon[(i + 1) % polygon.length]),
    );
  }
  return best;
}

/// How far [p] lies from the open line [line].
double _toOpenLine(List<Offset> line, Offset p) {
  double best = double.infinity;
  for (int i = 0; i + 1 < line.length; i++) {
    best = math.min(best, _toSegment(p, line[i], line[i + 1]));
  }
  return best;
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
