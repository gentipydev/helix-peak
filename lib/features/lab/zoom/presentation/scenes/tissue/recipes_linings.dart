import 'dart:math' as math;
import 'dart:ui';

import '../contour.dart';
import 'slide_builder.dart';
import 'tissue_slide.dart';

/// The recipes for tissues that are a lining over something: an epithelium
/// on fronds or folds, in layers, or as the walls of air spaces; the wall of
/// a sinus or of a vessel. Sizes are in micrometres and are the tissue's own.
extension LiningRecipes on SlideBuilder {
  /// Choroid plexus: fronds cut every way, each a core of loose tissue and
  /// wide capillaries wrapped in one layer of cuboidal cells, floating in
  /// the clear of the ventricle. With [placenta], chorionic villi instead: a
  /// thin dark trophoblast round each core, the mother's blood between
  /// them. The zoom's cell is on the top of one.
  void fronds({required bool placenta}) {
    final double tall =
        targetBounds.height.clamp(8.0, 22.0) * (placenta ? 0.45 : 1);
    final double wide =
        targetBounds.width.clamp(8.0, 30.0) * (placenta ? 0.4 : 0.92);
    final SlideInk skin = placenta ? SlideInk.basophil : SlideInk.eosin2;
    final List<List<Offset>> outlines = <List<Offset>>[];
    final List<(Offset, double, double)> rooms = <(Offset, double, double)>[];
    // The frond the zoom's cell is on: broad, its top where the cell's apex
    // is.
    final Contour first = Contour.blob(
      Offset.zero,
      80,
      46,
      count: 120,
      wobble: 0.05,
      seed: 2,
    );
    final Offset shift =
        Offset(0, targetBounds.top + (placenta ? 3 : 0)) - first.points.first;
    outlines.add(<Offset>[for (final Offset p in first.points) p + shift]);
    rooms.add((shift, 80 * 1.08, 46 * 1.08));
    for (int tries = 0; tries < 5000 && outlines.length < 34; tries++) {
      final Offset c = anywhere(field + 40);
      // The big ones first, the small in what room they leave.
      final double size = tries < 600 ? 1 : 0.72;
      final double rx = between(34, 74) * size;
      final double ry = between(26, 46) * size;
      final bool clear = rooms.every(((Offset, double, double) room) {
        final Offset d = c - room.$1;
        final double x = d.dx / (rx * 1.1 + room.$2 + 5);
        final double y = d.dy / (ry * 1.1 + room.$3 + 5);
        return x * x + y * y >= 1;
      });
      if (!clear) {
        continue;
      }
      rooms.add((c, rx * 1.1, ry * 1.1));
      outlines.add(
        Contour.blob(c, rx, ry, wobble: 0.11, seed: 30 + tries).points,
      );
    }
    final List<Path> bodies = <Path>[];
    for (int i = 0; i < outlines.length; i++) {
      final Lining lining = epithelium(
        Trail(outlines[i], closed: true),
        width: wide,
        height: tall,
        fill: (int _) => skin,
        nucleus: placenta ? 2.6 : 3,
        nucleusAt: placenta ? 0.5 : 0.55,
        nucleusInk: placenta ? SlideInk.nucleus2 : SlideInk.nucleus1,
        anchor: i == 0 ? 0 : null,
        anchorWidth: i == 0 ? targetBounds.width : 0,
        corner: 0.18,
      );
      final Path core = polygon(lining.inner);
      ink(SlideInk.eosin0).addPath(core, Offset.zero);
      bodies.add(polygon(outlines[i]));
      stroma(
        core,
        nuclei: 2 + random.nextInt(4),
        fibres: 3,
        vessels: placenta ? 3 : 2,
        sway: 1.5,
        layer: TissueSlide.tissue,
      );
    }
    if (placenta) {
      // The mother's blood, between the villi.
      for (int k = 0; k < 420; k++) {
        final Offset p = anywhere();
        if (bodies.every((Path body) => !body.contains(p)) && !onTarget(p, 4)) {
          red(p, layer: TissueSlide.ground);
        }
      }
    }
    own(skin, nucleus: placenta ? SlideInk.nucleus2 : SlideInk.nucleus1);
  }

  /// A mucosa thrown into folds, as a fallopian tube's is: tall columnar
  /// cells, ciliated, along every fold's surface, a core of loose tissue
  /// and small vessels in each, and the muscle of the wall below. With
  /// [villi], an intestine's instead: the folds are villi, goblet cells
  /// among their absorbing cells, crypts at their feet. The zoom's cell is
  /// on a fold, its apex to the lumen.
  void folds({required bool villi}) {
    final double tall = targetBounds.height.clamp(10.0, 26.0);
    final double wide = targetBounds.width.clamp(6.0, 14.0);
    final double homeRise = villi ? 168 : 80;
    final double floor = targetBounds.top + homeRise;
    // Each fold: where it stands, half its width, and how far it rises.
    final List<(double, double, double)> rises = <(double, double, double)>[
      if (villi)
        for (final double x in <double>[-330, -220, -110])
          (x + between(-7, 7), between(31, 36), between(190, 262))
      else
        for (final double x in <double>[-262, -150])
          (x + between(-9, 9), between(27, 36), between(128, 225)),
      (0, villi ? 34 : 58, homeRise),
      if (villi)
        for (final double x in <double>[110, 220, 330])
          (x + between(-7, 7), between(31, 36), between(190, 262))
      else
        for (final double x in <double>[148, 258])
          (x + between(-9, 9), between(27, 36), between(128, 225)),
    ];
    // The surface, from left to right: the floor, and each fold a finger
    // with a round top.
    const double fillet = 8;
    final List<Offset> surface = <Offset>[Offset(-field - 200, floor)];
    void run(Offset to) {
      final Offset from = surface.last;
      final int n = math.max(1, ((to - from).distance / 4).round());
      for (int i = 1; i <= n; i++) {
        surface.add(Offset.lerp(from, to, i / n)!);
      }
    }

    void arc(Offset centre, double radius, double from, double to) {
      final int n = math.max(4, ((to - from).abs() * radius / 1.2).round());
      for (int i = 1; i <= n; i++) {
        surface.add(centre + unit(from + (to - from) * i / n) * radius);
      }
    }

    for (final (double c, double w, double h) in rises) {
      run(Offset(c - w - fillet, floor));
      arc(Offset(c - w - fillet, floor - fillet), fillet, math.pi / 2, 0);
      run(Offset(c - w, floor - h + w));
      arc(Offset(c, floor - h + w), w, math.pi, 2 * math.pi);
      run(Offset(c + w, floor - fillet));
      arc(Offset(c + w + fillet, floor - fillet), fillet, math.pi, math.pi / 2);
    }
    run(Offset(field + 200, floor));
    // The zoom's cell stands where the surface passes its apex.
    final Offset apex = Offset(0, targetBounds.top);
    int anchor = 0;
    for (int i = 1; i < surface.length; i++) {
      if ((surface[i] - apex).distance < (surface[anchor] - apex).distance) {
        anchor = i;
      }
    }
    final Trail trail = Trail(surface);
    final Lining lining = epithelium(
      trail,
      width: wide,
      height: tall,
      fill: (int _) => SlideInk.eosin2,
      nucleus: 2.5,
      nucleusLong: 1.45,
      nucleusAt: 0.62,
      cilia: villi ? 1.3 : 3,
      anchor: trail.lengthTo(anchor),
      anchorWidth: targetBounds.width,
      corner: 0.15,
    );
    if (!villi) {
      // Folds cut across lie free in the lumen, each round its own core.
      final Path mucosa = polygon(<Offset>[
        ...surface,
        Offset(field + 220, field + 80),
        Offset(-field - 220, field + 80),
      ]);
      final List<(Offset, double, double)> rooms = <(Offset, double, double)>[];
      for (int tries = 0; tries < 2500 && rooms.length < 14; tries++) {
        final Offset c = anywhere(field + 20);
        final double rx = between(tall + 12, tall + 40);
        final double ry = between(tall + 7, tall + 20);
        final bool clear =
            !onTarget(c, rx + 14) &&
            !Contour.blob(
              c,
              rx + 9,
              ry + 9,
              count: 40,
              wobble: 0.1,
              seed: 80 + tries,
            ).points.any(mucosa.contains) &&
            rooms.every(((Offset, double, double) room) {
              final Offset d = c - room.$1;
              final double x = d.dx / (rx * 1.1 + room.$2 + 7);
              final double y = d.dy / (ry * 1.1 + room.$3 + 7);
              return x * x + y * y >= 1;
            });
        if (!clear) {
          continue;
        }
        rooms.add((c, rx * 1.1, ry * 1.1));
        final Lining island = epithelium(
          Trail(
            Contour.blob(c, rx, ry, wobble: 0.1, seed: 80 + tries).points,
            closed: true,
          ),
          width: wide,
          height: tall,
          fill: (int _) => SlideInk.eosin2,
          nucleus: 2.5,
          nucleusLong: 1.45,
          nucleusAt: 0.62,
          cilia: 3,
          corner: 0.15,
        );
        final Path core = polygon(island.inner);
        ink(SlideInk.eosin0).addPath(core, Offset.zero);
        stroma(
          core,
          nuclei: 3,
          fibres: 2,
          vessels: 1,
          sway: 1.5,
          layer: TissueSlide.tissue,
        );
      }
    }
    if (villi) {
      // Goblet cells: a drop of mucus, unstained, in the cell's apex.
      for (final (Offset at, Offset inward) in lining.cells) {
        if (chance(0.13)) {
          ellipse(
            ink(SlideInk.clear, TissueSlide.over),
            at + inward * (tall * 0.26),
            tall * 0.2,
            wide * 0.4,
            inward.direction,
          );
        }
      }
    }
    // What the epithelium lies on.
    final Path body = polygon(<Offset>[
      ...lining.inner,
      Offset(field + 220, field + 80),
      Offset(-field - 220, field + 80),
    ]);
    ink(SlideInk.eosin0, TissueSlide.ground).addPath(body, Offset.zero);
    if (villi) {
      // Crypts cut across, under the villi.
      for (double x = -field; x <= field; x += 62) {
        final Offset c = Offset(x + between(-6, 6), floor + between(40, 52));
        if (!near(c, 10)) {
          continue;
        }
        ring(
          c,
          lumen: 5,
          outer: 23,
          count: 9 + random.nextInt(3),
          turn: between(0, 6),
          look: (int _) => chance(0.2)
              ? (SlideInk.eosin0, 0.75, SlideInk.nucleus2)
              : (SlideInk.eosin2, 0.72, SlideInk.nucleus2),
          nucleus: 2.7,
        );
        keep(c, 25);
      }
    } else {
      // The tube's muscle, under its mucosa.
      final double top = floor + 118;
      ink(
        SlideInk.eosin2,
        TissueSlide.ground,
      ).addRect(Rect.fromLTRB(-field - 20, top, field + 20, field + 20));
      for (int k = 0; k < 150; k++) {
        final Offset p = Offset(
          between(-field, field),
          between(top + 5, field),
        );
        if (near(p)) {
          nucleus(
            p,
            between(5.5, 7.5),
            across: 1.5,
            turn: between(-0.12, 0.12),
            layer: TissueSlide.ground,
          );
        }
      }
    }
    stroma(body, nuclei: 150, fibres: 90, vessels: 7, sway: 0.9);
    own(SlideInk.eosin2);
    for (final double t in <double>[0.15, 0.32, 0.5, 0.68, 0.85]) {
      final double x = targetBounds.left + targetBounds.width * t;
      fibre(<Offset>[
        Offset(x, targetBounds.top),
        Offset(x, targetBounds.top - (villi ? 1.3 : 3)),
      ], layer: TissueSlide.own);
    }
  }

  /// A stratified epithelium on its stroma, as the skin's, the gullet's or
  /// the cervix's: a dark basal layer on a wavy floor, polygonal cells
  /// above it, flattening to the surface. With [umbrella], a bladder's
  /// instead: fewer layers, none flattened, the top one of large cells. The
  /// zoom's cell is in the middle layers.
  void stratified({required bool umbrella}) {
    const double step = 15;
    final double top = umbrella ? -64 : -120;
    final double low = umbrella ? 48 : 74;
    double floor(double x) => umbrella
        ? low + 5 * math.sin(x / 61 + 0.4)
        : low + 20 * math.sin(x / 47 + 0.6);
    // How much the layers thin toward the surface.
    final double bend = umbrella ? 1 : 1.5;
    final double deep = low - top;
    // Seeds are laid on an even lattice and then moved, each row to its
    // depth: thin rows at the surface, tall ones on the floor. The one the
    // zoom's cell takes is moved to the origin.
    final double own0 = math
        .pow((0 - top) / (floor(0) - top), 1 / bend)
        .toDouble();
    const double rise = step * 0.8660254;
    final List<Offset> seeds = <Offset>[];
    final List<bool> drawn = <bool>[];
    for (final Offset p in lattice(
      step,
      jitter: 0.45,
      pin: Offset(0, own0 * deep),
      pinned: true,
      beyond: 4,
    )) {
      // A whole row is of the epithelium or not, whichever way each of its
      // seeds was nudged: the surface and the floor stay even.
      final double row =
          own0 * deep + ((p.dy - own0 * deep) / rise).round() * rise;
      final bool inside = row > 0 && row < deep;
      final double share = inside
          ? (p.dy / deep).clamp(0.015, 0.985)
          : p.dy / deep;
      if (share < -2.6 * step / deep || share > 1 + 2.6 * step / deep) {
        continue;
      }
      seeds.add(
        Offset(
          p.dx,
          share <= 0
              ? top + p.dy
              : share >= 1
              ? floor(p.dx) + (p.dy - deep)
              : top + (floor(p.dx) - top) * math.pow(share, bend),
        ),
      );
      drawn.add(inside);
    }
    final List<List<Offset>> cells = voronoi(seeds, 50);
    for (int i = 0; i < seeds.length; i++) {
      if (!drawn[i] || cells[i].length < 3) {
        continue;
      }
      final Offset c = centroid(cells[i]);
      final double share = ((c.dy - top) / (floor(c.dx) - top)).clamp(0.0, 1.0);
      if (share > 0.86) {
        // The basal layer: small, dark, crowded.
        cell(
          cells[i],
          SlideInk.basophil,
          shrink: 0.95,
          corner: 0.22,
          nucleus: 3.2,
          nucleusAcross: 2.5,
          nucleusTurn: math.pi / 2,
          nucleusInk: SlideInk.nucleus2,
        );
      } else if (umbrella && share < 0.2) {
        cell(
          cells[i],
          SlideInk.eosin2,
          shrink: 0.95,
          corner: 0.25,
          nucleus: 3.7,
        );
      } else if (umbrella || share > 0.3) {
        cell(
          cells[i],
          chance(0.5) ? SlideInk.eosin1 : SlideInk.eosin2,
          shrink: 0.95,
          corner: 0.22,
          nucleus: 3.1,
        );
      } else {
        // Flattening toward the surface, its nucleus with it.
        cell(
          cells[i],
          chance(0.6) ? SlideInk.eosin1 : SlideInk.eosin0,
          shrink: 0.95,
          corner: 0.22,
          nucleus: 3.6,
          nucleusAcross: (0.9 + 2 * share / 0.3).clamp(0.9, 2.8),
          nucleusInk: share < 0.12 ? SlideInk.nucleus2 : SlideInk.nucleus1,
        );
      }
    }
    // The stroma under it.
    final Path under = polygon(<Offset>[
      for (double x = -field - 40; x <= field + 40; x += 6)
        Offset(x, floor(x) - 10),
      Offset(field + 40, field + 40),
      Offset(-field - 40, field + 40),
    ]);
    ink(SlideInk.eosin0, TissueSlide.ground).addPath(under, Offset.zero);
    stroma(
      polygon(<Offset>[
        for (double x = -field - 40; x <= field + 40; x += 6)
          Offset(x, floor(x) + 12),
        Offset(field + 40, field + 40),
        Offset(-field - 40, field + 40),
      ]),
      nuclei: 110,
      fibres: 110,
      vessels: 6,
      sway: 0.7,
    );
    own(SlideInk.eosin1);
  }

  /// Lung: air spaces walled by thin septa, capillaries full of red cells
  /// in the walls and the nuclei of the cells that line them. The zoom's
  /// cell is in a wall between two spaces.
  void alveoli() {
    const double pitch = 128;
    ellipse(
      ink(SlideInk.eosin1, TissueSlide.ground),
      Offset.zero,
      field + 4,
      field + 4,
    );
    // Two spaces, one above the zoom's cell and one below: the wall
    // between them passes through it.
    const Offset above = Offset(0, -pitch / 2);
    const Offset below = Offset(0, pitch / 2);
    final List<Offset> seeds = <Offset>[
      above,
      below,
      ...lattice(
        pitch,
        jitter: 0.45,
        pin: above,
        where: (Offset p) =>
            (p - above).distance > pitch * 0.6 &&
            (p - below).distance > pitch * 0.6,
      ),
    ];
    for (final List<Offset> poly in voronoi(seeds, pitch * 2.2)) {
      if (poly.length < 3 || !near(centroid(poly), pitch)) {
        continue;
      }
      ink(SlideInk.clear)
          .addPath(rounded(poly, shrink: 0.93, corner: 0.45), Offset.zero);
      // In the walls. Each is shared by two spaces, so each space lays
      // half of what its walls hold.
      for (int i = 0; i < poly.length; i++) {
        final Offset a = poly[i];
        final Offset b = poly[(i + 1) % poly.length];
        final int things = ((b - a).distance / 21).round();
        for (int k = 0; k < things; k++) {
          if (!chance(0.5)) {
            continue;
          }
          final Offset p = Offset.lerp(a, b, between(0.08, 0.92))!;
          if (!free(p, 3)) {
            continue;
          }
          final double kind = roll;
          if (kind < 0.45) {
            red(p, r: 3, layer: TissueSlide.over);
          } else if (kind < 0.8) {
            nucleus(
              p,
              3.7,
              across: 1.3,
              turn: (b - a).direction,
              ink: SlideInk.nucleus2,
              layer: TissueSlide.over,
            );
          } else {
            nucleus(p, 2.7, layer: TissueSlide.over);
          }
        }
      }
    }
    own(SlideInk.eosin2);
  }

  /// The edge of a lymph node: fat outside, the capsule, the sinus under
  /// it crossed by fine fibres, and the cortex, lymphocytes packed close
  /// with a follicle among them, its centre pale. The zoom's cell lines the
  /// sinus's floor.
  void lymphNode() {
    const double sinus = 30;
    const double capsule = 46;
    double floor(double x) => 0.0005 * x * x;
    double roof(double x) => floor(x) - sinus + 3 * math.sin(x / 37);
    double skin(double x) =>
        floor(x) - sinus - capsule + 4 * math.sin(x / 61 + 1);
    double lean(double x) => math.atan(0.001 * x);
    final List<double> across = <double>[
      for (double x = -field - 30; x <= field + 30; x += 5) x,
    ];
    final List<Offset> floorLine = <Offset>[
      for (final double x in across) Offset(x, floor(x)),
    ];
    final List<Offset> roofLine = <Offset>[
      for (final double x in across) Offset(x, roof(x)),
    ];
    final List<Offset> skinLine = <Offset>[
      for (final double x in across) Offset(x, skin(x)),
    ];
    // Fat, beyond the capsule.
    final List<Offset> fat = relaxed(
      lattice(68, jitter: 0.5, where: (Offset p) => p.dy < skin(p.dx) + 70),
      150,
      times: 1,
    );
    for (final List<Offset> poly in voronoi(fat, 150)) {
      if (poly.length >= 3 &&
          centroid(poly).dy < skin(centroid(poly).dx) + 24) {
        lard(poly, layer: TissueSlide.ground);
      }
    }
    ink(SlideInk.lamp).addPath(
      polygon(<Offset>[...floorLine, ...roofLine.reversed]),
      Offset.zero,
    );
    ink(SlideInk.eosin1).addPath(
      polygon(<Offset>[
        ...floorLine,
        Offset(field + 30, field + 30),
        Offset(-field - 30, field + 30),
      ]),
      Offset.zero,
    );
    ink(SlideInk.eosin2).addPath(
      polygon(<Offset>[...roofLine, ...skinLine.reversed]),
      Offset.zero,
    );
    // The capsule's collagen and its fibroblasts.
    for (int k = 0; k < 14; k++) {
      final double depth = between(0.1, 0.9);
      final double from = between(-field, field - 120);
      final double to = from + between(90, 200);
      fibre(<Offset>[
        for (double x = from; x < to; x += 8)
          Offset(
            x,
            roof(x) + (skin(x) - roof(x)) * depth + math.sin(x / 14 + k) * 1.2,
          ),
      ]);
    }
    for (int k = 0; k < 46; k++) {
      final double x = between(-field, field);
      nucleus(
        Offset(x, roof(x) + (skin(x) - roof(x)) * between(0.12, 0.88)),
        between(4.5, 6),
        across: 1.3,
        turn: lean(x),
        ink: SlideInk.nucleus2,
      );
    }
    // The sinus's walls, and the flat cells that line them.
    ink(SlideInk.border).addPath(polyline(floorLine), Offset.zero);
    ink(SlideInk.border).addPath(polyline(roofLine), Offset.zero);
    for (double x = -field + between(0, 30); x < field; x += between(26, 46)) {
      nucleus(
        Offset(x, floor(x) - 0.8),
        4.6,
        across: 1.2,
        turn: lean(x),
        ink: SlideInk.nucleus2,
      );
    }
    for (double x = -field + between(0, 30); x < field; x += between(26, 46)) {
      nucleus(
        Offset(x, roof(x) + 0.8),
        4.6,
        across: 1.2,
        turn: lean(x),
        ink: SlideInk.nucleus2,
      );
    }
    // In the sinus: fibres across it, a few macrophages, lymphocytes
    // passing through.
    for (int k = 0; k < 12; k++) {
      final double x = between(-field, field);
      fibre(<Offset>[Offset(x, floor(x)), Offset(x + between(-9, 9), roof(x))]);
    }
    for (int k = 0; k < 40; k++) {
      final double x = between(-field, field);
      final Offset p = Offset(x, floor(x) - between(6, sinus - 7));
      if (!free(p, 5)) {
        continue;
      }
      if (k < 5) {
        final Path body = Contour.blob(
          p,
          7.5,
          6.5,
          count: 24,
          wobble: 0.12,
          seed: k,
        ).toPath();
        ink(SlideInk.eosin0, TissueSlide.over).addPath(body, Offset.zero);
        ink(SlideInk.border, TissueSlide.over).addPath(body, Offset.zero);
        nucleus(
          p + const Offset(1.5, 0.5),
          3.4,
          across: 2.6,
          ink: SlideInk.nucleus0,
          layer: TissueSlide.over,
        );
        keep(p, 9);
      } else {
        nucleus(p, 2.7, ink: SlideInk.nucleus2);
      }
    }
    // The follicle: a pale centre of larger cells, macrophages with debris
    // among them, in a mantle of small dark lymphocytes.
    const Offset follicle = Offset(58, 152);
    const double centre = 56;
    const double mantle = 92;
    ink(SlideInk.eosin0, TissueSlide.over).addPath(
      Contour.blob(
        follicle,
        centre,
        centre * 0.92,
        wobble: 0.05,
        seed: 7,
      ).toPath(),
      Offset.zero,
    );
    for (int k = 0; k < 5; k++) {
      final Offset p =
          follicle + unit(k * 1.3 + 0.4) * between(12, centre - 16);
      ellipse(ink(SlideInk.clear, TissueSlide.over), p, 7.5, 6.8);
      for (int m = 0; m < 3; m++) {
        ellipse(
          ink(SlideInk.nucleus2, TissueSlide.over),
          p + unit(m * 2.1 + k) * 3.2,
          1.2,
          1.2,
        );
      }
      keep(p, 9);
    }
    for (final Offset p in lattice(
      10.5,
      jitter: 0.8,
      where: (Offset p) => (p - follicle).distance < centre - 4,
    )) {
      if (!kept(p)) {
        nucleus(
          p,
          between(3.1, 3.9),
          ink: chance(0.82) ? SlideInk.nucleus1 : SlideInk.nucleus0,
          layer: TissueSlide.over,
        );
      }
    }
    for (final Offset p in lattice(
      7.5,
      jitter: 0.7,
      where: (Offset p) => p.dy > floor(p.dx) + 3.8,
    )) {
      if (!near(p, 4)) {
        continue;
      }
      final double far = (p - follicle).distance;
      if (far < centre + 1) {
        continue;
      }
      if (far < mantle) {
        nucleus(p, 2.55, ink: SlideInk.nucleus2);
      } else if (chance(0.86)) {
        nucleus(
          p,
          between(2.5, 2.9),
          ink: chance(0.75) ? SlideInk.nucleus2 : SlideInk.nucleus1,
        );
      }
    }
    own(SlideInk.eosin1, nucleus: SlideInk.nucleus2);
  }

  /// The wall of an artery cut along its length: blood in the lumen, the
  /// flat cells that line it, then layer on layer of smooth muscle between
  /// wavy sheets of elastin, and the loose tissue outside. The zoom's cell
  /// lines the lumen.
  void vesselWall() {
    const double media = 150;
    double wall(double x) => 0.0004 * x * x;
    double lean(double x) => math.atan(0.0008 * x);
    final List<double> across = <double>[
      for (double x = -field - 30; x <= field + 30; x += 5) x,
    ];
    final List<Offset> inner = <Offset>[
      for (final double x in across) Offset(x, wall(x)),
    ];
    final List<Offset> outer = <Offset>[
      for (final double x in across)
        Offset(x, wall(x) + media + 6 * math.sin(x / 70)),
    ];
    for (int k = 0; k < 300; k++) {
      final Offset p = anywhere();
      if (p.dy < wall(p.dx) - 5 && !onTarget(p, 5)) {
        red(p, layer: TissueSlide.ground);
      }
    }
    final Path outside = polygon(<Offset>[
      ...outer,
      Offset(field + 30, field + 30),
      Offset(-field - 30, field + 30),
    ]);
    ink(SlideInk.eosin0, TissueSlide.ground).addPath(outside, Offset.zero);
    stroma(outside, nuclei: 40, fibres: 70, vessels: 3);
    ink(SlideInk.eosin2)
        .addPath(polygon(<Offset>[...inner, ...outer.reversed]), Offset.zero);
    ink(SlideInk.border).addPath(polyline(inner), Offset.zero);
    // Elastin, in wavy sheets.
    for (int k = 0; k <= 6; k++) {
      final double depth = 3 + k * (media - 6) / 6;
      fibre(<Offset>[
        for (final double x in across)
          Offset(x, wall(x) + depth + math.sin(x / 5 + k * 1.7) * 1.4),
      ]);
    }
    for (int k = 0; k < 190; k++) {
      final double x = between(-field, field);
      final Offset p = Offset(x, wall(x) + between(8, media - 6));
      if (free(p, 3)) {
        nucleus(
          p,
          between(6, 8.5),
          across: 1.5,
          turn: lean(x) + between(-0.1, 0.1),
        );
      }
    }
    for (double x = -field + between(0, 20); x < field; x += between(24, 40)) {
      nucleus(
        Offset(x, wall(x) - 0.6),
        4.8,
        across: 1.25,
        turn: lean(x),
        ink: SlideInk.nucleus2,
      );
    }
    own(SlideInk.eosin1, nucleus: SlideInk.nucleus2);
  }
}
