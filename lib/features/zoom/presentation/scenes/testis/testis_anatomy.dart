import 'dart:ui';

import '../tube_course.dart';

/// The right testis seen from its lateral side and cut down its length, as
/// an anatomy plate shows it, drawn from general anatomy: in millimetres on
/// a testis 50 mm from pole to pole, its back to the left, its upper pole
/// up and tilted 15° forward. The origin is the middle of the body's own
/// outline of it, where the zoom goes in, and about the testis's own; x
/// runs forward, y down.
///
/// The cut face shows the lobules between the septa that run from the
/// mediastinum, the thickened back of the tunica albuginea that holds the
/// rete testis, to the tunica all round. The epididymis lies along the
/// back: its head lifted off the upper pole to show the efferent ductules
/// running up into it from the rete, as the plate lifts it; its body down
/// the back; its tail at the lower pole, turning up as the vas deferens,
/// which rises behind it into the spermatic cord with the testicular artery
/// and the pampiniform plexus; the tunica vaginalis round them all.
///
/// Sizes keep to what is measured: the testis 4–5 cm long, 2–3 cm broad and
/// about 3 cm from front to back (Gray's Anatomy, Standring 2020; on
/// ultrasound 3–5 cm by 2–4 by about 3); the tunica albuginea about half a
/// millimetre thick; the mediastinum along the upper back, wider above than
/// below; 250–350 lobules, each of one to four seminiferous tubules about
/// 185 µm across where spermatogenesis is normal; 12 to 20 efferent
/// ductules leaving the rete at the mediastinum's upper end. On ultrasound
/// the epididymis's head is 5–12 mm, its body 2–4 and its tail 2–5; the vas
/// deferens is 1.5–2.7 mm thick, its lumen 0.2–0.7 (Middleton et al. 2009,
/// J Ultrasound Med 28:839); the testicular artery is about 1 mm across in
/// the cord (0.2–1.9 mm in 120 cords, at the external ring) and a vein of
/// the pampiniform plexus under 2 mm, past which it is a varicocele.
abstract final class TestisAnatomy {
  /// How long the testis is, pole to pole.
  static const double length = 50;

  /// The testis's outline, the tunica albuginea's outer face where the cut
  /// crosses it: from the upper pole round by the front, the lower pole and
  /// the back.
  static const List<Offset> testis = <Offset>[
    Offset(6.5, -23.6),
    Offset(9.0, -22.6),
    Offset(11.3, -20.8),
    Offset(13.3, -18.4),
    Offset(14.8, -15.4),
    Offset(15.8, -11.9),
    Offset(16.3, -8.1),
    Offset(16.2, -4.0),
    Offset(15.7, 0.2),
    Offset(14.7, 4.4),
    Offset(13.2, 8.5),
    Offset(11.3, 12.4),
    Offset(9.2, 15.9),
    Offset(6.7, 18.9),
    Offset(4.1, 21.4),
    Offset(1.4, 23.3),
    Offset(-1.3, 24.5),
    Offset(-3.9, 24.9),
    Offset(-6.5, 24.6),
    Offset(-9.7, 23.4),
    Offset(-11.8, 21.8),
    Offset(-13.3, 19.7),
    Offset(-14.3, 17.0),
    Offset(-15.0, 13.8),
    Offset(-15.2, 10.2),
    Offset(-15.1, 6.2),
    Offset(-14.6, 1.9),
    Offset(-13.5, -3.1),
    Offset(-12.2, -8.0),
    Offset(-10.7, -12.1),
    Offset(-9.0, -15.7),
    Offset(-7.0, -18.7),
    Offset(-4.9, -21.1),
    Offset(-2.6, -22.9),
    Offset(-0.1, -24.0),
    Offset(2.7, -24.3),
  ];

  /// How thick the tunica albuginea is.
  static const double tunica = 0.5;

  /// The mediastinum's free edge, where the septa leave it: from its upper
  /// end near the upper pole down the back to its lower end, each end on
  /// the tunica.
  static const List<Offset> mediastinumEdge = <Offset>[
    Offset(-2.5, -22.4),
    Offset(-2.0, -20.7),
    Offset(-3.1, -18.0),
    Offset(-5.1, -14.6),
    Offset(-7.5, -10.4),
    Offset(-9.9, -6.1),
    Offset(-11.9, -1.6),
    Offset(-13.2, 1.6),
    Offset(-14.3, 4.3),
  ];

  /// Its back, outside the tunica's inner face, which bounds it: from its
  /// lower end back up to its upper.
  static const List<Offset> mediastinumBack = <Offset>[
    Offset(-15.9, 4.2),
    Offset(-15.4, 0.6),
    Offset(-14.6, -3.5),
    Offset(-13.4, -8.3),
    Offset(-11.8, -12.8),
    Offset(-9.8, -16.6),
    Offset(-7.6, -19.6),
    Offset(-5.2, -22.0),
    Offset(-3.6, -23.1),
  ];

  /// The rete testis, its channels in the mediastinum's upper part.
  static const List<Offset> rete = <Offset>[
    Offset(-2.6, -20.9),
    Offset(-3.6, -18.1),
    Offset(-5.6, -14.6),
    Offset(-7.7, -10.9),
    Offset(-9.6, -7.7),
    Offset(-11.3, -8.3),
    Offset(-10.1, -11.6),
    Offset(-8.3, -15.2),
    Offset(-6.0, -18.7),
    Offset(-3.9, -21.4),
  ];

  /// How many septa leave the mediastinum's edge, and where on the tunica
  /// their fan of ends begins and ends: from just in front of the
  /// mediastinum's upper end, over the upper pole, down the front and round
  /// the lower pole, to just below its lower end.
  static const int septa = 16;
  static const Offset septaFrom = Offset(0.2, -23.4);
  static const Offset septaTo = Offset(-14.6, 7.0);

  /// The epididymis: its head over the upper pole, lifted off it, from its
  /// front; its body down the back; its tail round the lower pole.
  static const AnatomyTube epididymis = AnatomyTube(
    <Offset>[
      Offset(14.7, -24.9),
      Offset(13.3, -26.1),
      Offset(8.2, -30.0),
      Offset(-1.6, -30.9),
      Offset(-7.4, -28.2),
      Offset(-11.4, -23.3),
      Offset(-13.6, -17.0),
      Offset(-14.3, -10.6),
      Offset(-15.9, -4.8),
      Offset(-17.2, 1.1),
      Offset(-18.0, 7.1),
      Offset(-18.1, 12.2),
      Offset(-16.4, 21.2),
      Offset(-14.0, 24.7),
      Offset(-11.4, 26.6),
      Offset(-9.6, 27.2),
    ],
    <double>[
      0.8,
      1.7,
      3.3,
      3.9,
      3.8,
      3.0,
      2.2,
      1.7,
      1.65,
      1.65,
      1.75,
      2.0,
      2.4,
      2.5,
      1.8,
      1.1,
    ],
  );

  /// How many of the epididymis's points are its head.
  static const int epididymisHead = 6;

  /// The vas deferens, from the tail of the epididymis, hairpinned up behind
  /// it, convoluted at first, then on up out of the view in the cord.
  static const AnatomyTube vas = AnatomyTube(
    <Offset>[
      Offset(-9.6, 27.2),
      Offset(-12.8, 28.6),
      Offset(-15.6, 27.6),
      Offset(-18.6, 24.6),
      Offset(-21.0, 19.8),
      Offset(-22.3, 14.6),
      Offset(-22.9, 9.4),
      Offset(-22.1, 5.9),
      Offset(-23.2, 2.2),
      Offset(-22.0, -1.7),
      Offset(-22.8, -5.6),
      Offset(-21.4, -9.5),
      Offset(-21.6, -13.4),
      Offset(-19.8, -17.4),
      Offset(-18.6, -22.0),
      Offset(-16.9, -27.6),
      Offset(-14.8, -33.8),
      Offset(-13.0, -39.4),
      Offset(-11.3, -45.0),
    ],
    <double>[
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.05,
      0.95,
      1.05,
      0.95,
      1.05,
      0.95,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    fadeOut: 8,
  );

  /// The testicular artery, down the cord, winding as it nears the testis,
  /// to the back of it at the mediastinum's upper part, where it goes in.
  static const AnatomyTube artery = AnatomyTube(
    <Offset>[
      Offset(-5.0, -46.0),
      Offset(-5.6, -42.0),
      Offset(-5.0, -38.6),
      Offset(-6.9, -34.6),
      Offset(-6.0, -30.6),
      Offset(-7.9, -27.4),
      Offset(-8.0, -23.4),
      Offset(-8.0, -20.2),
      Offset(-7.9, -17.9),
    ],
    <double>[0.5, 0.5, 0.5, 0.5, 0.5, 0.48, 0.47, 0.46, 0.45],
    fadeIn: 8,
  );

  /// The veins of the pampiniform plexus, up from the back of the testis
  /// round the artery: the first three behind it, the rest in front.
  static const List<AnatomyTube> veins = <AnatomyTube>[
    AnatomyTube(
      <Offset>[
        Offset(-7.6, -16.8),
        Offset(-9.4, -20.6),
        Offset(-10.0, -24.6),
        Offset(-9.0, -29.6),
        Offset(-9.4, -34.0),
        Offset(-8.3, -39.0),
        Offset(-8.6, -43.0),
        Offset(-7.9, -46.6),
      ],
      <double>[0.62, 0.66, 0.7, 0.72, 0.72, 0.72, 0.72, 0.72],
      fadeOut: 8,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-8.4, -15.6),
        Offset(-9.9, -19.0),
        Offset(-7.1, -23.6),
        Offset(-8.5, -28.4),
        Offset(-6.3, -33.2),
        Offset(-7.6, -38.4),
        Offset(-6.5, -42.6),
        Offset(-6.3, -46.8),
      ],
      <double>[0.6, 0.64, 0.68, 0.7, 0.7, 0.72, 0.72, 0.72],
      fadeOut: 8,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-7.0, -18.4),
        Offset(-6.3, -21.6),
        Offset(-6.8, -25.4),
        Offset(-5.2, -29.6),
        Offset(-5.6, -34.4),
        Offset(-3.7, -38.8),
        Offset(-4.4, -42.8),
        Offset(-3.8, -46.4),
      ],
      <double>[0.58, 0.62, 0.66, 0.68, 0.7, 0.7, 0.7, 0.7],
      fadeOut: 8,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-9.0, -14.6),
        Offset(-10.6, -18.8),
        Offset(-9.2, -23.2),
        Offset(-10.4, -27.8),
        Offset(-8.2, -32.2),
        Offset(-9.4, -36.8),
        Offset(-7.6, -41.6),
        Offset(-8.4, -46.2),
      ],
      <double>[0.6, 0.64, 0.68, 0.7, 0.72, 0.72, 0.72, 0.72],
      fadeOut: 8,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-7.3, -17.4),
        Offset(-7.4, -21.0),
        Offset(-5.4, -24.8),
        Offset(-6.6, -29.0),
        Offset(-4.4, -33.0),
        Offset(-5.6, -37.4),
        Offset(-3.6, -41.8),
        Offset(-4.8, -46.6),
      ],
      <double>[0.56, 0.6, 0.64, 0.68, 0.68, 0.7, 0.7, 0.7],
      fadeOut: 8,
    ),
  ];

  /// How many of [veins] lie behind the artery.
  static const int veinsBehind = 3;

  /// The efferent ductules: how many, where they leave the rete, between
  /// two places at its upper end, and where they reach the head of the
  /// epididymis, between two places along its underside, each a share of
  /// the way along the head from its front: the first from low on the rete
  /// to the head's back, the last from its top toward the head's front.
  static const int ductules = 12;
  static const (Offset, Offset) ductulesFrom = (
    Offset(-5.4, -17.0),
    Offset(-2.9, -21.4),
  );
  static const (double, double) ductulesTo = (0.86, 0.3);

  /// The tunica vaginalis, the sac the testis and the epididymis lie in.
  static const List<Offset> sac = <Offset>[
    Offset(2.0, -37.2),
    Offset(10.0, -35.4),
    Offset(16.2, -30.8),
    Offset(18.6, -24.4),
    Offset(19.2, -16.0),
    Offset(18.8, -7.0),
    Offset(18.0, 2.0),
    Offset(15.8, 10.8),
    Offset(12.0, 18.4),
    Offset(6.6, 24.2),
    Offset(-0.2, 27.6),
    Offset(-7.4, 29.4),
    Offset(-13.2, 29.4),
    Offset(-18.0, 26.4),
    Offset(-20.4, 19.4),
    Offset(-20.8, 10.0),
    Offset(-20.0, 0.0),
    Offset(-18.6, -9.6),
    Offset(-17.0, -18.4),
    Offset(-15.4, -26.4),
    Offset(-11.6, -32.6),
    Offset(-5.2, -36.4),
  ];

  /// Where each part is named.
  static const Offset epididymisName = Offset(-1.6, -30.9);
  static const Offset reteName = Offset(-7.4, -13.8);
  static const Offset vasName = Offset(-22.1, 5.9);
}
