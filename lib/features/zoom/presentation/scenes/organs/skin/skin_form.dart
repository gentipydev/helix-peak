import 'dart:math' as math;
import 'dart:ui';

import '../../lobules.dart';
import '../../relief.dart';
import 'skin_anatomy.dart';
import 'skin_style.dart';

/// Where in the skin the zoom's cell lives, which its drawing lights in the
/// mark, by the name the Atlas gives the cell, as the kidney, the liver,
/// the stomach and the esophagus choose theirs: every skin cell the Atlas
/// names is drawn as one of a few shapes, which cannot tell them apart.
enum SkinHome {
  /// The epidermis's basal layer, and each hair bulb, where melanocytes
  /// pigment the hair.
  melanocytes('basal\nlayer'),

  /// The epidermis's basal layer.
  basalLayer('basal\nlayer'),

  /// The epidermis above its basal layer.
  epidermis('epidermis'),

  /// The hair follicles' sheaths.
  follicle('hair\nfollicle'),

  /// The sebaceous gland.
  sebaceousGland('sebaceous\ngland'),

  /// The sweat glands' coils and ducts.
  sweatGland('sweat\ngland'),

  /// The dermis: fibroblasts, and any cell the Atlas finds everywhere.
  dermis('dermis');

  const SkinHome(this.word);

  /// What its name reads, on two lines where it is long.
  final String word;

  /// Where a cell the Atlas calls [cellName] lives.
  static SkinHome of(String? cellName) {
    final String name = (cellName ?? '').toLowerCase();
    if (name.contains('melanocyte')) {
      return melanocytes;
    }
    if (name.contains('basal keratinocyte') && !name.contains('suprabasal')) {
      return basalLayer;
    }
    if (name.contains('keratinocyte') || name.contains('langerhans')) {
      return epidermis;
    }
    if (name.contains('hair cortex') || name.contains('root sheath')) {
      return follicle;
    }
    if (name.contains('sebaceous')) {
      return sebaceousGland;
    }
    if (name.contains('sweat gland')) {
      return sweatGland;
    }
    return dermis;
  }
}

/// A sweat gland as the cut shows it: its coil, the tube's loops in it,
/// and its duct up to its pore, in the scene.
final class SkinCoil {
  const SkinCoil({
    required this.ball,
    required this.loops,
    required this.duct,
    required this.centre,
  });

  /// The coil's ball, the loops of its tube in it, and its duct.
  final Path ball;
  final Path loops;
  final List<Offset> duct;

  /// The coil's middle.
  final Offset centre;
}

/// A hair above the surface, in the scene: the way it runs from its root,
/// and how wide it is.
final class SkinHair {
  const SkinHair(this.points, this.width);

  final List<Offset> points;
  final double width;
}

/// A block of the leg's skin as the zoom's organ scene draws it: every shape
/// in the scene's units at the skin's real size, the middle of the drawn
/// block at the origin. The anatomy is `SkinAnatomy`'s, in millimetres of
/// the block ([at]): across its front face, down from the skin's surface and
/// back into the block, seen in an oblique view, the front face flat to the
/// screen and the top and the right side receding up and to the right.
///
/// The front face is the cut: the epidermis on its ridges over the
/// papillary dermis, the reticular dermis, and the fat in its lobules; a
/// follicle cut along its length with its sebaceous gland and its arrector
/// pili, and another cut through obliquely; two sweat glands; the two
/// plexuses of vessels and the vessels joining them; a nerve. The top is
/// the skin's surface, with its furrows, pores and hairs; the right side a
/// second cut, its layers carried round.
///
/// The place its tissue is sampled is in the epidermis on the front face
/// ([site]). Everything here is geometry: what it is drawn in is
/// `SkinArt`'s.
final class SkinForm {
  SkinForm({required double width, required this.view})
    : scale = width / SkinAnatomy.width;

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's millimetres, in the scene's units.
  final double scale;

  static const double _w = SkinAnatomy.width;
  static const double _d = SkinAnatomy.depth;
  static const double _h = SkinAnatomy.faceDepth;

  /// A point of the block, [x] across its front face, [y] down from the
  /// surface and [z] back from the front face, on the screen in
  /// millimetres, before it is placed.
  static Offset project(double x, double y, [double z = 0]) =>
      Offset(x + z * SkinStyle.backAcross, y - z * SkinStyle.backUp);

  /// The middle of the block as it is drawn, its front, top and side, in
  /// the screen's millimetres: the scene's origin.
  static final Offset middle = Offset(
    project(_w, 0, _d).dx / 2 + SkinStyle.offCentre,
    (project(0, 0, _d).dy + _h) / 2,
  );

  /// A point of the screen's millimetres, in the scene.
  Offset place(Offset mm) => (mm - middle) * scale;

  /// A point of the block, in the scene.
  Offset at(double x, double y, [double z = 0]) => place(project(x, y, z));

  /// [millimetres] of the real skin, in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the scene, in the screen's millimetres.
  Offset toMm(Offset p) => p / scale + middle;

  // The block.

  /// Its corners as drawn: the front face's lower left, upper left, the
  /// top's back left and back right, the side's lower back, the front
  /// face's lower right.
  static final List<Offset> _corners = <Offset>[
    project(0, _h),
    project(0, 0),
    project(0, 0, _d),
    project(_w, 0, _d),
    project(_w, _h, _d),
    project(_w, _h),
  ];

  /// Its outline, front, top and side, in the scene.
  late final List<Offset> outlinePoints = <Offset>[
    for (final Offset p in _corners) place(p),
  ];
  late final Path outline = Path()..addPolygon(outlinePoints, true);

  /// Its front face, its top and its right side, in the scene.
  late final Path front = _polygon(<Offset>[
    project(0, 0),
    project(_w, 0),
    project(_w, _h),
    project(0, _h),
  ]);
  late final Path top = _polygon(<Offset>[
    project(0, 0),
    project(_w, 0),
    project(_w, 0, _d),
    project(0, 0, _d),
  ]);
  late final Path side = _polygon(<Offset>[
    project(_w, 0),
    project(_w, 0, _d),
    project(_w, _h, _d),
    project(_w, _h),
  ]);

  /// The edges where the top meets the front and the side, and where the
  /// side meets the front, in the scene.
  late final List<Offset> topEdge = <Offset>[
    at(0, 0),
    at(_w, 0),
    at(_w, 0, _d),
  ];
  late final List<Offset> sideEdge = <Offset>[at(_w, 0), at(_w, _h)];

  /// The outermost points of the block at [y] millimetres down the screen,
  /// to its left and to its right, in the scene: where a name level with
  /// what it names stands clear of it.
  (Offset, Offset) edgesAt(double y) {
    const double back = _d * SkinStyle.backUp;
    final double left = y >= 0
        ? 0
        : math.min(-y, back) * SkinStyle.backAcross / SkinStyle.backUp;
    const double far = _w + _d * SkinStyle.backAcross;
    final double right = y <= _h - back
        ? far
        : far -
              (math.min(y, _h) - (_h - back)) /
                  SkinStyle.backUp *
                  SkinStyle.backAcross;
    return (place(Offset(left, y)), place(Offset(right, y)));
  }

  // The layers on the front face, each edge across it from left to right.

  /// How many points an edge across the face is followed by.
  static final int _across = (_w * SkinStyle.perMm).round();

  static List<double> get _xs => <double>[
    for (int i = 0; i <= _across; i++) _w * i / _across,
  ];

  /// The epidermis's floor, its rete ridges reaching down into the dermis,
  /// at [x] across the face: on the general surface few and minute (Gray).
  static double floorAt(double x) {
    final double wander = 0.8 * math.sin(x * 3.1 + 0.6);
    final double ridge =
        0.5 +
        0.5 * math.sin(2 * math.pi * x / SkinAnatomy.ridgeSpacing + wander);
    return SkinAnatomy.epidermis +
        SkinAnatomy.ridgeDepth * (ridge * ridge - 0.35);
  }

  /// Where the papillary dermis gives way to the reticular, at [x].
  static double papillaryAt(double x) =>
      SkinAnatomy.epidermis +
      SkinAnatomy.papillary +
      0.02 * math.sin(x * 5.3 + 1);

  /// Where the dermis meets the fat, at [x].
  static double dermisAt(double x) =>
      SkinAnatomy.skin +
      0.05 * math.sin(x * 2.3 + 0.4) +
      0.025 * math.sin(x * 6.1 + 2);

  List<Offset> _edge(double Function(double) y) => <Offset>[
    for (final double x in _xs) at(x, y(x)),
  ];

  /// The epidermis's floor, along the basal layer, in the scene.
  late final List<Offset> basal = _edge(floorAt);

  /// The horny layer, the epidermis, the papillary dermis, the reticular
  /// dermis and the fat, each a band across the face, in the scene.
  late final Path corneum = _polygon(<Offset>[
    project(0, 0),
    project(_w, 0),
    project(_w, SkinAnatomy.corneum),
    project(0, SkinAnatomy.corneum),
  ]);
  late final Path epidermis = _band((double _) => 0, floorAt);
  late final Path papillary = _band(floorAt, papillaryAt);
  late final Path reticular = _band(papillaryAt, dermisAt);
  late final Path dermis = _band(floorAt, dermisAt);
  late final List<Offset> fatPoints = <Offset>[
    ..._edge(dermisAt),
    at(_w, _h),
    at(0, _h),
  ];
  late final Path fat = Path()..addPolygon(fatPoints, true);

  /// The lines between the layers, in the scene: the papillary dermis's
  /// floor and the dermis's.
  late final List<Offset> papillaryLine = _edge(papillaryAt);
  late final List<Offset> dermisLine = _edge(dermisAt);

  Path _band(double Function(double) upper, double Function(double) lower) {
    final List<double> xs = _xs;
    return Path()..addPolygon(<Offset>[
      for (final double x in xs) at(x, upper(x)),
      for (final double x in xs.reversed) at(x, lower(x)),
    ], true);
  }

  // The fat.

  /// Its lobules, laid in the fat of the front face.
  late final Lobules lobules = Lobules.lay(
    fatPoints,
    box: fat.getBounds(),
    inward: _area(fatPoints) > 0 ? 1.0 : -1.0,
    style: SkinStyle.lobules,
    mm: mm,
    seed: SkinStyle.seed,
  );

  /// The cushion its cut face lies on, under the lobules.
  late final Relief fatRelief = Relief(
    fatPoints,
    cell: mm(SkinStyle.reliefCell),
    inflation: SkinStyle.reliefInflation,
    sweeps: SkinStyle.reliefSweeps,
  );

  // The bands of fibres in the reticular dermis.

  /// Each a short wavy line lying mostly across the face, coarser toward
  /// the fat, in the scene.
  late final List<List<Offset>> fibres = () {
    final math.Random random = math.Random(SkinStyle.seed + 1);
    return <List<Offset>>[
      for (int k = 0; k < SkinStyle.fibres; k++)
        () {
          final double x = random.nextDouble() * _w;
          final double top = papillaryAt(x) + 0.06;
          final double y =
              top + random.nextDouble() * (dermisAt(x) - 0.05 - top);
          final double turn = (random.nextDouble() - 0.5) * 0.7;
          final double length =
              SkinStyle.fibreLength * (0.6 + 0.8 * random.nextDouble());
          final double phase = random.nextDouble() * math.pi * 2;
          return <Offset>[
            for (int i = 0; i <= 10; i++)
              () {
                final double s = (i / 10 - 0.5) * length;
                return at(
                  x + s * math.cos(turn),
                  y +
                      s * math.sin(turn) +
                      SkinStyle.fibreWave * math.sin(phase + s * 14),
                );
              }(),
          ];
        }(),
    ];
  }();

  // The follicle cut along its length.

  static const double _slope = SkinAnatomy.slope * math.pi / 180;

  /// The way down the follicle, from its opening toward its bulb, and the
  /// way across it toward the side the hair slopes toward, where its
  /// sebaceous gland and its muscle lie (Gray).
  static final Offset down = Offset(-math.cos(_slope), math.sin(_slope));
  static final Offset toward = Offset(math.sin(_slope), math.cos(_slope));

  /// How far along the follicle from its opening its bulb's middle lies.
  static final double bulbAlong = SkinAnatomy.bulbDepth / math.sin(_slope);

  /// A point so far [along] the follicle's middle from its opening and so
  /// far [across] it toward the slope's side, in the face's millimetres.
  static Offset follicleAt(double along, [double across = 0]) =>
      const Offset(SkinAnatomy.opening, 0) + down * along + toward * across;

  /// How far the follicle's sheaths reach from its middle, [along] it: wide
  /// in the funnel it opens by, as broad as it is down its length, and the
  /// bulb round its papilla at its deep end.
  static double follicleHalf(double along) {
    const double half = SkinAnatomy.follicleBreadth / 2;
    final double funnel = SkinAnatomy.funnelDepth / math.sin(_slope);
    double base = half;
    if (along < funnel) {
      final double t = 1 - along / funnel;
      base = half + (SkinAnatomy.funnelWidth / 2 - half) * t * t;
    }
    final double u = (along - bulbAlong) / (SkinAnatomy.bulbLength / 2);
    final double bulb = u.abs() >= 1
        ? 0
        : SkinAnatomy.bulbBreadth / 2 * math.sqrt(1 - u * u);
    return along <= bulbAlong ? math.max(base, bulb) : bulb;
  }

  /// Where the follicle ends, past its bulb.
  static final double follicleEnd = bulbAlong + SkinAnatomy.bulbLength / 2;

  /// The follicle's outline, its sheaths and its bulb, in the scene.
  late final List<Offset> folliclePoints = () {
    const int n = 160;
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    for (int i = 0; i <= n; i++) {
      // Closer together toward its end, where the bulb rounds off.
      final double t = i / n;
      final double along = follicleEnd * (1 - math.pow(1 - t, 1.6).toDouble());
      final double half = follicleHalf(along);
      final Offset p = follicleAt(along, half);
      final Offset q = follicleAt(along, -half);
      plus.add(at(p.dx, p.dy));
      minus.add(at(q.dx, q.dy));
    }
    return <Offset>[...plus, ...minus.reversed];
  }();
  late final Path follicle = Path()..addPolygon(folliclePoints, true);

  /// Its bulb, round the papilla, in the scene.
  late final Path bulb = _ellipse(
    follicleAt(bulbAlong),
    SkinAnatomy.bulbLength,
    SkinAnatomy.bulbBreadth,
    down,
  );

  /// Its papilla, rising into the bulb from below, in the scene.
  late final Path papilla = _ellipse(
    follicleAt(follicleEnd - SkinAnatomy.papillaHeight / 2),
    SkinAnatomy.papillaHeight,
    SkinAnatomy.papillaBreadth,
    down,
  );

  /// The hair in it, from its bulb up to the surface, and its inner root
  /// sheath, from the bulb up to the sebaceous duct, in the scene.
  late final Path shaft = _strip(
    0,
    bulbAlong - SkinAnatomy.bulbLength * 0.15,
    SkinAnatomy.shaft / 2,
  );
  late final Path innerSheath = _strip(
    SkinAnatomy.ductAlong,
    bulbAlong - SkinAnatomy.bulbLength * 0.25,
    SkinAnatomy.shaft / 2 + 0.018,
  );

  Path _strip(double from, double to, double half) {
    final Offset a = follicleAt(from, half);
    final Offset b = follicleAt(to, half);
    final Offset c = follicleAt(to, -half);
    final Offset d = follicleAt(from, -half);
    return _polygon(<Offset>[a, b, c, d]);
  }

  // The arrector pili.

  /// Where it is inserted, on the follicle's slope side below the
  /// sebaceous duct, in the face's millimetres.
  static final Offset insertion = follicleAt(
    SkinAnatomy.insertionAlong,
    SkinAnatomy.follicleBreadth / 2,
  );

  /// The muscle, from its origin in the papillary dermis to its insertion,
  /// tapering, in the scene.
  late final Path muscle = () {
    const Offset o = SkinAnatomy.origin;
    final Offset way = insertion - o;
    final Offset unit = way / way.distance;
    final Offset normal = Offset(-unit.dy, unit.dx);
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    const int n = 16;
    for (int i = 0; i <= n; i++) {
      final double t = i / n;
      final double half =
          (SkinAnatomy.muscleOrigin +
              (SkinAnatomy.muscleInsertion - SkinAnatomy.muscleOrigin) * t) /
          2;
      // Bowed a little away from the gland.
      final Offset p = o + way * t + normal * (0.025 * math.sin(math.pi * t));
      plus.add(p + normal * half);
      minus.add(p - normal * half);
    }
    return _polygon(<Offset>[...plus, ...minus.reversed]);
  }();

  /// How far from the follicle's slope-side edge, [along] it, the muscle
  /// lies, measured across the follicle: the room its gland has there.
  static double roomAt(double along) {
    const double half = SkinAnatomy.follicleBreadth / 2;
    final Offset f = follicleAt(along, half);
    const Offset o = SkinAnatomy.origin;
    final Offset m = insertion - o;
    // f + toward·t = o + m·s.
    final double det = toward.dx * -m.dy - toward.dy * -m.dx;
    final Offset r = o - f;
    return (r.dx * -m.dy - r.dy * -m.dx) / det;
  }

  // The sebaceous gland.

  /// Its alveoli, in the angle between the follicle and the muscle, each
  /// as large as the room there leaves it, clear of the muscle's breadth:
  /// their middles and radii, in the face's millimetres.
  static final List<(Offset, double)> alveoli = <(Offset, double)>[
    for (final (double along, double most) in SkinAnatomy.alveoli)
      () {
        const double half = SkinAnatomy.follicleBreadth / 2;
        const double muscle = SkinAnatomy.muscleOrigin / 2;
        Offset at(double r) => follicleAt(along, half + _clear + r);
        double r = math.min(most, (roomAt(along) - _clear * 2) / 2);
        while (r > 0.03 &&
            _toSegment(at(r), SkinAnatomy.origin, insertion) <
                r + muscle + _clear) {
          r -= 0.002;
        }
        return (at(r), r);
      }(),
  ];

  /// How far its alveoli keep from the follicle and the muscle.
  static const double _clear = 0.012;

  /// Its alveoli, each a little lobed, and its duct into the follicle, in
  /// the scene.
  late final Path gland = () {
    final Path path = Path();
    final math.Random random = math.Random(SkinStyle.seed + 2);
    for (final (Offset c, double r) in alveoli) {
      path.addPolygon(<Offset>[
        for (int k = 0; k < 36; k++)
          () {
            final double a = 2 * math.pi * k / 36;
            final double lobe =
                1 + 0.07 * math.sin(3 * a + random.nextDouble() * 6);
            final Offset p = c + Offset(math.cos(a), math.sin(a)) * (r * lobe);
            return at(p.dx, p.dy);
          }(),
      ], true);
    }
    final Offset first = alveoli.first.$1;
    final Offset entry = follicleAt(
      SkinAnatomy.ductAlong,
      SkinAnatomy.follicleBreadth / 2 - 0.01,
    );
    final Offset way = first - entry;
    final Offset normal = Offset(-way.dy, way.dx) / way.distance;
    const double half = 0.025;
    path.addPolygon(<Offset>[
      at((entry + normal * half).dx, (entry + normal * half).dy),
      at((first + normal * half).dx, (first + normal * half).dy),
      at((first - normal * half).dx, (first - normal * half).dy),
      at((entry - normal * half).dx, (entry - normal * half).dy),
    ], true);
    return path;
  }();

  /// The flecks of its fat-filled cells, in the scene.
  late final List<Offset> glandFlecks = () {
    final math.Random random = math.Random(SkinStyle.seed + 3);
    return <Offset>[
      for (final (Offset c, double r) in alveoli)
        for (int k = 0; k < 7; k++)
          () {
            final double a = random.nextDouble() * 2 * math.pi;
            final double s = r * 0.7 * math.sqrt(random.nextDouble());
            final Offset p = c + Offset(math.cos(a), math.sin(a)) * s;
            return at(p.dx, p.dy);
          }(),
    ];
  }();

  // The follicle cut through obliquely.

  static final Offset _otherWay = Offset(
    math.cos(SkinAnatomy.otherSlope * math.pi / 180),
    -math.sin(SkinAnatomy.otherSlope * math.pi / 180),
  );

  /// Its sheaths rising from its bulb until they leave the cut, square, its
  /// bulb, its papilla and its hair, in the scene.
  late final Path other = () {
    const Offset b = SkinAnatomy.otherBulb;
    final Offset normal = Offset(-_otherWay.dy, _otherWay.dx);
    const double half = SkinAnatomy.follicleBreadth / 2 * 0.9;
    final Offset end = b + _otherWay * SkinAnatomy.otherShown;
    return _polygon(<Offset>[
      b + normal * half,
      end + normal * half,
      end - normal * half,
      b - normal * half,
    ]);
  }();
  late final Path otherBulb = _ellipse(
    SkinAnatomy.otherBulb,
    SkinAnatomy.bulbLength * 0.9,
    SkinAnatomy.bulbBreadth * 0.9,
    -_otherWay,
  );
  late final Path otherPapilla = _ellipse(
    SkinAnatomy.otherBulb - _otherWay * (SkinAnatomy.bulbLength * 0.3),
    SkinAnatomy.papillaHeight * 0.9,
    SkinAnatomy.papillaBreadth * 0.9,
    -_otherWay,
  );
  late final Path otherShaft = () {
    const Offset b = SkinAnatomy.otherBulb;
    final Offset normal = Offset(-_otherWay.dy, _otherWay.dx);
    const double half = SkinAnatomy.shaft / 2;
    final Offset from = b + _otherWay * (SkinAnatomy.bulbLength * 0.15);
    final Offset end = b + _otherWay * SkinAnatomy.otherShown;
    return _polygon(<Offset>[
      from + normal * half,
      end + normal * half,
      end - normal * half,
      from - normal * half,
    ]);
  }();

  // The sweat glands.

  /// Each one's coil and duct, in the scene.
  late final List<SkinCoil> coils = <SkinCoil>[
    for (int k = 0; k < SkinAnatomy.coils.length; k++) _coil(k),
  ];

  SkinCoil _coil(int k) {
    final (Offset c, double width, double height, double pore) =
        SkinAnatomy.coils[k];
    final math.Random random = math.Random(SkinStyle.seed + 10 + k);
    final Path ball = _ellipse(c, width, height, const Offset(1, 0));
    // The tube rolled into the ball: loops lying on one another.
    final Path loops = Path();
    for (int j = 0; j < 7; j++) {
      final Offset middle =
          c +
          Offset(
            (random.nextDouble() - 0.5) * width * 0.5,
            (random.nextDouble() - 0.5) * height * 0.5,
          );
      final double rx = width * (0.14 + 0.08 * random.nextDouble());
      final double ry = height * (0.14 + 0.08 * random.nextDouble());
      final double turn = random.nextDouble() * math.pi;
      loops.addPolygon(<Offset>[
        for (int i = 0; i < 24; i++)
          () {
            final double a = 2 * math.pi * i / 24;
            final Offset p =
                middle +
                Offset(
                  rx * math.cos(a) * math.cos(turn) -
                      ry * math.sin(a) * math.sin(turn),
                  rx * math.cos(a) * math.sin(turn) +
                      ry * math.sin(a) * math.cos(turn),
                );
            return at(p.dx, p.dy);
          }(),
      ], true);
    }
    // Its duct: convoluted in the deeper dermis, straight in the
    // superficial, and spiralling through the epidermis to its pore (Gray).
    final Offset from = c - Offset(0, height / 2);
    final List<Offset> duct = <Offset>[];
    const int n = 90;
    for (int i = 0; i <= n; i++) {
      final double t = i / n;
      final double y = from.dy * (1 - t);
      final double x = from.dx + (pore - from.dx) * _smooth(t);
      final double deep = _smooth((y - 0.8) / 0.5);
      final double inEpidermis = _smooth(
        (SkinAnatomy.epidermis + 0.02 - y) / 0.03,
      );
      // The spiral comes to rest on the pore.
      final double wiggle =
          0.06 * deep * math.sin(t * 46 + k) +
          0.012 * inEpidermis * math.sin(t * 160) * math.min(1, (1 - t) / 0.03);
      duct.add(at(x + wiggle, y));
    }
    return SkinCoil(
      ball: ball,
      loops: loops,
      duct: duct,
      centre: at(c.dx, c.dy),
    );
  }

  // The vessels and the nerve.

  /// The cut vessels of the two plexuses and of the fat's septa, each with
  /// its radius and whether it is a venule, in the scene.
  late final List<(Offset, double, bool)> vessels = () {
    final List<(Offset, double, bool)> out = <(Offset, double, bool)>[];
    int k = 0;
    for (final (double x, double r) in SkinAnatomy.upperVessels) {
      out.add((at(x, SkinAnatomy.upperPlexus), mm(r), (k++).isOdd));
    }
    for (final (double x, double r) in SkinAnatomy.lowerVessels) {
      out.add((at(x, dermisAt(x)), mm(r), (k++).isOdd));
    }
    for (final (Offset p, double r) in SkinAnatomy.septalVessels) {
      out.add((at(p.dx, p.dy), mm(r), (k++).isOdd));
    }
    return out;
  }();

  /// The ascending arteriole and the descending venule joining the two
  /// plexuses, in the scene.
  late final Path arteriole = _riser(SkinAnatomy.arteriole, 0.4);
  late final Path venule = _riser(SkinAnatomy.venule, 1.7);

  Path _riser((double, double) vessel, double phase) {
    final (double x, double r) = vessel;
    final double bottom = dermisAt(x);
    const int n = 24;
    final List<Offset> plus = <Offset>[];
    final List<Offset> minus = <Offset>[];
    for (int i = 0; i <= n; i++) {
      final double y =
          SkinAnatomy.upperPlexus + (bottom - SkinAnatomy.upperPlexus) * i / n;
      final double wander = 0.02 * math.sin(y * 9 + phase);
      plus.add(project(x + wander + r, y));
      minus.add(project(x + wander - r, y));
    }
    return _polygon(<Offset>[...plus, ...minus.reversed]);
  }

  /// The nerve, cut across, and the fascicles in it, in the scene.
  late final Offset nerve = at(SkinAnatomy.nerve.dx, SkinAnatomy.nerve.dy);
  late final double nerveRadius = mm(SkinAnatomy.nerveRadius);

  // The surface.

  /// A point of the surface, [x] across and [z] back, in the scene.
  Offset onTop(double x, double z) => at(x, 0, z);

  /// Its furrows: two sets of lines crossing at different angles, dividing
  /// it into lozenges, as Gray has it; each line wanders a little, in the
  /// scene.
  late final List<List<Offset>> furrows = () {
    final math.Random random = math.Random(SkinStyle.seed + 4);
    final List<List<Offset>> out = <List<Offset>>[];
    for (final double angle in <double>[0.62, -0.45]) {
      final Offset way = Offset(math.cos(angle), math.sin(angle));
      final Offset across = Offset(-way.dy, way.dx);
      const double reach = _w + _d;
      for (double s = -reach; s <= reach; s += SkinStyle.furrowSpacing) {
        final double offset =
            s + (random.nextDouble() - 0.5) * SkinStyle.furrowJitter;
        final List<Offset> line = <Offset>[];
        for (double t = -reach; t <= reach; t += 0.08) {
          final Offset p =
              const Offset(_w / 2, _d / 2) +
              across * offset +
              way * t +
              across * (0.03 * math.sin(t * 7 + offset * 3));
          if (p.dx >= 0 && p.dx <= _w && p.dy >= 0 && p.dy <= _d) {
            line.add(onTop(p.dx, p.dy));
          } else if (line.isNotEmpty) {
            break;
          }
        }
        if (line.length > 1) {
          out.add(line);
        }
      }
    }
    return out;
  }();

  /// Its pores, the sweat ducts' openings: those on the top and the two at
  /// its front edge, where the cut's ducts open, in the scene.
  late final List<Offset> pores = <Offset>[
    for (final Offset p in SkinAnatomy.pores) onTop(p.dx, p.dy),
    for (final (Offset _, double _, double _, double pore) in SkinAnatomy.coils)
      onTop(pore, 0),
  ];

  /// The follicles' openings on the top, the cut one's at its front edge,
  /// in the scene.
  late final List<Offset> openings = <Offset>[
    onTop(SkinAnatomy.opening, 0),
    for (final Offset p in SkinAnatomy.hairs) onTop(p.dx, p.dy),
  ];

  /// The hairs above the surface: the cut follicle's, rising from the
  /// front edge in the cut's plane and leaning over, and those on the top,
  /// each leaning the same way, in the scene.
  late final List<SkinHair> hairs = <SkinHair>[
    _hair(const Offset(SkinAnatomy.opening, 0), 0, -down, 0),
    for (final Offset p in SkinAnatomy.hairs)
      _hair(
        Offset(p.dx, 0),
        p.dy,
        Offset(math.cos(0.75), -math.sin(0.75)),
        0.18,
      ),
  ];

  SkinHair _hair(Offset root, double z, Offset way, double back) {
    const double length = SkinAnatomy.hairShown;
    const int n = 24;
    return SkinHair(<Offset>[
      for (int i = 0; i <= n; i++)
        () {
          final double t = i / n * length;
          // Leaning over as it grows, as a hair does.
          final double bend = 0.25 * (t / length) * (t / length);
          final Offset p = root + way * t + Offset(bend, bend * 0.6);
          return at(p.dx, p.dy, z + back * t);
        }(),
    ], mm(SkinAnatomy.shaft));
  }

  // The right side, a second cut.

  /// A point of the side, [z] back and [y] down, in the scene.
  Offset onSide(double z, double y) => at(_w, y, z);

  /// Its layers, as bands from the front edge back, in the scene: the
  /// epidermis, the papillary dermis, the reticular dermis and the fat.
  late final Path sideEpidermis = _sideBand(0, SkinAnatomy.epidermis);
  late final Path sidePapillary = _sideBand(
    SkinAnatomy.epidermis,
    SkinAnatomy.epidermis + SkinAnatomy.papillary,
  );
  late final Path sideReticular = _sideBand(
    SkinAnatomy.epidermis + SkinAnatomy.papillary,
    SkinAnatomy.skin,
  );
  late final Path sideFat = _sideBand(SkinAnatomy.skin, _h);

  Path _sideBand(double from, double to) => _polygon(<Offset>[
    project(_w, from),
    project(_w, from, _d),
    project(_w, to, _d),
    project(_w, to),
  ]);

  /// The septa of its fat, faint lines down through it, and the vessels
  /// cut at its lower plexus, in the scene.
  late final List<List<Offset>> sideSepta = () {
    final math.Random random = math.Random(SkinStyle.seed + 5);
    return <List<Offset>>[
      for (double z = 0.45; z < _d; z += 0.7 + 0.2 * random.nextDouble())
        <Offset>[
          for (int i = 0; i <= 12; i++)
            () {
              final double y =
                  SkinAnatomy.skin + (_h - SkinAnatomy.skin) * i / 12;
              return onSide(z + 0.08 * math.sin(y * 4 + z), y);
            }(),
        ],
    ];
  }();
  late final List<Offset> sideVessels = <Offset>[
    onSide(0.7, SkinAnatomy.skin),
    onSide(1.9, SkinAnatomy.skin),
    onSide(1.3, SkinAnatomy.upperPlexus),
  ];

  // The place its tissue is sampled, and its names.

  /// In the epidermis of the front face, a third of the way across.
  late final Offset site = at(SkinAnatomy.site.dx, SkinAnatomy.site.dy);

  /// The points its names point at, in the scene, each column's spread
  /// down the block so that each name can stand level with its own: the
  /// basal layer under the site; the epidermis where the side cuts it, at
  /// the back; the dermis, the fat; the arrector pili by its insertion; the
  /// sebaceous gland's middle alveolus; the bulb of the follicle cut
  /// obliquely, by the block's right edge; the sweat gland in the fat.
  late final Offset basalName = at(
    SkinAnatomy.site.dx,
    floorAt(SkinAnatomy.site.dx),
  );
  late final Offset epidermisSiteName = site;
  late final Offset epidermisName = onSide(
    _d * 0.95,
    SkinAnatomy.epidermis / 2,
  );
  late final Offset dermisName = at(0.22, 1.25);
  late final Offset dermisSiteName = at(
    SkinAnatomy.site.dx,
    papillaryAt(SkinAnatomy.site.dx) + 0.1,
  );
  late final Offset fatName = at(1.5, 3.9);
  late final Offset muscleName = () {
    final Offset p = Offset.lerp(SkinAnatomy.origin, insertion, 0.78)!;
    return at(p.dx, p.dy);
  }();
  late final Offset glandName = () {
    final (Offset c, double _) = alveoli[1];
    return at(c.dx, c.dy);
  }();
  late final Offset follicleName = at(
    SkinAnatomy.otherBulb.dx,
    SkinAnatomy.otherBulb.dy + 0.1,
  );
  late final Offset sweatName = coils.last.centre;

  // Helpers.

  /// An ellipse [length] along [way] and [breadth] across it, round [c] in
  /// the face's millimetres, in the scene.
  Path _ellipse(Offset c, double length, double breadth, Offset way) {
    final Offset u = way / way.distance;
    final Offset v = Offset(-u.dy, u.dx);
    return Path()..addPolygon(<Offset>[
      for (int k = 0; k < 40; k++)
        () {
          final double a = 2 * math.pi * k / 40;
          final Offset p =
              c +
              u * (length / 2 * math.cos(a)) +
              v * (breadth / 2 * math.sin(a));
          return at(p.dx, p.dy);
        }(),
    ], true);
  }

  /// The polygon through [mm], points of the screen's millimetres or of the
  /// front face, in the scene.
  Path _polygon(List<Offset> mm) =>
      Path()..addPolygon(<Offset>[for (final Offset p in mm) place(p)], true);

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

/// How far [p] lies from the segment from [a] to [b].
double _toSegment(Offset p, Offset a, Offset b) {
  final Offset ab = b - a;
  final double length = ab.dx * ab.dx + ab.dy * ab.dy;
  final double t = length == 0
      ? 0
      : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
