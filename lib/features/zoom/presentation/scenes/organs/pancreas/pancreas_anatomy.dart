import 'dart:ui';

import '../../tube_course.dart';

/// The pancreas and what lies round it, drawn from general anatomy: in
/// centimetres on a gland 16 cm long, seen from the front with the stomach
/// taken away. x runs to the reader's right, the body's left; y runs down;
/// the origin is about the middle of the gland's box.
///
/// The head lies in the C of the duodenum, its uncinate process hooking
/// toward the midline under the notch the superior mesenteric vessels come
/// down through, behind them. The neck lies over the vessels; the body runs
/// up to the left across the spine, the omental tuberosity on its upper
/// border; the tail ends at the spleen's hilum. The splenic artery winds
/// along the upper border from the coeliac trunk; the bile duct comes down
/// behind the duodenum's first part and the head to the ampulla on the
/// second part's inner wall, where the main duct meets it; the accessory duct
/// opens two centimetres above.
abstract final class PancreasAnatomy {
  /// The gland's outline, from the top of its tail round by its upper
  /// border, the head and its uncinate process, and back along its lower
  /// border: the way round the anatomogram draws it.
  static const List<Offset> outline = <Offset>[
    Offset(7.55, -4.30),
    Offset(6.40, -3.95),
    Offset(5.00, -3.40),
    Offset(3.60, -2.95),
    Offset(2.20, -2.60),
    Offset(1.00, -2.50),
    // The omental tuberosity.
    Offset(0.00, -2.70),
    Offset(-0.90, -2.45),
    Offset(-1.70, -1.70),
    // The neck, under the portal vein.
    Offset(-2.60, -1.25),
    Offset(-3.60, -1.65),
    Offset(-4.80, -2.05),
    Offset(-6.00, -2.05),
    Offset(-7.10, -1.75),
    Offset(-7.75, -1.05),
    // The head, along the duodenum's second part.
    Offset(-8.00, 0.00),
    Offset(-7.95, 1.20),
    Offset(-7.70, 2.40),
    Offset(-7.20, 3.40),
    Offset(-6.40, 4.05),
    Offset(-5.20, 4.35),
    Offset(-3.90, 4.30),
    // The uncinate process, round its tip and back into the notch.
    Offset(-2.80, 4.10),
    Offset(-1.95, 3.70),
    Offset(-1.90, 3.15),
    Offset(-2.55, 2.70),
    Offset(-3.20, 2.30),
    Offset(-3.60, 1.95),
    // The neck's lower border, over the vessels.
    Offset(-3.10, 1.55),
    Offset(-2.30, 1.40),
    Offset(-1.40, 1.30),
    // The body and the tail.
    Offset(0.00, 1.05),
    Offset(1.60, 0.55),
    Offset(3.20, -0.05),
    Offset(4.80, -0.75),
    Offset(6.10, -1.55),
    Offset(7.10, -2.35),
    Offset(7.85, -3.05),
    Offset(8.00, -3.70),
    Offset(7.90, -4.15),
  ];

  /// Whether a point of the gland lies in its uncinate process, behind the
  /// superior mesenteric vessels.
  static bool inUncinate(Offset p) => p.dx > -4.5 && p.dy > 1.9;

  /// The duodenum, from the pylorus, cut where the stomach was taken away,
  /// round the head to the duodenojejunal flexure, and a short way of the
  /// jejunum, cut. Its first [duodenumFront] points, the first part, lie in
  /// front of the head; the rest behind it.
  static const AnatomyTube duodenum = AnatomyTube(
    <Offset>[
      Offset(-3.70, -2.90),
      Offset(-5.30, -3.15),
      Offset(-7.00, -3.30),
      Offset(-8.40, -3.05),
      Offset(-9.10, -2.10),
      Offset(-9.20, -0.20),
      Offset(-9.10, 1.80),
      Offset(-8.85, 3.70),
      Offset(-8.20, 5.05),
      Offset(-6.80, 5.50),
      Offset(-4.50, 5.70),
      Offset(-2.20, 5.65),
      Offset(-0.50, 5.30),
      Offset(0.45, 4.55),
      Offset(0.80, 3.40),
      Offset(0.60, 2.55),
      Offset(1.50, 2.80),
      Offset(2.60, 3.55),
      Offset(3.30, 4.30),
    ],
    <double>[
      1.50,
      1.46,
      1.42,
      1.38,
      1.35,
      1.35,
      1.35,
      1.33,
      1.32,
      1.30,
      1.30,
      1.30,
      1.30,
      1.28,
      1.27,
      1.25,
      1.25,
      1.25,
      1.25,
    ],
    cutStart: true,
    cutEnd: true,
  );

  static const int duodenumFront = 4;

  /// Where the duodenum is named: on its third part, as it leaves the
  /// corner of its C, so the name's line is short.
  static const Offset duodenumName = Offset(-7.50, 5.35);

  /// Where the spleen is named: in its middle, toward its hilum, where the
  /// narrowest view still shows it.
  static const Offset spleenName = Offset(10.50, -6.40);

  /// Where the bile duct and the main duct open into the duodenum, and the
  /// accessory duct above it.
  static const Offset majorPapilla = Offset(-7.85, 1.00);
  static const Offset minorPapilla = Offset(-7.85, -0.90);

  /// The spleen, behind and beyond the tail, its notched upper border to
  /// the reader's left and its hilum facing the tail.
  static const List<Offset> spleen = <Offset>[
    Offset(12.0, -11.0),
    Offset(13.0, -9.6),
    Offset(13.5, -7.6),
    Offset(13.3, -5.4),
    Offset(12.6, -3.4),
    Offset(11.4, -1.9),
    Offset(9.9, -1.0),
    Offset(8.8, -1.3),
    Offset(8.4, -2.4),
    Offset(8.35, -3.6),
    Offset(8.6, -4.6),
    Offset(8.5, -6.2),
    Offset(8.4, -7.4),
    Offset(9.0, -7.9),
    Offset(8.7, -8.6),
    Offset(9.5, -9.6),
    Offset(10.0, -10.5),
    Offset(11.0, -11.1),
  ];

  /// The coeliac trunk, rising from behind the gland's upper border.
  static const AnatomyTube coeliacTrunk = AnatomyTube(
    <Offset>[Offset(-1.30, -1.90), Offset(-1.30, -3.05)],
    <double>[0.35, 0.35],
  );

  /// The splenic artery, winding in and out along the upper border to the
  /// hilum, and its branches into the spleen.
  static const AnatomyTube splenicArtery = AnatomyTube(
    <Offset>[
      Offset(-1.30, -3.05),
      Offset(-0.35, -3.50),
      Offset(0.70, -2.70),
      Offset(1.70, -3.30),
      Offset(2.40, -3.55),
      Offset(3.30, -2.95),
      Offset(4.40, -3.70),
      Offset(5.10, -3.40),
      Offset(5.90, -3.95),
      Offset(6.80, -4.50),
      Offset(7.60, -4.40),
      Offset(8.40, -4.95),
    ],
    <double>[
      0.30,
      0.30,
      0.29,
      0.29,
      0.29,
      0.29,
      0.28,
      0.28,
      0.28,
      0.27,
      0.27,
      0.26,
    ],
  );

  static const List<AnatomyTube> hilarBranches = <AnatomyTube>[
    AnatomyTube(
      <Offset>[Offset(8.40, -4.95), Offset(8.9, -5.9), Offset(9.3, -6.6)],
      <double>[0.17, 0.16, 0.14],
    ),
    AnatomyTube(
      <Offset>[Offset(8.40, -4.95), Offset(9.0, -5.3), Offset(9.5, -5.6)],
      <double>[0.17, 0.16, 0.14],
    ),
    AnatomyTube(
      <Offset>[Offset(8.40, -4.95), Offset(9.0, -4.8), Offset(9.6, -4.7)],
      <double>[0.17, 0.16, 0.14],
    ),
    AnatomyTube(
      <Offset>[Offset(8.40, -4.95), Offset(8.9, -4.3), Offset(9.3, -3.8)],
      <double>[0.17, 0.16, 0.14],
    ),
  ];

  /// The common hepatic artery along the head's upper border, and the
  /// proper hepatic artery up to the liver, behind the duodenum's first
  /// part.
  static const AnatomyTube hepaticArtery = AnatomyTube(
    <Offset>[
      Offset(-1.30, -3.05),
      Offset(-2.60, -2.70),
      Offset(-3.90, -2.55),
      Offset(-5.00, -2.90),
      Offset(-5.60, -4.80),
      Offset(-5.85, -7.20),
      Offset(-5.95, -9.00),
    ],
    <double>[0.27, 0.26, 0.25, 0.25, 0.23, 0.22, 0.22],
    fadeOut: 2.5,
  );

  /// The superior mesenteric vein and artery, down from under the neck,
  /// through the notch, over the uncinate process and the duodenum's third
  /// part.
  static const AnatomyTube mesentericVein = AnatomyTube(
    <Offset>[
      Offset(-2.90, 0.20),
      Offset(-2.95, 1.90),
      Offset(-2.90, 3.30),
      Offset(-2.80, 5.00),
      Offset(-2.70, 7.20),
      Offset(-2.50, 9.50),
    ],
    <double>[0.55, 0.55, 0.55, 0.53, 0.50, 0.48],
    fadeOut: 2.5,
  );

  static const AnatomyTube mesentericArtery = AnatomyTube(
    <Offset>[
      Offset(-1.70, 0.60),
      Offset(-1.75, 2.40),
      Offset(-1.70, 4.60),
      Offset(-1.60, 7.20),
      Offset(-1.35, 9.50),
    ],
    <double>[0.36, 0.35, 0.34, 0.32, 0.30],
    fadeOut: 2.5,
  );

  /// The bile duct, down from the liver, behind the duodenum's first part
  /// and the head, to the ampulla.
  static const AnatomyTube bileDuct = AnatomyTube(
    <Offset>[
      Offset(-7.05, -9.00),
      Offset(-7.00, -7.20),
      Offset(-7.20, -5.00),
      Offset(-7.60, -1.60),
      Offset(-7.85, -0.20),
      Offset(-7.90, 0.60),
      majorPapilla,
    ],
    <double>[0.32, 0.32, 0.32, 0.31, 0.29, 0.26, 0.24],
    fadeIn: 2.5,
  );

  /// The main pancreatic duct, from the tail to the ampulla, widening as it
  /// goes, and the accessory duct from the neck to the minor papilla.
  static const AnatomyTube mainDuct = AnatomyTube(
    <Offset>[
      Offset(6.90, -3.25),
      Offset(5.60, -2.55),
      Offset(4.00, -1.75),
      Offset(2.40, -1.15),
      Offset(0.90, -0.70),
      Offset(-0.60, -0.45),
      Offset(-1.90, -0.30),
      Offset(-2.90, -0.05),
      Offset(-3.60, 0.35),
      Offset(-4.30, 0.85),
      Offset(-4.95, 1.20),
      Offset(-5.80, 1.35),
      Offset(-6.70, 1.30),
      Offset(-7.40, 1.15),
      majorPapilla,
    ],
    <double>[
      0.08,
      0.09,
      0.10,
      0.11,
      0.12,
      0.125,
      0.13,
      0.14,
      0.15,
      0.16,
      0.16,
      0.165,
      0.17,
      0.17,
      0.17,
    ],
  );

  static const AnatomyTube accessoryDuct = AnatomyTube(
    <Offset>[
      Offset(-3.60, 0.35),
      Offset(-4.70, -0.15),
      Offset(-6.00, -0.55),
      Offset(-7.20, -0.80),
      minorPapilla,
    ],
    <double>[0.06, 0.06, 0.06, 0.055, 0.05],
  );
}
