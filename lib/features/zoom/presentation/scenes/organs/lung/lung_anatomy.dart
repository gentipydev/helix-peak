import 'dart:ui';

/// An airway of the left lung's cut face, laid open along its length: its
/// middle line through [course], [radius] to either side, its wall
/// included; its [generation] counted from the trachea, 0; and whether the
/// form goes on to branch it further ([forks]).
typedef LungAirway = ({
  List<Offset> course,
  double radius,
  int generation,
  bool forks,
});

/// The lungs the anatomogram draws for the lung, in place, seen from the
/// front, the trachea coming down between them: the right lung whole, and
/// the left lung cut open from front to back, so that its bronchi, its
/// vessels and its substance show on the cut face. They are drawn from
/// general anatomy, in millimetres, x across to the body's left, y down,
/// from the middle line at the height of the left lung's apex.
///
/// The left lung is the one the zoom goes into: the GTEx Portal's sampling
/// site for the lung is "Inferior segment of left upper lobe, 1 cm below
/// the pleural surface" (gtex_v10, read on 2026-11-11), the lingula's lower
/// segment, and the Atlas's reading of a lung's cell types is made from
/// GTEx's samples. Its cut is a composite, as an anatomy plate's is: the
/// lobes as the lung shows them from the front, the oblique fissure running
/// from high on its costal border down to its base, the upper lobe above
/// and in front with the lingula below the cardiac notch, the lower lobe a
/// wedge behind and below; the root entering at the hilum; the upper lobe's
/// bronchi, with the arteries beside them, laid open where they run in the
/// cut, and the lower lobe's cut across where they cross it.
///
/// What is measured. After Gray (1918, pp. 1084-1098, read in the
/// archive.org text of the 20th edition): the trachea "measures about 11
/// cm. in length; its diameter, from side to side, is from 2 to 2.5 cm.",
/// its cartilages "from sixteen to twenty in number", each "about 4 mm. in
/// depth"; it divides at "the upper border of the fifth thoracic
/// vertebra". The right bronchus, "wider, shorter, and more vertical in
/// direction than the left, is about 2.5 cm. long"; the left, "smaller in
/// caliber but longer", "nearly 5 cm. long", "passes beneath the aortic
/// arch" and "has the left pulmonary artery lying at first above, and then
/// in front of it". The root of the left lung, "a little above the middle
/// of the mediastinal surface", is from above downward "pulmonary artery,
/// bronchus, pulmonary veins", the lower vein "at the apex or lowest part
/// of the hilus", the upper "in front". The apex reaches "from 2.5 to 4 cm.
/// above the level of the sternal end of the first rib"; the base is
/// "broad, concave"; the anterior border of the left lung "presents, below,
/// an angular notch, the cardiac notch, in which the pericardium is
/// exposed". The left lung's fissure "crosses" its posterior border "about
/// 6 cm. below the apex", "extends downward and forward over the costal
/// surface, and reaches the lower border a little behind its anterior
/// extremity"; the upper lobe "includes the apex, the anterior border";
/// the lower lobe "comprises almost the whole of the base". The right
/// lung's oblique fissure is "more vertical" and "cuts the lower border
/// about 7.5 cm. behind its anterior extremity"; its horizontal fissure
/// "cuts the anterior border on a level with the sternal end of the fourth
/// costal cartilage"; the right lung is "shorter by 2.5 cm. than the left"
/// and "broader". The surface is "marked out into numerous polyhedral
/// areas, indicating the lobules", and the secondary lobules "on the
/// surface are large", "those in the interior smaller"; the larger
/// intrapulmonary bronchi have "irregular plates of hyaline cartilage, most
/// developed at the points of division". The bronchi's calibres by
/// generation are Weibel's (1963, Morphometry of the Human Lung, model A):
/// 12.2 mm for the main bronchi, 8.3 for the lobar, 5.6 for the segmental,
/// then 4.5, 3.5, 2.8 and 2.3. The secondary lobule is 1 to 2.5 cm across
/// (Webb 2006, Radiology 239:322; Radiopaedia, "Secondary pulmonary
/// lobule"). The angle between the main bronchi is 77 ± 13 degrees on CT
/// (Karabulut 2005, Br J Radiol 78:787). The pulmonary trunk is 25.1 ± 2.8
/// mm across (Truong et al. 2012, Circ Cardiovasc Imaging 5:147).
///
/// Drawing choices, measured by none of these: the left lung 250 mm from
/// its apex to the lowest point of its base, as the zoom's card has it, and
/// about 118 mm across; both outlines, the cardiac notch and the lingula;
/// the right lung 25 mm shorter and 12 mm broader; the trachea 20 mm
/// across, the narrower end of Gray's, cut short 14 mm above the apices,
/// its cartilages evenly spaced, 15 in the 90 mm drawn; the
/// main bronchi at 25 and 50 degrees from the trachea's line; the courses
/// of the segmental bronchi, laid by hand after the left lung's segments
/// (apicoposterior, anterior, superior and inferior lingular), and the
/// branching past them, which the form makes by rule; the left pulmonary
/// artery 18 mm across and each artery beside its bronchus a little
/// narrower than it; the veins' courses between the segments; the lower
/// lobe's bronchi cut across where they are placed; the lobules 17 mm
/// apart; the site's place in the lingula, 10 mm in from its pleura.
abstract final class LungAnatomy {
  /// Where the zoom goes in: in the lingula's lower segment, 10 mm in from
  /// the pleura, as GTEx samples the lung.
  static const Offset site = Offset(37, 224);

  /// How tall the left lung is, from its apex to the lowest point of its
  /// base: the zoom's card's 25 cm.
  static const double height = 250;

  /// The left lung's outline, the cut's edge, round from its apex down its
  /// costal border, back along its base and up its mediastinal border: the
  /// lingula below the cardiac notch, and the hilum above it.
  static const List<Offset> leftOutline = <Offset>[
    Offset(31, 0),
    Offset(46, 3),
    Offset(62, 12),
    Offset(78, 27),
    Offset(93, 48),
    Offset(106, 74),
    Offset(115, 104),
    Offset(122, 136),
    Offset(127, 168),
    Offset(129, 198),
    Offset(129, 224),
    Offset(126.5, 242),
    Offset(121, 250),
    Offset(110, 247),
    Offset(96, 241),
    Offset(82, 236.5),
    Offset(68, 234.5),
    Offset(55, 236),
    Offset(45, 239),
    Offset(36, 239),
    Offset(29, 234),
    Offset(25.5, 224),
    Offset(25.5, 212),
    Offset(30, 201),
    Offset(36.5, 191),
    Offset(41, 178),
    Offset(42, 163),
    Offset(39, 150),
    Offset(32, 140),
    Offset(23, 132),
    Offset(15.5, 125),
    Offset(12.5, 110),
    Offset(11.5, 94),
    Offset(11.5, 78),
    Offset(12, 58),
    Offset(13.5, 38),
    Offset(16.5, 20),
    Offset(22, 7),
  ];

  /// The right lung's outline, round from its apex down its mediastinal
  /// border, along its base and up its costal border: 25 mm shorter than
  /// the left, broader, its anterior border nearly upright.
  static const List<Offset> rightOutline = <Offset>[
    Offset(-41, 1),
    Offset(-32, 7),
    Offset(-24, 19),
    Offset(-19, 37),
    Offset(-16, 58),
    Offset(-15, 80),
    Offset(-14.5, 104),
    Offset(-14.5, 130),
    Offset(-14, 158),
    Offset(-13.5, 186),
    Offset(-14, 207),
    Offset(-18, 219),
    Offset(-27, 223),
    Offset(-42, 219),
    Offset(-60, 214),
    Offset(-80, 212),
    Offset(-100, 215),
    Offset(-118, 221),
    Offset(-131, 227),
    Offset(-138.5, 222),
    Offset(-141, 204),
    Offset(-140, 176),
    Offset(-135, 145),
    Offset(-127, 112),
    Offset(-116, 81),
    Offset(-103, 53),
    Offset(-88, 30),
    Offset(-72, 14),
    Offset(-56, 4),
  ];

  /// The left lung's oblique fissure, from the costal border down to the
  /// base, run a little past the outline at either end; the upper lobe lies
  /// on its left hand from its start, toward the middle line.
  static const List<Offset> fissure = <Offset>[
    Offset(119, 86),
    Offset(110, 112),
    Offset(101, 142),
    Offset(91, 175),
    Offset(81, 207),
    Offset(73, 231),
    Offset(70, 242),
  ];

  /// The right lung's oblique fissure, from the costal border down to the
  /// base, and its horizontal fissure, from the anterior border across to
  /// the oblique one: each run a little past where it ends.
  static const List<Offset> rightOblique = <Offset>[
    Offset(-138, 112),
    Offset(-124, 140),
    Offset(-108, 168),
    Offset(-91, 191),
    Offset(-75, 207),
    Offset(-66, 218),
  ];
  static const List<Offset> rightHorizontal = <Offset>[
    Offset(-12, 121),
    Offset(-40, 124),
    Offset(-72, 125),
    Offset(-103, 124),
    Offset(-129, 121),
  ];

  // The trachea and the main bronchi.

  /// Where the trachea divides, and its course up from there to where it is
  /// cut short, a little above the apices: 90 mm of Gray's 11 cm.
  static const Offset carina = Offset(0, 74);
  static const List<Offset> trachea = <Offset>[
    Offset(0, 76),
    Offset(0, 46),
    Offset(0, 14),
    Offset(0, -14),
  ];
  static const double tracheaRadius = 10;

  /// How many cartilages ring the trachea, how deep each is, and how far
  /// above the carina the lowest lies.
  static const int rings = 15;
  static const double ringDepth = 4;
  static const double ringFrom = 6;

  /// The right main bronchus, 25 mm at 25 degrees from the trachea's line,
  /// on into the right lung's hilum under its mediastinal border; and the
  /// left, 50 mm at 50 degrees, to the left lung's hilum, where the cut
  /// lays it open.
  static const List<Offset> rightBronchus = <Offset>[
    Offset(-2, 71),
    Offset(-10.5, 92.5),
    Offset(-19, 104),
  ];
  static const double rightBronchusRadius = 7;
  static const List<Offset> leftBronchus = <Offset>[
    Offset(2, 72),
    Offset(11, 81),
    Offset(19, 90),
  ];
  static const double leftBronchusRadius = 6.1;

  // The left lung's airways in the cut, laid open.

  /// The main bronchus on from the hilum, the upper lobe's bronchus, its
  /// two divisions, its four segmental bronchi and their larger branches,
  /// laid by hand; the form branches each one marked [LungAirway.forks] on
  /// by rule.
  static const List<LungAirway> airways = <LungAirway>[
    (
      course: <Offset>[Offset(16, 87), Offset(27, 97), Offset(37, 105)],
      radius: 6.1,
      generation: 1,
      forks: false,
    ),
    (
      course: <Offset>[Offset(36, 105), Offset(44, 98), Offset(51, 93)],
      radius: 4.2,
      generation: 2,
      forks: false,
    ),
    // The upper division, its apicoposterior and anterior bronchi.
    (
      course: <Offset>[Offset(50, 94), Offset(54, 82), Offset(57, 71)],
      radius: 3.4,
      generation: 3,
      forks: false,
    ),
    (
      course: <Offset>[
        Offset(57, 72),
        Offset(55, 56),
        Offset(51, 40),
        Offset(47, 27),
      ],
      radius: 2.8,
      generation: 3,
      forks: true,
    ),
    (
      course: <Offset>[
        Offset(57, 72),
        Offset(70, 66),
        Offset(82, 65),
        Offset(92, 68),
      ],
      radius: 2.8,
      generation: 3,
      forks: true,
    ),
    // The lingular bronchus, its superior and inferior bronchi.
    (
      course: <Offset>[Offset(51, 93), Offset(57, 106), Offset(61, 119)],
      radius: 3.4,
      generation: 3,
      forks: false,
    ),
    (
      course: <Offset>[
        Offset(61, 119),
        Offset(74, 130),
        Offset(83, 140),
        Offset(90, 150),
      ],
      radius: 2.6,
      generation: 3,
      forks: true,
    ),
    (
      course: <Offset>[
        Offset(61, 119),
        Offset(64, 142),
        Offset(63, 166),
        Offset(57, 188),
        Offset(50, 204),
      ],
      radius: 2.6,
      generation: 3,
      forks: true,
    ),
    // Their larger branches.
    (
      course: <Offset>[Offset(54, 50), Offset(64, 39), Offset(73, 27)],
      radius: 2.3,
      generation: 4,
      forks: true,
    ),
    (
      course: <Offset>[Offset(50, 36), Offset(43, 26), Offset(39, 18)],
      radius: 2.3,
      generation: 4,
      forks: true,
    ),
    (
      course: <Offset>[Offset(71, 66), Offset(79, 53), Offset(87, 41)],
      radius: 2.3,
      generation: 4,
      forks: true,
    ),
    (
      course: <Offset>[Offset(84, 65), Offset(94, 80), Offset(102, 97)],
      radius: 2.3,
      generation: 4,
      forks: true,
    ),
    (
      course: <Offset>[Offset(76, 132), Offset(87, 121), Offset(99, 113)],
      radius: 2.3,
      generation: 4,
      forks: true,
    ),
    (
      course: <Offset>[Offset(63, 160), Offset(73, 172), Offset(79, 188)],
      radius: 2.3,
      generation: 4,
      forks: true,
    ),
  ];

  /// The lower lobe's bronchus where it leaves the cut, turning back toward
  /// the lobe behind it: cut across, beside the main bronchus's end.
  static const Offset lowerBronchus = Offset(41, 113);
  static const double lowerBronchusRadius = 4.4;

  /// The lower lobe's bronchi cut across where they cross the cut, each
  /// with its artery beside it: middle and radius, in rays down toward the
  /// base, as its basal bronchi fan out behind the cut.
  static const List<(Offset, double)> crossed = <(Offset, double)>[
    (Offset(108, 136), 2.6),
    (Offset(111, 164), 2.3),
    (Offset(115, 192), 2.0),
    (Offset(117, 219), 1.7),
    (Offset(98, 180), 2.4),
    (Offset(100, 206), 2.0),
    (Offset(97, 229), 1.6),
    (Offset(84, 222), 1.5),
  ];

  /// How the form branches an airway on: as far as which generation, each
  /// generation's radius from the fourth on (Weibel's calibre, its wall
  /// included), how long a branch is in its generation, how far a branch
  /// turns from its parent's way at a fork, the smaller of two more.
  static const int deepest = 6;
  static const List<double> branchRadius = <double>[2.3, 1.85, 1.45];
  static const List<double> branchLength = <double>[20, 15, 11];
  static const double branchTurn = 0.3;
  static const double branchTurnMinor = 0.62;

  /// Where along a segmental bronchus the form branches it to the side, to
  /// either side in turn: shares of its length.
  static const List<double> sideBranches = <double>[0.35, 0.68];

  // The vessels.

  /// The left pulmonary artery: cut short in the mediastinum, above the
  /// main bronchus, and its course on from the hilum, laid open in the
  /// cut, arching over the bronchus to where it turns back behind it.
  static const List<Offset> artery = <Offset>[
    Offset(9, 72),
    Offset(13, 72),
    Offset(18, 73),
  ];
  static const List<Offset> arteryCut = <Offset>[
    Offset(15, 75),
    Offset(26, 76),
    Offset(35, 81),
  ];
  static const double arteryRadius = 8;

  /// Each artery beside its bronchus, a share of the bronchus's radius, and
  /// how far apart the two run, a share of the artery's radius past the
  /// bronchus's edge.
  static const double arteryShare = 0.6;
  static const double arteryGap = 0.3;

  /// The way an artery lies from its bronchus, as near as the bronchus's
  /// course lets it: toward the apex and the costal border.
  static const Offset arteryToward = Offset(0.6, -0.8);

  /// The pulmonary veins: the upper one cut short in the mediastinum and
  /// laid open from the hilum to where it turns back; the lower one below
  /// it, cut short, where it leaves the lung at the hilum's lowest point.
  static const List<Offset> upperVein = <Offset>[
    Offset(8, 113),
    Offset(12, 113),
    Offset(18, 113),
  ];
  static const double upperVeinRadius = 6;
  static const List<Offset> upperVeinCut = <Offset>[
    Offset(16, 113),
    Offset(26, 118),
    Offset(33, 122),
  ];
  static const double upperVeinCutRadius = 5;
  static const List<Offset> lowerVein = <Offset>[
    Offset(9, 124),
    Offset(13, 123.5),
    Offset(19, 122),
  ];
  static const double lowerVeinRadius = 5.5;

  /// The veins cut across between the segments, where they cross the cut
  /// away from the bronchi: middle and radius. A vein the airways laid
  /// past the segments come too near is left out.
  static const List<(Offset, double)> veinsCrossed = <(Offset, double)>[
    (Offset(75, 42), 2.2),
    (Offset(91, 54), 1.8),
    (Offset(66, 88), 2.6),
    (Offset(84, 92), 2.2),
    (Offset(101, 98), 1.8),
    (Offset(78, 112), 2.0),
    (Offset(77, 170), 2.4),
    (Offset(86, 192), 2.0),
    (Offset(69, 197), 1.8),
    (Offset(104, 151), 1.6),
    (Offset(122, 205), 1.4),
    (Offset(90, 238), 1.4),
  ];

  // The lobules.

  /// How far apart the secondary lobules' middles lie, how unevenly they
  /// are laid, and how far in from the pleura their septa show: marked
  /// under the pleura, fading toward the hilum.
  static const double lobule = 17;
  static const double lobuleJitter = 0.35;
  static const int lobuleRelax = 2;
  static const double septaReach = 32;

  /// How far a bronchus keeps from the outline, the fissure and the site,
  /// past its radius.
  static const double edgeClear = 6;
  static const double fissureClear = 4;
  static const double siteClear = 9;

  // Where the parts are named.

  static const Offset tracheaName = Offset(0, 4);
  static const Offset bronchusName = Offset(32, 101);
  static const Offset arteryName = Offset(25, 76);
  static const Offset upperLobeName = Offset(80, 40);
  static const Offset lowerLobeName = Offset(114, 196);
  static const Offset rightLungName = Offset(-95, 160);
}
