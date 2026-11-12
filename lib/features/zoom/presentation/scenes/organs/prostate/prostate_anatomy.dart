import 'dart:ui';

import '../../tube_course.dart';

/// The prostate the anatomogram draws on the male figure, seen from the
/// front in place as the body shows it, and cut from front to back through
/// its ejaculatory ducts and its urethra below the verumontanum, its front
/// taken away, so that its zones show as the disc of secretory tissue they
/// form in that plane: the central zone a cone round the ejaculatory ducts,
/// its base the prostate's, its apex at the verumontanum; the peripheral
/// zone round it and down to the apex, its ducts radiating from the
/// urethra; the urethra laid open from the verumontanum to the apex, the
/// urethral crest down its floor; the seminal vesicles and the ampullae of
/// the deferent ducts above the base, coming down to it to make the
/// ejaculatory ducts; the membranous urethra in its sphincter below the
/// apex, cut short. It is drawn from general anatomy, in millimetres, x
/// across to the body's left, which from the front is the screen's right,
/// y down, from the middle of the prostate's box.
///
/// What is measured. After Gray (1918, read in the archive.org text of the
/// 20th edition): the prostate "is about the size of a chestnut and
/// somewhat conical in shape", its base "directed upward" and "applied to
/// the inferior surface of the bladder", its apex "directed downward"; it
/// "measures about 4 cm. transversely at the base, 2 cm. in its
/// antero-posterior diameter, and 3 cm. in its vertical diameter. Its
/// weight is about 8 gm."; "near its upper border there is a depression
/// through which the two ejaculatory ducts enter"; "the ejaculatory ducts
/// pass obliquely downward and forward through the posterior part of the
/// prostate, and open into the prostatic portion of the urethra"; "the
/// substance of the prostate is of a pale reddish-gray color, of great
/// density", its muscular tissue "looser and more sponge-like toward the
/// apex"; "the prostatic ducts open into the floor of the prostatic portion
/// of the urethra" (pp. 1251-1253). The prostatic urethra is "about 3 cm.
/// long", "spindle-shaped, being wider in the middle than at either
/// extremity, and narrowest below"; on its posterior wall the urethral
/// crest, "from 15 to 17 mm. in length, and about 3 mm. in height"; on
/// either side "the prostatic sinus, the floor of which is perforated by
/// numerous apertures, the orifices of the prostatic ducts"; on the crest
/// "the colliculus seminalis, upon or within the margins of which are the
/// orifices of the prostatic utricle and the slit-like openings of the
/// ejaculatory ducts"; the utricle "a cul-de-sac about 6 mm. long" (pp.
/// 1234-1235). The seminal vesicles are "usually about 7.5 cm. long", their
/// "lower extremities are pointed, and converge toward the base of the
/// prostate, where each joins with the corresponding ductus deferens to
/// form the ejaculatory duct", "along the medial margin of each vesicle
/// runs the ampulla of the ductus deferens"; each ejaculatory duct "is
/// about 2 cm. long", running "along the sides of the prostatic utricle",
/// the ducts diminishing in size and converging toward their ends (pp.
/// 1246-1247). In 500 prostates the peripheral zone is over 70% of the
/// glandular prostate, its ducts radiating laterally from the urethra
/// lateral and distal to the verumontanum; the central zone 25%, its ducts
/// arising close to the ejaculatory ducts' orifices and following them up,
/// branching laterally near the base, the two together a full disc of
/// secretory tissue in a coronal plane; the urethra above the verumontanum
/// bends forward 35 degrees out of it, a small transition zone and a
/// sphincter round it there, where nodular hyperplasia arises (McNeal
/// 1981, Prostate 2:35). GTEx samples the prostate from a "Non-nodular
/// region of representative region" (the GTEx Portal's sampling site for
/// Prostate, gtex_v10, read on 2026-11-12).
///
/// Drawing choices, measured by none of these: the outline's curve, 40 mm
/// across its base and 32 mm tall, Gray's 4 by 3 cm; the cut laid in
/// McNeal's coronal plane, so the urethra above the verumontanum, the
/// transition zone and the anterior fibromuscular stroma, all in front of
/// it, are not cut; the central zone's cone 23 mm across the base; the
/// ducts' courses and their branching; the lumens of the glands as pores,
/// denser toward the apex; the opened urethra's width; the colliculus 3 by
/// 4.4 mm; the ejaculatory ducts 1.2 mm across at the base; the seminal
/// vesicles' and the ampullae's courses, widths and coils, cut short above
/// as they run on out of the view; the prostatic arteries' courses; the
/// sphincter round the membranous urethra; the place the body goes in, in
/// the peripheral zone on the body's right below the verumontanum's level,
/// 3.5 mm in from the capsule.
abstract final class ProstateAnatomy {
  /// How wide the prostate is across its base: the zoom's card's 4 cm.
  static const double width = 40;

  /// The cut face's outline, round from the middle of its base over its
  /// left side, its apex and its right side: a chestnut, its base broad
  /// and a little dipped where the ejaculatory ducts enter, its apex
  /// narrow.
  static const List<Offset> outline = <Offset>[
    Offset(0, -15.55),
    Offset(3, -15.75),
    Offset(7, -15.95),
    Offset(11, -15.85),
    Offset(14.8, -14.95),
    Offset(17.6, -13.05),
    Offset(19.4, -10.2),
    Offset(20, -6.6),
    Offset(19.7, -2.6),
    Offset(18.5, 1.6),
    Offset(16.3, 5.8),
    Offset(12.9, 9.9),
    Offset(9.2, 13.2),
    Offset(5.4, 15.35),
    Offset(2.6, 16.2),
    Offset(0, 16.4),
    Offset(-2.6, 16.2),
    Offset(-5.4, 15.35),
    Offset(-9.2, 13.2),
    Offset(-12.9, 9.9),
    Offset(-16.3, 5.8),
    Offset(-18.5, 1.6),
    Offset(-19.7, -2.6),
    Offset(-20, -6.6),
    Offset(-19.4, -10.2),
    Offset(-17.6, -13.05),
    Offset(-14.8, -14.95),
    Offset(-11, -15.85),
    Offset(-7, -15.95),
    Offset(-3, -15.75),
  ];

  /// The central zone: its border on the body's left, from the base down to
  /// the verumontanum (the right's is its mirror), and how far above the
  /// base it is closed, outside the outline, which bounds it.
  static const List<Offset> centralBorder = <Offset>[
    Offset(11.6, -17),
    Offset(11.4, -15.6),
    Offset(10.5, -11.5),
    Offset(8.5, -7.3),
    Offset(5.7, -3.8),
    Offset(2.9, -1.6),
    Offset(1.2, -0.9),
    Offset(0, -0.7),
  ];

  /// The colliculus seminalis on the floor of the opened urethra: its middle
  /// and its half-width and half-height; the utricle's orifice on it, and
  /// the ejaculatory ducts' slits beside that.
  static const Offset colliculus = Offset(0, 0.6);
  static const double colliculusAcross = 1.5;
  static const double colliculusDown = 2.2;
  static const Offset utricleMouth = Offset(0, -0.1);
  static const Offset ductMouth = Offset(0.75, 0.95);

  /// The utricle, a blind sac from its orifice up between the ejaculatory
  /// ducts, Gray's 6 mm, and how wide.
  static const double utricleTop = -6.2;
  static const double utricleWidth = 1.3;

  /// The urethra, laid open from just above the colliculus to the apex: its
  /// half-width down it, at each of these depths.
  static const List<(double, double)> urethra = <(double, double)>[
    (-2.6, 0),
    (-2.1, 1.6),
    (-1.0, 2.5),
    (3.0, 2.6),
    (8.0, 2.0),
    (13.0, 1.35),
    (16.8, 1.05),
  ];

  /// The urethral crest down the urethra's floor below the colliculus, to
  /// this depth, and how wide; the prostatic sinuses either side of it,
  /// their duct orifices this far out from the middle, from and to these
  /// depths, this far apart.
  static const double crestTo = 9.5;
  static const double crestWidth = 0.7;
  static const double sinusOut = 1.55;
  static const double sinusFrom = 3.4;
  static const double sinusTo = 9.6;
  static const double sinusApart = 1.05;

  /// The smooth muscle round the urethra below the verumontanum: how thick
  /// at its top, and at the apex, where the sphincter begins.
  static const double sleeve = 0.8;
  static const double sleeveApex = 1.6;

  /// The ejaculatory duct on the body's left (the right's is its mirror):
  /// from the base, where its seminal vesicle and its ampulla meet, down
  /// along the utricle to its slit on the colliculus; how wide its wall is
  /// at the base and at its end, and its lumen.
  static const List<Offset> duct = <Offset>[
    Offset(2.7, -15.6),
    Offset(2.45, -11.5),
    Offset(1.9, -7),
    Offset(1.25, -3),
    Offset(0.75, 0.95),
  ];
  static const double ductBase = 0.8;
  static const double ductEnd = 0.42;
  static const double ductLumen = 0.12;

  /// The ducts of the peripheral zone on the body's left (the right's are
  /// their mirror): each from where it leaves the urethra's side, at this
  /// depth, out at this angle from straight across (up negative), this far;
  /// and the share of the way along it branches at, and its branch's turn.
  static const List<(double, double, double, double, double)> peripheralDucts =
      <(double, double, double, double, double)>[
        (1.2, -1.15, 15.5, 0.55, 0.35),
        (2.8, -0.85, 15.6, 0.5, -0.32),
        (4.4, -0.55, 15.4, 0.55, 0.3),
        (6.0, -0.28, 14.6, 0.5, -0.3),
        (7.6, -0.02, 13.4, 0.55, 0.3),
        (9.2, 0.24, 11.8, 0.5, -0.3),
        (10.8, 0.5, 10, 0.55, 0.28),
        (12.4, 0.78, 7.8, 0.5, -0.28),
        (14.0, 1.05, 5.4, 0.55, 0.25),
      ];

  /// The ducts of the central zone on the body's left: each from beside the
  /// ejaculatory duct's orifice up along it to near the base, where it
  /// branches out to the side.
  static const List<List<Offset>> centralDucts = <List<Offset>>[
    <Offset>[
      Offset(1.5, -0.6),
      Offset(3.2, -5),
      Offset(4.6, -10),
      Offset(5.4, -14.4),
    ],
    <Offset>[
      Offset(2.4, -1.4),
      Offset(4.6, -5.4),
      Offset(6.6, -9.6),
      Offset(8.6, -14),
    ],
    <Offset>[Offset(4.6, -10), Offset(6.6, -12.4), Offset(7.6, -14.8)],
    <Offset>[Offset(6.6, -9.6), Offset(9, -11.6), Offset(10.4, -14.4)],
  ];

  /// How many pores, the lumens of the glands, the cut face shows, and how
  /// wide the least and the most; how many times denser they lie at the
  /// apex than at the base.
  static const int pores = 90;
  static const double poreLeast = 0.28;
  static const double poreMost = 0.6;
  static const double poreApex = 3;

  /// Where the body goes in: in the peripheral zone on the body's right,
  /// below the verumontanum's level, clear of its ducts.
  static const Offset site = Offset(-13.4, 4.6);

  /// The seminal vesicle on the body's left (the right's is its mirror):
  /// its course up and out from its pointed lower end at the base, and how
  /// wide it is at each knot, before its coils; how far apart its coils
  /// are along it and how deep; how far it fades out over, above.
  static const List<Offset> vesicle = <Offset>[
    Offset(4.6, -14.8),
    Offset(8.8, -17.6),
    Offset(13.8, -20),
    Offset(18.6, -22),
    Offset(23.2, -23.6),
  ];
  static const List<double> vesicleRadii = <double>[2.4, 3.6, 4.6, 5.2, 5.4];
  static const double coil = 4.2;
  static const double coilDepth = 0.1;
  static const double vesicleFade = 7;

  /// The ampulla of the deferent duct on the body's left, along the
  /// vesicle's medial margin: its course up from the base, tortuous, how
  /// wide, how far each turn of it swings and how long one is; fading out
  /// above as the duct runs on.
  static const List<Offset> ampulla = <Offset>[
    Offset(1.7, -15),
    Offset(3.1, -18.6),
    Offset(4.6, -22.2),
    Offset(6.2, -25.4),
    Offset(7.6, -27.8),
  ];
  static const List<double> ampullaRadii = <double>[1.5, 2.3, 2.3, 1.9, 1.5];
  static const double ampullaSwing = 0.32;
  static const double ampullaTurn = 5.2;
  static const double ampullaFade = 6;

  /// The prostatic artery on the body's left, from the inferior vesical,
  /// coming in to the base's corner (the right's is its mirror).
  static const AnatomyTube artery = AnatomyTube(
    <Offset>[
      Offset(31, -12.6),
      Offset(27, -13.4),
      Offset(22.6, -12.8),
      Offset(19, -11),
    ],
    <double>[0.75, 0.75, 0.72, 0.68],
    fadeIn: 6,
  );

  /// The membranous urethra in its sphincter below the apex, cut short.
  static const AnatomyTube sphincter = AnatomyTube(
    <Offset>[Offset(0, 14.8), Offset(0, 17), Offset(0.1, 19)],
    <double>[3.8, 3.7, 3.6],
    cutEnd: true,
  );

  // Where the parts are named.

  /// The central zone toward the base's corner on the body's left; the
  /// urethra's lumen on its right side, below the crest; the colliculus
  /// on its left side.
  static const Offset centralName = Offset(8.4, -12.6);
  static const Offset urethraName = Offset(-1.2, 11.2);
  static const Offset verumontanumName = Offset(0.9, 0.9);
}
