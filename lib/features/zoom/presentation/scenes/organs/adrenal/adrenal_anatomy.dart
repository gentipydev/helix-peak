import 'dart:ui';

import '../../tube_course.dart';

/// The adrenal gland the anatomogram draws for the adrenal, seen from the
/// front on its kidney's upper pole, as the body shows it, cut through the
/// middle of its thickness, its front half taken away, so that its cortex
/// shows round the medulla in its body, the central vein leaving through
/// its hilum. It is drawn from general anatomy, in millimetres, x across
/// toward the body's midline, y down, from the middle of its box: the
/// right gland, the body's right, as drawn, and the left one turned over,
/// each of its own shape.
///
/// Sizes keep to what is measured. The glands lie immediately above and in
/// front of the upper end of each kidney, 3 to 5 cm long, rather less wide
/// and 4 to 6 mm thick; the right one roughly triangular, its base on the
/// medial and anterior aspects of the kidney's upper end, a short furrow, its
/// hilum, a little below its apex near its anterior border, from which the
/// suprarenal vein leaves for the inferior vena cava; the left crescentic,
/// its concavity on the medial border of the kidney's upper part, its hilum
/// near its lower end, its vein leaving for the renal vein; cut, the cortex
/// deep yellow and the medulla dark red or brown, the cortex's zona
/// reticularis, against the medulla, darker than the rest; the arteries
/// numerous, from the aorta, the inferior phrenic and the renal (Gray 1918,
/// pp. 1278–1280). On CT the right gland's body is 0.61 ± 0.2 cm across and
/// its limbs 0.28 cm; the left's body 0.79 ± 0.21 cm and its limbs 0.30 to
/// 0.33 cm (Vincent et al. 1994, Clin Radiol 49:453): the cut here is
/// through the body.
///
/// Drawing choices, measured by none of these: the outlines, the right
/// gland's a cocked hat after the anatomogram's own, 48 mm across and 42
/// tall, the left
/// gland's 21 across and 50 tall; the medulla's extent in the cut; the
/// zona reticularis's edge, a line 0.6 mm out from the medulla; the central
/// vein 2.8 mm across out of the hilum, narrowing in its channel, drawn some 12 mm
/// past it and cut short; the suprarenal arteries 1.1 mm across, fading out
/// toward where they come from; the vena cava not drawn: it lies in front
/// of the right gland's medial part and would hide it, and is 2 cm across,
/// too wide for the view.
abstract final class AdrenalAnatomy {
  /// How tall each gland is drawn, and how wide.
  static const double rightWidth = 47.6;
  static const double leftHeight = 50;

  /// The right gland's outline: from its lateral tip up its lateral border
  /// to its apex, down its medial border to its medial foot, and back along
  /// its concave base, where it rests on the kidney.
  static const List<Offset> rightOutline = <Offset>[
    Offset(-24, 4.4),
    Offset(-21, -0.4),
    Offset(-16.6, -5.6),
    Offset(-11.6, -10.4),
    Offset(-6.2, -14.8),
    Offset(-0.8, -18.6),
    Offset(4, -21),
    Offset(8.4, -21.8),
    Offset(12.6, -20.6),
    Offset(16.4, -17.4),
    Offset(19.6, -12.6),
    Offset(22, -6.6),
    Offset(23.4, 0),
    Offset(23.6, 6.4),
    Offset(22.6, 12.2),
    Offset(20.6, 17),
    Offset(18.4, 20.6),
    Offset(15.8, 19.6),
    Offset(13, 15.8),
    Offset(10.4, 11.2),
    Offset(7, 7),
    Offset(2.4, 3.4),
    Offset(-3, 1.2),
    Offset(-8.6, 0.4),
    Offset(-14, 1),
    Offset(-19.2, 2.4),
    Offset(-22.4, 3.8),
  ];

  /// The right gland's medulla, in its body.
  static const List<Offset> rightMedulla = <Offset>[
    Offset(-12, -6.4),
    Offset(-6, -9.2),
    Offset(0, -9.6),
    Offset(6, -9.2),
    Offset(11.2, -6),
    Offset(15.4, -0.6),
    Offset(18.6, 5.4),
    Offset(19.6, 10.6),
    Offset(17.6, 11.6),
    Offset(14.4, 6.8),
    Offset(11, 1.6),
    Offset(6.8, -2.6),
    Offset(0, -3.6),
    Offset(-6, -3.6),
    Offset(-11.4, -4.8),
  ];

  /// The right gland's central vein: its channel from the medulla to the
  /// hilum, and on out of it toward the vena cava, cut short.
  static const AnatomyTube rightChannel = AnatomyTube(
    <Offset>[Offset(10.8, -5.6), Offset(15.4, -9), Offset(19.8, -12.4)],
    <double>[0.9, 1.1, 1.3],
  );
  static const AnatomyTube rightVein = AnatomyTube(
    <Offset>[
      Offset(19.6, -12.4),
      Offset(24.2, -14.6),
      Offset(28.8, -15.6),
      Offset(33.4, -16),
    ],
    <double>[1.4, 1.4, 1.4, 1.4],
    cutEnd: true,
  );

  /// The right gland's arteries: two superior from above, a middle from
  /// the medial side, an inferior from below, each fading out toward where
  /// it comes from.
  static const List<AnatomyTube> rightArteries = <AnatomyTube>[
    AnatomyTube(
      <Offset>[Offset(-6.4, -31), Offset(-4.4, -24.4), Offset(-2.4, -16.6)],
      <double>[0.55, 0.55, 0.55],
      fadeIn: 7,
    ),
    AnatomyTube(
      <Offset>[Offset(7.6, -33), Offset(9.4, -27.4), Offset(10.6, -22)],
      <double>[0.55, 0.55, 0.55],
      fadeIn: 7,
    ),
    AnatomyTube(
      <Offset>[Offset(37, 1.4), Offset(29.8, -0.6), Offset(23.8, -1.2)],
      <double>[0.55, 0.55, 0.55],
      fadeIn: 7,
    ),
    AnatomyTube(
      <Offset>[Offset(29.2, 30), Offset(23.8, 25.4), Offset(19.6, 20.2)],
      <double>[0.55, 0.55, 0.55],
      fadeIn: 7,
    ),
  ];

  /// Where the body goes into the right gland: in its cortex, above the
  /// medulla, toward its medial border.
  static const Offset rightSite = Offset(9.6, -13);

  /// The left gland's outline, medial to the right as the right gland's
  /// is: from its narrow upper end down its convex medial border, round its
  /// rounded lower end and up its concave lateral border, along the
  /// kidney's medial border.
  static const List<Offset> leftOutline = <Offset>[
    Offset(-6, -25),
    Offset(2, -22),
    Offset(8, -15),
    Offset(12, -6),
    Offset(13.6, 4),
    Offset(12.4, 13),
    Offset(8.6, 20),
    Offset(3, 24.4),
    Offset(-3, 25),
    Offset(-7, 22),
    Offset(-6, 16),
    Offset(-3.4, 8),
    Offset(-2, 0),
    Offset(-2.6, -8),
    Offset(-4.6, -16),
    Offset(-7.4, -21.6),
  ];

  /// The left gland's medulla, in its body and its lower end.
  static const List<Offset> leftMedulla = <Offset>[
    Offset(1.4, -8),
    Offset(5, -6.4),
    Offset(8, 0),
    Offset(9, 8),
    Offset(7.6, 15),
    Offset(4.6, 18),
    Offset(2.2, 15.6),
    Offset(1.6, 8),
    Offset(0.8, 0),
    Offset(0.4, -5),
  ];

  /// The left gland's central vein, from the medulla out of its hilum near
  /// its lower end, down toward the renal vein, cut short.
  static const AnatomyTube leftChannel = AnatomyTube(
    <Offset>[Offset(5.4, 6), Offset(5.2, 14.6), Offset(4.8, 22.4)],
    <double>[0.9, 1.1, 1.3],
  );
  static const AnatomyTube leftVein = AnatomyTube(
    <Offset>[
      Offset(4.8, 22.4),
      Offset(5, 27),
      Offset(5.8, 32),
      Offset(6.8, 36),
    ],
    <double>[1.4, 1.4, 1.4, 1.4],
    cutEnd: true,
  );

  /// The left gland's arteries: a superior from above, a middle from the
  /// medial side, an inferior from below.
  static const List<AnatomyTube> leftArteries = <AnatomyTube>[
    AnatomyTube(
      <Offset>[Offset(-2, -36), Offset(-2.6, -30), Offset(-2.4, -23.4)],
      <double>[0.55, 0.55, 0.55],
      fadeIn: 7,
    ),
    AnatomyTube(
      <Offset>[Offset(28.4, -4), Offset(20.4, -3), Offset(13.2, -1.6)],
      <double>[0.55, 0.55, 0.55],
      fadeIn: 7,
    ),
    AnatomyTube(
      <Offset>[Offset(22, 32), Offset(15.6, 25.8), Offset(10.4, 19.4)],
      <double>[0.55, 0.55, 0.55],
      fadeIn: 7,
    ),
  ];

  /// Where the body goes into the left gland: in its cortex, toward its
  /// upper end.
  static const Offset leftSite = Offset(7, -10.6);

  /// How far out from the medulla the zona reticularis's edge lies.
  static const double reticularis = 0.6;

  /// How far below the kidney's top its pole is drawn whole, and over how
  /// much further it fades out.
  static const double poleShown = 14;
  static const double poleFade = 12;
}
