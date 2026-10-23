import 'dart:ui';

/// The kidney the anatomogram draws for the kidney, cut open from front to
/// back and seen from the front, as every anatomy plate draws it: drawn from
/// general anatomy, in millimetres, as a right kidney, x across toward its
/// hilum (the body's left), y down, from the middle of its outline's box.
/// The left kidney is the same mirrored.
///
/// The cut shows the cortex under the capsule, running in between the
/// medullary pyramids as the renal columns; the pyramids, striated, their
/// bases toward the capsule and their papillae opening into the minor
/// calyces in the renal sinus; the minor calyces gathering into three major
/// ones and those into the pelvis, which leaves the hilum as the ureter;
/// the renal artery and vein at the hilum, their branches in the fat of
/// the sinus, interlobar up the columns and arcuate over each pyramid's
/// base; and the medullary rays, running up from the pyramids' bases into
/// the cortex, among the glomeruli.
///
/// Sizes keep to what is measured. The textbooks' adult kidney is 12 cm
/// long and 6 cm wide (Alyami et al. 2024, Medicine 103:e38607); on
/// ultrasound in 252 healthy adults it was 10.7 cm long, its cortex 1.1 ±
/// 0.53 cm thick, 0.6 to 1.6 (El-Reshaid and Abdul-Fattah 2014, Med Princ
/// Pract 23:432). A kidney has 21 pyramids on average, each 1.56 cm³, by CT
/// in 2,876 living donors (Gregory et al. 2023, J Am Soc Nephrol 34:1752).
/// It has 918,210 glomeruli on average, 210,332 to 2,702,079 (Hughson et
/// al. 2014, Nephrol Dial Transplant 29:1399), each in a Bowman's capsule
/// of 6.1 × 10⁶ µm³ in adults whose kidneys work normally, a ball 0.23 mm
/// across (Sasaki et al. 2018, Kidney Int Rep 3:314), in a cortex of 89 to
/// 127 cm³ (Sasaki et al. 2019, Sci Rep 9:14400): about two to a square
/// millimetre of a cut through it. The thick ascending limb of the loop of
/// Henle runs up through the outer medulla, as its medullary part, and on
/// in the cortex, as its cortical part, in the medullary rays that lead
/// down into the medulla (Lake et al. 2023, Nature 619:585); its cells make
/// 85 to 90% of the uromodulin, and those of the early distal convoluted
/// tubule the rest (Karagiannidis et al. 2024, Nephrol Dial Transplant
/// 39:1073). The renal artery is 5.5 ± 1.4 mm across on the right and 5.3 ±
/// 1.1 on the left (Abd Elrahim 2020, Saudi Med J 41:34). A kidney is
/// biopsied at its lower pole, through its cortex (Granata et al. 2021,
/// Diagnostics 11:2186), where the zoom goes in.
///
/// Drawing choices, measured by none of these: the outline, drawn to the
/// anatomogram's own proportions; the cortex 9 mm thick; the eight pyramids
/// the cut passes through, laid evenly round the sinus, each its base 80% of
/// its share of the corticomedullary junction; the outer medulla the outer
/// 40% of a pyramid, the papilla the inner 28%; the sinus's shape; a minor
/// calyx to each papilla, three major calyces and the pelvis; the medullary
/// rays 0.5 mm wide, 1.8 mm apart, stopping 1.2 mm short of the capsule; a
/// quarter of the glomeruli a cut shows; the renal vein 10 mm across, the
/// segmental arteries 2.4, the interlobar 1.6 and the arcuate 1; the vessels
/// cut short 16 mm past the hilum, and the ureter, 5 mm across, shown for
/// 45 mm below it.
abstract final class KidneyAnatomy {
  /// How long the kidney is, pole to pole.
  static const double length = 120;

  /// The kidney's outline, the capsule where the cut crosses it, closed
  /// across the hilum where the sinus opens: from the upper pole round by
  /// the hilum, the lower pole and the lateral border.
  static const List<Offset> outline = <Offset>[
    Offset(5, -60),
    Offset(13, -58.5),
    Offset(19.5, -55),
    Offset(24.5, -49),
    Offset(27.5, -41),
    Offset(28.5, -32),
    Offset(27.5, -23),
    Offset(24, -15),
    Offset(18.5, -9.5),
    Offset(14.5, -3),
    Offset(12, 4),
    Offset(11.5, 11),
    Offset(13, 18.5),
    Offset(15.5, 26),
    Offset(16.8, 33),
    Offset(16.5, 40),
    Offset(14.5, 47),
    Offset(11, 52.5),
    Offset(6.5, 56.8),
    Offset(1, 59.3),
    Offset(-5, 60),
    Offset(-11, 58.6),
    Offset(-16.5, 55),
    Offset(-21.5, 49),
    Offset(-25.5, 41),
    Offset(-28, 31),
    Offset(-29.2, 19),
    Offset(-29.3, 6),
    Offset(-28.5, -7),
    Offset(-26.7, -20),
    Offset(-24, -32),
    Offset(-20.3, -42),
    Offset(-15.8, -50),
    Offset(-10.5, -55.8),
    Offset(-3, -59.4),
  ];

  /// The outline's knots where the sinus opens: its upper lip and its lower.
  static const int upperLip = 7;
  static const int lowerLip = 13;

  /// How thick the cortex is, from the capsule to the pyramids' bases.
  static const double cortex = 9;

  /// The renal sinus's wall, from the upper lip round inside the kidney to
  /// the lower lip: up into the upper pole above the hilum, where the upper
  /// major calyx reaches, down the lateral side of the sinus and into the
  /// lower pole, where the lower one does.
  static const List<Offset> sinus = <Offset>[
    Offset(24, -15),
    Offset(20, -19),
    Offset(15, -24),
    Offset(10, -29),
    Offset(5, -33),
    Offset(0, -33),
    Offset(-2, -28),
    Offset(-3, -20),
    Offset(-3.5, -11),
    Offset(-4, -2),
    Offset(-4, 7),
    Offset(-3.5, 16),
    Offset(-2, 24),
    Offset(0, 31),
    Offset(4, 35),
    Offset(8, 34),
    Offset(11.5, 30),
    Offset(15.5, 26),
  ];

  /// How many pyramids the cut passes through, and where along the
  /// corticomedullary junction they lie, as shares of it from the upper
  /// lip round over the upper pole, the lateral border and the lower pole
  /// to the lower lip: the first's base from, the last's to.
  static const int pyramids = 8;
  static const double pyramidsFrom = 0.08;
  static const double pyramidsTo = 0.86;

  /// A pyramid's base, a share of its share of the junction: the rest is
  /// the renal columns between it and its neighbours.
  static const double pyramidBase = 0.8;

  /// How far a papilla stands into the sinus past its wall, into its
  /// calyx, and the radius its tip is rounded to.
  static const double papillaInto = 3;
  static const double papillaRound = 2.6;

  /// How far a pyramid's flanks bow out from its axis, a share of their
  /// length; and how far apart along the sinus's wall two papillae open at
  /// least, where pyramids gather toward a pole.
  static const double flankBow = 0.06;
  static const double papillaGap = 8;

  /// The outer medulla, a share of a pyramid from its base, and the papilla,
  /// a share from its tip.
  static const double outerMedulla = 0.4;
  static const double papilla = 0.28;

  /// A minor calyx: how far its cup reaches round its papilla from the
  /// papilla's tip, and how far out from it its wall lies.
  static const double cupBack = 4;
  static const double cupClear = 1.6;

  /// The calyces' necks and the pelvis, each a course and its half widths
  /// along it: the upper, middle and lower major calyces gathering into the
  /// pelvis at the hilum, which narrows into the ureter below it.
  static const List<Offset> upperCalyx = <Offset>[
    Offset(10, -2),
    Offset(7, -13),
    Offset(4, -23),
    Offset(2, -28),
  ];
  static const List<double> upperCalyxHalf = <double>[4.5, 3.2, 2.6, 2.3];
  static const List<Offset> middleCalyx = <Offset>[
    Offset(10, 4),
    Offset(4, 3),
    Offset(-0.5, 2),
  ];
  static const List<double> middleCalyxHalf = <double>[4.5, 3, 2.4];
  static const List<Offset> lowerCalyx = <Offset>[
    Offset(11, 10),
    Offset(8, 19),
    Offset(5, 26),
    Offset(3, 30),
  ];
  static const List<double> lowerCalyxHalf = <double>[4.5, 3.2, 2.6, 2.3];

  /// The pelvis: its course from where the major calyces meet, out
  /// through the hilum and down to the pelviureteric junction, and its half
  /// widths along it.
  static const List<Offset> pelvis = <Offset>[
    Offset(8, 4),
    Offset(15, 9),
    Offset(20, 16),
    Offset(23, 25),
  ];
  static const List<double> pelvisHalf = <double>[6.5, 7.5, 6, 3.6];

  /// The ureter, from the pelvis on down beside the lower pole, and its
  /// radius; how far its end fades.
  static const List<Offset> ureter = <Offset>[
    Offset(23, 25),
    Offset(25, 38),
    Offset(25.5, 52),
    Offset(24.5, 70),
  ];
  static const double ureterRadius = 2.5;
  static const double ureterFade = 20;

  /// The renal artery and vein, from where each enters the sinus out
  /// through the hilum to where the cut leaves it, and their radii.
  static const List<Offset> renalArtery = <Offset>[
    Offset(14, -6),
    Offset(22, -10),
    Offset(30, -12),
    Offset(40, -13),
  ];
  static const double arteryRadius = 2.75;
  static const List<Offset> renalVein = <Offset>[
    Offset(13, 1),
    Offset(22, 0),
    Offset(31, 0.5),
    Offset(40, 2),
  ];
  static const double veinRadius = 5;

  /// The vessels inside: the segmental arteries' radius, from the renal
  /// artery to each column's root; the interlobar arteries' up each column;
  /// the arcuate arteries' over each pyramid's base; and the vein's
  /// branches into the sinus, their radius.
  static const double segmentalRadius = 1.2;
  static const double interlobarRadius = 0.8;
  static const double arcuateRadius = 0.5;
  static const double veinBranchRadius = 2.2;
  static const List<List<Offset>> veinBranches = <List<Offset>>[
    <Offset>[Offset(13, 1), Offset(7, -6), Offset(3, -14)],
    <Offset>[Offset(13, 1), Offset(6, 8), Offset(3, 16)],
  ];

  /// The medullary rays: how wide, how far apart along a pyramid's base,
  /// and how far short of the capsule each stops.
  static const double ray = 0.5;
  static const double raySpacing = 1.8;
  static const double rayShort = 1.2;

  /// The glomeruli: their radius, and how many to a square millimetre of
  /// the cortex the cut shows, a quarter of those it holds.
  static const double glomerulus = 0.115;
  static const double glomeruliPerMm2 = 0.5;

  /// Where the renal pelvis and the ureter are named: the pelvis's middle,
  /// and the ureter well below the hilum.
  static const Offset pelvisName = Offset(17, 12);
  static const Offset ureterName = Offset(25.3, 48);

  /// How far down the kidney, from its top, the cortex and the medulla are
  /// named on its lateral side.
  static const double cortexNameDown = 0.25;
  static const double medullaNameDown = 0.48;
}
