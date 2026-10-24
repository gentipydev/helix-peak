import 'dart:ui';

/// A block cut through the whole thickness of a placenta at term, in its
/// uterine wall, beside where its umbilical cord is inserted, drawn from
/// general anatomy in millimetres: x across the block's front face from its
/// left edge, y down from the placenta's fetal surface, z back into the
/// block from the front face. Its front face is the cut, flat to the view,
/// from the chorionic plate down through the villi and the basal plate to
/// the uterine muscle; its top is the fetal surface under the amnion, the
/// cord's root on it; its right side is a second cut, seen in shade.
///
/// What is measured:
/// - After Gray (1918, the twentieth edition, pp. 62–65, read in the
///   Internet Archive's copy): the villi of the chorion frondosum branch
///   repeatedly and hang in the intervillous space, bathed in maternal
///   blood; many of the larger villi reach from the chorionic to the
///   decidual surface, others are attached to the septa, but most hang
///   free; the deeper part of the stratum compactum is condensed into the
///   basal plate, and between it and the uterine muscle lie the stratum
///   spongiosum and a boundary layer, through which the uterine arteries
///   and veins pass to and from the intervillous space; septa of the
///   stratum compactum rise from the basal plate and part the placenta into
///   its lobules, or cotyledons, most ending in irregular or pointed
///   processes; the placenta is about 3 cm thick when expelled; the fetal
///   surface is smooth under the amnion; the cord is usually attached near
///   the placenta's centre, and from it the umbilical vessels radiate under
///   the amnion, the veins deeper and larger than the arteries.
/// - In utero the placenta is thicker than it is once delivered: by
///   ultrasound its median thickness at 40 weeks is 39.9 mm, pooled over 20
///   studies of 7,955 women (Ali et al. 2026, J Med Ultrasound 34:9);
///   delivered and sliced, 183 placentas averaged 1.72 cm, at most 2.24 cm
///   (Park et al. 2018, PLoS One 13:e0191276).
/// - A converted spiral artery is 0.4–0.5 mm across until its last few
///   millimetres, which dilate into a funnel opening through the basal
///   plate, 2.4 mm at its widest at term; it opens into the villus-free
///   central cavity of a lobule, from which the blood spreads out between
///   the villi; lobules are 2–3 cm across, larger toward the middle of the
///   placenta; trophoblast converts the arteries as deep as the inner third
///   of the myometrium; terminal villi are about 0.1 mm across (Burton et
///   al. 2009, Placenta 30:473).
/// - Stem villi are from 100 µm to several millimetres across; the septa
///   grow out of the decidua and never reach the chorionic plate; the fetal
///   surface is smooth, bluish grey and glistening under the amnion, the
///   chorionic vessels radiating from the cord's insertion (Quaye et al.
///   2026, Arch Gynecol Obstet 313:234).
/// - After 30 weeks the cord's cross-section is 186.4 mm², its vein's
///   52.1 mm² and an artery's 15.5 mm²: about 15.4, 8.1 and 4.4 mm across
///   (Rostamzadeh et al. 2015, Iran J Radiol 12:e12230).
/// - At term the cord coils 0.21 to 0.47 times to the centimetre, 0.337 on
///   average, in 65 low-risk pregnancies (Celik et al. 2026, J Clin Med
///   15:1810).
/// - At 34 weeks the uterine wall is about 6.3 mm thick at its front and
///   6.9 mm at its fundus (Louwagie et al. 2021, PLoS One 16:e0242118,
///   their regressions, lying down); it is thicker behind the placenta than
///   elsewhere (Degani et al. 1998, J Ultrasound Med 17:661).
///
/// Drawing choices, measured by none of these: the block, 5 cm across and
/// 3.2 deep; the amnion's, the chorionic plate's, the basal plate's and the
/// decidua's thickness under it; two whole lobules across the face, each
/// one villous tree, and where their stem villi leave the chorionic plate,
/// how they branch and how thickly their villi are drawn; each central
/// cavity's size; the septa's places, heights and breadth; where the veins
/// leave the basal plate, at the lobules' edges, and how wide they are;
/// the spiral arteries' coils; the chorionic vessels' courses and calibres;
/// how far the cord is drawn above the surface before it is cut, and where
/// its vessels lie in it.
abstract final class PlacentaAnatomy {
  // The block.

  /// How wide its front face is, and how far back into the placenta its
  /// top and its side reach.
  static const double width = 50;
  static const double depth = 32;

  // The layers, down from the fetal surface.

  /// The amnion, and the chorionic plate under it: where each ends.
  static const double amnion = 0.2;
  static const double chorionicPlate = 1.8;

  /// The placenta, from its fetal surface to the floor of its basal plate,
  /// in utero at term; and the basal plate's own thickness.
  static const double thickness = 40;
  static const double basalPlate = 1.5;

  /// The decidua left under the basal plate, and the uterine muscle under
  /// that.
  static const double decidua = 2.5;
  static const double myometrium = 7;

  /// How deep the block's front face reaches.
  static const double faceDepth = thickness + decidua + myometrium;

  // The lobules.

  /// The middle of each lobule across the face, where its spiral artery
  /// opens.
  static const List<double> lobules = <double>[13.5, 37];

  /// Each lobule's central cavity: how wide, and how far up from the basal
  /// plate it reaches.
  static const double cavityWidth = 7;
  static const double cavityHeight = 13;

  /// The septa: where each rises from the basal plate across the face, and
  /// how far up toward the chorionic plate it reaches, a share of the way;
  /// and how broad each is at its foot.
  static const List<(double, double)> septa = <(double, double)>[
    (1.4, 0.42),
    (25.4, 0.6),
    (48.7, 0.5),
  ];
  static const double septumFoot = 2.6;

  // The villous trees.

  /// Where each lobule's stem villus leaves the chorionic plate, from the
  /// lobule's middle; how broad it is there, and its branches at their
  /// ends.
  static const double trunkOffset = 1.2;
  static const double trunk = 2.4;
  static const double twig = 0.35;

  /// How far down the stem villus runs before it branches.
  static const double trunkLength = 8;

  /// The villi clustered round the stem villi's branches, each drawn as a
  /// small round clump: their least and greatest radius, and how far from
  /// a branch they lie at most.
  static const double clumpMin = 0.24;
  static const double clumpMax = 0.5;
  static const double foliage = 2.2;

  // The vessels.

  /// A spiral artery: how wide it is, and its mouth; how far below the
  /// basal plate's top its funnel begins.
  static const double spiral = 0.45;
  static const double mouth = 2.4;
  static const double funnel = 3;

  /// How far each spiral artery's coils swing to either side, and how far
  /// apart they lie.
  static const double coilSwing = 1.1;
  static const double coilPitch = 2.6;

  /// The veins leaving the basal plate at the lobules' edges, across the
  /// face, and how wide each is.
  static const List<double> veins = <double>[4.2, 22.4, 28.6, 45.8];
  static const double vein = 1.6;

  /// The veins cut in the myometrium: where each lies, how wide and how
  /// tall.
  static const List<(Offset, double, double)> sinuses =
      <(Offset, double, double)>[
        (Offset(8, 45.2), 3.2, 1.3),
        (Offset(25.5, 46.4), 3.8, 1.5),
        (Offset(43.5, 45), 3, 1.2),
      ];

  /// The chorionic vessels: an artery's and a vein's breadth.
  static const double chorionicArtery = 1.2;
  static const double chorionicVein = 1.6;

  /// Each chorionic vessel's course over the fetal surface from the cord's
  /// root, across and back, and whether it is a vein; each runs out of the
  /// block at its front edge or its back, and each artery crosses its vein
  /// at least once.
  static const List<(List<Offset>, bool)> chorionic = <(List<Offset>, bool)>[
    (
      <Offset>[Offset(33, 19), Offset(24, 13.5), Offset(13, 7), Offset(4, 0)],
      true,
    ),
    (
      <Offset>[Offset(34, 18), Offset(27, 16), Offset(17, 9), Offset(9, 0)],
      false,
    ),
    (
      <Offset>[Offset(38, 17), Offset(41, 11), Offset(43, 5), Offset(46, 0)],
      true,
    ),
    (
      <Offset>[
        Offset(37, 17),
        Offset(43.5, 10),
        Offset(41.5, 4.5),
        Offset(40, 0),
      ],
      false,
    ),
    (<Offset>[Offset(33, 23), Offset(23, 27), Offset(12, 32)], true),
    (
      <Offset>[Offset(34, 24), Offset(26, 25), Offset(16, 30), Offset(11, 32)],
      false,
    ),
  ];

  // The cord.

  /// Its root on the fetal surface, across and back; how wide it is, its
  /// vein and its arteries; and how far above the surface it is cut.
  static const Offset cordRoot = Offset(36, 21);
  static const double cord = 15.4;
  static const double cordVein = 8.1;
  static const double cordArtery = 4.4;
  static const double cordShown = 12;

  /// How many times it coils to the millimetre, its arteries winding round
  /// its vein.
  static const double coiling = 0.0337;

  /// Where in the front face its tissue is sampled: in the villi of the
  /// left lobule, above its central cavity.
  static const Offset site = Offset(9, 20);
}
