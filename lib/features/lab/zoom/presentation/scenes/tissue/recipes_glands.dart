import 'dart:math' as math;
import 'dart:ui';

import '../contour.dart';
import 'slide_builder.dart';
import 'tissue_slide.dart';

/// The recipes for tissues built of glands: cells set round a lumen in
/// acini, ducts, tubules and follicles, or in plates and nests among
/// capillaries. Sizes are in micrometres and are the tissue's own.
extension GlandRecipes on SlideBuilder {
  /// Exocrine pancreas, or a serous salivary gland: acini packed edge to
  /// edge, each a ring of pyramidal cells round a pinpoint lumen, their
  /// bases purple with ribosomes, their apexes pink with granules, their
  /// nuclei low. The zoom's cell is one of a ring, its apex at the lumen.
  void acini() {
    _exocrine(home: Offset(0, targetBounds.top - 3));
    own(SlideInk.basophil, apex: SlideInk.eosin3, nucleus: SlideInk.nucleus2);
  }

  /// The exocrine tissue, with the lumen of one acinus at [home] where
  /// given. A cell whose nucleus [spare] passes is left out, and what the
  /// cells left out would have filled is returned: room for something laid
  /// among the acini, an islet or a duct, with the acini close about it.
  Path _exocrine({Offset? home, bool Function(Offset nucleus)? spare}) {
    const double pitch = 40;
    const double seat = 11;
    ellipse(
      ink(SlideInk.eosin0, TissueSlide.ground),
      Offset.zero,
      field + 4,
      field + 4,
    );
    final List<Offset> centres = lattice(
      pitch,
      jitter: 0.3,
      pin: home ?? Offset.zero,
      pinned: home != null,
    );
    final List<Offset> seeds = <Offset>[];
    final List<int> owner = <int>[];
    for (int i = 0; i < centres.length; i++) {
      final bool own = home != null && i == 0;
      final int n = own ? 8 : 7 + random.nextInt(3);
      // The zoom's cell is the one straight below its acinus's lumen.
      final double turn = own ? math.pi / 2 : between(0, 2 * math.pi);
      for (int k = 0; k < n; k++) {
        seeds.add(centres[i] + unit(turn + 2 * math.pi * k / n) * seat);
        owner.add(i);
      }
    }
    final List<List<Offset>> cells = voronoi(seeds, pitch * 1.15);
    final Path room = Path();
    final Set<int> laid = <int>{};
    for (int i = 0; i < cells.length; i++) {
      final Offset c = centres[owner[i]];
      if (!near(c, pitch) || cells[i].length < 3) {
        continue;
      }
      // The acinus drawn in about its own middle: a septum opens between
      // it and the next, and its cells stay side by side.
      final List<Offset> poly = <Offset>[
        for (final Offset p in cells[i]) c + (p - c) * 0.95,
      ];
      final Offset out = centroid(poly) - c;
      final double far = out.distance;
      if (far <= 0) {
        continue;
      }
      final Offset nucleusAt = c + out / far * math.min(far * 1.3, 14.5);
      if (spare != null && spare(nucleusAt)) {
        room.addPath(polygon(cells[i]), Offset.zero);
        continue;
      }
      if (!cell(
        poly,
        SlideInk.basophil,
        shrink: 0.97,
        corner: 0.18,
        nucleus: 2.9,
        nucleusAt: nucleusAt,
        nucleusInk: SlideInk.nucleus2,
      )) {
        continue;
      }
      laid.add(owner[i]);
      // Where acini meet: a capillary, or a fibroblast.
      Offset corner = cells[i].first;
      for (final Offset p in cells[i]) {
        if ((p - c).distance > (corner - c).distance) {
          corner = p;
        }
      }
      if (room.contains(corner) || (spare != null && spare(corner))) {
        continue;
      }
      if (chance(0.06)) {
        red(corner, r: 3);
      } else if (chance(0.06)) {
        nucleus(
          corner,
          3.4,
          across: 1.1,
          turn: between(0, math.pi),
          ink: SlideInk.nucleus2,
        );
      }
    }
    // Each acinus's granules, round its lumen: one zone over its cells'
    // apexes, their borders showing through it.
    for (final int i in laid) {
      final double reach = between(10, 12);
      ellipse(ink(SlideInk.granules), centres[i], reach, reach * 0.96);
      if (spare == null || !spare(centres[i])) {
        ellipse(ink(SlideInk.clear, TissueSlide.over), centres[i], 2.6, 2.4);
      }
    }
    return room;
  }

  /// An islet of Langerhans in the exocrine pancreas: a nest of pale
  /// endocrine cells in cords among capillaries, the acini close about it.
  /// The zoom's cell is one of the islet's.
  void islet() {
    const Offset centre = Offset(10, -7);
    const double r = 70;
    final Path room = _exocrine(
      spare: (Offset nucleus) => (nucleus - centre).distance < r,
    );
    ink(SlideInk.eosin0, TissueSlide.over).addPath(room, Offset.zero);
    for (int k = 0; k < 4; k++) {
      final double a = 0.7 + k * 1.57 + between(-0.2, 0.2);
      capillary(
        smooth(<Offset>[
          centre + unit(a) * (r * 0.84),
          centre + unit(a + 1.1) * (r * between(0.44, 0.7)),
          centre + unit(a + 2.2) * (r * 0.52),
        ]),
        5.5,
        layer: TissueSlide.over,
      );
    }
    final List<Offset> seeds = relaxed(
      lattice(
        11.5,
        jitter: 0.5,
        pinned: true,
        where: (Offset p) => (p - centre).distance < r + 44,
      ),
      26,
      fixed: 1,
    );
    for (final List<Offset> poly in voronoi(seeds, 26)) {
      if (poly.length < 3 || !room.contains(centroid(poly))) {
        continue;
      }
      cell(
        poly,
        chance(0.7) ? SlideInk.eosin1 : SlideInk.eosin0,
        layer: TissueSlide.over,
        shrink: 0.93,
        corner: 0.2,
      );
    }
    own(SlideInk.eosin1);
  }

  /// A duct among the acini: cuboidal cells in a ring round an open lumen,
  /// in a sheath of connective tissue. The zoom's cell is one of the ring.
  void ducts() {
    const double lumen = 13;
    const double sheath = 13;
    final double tall = targetBounds.height.clamp(9.0, 20.0);
    final double seat = lumen + tall / 2;
    final double outer = lumen + tall;
    final Offset centre = Offset(0, -seat);
    // The sheath takes the room the acini leave about the duct.
    ink(SlideInk.eosin1, TissueSlide.ground).addPath(
      _exocrine(
        spare: (Offset nucleus) => (nucleus - centre).distance < outer + sheath,
      ),
      Offset.zero,
    );
    for (int k = 0; k < 9; k++) {
      final double from = between(0, 2 * math.pi);
      final double at = outer + between(2.5, sheath - 2.5);
      fibre(<Offset>[
        for (int i = 0; i <= 8; i++)
          centre + unit(from + i * 0.13) * (at + math.sin(i * 1.3 + k) * 0.7),
      ], layer: TissueSlide.ground);
    }
    for (int k = 0; k < 10; k++) {
      final double a = between(0, 2 * math.pi);
      nucleus(
        centre + unit(a) * (outer + between(3, sheath - 3)),
        3.8,
        across: 1.15,
        turn: a + math.pi / 2,
        ink: SlideInk.nucleus2,
        layer: TissueSlide.ground,
      );
    }
    ring(
      centre,
      lumen: lumen,
      outer: outer,
      count: (2 * math.pi * seat / targetBounds.width.clamp(9.0, 16.0)).round(),
      turn: math.pi / 2,
      look: (int _) => (SlideInk.eosin0, 0.5, SlideInk.nucleus1),
      layer: TissueSlide.over,
      nucleus: 3.1,
    );
    own(SlideInk.eosin0);
  }

  /// A liver lobule about its central vein: plates of hepatocytes one or
  /// two cells thick running out from the vein and branching as they go,
  /// sinusoids between them with their lining cells and red cells. The
  /// zoom's cell is one of a plate's.
  void liver() {
    const double long = 24;
    const double gap = 6.5;
    const double vein = 32;
    const double widest = 33;
    const double away = vein + 4 + 4.5 * long;
    final Offset v = const Offset(-0.815, -0.58) * away;
    final double reach = away + field + 30;

    // The sinusoids: lines out from the vein, a new one opening in the
    // middle of a plate once the plate has grown two cells wide.
    final List<_Plate> plates = <_Plate>[];
    void grow(double a0, double a1, double from) {
      final double span = a1 - a0;
      final double to = math.max(from, math.min(reach, between(64, 76) / span));
      plates.add(_Plate(a0, a1, from, to));
      if (to < reach) {
        final double mid = a0 + span * between(0.44, 0.56);
        grow(a0, mid, to);
        grow(mid, a1, to);
      }
    }

    const int first = 6;
    final List<double> cuts = <double>[
      for (int i = 0; i < first; i++)
        2 * math.pi * (i + between(-0.15, 0.15)) / first,
    ];
    for (int i = 0; i < first; i++) {
      grow(
        cuts[i],
        i + 1 < first ? cuts[i + 1] : cuts[0] + 2 * math.pi,
        vein + 4,
      );
    }

    // Where a plate becomes two cells thick.
    double pairsFrom(_Plate p) => ((40 + gap) / p.span).clamp(p.from, p.to);
    (double, double) single(_Plate p, double rho) {
      final double half = math.min(widest, p.span * rho - gap) / (2 * rho);
      return (p.mid - half, p.mid + half);
    }

    (double, double) left(_Plate p, double rho) =>
        (p.a0 + gap / (2 * rho), p.mid);
    (double, double) right(_Plate p, double rho) =>
        (p.mid, p.a1 - gap / (2 * rho));

    // The plate the zoom's cell is in: the whole lobule is turned so that
    // one of its files runs through the origin.
    _Plate home = plates.first;
    bool paired = false;
    bool found = false;
    for (final _Plate p in plates) {
      final double two = pairsFrom(p);
      if (p.from + 14 <= away && away <= two - 14) {
        home = p;
        paired = false;
        found = true;
        break;
      }
      if (two + 14 <= away && away <= p.to - 14) {
        home = p;
        paired = true;
        found = true;
        break;
      }
    }
    if (!found) {
      for (final _Plate p in plates) {
        if (p.from <= away && away < p.to) {
          home = p;
          paired = away >= pairsFrom(p);
          break;
        }
      }
    }
    final (double low, double high) = paired
        ? left(home, away)
        : single(home, away);
    final double turn = math.atan2(-v.dy, -v.dx) - (low + high) / 2;
    Offset place(double rho, double angle) => v + unit(angle + turn) * rho;

    List<double> divide(double a, double b) {
      final int n = ((b - a) / long).round();
      if (n <= 0) {
        return <double>[b];
      }
      final double step = (b - a) / n;
      return <double>[
        a,
        for (int i = 1; i < n; i++) a + step * (i + between(-0.12, 0.12)),
        b,
      ];
    }

    void file(
      _Plate p,
      (double, double) Function(_Plate, double) bounds,
      double a,
      double b,
      double? cellAt,
    ) {
      final List<double> at;
      if (cellAt == null) {
        at = divide(a, b);
      } else {
        final List<double> above = divide(cellAt + long / 2, b);
        at = <double>[
          ...divide(a, cellAt - long / 2),
          if (above.first != cellAt + long / 2) cellAt + long / 2,
          ...above,
        ];
      }
      for (int i = 0; i + 1 < at.length; i++) {
        final (double l0, double h0) = bounds(p, at[i]);
        final (double l1, double h1) = bounds(p, at[i + 1]);
        final List<Offset> poly = <Offset>[
          place(at[i], l0),
          place(at[i], h0),
          place(at[i + 1], h1),
          place(at[i + 1], l1),
        ];
        // One hepatocyte in eight has two nuclei.
        final bool twin = chance(0.12);
        if (!cell(
          poly,
          chance(0.5) ? SlideInk.eosin1 : SlideInk.eosin2,
          shrink: 0.95,
          corner: 0.22,
          nucleus: twin ? 0 : 4.3,
          nucleolus: true,
        )) {
          continue;
        }
        if (twin) {
          final Offset c = centroid(poly);
          final Offset apart = unit(between(0, math.pi)) * 4.4;
          nucleus(c + apart, 3.9, nucleolus: true);
          nucleus(c - apart, 3.9, nucleolus: true);
        }
      }
    }

    for (final _Plate p in plates) {
      final double two = pairsFrom(p);
      final bool mine = identical(p, home);
      if (two - p.from > 1) {
        file(p, single, p.from, two, mine && !paired ? away : null);
      }
      if (p.to - two > 1) {
        file(p, left, two, p.to, mine && paired ? away : null);
        file(p, right, two, p.to, null);
      }
      // The sinusoid along the plate's edge: a lining cell's nucleus, or a
      // red cell, every so often.
      for (
        double rho = p.from + between(6, 30);
        rho < p.to;
        rho += between(24, 58)
      ) {
        final Offset at = place(rho, p.a0);
        if (!free(at, 3)) {
          continue;
        }
        if (chance(0.5)) {
          nucleus(
            at + unit(p.a0 + turn + math.pi / 2) * between(-2, 2),
            4.6,
            across: 1.3,
            turn: p.a0 + turn,
            ink: SlideInk.nucleus2,
          );
        } else {
          red(at, r: 3.1);
        }
      }
    }

    // The central vein.
    keep(v, vein);
    ink(SlideInk.clear).addPath(
      Contour.blob(v, vein, vein * 0.93, wobble: 0.05, seed: 5).toPath(),
      Offset.zero,
    );
    for (int k = 0; k < 6; k++) {
      final double a = k * 1.05 + between(-0.2, 0.2);
      nucleus(
        v +
            Offset(
              math.cos(a) * (vein + 0.5),
              math.sin(a) * (vein * 0.93 + 0.5),
            ),
        4.4,
        across: 1.2,
        turn: a + math.pi / 2,
        ink: SlideInk.nucleus2,
      );
    }
    for (int k = 0; k < 8; k++) {
      red(v + unit(between(0.2, 1.9)) * between(4, vein - 6));
    }
    own(SlideInk.eosin1, nucleolus: true);
  }

  /// An endocrine gland such as the anterior pituitary: nests of cells that
  /// take the stains three ways (deep pink acidophils, purple basophils,
  /// pale chromophobes) with sinusoids between the nests. The zoom's cell
  /// is one of a nest's.
  void cords() {
    const double step = 12.5;
    const double nest = 58;
    final List<Offset> nests = lattice(nest, jitter: 0.6, pinned: true);
    // The nearest nest to a point and the next nearest, with how far each
    // is.
    (int, double, int, double) nearestTwo(Offset p) {
      int a = 0;
      int b = 0;
      double da = double.infinity;
      double db = double.infinity;
      for (int i = 0; i < nests.length; i++) {
        final double d = (nests[i] - p).distance;
        if (d < da) {
          b = a;
          db = da;
          a = i;
          da = d;
        } else if (d < db) {
          b = i;
          db = d;
        }
      }
      return (a, da, b, db);
    }

    final List<Offset> seeds = relaxed(
      lattice(step, jitter: 0.6, pinned: true),
      28,
      fixed: 1,
    );
    for (final List<Offset> poly in voronoi(seeds, 28)) {
      if (poly.length < 3) {
        continue;
      }
      final Offset c = centroid(poly);
      if (!near(c, 20)) {
        continue;
      }
      // A nest drawn in about its own middle: a sinusoid opens between it
      // and the next.
      final Offset home = nests[nearestTwo(c).$1];
      final double kind = 0.55 * roll + 0.45 * noise(c, 60);
      cell(
        <Offset>[for (final Offset p in poly) home + (p - home) * 0.9],
        kind < 0.45
            ? SlideInk.eosin3
            : kind < 0.53
            ? SlideInk.basophil
            : chance(0.5)
            ? SlideInk.eosin0
            : SlideInk.eosin1,
        shrink: 0.985,
        corner: 0.15,
        nucleus: 3.1,
        nucleusInk: chance(0.3) ? SlideInk.nucleus2 : SlideInk.nucleus1,
      );
    }
    // In the sinusoids: red cells and the nuclei of their lining.
    for (int k = 0; k < 520; k++) {
      final Offset p = anywhere();
      final (int a, double da, int b, double db) = nearestTwo(p);
      if (db - da > 0.07 * (da + db) || !free(p, 3)) {
        continue;
      }
      if (chance(0.55)) {
        red(p, r: 2.9);
      } else {
        nucleus(
          p,
          4.4,
          across: 1.2,
          turn: (nests[b] - nests[a]).direction + math.pi / 2,
          ink: SlideInk.nucleus2,
        );
      }
    }
    own(SlideInk.eosin3);
  }

  /// Thyroid: follicles of every size packed together, each a lake of pink
  /// colloid walled by one layer of cuboidal cells, capillaries in the thin
  /// stroma between. The zoom's cell is one of a follicle's wall.
  void follicles() {
    const double pitch = 96;
    const double homeR = 38;
    final double tall = targetBounds.height.clamp(8.0, 16.0);
    final double wide = targetBounds.width.clamp(8.0, 16.0);
    ellipse(
      ink(SlideInk.eosin0, TissueSlide.ground),
      Offset.zero,
      field + 4,
      field + 4,
    );
    // The zoom's cell stands on the floor of its follicle.
    final Offset foot = Offset(0, targetBounds.bottom);
    final List<Offset> centres = lattice(
      pitch,
      jitter: 0.35,
      pin: foot - const Offset(0, homeR * 0.94),
      pinned: true,
    );
    final List<List<Offset>> rooms = voronoi(centres, pitch * 2.2);
    for (int i = 0; i < centres.length; i++) {
      if (!near(centres[i], pitch) || rooms[i].length < 3) {
        continue;
      }
      final List<Offset> wall;
      double? anchor;
      if (i == 0) {
        final Contour blob = Contour.blob(
          Offset.zero,
          homeR,
          homeR * 0.94,
          count: 120,
          wobble: 0.03,
          seed: 4,
        );
        final Offset lowest = blob.points[60];
        wall = <Offset>[for (final Offset p in blob.points) p + foot - lowest];
      } else {
        wall = roundedPoints(rooms[i], shrink: 0.9, corner: 0.45);
      }
      final Trail trail = Trail(wall, closed: true);
      if (i == 0) {
        anchor = trail.lengthTo(60);
      }
      ink(SlideInk.lamp).addPath(polygon(wall), Offset.zero);
      final Lining lining = epithelium(
        trail,
        width: wide * 0.92,
        height: tall,
        fill: (int _) => SlideInk.eosin1,
        nucleus: 3,
        anchor: anchor,
        anchorWidth: wide,
        corner: 0.15,
      );
      // The colloid, drawn back a little from the cells as it shrinks in
      // the making of a slide.
      ink(
        chance(0.5) ? SlideInk.eosin2 : SlideInk.eosin3,
      ).addPath(rounded(lining.inner, shrink: 0.95, corner: 0.5), Offset.zero);
      for (final Offset corner in rooms[i]) {
        if (chance(0.1) && free(corner, 3)) {
          red(corner, r: 3.1);
        }
      }
    }
    own(SlideInk.eosin1);
  }

  /// A stomach's glands cut across, or with [kidney] a kidney's tubules:
  /// rings of cells round small lumens, close together in a little stroma.
  /// The stomach's rings mix deep pink parietal cells, purple chief cells
  /// and pale mucous cells; the kidney's are pink proximal tubules with
  /// fuzzy lumens and paler distal ones with open lumens, about a
  /// glomerulus. The zoom's cell is one of a ring.
  void glands({required bool kidney}) {
    final double wall = kidney ? 16 : 20;
    final double lumen = kidney ? 12 : 6;
    final double outer = lumen + wall;
    final double seat = lumen + wall / 2;
    final double pitch = 2 * outer + 7;
    final int homeCount = kidney ? 7 : 8;
    ellipse(
      ink(SlideInk.eosin0, TissueSlide.ground),
      Offset.zero,
      field + 4,
      field + 4,
    );
    final List<Offset> centres = lattice(
      pitch,
      jitter: 0.2,
      pin: Offset(0, -seat),
      pinned: true,
    );
    Offset? tuft;
    const double tuftRadius = 88;
    if (kidney) {
      tuft = centres.reduce(
        (Offset a, Offset b) =>
            (a - const Offset(126, 104)).distance <
                (b - const Offset(126, 104)).distance
            ? a
            : b,
      );
      keep(tuft, tuftRadius + 6);
    }
    final List<Offset> laid = <Offset>[];
    for (int i = 0; i < centres.length; i++) {
      final Offset c = centres[i];
      if (!near(c, outer + 6) ||
          (tuft != null && (c - tuft).distance < tuftRadius + outer)) {
        continue;
      }
      laid.add(c);
      final bool own = i == 0;
      // A distal tubule: paler, more cells, its lumen open.
      final bool distal = kidney && !own && chance(0.3);
      final int count = own
          ? homeCount
          : (homeCount + (distal ? 2 : 0) + random.nextInt(3) - 1).clamp(5, 13);
      ring(
        c,
        lumen: lumen * (distal ? 1.15 : 1),
        outer: outer * (own ? 1 : between(0.94, 1.05)),
        count: count,
        turn: own ? math.pi / 2 : between(0, 2 * math.pi),
        look: (int _) {
          if (kidney) {
            return distal
                ? (SlideInk.eosin1, 0.55, SlideInk.nucleus1)
                : (SlideInk.eosin3, 0.6, SlideInk.nucleus1);
          }
          final double kind = roll;
          return kind < 0.35
              ? (SlideInk.eosin3, 0.5, SlideInk.nucleus1)
              : kind < 0.75
              ? (SlideInk.basophil, 0.72, SlideInk.nucleus2)
              : (SlideInk.eosin1, 0.78, SlideInk.nucleus2);
        },
        open: !kidney || distal,
      );
      if (kidney && !distal) {
        // A proximal tubule's brush border fills most of its lumen.
        ellipse(ink(SlideInk.eosin1), c, lumen * 1.04, lumen * 1.04);
        ellipse(ink(SlideInk.clear), c, lumen * 0.42, lumen * 0.36);
      }
    }
    // Between the rings: small round cells, spindle cells, capillaries.
    for (int k = 0; k < 700; k++) {
      final Offset p = anywhere();
      if (!free(p, 3) ||
          laid.any((Offset c) => (p - c).distance < outer * 1.06 + 2.5)) {
        continue;
      }
      final double kind = roll;
      if (kind < 0.25) {
        red(p, r: 3);
      } else if (kind < 0.6 && !kidney) {
        nucleus(p, 2.4, ink: SlideInk.nucleus2);
      } else {
        nucleus(
          p,
          3.8,
          across: 1.2,
          turn: between(0, math.pi),
          ink: SlideInk.nucleus2,
        );
      }
    }
    if (tuft != null) {
      _glomerulus(tuft, tuftRadius);
    }
    own(
      kidney ? SlideInk.eosin3 : SlideInk.eosin1,
      nucleus: kidney ? SlideInk.nucleus1 : SlideInk.nucleus2,
    );
  }

  /// A glomerulus at [c]: a tuft of capillary loops, crowded with nuclei,
  /// in the clear space of its capsule.
  void _glomerulus(Offset c, double r) {
    const int over = TissueSlide.over;
    final Contour capsule = Contour.blob(c, r, r * 0.95, wobble: 0.03, seed: 8);
    ink(SlideInk.clear, over).addPath(capsule.toPath(), Offset.zero);
    for (int k = 0; k < 9; k++) {
      final double a = k * 0.7 + between(-0.15, 0.15);
      nucleus(
        c + Offset(math.cos(a) * (r + 0.6), math.sin(a) * (r * 0.95 + 0.6)),
        4.2,
        across: 1.1,
        turn: a + math.pi / 2,
        ink: SlideInk.nucleus2,
        layer: over,
      );
    }
    // The tuft is laid a layer up, so that its pink lies over the space.
    final SlideLayer top = slide.layers[TissueSlide.top];
    final double inner = r * 0.8;
    top
        .of(SlideInk.eosin1)
        .addPath(
          Contour.blob(c, inner, inner * 0.94, wobble: 0.14, seed: 9).toPath(),
          Offset.zero,
        );
    for (int k = 0; k < 26; k++) {
      final Offset p =
          c + unit(between(0, 2 * math.pi)) * (inner * 0.82 * math.sqrt(roll));
      final double loop = between(3.6, 6.4);
      ellipse(
        top.of(SlideInk.clear),
        p,
        loop,
        loop * between(0.7, 0.95),
        between(0, math.pi),
      );
      if (chance(0.7)) {
        ellipse(
          top.of(SlideInk.blood),
          p + unit(between(0, 6)) * 1.2,
          2.6,
          2.4,
        );
      }
    }
    for (int k = 0; k < 85; k++) {
      final Offset p =
          c + unit(between(0, 2 * math.pi)) * (inner * 0.9 * math.sqrt(roll));
      ellipse(
        top.of(chance(0.6) ? SlideInk.nucleus2 : SlideInk.nucleus1),
        p,
        2.7,
        2.4,
      );
    }
  }

  /// Seminiferous tubules cut across: in each wall, from the outside in,
  /// spermatogonia and Sertoli cells on the basement membrane, the large
  /// nuclei of primary spermatocytes, round spermatids, and the small dark
  /// heads of the elongating ones at the lumen, their tails in it; Leydig
  /// cells and capillaries between the tubules. The zoom's cell is in a
  /// wall, among the spermatocytes.
  void tubules() {
    const double r = 96;
    ellipse(
      ink(SlideInk.eosin0, TissueSlide.ground),
      Offset.zero,
      field + 4,
      field + 4,
    );
    final List<Offset> centres = lattice(
      2.14 * r,
      jitter: 0.1,
      pin: const Offset(0, -0.63 * r),
      pinned: true,
    );
    for (int i = 0; i < centres.length; i++) {
      final Offset c = centres[i];
      if (!near(c, r)) {
        continue;
      }
      final double rx = r * (i == 0 ? 1 : between(0.93, 1.04));
      final double ry = r * (i == 0 ? 1 : between(0.9, 1.02));
      final Path wall = Contour.blob(
        c,
        rx,
        ry,
        wobble: 0.03,
        seed: 20 + i,
      ).toPath();
      ink(SlideInk.eosin1).addPath(wall, Offset.zero);
      ink(SlideInk.border).addPath(wall, Offset.zero);
      Offset at(double a, double share) =>
          c + Offset(math.cos(a) * rx * share, math.sin(a) * ry * share);
      // One layer of the wall: nuclei [apart] along a circle at [share]
      // of the way out, [filled] of the places taken.
      void layerOf(
        double share,
        double apart,
        double filled,
        void Function(Offset p, double a) lay,
      ) {
        final int n = (2 * math.pi * r * share / apart).round();
        final double start = between(0, 2 * math.pi);
        for (int k = 0; k < n; k++) {
          if (!chance(filled)) {
            continue;
          }
          final double a = start + 2 * math.pi * (k + between(-0.25, 0.25)) / n;
          lay(at(a, share + between(-0.016, 0.016)), a);
        }
      }

      // Myoid cells flat on the tubule's outside.
      layerOf(1.015, 34, 0.6, (Offset p, double a) {
        nucleus(
          p,
          4.2,
          across: 1.1,
          turn: a + math.pi / 2,
          ink: SlideInk.nucleus2,
        );
      });
      // Spermatogonia, dark, and the pale nuclei of Sertoli cells.
      layerOf(0.925, 15, 0.9, (Offset p, double a) {
        if (chance(0.68)) {
          nucleus(
            p,
            3.5,
            across: 3,
            turn: a + math.pi / 2,
            ink: SlideInk.nucleus2,
          );
        } else {
          nucleus(
            p - unit(a) * 2,
            3.9,
            across: 3.3,
            turn: a,
            ink: SlideInk.nucleus0,
            nucleolus: true,
          );
        }
      });
      // Primary spermatocytes, the largest nuclei of the wall.
      for (final double share in <double>[0.775, 0.635]) {
        layerOf(share, 15.5, 0.86, (Offset p, double _) {
          nucleus(p, 4.7);
        });
      }
      // Round spermatids.
      for (final double share in <double>[0.515, 0.44]) {
        layerOf(share, 9, 0.8, (Offset p, double _) {
          nucleus(
            p,
            2.5,
            ink: chance(0.5) ? SlideInk.nucleus1 : SlideInk.nucleus0,
          );
        });
      }
      // Elongating spermatids: heads toward the wall, tails in the lumen.
      layerOf(0.355, 6.5, 0.55, (Offset p, double a) {
        nucleus(
          p,
          2.7,
          across: 0.85,
          turn: a,
          ink: SlideInk.nucleus2,
          layer: TissueSlide.over,
        );
        fibre(<Offset>[
          p,
          at(a + between(-0.1, 0.1), between(0.14, 0.24)),
        ], layer: TissueSlide.over);
      });
      ink(SlideInk.clear).addPath(
        Contour.blob(
          c,
          rx * 0.27,
          ry * 0.27,
          wobble: 0.16,
          seed: 60 + i,
        ).toPath(),
        Offset.zero,
      );
    }
    // Between the tubules: Leydig cells in clusters, capillaries, and
    // fibroblasts.
    bool between3(Offset p, double margin) =>
        centres.every((Offset c) => (p - c).distance > r * 1.06 + margin);
    int clusters = 0;
    int vessels = 0;
    for (int k = 0; k < 900; k++) {
      final Offset p = anywhere();
      if (!free(p, 4)) {
        continue;
      }
      if (clusters < 9 && between3(p, 12) && !kept(p, 16)) {
        clusters++;
        final int cells = 3 + random.nextInt(4);
        for (int m = 0; m < cells; m++) {
          final Offset q = p + unit(m * 2.4 + between(0, 0.6)) * between(3, 10);
          if (!between3(q, 5)) {
            continue;
          }
          final double size = between(5.8, 7.4);
          final Path body = Contour.blob(
            q,
            size,
            size * 0.9,
            count: 24,
            wobble: 0.08,
            seed: k + m,
          ).toPath();
          ink(SlideInk.eosin3, TissueSlide.ground).addPath(body, Offset.zero);
          ink(SlideInk.border, TissueSlide.ground).addPath(body, Offset.zero);
          nucleus(q, 2.8, layer: TissueSlide.ground);
        }
        keep(p, 16);
      } else if (vessels < 6 && between3(p, 9) && !kept(p, 10)) {
        vessels++;
        vessel(p, between(4.5, 7), layer: TissueSlide.ground);
      } else if (between3(p, 3) && !kept(p, 4) && chance(0.12)) {
        nucleus(
          p,
          4,
          across: 1.2,
          turn: between(0, math.pi),
          ink: SlideInk.nucleus2,
          layer: TissueSlide.ground,
        );
      }
    }
    own(SlideInk.eosin1);
  }
}

/// A plate of the liver between two sinusoids: the angles of its edges
/// about the central vein, and how far from the vein it runs before a new
/// sinusoid divides it.
final class _Plate {
  const _Plate(this.a0, this.a1, this.from, this.to);

  final double a0;
  final double a1;
  final double from;
  final double to;

  double get span => a1 - a0;
  double get mid => (a0 + a1) / 2;
}
