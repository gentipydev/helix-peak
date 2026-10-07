import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/cell_archetypes.dart';
import '../contour.dart';
import 'slide_builder.dart';
import 'tissue_slide.dart';

/// The recipes for tissues that are a mass of one thing: marrow, muscle,
/// brain, the retina's layers, fat, and the spindle cells of smooth muscle
/// and stroma. Sizes are in micrometres and are the tissue's own.
extension BulkRecipes on SlideBuilder {
  /// Bone marrow: small blood-forming cells packed close, the red line's
  /// in clusters with small dark nuclei, fat cells among them, a
  /// megakaryocyte here and there, and a sinusoid full of red cells. With
  /// [island], the zoom's cell is an erythroblast of an island, round the
  /// macrophage that nurses it, as the cell's scene shows it.
  void marrow({required bool island}) {
    const int over = TissueSlide.over;
    capillary(
      smooth(<Offset>[
        Offset(-field - 20, 64),
        const Offset(-128, 142),
        const Offset(-6, 214),
        Offset(84, field + 20),
      ], steps: 14),
      17,
      layer: over,
      reds: 0.8,
    );
    // Fat cells and megakaryocytes, each where there is room.
    final List<(Offset, double)> fats = <(Offset, double)>[];
    for (int tries = 0; tries < 600 && fats.length < 9; tries++) {
      final Offset c = anywhere(field + 10);
      final double r = between(26, 40);
      if (c.distance < r + 48 ||
          kept(c, r + 8) ||
          fats.any(
            ((Offset, double) f) => (f.$1 - c).distance < f.$2 + r + 10,
          )) {
        continue;
      }
      fats.add((c, r));
    }
    final List<(Offset, double)> giants = <(Offset, double)>[];
    for (int tries = 0; tries < 600 && giants.length < 3; tries++) {
      final Offset c = anywhere(field * 0.86);
      final double r = between(20, 26);
      if (c.distance < r + 44 ||
          kept(c, r + 6) ||
          fats.any(
            ((Offset, double) f) => (f.$1 - c).distance < f.$2 + r + 8,
          ) ||
          giants.any(((Offset, double) g) => (g.$1 - c).distance < 90)) {
        continue;
      }
      giants.add((c, r));
    }
    for (final (Offset c, double r) in fats) {
      keep(c, r - 1);
    }
    for (final (Offset c, double r) in giants) {
      keep(c, r - 2);
    }
    // The island's own places, as the cell's scene lays them out.
    final double r = targetBounds.width / 1.9;
    final Offset nurse = Offset(-r * 2.3, r * 0.25);
    final List<(Offset, double, double)> brood = <(Offset, double, double)>[
      for (int k = 0; k < 5; k++)
        (
          nurse + unit(math.pi * (0.45 + 0.28 * k)) * (r * 2.25),
          r * (0.95 - 0.1 * k),
          math.pi * (0.45 + 0.28 * k),
        ),
    ];
    final List<Offset> grown = <Offset>[
      Offset(r * 1.9, -r * 1.6),
      Offset(r * 2.5, -r * 0.4),
      Offset(r * 1.7, r * 1.5),
    ];
    if (island) {
      keep(nurse, r * 1.5);
      for (final (Offset c, double size, double _) in brood) {
        keep(c, size + 0.5);
      }
      for (final Offset p in grown) {
        keep(p, 4.2);
      }
    }
    // The blood-forming cells. No borders: they lie loose.
    final List<Offset> seeds = relaxed(lattice(9.6, jitter: 0.8), 22, times: 1);
    for (final List<Offset> poly in voronoi(seeds, 22)) {
      if (poly.length < 3) {
        continue;
      }
      if (noise(centroid(poly), 42) > 0.56) {
        // The red line: a small round nucleus, very dark.
        cell(
          poly,
          SlideInk.eosin2,
          shrink: 0.9,
          corner: 0.45,
          nucleus: 2.9,
          nucleusInk: SlideInk.nucleus2,
          border: false,
        );
      } else {
        cell(
          poly,
          chance(0.06)
              ? SlideInk.eosin3
              : chance(0.5)
              ? SlideInk.eosin1
              : SlideInk.eosin0,
          shrink: 0.9,
          corner: 0.45,
          nucleus: between(3.1, 3.7),
          nucleusAcross: between(2.4, 3.2),
          nucleusTurn: between(0, math.pi),
          nucleusInk: chance(0.6) ? SlideInk.nucleus1 : SlideInk.nucleus2,
          border: false,
        );
      }
    }
    for (int i = 0; i < fats.length; i++) {
      final (Offset c, double r) = fats[i];
      final Contour blob = Contour.blob(
        c,
        r,
        r * between(0.9, 1),
        count: 48,
        wobble: 0.05,
        seed: 40 + i,
      );
      ink(SlideInk.eosin1, over).addPath(blob.toPath(), Offset.zero);
      ink(SlideInk.clear, over).addPath(
        Contour(<Offset>[
          for (final Offset p in blob.points) c + (p - c) * 0.94,
        ]).toPath(),
        Offset.zero,
      );
      if (chance(0.5)) {
        final double a = between(0, 2 * math.pi);
        nucleus(
          c + unit(a) * (r * 0.93),
          4.6,
          across: 1.2,
          turn: a + math.pi / 2,
          ink: SlideInk.nucleus2,
          layer: over,
        );
      }
    }
    for (int i = 0; i < giants.length; i++) {
      final (Offset c, double r) = giants[i];
      final Path body = Contour.blob(
        c,
        r,
        r * 0.9,
        count: 48,
        wobble: 0.1,
        seed: 50 + i,
      ).toPath();
      ink(SlideInk.eosin1, over).addPath(body, Offset.zero);
      ink(SlideInk.border, over).addPath(body, Offset.zero);
      // A megakaryocyte's nucleus: many lobes in one mass.
      for (int m = 0; m < 6; m++) {
        final double a = between(0, 2 * math.pi);
        ellipse(
          ink(SlideInk.nucleus2, over),
          c + unit(a) * (r * between(0.08, 0.36)),
          r * between(0.2, 0.31),
          r * between(0.16, 0.25),
          between(0, math.pi),
        );
      }
    }
    if (island) {
      final Path body = Contour.blob(
        nurse,
        r * 1.5,
        r * 1.25,
        wobble: 0.18,
        seed: 5,
      ).toPath();
      ink(SlideInk.eosin0, over).addPath(body, Offset.zero);
      ink(SlideInk.border, over).addPath(body, Offset.zero);
      nucleus(
        nurse + Offset(-r * 0.3, 0),
        r * 0.5,
        across: r * 0.4,
        ink: SlideInk.nucleus0,
        layer: over,
        nucleolus: true,
      );
      for (int k = 0; k < brood.length; k++) {
        final (Offset c, double size, double a) = brood[k];
        final Path young = Contour.blob(
          c,
          size,
          size,
          count: 32,
          wobble: 0.05,
          seed: 20 + k,
        ).toPath();
        ink(SlideInk.eosin2, over).addPath(young, Offset.zero);
        ink(SlideInk.border, over).addPath(young, Offset.zero);
        // The last, about to lose its nucleus: pushed to the rim.
        nucleus(
          c + unit(a) * (size * (k == brood.length - 1 ? 0.62 : 0)),
          size * (0.55 - 0.05 * k),
          ink: SlideInk.nucleus2,
          layer: over,
        );
      }
      for (final Offset p in grown) {
        red(p, r: 3.7, layer: over);
      }
    }
    own(
      island ? SlideInk.eosin2 : SlideInk.eosin1,
      nucleus: island ? SlideInk.nucleus2 : SlideInk.nucleus1,
    );
  }

  /// Skeletal muscle cut along its fibres: long fibres side by side, their
  /// nuclei flat against their edges, capillaries between. With [heart],
  /// heart muscle instead: thinner fibres, each cell's nucleus in its
  /// middle, the cells joined end to end at stepped discs. The zoom's fibre
  /// runs through the origin.
  void muscle({required bool heart}) {
    const double gap = 2.6;
    final double ownTop = heart ? -11 : targetBounds.top;
    final double ownBottom = heart ? 11 : targetBounds.bottom;
    double thick() => heart ? between(17, 25) : between(36, 62);
    final List<(double, double)> bands = <(double, double)>[
      if (heart) (ownTop, ownBottom),
    ];
    for (double y = ownBottom + gap; y < field + 20;) {
      final double t = thick();
      bands.add((y, y + t));
      y += t + gap;
    }
    for (double y = ownTop - gap; y > -field - 20;) {
      final double t = thick();
      bands.add((y - t, y));
      y -= t + gap;
    }
    for (final (double top, double bottom) in bands) {
      final Path band = Path()
        ..addRRect(
          RRect.fromLTRBR(
            -field - 40,
            top,
            field + 40,
            bottom,
            const Radius.circular(3),
          ),
        );
      ink(chance(0.5) ? SlideInk.eosin2 : SlideInk.eosin3)
          .addPath(band, Offset.zero);
      ink(SlideInk.border).addPath(band, Offset.zero);
      _striate(top, bottom, TissueSlide.tissue);
      final double middle = (top + bottom) / 2;
      if (heart) {
        for (
          double x = -field + between(0, 60);
          x < field;
          x += between(58, 96)
        ) {
          nucleus(Offset(x, middle), 6, across: 2.7);
          // The disc where this cell meets the next, stepped.
          final double disc = x + between(26, 40);
          fibre(<Offset>[
            Offset(disc, top + 1.5),
            Offset(disc, middle - 1),
            Offset(disc + 2.4, middle + 1),
            Offset(disc + 2.4, bottom - 1.5),
          ]);
        }
      } else {
        for (
          double x = -field + between(0, 50);
          x < field;
          x += between(46, 92)
        ) {
          nucleus(
            Offset(x, chance(0.5) ? top + 2.5 : bottom - 2.5),
            between(5, 6.4),
            across: 1.5,
            ink: SlideInk.nucleus2,
          );
        }
      }
      for (
        double x = -field + between(0, 120);
        x < field;
        x += between(70, 190)
      ) {
        red(Offset(x, bottom + gap / 2), r: 2.5, layer: TissueSlide.over);
      }
    }
    if (heart) {
      own(SlideInk.eosin3);
      return;
    }
    own(SlideInk.eosin2, nucleus: SlideInk.nucleus2);
    _striate(targetBounds.top, targetBounds.bottom, TissueSlide.own);
    // The fibre's other nuclei along its rim: the nearest where the cell's
    // scene has them, then on along the fibre.
    final double r = targetBounds.bottom / 1.3;
    final double n = -targetBounds.top / 0.6;
    for (final double x in <double>[-1.7, -1.05, 0.95, 1.6]) {
      nucleus(
        Offset(x * r, -n * 0.1),
        n * 1.2,
        across: n * 0.36,
        ink: SlideInk.nucleus2,
        layer: TissueSlide.own,
      );
    }
    for (final double side in <double>[-1, 1]) {
      for (double x = r * 3; x < field; x += between(48, 90)) {
        nucleus(
          Offset(
            side * x,
            chance(0.5) ? targetBounds.top + 2.4 : targetBounds.bottom - 2.4,
          ),
          n * 1.2,
          across: n * 0.36,
          ink: SlideInk.nucleus2,
          layer: TissueSlide.own,
        );
      }
    }
  }

  /// Marks a fibre lying between [top] and [bottom] as striated: the
  /// stripes themselves, a sarcomere apart, are drawn over it.
  void _striate(double top, double bottom, int layer) {
    ink(
      SlideInk.stria,
      layer,
    ).addRect(Rect.fromLTRB(-field - 2, top + 0.7, field + 2, bottom - 0.7));
  }

  /// Grey matter: a pink felt of fibres stippled with the small nuclei of
  /// glia, some in a clear halo, neurons standing out purple with pale
  /// nuclei, and capillaries. The zoom's cell is one of the neurons.
  void greyMatter() {
    const int ground = TissueSlide.ground;
    ellipse(ink(SlideInk.eosin0, ground), Offset.zero, field + 4, field + 4);
    for (int k = 0; k < 170; k++) {
      strand(
        anywhere(),
        between(0, math.pi),
        between(18, 44),
        wave: 1.2,
        layer: ground,
      );
    }
    for (int k = 0, laid = 0; k < 40 && laid < 4; k++) {
      final Offset from = anywhere(field * 0.9);
      final double heading = between(0, 2 * math.pi);
      final List<Offset> spine = smooth(<Offset>[
        from,
        from + unit(heading) * 45 + unit(heading + 1.5) * between(-14, 14),
        from + unit(heading) * between(85, 120),
      ]);
      if (spine.any((Offset p) => p.distance < 62 || kept(p, 30))) {
        continue;
      }
      capillary(spine, 6);
      laid++;
    }
    // The neurons: each the shape of the zoom's own where that is a
    // neuron, a pyramid otherwise.
    final List<Offset> bodies = <Offset>[];
    for (int tries = 0; tries < 700 && bodies.length < 11; tries++) {
      final Offset c = anywhere(field * 0.96);
      if (c.distance < 66 ||
          kept(c, 22) ||
          bodies.any((Offset b) => (b - c).distance < 56)) {
        continue;
      }
      bodies.add(c);
      final double size = between(0.8, 1.12);
      final double turn = shape == CellShape.neuron
          ? between(0, 2 * math.pi)
          : between(-0.35, 0.35);
      final double ca = math.cos(turn);
      final double sa = math.sin(turn);
      final List<Offset> outline = shape == CellShape.neuron
          ? target.points
          : const <Offset>[
              Offset(-11, 8),
              Offset(11, 8),
              Offset(4.6, -5.5),
              Offset(2.2, -14),
              Offset(0.8, -35),
              Offset(-0.8, -35),
              Offset(-2.2, -14),
              Offset(-4.6, -5.5),
            ];
      final Path body = Contour(<Offset>[
        for (final Offset p in outline)
          c + Offset(p.dx * ca - p.dy * sa, p.dx * sa + p.dy * ca) * size,
      ]).toPath();
      ink(SlideInk.basophil).addPath(body, Offset.zero);
      ink(SlideInk.border).addPath(body, Offset.zero);
      nucleus(c, 4.6 * size, ink: SlideInk.nucleus0, nucleolus: true);
      keep(c, 15 * size);
    }
    for (int k = 0; k < 330; k++) {
      final Offset p = anywhere();
      if (!free(p, 5)) {
        continue;
      }
      if (chance(0.3)) {
        // An oligodendrocyte: a round dark nucleus in a clear halo.
        ellipse(ink(SlideInk.lamp), p, 3.8, 3.6);
        nucleus(p, 2.5, ink: SlideInk.nucleus2);
      } else {
        nucleus(
          p,
          between(3.2, 3.9),
          across: between(2.5, 3),
          turn: between(0, math.pi),
        );
      }
    }
    own(SlideInk.basophil, nucleus: SlideInk.nucleus0, nucleolus: true);
  }

  /// The retina, the vitreous above and the choroid below: nerve fibres,
  /// the ganglion cells, and then band on band, pale plexiform layers
  /// between the crowded nuclei of the inner and outer nuclear layers, the
  /// rods and cones, and the pigment epithelium. The zoom's cell is a
  /// ganglion cell.
  void retina() {
    const int ground = TissueSlide.ground;
    const double fibres = -40;
    const double ganglion = -12;
    const double innerPlexus = 12;
    const double innerNuclei = 52;
    const double outerPlexus = 87;
    const double outerNuclei = 102;
    const double segments = 152;
    const double pigment = 198;
    const double choroid = 210;
    Rect band(double top, double bottom) =>
        Rect.fromLTRB(-field - 10, top, field + 10, bottom);
    ink(SlideInk.eosin0, ground)
      ..addRect(band(fibres, innerPlexus))
      ..addRect(band(innerNuclei, outerPlexus))
      ..addRect(band(outerNuclei, segments))
      ..addRect(band(choroid, field + 10));
    ink(SlideInk.eosin1, ground)
      ..addRect(band(innerPlexus, innerNuclei))
      ..addRect(band(outerPlexus, outerNuclei));
    ink(SlideInk.eosin2, ground).addRect(band(segments, pigment));
    for (int k = 0; k < 40; k++) {
      strand(
        Offset(between(-field, field), between(fibres + 3, ganglion - 2)),
        between(-0.05, 0.05),
        between(50, 110),
        wave: 0.8,
        layer: ground,
      );
    }
    for (int k = 0; k < 70; k++) {
      strand(
        Offset(
          between(-field, field),
          between(innerPlexus + 3, innerNuclei - 3),
        ),
        between(0, math.pi),
        between(12, 26),
        wave: 1,
        layer: ground,
      );
    }
    // The ganglion cells, in one row.
    for (double x = -field + between(0, 30); x < field; x += between(26, 44)) {
      final Offset c = Offset(x, between(-4, 4));
      if (!free(c, 14)) {
        continue;
      }
      final double size = between(7, 9);
      final Path body = Contour.blob(
        c,
        size,
        size * 0.9,
        count: 32,
        wobble: 0.1,
        seed: x.round(),
      ).toPath();
      ink(SlideInk.basophil).addPath(body, Offset.zero);
      ink(SlideInk.border).addPath(body, Offset.zero);
      nucleus(c, 3.9, ink: SlideInk.nucleus0, nucleolus: true);
    }
    for (final Offset p in lattice(
      6.6,
      jitter: 0.6,
      where: (Offset p) => p.dy > innerNuclei + 2 && p.dy < outerPlexus - 2,
    )) {
      if (near(p)) {
        nucleus(
          p,
          2.9,
          ink: chance(0.6) ? SlideInk.nucleus2 : SlideInk.nucleus1,
        );
      }
    }
    for (final Offset p in lattice(
      5.9,
      jitter: 0.5,
      where: (Offset p) => p.dy > outerNuclei + 2 && p.dy < segments - 2,
    )) {
      if (near(p)) {
        nucleus(p, 2.6, ink: SlideInk.nucleus2);
      }
    }
    // Rods and cones, side by side.
    for (double x = -field; x < field; x += 3.1) {
      fibre(<Offset>[
        Offset(x, segments + 1),
        Offset(x + between(-0.5, 0.5), pigment - 1),
      ], layer: ground);
    }
    for (double x = -field - 6; x < field; x += 12) {
      cell(
        <Offset>[
          Offset(x, pigment),
          Offset(x + 12, pigment),
          Offset(x + 12, choroid),
          Offset(x, choroid),
        ],
        SlideInk.basophil,
        nucleus: 2.6,
        nucleusInk: SlideInk.nucleus2,
      );
    }
    stroma(
      Path()..addRect(band(choroid + 2, field)),
      nuclei: 30,
      fibres: 20,
      vessels: 5,
    );
    own(SlideInk.basophil, nucleus: SlideInk.nucleus0, nucleolus: true);
  }

  /// Fat: large clear cells edge to edge, each a thin rim round the space
  /// its lipid left, a nucleus pressed flat against the rim here and there,
  /// and capillaries where the cells meet. The zoom's cell is one of them.
  void fat() {
    final List<Offset> seeds = relaxed(
      lattice(66, jitter: 0.5, pin: targetBounds.center, pinned: true),
      150,
      fixed: 1,
    );
    final List<List<Offset>> cells = voronoi(seeds, 150);
    for (int i = 1; i < cells.length; i++) {
      lard(cells[i]);
      for (final Offset corner in cells[i]) {
        if (chance(0.07) && free(corner, 4)) {
          red(corner, r: 3, layer: TissueSlide.over);
        }
      }
    }
    own(SlideInk.eosin1, nucleus: SlideInk.nucleus2, hollow: 0.93);
  }

  /// Smooth muscle: spindle cells in sheets, every nucleus a long oval
  /// lying the way its sheet runs. With [whorled], a cellular stroma such
  /// as the ovary's instead: more nuclei, the cells streaming and turning
  /// in whorls. The zoom's cell lies along the grain.
  void spindles({required bool whorled}) {
    const int ground = TissueSlide.ground;
    ellipse(ink(SlideInk.eosin1, ground), Offset.zero, field + 4, field + 4);
    // Which way the cells run at each place: level at the zoom's own.
    final double level = noise(Offset.zero, 130);
    double flow(Offset p) => whorled
        ? 2 * math.pi * (noise(p, 130) - level)
        : 0.35 * math.sin(p.dx / 90 + p.dy / 140);
    for (int k = 0; k < 5; k++) {
      final Offset p = anywhere(field * 0.9);
      if (p.distance > 70 && !kept(p, 26)) {
        vessel(p, between(5, 8), layer: ground);
      }
    }
    for (int k = 0; k < 420; k++) {
      final Offset p = anywhere();
      strand(p, flow(p), between(30, 70), wave: 1.4, layer: ground);
    }
    for (int k = 0; k < (whorled ? 900 : 520); k++) {
      final Offset p = anywhere();
      if (!free(p, 4)) {
        continue;
      }
      nucleus(
        p,
        between(6, 9),
        across: between(1.5, 2.1),
        turn: flow(p) + between(-0.15, 0.15),
        ink: chance(0.5) ? SlideInk.nucleus1 : SlideInk.nucleus2,
      );
    }
    own(SlideInk.eosin2);
  }
}
