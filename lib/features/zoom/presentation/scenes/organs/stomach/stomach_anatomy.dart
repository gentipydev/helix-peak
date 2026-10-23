import 'dart:ui';

import '../../tube_course.dart';

/// The stomach the anatomogram draws for the stomach, opened from the
/// front and seen from the front, as the body shows it: its front wall cut
/// away, so that what is seen is the inside of its back wall, and the wall
/// cut through all round it. It is drawn from general anatomy, in
/// millimetres, x across to the body's left, y down, from the middle of its
/// outline's box.
///
/// The cut is a composite, as an anatomy plate of the stomach's inside is:
/// the abdominal esophagus opened down to the cardia, its pale lining
/// meeting the stomach's at the Z-line; the fundus above the cardia; the
/// body, its mucosa thrown into rugae that run its length; the antrum past
/// the incisura angularis, and the pyloric canal narrowing to the pylorus,
/// whose sphincter is the wall's circular muscle thickened into a ring;
/// round it all, the cut wall's four coats. Outside it, the arteries along
/// its two curvatures, cut short where they leave, and the esophagus and
/// the duodenum running on, cut short.
///
/// What is measured: the parts and their bounds, after Gray (1918, via
/// Bartleby): the fundus above a plane through the cardiac orifice, the
/// pyloric part past one through the incisura angularis, its last 2.5 cm
/// or so before the pylorus (his pyloric antrum, today's pyloric canal)
/// narrower; the rugae for the most part lengthwise, most marked toward
/// the pylorus and along the greater curvature; the mucosa thinner at the
/// cardiac end than toward the pylorus; the pylorus a muscular ring of the
/// circular coat thickened, projecting into the lumen; the fundus (oxyntic)
/// glands, which the tissue the zoom goes into draws, in the body and the
/// fundus; the left gastric, right gastric, right and left gastroepiploic
/// and short gastric arteries. The wall is 5.1 ± 1.1 mm thick through the
/// body and antrum on ultrasound in 28 healthy adults, 7 at most (Rapaccini
/// et al. 1988, Gastrointest Radiol 13:197), and 3.27 ± 0.42 mm on
/// endoscopic ultrasound (Larsen et al. 2011, Obes Surg 21:300); in 53
/// resected, fixed stomachs it was thickest in the antrum and thinnest in
/// the fundus, 2.9, 2.6 and 2.3 mm in all, its muscle about two fifths of
/// that, 1.2, 1.0 and 0.9 (Endo et al. 2025, Obes Surg 35:946). The left
/// gastric artery is 2.7 ± 0.3 mm across, the right 1.6 ± 0.2, on CT in
/// 385 adults, an arcade along the lesser curvature in 81% (Tuan et al.
/// 2026, Anat Histol Embryol 55:e70162); the right gastroepiploic 2.49 ±
/// 0.66 mm at its origin, on CT angiography in 34 (Howell et al. 2018,
/// Plast Reconstr Surg 142:1046).
///
/// Drawing choices, measured by none of these: the outline, drawn to the
/// anatomogram's own proportions, 250 mm along its longest side, as the
/// zoom's card has it; the wall through each part, between those
/// measurements, and the pyloric ring 9 mm; the coats' shares of it; the
/// esophagus 22 mm across and the duodenum 26; where the rugae run, how far
/// apart, how much they wander and where they break off; the Z-line's
/// tongues; the courses of the
/// arteries and their branches to the wall, the left gastroepiploic 2 mm
/// across, the short gastrics 1.2; and the tubes cut short 15 to 45 mm out.
abstract final class StomachAnatomy {
  /// How long the stomach is, along its longest side, across.
  static const double length = 250;

  /// The stomach's outline, the serosa where the cut crosses it: from the
  /// abdominal esophagus's cut end over the incisura cardiaca and the
  /// fundus, down the greater curvature and along the antrum to the
  /// pylorus, and back along the lesser curvature through the incisura
  /// angularis to the esophagus.
  static const List<Offset> outline = <Offset>[
    Offset(-61, -103),
    Offset(-55, -108),
    Offset(-47, -112),
    Offset(-39, -111),
    Offset(-30, -99),
    Offset(-20, -88),
    Offset(-8, -91),
    Offset(12, -100),
    Offset(36, -106),
    Offset(60, -106),
    Offset(84, -99),
    Offset(104, -85),
    Offset(118, -66),
    Offset(125, -42),
    Offset(123, -16),
    Offset(115, 10),
    Offset(101, 34),
    Offset(82, 56),
    Offset(58, 76),
    Offset(30, 93),
    Offset(0, 105),
    Offset(-30, 111),
    Offset(-60, 108),
    Offset(-84, 100),
    Offset(-100, 90),
    Offset(-110, 82),
    Offset(-117, 77),
    Offset(-123, 73),
    Offset(-127, 60),
    Offset(-123, 47),
    Offset(-116, 42),
    Offset(-104, 36),
    Offset(-86, 29),
    Offset(-66, 24),
    Offset(-52, 17),
    Offset(-42, 4),
    Offset(-31, -20),
    Offset(-26, -40),
    Offset(-30, -57),
    Offset(-42, -74),
    Offset(-53, -88),
    Offset(-58, -97),
  ];

  /// How thick the wall is at each of [outline]'s points: none across the
  /// esophagus's cut end and the pyloric orifice, where the lumen runs on;
  /// thinnest round the fundus, thicker down the body and the antrum, and
  /// thickest at the pyloric ring either side of the orifice.
  static const List<double> wall = <double>[
    3, 0, 0, 3, 3, 3.2, //
    3.5, 3.5, 3.5, 3.5, 3.5, 3.5, //
    3.8, 4, 4, 4, 4.2, 4.4, 4.6, 4.8, //
    5, 5, 5, 5.2, 5.4, 5.6, //
    6.5, 9, 0, 9, //
    6.5, 5.6, 5.4, 5.2, 5, 4.6, 4.2, 4, 3.8, 3.5, //
    3.2, 3,
  ];

  /// The places in [outline] the curvatures run between: the incisura
  /// cardiaca and the pyloric ring's lower lip, for the greater; the
  /// esophagus's right margin level with it and the ring's upper lip, for
  /// the lesser, which runs the other way round the outline.
  static const int notch = 5;
  static const int lowerLip = 27;
  static const int upperLip = 29;
  static const int cardia = 40;

  /// The wall's coats, from the lumen out, each a share of the wall at
  /// most so many millimetres: the mucosa, the submucosa and the serosa;
  /// the muscularis is the rest, so that it is what thickens into the
  /// pyloric ring.
  static const double mucosaShare = 0.28;
  static const double mucosaMost = 1.4;
  static const double submucosaShare = 0.22;
  static const double submucosaMost = 1.1;
  static const double serosaShare = 0.06;
  static const double serosaMost = 0.25;

  /// Where the body goes into the stomach, in its body, its oxyntic mucosa
  /// between two rugae: the drawing is laid so that this lies on the place
  /// the body's outline of it is gone into.
  static const Offset site = Offset(49, -25);

  // The rugae.

  /// Each ruga: how far across from the greater curvature to the lesser it
  /// runs (0 to 1), from and to how far along them (0 at the cardia, 1 at
  /// the pylorus), and the seed of its wandering. Laid between the two
  /// curvatures, each the same share of the way along each, they run the
  /// stomach's length and gather toward the pylorus; the three nearest the
  /// lesser curvature are its gastric canal.
  static const List<(double, double, double, int)> rugae =
      <(double, double, double, int)>[
        (0.05, 0.16, 0.985, 1),
        (0.13, 0.12, 0.9, 2),
        (0.22, 0.12, 0.975, 3),
        (0.32, 0.13, 0.9, 4),
        (0.42, 0.17, 0.97, 5),
        (0.55, 0.20, 0.88, 6),
        (0.66, 0.18, 0.95, 7),
        (0.77, 0.10, 0.86, 8),
        (0.86, 0.04, 0.9, 9),
        (0.94, 0.02, 0.96, 10),
      ];

  /// How far a ruga wanders to either side at most, and at most this share
  /// of the way across; the two wavelengths it wanders by, along the
  /// greater curvature.
  static const double wander = 2.2;
  static const double wanderShare = 0.02;
  static const double wave = 46;
  static const double ripple = 21;

  /// How many times a ruga breaks off at most, and for how long, along the
  /// greater curvature.
  static const int breaks = 2;
  static const double breakLength = 10;

  /// The esophagus's own folds, each the share of the way across it.
  static const List<double> esophagealFolds = <double>[0.3, 0.5, 0.7];

  /// The Z-line: how many tongues of the stomach's mucosa reach up into the
  /// esophagus's, and how far.
  static const int tongues = 4;
  static const double tongue = 2.4;

  // What runs on beside it, cut short.

  /// The esophagus, from the cardia up out of the cut, and the duodenum,
  /// from the pylorus round its first bend; each cut short.
  static const AnatomyTube esophagus = AnatomyTube(
    <Offset>[
      Offset(-48, -100),
      Offset(-54, -114),
      Offset(-66, -130),
      Offset(-80, -146),
    ],
    <double>[11, 11, 11, 11],
    cutEnd: true,
  );
  static const AnatomyTube duodenum = AnatomyTube(
    <Offset>[
      Offset(-117, 60),
      Offset(-127, 60),
      Offset(-141, 57),
      Offset(-154, 62),
      Offset(-161, 76),
      Offset(-162, 94),
    ],
    <double>[13, 13, 13, 13, 13, 13],
    cutEnd: true,
  );

  /// The arteries along its curvatures, each from where it meets its
  /// fellow to where it is cut short, at its origin: the left gastric, up
  /// the lesser curvature to the cardia and down to the coeliac trunk; the
  /// right gastric, along the pyloric part to the hepatic artery; the left
  /// and right gastroepiploic, round the greater curvature to the splenic
  /// artery and the gastroduodenal; and three short gastrics from the
  /// fundus toward the spleen.
  static const List<AnatomyTube> arteries = <AnatomyTube>[
    AnatomyTube(
      <Offset>[
        Offset(-50, 6),
        Offset(-39, -20),
        Offset(-34, -42),
        Offset(-38, -62),
        Offset(-52, -82),
        Offset(-66, -90),
        Offset(-80, -74),
        Offset(-88, -56),
      ],
      <double>[0.8, 0.85, 0.95, 1.05, 1.15, 1.3, 1.35, 1.35],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-50, 6),
        Offset(-62, 17),
        Offset(-80, 23),
        Offset(-100, 30),
        Offset(-113, 35),
        Offset(-120, 22),
        Offset(-121, 8),
      ],
      <double>[0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[
        Offset(40, 99),
        Offset(66, 85),
        Offset(91, 66),
        Offset(111, 41),
        Offset(123, 15),
        Offset(131, -6),
        Offset(143, -16),
      ],
      <double>[0.9, 0.9, 0.95, 1, 1, 1, 1],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[
        Offset(40, 99),
        Offset(5, 113),
        Offset(-30, 119),
        Offset(-62, 116),
        Offset(-88, 108),
        Offset(-108, 99),
        Offset(-121, 98),
        Offset(-130, 108),
      ],
      <double>[0.9, 0.95, 1, 1.05, 1.1, 1.15, 1.2, 1.25],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[Offset(127, -58), Offset(138, -54), Offset(148, -52)],
      <double>[0.6, 0.6, 0.6],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[Offset(113, -84), Offset(126, -88), Offset(137, -94)],
      <double>[0.6, 0.6, 0.6],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[Offset(93, -103), Offset(104, -112), Offset(112, -121)],
      <double>[0.6, 0.6, 0.6],
      cutEnd: true,
    ),
  ];

  /// The arteries that send small branches in to the wall, by their places
  /// in [arteries]: all of them, where they run near it.
  static const List<int> arcades = <int>[0, 1, 2, 3, 4, 5, 6];

  /// The small branches into the wall: about how far apart along an
  /// arcade, and how much more or less, how near the wall it must run to
  /// send one, how far ahead or behind along it each leans, how far under
  /// the wall each goes, and how wide each is.
  static const double branchApart = 22;
  static const double branchJitter = 7;
  static const double branchReach = 15;
  static const double branchLean = 5;
  static const double branchUnder = 3;
  static const double branch = 0.4;

  // Where the parts are named.

  static const Offset fundusName = Offset(42, -94);
  static const Offset bodyName = Offset(96, -36);
  static const Offset rugaeName = Offset(20, 74);
  static const Offset antrumName = Offset(-78, 62);
  static const Offset pylorusName = Offset(-121, 60);
  static const Offset duodenumName = Offset(-158, 74);
  static const Offset esophagusName = Offset(-68, -133);
}
