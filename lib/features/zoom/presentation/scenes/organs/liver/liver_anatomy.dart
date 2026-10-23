import 'dart:ui';

import '../../tube_course.dart';

/// The liver the anatomogram draws for the liver, cut open from front to
/// back and seen from the front, as the body shows it: its right lobe on
/// the left. It is drawn from general anatomy, in millimetres, x across to
/// the body's left, y down, from the middle of its outline's box.
///
/// The cut is a composite, as a coronal CT of the liver is read: the
/// inferior vena cava rising behind the caudate lobe to the dome, the
/// right, middle and left hepatic veins fanning out of it into the lobes,
/// bare; the portal vein rising to the porta and dividing there, its
/// branches each in a sheath of Glisson's capsule with an artery and a bile
/// duct beside it; the gallbladder in its fossa under the right lobe, its
/// fundus past the lower border; the round ligament in the umbilical
/// fissure, which parts the right lobe from the left; and the small vessels
/// the cut crosses everywhere else, each a portal tract or a hepatic venule.
/// No one plane holds all of that: the cava lies behind the portal vein,
/// and the gallbladder in front of it.
///
/// Sizes keep to what is measured. Fifty livers from cadavers were 199.4 ±
/// 24.5 mm across and 149.5 ± 18.7 mm tall (Gupta, Sodhi and Yadav 2008,
/// Indian J Surg 70:3); on ultrasound, in 2,080 adults, the liver was 14.0 ±
/// 1.7 cm long in the midclavicular line (Kratzer et al. 2003, J Ultrasound
/// Med 22:1155). The main portal vein is 10.79 ± 1.27 mm across in adults
/// without liver disease (Ayele et al. 2022, Int J Gen Med 15:45); the right
/// hepatic vein 8.97 ± 2.29 mm, on CT in 90 living donors (Gündoğdu 2023,
/// Indian J Radiol Imaging 33:332); the inferior vena cava at most 21 mm
/// (Rudski et al. 2010, J Am Soc Echocardiogr 23:685); the common bile duct
/// 3.1 mm in young adults and 4.4 past 55 (Hela and Maitra 2025, Cureus
/// 17:e95232). The gallbladder is 7 to 10 cm long and 2.5 cm broad at its
/// widest, its fundus past the liver's anterior border (Gray 1918). The
/// middle hepatic vein runs on Cantlie's line, from the gallbladder's fossa
/// to the left side of the vena cava; the quadrate lobe lies between the
/// round ligament and the gallbladder's fossa, the caudate lobe beside the
/// vena cava (Marcinkevičiūtė et al. 2026, Front Surg 13:1743615).
///
/// Drawing choices, measured by none of these: the outline, drawn to the
/// anatomogram's own proportions a little taller, 220 mm across, as the
/// zoom's card has it, and 155 tall; the courses of every vessel and its
/// branches; the middle and left hepatic veins 8 and 7 mm across where they
/// meet the cava; the portal vein's branches 9 mm and down; the sheath 2.2
/// mm; the hepatic artery 4.4 mm; the gallbladder, seen foreshortened as a
/// front view sees it, 24 mm across; the round ligament 4.4 mm; the trunks
/// cut short 10 to 40 mm past the liver; and the small vessels, one about
/// every 11 mm, 1.2 to 3 mm across.
abstract final class LiverAnatomy {
  /// How wide the liver is, across from its right lobe to its left.
  static const double length = 220;

  /// The liver's outline, the capsule where the cut crosses it: from the
  /// right lobe's upper lateral corner over the dome to the left lobe's
  /// tip, back along the lower border through the umbilical notch and past
  /// the gallbladder to the right lobe's lowest point, and up its lateral
  /// border.
  static const List<Offset> outline = <Offset>[
    Offset(-100, -42.5),
    Offset(-92, -57.5),
    Offset(-80, -67.5),
    Offset(-62, -74.5),
    Offset(-40, -77.5),
    Offset(-18, -75.5),
    Offset(0, -70.5),
    Offset(14, -65.5),
    Offset(28, -64.5),
    Offset(44, -65.5),
    Offset(62, -62.5),
    Offset(80, -56.5),
    Offset(96, -47.5),
    Offset(106, -40.5),
    Offset(110, -34.5),
    Offset(107, -28.5),
    Offset(96, -22.5),
    Offset(78, -12.5),
    Offset(58, -2.5),
    Offset(40, 6.5),
    Offset(28, 12.5),
    Offset(20, 16.5),
    Offset(14, 9.5),
    Offset(8, 18.5),
    Offset(-4, 25.5),
    Offset(-18, 32.5),
    Offset(-32, 39.5),
    Offset(-46, 49.5),
    Offset(-62, 60.5),
    Offset(-78, 70.5),
    Offset(-92, 77.5),
    Offset(-100, 73.5),
    Offset(-106, 59.5),
    Offset(-109, 37.5),
    Offset(-110, 12.5),
    Offset(-109, -12.5),
    Offset(-106, -30.5),
  ];

  /// Where the body goes into the liver, in its right lobe between the
  /// right and middle hepatic veins: the drawing is laid so that this lies
  /// on the place the body's outline of it is gone into.
  static const Offset site = Offset(-50, -14.5);

  // The hepatic veins and the vena cava: bare channels, emptied.

  /// The inferior vena cava, from where it comes into the cut behind the
  /// caudate lobe up through the dome, cut short above it.
  static const AnatomyTube cava = AnatomyTube(
    <Offset>[
      Offset(-6, -26.5),
      Offset(-6, -42.5),
      Offset(-5, -62.5),
      Offset(-4, -88.5),
    ],
    <double>[7.5, 10.5, 10.5, 10.5],
    cutEnd: true,
  );

  /// The hepatic veins, each from the cava out into its part of the liver,
  /// and their larger tributaries.
  static const List<AnatomyTube> hepaticVeins = <AnatomyTube>[
    // The right, between the right lobe's anterior and posterior sections.
    AnatomyTube(
      <Offset>[
        Offset(-12, -60.5),
        Offset(-32, -53.5),
        Offset(-56, -44.5),
        Offset(-78, -31.5),
        Offset(-97, -14.5),
      ],
      <double>[4.5, 4, 3, 2, 1],
    ),
    AnatomyTube(
      <Offset>[Offset(-56, -44.5), Offset(-70, -58.5), Offset(-82, -64.5)],
      <double>[2, 1.4, 0.8],
    ),
    AnatomyTube(
      <Offset>[Offset(-78, -31.5), Offset(-93, -42.5)],
      <double>[1.4, 0.8],
    ),
    // The middle, down Cantlie's line toward the gallbladder's fossa.
    AnatomyTube(
      <Offset>[
        Offset(-2, -60.5),
        Offset(-8, -45.5),
        Offset(-14, -30.5),
        Offset(-20, -14.5),
      ],
      <double>[4, 3.4, 2.4, 1.2],
    ),
    AnatomyTube(
      <Offset>[Offset(-12, -36.5), Offset(-26, -30.5), Offset(-34, -24.5)],
      <double>[1.6, 1.1, 0.7],
    ),
    // The left, into the left lobe.
    AnatomyTube(
      <Offset>[
        Offset(5, -62.5),
        Offset(26, -57.5),
        Offset(50, -50.5),
        Offset(74, -43.5),
        Offset(94, -37.5),
      ],
      <double>[3.5, 3, 2.2, 1.4, 0.8],
    ),
    AnatomyTube(
      <Offset>[Offset(50, -50.5), Offset(62, -60.5)],
      <double>[1.2, 0.7],
    ),
  ];

  // The portal vein and its branches, each in its sheath.

  /// The portal vein, from below the liver up to the porta, where it
  /// divides; cut short below.
  static const AnatomyTube portalVein = AnatomyTube(
    <Offset>[
      Offset(-6, -0.5),
      Offset(-5, 13.5),
      Offset(-4, 33.5),
      Offset(-4, 71.5),
    ],
    <double>[5.4, 5.4, 5.4, 5.4],
    cutEnd: true,
  );

  /// The portal vein's branches: the right, dividing into its anterior and
  /// posterior branches; the left, its transverse part out to the
  /// umbilical fissure, the umbilical part turning down in it, and its
  /// branches to the left lobe and to the quadrate.
  static const List<AnatomyTube> portalBranches = <AnatomyTube>[
    AnatomyTube(
      <Offset>[Offset(-6, -0.5), Offset(-22, -3.5), Offset(-34, -4.5)],
      <double>[4.5, 4.3, 4],
    ),
    AnatomyTube(
      <Offset>[Offset(-34, -4.5), Offset(-35, -20.5), Offset(-33, -34.5)],
      <double>[2.8, 2, 1.2],
    ),
    AnatomyTube(
      <Offset>[
        Offset(-34, -4.5),
        Offset(-58, 3.5),
        Offset(-80, 15.5),
        Offset(-97, 27.5),
      ],
      <double>[3, 2.4, 1.6, 0.9],
    ),
    AnatomyTube(
      <Offset>[Offset(-62, 5.5), Offset(-70, 25.5), Offset(-76, 45.5)],
      <double>[1.6, 1.1, 0.7],
    ),
    AnatomyTube(
      <Offset>[Offset(-6, -0.5), Offset(6, -4.5), Offset(16, -6.5)],
      <double>[4, 4, 3.8],
    ),
    AnatomyTube(
      <Offset>[Offset(16, -6.5), Offset(17, 1.5), Offset(15, 6.5)],
      <double>[3.2, 3, 2.6],
    ),
    AnatomyTube(
      <Offset>[
        Offset(16, -6.5),
        Offset(36, -14.5),
        Offset(60, -21.5),
        Offset(84, -27.5),
      ],
      <double>[2.6, 2.2, 1.6, 0.9],
    ),
    AnatomyTube(
      <Offset>[Offset(11, -5.5), Offset(14, -19.5), Offset(20, -32.5)],
      <double>[1.8, 1.3, 0.8],
    ),
  ];

  /// How far a portal sheath reaches past its vein's wall.
  static const double sheath = 2.2;

  /// The hepatic artery, up beside the portal vein to the porta, cut short
  /// below the liver.
  static const AnatomyTube hepaticArtery = AnatomyTube(
    <Offset>[Offset(3, 1.5), Offset(5, 23.5), Offset(7, 45.5), Offset(8, 69.5)],
    <double>[2, 2.2, 2.2, 2.2],
    cutEnd: true,
  );

  // The bile ducts.

  /// The common hepatic and common bile duct, from the porta down beside
  /// the portal vein, fading out below the liver.
  static const AnatomyTube bileDuct = AnatomyTube(
    <Offset>[
      Offset(-12, 1.5),
      Offset(-13, 21.5),
      Offset(-15, 43.5),
      Offset(-16, 65.5),
      Offset(-17, 95.5),
    ],
    <double>[2, 2.2, 2.2, 2.2, 2.2],
    fadeOut: 24,
  );

  /// The cystic duct, from the gallbladder's neck into the bile duct.
  static const AnatomyTube cysticDuct = AnatomyTube(
    <Offset>[Offset(-20, 11.5), Offset(-17, 16.5), Offset(-13.5, 23.5)],
    <double>[1.4, 1.4, 1.4],
  );

  /// The portal branches a bile duct runs beside, in their sheaths, by
  /// their places in [portalBranches]: the right and left hepatic ducts and
  /// the larger segmental ones.
  static const List<int> ductBranches = <int>[0, 1, 2, 4, 5, 6];

  /// How wide a bile duct is, where it runs beside a portal branch.
  static const double duct = 0.6;

  // The gallbladder.

  /// The gallbladder's axis, from its neck to its fundus, and how wide its
  /// lumen is to either side along it; how thick its wall is.
  static const List<Offset> gallbladder = <Offset>[
    Offset(-20, 11.5),
    Offset(-27, 23.5),
    Offset(-35, 35.5),
    Offset(-42, 51.5),
  ];
  static const List<double> gallbladderHalf = <double>[4, 10, 12, 11];
  static const double gallbladderWall = 2;

  /// The round ligament, from the umbilical notch down the falciform
  /// ligament's free edge, fading out below the liver.
  static const AnatomyTube roundLigament = AnatomyTube(
    <Offset>[Offset(14, 11.5), Offset(19, 39.5), Offset(23, 65.5)],
    <double>[2.2, 2.2, 2.2],
    fadeOut: 22,
  );

  // The small vessels the cut crosses.

  /// About how far apart they lie, how wide each is at least and at most,
  /// and how long it is cut across at most, a multiple of its width; the
  /// share of them that are portal tracts, the rest hepatic venules.
  static const double smallApart = 11;
  static const double smallLeast = 0.6;
  static const double smallMost = 1.5;
  static const double smallLong = 2.1;
  static const double smallPortal = 0.5;

  // Where the parts are named: the left lobe low in it, by its lower
  // border, so that its name is set below the liver, where there is room.

  static const Offset cavaName = Offset(-4, -84.5);
  static const Offset hepaticVeinsName = Offset(-60, -42.5);
  static const Offset portalVeinName = Offset(-4, 52.5);
  static const Offset gallbladderName = Offset(-31, 31.5);
  static const Offset rightLobeName = Offset(-86, 29.5);
  static const Offset leftLobeName = Offset(40, 1.5);
}
