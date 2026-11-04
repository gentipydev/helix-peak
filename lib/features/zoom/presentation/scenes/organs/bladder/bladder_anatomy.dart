import 'dart:ui';

import '../../tube_course.dart';

/// The urinary bladder the anatomogram draws for the bladder, opened from
/// the front and seen from the front, as the body shows it: its front wall
/// cut away, so that what is seen is the inside of its back half, and the
/// wall cut through all round it. It is drawn from general anatomy, in
/// millimetres, x across to the body's left, y down, from the middle of its
/// outline's box.
///
/// It is drawn part-filled, as a plate of the bladder's inside is: the
/// mucosa of its back wall, smooth over the trigone and thrown into low
/// folds round the base and the lower sides, the dome stretched smooth; the
/// trigone between the two ureteric orifices, slits at the ends of the
/// torus uretericus, and the internal urethral orifice at the neck; round
/// it all, the cut wall's coats, its muscle thickened into the sphincter
/// round the neck. Outside it, the ureters coming down to it and the
/// urethra leaving it, and the vesical arteries, each cut short.
///
/// What is measured. After Gray (1918, pp. 1226-1236, read in the
/// archive.org text of the 20th edition, and Fig. 1140): moderately full,
/// the bladder holds about half a litre and is an oval about 12 cm long;
/// its mucosa is "of a pale rose color", loosely attached to the muscle and
/// "wrinkled or folded when the bladder is contracted", the folds "effaced"
/// when it is distended; over the trigone it is bound to the muscle and
/// "always smooth"; the trigone's angles are the internal urethral orifice
/// in front and the ureters' orifices behind; the torus uretericus, "a
/// slightly curved ridge", is its base and shows as "a pale band", and runs
/// on past the orifices as the plicae uretericae, which the ureters raise as
/// they run obliquely for about 2 cm through the wall; the ureters' orifices
/// are "slit-like", about 2.5 cm apart in the contracted bladder and as far
/// from the urethral orifice, and up to about 5 cm in the distended; the
/// internal urethral orifice, at the trigone's apex in "the most dependent
/// part of the bladder", is "somewhat crescentic"; the wall has four coats,
/// serous (over the dome alone), muscular, submucous and mucous, its muscle
/// in three layers, the middle one "a thick circular layer" round the
/// urethral orifice, the sphincter vesicae; the arteries are the superior,
/// middle and inferior vesical, and in the female branches of the uterine
/// and vaginal; the female urethra is about 4 cm long and "about 6 mm"
/// across, running down and forward. The wall is 2.0 ± 0.4 mm thick at
/// 338 ± 82 mL on ultrasound in 95 healthy adults (Kanyilmaz et al. 2013,
/// J Res Med Sci 18:103), and on CT in 111 women 3.5 mm on average, 1.9 mm
/// where the bladder is 9 cm long or more (Feinberg et al. 2026, Cureus
/// 18:e116549); its detrusor is 1.2 mm in women and 1.4 mm in men, the same
/// from 250 mL on (Oelke et al. 2006, Neurourol Urodyn 25:308, 55 healthy
/// adults); its lamina propria is 0.46 to 1.58 mm deep at the trigone and
/// 0.98 to 3.07 mm at the dome in resected bladders (Paner et al. 2007, Am
/// J Surg Pathol 31:1420). GTEx samples the "Central posterior urinary
/// bladder, trimming from the outer wall if necessary" (the GTEx Portal's
/// sampling site for Bladder, gtex_v10), which faces the eye here.
///
/// Drawing choices, measured by none of these: the outline, drawn to the
/// female anatomogram's own proportions, 100 mm across, as the zoom's card
/// has it; the wall through each part, between those measurements, and
/// 3.6 mm in the sphincter round the neck; the coats' shares of it; the
/// trigone seen foreshortened to three quarters of its height, as the
/// sloping base is from the front, its orifices 35 mm apart, between
/// Gray's two; the torus's bow; the plicae 12 mm; the slits 4 mm and the
/// crescent 6 mm; where the folds run, how long they are and how much they
/// wander, and none in the upper third; the ureters 5 mm across, their
/// courses, and where they are cut; the urethra cut 15 mm below the neck;
/// the arteries' courses and widths, and their branches to the wall.
abstract final class BladderAnatomy {
  /// How wide the bladder is, across: its longest side, seen from the
  /// front.
  static const double length = 100;

  /// The right half of the bladder's outline, the serosa where the cut
  /// crosses the wall: from the middle of the dome down the body's left
  /// side to the neck's lowest point, below the urethral orifice. The
  /// outline is the same either side of the middle.
  static const List<Offset> half = <Offset>[
    Offset(0, -37.2),
    Offset(10, -36.7),
    Offset(20, -35.4),
    Offset(28.5, -33.5),
    Offset(34.5, -31),
    Offset(39.5, -27.6),
    Offset(43.5, -23.4),
    Offset(46.6, -18.4),
    Offset(48.6, -13),
    Offset(49.7, -7.2),
    Offset(50, -1.8),
    Offset(49.6, 3.4),
    Offset(48.4, 8.2),
    Offset(46.1, 12.4),
    Offset(42.8, 16.6),
    Offset(38.9, 20.4),
    Offset(34.6, 23.3),
    Offset(29, 25),
    Offset(22, 26),
    Offset(15.5, 27),
    Offset(11, 28.4),
    Offset(8, 30.2),
    Offset(6.6, 32.6),
    Offset(6, 35.2),
    Offset(4, 37),
    Offset(0, 37.4),
  ];

  /// How thick the wall is at each of [half]'s points: thinnest over the
  /// dome, thicker down the sides and round the base, thickest in the
  /// sphincter round the neck, and none at the neck's lowest point, where
  /// the urethra's lumen runs on.
  static const List<double> wall = <double>[
    1.8, 1.8, 1.8, 1.85, 1.9, 1.95, 2, 2, 2, 2, //
    2, 2.05, 2.1, 2.2, 2.3, 2.4, 2.4, 2.4, 2.45, 2.6, //
    3, 3.4, 3.6, 3.6, 2.6, 0,
  ];

  /// The wall's coats, from the outside in, each a share of the wall at
  /// most so many millimetres: the serosa, the lamina propria and the
  /// urothelium; the detrusor is the rest, so that it is what thickens into
  /// the sphincter.
  static const double serosaShare = 0.08;
  static const double serosaMost = 0.2;
  static const double laminaShare = 0.3;
  static const double laminaMost = 0.8;
  static const double urotheliumShare = 0.025;
  static const double urotheliumMost = 0.08;

  /// Where the body goes into the bladder, in its back wall, above the
  /// trigone: the drawing is laid so that this lies on the place the body's
  /// outline of it is gone into.
  static const Offset site = Offset(-2.9, -4.1);

  // The trigone.

  /// The ureters' orifices, at the trigone's two upper corners, and the
  /// internal urethral orifice at its apex, where the base runs down into
  /// the neck.
  static const Offset rightOrifice = Offset(17.5, 7);
  static const Offset urethralOrifice = Offset(0, 29.5);

  /// How far the torus uretericus bows up from the line between the
  /// orifices, away from the neck, at its middle.
  static const double torusBow = 1.5;

  /// How long each plica ureterica runs up and out from its orifice, and
  /// at what angle above the level, in radians: the way each ureter comes
  /// through the wall.
  static const double plica = 12;
  static const double plicaRise = 0.6;

  /// How long and wide each ureter's slit is, laid along its plica; how
  /// wide the urethral orifice's crescent is, and how deep.
  static const double slit = 4;
  static const double slitWidth = 0.8;
  static const double crescent = 6;
  static const double crescentDepth = 1.2;

  // The folds.

  /// Each low fold of the mucosa: where it starts, low, and where it ends,
  /// up and out, and the seed of its wandering. They run up and out from
  /// round the base and the lower sides, none over the trigone and none in
  /// the upper third, where the dome has stretched smooth.
  static const List<(Offset, Offset, int)> folds = <(Offset, Offset, int)>[
    (Offset(-21, 21), Offset(-33, 8), 1),
    (Offset(-29, 17.5), Offset(-36, 9.5), 2),
    (Offset(-13.5, 23), Offset(-23, 14.5), 3),
    (Offset(-37, 13), Offset(-44.5, -1), 4),
    (Offset(-32.5, -2.5), Offset(-39.5, -10.5), 5),
    (Offset(-11, 1.5), Offset(-18.5, -7), 6),
    (Offset(21, 20.5), Offset(34, 7.5), 7),
    (Offset(30, 16), Offset(36.5, 9), 8),
    (Offset(13, 23.2), Offset(24, 14), 9),
    (Offset(38, 11.5), Offset(45, -3), 10),
    (Offset(31.5, -2), Offset(38.5, -10), 11),
    (Offset(10.5, 1), Offset(17.5, -8), 12),
  ];

  /// How far a fold wanders to either side at most, and the two
  /// wavelengths it wanders by; how long a fold must be to break off once,
  /// and for how long.
  static const double wander = 0.35;
  static const double wave = 16;
  static const double ripple = 7;
  static const double breakFrom = 16;
  static const double breakLength = 2.5;

  // What runs on beside it, cut short.

  /// The right ureter, from behind the bladder's lateral angle, where it
  /// goes into the wall at the torus's level, up beside the wall to where
  /// it is cut short above and to the side.
  static const AnatomyTube rightUreter = AnatomyTube(
    <Offset>[
      Offset(42, 10),
      Offset(49, 6),
      Offset(54.5, -6),
      Offset(57, -20),
      Offset(57.5, -34),
    ],
    <double>[2.5, 2.5, 2.5, 2.5, 2.5],
    cutEnd: true,
  );

  /// The urethra, from inside the neck down to where it is cut short.
  static const AnatomyTube urethra = AnatomyTube(
    <Offset>[Offset(0, 33), Offset(0, 42.5), Offset(0, 52)],
    <double>[3, 3, 3],
    cutEnd: true,
  );

  /// The right superior vesical artery, from over the bladder's upper
  /// side, round its shoulder outside the wall, up to where it is cut short
  /// toward its origin; and the right inferior vesical, from the bladder's
  /// base round its lower corner, out to where it is cut short below and
  /// to the side.
  static const AnatomyTube rightSuperior = AnatomyTube(
    <Offset>[
      Offset(24, -39.5),
      Offset(33, -38),
      Offset(40.5, -35),
      Offset(46, -39),
      Offset(50, -46),
    ],
    <double>[0.6, 0.65, 0.7, 0.75, 0.75],
    cutEnd: true,
  );
  static const AnatomyTube rightInferior = AnatomyTube(
    <Offset>[
      Offset(29, 28.5),
      Offset(38, 25.5),
      Offset(46, 21),
      Offset(52, 25),
      Offset(57, 30),
    ],
    <double>[0.5, 0.55, 0.6, 0.6, 0.6],
    cutEnd: true,
  );

  /// The small branches into the wall: about how far apart along an
  /// artery, and how much more or less, how near the wall it must run to
  /// send one, how far ahead or behind along it each leans, how far under
  /// the wall each goes, and how wide each is.
  static const double branchApart = 13;
  static const double branchJitter = 4;
  static const double branchReach = 12;
  static const double branchLean = 3;
  static const double branchUnder = 2;
  static const double branch = 0.3;

  // Where the parts are named.

  /// The trigone, named in its half on the body's right, the side its
  /// orifice is named on, so that its name's line and the urethra's, which
  /// lies under its middle, never meet.
  static const Offset trigoneName = Offset(-6, 13);

  /// The detrusor, named in the cut wall of the body's left side, and the
  /// urethra at its middle.
  static const Offset detrusorName = Offset(50, -8);
  static const Offset urethraName = Offset(0, 46);

  /// The left ureter, on the body's right, named where it runs beside the
  /// wall, on the side its orifice is named: the figure's neighbour below
  /// is named on the other.
  static const Offset ureterName = Offset(-56, -13);
}
