import 'dart:ui';

import '../../tube_course.dart';

/// The uterus the anatomogram draws for the endometrium, bivalved along its
/// canal from the external os to the fundus, as GTEx opens it to sample its
/// body, and seen from the front: its front half taken away, so that what
/// is seen is the back half, the cut through its wall all round the cavity
/// and the canal, and the cavity's back wall between them. Its tubes leave
/// its cornua and its ovarian ligaments run out below them, each cut short;
/// the uterine arteries climb beside it. It is drawn from general anatomy,
/// in millimetres, x across to the body's left, y down, from the middle of
/// the cervix's canal, in the cervix specimen's own frame
/// (`cervix_anatomy.dart`), whose cervix it is below the isthmus.
///
/// What is measured. After Gray (1918, pp. 1259-1264, read in the
/// archive.org text of the 20th edition, and Fig. 1167, "Posterior half of
/// uterus and upper part of vagina"): the uterus is pear-shaped, about 7.5
/// cm long, 5 cm broad at its upper part and nearly 2.5 cm thick; its body
/// is flattened from before backward, its fundus convex, and the uterine
/// tubes enter it at its upper lateral angles, the round and ovarian
/// ligaments just below them; its cavity is "a mere slit", triangular in
/// the coronal plane, its base between the orifices of the tubes and its
/// apex at the internal orifice; its wall has a serous coat, a muscular
/// coat, "dense, firm, of a grayish color", whose middle layer holds the
/// larger vessels, and a mucous coat, "soft, spongy" and "of a pale red
/// color", its uterine glands tubular and "somewhat convoluted" at their
/// deep ends, which reach down to the muscle with no submucosa between; the
/// uterine artery ascends "in a tortuous manner" beside the uterus to the
/// junction of the tube with it, where it anastomoses with the ovarian
/// artery, giving branches to the wall all the way. The endometrium is 8.6
/// mm thick (median, both layers) in 849 premenopausal women on
/// transvaginal ultrasound, 5.4 mm just after menstruation, 9.2 mm on days
/// 13-14 and 11.1 mm on day 18 (Tsuda et al. 2018, Reprod Med Biol 17:29).
/// GTEx samples the uterus's "Corpus", having bivalved the uterus "along
/// endocervical canal to fundus" (the GTEx Portal's sampling site for
/// Uterus, gtex_v10); the Human Protein Atlas reads its endometrium.
///
/// Drawing choices, measured by none of these: the outline, 79 mm from the
/// fundus to the external os, 50 mm across the cornua, its cervix the
/// cervix specimen's; the cavity 31 mm across between its angles and 30 mm
/// from its fundal border to the internal orifice, its sides bowed in a
/// little; the endometrium, one layer of the sample above, 5 mm thick in
/// the body and thinning to 1.2 mm at the isthmus, its basal layer 1 mm;
/// where its glands run, how far apart and how they coil; the openings of
/// the glands on the cavity's back wall, as pits 1.3 mm apart; the middle
/// layer of the muscle's vessels, cut across, how many, how big and where;
/// the tubes' isthmus 3 mm across and where they fade out, their intramural
/// part's course; the ovarian ligaments' width and course; the arteries'
/// courses and widths, and their branches to the wall; where the tissue is
/// sampled.
abstract final class UterusAnatomy {
  /// How long the uterus is, from its fundus to its external os: about 8
  /// cm, as the zoom's card has it.
  static const double length = 80;

  /// The right half of the outline above the isthmus, where the cut crosses
  /// the body's outer surface: from the middle of the fundus down the body's
  /// left side, out round the cornu and in to the isthmus, where the
  /// cervix's own half (`CervixAnatomy.half`) goes on from its waist. The
  /// outline is the same either side of the middle.
  static const List<Offset> body = <Offset>[
    Offset(0, -59),
    Offset(5, -58.8),
    Offset(10, -58),
    Offset(14.5, -56.6),
    Offset(18.5, -54.6),
    Offset(21.6, -52.2),
    Offset(23.6, -49.6),
    Offset(24.6, -47),
    Offset(24.9, -44),
    Offset(24.6, -40.5),
    Offset(23.7, -36.5),
    Offset(22.3, -32.5),
    Offset(20.5, -28.5),
    Offset(18.5, -25),
    Offset(16.6, -22),
    Offset(15.1, -19.8),
  ];

  /// Where the cervix's half takes the outline over: below this height.
  static const double isthmus = -17;

  /// The cavity: its two angles, where the tubes open into it, and how far
  /// its fundal border bows down between them; how far it reaches to either
  /// side at each height below them, down to the internal orifice, where
  /// the canal goes on.
  static const Offset angle = Offset(15.6, -47.2);
  static const double fundalBow = 1.3;
  static const List<(double, double)> cavity = <(double, double)>[
    (-47.2, 15.6),
    (-45, 14.7),
    (-41, 12.8),
    (-36, 10.4),
    (-31, 7.9),
    (-26, 5.3),
    (-22, 3.3),
    (-19, 2),
    (-17, 1.4),
  ];

  // The endometrium.

  /// How thick it is in the body, and at the isthmus, and over how far
  /// above the isthmus it thins from the one to the other; how thick its
  /// basal layer is, against the muscle.
  static const double endometrium = 5;
  static const double endometriumIsthmus = 1.2;
  static const double thinning = 7;
  static const double basal = 1;

  /// Its glands, cut along their length: about how far apart along the
  /// cavity's edge; how far short of its basal layer each stops, at most;
  /// how far to either side each coils, and over what length a coil.
  static const double glandApart = 1.3;
  static const double glandShort = 1.2;
  static const double glandCoil = 0.24;
  static const double glandTurn = 1.1;

  /// The openings of its glands on the cavity's back wall: how far apart,
  /// and how wide each is.
  static const double pitApart = 1.3;
  static const double pit = 0.11;

  // The muscle.

  /// The vessels of its middle layer, cut across: how far out from the
  /// endometrium toward the serosa their layer lies, a share of the wall;
  /// about how far apart along it; and the least and most each is across.
  static const double vascularLayer = 0.55;
  static const double vesselApart = 2.4;
  static const double vesselLeast = 0.35;
  static const double vesselMost = 0.95;

  // The tubes and the ligaments.

  /// The right tube's intramural part, from the cavity's angle out through
  /// the cornu; its isthmus beyond, running out from the cornu and fading
  /// out; and the right ovarian ligament below it, likewise.
  static const List<Offset> rightIntramural = <Offset>[
    Offset(15.6, -47.2),
    Offset(18.5, -47.9),
    Offset(21.5, -47.7),
    Offset(24.7, -47.4),
  ];
  static const double intramural = 0.32;
  static const AnatomyTube rightTube = AnatomyTube(
    <Offset>[
      Offset(24.3, -47.5),
      Offset(29, -48.4),
      Offset(34, -49.7),
      Offset(39, -51.5),
      Offset(44, -53.9),
    ],
    <double>[1.5, 1.5, 1.5, 1.55, 1.6],
    fadeOut: 9,
  );
  static const AnatomyTube rightLigament = AnatomyTube(
    <Offset>[
      Offset(24.2, -41.5),
      Offset(29, -40.4),
      Offset(34, -39.4),
      Offset(39.5, -38.4),
    ],
    <double>[1.6, 1.5, 1.4, 1.3],
    fadeOut: 9,
  );

  // The arteries, beside it and cut short.

  /// The right uterine artery's ascending branch, tortuous, from where the
  /// artery reaches the isthmus (`CervixAnatomy.rightUterine`) up beside
  /// the body to below the cornu; its tubal branch on under the tube and its
  /// ovarian branch out above the ligament, fading out; and its
  /// cervicovaginal branch down beside the cervix, cut short.
  static const AnatomyTube rightAscending = AnatomyTube(
    <Offset>[
      Offset(15.4, -17.8),
      Offset(16.9, -20.4),
      Offset(19, -23.2),
      Offset(20.9, -26.4),
      Offset(23.4, -29),
      Offset(24, -32.5),
      Offset(26.1, -35.4),
      Offset(26.3, -39),
      Offset(27.6, -42),
      Offset(27.4, -45.4),
    ],
    <double>[0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.9, 0.9, 0.85],
  );
  static const AnatomyTube rightTubal = AnatomyTube(
    <Offset>[
      Offset(27.4, -45.4),
      Offset(31, -45.9),
      Offset(35, -47),
      Offset(40, -48.7),
    ],
    <double>[0.55, 0.55, 0.5, 0.5],
    fadeOut: 7,
  );
  static const AnatomyTube rightOvarian = AnatomyTube(
    <Offset>[
      Offset(27.4, -45.4),
      Offset(31, -44.4),
      Offset(35.5, -43.5),
      Offset(40.5, -42.7),
    ],
    <double>[0.65, 0.65, 0.6, 0.6],
    fadeOut: 7,
  );
  static const AnatomyTube rightCervicovaginal = AnatomyTube(
    <Offset>[
      Offset(15.4, -16.6),
      Offset(15.9, -13),
      Offset(16, -9),
      Offset(16.1, -5),
      Offset(17.2, -2),
      Offset(18.7, 1.5),
      Offset(19.6, 5),
    ],
    <double>[0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7],
    cutEnd: true,
  );

  /// The small branches into the wall: about how far apart along the
  /// ascending artery, and how much more or less; how near the wall it must
  /// run to send one, how far ahead or behind along it each leans, how far
  /// under the wall each goes, and how wide each is.
  static const double branchApart = 4.6;
  static const double branchJitter = 1.2;
  static const double branchReach = 5;
  static const double branchLean = 1.5;
  static const double branchUnder = 1.6;
  static const double branch = 0.24;

  // Where it is gone into, and where its parts are named.

  /// Where the tissue is sampled: in the endometrium of the body, in its
  /// functional layer on the body's right, where the cut crosses it beside
  /// the cavity. The drawing is laid so that this lies on the place the
  /// body's outline of the endometrium is gone into.
  static const Offset site = Offset(-9.9, -28);

  /// The cavity's back wall, where the endometrium's surface faces the eye;
  /// the muscle, over the fundus; the canal; and the tube on the body's
  /// left, where it leaves its cornu.
  static const Offset surfaceName = Offset(-3, -38);
  static const Offset muscleName = Offset(-7, -55);
  static const Offset canalName = Offset(-1.6, 2);
  static const Offset tubeName = Offset(33, -49.4);
}
