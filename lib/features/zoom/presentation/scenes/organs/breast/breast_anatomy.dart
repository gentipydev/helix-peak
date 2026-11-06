import 'dart:ui';

import '../../tube_course.dart';

/// The breast the anatomogram draws for the breast, the body's right one,
/// seen from the front in place, as the body shows it, its lower half
/// dissected as Gray's plate of it is (1918, Fig. 1172): the upper half
/// under its skin, the areola and the nipple at its middle; the lower half's
/// skin, and the fat over the gland, taken away, to show the gland's lobes
/// and their ducts running in to the nipple, the lobules at the ducts' ends
/// and the fat between them. It is drawn from general anatomy, in
/// millimetres, x across to the body's left (the screen's right: the figure
/// faces the view), y down, from the middle of the nipple. Round it lie the
/// pectoralis major it rests on, and the arteries that come to it.
///
/// It is a resting adult woman's breast, for every cell and on both
/// figures, as GTEx samples it: "Central breast subareolar region of the
/// right breast, 1-2 cm under the skin surface of nipple region" (the GTEx
/// Portal's sampling site for Breast - Mammary Tissue, gtex_v10).
///
/// What is measured:
/// - After Gray (1918, pp. 1267-1268, read in the archive.org text of the
///   20th edition, and Figs. 1172-1173): each breast extends from the second
///   rib to the sixth, and from the side of the sternum to near the
///   mid-axillary line; its deep surface is nearly circular, its long
///   diameter directed upward and lateralward toward the axilla; the nipple
///   lies "just below the center", about the fourth intercostal space, its
///   smooth muscle fibres arranged "in a circular manner around the base";
///   the areola round its base bears the areolar glands, "small tubercles
///   beneath the skin"; the gland is lobes of lobules, the smallest lobules
///   "a cluster of rounded alveoli", each lobe's ducts uniting in one canal;
///   the ducts converge toward the areola, contract at the nipple's base and
///   run straight to its summit; the gland is "thicker in the center than at
///   the circumference", its surface sending processes toward the skin,
///   joined to it by bands of connective tissue, Cooper's ligamenta
///   suspensoria (p. 435); fibrous tissue sends septa between the lobes, and
///   fat fills the intervals, but "there is no fat immediately beneath the
///   areola and papilla"; its arteries come from the axillary's thoracic
///   branches, the intercostals and the internal mammary (internal
///   thoracic); its lymph gathers in a plexus beneath the areola and passes
///   to the pectoral group of axillary nodes (pp. 715-716). The pectoralis
///   major (pp. 436-437) arises from the sternal half of the clavicle, half
///   the breadth of the sternum's front down to the sixth or seventh
///   cartilage, the cartilages of the true ribs and the external oblique's
///   aponeurosis, its fibres converging on a tendon about 5 cm broad at the
///   crest of the greater tubercle of the humerus.
/// - Over 90% of nipples have 5 to 9 duct orifices, each leading to a
///   separate ductal system (Love and Barsky 2004, Cancer 101:1947); a
///   median of 23 ducts lies in the nipple, many sharing an orifice (Rusby
///   et al. 2007, Breast Cancer Res Treat 106:171). By ultrasound in 21
///   lactating women the breast has 9.2 to 9.6 main ducts, 1.9 to 2.0 mm
///   across, all branching within the areola's radius, the first branch
///   8.0 ± 5.5 mm from the nipple, with no sinuses (Ramsay et al. 2005,
///   J Anat 206:525): Gray's ampullae are not drawn.
/// - A lobule (terminal duct lobular unit) spans a median 740 µm before the
///   menopause, of 29 acini, and 363 µm after it, of 12 (Wetstein et al.
///   2020, PLoS One 15:e0231653).
/// - The areola is 4.5 ± 1.4 cm across in 54 nulliparous women (Al-Qattan
///   et al. 2019, Plast Reconstr Surg Glob Open 7:e2326), 5.1 cm in 370,
///   whose nipples were 1.2 cm across (Archibong et al. 2021, J West Afr
///   Coll Surg 11:1).
/// - The breast's skin is 0.5 to 2.7 mm thick on mammograms, by quadrant
///   (Pope et al. 1984, J Can Assoc Radiol 35:365), up to twice as thick
///   medially and below as laterally and above (Willson et al. 1982, Clin
///   Radiol 33:691).
/// - The superficial fascia turns under the nipple and areola about 10 mm
///   from the nipple, its fibres there holding smooth muscle (Komiya et al.
///   2015, Aesthetic Plast Surg 39:209).
/// - The internal thoracic artery's branches reach the nipple and areola
///   through the first, second or third intercostal space, the second most
///   often, in 60 breasts on CT (Thuy et al. 2025, Med Arch 79:267); the
///   main one is at least 1 mm across (Hosny et al. 2025, Aesthet Surg J
///   Open Forum 7:ojae090).
///
/// Drawing choices, measured by none of these: the outline, drawn to the
/// female anatomogram's own proportions, 150 mm across, as the zoom's card
/// has it, its axillary tail, and its mound without the tail; the nipple
/// 2 mm below the middle; the skin's cut just under the nipple, and how
/// thick the skin is drawn along it; five duct systems in the lower half, of
/// the nine round the nipple, their courses, how they fork and how wide each
/// branch is at rest (the main ducts 1.2 mm, under the lactating 1.9); the
/// lobes' shapes and reach; the lobules' clusters; the fat lobules' size;
/// the ligaments' courses; the areolar glands and the nipple's orifices,
/// where each lies; the pectoralis major's borders; the arteries' courses,
/// where they are cut, and the lateral thoracic artery's width; the place
/// the body goes in, on a duct under the areola 10.5 mm below the nipple,
/// GTEx's subareolar region seen from the front.
abstract final class BreastAnatomy {
  /// How wide the breast is, across at the nipple's height: the zoom's
  /// card's 15 cm.
  static const double length = 150;

  /// The breast's outline, its base as the front shows it, the skin where it
  /// turns onto the chest: from the middle of its top round by its medial
  /// side, its lower pole, its lateral side and its axillary tail, up and out
  /// toward the axilla, back to the top.
  static const List<Offset> outline = <Offset>[
    Offset(-8, -60.5),
    Offset(8, -60),
    Offset(24, -58.5),
    Offset(40, -54),
    Offset(53, -47),
    Offset(63, -38),
    Offset(70, -27),
    Offset(74, -14),
    Offset(75.2, -1),
    Offset(74, 12),
    Offset(70.5, 24),
    Offset(64.5, 35),
    Offset(55.5, 44),
    Offset(43, 51),
    Offset(28, 55),
    Offset(12, 57),
    Offset(-4, 57.3),
    Offset(-20, 56),
    Offset(-35, 52.5),
    Offset(-49, 46),
    Offset(-60, 37),
    Offset(-68, 25.5),
    Offset(-73.5, 12),
    Offset(-75.3, -2),
    Offset(-76.3, -15),
    Offset(-78.3, -27),
    Offset(-81.5, -38),
    Offset(-85.5, -48),
    Offset(-89.5, -57),
    Offset(-92.3, -64),
    Offset(-92.6, -69.5),
    Offset(-89, -72.5),
    Offset(-82, -72),
    Offset(-72, -68.5),
    Offset(-60, -65),
    Offset(-46, -62.5),
    Offset(-28, -61.3),
  ];

  /// The breast's mound: its outline without its axillary tail, a round
  /// shoulder in its place, inside the outline everywhere. The body's oval
  /// draws in to this, the bed the breast lies on; the tail, which the
  /// anatomogram does not draw, comes up with the rest of the breast.
  static const List<Offset> mound = <Offset>[
    Offset(-8, -60.5),
    Offset(8, -60),
    Offset(24, -58.5),
    Offset(40, -54),
    Offset(53, -47),
    Offset(63, -38),
    Offset(70, -27),
    Offset(74, -14),
    Offset(75.2, -1),
    Offset(74, 12),
    Offset(70.5, 24),
    Offset(64.5, 35),
    Offset(55.5, 44),
    Offset(43, 51),
    Offset(28, 55),
    Offset(12, 57),
    Offset(-4, 57.3),
    Offset(-20, 56),
    Offset(-35, 52.5),
    Offset(-49, 46),
    Offset(-60, 37),
    Offset(-68, 25.5),
    Offset(-73.5, 12),
    Offset(-75.3, -2),
    Offset(-76.1, -15),
    Offset(-75.8, -28),
    Offset(-73, -40),
    Offset(-66.5, -50.5),
    Offset(-57, -57.5),
    Offset(-44, -61),
    Offset(-28, -61.1),
  ];

  /// Where the axillary tail runs, from its root to its tip: where it is
  /// named.
  static const Offset tailRoot = Offset(-72, -52);
  static const Offset tailTip = Offset(-89, -67);

  // The skin, and its cut.

  /// How far below the nipple's middle the skin is cut across, just under
  /// the nipple, so that the nipple stays whole and the areola's upper half
  /// is kept with the skin above.
  static const double cut = 6.5;

  /// How thick the skin is drawn where it is cut: along the cut, and round
  /// the lower edge, where it is thicker; and its epidermis.
  static const double skin = 2;
  static const double skinBelow = 2.3;
  static const double epidermis = 0.1;

  /// The nipple's radius, and the areola's.
  static const double nipple = 6.15;
  static const double areola = 22.5;

  /// The areolar glands on the areola's upper half: where each lies, and
  /// how wide each is.
  static const List<Offset> areolarGlands = <Offset>[
    Offset(-17.5, -6),
    Offset(-12, -14),
    Offset(-3.5, -18.5),
    Offset(6.5, -17),
    Offset(14.5, -11.5),
    Offset(18.5, -2.5),
  ];
  static const double areolarGland = 0.6;

  /// The ducts' orifices on the nipple, and how wide each is drawn.
  static const List<Offset> orifices = <Offset>[
    Offset(-1.6, -1.9),
    Offset(1.2, -2.4),
    Offset(2.6, 0.3),
    Offset(0.8, 2.3),
    Offset(-2.2, 1.4),
    Offset(-0.2, -0.1),
  ];
  static const double orifice = 0.22;

  /// Where the body goes into the breast: on a duct under the areola, below
  /// the cut, where GTEx's subareolar region lies seen from the front. The
  /// drawing is laid so that this lies on the place the body's outline of it
  /// is gone into.
  static const Offset site = Offset(0, 10.5);

  // The gland.

  /// The five duct systems that run into the lower half, of the nine round
  /// the nipple: each its way out from the nipple, in degrees below the
  /// level toward the body's left (0, the screen's right, to 180, its
  /// left), how far its lobe reaches, how widely its lobe spreads either
  /// side of it, in degrees, and the seed its branches and its edge are
  /// laid by.
  static const List<(double, double, double, int)> lobes =
      <(double, double, double, int)>[
        (24, 45, 15, 1),
        (58, 51, 15.5, 2),
        (90, 47, 14, 3),
        (124, 53, 16, 4),
        (155, 44, 14.5, 5),
      ];

  /// How far out from the nipple's middle the lobes begin, past the
  /// areola's edge, and where each main duct first branches, 8 mm out from
  /// the nipple's edge (Ramsay).
  static const double lobeFrom = 24;
  static const double firstBranch = 14;

  /// How wide each generation of a duct is: the main duct, its first
  /// branches and theirs, and the terminal ducts and the short ones the
  /// lobules bud from.
  static const List<double> ductWidths = <double>[1.2, 0.9, 0.65, 0.45, 0.3];

  /// How far a lobe's lobulated edge reaches in and out, and over how many
  /// bumps along its outer edge and its sides.
  static const double lobeBumps = 1.8;
  static const double lobeRipples = 1;

  /// A lobule, a terminal duct lobular unit, across (Wetstein, before the
  /// menopause); how many lie in a cluster at a terminal duct's end, and in
  /// one at a short duct's, and how far out from the end each cluster
  /// spreads.
  static const double lobule = 0.74;
  static const int cluster = 6;
  static const int bud = 2;
  static const double clusterReach = 1.3;

  /// How far apart the short ducts bud from the last branches, and how
  /// long each is.
  static const double budApart = 4.5;
  static const double budLength = 1.8;

  // The fat and its ligaments.

  /// How far apart the fat's lobules lie, centre to centre.
  static const double fatLobule = 6;

  /// The suspensory ligaments: their ways out from the nipple through the
  /// fat to the skin, in degrees as [lobes], and how wide each is.
  static const List<double> ligaments = <double>[20, 41, 62, 90, 108, 128, 158];
  static const double ligament = 0.6;

  // What lies round it.

  /// The pectoralis major, under and round the breast: its sternal border
  /// down to the sixth cartilage, its lower border rising behind the breast
  /// to the anterior axillary fold, the fold out toward the humerus, the
  /// tendon, and the clavicle's medial half back to the sternum; and the
  /// place its fibres converge on, at the tendon.
  static const List<Offset> pectoralis = <Offset>[
    Offset(107, -118),
    Offset(107, 62),
    Offset(96, 66),
    Offset(70, 60),
    Offset(36, 47),
    Offset(0, 30),
    Offset(-36, 9),
    Offset(-66, -17),
    Offset(-88, -40),
    Offset(-106, -64),
    Offset(-124, -90),
    Offset(-142, -112),
    Offset(-150, -124),
    Offset(-120, -128),
    Offset(-60, -132),
    Offset(20, -126),
    Offset(80, -120),
  ];
  static const Offset insertion = Offset(-152, -122);

  /// How far apart its fascicles are drawn, along its origin.
  static const double fascicle = 5;

  /// The internal thoracic artery's branches through the first, second and
  /// third intercostal spaces, each from under the breast's medial edge out
  /// to where it leaves the chest wall beside the sternum, cut there.
  static const List<AnatomyTube> perforators = <AnatomyTube>[
    AnatomyTube(
      <Offset>[Offset(52, -40), Offset(70, -58), Offset(88, -74)],
      <double>[0.55, 0.55, 0.55],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[Offset(64, -28), Offset(79, -40), Offset(91, -46)],
      <double>[0.65, 0.65, 0.65],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[Offset(70, -7), Offset(82, -13), Offset(92, -17)],
      <double>[0.55, 0.55, 0.55],
      cutEnd: true,
    ),
  ];

  /// The lateral thoracic artery, from below, where it fades out, up beside
  /// the breast's lateral edge to where it comes from under the
  /// pectoralis's lateral border, cut there.
  static const AnatomyTube lateralThoracic = AnatomyTube(
    <Offset>[
      Offset(-82.5, 34),
      Offset(-87, 14),
      Offset(-91.5, -8),
      Offset(-96, -30),
      Offset(-99, -49),
    ],
    <double>[0.65, 0.7, 0.75, 0.8, 0.8],
    fadeIn: 14,
    cutEnd: true,
  );

  /// The small branches into the breast's edge: about how far apart along
  /// an artery, and how much more or less, how near the edge it must run to
  /// send one, how far ahead or behind along it each leans, how far under
  /// the edge each goes, and how wide each is.
  static const double branchApart = 22;
  static const double branchJitter = 4;
  static const double branchReach = 18;
  static const double branchLean = 3;
  static const double branchUnder = 2;
  static const double branch = 0.3;

  // Where the parts are named.

  /// The areola, in its upper half off the nipple, toward the middle; the
  /// pectoralis, above
  /// the breast toward the middle; the fat, low on the lateral side; a
  /// ligament, low on the medial side; the gland, a lobe below the site.
  static const Offset areolaName = Offset(10, -15);
  static const Offset pectoralisName = Offset(30, -72);
  static const Offset fatName = Offset(-44, 30);
  static const Offset ligamentName = Offset(40, 42);
  static const Offset glandName = Offset(0, 32);
}
