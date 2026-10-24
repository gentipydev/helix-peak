import 'dart:ui';

import '../../tube_course.dart';

/// The lymph node the zoom draws for lymphoid tissue, cut in two through
/// its hilum, as a section of one is read: in millimetres, its long axis
/// across, its hilum below, from its middle; x across, y down.
///
/// Sizes keep to what is measured. Lymph glands are small oval or
/// bean-shaped bodies with, on one side, a slight depression, the hilus,
/// through which the bloodvessels enter and leave and the efferent vessel
/// emerges, the afferent vessels entering all round the periphery; on
/// section the cortex lighter, the medulla darker, the cortex deficient at
/// the hilus, where the medulla reaches the surface; trabeculae from the
/// capsule run inward a third or a quarter of the way to the centre; a lymph
/// path, the sinus, lies under the capsule and along the trabeculae; the
/// pulp lies in nodules, the follicles, in the cortex, some with germ
/// centres, and in rounded cords in the medulla (Gray 1918, pp. 688–689).
/// The node has three compartments, the cortex, the paracortex and the
/// medulla, B cells homing to the cortex's follicles and T cells to the
/// paracortex (Willard-Mack 2006, Toxicol Pathol 34:409). Nodes under 10 mm
/// across their short axis are normal, and a benign node is oval, its long
/// axis more than twice its short (Möller et al. 2026, Cancers 18:1045):
/// this one is 18 by 8.4 mm.
///
/// Drawing choices, measured by none of these: the outline's curve and
/// its hilum's notch; the subcapsular sinus 0.35 mm deep; the cortex 1.6
/// mm and the paracortex 1 mm, both tapering to nothing by the hilum; the follicles 1.1 to 1.7 mm across, their
/// germinal centres 0.6 of them, set toward the medulla under a mantle cap;
/// the trabeculae and the medullary cords' courses; the afferent
/// lymphatics 0.6 mm across, beaded where their valves are, fading out
/// toward where they come from; the efferent lymphatic, the artery and the
/// vein at the hilum, cut short; the place the body goes in, in the
/// subcapsular sinus at the node's crown.
abstract final class NodeAnatomy {
  /// How long and how wide the node is, and how deep and wide the notch
  /// of its hilum.
  static const double length = 18;
  static const double width = 8.4;
  static const double hilumDepth = 1.5;
  static const double hilumWidth = 0.42;

  /// How deep under the capsule the sinus, the cortex and the paracortex
  /// reach, and how far round from the hilum the cortex is missing, a share
  /// of the way round.
  static const double sinus = 0.35;
  static const double cortex = 1.6;
  static const double paracortex = 2.6;
  static const double bare = 0.09;

  /// Over what share of the cortex's run from either end, by the hilum, its
  /// bands taper to nothing; and the share at either end the follicles
  /// keep off.
  static const double taper = 0.22;
  static const double spread = 0.1;

  /// How many follicles lie in the cortex, how wide the least and the
  /// most, and their germinal centres' share.
  static const int follicles = 13;
  static const double follicleLeast = 0.55;
  static const double follicleMost = 0.85;
  static const double germinal = 0.6;

  /// How many trabeculae run in from the capsule, and how far: a third of
  /// the way to the middle at most, where the node is deepest.
  static const int trabeculae = 14;
  static const double trabecula = 1.4;

  /// How many medullary cords run to the hilum, and how far to either side
  /// of a straight course one wanders, about.
  static const int cords = 7;
  static const double cordSway = 0.32;

  /// Where the body goes in: in the subcapsular sinus, at the crown.
  static const Offset site = Offset(0.8, -3.95);

  /// The afferent lymphatics, coming in to the capsule, each fading out
  /// toward where it comes from; beaded at their valves.
  static const List<AnatomyTube> afferents = <AnatomyTube>[
    AnatomyTube(
      <Offset>[Offset(-6, -11.4), Offset(-5, -7.6), Offset(-4.2, -3.65)],
      <double>[0.3, 0.38, 0.3],
      fadeIn: 3,
    ),
    AnatomyTube(
      <Offset>[Offset(2.4, -12.2), Offset(2.2, -8.2), Offset(1.8, -4.05)],
      <double>[0.3, 0.38, 0.3],
      fadeIn: 3,
    ),
    AnatomyTube(
      <Offset>[Offset(11.4, -9), Offset(8.8, -6), Offset(6.8, -2.7)],
      <double>[0.3, 0.38, 0.3],
      fadeIn: 3,
    ),
    AnatomyTube(
      <Offset>[Offset(-13.6, -5.2), Offset(-11.4, -3), Offset(-8.7, -1)],
      <double>[0.3, 0.38, 0.3],
      fadeIn: 3,
    ),
    AnatomyTube(
      <Offset>[Offset(14, 2), Offset(11.4, 1.1), Offset(8.9, 0.55)],
      <double>[0.3, 0.38, 0.3],
      fadeIn: 3,
    ),
  ];

  /// At the hilum: the efferent lymphatic, the artery and the vein, each
  /// cut short below.
  static const AnatomyTube efferent = AnatomyTube(
    <Offset>[Offset(-0.9, 2.4), Offset(-1.4, 5.4), Offset(-2.2, 8.4)],
    <double>[0.42, 0.42, 0.42],
    cutEnd: true,
  );
  static const AnatomyTube artery = AnatomyTube(
    <Offset>[Offset(0.6, 2.4), Offset(0.7, 5.4), Offset(0.9, 8.6)],
    <double>[0.3, 0.3, 0.3],
    cutEnd: true,
  );
  static const AnatomyTube vein = AnatomyTube(
    <Offset>[Offset(1.8, 2.4), Offset(2.4, 5.2), Offset(3.4, 8.2)],
    <double>[0.48, 0.48, 0.48],
    cutEnd: true,
  );

  // Where the parts are named.

  static const Offset medullaName = Offset(-2.4, 0.6);
  static const Offset paracortexName = Offset(6.9, 0.4);
}
