import 'dart:ui';

/// The vagina the anatomogram draws for the vagina, opened down the middle
/// of its front wall from the introitus to the anterior fornix and pinned
/// flat, its inside facing the eye, as a pathologist lays a hollow organ
/// open: its back wall in the middle, from the posterior fornix above the
/// cervix down to the fourchette, and the two halves of its front wall laid
/// out to either side, shorter, their cut edges outermost; the vaginal part
/// of the cervix standing out of the vault at the top, its external os on
/// its face; the hymen's remnants along the introitus. It is drawn from
/// general anatomy, in millimetres, x across to the body's left, y down,
/// from the middle of the external os.
///
/// What is measured. After Gray (1918, pp. 1264-1265, read in the
/// archive.org text of the 20th edition, and Fig. 1167): the vagina is a
/// musculomembranous tube, its walls ordinarily in contact, its anterior
/// wall about 7.5 cm long and its posterior about 9 cm; the cervix projects
/// into its upper end, the recess round the cervix being its fornices, the
/// posterior the deepest; on the inner surface of each wall a median
/// ridge, the columna rugarum, and from it numerous transverse ridges, the
/// rugae, the anterior column forming below "a ridge", the urethral carina,
/// where the urethra lies against the wall; the vaginal orifice is closed
/// in part by the hymen, of which, once ruptured, small rounded projections
/// remain, the carunculae hymenales; its mucous membrane is covered by
/// stratified squamous epithelium. The vagina is widest just below the
/// cervix, 32.5 mm, on MRI in 28 women of reproductive age (Barnhart et al.
/// 2006, Hum Reprod 21:1618). GTEx samples the vagina's "Anterior" wall (the
/// GTEx Portal's sampling site for Vagina, gtex_v10).
///
/// Drawing choices, measured by none of these: the outline, the walls laid
/// flat each as wide as the vagina is across, its back wall 32 mm wide
/// below the cervix and 28 mm at the introitus, each half of its front wall
/// 15 mm, 103 mm from the posterior fornix to the fourchette with the
/// cervix's end in the vault; the lateral sulci between the walls as a
/// line; the vaginal part 24 mm across and 22 mm high, its os a slit 5 mm
/// across; the columns' widths and where they run; the rugae's spacing,
/// bow and reach, and none on the cervix; the carina's length; the
/// caruncles' count and size; where the tissue is sampled.
abstract final class VaginaAnatomy {
  /// How long the vagina is, its back wall from the posterior fornix to the
  /// fourchette: about 9 cm, as the zoom's card has it.
  static const double length = 90;

  /// The right half of the outline, the edge of the pinned specimen: from
  /// the middle of the posterior fornix out over the lateral fornix and
  /// along the top of the front wall's half, down its cut edge, and in
  /// along the introitus to the fourchette, below the back wall's middle.
  /// The outline is the same either side of the middle.
  static const List<Offset> half = <Offset>[
    Offset(0, -15),
    Offset(6, -14.6),
    Offset(11, -13.2),
    Offset(14.8, -10.8),
    Offset(17.4, -7.4),
    Offset(19.2, -3.6),
    Offset(22, -1.4),
    Offset(26, -0.4),
    Offset(30, 0),
    Offset(33, 0.8),
    Offset(33.8, 4),
    Offset(33.8, 12),
    Offset(33.4, 25),
    Offset(32.6, 40),
    Offset(31.4, 55),
    Offset(30, 67),
    Offset(28.8, 74.5),
    Offset(26, 78.2),
    Offset(21, 82),
    Offset(14, 85.6),
    Offset(7, 87.4),
    Offset(0, 88),
  ];

  /// The lateral sulcus on the body's left, where the back wall meets the
  /// front wall's half laid out beside it: from the lateral fornix down to
  /// the introitus.
  static const List<Offset> sulcus = <Offset>[
    Offset(19.2, -3.6),
    Offset(18.4, 4),
    Offset(17.4, 20),
    Offset(16.4, 40),
    Offset(15.4, 60),
    Offset(14.6, 75),
    Offset(14, 85.6),
  ];

  // The vaginal part of the cervix.

  /// Its middle, how far it reaches to either side and up and down, and
  /// its external os, a slit: how wide and how high.
  static const Offset portio = Offset(0, 1);
  static const double portioWide = 12;
  static const double portioHigh = 11;
  static const double osWide = 2.5;
  static const double osHigh = 0.65;

  // The mucosa.

  /// The posterior column down the back wall's middle, from below the
  /// cervix to the introitus, and the anterior column's halves along the
  /// front wall's cut edges, how far in from them, from where to where; how
  /// wide each is, and the urethral carina, wider, below where it begins.
  static const double posteriorTop = 14;
  static const double posteriorBottom = 84;
  static const double anteriorIn = 2.4;
  static const double anteriorTop = 26;
  static const double anteriorBottom = 72;
  static const double column = 1.6;
  static const double carinaTop = 52;
  static const double carina = 2.2;

  /// The rugae, running out from the columns: how far apart, where the
  /// first lies on the back wall and on the front wall's halves, how far
  /// each bows up at its middle, and how far short of the sulcus and the
  /// edges each stops.
  static const double rugaApart = 2.3;
  static const double firstBack = 15;
  static const double firstFront = 5;
  static const double rugaBow = 1.4;
  static const double rugaShort = 1.2;

  /// The hymen's caruncles along the introitus: how many, and the least
  /// and the most each reaches out.
  static const int caruncles = 9;
  static const double caruncleLeast = 1.1;
  static const double caruncleMost = 1.8;

  // Where it is gone into, and where its parts are named.

  /// Where the tissue is sampled: on the front wall's half laid out on the
  /// body's right, in its middle third, a little out from the sulcus. The
  /// drawing is laid so that this lies on the place the body's outline of
  /// the vagina is gone into.
  static const Offset site = Offset(-18.4, 40);

  /// The vaginal part; the posterior fornix, above it; the rugae, on the
  /// back wall; the hymen's caruncles, on the body's left, clear of the
  /// scale bar.
  static const Offset cervixName = Offset(5, -3);
  static const Offset fornixName = Offset(-4, -12.6);
  static const Offset rugaeName = Offset(5, 66);
  static const Offset hymenName = Offset(17.6, 85.4);
}
