import 'dart:math' as math;
import 'dart:ui';

import 'adipose_anatomy.dart';
import 'adipose_style.dart';

/// A block of the abdominal wall beside the navel as the zoom's organ scene
/// draws it: every shape in the scene's units at the wall's real size, the
/// middle of the drawn block at the origin. The anatomy is
/// `AdiposeAnatomy`'s, in millimetres of the block ([at]): across its front
/// face, down from the skin's surface and back into the block, seen in an
/// oblique view, the front face flat to the screen and the top and the
/// right side receding up and to the right, as the skin's block is.
///
/// The front face is the cut: the skin, the superficial fat in its small
/// rounded lobes between upright septa, the membranous layer, the deep fat
/// in its wide flat lobes between leaning septa, the rectus sheath and the
/// rectus cut across, its fascicles; the superficial epigastric artery and
/// vein cut in the superficial fat, and a perforator rising from the rectus
/// to the skin. The top is the skin's surface; the right side a second cut,
/// its layers carried round.
///
/// Wherever the zoom's cell lives in it, it lives in the fat: its home is
/// the fat of both layers. The place its tissue is sampled is in the
/// superficial fat ([site]). Everything here is geometry: what it is drawn
/// in is `AdiposeArt`'s.
final class AdiposeForm {
  AdiposeForm({required double width, required this.view})
    : scale = width / AdiposeAnatomy.width;

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's millimetres, in the scene's units.
  final double scale;

  static const double _w = AdiposeAnatomy.width;
  static const double _d = AdiposeAnatomy.depth;
  static const double _h = AdiposeAnatomy.faceDepth;

  /// A point of the block, [x] across its front face, [y] down from the
  /// skin's surface and [z] back from the front face, on the screen in
  /// millimetres, before it is placed.
  static Offset project(double x, double y, [double z = 0]) =>
      Offset(x + z * AdiposeStyle.backAcross, y - z * AdiposeStyle.backUp);

  /// The middle of the block as it is drawn, its front, top and side, in
  /// the screen's millimetres: the scene's origin.
  static final Offset middle = Offset(
    project(_w, 0, _d).dx / 2 + AdiposeStyle.offCentre,
    (project(0, 0, _d).dy + _h) / 2,
  );

  /// A point of the screen's millimetres, in the scene.
  Offset place(Offset mm) => (mm - middle) * scale;

  /// A point of the block, in the scene.
  Offset at(double x, double y, [double z = 0]) => place(project(x, y, z));

  /// [millimetres] of the real wall, in the scene's units.
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
    const double back = _d * AdiposeStyle.backUp;
    final double left = y >= 0
        ? 0
        : math.min(-y, back) * AdiposeStyle.backAcross / AdiposeStyle.backUp;
    const double far = _w + _d * AdiposeStyle.backAcross;
    final double right = y <= _h - back
        ? far
        : far -
              (math.min(y, _h) - (_h - back)) /
                  AdiposeStyle.backUp *
                  AdiposeStyle.backAcross;
    return (place(Offset(left, y)), place(Offset(right, y)));
  }

  // The layers on the front face, each edge across it from left to right.

  /// How many points an edge across the face is followed by.
  static final int _across = (_w * AdiposeStyle.perMm).round();

  static List<double> get _xs => <double>[
    for (int i = 0; i <= _across; i++) _w * i / _across,
  ];

  /// Where the skin meets the fat, at [x].
  static double skinAt(double x) =>
      AdiposeAnatomy.skin + 0.08 * math.sin(x * 0.9 + 0.4);

  /// Where the superficial fat meets the membranous layer, and where that
  /// meets the deep fat, at [x].
  static double superficialAt(double x) =>
      AdiposeAnatomy.superficialEnd +
      0.4 * math.sin(x * 0.31 + 1) +
      0.15 * math.sin(x * 1.1);
  static double membranousAt(double x) =>
      superficialAt(x) + AdiposeAnatomy.membranous;

  /// Where the deep fat meets the rectus sheath, and the sheath the rectus,
  /// at [x].
  static double deepAt(double x) =>
      AdiposeAnatomy.deepEnd + 0.3 * math.sin(x * 0.23 + 2);
  static double rectusAt(double x) => deepAt(x) + AdiposeAnatomy.sheath;

  List<Offset> _edge(double Function(double) y) => <Offset>[
    for (final double x in _xs) at(x, y(x)),
  ];

  Path _band(double Function(double) upper, double Function(double) lower) {
    final List<double> xs = _xs;
    return Path()..addPolygon(<Offset>[
      for (final double x in xs) at(x, upper(x)),
      for (final double x in xs.reversed) at(x, lower(x)),
    ], true);
  }

  /// The epidermis, the dermis, the superficial fat, the membranous layer,
  /// the deep fat, the anterior rectus sheath and the rectus, each a band
  /// across the face, in the scene.
  late final Path epidermis = _band(
    (double _) => 0,
    (double _) => AdiposeAnatomy.epidermis,
  );
  late final Path dermis = _band(
    (double _) => AdiposeAnatomy.epidermis,
    skinAt,
  );
  late final Path superficial = _band(skinAt, superficialAt);
  late final Path membranous = _band(superficialAt, membranousAt);
  late final Path deep = _band(membranousAt, deepAt);
  late final Path sheath = _band(deepAt, rectusAt);
  late final Path rectus = _band(rectusAt, (double _) => _h);

  /// The epidermis's middle, across the face's top, in the scene.
  late final List<Offset> epidermisLine = <Offset>[
    at(0, AdiposeAnatomy.epidermis / 2),
    at(_w, AdiposeAnatomy.epidermis / 2),
  ];

  /// The lines between the layers, in the scene.
  late final List<List<Offset>> layerLines = <List<Offset>>[
    _edge(skinAt),
    _edge(superficialAt),
    _edge(membranousAt),
    _edge(deepAt),
    _edge(rectusAt),
  ];

  // The lobes and the fascicles.

  /// The superficial fat's lobes, each a cell of a lattice taller than it
  /// is wide, their septa upright; the deep fat's, each a cell of one far
  /// wider than tall, leaning; the rectus's fascicles: in the scene, each
  /// laid over its layer's box and cut by its layer when drawn.
  late final List<List<Offset>> superficialLobes = _lattice(
    AdiposeAnatomy.superficialAcross,
    AdiposeAnatomy.superficialDown,
    0,
    AdiposeAnatomy.skin,
    AdiposeAnatomy.superficialEnd + 0.6,
    AdiposeStyle.seed,
  );
  late final List<List<Offset>> deepLobes = _lattice(
    AdiposeAnatomy.deepAcross,
    AdiposeAnatomy.deepDown,
    AdiposeAnatomy.deepLean,
    AdiposeAnatomy.membranousEnd - 0.6,
    AdiposeAnatomy.deepEnd + 0.4,
    AdiposeStyle.seed + 1,
  );
  late final List<List<Offset>> fascicles = _lattice(
    AdiposeAnatomy.fascicle,
    AdiposeAnatomy.fascicle,
    0,
    AdiposeAnatomy.deepEnd,
    _h,
    AdiposeStyle.seed + 2,
  );

  /// The cells of a lattice [across] by [down] apart, turned by [lean],
  /// whose middles lie on the face from [from] to [to] down it, in the
  /// scene: each the
  /// ground nearer its middle than any other's, in the lattice's own
  /// measure, so that a lattice wider than tall gives flat cells.
  List<List<Offset>> _lattice(
    double across,
    double down,
    double lean,
    double from,
    double to,
    int seed,
  ) {
    final math.Random random = math.Random(seed);
    final double c = math.cos(lean);
    final double s = math.sin(lean);
    // The face's millimetres from the lattice's own measure, where its
    // cells are a unit apart, and back.
    Offset toFace(Offset u) => Offset(
      u.dx * across * c - u.dy * down * s,
      u.dx * across * s + u.dy * down * c,
    );
    Offset toUnit(Offset p) =>
        Offset((p.dx * c + p.dy * s) / across, (-p.dx * s + p.dy * c) / down);
    final List<Offset> corners = <Offset>[
      toUnit(Offset(-across, from - down)),
      toUnit(Offset(_w + across, from - down)),
      toUnit(Offset(_w + across, to + down)),
      toUnit(Offset(-across, to + down)),
    ];
    final double u0 = corners.map((Offset p) => p.dx).reduce(math.min);
    final double u1 = corners.map((Offset p) => p.dx).reduce(math.max);
    final double v0 = corners.map((Offset p) => p.dy).reduce(math.min);
    final double v1 = corners.map((Offset p) => p.dy).reduce(math.max);
    final List<Offset> middles = <Offset>[];
    for (int row = v0.floor(); row <= v1.ceil(); row++) {
      for (int col = u0.floor(); col <= u1.ceil(); col++) {
        middles.add(
          Offset(
            col +
                (row.isOdd ? 0.5 : 0) +
                (random.nextDouble() * 2 - 1) * AdiposeAnatomy.stray,
            row + (random.nextDouble() * 2 - 1) * AdiposeAnatomy.stray,
          ),
        );
      }
    }
    final List<List<Offset>> out = <List<Offset>>[];
    for (int i = 0; i < middles.length; i++) {
      // Only the cells whose middles lie on the face, each cut against all
      // the others: what it draws stays near the block.
      final Offset p = toFace(middles[i]);
      if (p.dx < 0 || p.dx > _w || p.dy < from || p.dy > to) {
        continue;
      }
      out.add(<Offset>[
        for (final Offset q in _cell(middles, i, 1.6))
          () {
            final Offset f = toFace(q);
            return at(f.dx, f.dy);
          }(),
      ]);
    }
    return out;
  }

  // The vessels.

  /// The superficial inferior epigastric artery and vein, cut across, each
  /// with its radius, in the scene.
  late final (Offset, double) epigastricArtery = _vessel(
    AdiposeAnatomy.epigastricArtery,
  );
  late final (Offset, double) epigastricVein = _vessel(
    AdiposeAnatomy.epigastricVein,
  );

  (Offset, double) _vessel((Offset, double) v) =>
      (at(v.$1.dx, v.$1.dy), mm(v.$2 / 2));

  /// The perforator's artery and vein, each its middle line from where it
  /// leaves the rectus to where it reaches the skin, in the scene.
  late final List<Offset> perforatorArtery = _perforator(-0.55, 0);
  late final List<Offset> perforatorVein = _perforator(0.55, 1.3);

  List<Offset> _perforator(double beside, double phase) {
    const double from = AdiposeAnatomy.perforatorFrom;
    const double to = AdiposeAnatomy.perforatorTo;
    final double bottom = rectusAt(from) + 3;
    final double top = skinAt(to) + 0.2;
    const int n = 60;
    return <Offset>[
      for (int i = 0; i <= n; i++)
        () {
          final double t = i / n;
          final double y = bottom + (top - bottom) * t;
          final double x =
              from +
              (to - from) * (t * t * (3 - 2 * t)) +
              beside * (1 - 0.6 * t) +
              0.5 * math.sin(t * 9 + phase);
          return at(x, y);
        }(),
    ];
  }

  // The surface.

  /// A point of the surface, [x] across and [z] back, in the scene.
  Offset onTop(double x, double z) => at(x, 0, z);

  /// Its furrows: two sets of lines crossing at different angles, each
  /// wandering a little, in the scene.
  late final List<List<Offset>> furrows = () {
    final math.Random random = math.Random(AdiposeStyle.seed + 3);
    final List<List<Offset>> out = <List<Offset>>[];
    for (final double angle in <double>[0.55, -0.4]) {
      final Offset way = Offset(math.cos(angle), math.sin(angle));
      final Offset normal = Offset(-way.dy, way.dx);
      const double reach = _w + _d;
      for (double s = -reach; s <= reach; s += AdiposeStyle.furrowSpacing) {
        final double offset =
            s + (random.nextDouble() - 0.5) * AdiposeStyle.furrowJitter;
        final List<Offset> line = <Offset>[];
        for (double t = -reach; t <= reach; t += 0.5) {
          final Offset p =
              const Offset(_w / 2, _d / 2) +
              normal * offset +
              way * t +
              normal * (0.12 * math.sin(t * 1.3 + offset));
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

  // The right side, a second cut.

  Path _sideBand(double from, double to) => _polygon(<Offset>[
    project(_w, from),
    project(_w, from, _d),
    project(_w, to, _d),
    project(_w, to),
  ]);

  /// Its layers, as bands from the front edge back, in the scene: the
  /// skin, the superficial fat, the membranous layer, the deep fat, the
  /// rectus sheath and the rectus.
  late final Path sideSkin = _sideBand(0, AdiposeAnatomy.skin);
  late final Path sideSuperficial = _sideBand(
    AdiposeAnatomy.skin,
    AdiposeAnatomy.superficialEnd,
  );
  late final Path sideMembranous = _sideBand(
    AdiposeAnatomy.superficialEnd,
    AdiposeAnatomy.membranousEnd,
  );
  late final Path sideDeep = _sideBand(
    AdiposeAnatomy.membranousEnd,
    AdiposeAnatomy.deepEnd,
  );
  late final Path sideSheath = _sideBand(
    AdiposeAnatomy.deepEnd,
    AdiposeAnatomy.deepEnd + AdiposeAnatomy.sheath,
  );
  late final Path sideRectus = _sideBand(
    AdiposeAnatomy.deepEnd + AdiposeAnatomy.sheath,
    _h,
  );

  // The place its tissue is sampled, and its names.

  /// In the superficial fat, low in it, a little left of the middle.
  late final Offset site = at(AdiposeAnatomy.site.dx, AdiposeAnatomy.site.dy);

  /// The points its names point at, in the scene, each column's spread
  /// down the block so that each name can stand level with its own: the
  /// fat at the site; a septum of the superficial fat left of the site,
  /// high in it; the deep fat under the site; the membranous layer right of
  /// the middle, left of the epigastric vessels (further right its name
  /// jolted 1.53 pixels a frame, stepping back out, over the 1.5 the zoom
  /// allows), and the rectus near the block's foot, each column's names
  /// spread as far apart as the block lets them.
  late final Offset fatName = site;
  late final Offset deepName = at(
    AdiposeAnatomy.site.dx - 4,
    (membranousAt(AdiposeAnatomy.site.dx - 4) +
            deepAt(AdiposeAnatomy.site.dx - 4)) /
        2,
  );
  late final Offset septumName = () {
    // The septum point nearest a place left of the site, high in the
    // superficial fat, on the edges of its lobes.
    final Offset wanted = at(6, AdiposeAnatomy.skin + 0.8);
    Offset best = superficialLobes.first.first;
    for (final List<Offset> lobe in superficialLobes) {
      for (int i = 0; i < lobe.length; i++) {
        final Offset a = lobe[i];
        final Offset b = lobe[(i + 1) % lobe.length];
        final Offset m = (a + b) / 2;
        final Offset mmM = toMm(m);
        if (mmM.dy < skinAt(mmM.dx) + 0.5 ||
            mmM.dy > superficialAt(mmM.dx) - 0.5) {
          continue;
        }
        if ((m - wanted).distance < (best - wanted).distance) {
          best = m;
        }
      }
    }
    return best;
  }();
  late final Offset membranousName = at(
    28,
    (superficialAt(28) + membranousAt(28)) / 2,
  );
  late final Offset rectusName = at(30, _h - 1);

  // Helpers.

  /// The polygon through [mm], points of the screen's millimetres, in the
  /// scene.
  Path _polygon(List<Offset> mm) =>
      Path()..addPolygon(<Offset>[for (final Offset p in mm) place(p)], true);
}

/// The [i]th of [middles]' cells: the ground nearer to it than to any
/// other, within [reach] of it, as the thyroid's lobules are cut.
List<Offset> _cell(List<Offset> middles, int i, double reach) {
  final Offset c = middles[i];
  List<Offset> poly = <Offset>[
    c + Offset(-reach, -reach),
    c + Offset(reach, -reach),
    c + Offset(reach, reach),
    c + Offset(-reach, reach),
  ];
  for (int j = 0; j < middles.length; j++) {
    final Offset d = middles[j] - c;
    if (j == i || d.distance > 2 * reach) {
      continue;
    }
    // Keep the side of the halfway line that holds c: p·d <= |d|²/2.
    final double limit = d.distanceSquared / 2;
    double side(Offset p) => (p - c).dx * d.dx + (p - c).dy * d.dy - limit;
    final List<Offset> out = <Offset>[];
    for (int k = 0; k < poly.length; k++) {
      final Offset a = poly[k];
      final Offset b = poly[(k + 1) % poly.length];
      final double sa = side(a);
      final double sb = side(b);
      if (sa <= 0) {
        out.add(a);
      }
      if ((sa < 0) != (sb < 0)) {
        out.add(Offset.lerp(a, b, sa / (sa - sb))!);
      }
    }
    poly = out;
    if (poly.length < 3) {
      return poly;
    }
  }
  return poly;
}
