import 'dart:ui';

import '../../tube_course.dart';

/// The right epididymis seen from its lateral side, as Gray's plate of the
/// right testis exposed by laying open the tunica vaginalis shows it, and
/// cut down its length to show its ducts as Gray's vertical section shows
/// them: on the back of its testis, which lies whole beside it, the
/// testis's upper pole up and tilted a little forward. It is drawn from
/// general anatomy, in millimetres, x forward (the testis's side), y down,
/// from the middle of the epididymis's own outline.
///
/// What is measured. After Gray (1918, pp. 1240-1246, read in the
/// archive.org text of the 20th edition, and Figs. 1148, "The right testis,
/// exposed by laying open the tunica vaginalis", and 1149, "Vertical
/// section of the testis, to show the arrangement of the ducts"): the
/// testis is 4 to 5 cm long, 2.5 cm broad and 3 cm from front to back, its
/// upper end directed forward; the epididymis is "a long, narrow,
/// flattened body" lying on the lateral edge of the testis's posterior
/// border, its upper end enlarged, the head, its lower end pointed, the
/// tail, continuous with the ductus deferens, its middle the body; between
/// the body and the testis is a pouch, the sinus of the epididymis; twelve
/// to fifteen or twenty efferent ductules leave the rete at the upper end
/// of the mediastinum, perforate the tunica albuginea and, "exceedingly
/// convoluted", form the coni vasculosi, which "together constitute the
/// head of the epididymis", each cone a single convoluted duct; opposite
/// the bases of the cones they open into a single duct which by its
/// convolutions makes the body and the tail, "upward of 6 meters" long
/// unravelled, increasing in diameter "as it approaches the ductus
/// deferens", its convolutions held together by fine areolar tissue and
/// bands of fibrous tissue; the tunica albuginea is bluish-white; the
/// ductus deferens begins at the lower part of the tail, "at first very
/// tortuous", and ascends along the posterior border of the testis and the
/// medial side of the epididymis into the spermatic cord, with the
/// testicular artery and the pampiniform plexus. In man the proximal
/// epididymis is formed by the efferent ducts alone (Sullivan et al. 2019,
/// Andrology 7:748), which join the epididymal duct near the border of the
/// head and the body (Saitoh et al. 1990, Int J Androl 13:369); 14.7
/// efferent ducts on average, 3.0 m long together, occupy most of the
/// head, and the epididymal duct is in segments parted by little or no
/// connective tissue (Nakata et al. 2024, Andrology 12:87). On ultrasound
/// in 248 healthy fertile men the epididymal head is at most 12 mm, its
/// tail at most 6 mm and the vas deferens at most 4.5 mm, and the testis is
/// about 17 ml (Lotti et al. 2021, Andrology 9:559); the vas deferens is
/// 1.5–2.7 mm thick (Middleton et al. 2009, J Ultrasound Med 28:839); the
/// testicular artery about 1 mm across in the cord (Raman and Goldstein
/// 2004, Urology 64:561).
///
/// Drawing choices, measured by none of these: the outline, the head 6 mm
/// above the testis's upper pole and 8.5 mm thick, the body 4.6 mm, the
/// tail 6 mm; the testis an ellipse 47 by 30 mm tilted 8°, the
/// epididymis lying 1.6 mm in over its edge, 2.2 mm at the head; ten cones
/// in the cut, of the fifteen or so, shared out along the head; where the
/// head ends; seven septa across the duct; the duct's profiles, 0.6 mm
/// across at the body's top and 0.9 mm at the tail; where the tissue is
/// sampled; the courses of the vas deferens and of the cord's vessels; the
/// sac round them.
abstract final class EpididymisAnatomy {
  /// How long the epididymis is, from its head's top to its tail's
  /// lowest point: about 5 cm, as the zoom's card has it (drawn, 53 mm).
  static const double length = 50;

  /// The epididymis's outline where the cut crosses it: from the head's top
  /// forward over the testis's upper pole to the head's front end, back
  /// along the head's underside over the testis, down the body's front edge
  /// over the testis's back border, round the tail under its lower pole,
  /// and up the back.
  static const List<Offset> outline = <Offset>[
    Offset(4.1, -26.6),
    Offset(9.1, -25.2),
    Offset(12.2, -22.9),
    Offset(13.0, -20.5),
    Offset(11.8, -18.6),
    Offset(8.2, -19.0),
    Offset(5.8, -19.0),
    Offset(3.3, -18.2),
    Offset(0.8, -16.6),
    Offset(-1.6, -14.2),
    Offset(-4.3, -11.3),
    Offset(-6.1, -7.6),
    Offset(-7.4, -3.3),
    Offset(-8.2, 1.2),
    Offset(-8.4, 5.8),
    Offset(-8.0, 10.0),
    Offset(-7.1, 14.0),
    Offset(-5.6, 17.5),
    Offset(-3.7, 20.2),
    Offset(-1.5, 22.2),
    Offset(0.9, 23.5),
    Offset(2.2, 24.5),
    Offset(1.6, 26.0),
    Offset(-0.7, 26.6),
    Offset(-4.8, 26.4),
    Offset(-8.0, 24.4),
    Offset(-9.8, 20.4),
    Offset(-11.4, 15.5),
    Offset(-12.6, 10.8),
    Offset(-13.0, 5.8),
    Offset(-12.8, 0.7),
    Offset(-11.9, -4.4),
    Offset(-10.4, -9.2),
    Offset(-8.4, -13.2),
    Offset(-6.8, -17.2),
    Offset(-5.0, -21.6),
    Offset(-1.5, -25.2),
  ];

  /// How many of the outline's points, from the head's front end, run down
  /// its front edge over the testis, the sinus's side: the first and the
  /// last of them.
  static const int frontFrom = 4;
  static const int frontTo = 21;

  /// How thick the tunica round the epididymis is.
  static const double tunica = 0.3;

  // The head and its cones.

  /// Where the head ends, across the epididymis: a point on the line, and
  /// the way across the line toward the head.
  static const Offset headEnd = Offset(-5.2, -12.6);
  static const Offset towardHead = Offset(0.45, -0.89);

  /// The cones of efferent ductules in the cut: how many. The ductules come
  /// up into the head all along its underside, where it lies on the testis,
  /// so each cone's apex is on the underside and its base on the head's top
  /// and back; between them the head is shared out alike along both, from
  /// where the head ends to its front end, the outline's point [frontEnd].
  static const int cones = 10;
  static const int frontEnd = 3;

  /// How far in from the underside the ductules begin to coil, and how
  /// tightly: the wave each coils in along its cone, and the share of the
  /// cone's width it swings across.
  static const double hilum = 0.8;
  static const double coilWave = 0.9;
  static const double coilSwing = 0.72;

  // The duct, in the body and the tail.

  /// The septa across it, each from its front edge to its back.
  static const List<(Offset, Offset)> septa = <(Offset, Offset)>[
    (Offset(-6.6, -6.1), Offset(-11.2, -6.9)),
    (Offset(-7.8, -1.0), Offset(-12.4, -1.6)),
    (Offset(-8.35, 4.0), Offset(-13.0, 3.9)),
    (Offset(-8.2, 8.6), Offset(-12.8, 9.0)),
    (Offset(-7.4, 13.0), Offset(-11.8, 14.0)),
    (Offset(-5.3, 18.0), Offset(-10.0, 19.8)),
    (Offset(-2.4, 21.5), Offset(-6.4, 25.4)),
  ];

  /// The duct's profiles where the cut crosses its coils: their radius at
  /// the body's top and at the tail's lowest point, at most how much longer
  /// than wide, and how far apart and how far in from the edges and the
  /// septa they keep.
  static const double profileTop = 0.3;
  static const double profileTail = 0.45;
  static const double profileLong = 1.9;
  static const double profileGap = 0.16;
  static const double profileClear = 0.22;

  /// Where the tissue is sampled: in the duct, just below where the head
  /// ends, where the efferent ductules have opened into it. The drawing is
  /// laid so that this lies on the place the body's outline of the
  /// epididymis is gone into.
  static const Offset site = Offset(-7.2, -10.4);

  // The testis.

  /// The testis, whole: an ellipse round its middle, half as long and half
  /// as deep from front to back as it is, its upper pole turned forward.
  static const Offset testisCentre = Offset(5.2, 2.0);
  static const double testisHalfLength = 23.5;
  static const double testisHalfDepth = 15;
  static const double testisTilt = 8;

  /// The sac of the tunica vaginalis, laid open round them both.
  static const List<Offset> sac = <Offset>[
    Offset(2.7, -30.1),
    Offset(10.4, -28.5),
    Offset(16.2, -23.0),
    Offset(20.1, -17.0),
    Offset(22.7, -11.2),
    Offset(23.9, -5.3),
    Offset(23.9, 0.3),
    Offset(23.4, 5.9),
    Offset(22.2, 11.6),
    Offset(19.8, 17.4),
    Offset(15.8, 23.0),
    Offset(10.0, 27.5),
    Offset(2.7, 29.7),
    Offset(-5.2, 29.9),
    Offset(-11.7, 25.3),
    Offset(-14.7, 17.8),
    Offset(-16.5, 11.4),
    Offset(-16.8, 5.6),
    Offset(-16.4, 0.4),
    Offset(-15.5, -4.5),
    Offset(-14.3, -9.4),
    Offset(-12.1, -14.5),
    Offset(-9.5, -20.8),
    Offset(-4.8, -27.5),
  ];

  // The cord.

  /// The vas deferens, from the tail's lowest part, under it, hairpinned
  /// up behind the body, tortuous at first, then on up out of the view in
  /// the cord.
  static const AnatomyTube vas = AnatomyTube(
    <Offset>[
      Offset(-6.5, 24.6),
      Offset(-9.4, 26.6),
      Offset(-12.0, 25.4),
      Offset(-13.4, 21.8),
      Offset(-14.2, 17.8),
      Offset(-13.4, 14.8),
      Offset(-14.4, 11.8),
      Offset(-13.6, 8.8),
      Offset(-14.4, 5.8),
      Offset(-13.7, 2.8),
      Offset(-14.0, -0.6),
      Offset(-13.2, -4.6),
      Offset(-12.0, -9.4),
      Offset(-10.6, -14.4),
      Offset(-9.6, -19.6),
      Offset(-9.0, -25.0),
      Offset(-8.8, -30.0),
      Offset(-8.7, -32.0),
    ],
    <double>[
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
      1.1,
    ],
    fadeOut: 8,
  );

  /// The testicular artery, down the cord, winding, behind the head to the
  /// testis's back at the mediastinum's upper end, where it goes in.
  static const AnatomyTube artery = AnatomyTube(
    <Offset>[
      Offset(-4.6, -32.0),
      Offset(-3.8, -34.0),
      Offset(-5.0, -30.0),
      Offset(-4.2, -26.5),
      Offset(-4.8, -23.0),
      Offset(-3.6, -20.0),
      Offset(-2.4, -17.4),
    ],
    <double>[0.5, 0.5, 0.5, 0.48, 0.47, 0.46, 0.45],
    fadeIn: 8,
  );

  /// The veins of the pampiniform plexus, up the cord round the artery
  /// from the testis's back: the first two behind it, the rest in front;
  /// each drawn from above.
  static const List<AnatomyTube> veins = <AnatomyTube>[
    AnatomyTube(
      <Offset>[
        Offset(-7.2, -32.0),
        Offset(-6.2, -33.4),
        Offset(-7.4, -29.2),
        Offset(-6.0, -25.4),
        Offset(-6.6, -21.8),
        Offset(-5.0, -18.8),
        Offset(-3.6, -16.6),
      ],
      <double>[0.72, 0.72, 0.72, 0.7, 0.68, 0.66, 0.62],
      fadeIn: 8,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-1.6, -32.0),
        Offset(-2.8, -33.6),
        Offset(-1.4, -29.4),
        Offset(-2.6, -25.6),
        Offset(-1.8, -22.0),
        Offset(-2.6, -19.2),
        Offset(-1.6, -16.8),
      ],
      <double>[0.72, 0.7, 0.7, 0.68, 0.66, 0.64, 0.6],
      fadeIn: 8,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-5.0, -32.0),
        Offset(-6.4, -34.4),
        Offset(-5.2, -30.6),
        Offset(-6.2, -27.0),
        Offset(-5.0, -23.4),
        Offset(-5.8, -20.4),
        Offset(-4.2, -17.6),
      ],
      <double>[0.7, 0.7, 0.68, 0.68, 0.66, 0.62, 0.58],
      fadeIn: 8,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-3.6, -32.0),
        Offset(-2.2, -34.0),
        Offset(-3.4, -30.0),
        Offset(-2.2, -26.2),
        Offset(-3.2, -22.6),
        Offset(-2.0, -19.6),
        Offset(-1.2, -17.6),
      ],
      <double>[0.7, 0.68, 0.68, 0.66, 0.64, 0.6, 0.56],
      fadeIn: 8,
    ),
  ];

  /// How many of [veins] lie behind the artery.
  static const int veinsBehind = 2;

  // Where the parts are named.

  /// The tail, in its middle; the testis, below its middle toward its
  /// front; the vas deferens, where it rises behind the head's end; the
  /// duct, in the body's middle, where it is not the home.
  static const Offset tailName = Offset(-4.6, 23.6);
  static const Offset testisName = Offset(13.5, 10.0);
  static const Offset vasName = Offset(-14.4, 11.8);
  static const Offset ductName = Offset(-10.6, 3.5);
}
