import 'dart:ui';

import '../../tube_course.dart';

/// The intestines the anatomogram draws for the intestine, in place, seen
/// from the front, the greater omentum taken away, as an atlas shows them:
/// the coils of the jejunum and the ileum in the middle, framed by the
/// colon, and a window cut where the one meets the other, the ileocecal
/// junction, to show their lining. They are drawn from general anatomy, in
/// millimetres, x across to the body's left, y down, from about the middle
/// of what is drawn, as the body shows them from the front: the cecum low
/// on the body's right, the colon rising up that side, across under the
/// liver and the stomach, and down the left into the pelvis.
///
/// The window: the front wall of the cecum and of the start of the
/// ascending colon cut away, as Gray's plate shows them (Fig. 1075), the
/// inside of their back wall seen through it, the ileocecal valve's two
/// lips round the ileum's opening and the frenula running off them, the
/// appendix's orifice below, a semilunar fold across the colon above; and
/// the terminal ileum laid open from the front just short of the valve,
/// its lining with a Peyer's patch on it, where the zoom goes in.
///
/// What is measured. After Gray (1918, pp. 1170-1187, read in the
/// archive.org text of the 20th edition, and Fig. 1075): the jejunum is the
/// upper two-fifths of the small intestine past the duodenum, the ileum the
/// lower three-fifths; the jejunum "wider, its diameter being about 4 cm",
/// "thicker, more vascular, and of a deeper color than the ileum", the
/// ileum "narrow, its diameter being 3.75 cm", its circular folds few and
/// small, disappearing "entirely toward its lower end"; the jejunum "for the
/// most part occupies the umbilical and left iliac regions", the ileum
/// "chiefly the umbilical, hypogastric, right iliac, and pelvic regions";
/// "the terminal part of the ileum usually lies in the pelvis, from which it
/// ascends over the right Psoas and right iliac vessels" and opens "into
/// the medial side of the commencement of the large intestine". Peyer's
/// patches are "circular or oval", "from twenty to thirty in number, and
/// varying in length from 2 to 10 cm", "largest and most numerous in the
/// ileum", "placed lengthwise" and "in the portion of the tube most distant
/// from the attachment of the mesentery". The large intestine "describes
/// an arch which surrounds the convolutions of the small intestine": the
/// cecum, "6.25 cm. in length and 7.5 in breadth", in the right iliac
/// fossa; the ascending colon, "smaller in caliber than the cecum", up to
/// the liver; the transverse colon "with a downward convexity" across to
/// the left colic flexure, which "lies at a higher level than" the right;
/// the descending colon down the left side, and the iliac colon to the
/// pelvis, where the sigmoid colon "forms a loop" that "normally lies
/// within the pelvis" and ends in the rectum "at the level of the third
/// piece of the sacrum". Its longitudinal fibres gather into "three flat
/// longitudinal bands", "each of about 12 mm. in width", the anterior one
/// "in front in the ascending, descending, and iliac parts", which "serve
/// to produce the sacculi"; its mucosa is "raised into numerous crescentic
/// folds which correspond to the intervals between the sacculi"; small
/// pouches of fat, the appendices epiploicae, "most numerous on the
/// transverse colon". The appendix "varies from 2 to 20 cm. in length, its
/// average being about 8.3 cm", may pass "downward into the lesser pelvis",
/// and opens into the cecum "below and behind the ileocecal opening". The
/// colic valve's two lips "project into the lumen of the large intestine",
/// the upper "nearly horizontal", the lower "longer and more concave";
/// "at the ends of the aperture the two segments of the valve coalesce, and
/// are continued as narrow membranous ridges around the canal for a short
/// distance, forming the frenula". GTEx takes the small intestine from "the
/// most distal part of the small intestine; thickened mucosa with a
/// punctuate appearance corresponding to lymphoid nodules (Peyer Patches)
/// just proximal to the ileocecal valve", after identifying "the right
/// colon and cecum" (GTEx Tissue Harvesting Work Instruction, PR-0004-W1,
/// version 03.05, 4.3.6.21, its dissection guide Gray's Fig. 1075). On CT
/// without distension the colon narrows from the cecum (35.8 mm across) to
/// the ascending (32.6), the transverse (22.7), the descending (18.2) and
/// the sigmoid colon (17.4) (Haraikawa et al. 2023, J Clin Med 12:341).
///
/// Drawing choices, measured by none of these: the whole 350 mm from the
/// left colic flexure's top to the lowest coil in the pelvis, as the zoom's
/// card has it, and about 300 mm across; the colon's course and its
/// calibre, from the cecum's 75 mm down to the sigmoid's 34, between the
/// CT's narrow colon and Gray's cecum; the sacculi 34 mm apart and how far
/// they bulge; the one free band drawn, along the colon's front; the
/// appendices' number, size and places; the appendix's course and its
/// 7 mm calibre; the small intestine's calibre, 34 mm for the jejunum and
/// 28 for the ileum, under Gray's distended 4 and 3.75 cm; the coils
/// themselves, laid by hand, the jejunum in passes across the upper left
/// of the body and the ileum in passes down its lower right and in the
/// pelvis, each coil's ends running back under another into the shade; the
/// wall 2.5 mm through the colon and 2 through the ileum, and its coats'
/// shares; the window's extent; the valve's lips and frenula; the patch's
/// size, 30 by 11 mm, and how far it lies from the valve; the terminal
/// ileum's turn, its antimesenteric wall, where Gray puts the patches, the
/// wall seen through the cut.
abstract final class IntestineAnatomy {
  /// How tall the intestines stand, the left colic flexure's top to the
  /// lowest coil in the pelvis: what is drawn's longest side, seen from the
  /// front.
  static const double length = 350;

  // The colon.

  /// The colon's middle line, from the cecum's blind end up the body's
  /// right, across and down the left into the pelvis, to where the sigmoid
  /// colon runs on behind the coils toward the rectum; and how wide it is
  /// to either side at each of those points.
  static const List<Offset> colon = <Offset>[
    Offset(-108, 128),
    Offset(-110, 106),
    Offset(-111, 76),
    Offset(-114, 45),
    Offset(-118, 0),
    Offset(-120, -50),
    Offset(-117, -100),
    Offset(-100, -132),
    Offset(-60, -118),
    Offset(-12, -100),
    Offset(38, -110),
    Offset(82, -140),
    Offset(110, -152),
    Offset(128, -125),
    Offset(131, -60),
    Offset(128, 5),
    Offset(116, 60),
    Offset(92, 100),
    Offset(50, 122),
    Offset(5, 132),
    Offset(-20, 120),
    Offset(-8, 100),
    Offset(14, 108),
    Offset(16, 140),
  ];
  static const List<double> colonHalf = <double>[
    33,
    35,
    37,
    33,
    29,
    28,
    27,
    26,
    25,
    24,
    24,
    23,
    22,
    20,
    19,
    19,
    18,
    18,
    17,
    17,
    17,
    17,
    17,
    17,
  ];

  /// How far round its blind end the cecum is drawn in to its rounded
  /// tip, from [colon]'s first point.
  static const double cecumRound = 30;

  /// Which of [colon]'s points the sigmoid colon starts at: from there on
  /// it lies behind the coils in the pelvis.
  static const int sigmoidFrom = 17;

  /// How far before its end the sigmoid colon runs back into the shade,
  /// on behind the coils toward the rectum.
  static const double rectumFade = 20;

  /// Over how long a stretch before the sigmoid colon the colon goes down
  /// into the shade of the pelvis, behind the coils.
  static const double sigmoidShading = 40;

  /// The sacculi: how far apart their middles lie along the colon, from
  /// how far along it they start, how far they bulge, a share of the
  /// colon's half-width, and how far along it from its end they stop
  /// (none on the rectum).
  static const double sacculus = 34;
  static const double sacculiFrom = 96;
  static const double sacculusBulge = 0.07;
  static const double sacculiStop = 40;

  /// The free band, how wide.
  static const double band = 12;

  /// The appendices epiploicae: how far along the colon from its start
  /// each hangs, on which side (1 the colon's left hand, -1 its right) and
  /// how long it is.
  static const List<(double, double, double)> appendices =
      <(double, double, double)>[
        (300, 1, 15),
        (334, 1, 12),
        (366, 1, 16),
        (400, 1, 13),
        (436, 1, 15),
        (470, 1, 12),
        (700, -1, 13),
        (736, -1, 15),
      ];

  /// The colon's wall, cut round the window, and its coats from the
  /// outside in, each a share of it: the serosa, the longitudinal muscle,
  /// the circular muscle, the submucosa; the mucosa is the rest.
  static const double colonWall = 2.5;
  static const double ileumWall = 2;
  static const double serosaShare = 0.06;
  static const double longitudinalShare = 0.14;
  static const double circularShare = 0.3;
  static const double submucosaShare = 0.22;

  // The window.

  /// How far along the colon from its start its front wall is cut away:
  /// the cecum's and the ascending colon's first stretch.
  static const double windowTo = 118;

  /// The colic valve, on the cecum's medial wall: the aperture's two ends,
  /// its lateral end rounded and its medial end pointed; how far each lip
  /// stands off the aperture at its middle; how far the frenula run on
  /// from its ends.
  static const Offset valveFrom = Offset(-103, 54);
  static const Offset valveTo = Offset(-84, 57);
  static const double upperLip = 4.5;
  static const double lowerLip = 6;
  static const double frenulum = 13;

  /// The appendix's orifice, below and behind the valve: where, and how
  /// wide.
  static const Offset orifice = Offset(-97, 84);
  static const double orificeRadius = 2.4;

  /// The semilunar folds seen in the window, from either side in turn, how
  /// far across the lumen each reaches, a share of it; and how wide each
  /// crescent bows.
  static const double semilunarReach = 0.78;
  static const double semilunarBow = 5;

  // The appendix.

  /// Its middle line, from its base low on the cecum's medial side down
  /// over the pelvic brim to its tip, and how wide it is to either side.
  static const List<Offset> appendix = <Offset>[
    Offset(-99, 108),
    Offset(-95, 116),
    Offset(-88, 134),
    Offset(-81, 152),
    Offset(-79, 170),
  ];
  static const double appendixHalf = 3.5;

  // The small intestine.

  /// The jejunum's and the ileum's half-widths.
  static const double jejunumHalf = 17;
  static const double ileumHalf = 14;

  /// How far from each end a coil runs back into the shade, turning away
  /// under the coils over it.
  static const double coilFade = 24;

  /// The coils, back to front, each its middle line and whether it is the
  /// jejunum's.
  static const List<(List<Offset>, bool)> coils = <(List<Offset>, bool)>[
    (
      <Offset>[
        Offset(30, -87),
        Offset(50, -91),
        Offset(71, -94),
        Offset(92, -90),
        Offset(102, -86),
        Offset(106, -76),
        Offset(102, -65),
        Offset(92, -61),
        Offset(73, -65),
        Offset(54, -63),
        Offset(36, -59),
        Offset(18, -57),
        Offset(-1, -61),
        Offset(-20, -65),
        Offset(-30, -57),
        Offset(-34, -46),
        Offset(-30, -36),
        Offset(-20, -36),
        Offset(1, -32),
        Offset(22, -28),
        Offset(42, -31),
        Offset(63, -36),
        Offset(83, -34),
        Offset(104, -29),
        Offset(114, -28),
      ],
      true,
    ),
    (
      <Offset>[
        Offset(114, -1),
        Offset(91, 4),
        Offset(70, 1),
        Offset(48, -4),
        Offset(27, 0),
        Offset(6, 4),
        Offset(-4, 4),
        Offset(-8, 14),
        Offset(-4, 24),
        Offset(6, 32),
        Offset(27, 28),
        Offset(48, 24),
        Offset(70, 29),
        Offset(91, 32),
        Offset(114, 27),
      ],
      true,
    ),
    (
      <Offset>[
        Offset(-78, -104),
        Offset(-79, -80),
        Offset(-75, -60),
        Offset(-76, -40),
        Offset(-80, -20),
        Offset(-77, 0),
        Offset(-74, 20),
        Offset(-73, 28),
        Offset(-64, 32),
        Offset(-56, 28),
        Offset(-49, 20),
        Offset(-52, 0),
        Offset(-55, -20),
        Offset(-51, -40),
        Offset(-50, -60),
        Offset(-54, -80),
        Offset(-53, -104),
      ],
      false,
    ),
    (
      <Offset>[
        Offset(-28, -94),
        Offset(-23, -71),
        Offset(-24, -53),
        Offset(-28, -34),
        Offset(-24, -15),
        Offset(-23, 3),
        Offset(-28, 22),
        Offset(-25, 41),
        Offset(-22, 60),
        Offset(-21, 68),
        Offset(-12, 72),
        Offset(-4, 68),
        Offset(3, 60),
        Offset(-2, 36),
        Offset(0, 12),
        Offset(2, -12),
      ],
      false,
    ),
    (
      <Offset>[
        Offset(116, 58),
        Offset(95, 59),
        Offset(75, 63),
        Offset(56, 59),
        Offset(36, 58),
        Offset(28, 64),
        Offset(24, 72),
        Offset(28, 81),
        Offset(36, 83),
        Offset(58, 84),
        Offset(79, 88),
        Offset(100, 82),
      ],
      false,
    ),
    (
      <Offset>[
        Offset(45, 96),
        Offset(48, 114),
        Offset(49, 132),
        Offset(45, 146),
        Offset(43, 152),
        Offset(36, 155),
        Offset(28, 152),
        Offset(21, 146),
        Offset(25, 134),
        Offset(24, 117),
        Offset(20, 100),
      ],
      false,
    ),
    (
      <Offset>[
        Offset(-53, 96),
        Offset(-47, 114),
        Offset(-50, 133),
        Offset(-52, 147),
        Offset(-46, 153),
        Offset(-38, 156),
        Offset(-29, 153),
        Offset(-27, 147),
        Offset(-27, 140),
        Offset(-23, 128),
      ],
      false,
    ),
    (
      <Offset>[
        Offset(2, -62),
        Offset(30, -46),
        Offset(58, -22),
        Offset(72, 4),
        Offset(64, 30),
        Offset(40, 40),
      ],
      true,
    ),
    (
      <Offset>[
        Offset(-40, 40),
        Offset(-16, 52),
        Offset(12, 50),
        Offset(34, 36),
        Offset(44, 14),
      ],
      false,
    ),
  ];

  /// The terminal ileum, from the pelvis up over the brim to the cecum's
  /// medial side, where it passes in under the cecum's wall.
  static const AnatomyTube terminalIleum = AnatomyTube(
    <Offset>[
      Offset(-8, 168),
      Offset(-18, 150),
      Offset(-32, 122),
      Offset(-48, 96),
      Offset(-62, 76),
      Offset(-74, 64),
      Offset(-88, 58),
    ],
    <double>[14, 14, 14, 14, 14, 14, 14],
    fadeIn: coilFade,
  );

  /// How far back from its end the terminal ileum is laid open: from so
  /// far short of the cecum's wall, for so far.
  static const double openFrom = 22;
  static const double openTo = 108;

  /// The Peyer's patch on its lining: how far back from the ileum's end
  /// its middle lies, how long and how wide it is; and how many lymphoid
  /// nodules show on it.
  static const double patchAt = 50;
  static const double patchLength = 30;
  static const double patchWidth = 11;
  static const int patchNodules = 11;

  /// Where the body goes into the intestines, as GTEx does: on the Peyer's
  /// patch, in the terminal ileum just short of the valve. The drawing is
  /// laid so that this lies on the place the body's outline of the
  /// intestine is gone into; it is the patch's middle, worked out where
  /// the form lays the ileum, and set here to the millimetre for the tool
  /// that places the body's site (`tool/zoom/anatomogram.py`).
  static const Offset site = Offset(-51.5, 90.7);

  // Where the parts are named.

  /// The transverse and the descending colon, the jejunum and the ileum,
  /// each at the nearest point of its middle line; the appendix at its
  /// middle.
  static const Offset transverseName = Offset(20, -104);
  static const Offset descendingName = Offset(131, -40);
  static const Offset jejunumName = Offset(60, -63);
  static const Offset ileumName = Offset(36, 156);
  static const Offset appendixName = Offset(-84, 145);
}
