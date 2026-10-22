import 'dart:ui';

/// The heart the anatomogram draws for heart muscle, cut open from front to
/// back and seen from the front, as the body shows it: its right on the
/// left. It is drawn from general anatomy, in millimetres, x across to the
/// body's left, y down, from the crux, the top of the muscular septum
/// where the four chambers meet.
///
/// The cut is the one every textbook draws (Gray 1918; OpenStax Anatomy and
/// Physiology 2e, fig. 19.9): the four chambers side by side, the atria
/// above, the ventricles below the valves, the septum running down to the
/// apex, and the great vessels rising above them, cut open with it. No one
/// plane holds all of that: the right ventricle lies in front of the left,
/// and the great arteries cross each other as they leave. It is a
/// composite, each part at the size it is measured at.
///
/// Sizes keep to what is measured, in men in diastole. The left ventricle
/// is 52 ± 5 mm across in the four-chamber view; its compact wall 8.3 mm
/// thick at the base, 7.2 at the middle and 5.6 at the apex; the septum 9.0
/// at the base (Kawel-Boehm et al. 2020, J Cardiovasc Magn Reson 22:87,
/// tables 7, 26 and 27). The right ventricle's free wall is 3 to 5 mm
/// thick (Lang et al. 2015, Eur Heart J Cardiovasc Imaging 16:233). The
/// left atrium is 58 by 43 mm and the right 53 by 48 in the four-chamber
/// view (Kawel-Boehm et al. 2020, tables 15 and 18); atrial walls are about
/// 2 mm (1.1 to 2.0 on CT, 2.2 to 2.8 by calipers). The aortic annulus is
/// 23 mm across, its sinus 32 and the sinotubular junction 25; the
/// ascending aorta 27 to 35 with age; the pulmonary trunk 23, its branches
/// 17 to 20 (Kawel-Boehm et al. 2020, tables 39, 40, 42 and 56). The
/// mitral annulus has an area of 7 to 8 cm² in diastole, about 31 mm
/// across (Nemes et al. 2025, Quant Imaging Med Surg 15:4748); the
/// tricuspid annulus is 33 ± 4 mm across in the four-chamber view (Muraru
/// et al. 2022, Front Cardiovasc Med 9:1011931). The pulmonary veins open
/// 9 to 13 mm wide (Kim et al. 2005, Radiology 235:43); the inferior vena
/// cava is at most 21 mm (Rudski et al. 2010, J Am Soc Echocardiogr
/// 23:685). The coronary arteries' lumens are 2.8 to 4.2 mm near their
/// origins (Dodge et al. 1992, Circulation 86:232).
///
/// Drawing choices, measured by none of these: the long axis 25° from
/// upright, more upright than a heart lies, as the anatomogram and the
/// textbooks draw it; the left ventricle 86 mm long; the leaflets' lengths
/// (the mitral's anterior 22 mm and posterior 13, within what is measured
/// of them); the papillary muscles' and the moderator band's sizes; the
/// courses of the great vessels, the arch lower than it rises and every
/// vessel cut short; the superior vena cava 20 mm across; the fat in the
/// grooves.
abstract final class HeartAnatomy {
  /// How far the long axis, from the base to the apex, leans from upright,
  /// toward the body's left, in degrees.
  static const double tilt = 25;

  // The left ventricle, in its own frame: u down its axis from the middle
  // of its base, v across it toward its free wall.

  /// How long its cavity is, from its base to the apex, and how wide at its
  /// widest.
  static const double lvLength = 86;
  static const double lvWidth = 52;

  /// How far down its axis the cavity is widest.
  static const double lvWidest = 17;

  /// The free wall's thickness at the base, the middle and the apex, and
  /// the septum's.
  static const List<double> freeWall = <double>[8.3, 7.2, 5.6];
  static const List<double> septum = <double>[9.0, 8.0, 6.5];

  /// How far down the axis the middle and the apex's thickness hold.
  static const double wallMiddle = 43;
  static const double wallApex = 73;

  /// Where the mitral annulus begins, across the base from its middle
  /// toward the septum: the aortic-mitral curtain, the anterior leaflet's
  /// hinge.
  static const double mitralFrom = -7;

  // The right ventricle.

  /// How far below the base the septal leaflet of the tricuspid valve is
  /// hinged, and how wide the annulus is, and how much lower its lateral
  /// end lies.
  static const double tricuspidDrop = 7;
  static const double tricuspid = 33;
  static const double tricuspidLean = 4;

  /// How far down the left ventricle's axis the right ventricle's apex
  /// meets the septum.
  static const double rvApex = 65;

  /// The free wall's thickness.
  static const double rvWall = 4;

  /// The free wall's endocardium, from the tricuspid annulus's lateral
  /// hinge round to the apex.
  static const List<Offset> rvFree = <Offset>[
    Offset(-30, 40),
    Offset(-20, 53),
    Offset(0, 61),
    Offset(20, 63),
  ];

  // The atria.

  /// The atria's walls, and the right atrium's and the left's outside, from
  /// the interatrial septum round over the top to the atrioventricular
  /// groove.
  static const double atrialWall = 2;
  static const List<Offset> raOutside = <Offset>[
    Offset(-12, -46),
    Offset(-26, -50),
    Offset(-42, -46),
    Offset(-52, -32),
    Offset(-56, -14),
    Offset(-55, 4),
    Offset(-50, 18),
  ];
  static const List<Offset> laOutside = <Offset>[
    Offset(4, -50),
    Offset(18, -57),
    Offset(36, -58),
    Offset(50, -52),
    Offset(58, -40),
    Offset(60, -30),
  ];

  // The valves, as long as their leaflets are.

  static const double mitralAnterior = 22;
  static const double mitralPosterior = 13;
  static const double tricuspidAnterior = 20;
  static const double tricuspidSeptal = 14;

  // The papillary muscles: where each rises from its wall, how long it is
  // and how wide at its base. The left ventricle's anterolateral one rises
  // from its free wall and its posteromedial one beside the septum, so far
  // down its axis; the right's anterior one from its free wall, so far along
  // it from the tricuspid annulus, and its septal one from the septum, so
  // far down the left's axis (its posterior one lies behind the cut). The
  // moderator band crosses the right ventricle from the septum to the
  // anterior one's base.

  static const double anterolateral = 50;
  static const double posteromedial = 56;
  static const (double, double) lvPapillary = (24, 11);
  static const double rvAnterior = 0.55;
  static const (double, double) rvAnteriorSize = (18, 8);
  static const double rvSeptal = 16;
  static const (double, double) rvSeptalSize = (6, 4);
  static const double moderator = 38;
  static const double moderatorWidth = 4;

  /// How many chordae run from each papillary muscle to its leaflets.
  static const int chordae = 5;

  // The great vessels: each a course, how wide at each point of it (radii),
  // and its wall.

  static const List<Offset> aorta = <Offset>[
    Offset(-10, -16),
    Offset(-11, -26),
    Offset(-12, -36),
    Offset(-13, -50),
    Offset(-6, -62),
    Offset(8, -66),
    Offset(22, -62),
    Offset(30, -53),
  ];
  static const List<double> aortaRadii = <double>[
    11.5,
    16,
    12.5,
    15,
    13,
    13,
    13,
    12,
  ];
  static const double aortaWall = 2.2;

  /// How far from its root the aorta is cut open, through its valve, its
  /// sinus and its sinotubular junction, and the pulmonary trunk, through
  /// its valve: whole beyond.
  static const double aortaOpen = 22;
  static const double trunkOpen = 10;

  /// The arch's three branches: the brachiocephalic trunk, the left common
  /// carotid and the left subclavian artery.
  static const List<List<Offset>> branches = <List<Offset>>[
    <Offset>[Offset(-8, -70), Offset(-10, -86)],
    <Offset>[Offset(4, -74), Offset(5, -89)],
    <Offset>[Offset(15, -72), Offset(18, -87)],
  ];
  static const List<double> branchRadii = <double>[6.3, 4, 4.4];
  static const double branchWall = 0.9;

  /// The right ventricle's outflow, its infundibulum, up to the pulmonary
  /// valve, and the trunk on from it to where it divides.
  static const List<Offset> infundibulum = <Offset>[
    Offset(0, 26),
    Offset(3, 8),
    Offset(8, -10),
    Offset(14, -24),
  ];
  static const double infundibulumRadius = 11;
  static const List<Offset> trunk = <Offset>[
    Offset(14, -24),
    Offset(18, -34),
    Offset(22, -44),
  ];
  static const double trunkRadius = 11.5;
  static const List<Offset> leftPulmonary = <Offset>[
    Offset(22, -44),
    Offset(40, -50),
    Offset(58, -50),
  ];
  static const List<Offset> rightPulmonary = <Offset>[
    Offset(22, -44),
    Offset(0, -50),
    Offset(-30, -52),
    Offset(-66, -52),
  ];
  static const double pulmonaryRadius = 9;
  static const double pulmonaryWall = 1.2;

  /// The venae cavae and the pulmonary veins, two each side.
  static const List<Offset> superiorCava = <Offset>[
    Offset(-36, -40),
    Offset(-37, -62),
    Offset(-38, -86),
  ];
  static const List<Offset> inferiorCava = <Offset>[
    Offset(-48, 10),
    Offset(-49, 34),
    Offset(-50, 58),
  ];
  static const double cavaRadius = 10;
  static const List<List<Offset>> rightVeins = <List<Offset>>[
    <Offset>[Offset(-6, -38), Offset(-40, -38), Offset(-68, -36)],
    <Offset>[Offset(-6, -28), Offset(-40, -26), Offset(-61, -24)],
  ];
  static const List<List<Offset>> leftVeins = <List<Offset>>[
    <Offset>[Offset(44, -46), Offset(60, -48), Offset(72, -48)],
    <Offset>[Offset(48, -34), Offset(64, -34), Offset(74, -32)],
  ];
  static const double veinRadius = 6.5;
  static const double veinWall = 1;

  // The coronary arteries, cut across in the fat of the atrioventricular
  // grooves: the right's beside the tricuspid annulus, the circumflex
  // beside the mitral.

  static const double rightCoronary = 3.6;
  static const double circumflex = 3.4;
  static const double coronaryWall = 0.6;
  static const double grooveFat = 5.5;

  // Where each chamber is named.

  static const Offset rightAtrium = Offset(-32, -14);
  static const Offset leftAtrium = Offset(42, -30);
  static const Offset rightVentricle = Offset(-8, 34);
  static const Offset leftVentricle = Offset(38, 24);
}
