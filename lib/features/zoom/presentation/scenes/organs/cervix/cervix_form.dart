import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'cervix_anatomy.dart';
import 'cervix_style.dart';

/// The cervix as the zoom's organ scene draws it, opened along its canal:
/// every part in the scene's units at its real size, the middle of the
/// body's outline of it at the origin.
///
/// The cervix is drawn from general anatomy ([CervixAnatomy]) and laid on
/// the body's outline of it so that the place it is gone into in the
/// anatomy ([CervixAnatomy.site]) lies on the place the body goes in
/// ([site]). The body draws the cervix as two halves, each a wall and the
/// canal between them; the step from the body draws the half it follows in
/// toward the cervix's own canal and wall on that side ([pathAt]), and the
/// other half gives way. Its vaginal part, the ectocervix, is where the
/// zoom goes in, whatever the protein: no cell the Atlas names has the
/// cervix as its home, so the zoom draws the tissue's own, and the tissue
/// is its squamous epithelium. Everything here is geometry: what it is
/// drawn in is `CervixArt`'s.
final class CervixForm {
  CervixForm({
    required List<Offset> diagram,
    required this.others,
    required this.site,
    required double length,
    required this.view,
  }) : scale = length / CervixAnatomy.length {
    outlinePoints = _placed(_outlineMm);
    outline = Path()..addPolygon(outlinePoints, true);
    box = _bounds(outlinePoints);
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(CervixStyle.outlineSpan)
        .points;
    _diagramBox = _bounds(diagramDense);
    // The followed half's counterpart, drawn the same way round as the
    // body's outline, so the one can be drawn in toward the other.
    final List<Offset> half = _placed(_halfMm);
    final List<Offset> template = _area(half).sign != _area(diagramDense).sign
        ? half.reversed.toList()
        : half;
    halfPoints = template;
    _morph = OutlineMorph(
      template: template,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: CervixStyle.morphPoints,
      bed: mm(CervixStyle.bed),
      marks: _marks,
      start: _topMiddle,
    );
  }

  /// The cervix where the body draws it as [part], in a view [view] metres
  /// across.
  factory CervixForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return CervixForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      others: <List<Offset>>[
        for (final List<Offset> other in part.others)
          <Offset>[for (final Offset p in other) placed(p)],
      ],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
    );
  }

  /// Where the body goes into the cervix, in the scene: its vaginal part's
  /// surface, on the body's left.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// The body's other outlines of the cervix, beside the one it follows,
  /// in the scene: its other half.
  final List<List<Offset>> others;

  late final OutlineMorph _morph;
  late final Rect _diagramBox;

  /// The outline of the uterus's lower body and the cervix, where the cut
  /// crosses their outer surface, the points it is followed by, and its
  /// box.
  late final Path outline;
  late final List<Offset> outlinePoints;
  late final Rect box;

  /// The half the body's followed outline draws in to: the canal and the
  /// cervix's wall on the body's left.
  late final List<Offset> halfPoints;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => site + (mm - CervixAnatomy.site) * scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) => CervixAnatomy.site + (p - site) / scale;

  /// How far the cervix's half lies from the body's outline it draws in
  /// from, in millimetres, laid so that the site lies where the body's is:
  /// what laying it so costs.
  double get anchorShift =>
      (_bounds(halfPoints).center - _diagramBox.center).distance / scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the cervix's half at 1, and [bed] of the way on toward the
  /// bed it lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the cervix's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The anatomy in millimetres, built once for every cervix.

  /// The outline's own points, its right half and then its left, mirrored,
  /// from the middle of the uterus's cut round by the vaginal part's end,
  /// followed closely.
  static final List<Offset> _outlineMm = Contour(<Offset>[
    ...CervixAnatomy.half,
    for (int i = CervixAnatomy.half.length - 2; i >= 1; i--)
      Offset(-CervixAnatomy.half[i].dx, CervixAnatomy.half[i].dy),
  ]).sampled(CervixStyle.outlineSpan).points;

  /// The outline in millimetres. For tests.
  static List<Offset> get outlineMm => _outlineMm;

  /// How far the canal, or the uterine cavity above it, reaches to either
  /// side at [y], in millimetres: smooth through the anatomy's heights.
  static double grooveAt(double y) => _smoothThrough(<(double, double)>[
    ...CervixAnatomy.cavity,
    ...CervixAnatomy.canal.skip(1),
  ], y);

  /// The uterine cavity and the canal below it, one opening from where the
  /// uterus is cut down to the external orifice, and each alone.
  static final List<Offset> _grooveMm = _between(
    CervixAnatomy.uterusCut,
    CervixAnatomy.externalOs,
  );
  static final List<Offset> _cavityMm = _between(
    CervixAnatomy.uterusCut,
    CervixAnatomy.internalOs,
  );
  static final List<Offset> _canalMm = _between(
    CervixAnatomy.internalOs,
    CervixAnatomy.externalOs,
  );

  static List<Offset> _between(double top, double bottom) {
    final int steps = ((bottom - top) / CervixStyle.edgeStep).ceil();
    final List<Offset> right = <Offset>[
      for (int i = 0; i <= steps; i++)
        () {
          final double y = top + (bottom - top) * i / steps;
          return Offset(grooveAt(y), y);
        }(),
    ];
    return <Offset>[
      ...right,
      for (final Offset p in right.reversed) Offset(-p.dx, p.dy),
    ];
  }

  /// Whether [mm] lies in the canal, or in the uterine cavity above it.
  static bool inGroove(Offset mm) =>
      mm.dy >= CervixAnatomy.uterusCut &&
      mm.dy <= CervixAnatomy.externalOs &&
      mm.dx.abs() < grooveAt(mm.dy);

  /// The canal in millimetres. For tests.
  static List<Offset> get canalMm => _canalMm;

  // The vaginal part.

  /// How far down the line across the cervix between the vagina's two
  /// attachments lies at [x]: bowed down at its middle, level beyond them.
  static double portioTopAt(double x) {
    final double a = CervixAnatomy.attachment.dx;
    final double t = (x / a).clamp(-1.0, 1.0);
    return CervixAnatomy.attachment.dy + CervixAnatomy.portioBow * (1 - t * t);
  }

  /// The region below that line, reaching well past the outline on either
  /// side and below it: the ectocervix, where it lies inside the outline
  /// and outside the canal.
  static final List<Offset> _belowMm = () {
    const double reach = 30;
    final double a = CervixAnatomy.attachment.dx;
    const int steps = 40;
    return <Offset>[
      Offset(-reach, CervixAnatomy.attachment.dy),
      for (int i = 0; i <= steps; i++)
        () {
          final double x = -a + 2 * a * i / steps;
          return Offset(x, portioTopAt(x));
        }(),
      Offset(reach, CervixAnatomy.attachment.dy),
      const Offset(reach, reach),
      const Offset(-reach, reach),
    ];
  }();

  /// Whether [mm] lies in the ectocervix: inside the outline, below the
  /// vagina's attachments and outside the canal.
  static bool inHome(Offset mm) =>
      _inside(_outlineMm, mm) && mm.dy > portioTopAt(mm.dx) && !inGroove(mm);

  /// The ectocervix's surface, from one attachment round its end to the
  /// other, and the line its epithelium meets the stroma at, a little in
  /// from it.
  static final List<Offset> _surfaceMm = () {
    final List<Offset> out = <Offset>[];
    final int n = _outlineMm.length;
    // The outline runs round from the top's middle down the body's left
    // side: the surface is the run of it below the attachments.
    for (int i = 0; i < n; i++) {
      final Offset p = _outlineMm[i];
      if (p.dy >= CervixAnatomy.attachment.dy) {
        out.add(p);
      }
    }
    return out;
  }();
  static final List<Offset> _epitheliumMm = () {
    final List<Offset> normals = _normals(_surfaceMm);
    final double inward =
        _inside(
          _outlineMm,
          _surfaceMm[_surfaceMm.length ~/ 2] +
              normals[_surfaceMm.length ~/ 2] * 0.2,
        )
        ? 1
        : -1;
    return <Offset>[
      for (int i = 0; i < _surfaceMm.length; i++)
        _surfaceMm[i] + normals[i] * (CervixAnatomy.epithelium * inward),
    ];
  }();

  /// The ectocervix's surface in millimetres. For tests.
  static List<Offset> get surfaceMm => _surfaceMm;

  /// The transformation zone: its outer edges, each where the original
  /// squamocolumnar junction lies on the surface, [CervixAnatomy.zoneOut]
  /// out along it from the external orifice's edge; its inner edges, each
  /// from there in to the canal's side [CervixAnatomy.zoneDepth] above the
  /// orifice; and the zone itself, round the canal's end.
  static final List<Offset> _zoneEnds = () {
    // Along the surface from where it passes under the orifice's edge, out
    // either way.
    final double edge = grooveAt(CervixAnatomy.externalOs);
    final List<Offset> out = <Offset>[];
    for (final double side in <double>[-1, 1]) {
      int from = 0;
      for (int i = 0; i < _surfaceMm.length; i++) {
        final Offset p = _surfaceMm[i];
        if ((p.dx - side * edge).abs() <
                (_surfaceMm[from].dx - side * edge).abs() &&
            p.dy > CervixAnatomy.externalOs) {
          from = i;
        }
      }
      final int way =
          _surfaceMm[math.min(_surfaceMm.length - 1, from + 1)].dx * side >
              _surfaceMm[from].dx * side
          ? 1
          : -1;
      double along = 0;
      int i = from;
      while (along < CervixAnatomy.zoneOut &&
          i + way >= 0 &&
          i + way < _surfaceMm.length) {
        along += (_surfaceMm[i + way] - _surfaceMm[i]).distance;
        i += way;
      }
      out.add(_surfaceMm[i]);
    }
    return out;
  }();
  static final List<List<Offset>> _zoneEdgesMm = <List<Offset>>[
    for (final Offset end in _zoneEnds)
      () {
        const double y = CervixAnatomy.externalOs - CervixAnatomy.zoneDepth;
        final Offset canal = Offset(end.dx.sign * grooveAt(y), y);
        final Offset control = Offset(end.dx, y);
        const int steps = 24;
        return <Offset>[
          for (int k = 0; k <= steps; k++)
            () {
              final double t = k / steps;
              final double u = 1 - t;
              return canal * (u * u) + control * (2 * u * t) + end * (t * t);
            }(),
        ];
      }(),
  ];
  static final List<Offset> _zoneMm = () {
    const double y = CervixAnatomy.externalOs - CervixAnatomy.zoneDepth;
    final List<Offset> left = _zoneEdgesMm[0];
    final List<Offset> right = _zoneEdgesMm[1];
    // The surface between the two ends, round the vaginal part's end.
    final int a = _surfaceMm.indexOf(_zoneEnds[0]);
    final int b = _surfaceMm.indexOf(_zoneEnds[1]);
    final List<Offset> round = a <= b
        ? _surfaceMm.sublist(a, b + 1)
        : _surfaceMm.sublist(b, a + 1).reversed.toList();
    // Down the canal's left side from the left edge's top to the orifice,
    // across its end and up its right side.
    final List<Offset> canal = <Offset>[
      for (final Offset p in _canalMm)
        if (p.dy >= y) p,
    ];
    final List<Offset> canalRight = <Offset>[
      for (final Offset p in canal)
        if (p.dx > 0) p,
    ];
    final List<Offset> canalLeft = <Offset>[
      for (final Offset p in canal)
        if (p.dx < 0) p,
    ];
    canalLeft.sort((Offset p, Offset q) => p.dy.compareTo(q.dy));
    canalRight.sort((Offset p, Offset q) => q.dy.compareTo(p.dy));
    return <Offset>[
      ...canalLeft,
      ...canalRight,
      ...right,
      ...round.reversed,
      ...left.reversed,
    ];
  }();

  /// Whether [mm] lies in the transformation zone.
  static bool inZone(Offset mm) => _inside(_zoneMm, mm);

  // The canal's back wall.

  /// The ridge down the canal's back wall, wandering a little.
  static final List<Offset> _columnMm = _wandering(
    const Offset(CervixAnatomy.columnX, CervixAnatomy.columnTop),
    const Offset(CervixAnatomy.columnX, CervixAnatomy.columnBottom),
    math.Random(CervixStyle.seed),
    0.15,
  );

  /// The palmate folds, each from the ridge up and out to near the canal's
  /// side, wandering a little: those of the upper canal, and the lower
  /// half's finer ones.
  static final (List<List<Offset>>, List<List<Offset>>) _foldsMm = () {
    final math.Random random = math.Random(CervixStyle.seed + 1);
    final List<List<Offset>> upper = <List<Offset>>[];
    final List<List<Offset>> lower = <List<Offset>>[];
    for (final double side in <double>[1, -1]) {
      for (int k = 0; k < CervixAnatomy.folds; k++) {
        final double y0 =
            CervixAnatomy.firstFold +
            k * CervixAnatomy.foldApart +
            (side < 0 ? CervixAnatomy.foldApart / 2 : 0);
        final Offset from = Offset(
          CervixAnatomy.columnX + side * CervixAnatomy.columnWidth / 2,
          y0,
        );
        final Offset way = Offset(
          side * math.cos(CervixAnatomy.foldRise),
          -math.sin(CervixAnatomy.foldRise),
        );
        // As far as the canal's side, short of it by a little.
        double reach = 0;
        while (reach < 12) {
          final Offset p = from + way * (reach + CervixStyle.edgeStep);
          if (p.dx.abs() > grooveAt(p.dy) - CervixAnatomy.foldShort ||
              p.dy < CervixAnatomy.internalOs) {
            break;
          }
          reach += CervixStyle.edgeStep;
        }
        if (reach < 1) {
          continue;
        }
        final List<Offset> fold = _wandering(
          from,
          from + way * reach,
          random,
          0.12,
        );
        (y0 > CervixAnatomy.foldsFiner ? lower : upper).add(fold);
      }
    }
    return (upper, lower);
  }();

  /// The crypts, each from the canal's side out and up into the stroma.
  static final List<List<Offset>> _cryptsMm = () {
    final math.Random random = math.Random(CervixStyle.seed + 2);
    final List<List<Offset>> out = <List<Offset>>[];
    for (final double side in <double>[1, -1]) {
      for (
        double y =
            CervixAnatomy.cryptsTop +
            (side < 0 ? CervixAnatomy.cryptApart / 2 : 0);
        y <= CervixAnatomy.cryptsBottom;
        y += CervixAnatomy.cryptApart
      ) {
        final double jitter = (random.nextDouble() - 0.5) * 1.2;
        // Not every place along the canal has one.
        if (random.nextDouble() < 0.2) {
          continue;
        }
        final double at = y + jitter;
        final Offset from = Offset(side * grooveAt(at), at);
        final double rise =
            CervixAnatomy.cryptRise + (random.nextDouble() - 0.5) * 0.6;
        final Offset way = Offset(side * math.cos(rise), -math.sin(rise));
        final double length =
            CervixAnatomy.cryptLeast +
            (CervixAnatomy.cryptMost - CervixAnatomy.cryptLeast) *
                random.nextDouble();
        final Offset to = from + way * length;
        // Clear of every cyst.
        if (CervixAnatomy.cysts.any(
          ((Offset, double) c) => _toSegment(c.$1, from, to) < c.$2 + 0.4,
        )) {
          continue;
        }
        out.add(_wandering(from, to, random, 0.18));
      }
    }
    return out;
  }();

  /// The crypts in millimetres. For tests.
  static List<List<Offset>> get cryptsMm => _cryptsMm;

  /// The palmate folds in millimetres, upper and lower. For tests.
  static List<List<Offset>> get foldsMm => <List<Offset>>[
    ..._foldsMm.$1,
    ..._foldsMm.$2,
  ];

  // The vagina.

  /// Its walls, the right as the anatomy has it and the left mirrored:
  /// each its inner surface from the fornix's top down to the cut, and its
  /// outer surface from where it leaves the cervix down to the cut.
  static final List<Offset> _innerRightMm = _openSampled(
    CervixAnatomy.vaginaInner,
    CervixStyle.outlineSpan,
  );
  static final List<Offset> _outerRightMm = _openSampled(
    CervixAnatomy.vaginaOuter,
    CervixStyle.outlineSpan,
  );

  static List<Offset> _mirroredMm(List<Offset> points) => <Offset>[
    for (final Offset p in points) Offset(-p.dx, p.dy),
  ];

  /// Each wall, cut: from its outer surface's top down, across the cut, and
  /// up its inner surface; its lamina propria and its epithelium's inner
  /// edges, in from its inner surface.
  static final List<List<Offset>> _wallsMm = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      <Offset>[
        ...(side < 0 ? _mirroredMm(_outerRightMm) : _outerRightMm),
        ...(side < 0 ? _mirroredMm(_innerRightMm) : _innerRightMm).reversed,
      ],
  ];
  static List<Offset> _offsetWall(double side, double by) {
    final List<Offset> inner = side < 0
        ? _mirroredMm(_innerRightMm)
        : _innerRightMm;
    final List<Offset> normals = _normals(inner);
    // Outward, away from the vagina's middle.
    final double out = normals[inner.length ~/ 2].dx * side > 0 ? 1 : -1;
    return <Offset>[
      for (int i = 0; i < inner.length; i++) inner[i] + normals[i] * (by * out),
    ];
  }

  static final List<List<Offset>> _laminaeMm = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      <Offset>[
        ...(side < 0 ? _mirroredMm(_innerRightMm) : _innerRightMm),
        ..._offsetWall(
          side,
          CervixAnatomy.vaginaEpithelium + CervixAnatomy.vaginaLamina,
        ).reversed,
      ],
  ];
  static final List<List<Offset>> _vaginalEpitheliaMm = <List<Offset>>[
    for (final double side in <double>[-1, 1])
      <Offset>[
        ...(side < 0 ? _mirroredMm(_innerRightMm) : _innerRightMm),
        ..._offsetWall(side, CervixAnatomy.vaginaEpithelium).reversed,
      ],
  ];

  /// Its lumen, between the walls' inner surfaces, its top under the
  /// cervix: what is seen of its back wall's mucosa.
  static final List<Offset> _lumenMm = <Offset>[
    ..._innerRightMm,
    ..._mirroredMm(_innerRightMm).reversed,
  ];

  /// Whether [mm] lies in the vagina's lumen, below the cervix.
  static bool inLumen(Offset mm) =>
      _inside(_lumenMm, mm) && !_inside(_outlineMm, mm);

  /// The vagina's outline, its walls' outer surfaces and the cut across
  /// them, with its top under the cervix.
  static final List<Offset> _vaginaOutlineMm = <Offset>[
    ..._outerRightMm,
    ..._mirroredMm(_outerRightMm).reversed,
  ];

  /// The column down its back wall below the cervix.
  static final List<Offset> _vaginaColumnMm = _wandering(
    Offset(0, CervixAnatomy.half.last.dy + 1.2),
    const Offset(0, CervixAnatomy.vaginaCut - 0.6),
    math.Random(CervixStyle.seed + 3),
    0.2,
  );

  /// The rugae, each from the column out toward a wall, bowed up at its
  /// middle.
  static final List<List<Offset>> _rugaeMm = () {
    final math.Random random = math.Random(CervixStyle.seed + 4);
    final List<List<Offset>> out = <List<Offset>>[];
    for (
      double y = CervixAnatomy.firstRuga;
      y < CervixAnatomy.vaginaCut - 1;
      y += CervixAnatomy.rugaApart
    ) {
      for (final double side in <double>[-1, 1]) {
        final double wall = _innerAt(y);
        const double from = CervixAnatomy.vaginaColumn / 2;
        final double to = wall - CervixAnatomy.rugaShort;
        final int steps = ((to - from) / CervixStyle.edgeStep).ceil();
        final double phase = random.nextDouble() * 2 * math.pi;
        out.add(<Offset>[
          for (int i = 0; i <= steps; i++)
            () {
              final double x = from + (to - from) * i / steps;
              final double t = x / wall;
              return Offset(
                side * x,
                y -
                    CervixAnatomy.rugaBow * (1 - t * t) +
                    0.18 * math.sin(x / 2.2 + phase),
              );
            }(),
        ]);
      }
    }
    return out;
  }();

  /// How far the vagina's inner surface lies from its middle at [y].
  static double _innerAt(double y) {
    double best = _innerRightMm.first.dx;
    double least = double.infinity;
    for (final Offset p in _innerRightMm) {
      if ((p.dy - y).abs() < least) {
        least = (p.dy - y).abs();
        best = p.dx;
      }
    }
    return best;
  }

  // The parts, laid in the scene.

  /// The uterine cavity and the canal, one opening and each alone.
  late final List<Offset> groove = _placed(_grooveMm);
  late final List<Offset> cavity = _placed(_cavityMm);
  late final List<Offset> canal = _placed(_canalMm);

  /// The internal orifice, across the opening at the isthmus.
  late final (Offset, Offset) internalOsLine = (
    place(
      Offset(-grooveAt(CervixAnatomy.internalOs), CervixAnatomy.internalOs),
    ),
    place(Offset(grooveAt(CervixAnatomy.internalOs), CervixAnatomy.internalOs)),
  );

  /// The region below the line between the vagina's attachments, which the
  /// outline cuts the ectocervix out of.
  late final List<Offset> below = _placed(_belowMm);

  /// The ectocervix's surface and the line its epithelium meets the stroma
  /// at.
  late final List<Offset> surface = _placed(_surfaceMm);
  late final List<Offset> epithelium = _placed(_epitheliumMm);

  /// The transformation zone, and its two inner edges.
  late final List<Offset> zone = _placed(_zoneMm);
  late final List<List<Offset>> zoneEdges = <List<Offset>>[
    for (final List<Offset> edge in _zoneEdgesMm) _placed(edge),
  ];

  /// The ridge down the canal's back wall; its palmate folds, upper and
  /// lower; its crypts.
  late final List<Offset> column = _placed(_columnMm);
  late final List<List<Offset>> folds = <List<Offset>>[
    for (final List<Offset> fold in _foldsMm.$1) _placed(fold),
  ];
  late final List<List<Offset>> finerFolds = <List<Offset>>[
    for (final List<Offset> fold in _foldsMm.$2) _placed(fold),
  ];
  late final List<List<Offset>> crypts = <List<Offset>>[
    for (final List<Offset> crypt in _cryptsMm) _placed(crypt),
  ];

  /// The folds and the crypts as the creases cut along them, tapering in
  /// from their ends.
  late final Path foldCreases = _creases(
    _foldsMm.$1,
    CervixStyle.crease,
    CervixStyle.creaseTaper,
  );
  late final Path finerCreases = _creases(
    _foldsMm.$2,
    CervixStyle.crease * 0.8,
    CervixStyle.creaseTaper,
  );
  late final Path cryptCreases = _creases(
    _cryptsMm,
    CervixStyle.crypt,
    CervixStyle.creaseTaper / 2,
  );
  late final Path columnCrease = _creases(
    <List<Offset>>[_columnMm],
    CervixStyle.columnCrease,
    2,
  );

  /// The Nabothian cysts: each one's middle and radius.
  late final List<(Offset, double)> cysts = <(Offset, double)>[
    for (final (Offset at, double r) in CervixAnatomy.cysts) (place(at), mm(r)),
  ];

  /// The vagina: its outline, its walls, their laminae and epithelia, its
  /// lumen, the column down its back wall and its rugae.
  late final List<Offset> vaginaOutline = _placed(_vaginaOutlineMm);
  late final List<List<Offset>> walls = <List<Offset>>[
    for (final List<Offset> wall in _wallsMm) _placed(wall),
  ];
  late final List<List<Offset>> laminae = <List<Offset>>[
    for (final List<Offset> lamina in _laminaeMm) _placed(lamina),
  ];
  late final List<List<Offset>> vaginalEpithelia = <List<Offset>>[
    for (final List<Offset> e in _vaginalEpitheliaMm) _placed(e),
  ];
  late final List<Offset> lumen = _placed(_lumenMm);
  late final List<List<Offset>> lumenEdges = <List<Offset>>[
    _placed(_mirroredMm(_innerRightMm)),
    _placed(_innerRightMm),
  ];
  late final Path vaginaColumnCrease = _creases(
    <List<Offset>>[_vaginaColumnMm],
    CervixStyle.columnCrease,
    2,
  );
  late final List<Offset> vaginaColumn = _placed(_vaginaColumnMm);
  late final Path rugaCreases = _creases(
    _rugaeMm,
    CervixStyle.crease,
    CervixStyle.creaseTaper * 2,
  );

  /// The vaginal part's own outline below the attachments, to cast its
  /// shadow on the vagina's back wall.
  late final List<Offset> portio = () {
    final List<Offset> out = <Offset>[..._surfaceMm];
    return _placed(out);
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
      TubeCourse(tube, place, scale, mm(CervixStyle.edgeStep), bend: 0.9);

  /// [tube] as it runs on the body's right, mirrored.
  static AnatomyTube _mirrored(AnatomyTube tube) => AnatomyTube(
    <Offset>[for (final Offset p in tube.points) Offset(-p.dx, p.dy)],
    tube.radii,
    fadeIn: tube.fadeIn,
    fadeOut: tube.fadeOut,
    cutStart: tube.cutStart,
    cutEnd: tube.cutEnd,
  );

  static final List<AnatomyTube> _arteriesMm = <AnatomyTube>[
    for (final AnatomyTube t in <AnatomyTube>[
      CervixAnatomy.rightUterine,
      CervixAnatomy.rightAscending,
      CervixAnatomy.rightCervicovaginal,
    ]) ...<AnatomyTube>[_mirrored(t), t],
  ];

  /// The uterine arteries, each with its ascending and cervicovaginal
  /// branches, cut short: the body's right's and left's, in turn.
  late final List<TubeCourse> arteries = <TubeCourse>[
    for (final AnatomyTube t in _arteriesMm) _tube(t),
  ];

  /// The uterine artery on the body's left, which is named.
  late final TubeCourse namedArtery = arteries[1];

  /// The arteries' small branches into the wall, each running in under it.
  late final List<TubeCourse> branches = <TubeCourse>[
    for (final AnatomyTube t in _branchesMm) _tube(t),
  ];

  static final List<AnatomyTube> _branchesMm = () {
    final List<AnatomyTube> out = <AnatomyTube>[];
    final math.Random random = math.Random(CervixStyle.seed + 5);
    // Into the cervix and the uterus, from the branches that run beside
    // them; the vagina's wall is left alone.
    for (final AnatomyTube artery in _arteriesMm.skip(2)) {
      final TubeCourse course = TubeCourse(
        artery,
        (Offset p) => p,
        1,
        CervixStyle.edgeStep,
        bend: 0.9,
      );
      double next = CervixAnatomy.branchApart / 2;
      for (int i = 0; i < course.length; i++) {
        if (course.arc[i] < next) {
          continue;
        }
        final Offset c = course.centres[i];
        if (c.dy > 0) {
          break;
        }
        final Offset way = Offset(course.across[i].dy, -course.across[i].dx);
        final Offset aim =
            c +
            way * (CervixAnatomy.branchLean * (2 * random.nextDouble() - 1));
        Offset edge = _outlineMm.first;
        for (final Offset q in _outlineMm) {
          if ((q - aim).distanceSquared < (edge - aim).distanceSquared) {
            edge = q;
          }
        }
        final Offset to = edge - c;
        final double reach = to.distance;
        if (reach > CervixAnatomy.branchReach || reach <= 0) {
          continue;
        }
        next =
            course.arc[i] +
            CervixAnatomy.branchApart +
            CervixAnatomy.branchJitter * (2 * random.nextDouble() - 1);
        out.add(
          AnatomyTube(
            <Offset>[c, edge + to / reach * CervixAnatomy.branchUnder],
            const <double>[CervixAnatomy.branch, CervixAnatomy.branch],
          ),
        );
      }
    }
    return out;
  }();

  /// What runs on beside the cervix.
  late final List<TubeCourse> beside = arteries;

  // Where the parts are named.

  /// The ectocervix, in the vaginal part on the body's left; the uterus,
  /// in its cut muscle; the canal; the transformation zone; the vagina; and
  /// the uterine artery on the body's left, where it comes in to the
  /// cervix.
  late final Offset homeName = place(CervixAnatomy.homeName);
  late final Offset uterusName = place(CervixAnatomy.uterusName);
  late final Offset canalName = place(CervixAnatomy.canalName);
  late final Offset zoneName = place(CervixAnatomy.zoneName);
  late final Offset vaginaName = place(CervixAnatomy.vaginaName);
  late final Offset arteryName = namedArtery.centres[namedArtery.length ~/ 2];

  /// The outermost points of what is drawn at the height of [at], on
  /// either side: the outline, the vagina's walls and the arteries beside
  /// them, with room round the arteries; [at] alone where nothing is.
  (Offset, Offset) edgesAt(Offset at) {
    double left = double.infinity;
    double right = double.negativeInfinity;
    for (final List<Offset> shape in <List<Offset>>[
      outlinePoints,
      vaginaOutline,
    ]) {
      for (final double x in _crossings(shape, at.dy)) {
        left = math.min(left, x);
        right = math.max(right, x);
      }
    }
    final double clear = mm(CervixStyle.nameClear);
    for (final TubeCourse tube in beside) {
      for (int i = 0; i < tube.length; i++) {
        if (tube.shown[i] <= CervixStyle.nameShown) {
          continue;
        }
        final double reach = tube.radius[i] + clear;
        if ((tube.centres[i].dy - at.dy).abs() > reach) {
          continue;
        }
        left = math.min(left, tube.centres[i].dx - reach);
        right = math.max(right, tube.centres[i].dx + reach);
      }
    }
    if (left > right) {
      return (at, at);
    }
    return (Offset(left, at.dy), Offset(right, at.dy));
  }

  static List<double> _crossings(List<Offset> points, double y) {
    final List<double> out = <double>[];
    final int n = points.length;
    for (int i = 0; i < n; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % n];
      if ((a.dy <= y) != (b.dy <= y)) {
        out.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
      }
    }
    return out;
  }

  // The step from the body.

  /// The followed half's counterpart, in millimetres: the canal and the
  /// cervix's wall on the body's left, from the isthmus down, round the
  /// vaginal part's end to below the canal's far side.
  static final List<Offset> _halfMm = () {
    const double top = CervixAnatomy.internalOs;
    const double bottom = CervixAnatomy.externalOs;
    final List<Offset> wall = <Offset>[
      for (final Offset p in _outlineMm)
        if (p.dx >= 0 && p.dy >= top) p,
    ];
    wall.sort((Offset p, Offset q) => p.dy.compareTo(q.dy));
    // Across the isthmus from the canal's far side to the outline, as
    // finely as the rest is followed.
    final double far = -grooveAt(top);
    final int across = ((wall.first.dx - far) / CervixStyle.edgeStep).ceil();
    final List<Offset> out = <Offset>[
      for (int i = 0; i < across; i++)
        Offset(far + (wall.first.dx - far) * i / across, top),
      ...wall,
    ];
    // Round the end, below the canal's far side, and up it.
    final double end = grooveAt(bottom);
    final List<Offset> under = <Offset>[
      for (final Offset p in _outlineMm)
        if (p.dx < 0 && p.dx >= -end && p.dy > bottom) p,
    ];
    under.sort((Offset p, Offset q) => q.dx.compareTo(p.dx));
    out.addAll(under);
    final int steps = ((bottom - top) / CervixStyle.edgeStep).ceil();
    for (int i = 0; i < steps; i++) {
      final double y = bottom - (bottom - top) * i / steps;
      out.add(Offset(-grooveAt(y), y));
    }
    return out;
  }();

  /// Where the step from the body meets the cervix's half and the body's
  /// outline: the middle of the top, which is nearly level, in place of the
  /// topmost point, which a hair's difference could move along it; each
  /// side's outermost point, and the lowest, each picked out of either
  /// outline alike.
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
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.3, 0.7),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.3, 0.7),
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
  /// cervix's half and the body's, for tests: the top's middle, then the
  /// rest in the order round it from there.
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

/// A line from [from] to [to] in points [CervixStyle.edgeStep] apart,
/// wandering to either side by up to [wander], laid by [random].
List<Offset> _wandering(
  Offset from,
  Offset to,
  math.Random random,
  double wander,
) {
  final Offset way = to - from;
  final double length = way.distance;
  if (length <= 0) {
    return <Offset>[from, to];
  }
  final Offset along = way / length;
  final Offset across = Offset(-along.dy, along.dx);
  final double phase = random.nextDouble() * 2 * math.pi;
  final double wave = 3 + 3 * random.nextDouble();
  final int steps = math.max(2, (length / CervixStyle.edgeStep).ceil());
  return <Offset>[
    for (int i = 0; i <= steps; i++)
      () {
        final double s = length * i / steps;
        // No wandering at the ends, so each starts and stops where it is
        // laid.
        final double fade = math.sin(math.pi * i / steps);
        return from +
            along * s +
            across * (wander * fade * math.sin(s / wave * 2 * math.pi + phase));
      }(),
  ];
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
