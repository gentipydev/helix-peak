import 'dart:ui';

import '../../tube_course.dart';

/// The uterine cervix the anatomogram draws for the cervix, opened along
/// its canal and seen from the front, as the body shows it: bivalved from
/// the external os up into the uterus, as GTEx opens it to sample it, its
/// front half taken away, so that what is seen is the back half, the cut
/// through its wall either side of the canal and the canal's back wall
/// between them. Above it the lower body of the uterus, below it the vault
/// of the vagina round its vaginal part, each cut short. It is drawn from
/// general anatomy, in millimetres, x across to the body's left, y down,
/// from the middle of its canal.
///
/// What is measured. After Gray (1918, pp. 1259-1264 and 615-616, read in
/// the archive.org text of the 20th edition, and Fig. 1167, "Posterior half
/// of uterus and upper part of vagina"): the uterus is about 7.5 cm long and
/// 5 cm broad above, and narrows at its isthmus, inside which is the
/// internal orifice; the cervix below it is "somewhat conical", "slightly
/// wider in the middle than either above or below"; the vagina is attached
/// round it, dividing it into a supravaginal and a vaginal portion, the
/// vaginal portion projecting "free" into the vagina between its fornices,
/// the external orifice "small" and "somewhat circular" on its rounded end,
/// between two lips; the canal is "somewhat fusiform, flattened from before
/// backward, and broader at the middle than at either extremity", and its
/// walls each have a longitudinal ridge "from which proceed a number of small
/// oblique columns, the palmate folds, giving the appearance of branches from
/// the stem of a tree"; the mucosa of the canal's upper two-thirds has "deep
/// glandular follicles", and little cysts, the ovula Nabothi, lie along its
/// whole length; its columnar epithelium "gradually changes to stratified
/// squamous close to the external orifice", and on the vaginal surface of
/// the cervix the epithelium is the vagina's, stratified squamous; the
/// muscular coat of the uterus is "dense, firm, of a grayish color", its
/// mucous membrane "of a pale red color"; the vagina has a column down its
/// back wall and transverse rugae from it; the uterine artery reaches the
/// margin of the cervix in the fibrous tissue beside it, ascends "in a
/// tortuous manner" beside the uterus, supplies the cervix and sends
/// branches down the vagina, and crosses the ureter about 2 cm from the
/// cervix. The canal is 33.95 mm long in 20 hysterectomy specimens
/// (Vinnikov et al. 2024, Australas J Ultrasound Med 27:141); the vagina
/// is widest just below the cervix, 32.5 mm, on MRI in 28 women of
/// reproductive age (Barnhart et al. 2006, Hum Reprod 21:1618); the
/// deepest endocervical crypt of a cone is 3.38 mm deep on average, in 343
/// cones (Anderson and Hartley 1980, Obstet Gynecol 55:546); the normal
/// cervical squamous epithelium is 246 ± 91 µm thick in 209 biopsies (Wang
/// et al. 2021, Zhonghua Bing Li Xue Za Zhi 50:339); Nabothian cysts form
/// at the squamocolumnar junction (Mikes and Puckett, StatPearls 2025); the
/// ureter lies 2.3 ± 0.8 cm from the cervix's margin on CT in 52 women
/// (Hurd et al. 2001, Am J Obstet Gynecol 184:336), 2.8 cm where the
/// uterine artery crosses it in 22 cadavers (Magrina et al. 2022, J Minim
/// Invasive Gynecol 29:879), out beyond the drawing. GTEx samples the
/// "Ectocervix (squamous)" and the "Endocervix (glandular)" after it has
/// bivalved "the uterus along the endocervical canal to open uterus and
/// cervix from external os to fundus" (the GTEx Portal's sampling sites for
/// Cervix - Ectocervix and Cervix - Endocervix, gtex_v10).
///
/// Drawing choices, measured by none of these: the outline, 28 mm across
/// the cervix's middle and 32 across the uterus where it is cut, 11 mm
/// above the internal orifice; the canal 8 mm across at its widest, as the
/// anatomogram's own canal is at its real size; the vagina attached to the
/// cervix's sides 2.5 mm below the canal's middle; the vaginal part's
/// shape, its end 2.3 mm below the external orifice; the uterine cavity's
/// width where it is cut; the vaginal wall 3.2 mm thick and cut 27 mm below
/// the canal's middle; the palmate folds' count, slant and spacing, and the
/// crypts'; the transformation zone 5 mm out along the surface from the
/// orifice and 4 mm deep; where the four cysts lie and how big each is;
/// where the tissue is sampled; the arteries' courses and widths, and their
/// branches to the wall.
abstract final class CervixAnatomy {
  /// How long the cervix is, from its isthmus to its end: about 4 cm, as
  /// the zoom's card has it.
  static const double length = 40;

  /// The right half of the outline, the uterus and the cervix where the cut
  /// crosses their outer surface: from the middle of the uterus's cut down
  /// the body's left side, in at the isthmus, out a little at the cervix's
  /// middle, past where the vagina is attached and round the vaginal part
  /// to the middle of its end, below the external orifice. The outline is
  /// the same either side of the middle.
  static const List<Offset> half = <Offset>[
    Offset(0, -28),
    Offset(5, -28),
    Offset(10, -28),
    Offset(13.9, -28),
    Offset(16.2, -27.8),
    Offset(16.2, -25.8),
    Offset(15.6, -24.5),
    Offset(14.6, -21.5),
    Offset(13.7, -19),
    Offset(13.3, -17),
    Offset(13.4, -14.5),
    Offset(13.8, -11),
    Offset(14.1, -7),
    Offset(14.2, -3),
    Offset(14.1, 0),
    Offset(13.9, 1.5),
    Offset(13.6, 2.5),
    Offset(13.3, 4.5),
    Offset(12.8, 7),
    Offset(12.1, 9.5),
    Offset(11.1, 12),
    Offset(9.8, 14.3),
    Offset(8.2, 16.3),
    Offset(6.4, 17.9),
    Offset(4.4, 19),
    Offset(2.2, 19.6),
    Offset(0, 19.8),
  ];

  /// Where the cut through the uterus runs across, above the isthmus.
  static const double uterusCut = -28;

  /// The internal orifice, at the isthmus, and the external, where the
  /// canal opens on the vaginal part's end: their heights.
  static const double internalOs = -17;
  static const double externalOs = 17.5;

  /// How far either side of the isthmus the uterus's muscle gives way to
  /// the cervix's fibrous stroma.
  static const double isthmusBlend = 3;

  /// The canal, from the internal orifice to the external, and the uterine
  /// cavity above it, from where the uterus is cut down to the internal
  /// orifice: how far it reaches to either side at each height.
  static const List<(double, double)> canal = <(double, double)>[
    (-17, 1.4),
    (-14, 2.1),
    (-10, 3),
    (-5, 3.7),
    (0, 4),
    (5, 3.8),
    (10, 3.3),
    (14, 2.8),
    (17.5, 2.5),
  ];
  static const List<(double, double)> cavity = <(double, double)>[
    (-28, 4.2),
    (-25, 3.2),
    (-21, 2.1),
    (-17, 1.4),
  ];

  // The canal's back wall.

  /// The longitudinal ridge down the canal's back wall, a little off its
  /// middle: where it runs across, from where to where, and how wide it is.
  static const double columnX = -0.4;
  static const double columnTop = -15.5;
  static const double columnBottom = 13.5;
  static const double columnWidth = 1;

  /// The palmate folds, running up and out from the ridge to the canal's
  /// sides: how many on either side, the first's height on the body's left
  /// side and how far apart they are, the right side's lying half way
  /// between; how steeply each rises, in radians above the level; how far
  /// short of the canal's side each stops; and below what height they are
  /// the lower half's finer folds.
  static const int folds = 8;
  static const double firstFold = -14;
  static const double foldApart = 3.2;
  static const double foldRise = 0.63;
  static const double foldShort = 0.35;
  static const double foldsFiner = 4;

  /// The crypts running from the canal's sides into the stroma, in its
  /// upper two-thirds and down to the transformation zone: from where to
  /// where, how far apart on either side, the other side's lying half way
  /// between; how steeply each rises out, in radians above the level; and
  /// the least and most that each reaches in.
  static const double cryptsTop = -15;
  static const double cryptsBottom = 11;
  static const double cryptApart = 2.4;
  static const double cryptRise = 0.4;
  static const double cryptLeast = 1.2;
  static const double cryptMost = 3.4;

  /// The Nabothian cysts, cut through: each one's middle and radius.
  static const List<(Offset, double)> cysts = <(Offset, double)>[
    (Offset(-6.7, 6), 1.5),
    (Offset(5.9, -4.5), 1),
    (Offset(-4.9, 14.6), 1.25),
    (Offset(5.2, 13.8), 0.9),
  ];

  // The vaginal part, the ectocervix.

  /// Where the vagina is attached to the cervix's side, the lateral
  /// fornix's top, on the body's left; and how far the line across the
  /// cervix between the two bows down at its middle.
  static const Offset attachment = Offset(13.6, 2.5);
  static const double portioBow = 1.5;

  /// How thick the squamous epithelium on the vaginal part is.
  static const double epithelium = 0.25;

  /// The transformation zone: how far it runs out along the surface from
  /// the external orifice's edge, and how deep it reaches in.
  static const double zoneOut = 5;
  static const double zoneDepth = 4;

  /// Where the tissue is sampled: on the vaginal part's surface on the
  /// body's left, a way out beyond the transformation zone, just under the
  /// surface. The drawing is laid so that this lies on the place the body's
  /// outline of the cervix is gone into.
  static const Offset site = Offset(8.6, 15.6);

  // The vagina.

  /// The vagina's right wall, cut, from where it is attached to the cervix
  /// down to where it is cut short: its inner surface, from the fornix's top,
  /// and its outer, from where it leaves the cervix above.
  static const List<Offset> vaginaInner = <Offset>[
    Offset(13.6, 2.5),
    Offset(14.8, 4),
    Offset(15.9, 6.5),
    Offset(16.3, 10),
    Offset(16.4, 16),
    Offset(16.3, 21.5),
    Offset(16.2, 27),
  ];
  static const List<Offset> vaginaOuter = <Offset>[
    Offset(14.15, -2),
    Offset(15.6, 0.5),
    Offset(17.6, 3),
    Offset(19, 6.5),
    Offset(19.5, 10),
    Offset(19.6, 16),
    Offset(19.5, 21.5),
    Offset(19.4, 27),
  ];

  /// Where the vagina is cut across.
  static const double vaginaCut = 27;

  /// Its wall's coats, from the inside out: the epithelium and the lamina
  /// propria; the muscularis is the rest.
  static const double vaginaEpithelium = 0.25;
  static const double vaginaLamina = 1.1;

  /// The column down its back wall, below the cervix, and the rugae running
  /// out from it to either side: how wide the column is, the first ruga's
  /// height and how far apart they are, how far each bows up at its middle,
  /// and how far short of the walls each stops.
  static const double vaginaColumn = 1.4;
  static const double firstRuga = 22;
  static const double rugaApart = 2.4;
  static const double rugaBow = 1.2;
  static const double rugaShort = 1.6;

  // What runs beside it, cut short.

  /// The right uterine artery, from where it is cut short beside and below
  /// the isthmus, rising in to the cervix's margin there; its ascending
  /// branch, tortuous, up beside the uterus to where the uterus is cut; and
  /// its cervicovaginal branch, down beside the cervix and on outside the
  /// vagina's wall to where the vagina is cut.
  static const AnatomyTube rightUterine = AnatomyTube(
    <Offset>[
      Offset(30, -10.5),
      Offset(25.5, -12.6),
      Offset(21, -15),
      Offset(17.6, -16.6),
      Offset(15.6, -17.2),
    ],
    <double>[1.2, 1.2, 1.2, 1.2, 1.2],
    cutStart: true,
  );
  static const AnatomyTube rightAscending = AnatomyTube(
    <Offset>[
      Offset(15.4, -17.8),
      Offset(16.2, -20.5),
      Offset(17.4, -23),
      Offset(16.9, -25.5),
      Offset(18.1, -26),
      Offset(18.3, -28),
    ],
    <double>[0.85, 0.85, 0.85, 0.85, 0.85, 0.85],
    cutEnd: true,
  );
  static const AnatomyTube rightCervicovaginal = AnatomyTube(
    <Offset>[
      Offset(15.4, -16.6),
      Offset(15.9, -13),
      Offset(16, -9),
      Offset(16.1, -5),
      Offset(17.2, -2),
      Offset(19.4, 1.2),
      Offset(21, 4.5),
      Offset(21.8, 9),
      Offset(22, 16),
      Offset(21.9, 21.5),
      Offset(21.8, 27.4),
    ],
    <double>[0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7],
    cutEnd: true,
  );

  /// The small branches into the wall: about how far apart along an
  /// artery, and how much more or less, how near the wall it must run to
  /// send one, how far ahead or behind along it each leans, how far under
  /// the wall each goes, and how wide each is.
  static const double branchApart = 5.5;
  static const double branchJitter = 1.5;
  static const double branchReach = 4.5;
  static const double branchLean = 1.5;
  static const double branchUnder = 1.2;
  static const double branch = 0.22;

  // Where the parts are named.

  /// The uterus, in its cut muscle on the body's right; the canal, inside
  /// it on that side; the ectocervix, in the vaginal part on the body's
  /// left; the transformation zone, on the body's right; the vagina, its
  /// back wall below the cervix on that side, toward its corner.
  static const Offset uterusName = Offset(-10, -23.5);
  static const Offset canalName = Offset(-2.4, -7);
  static const Offset homeName = Offset(10.4, 10);
  static const Offset zoneName = Offset(-4, 16.6);
  static const Offset vaginaName = Offset(-12.5, 25);
}
