import 'dart:ui';

import '../../tube_course.dart';

/// The gallbladder the anatomogram draws for the gallbladder, laid open
/// from the front with its ducts, as Gray's plate lays it open (Fig. 1095,
/// after Spalteholz): its front wall cut away, so that what is seen is the
/// inside of its back half, the half that lies in the liver's fossa, and
/// the wall cut through all round it. It is drawn from general anatomy, in
/// millimetres, x across to the body's left, y down, from about the middle
/// of its outline's box, as the body shows it from the front: its fundus to
/// the body's right, its body and neck rising toward the porta.
///
/// Its mucosa, raised into a fine net of folds, a honeycomb; at the neck,
/// curving on itself like an S, the folds turning oblique, a spiral valve;
/// the neck narrowing to the cystic duct, laid open on with it, its
/// crescentic folds across it; round it all, the cut wall's coats. Outside
/// it, the hepatic duct coming down from the porta, joined by the cystic
/// duct at an acute angle, and running on as the common bile duct, cut
/// short below; and the cystic artery, cut short at the right hepatic
/// artery, coming down to the neck and running on along the attached side.
///
/// What is measured. After Gray (1918, pp. 1197-1199, read in the
/// archive.org text of the 20th edition, and Figs. 1095 and 1096): the
/// gallbladder is "a conical or pear-shaped musculomembranous sac", "from 7
/// to 10 cm. in length, 2.5 cm. in breadth at its widest part", holding 30
/// to 35 c.c.; a fundus, a body and a neck, the fundus "directed downward,
/// forward, and to the right", the body and neck "upward and backward to
/// the left"; the neck "narrow, and curves upon itself like the letter S",
/// with "a well-marked constriction" where it meets the cystic duct; three
/// coats, serous, fibromuscular and mucous, the serous coat investing the
/// fundus whole but the body and neck "only on their under surfaces"; the
/// fibromuscular coat "a thin but strong layer" of dense fibrous tissue
/// mixed with plain muscle fibres; the mucosa "elevated into minute rugae",
/// and opposite the neck "oblique ridges or folds, forming a sort of spiral
/// valve"; the cystic duct about 4 cm long, running "backward, downward, and
/// to the left" from the neck, its mucosa "thrown into a series of
/// crescentic folds, from five to twelve in number", directed obliquely
/// round it, "much the appearance of a continuous spiral valve"; the hepatic
/// duct passing "downward and to the right for about 4 cm", "joined at an
/// acute angle by the cystic duct"; the common bile duct about 7.5 cm long,
/// "of the diameter of a goose-quill"; the cystic artery, "usually a branch
/// of the right hepatic", passing "downward and forward along the neck" and
/// dividing into a branch on the free surface and one on the attached. On
/// ultrasound a normal gallbladder is under 10 by 4 by 4 cm, its wall under
/// 3 mm, 1 to 2 mm in the literature's lower measurements, and Hartmann's
/// pouch, an outpouching where the gallbladder narrows to the cystic duct,
/// is found in 4.7 to 52% (Lucius et al. 2025, Life 15:941). The wall has
/// no muscularis mucosae and no submucosa; under its muscle lies the
/// perimuscular connective tissue, continuous on the hepatic side with the
/// liver's (Rana et al. 2025, Indian J Radiol Imaging 35:218). The cystic
/// duct is 4.21 mm across, the pooled mean of 105 studies, and joins the
/// hepatic duct most often on its right side, at its middle level
/// (Plutecki et al. 2026, Ann Anat 266:152857); the cystic artery comes
/// from the right hepatic artery in 86%, runs above and medial to the
/// cystic duct, is 21.3 mm long and mostly over 1 mm across (Triantafyllou
/// et al. 2025, Ann Anat 257:152343). The bile duct is 3.1 to 4.4 mm across
/// (Hela and Maitra 2025, as the liver's drawing has it).
///
/// Drawing choices, measured by none of these: the outline, 90 mm long, as
/// the zoom's card has it, and 34 mm across at its widest, between Gray's
/// 2.5 cm and the ultrasound's 4, broadest toward the fundus; its tilt, about a sixth of a right angle,
/// between the female anatomogram's and the male's; the wall 2 mm through
/// the fundus and body, thinning down the neck, and the coats' shares of
/// it; the serosa drawn all round, a hair thin, though Gray has it under
/// the body and neck alone; the honeycomb's meshes about 2 mm across, as
/// Gray's plate draws them (about a forty-fifth of the sac's length), the
/// same everywhere; three oblique folds in the neck and eight in the cystic
/// duct; the pouch 5 mm deep; the cystic duct's course and how long it is
/// laid open; where the hepatic duct comes in and where the bile duct is
/// cut; the artery's course and width, and how far along the attached side
/// it is drawn.
abstract final class GallbladderAnatomy {
  /// How long the gallbladder is, fundus to neck, across: its outline's
  /// longest side, seen from the front.
  static const double length = 90;

  /// The sac's middle line, from the fundus's middle to the neck's end,
  /// where the cystic duct begins; how wide it is to either side at each of
  /// those points (the fundus and the neck's end rounded by theirs); and how
  /// thick its wall is there.
  static const List<Offset> spine = <Offset>[
    Offset(-28.5, 4.5),
    Offset(-11, 1),
    Offset(6, -3.5),
    Offset(20, -9.5),
    Offset(29.5, -15.5),
    Offset(37.5, -14.5),
    Offset(42.3, -8.5),
  ];
  static const List<double> half = <double>[16.5, 17, 14, 8.6, 5.3, 3.9, 3];
  static const List<double> wall = <double>[2, 2, 2, 1.8, 1.4, 1.2, 1];

  /// Which of [spine]'s points the neck starts at: the honeycomb runs up to
  /// it, and the oblique folds take over beyond.
  static const int neckFrom = 3;

  /// Hartmann's pouch, on the neck's under side where it leaves the body:
  /// how far along the middle line from [spine]'s first point, how deep and
  /// how long.
  static const double pouchAt = 55;
  static const double pouchDepth = 5;
  static const double pouchLength = 10;

  /// The wall's coats, from the outside in, each a share of the wall at
  /// most so many millimetres: the serosa, the perimuscular connective
  /// tissue, and the mucosa; the fibromuscular coat is the rest.
  static const double serosaShare = 0.06;
  static const double serosaMost = 0.12;
  static const double perimuscularShare = 0.42;
  static const double perimuscularMost = 0.9;
  static const double mucosaShare = 0.16;
  static const double mucosaMost = 0.3;

  /// Where the body goes into the gallbladder, in its back wall, in the
  /// body toward the fundus: the drawing is laid so that this lies on the
  /// place the body's outline of it is gone into.
  static const Offset site = Offset(-12.6, 1.4);

  // The mucosa.

  /// The honeycomb's meshes: how far apart their middles lie, how far each
  /// strays from its lattice, a share of that, and how many times they are
  /// evened out as packed cells are.
  static const double mesh = 2;
  static const double meshJitter = 0.35;
  static const int meshRelax = 2;

  /// The neck's oblique folds: how far along its middle line each crosses,
  /// a share of the way from the neck's start to its end; how far across
  /// the lumen each reaches, a share of it; and how far it slants along the
  /// way, millimetres from its root to its tip.
  static const List<double> neckFolds = <double>[0.22, 0.48, 0.74];
  static const double neckFoldReach = 0.72;
  static const double neckFoldSlant = 2.6;

  // The cystic duct, laid open.

  /// Its middle line, from inside the neck's end down to the hepatic
  /// duct's side, where it opens into it; its lumen's half-width and its
  /// wall.
  static const List<Offset> cysticDuct = <Offset>[
    Offset(41.2, -10),
    Offset(44.5, -3.5),
    Offset(44.5, 2.5),
    Offset(47.2, 8),
    Offset(46.6, 13.5),
    Offset(48.2, 18),
    Offset(49.6, 20.8),
  ];
  static const double cysticLumen = 2.1;
  static const double cysticWall = 0.7;

  /// Its crescentic folds: how many, and how far across the lumen each
  /// reaches, a share of it, from either side in turn; how far each slants
  /// along the way, millimetres from its root to its tip.
  static const int cysticFolds = 8;
  static const double cysticFoldReach = 0.78;
  static const double cysticFoldSlant = 1.6;

  // What runs on beside it, cut short.

  /// The hepatic duct, coming down from the porta above, where it fades,
  /// to the cystic duct's opening, and on as the common bile duct, down to
  /// where it is cut short.
  static const AnatomyTube bileDuct = AnatomyTube(
    <Offset>[
      Offset(56.5, -28),
      Offset(55, -12),
      Offset(52.8, 5),
      Offset(51.6, 21),
      Offset(51.9, 31),
      Offset(52.6, 41),
    ],
    <double>[2, 2, 2, 2.1, 2.2, 2.2],
    fadeIn: 10,
    cutEnd: true,
  );

  /// The cystic artery, from along the gallbladder's attached side, where
  /// it fades, up past the neck to the right hepatic artery, where it is
  /// cut short.
  static const AnatomyTube cysticArtery = AnatomyTube(
    <Offset>[
      Offset(-6, -19.3),
      Offset(8, -20.3),
      Offset(20, -22.2),
      Offset(29, -24.3),
      Offset(38, -26.5),
      Offset(46, -30.5),
    ],
    <double>[0.6, 0.65, 0.7, 0.75, 0.75, 0.75],
    fadeIn: 9,
    cutEnd: true,
  );

  // Where the parts are named.

  /// The fundus, in its round end; the neck, in its first bend; the cystic
  /// duct, at its middle; the common bile duct, below the cystic duct's
  /// opening; the cystic artery, past the neck; and the liver, in the
  /// figure's liver above the gallbladder, which lies in its fossa, where
  /// no other part of either figure lies over it.
  static const Offset fundusName = Offset(-35, 13);
  static const Offset neckName = Offset(31, -15);
  static const Offset cysticName = Offset(47.5, 15);
  static const Offset bileDuctName = Offset(52, 33);
  static const Offset arteryName = Offset(38, -26.5);
  static const Offset liverName = Offset(-8, -36);
}
