import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The femur the anatomogram draws for the bone marrow, the figure's left,
/// cut down its length in the frontal plane through its head, neck and
/// shaft and seen from the front, as the frontal sections Gray 1918 takes
/// from Koch show it, drawn from general anatomy: in millimetres in the
/// bone's own frame, x across it, lateral to the right, y down the axis of
/// its shaft, which is x = 0. The form stands it as each figure stands its
/// femur, leaning in toward the knee (`MarrowForm`).
///
/// The cut shows the cortex, thickest round the middle of the shaft and
/// thinning to a shell at either end; the cartilage on the head and the
/// condyles; the scars of the growth plates across the head, the greater
/// trochanter and the lower end; the trabeculae of the spongy bone in the
/// ends, in the groups Koch traced in the upper femur and the longitudinal
/// and transverse systems of the lower (Koch 1917, Am J Anat 21:177, as
/// Gray 1918 quotes him; the groups as Singh, Nagrath and Maini 1970, J
/// Bone Joint Surg Am 52:457, name them); the marrow cavity down the shaft;
/// and the nutrient artery, which enters the shaft through a canal directed
/// obliquely upward (Gray 1918) and branches up and down the cavity.
///
/// Sizes keep to what is measured, in men, whose femurs are 449.7 ± 16.7
/// mm long, the zoom's 45 cm (Kanz et al. 2015, Anthropol Anz 72:117). The
/// head is 47.0 ± 2.3 mm across, the shaft 27.9 ± 2.5 at its middle and the
/// condyles 79.6 ± 4.6 (Kanz et al. 2015); the head is rather more than a
/// hemisphere, its fovea a little below and behind its centre, and the
/// greater trochanter about 1 cm lower than it (Gray 1918). On CT the neck
/// meets the shaft at 127.2 ± 5.2°, the head's centre lies 37.5 ± 4.6 mm
/// from the shaft's axis, and the cavity is 11.9 ± 1.7 mm across at its
/// isthmus (Kulkarni et al. 2020, J Orthop 20:63), 10.71 ± 2.2 in 1,189
/// femurs (Thiesen et al. 2022, Eur J Trauma Emerg Surg 48:2379), so the
/// cortex there is what the shaft's breadth leaves round it, about 8 mm. The
/// head's cartilage is 2.8 mm thick round the fovea and 1.1 to 1.3 toward
/// its rims (Nakanishi et al. 2001, Eur Radiol 11:2178), the condyles' 2.3
/// ± 0.5 in knees without arthritis (Sandhar et al. 2026, J Exp Orthop
/// 13:e70641). The nutrient foramina lie 29 to 69% of the femur's length
/// from its upper end (Kizilkanat et al. 2007, Ann Anat 189:87).
///
/// The marrow is a young adult's. Every femur has fatty marrow in its head
/// and its greater trochanter, and 95% of femurs under fifty keep red marrow
/// between the trochanters, 12.5% over fifty (Mitchell et al. 1986,
/// Radiology 161:199). The red marrow turns to yellow first down the shaft,
/// by ten, then at the lower end, by twenty, with the adult pattern by 24
/// (Moore and Dawson 1990, Radiology 175:219); what is left lies along the
/// weight-bearing axis, the top of the shaft's red marrow running on from
/// the upper end's (Niu et al. 2007, J Huazhong Univ Sci Technolog Med Sci
/// 27:617).
///
/// Drawing choices, measured by none of these: the neck's width at its
/// waist, the lesser trochanter's size, the courses of the scars, the
/// cortex's thickness toward the ends, and the nutrient canal, drawn in
/// the cut though it pierces the linea aspera behind it.
abstract final class MarrowAnatomy {
  /// How long the femur is, from the top of its head to the bottom of its
  /// condyles, as it stands.
  static const double length = 450;

  // The head and the neck.

  /// The head's radius, and its centre, where a neck meeting the shaft at
  /// [neckShaft] degrees, its axis crossing the shaft's at [neckFoot], puts
  /// a head [offset] from the shaft's axis.
  static const double headRadius = 23.5;
  static const Offset head = Offset(-39.0, -199.39);
  static const double neckShaft = 127;
  static const double offset = 39;
  static const Offset neckFoot = Offset(0, -170);

  /// Half the neck's width at its waist.
  static const double neckWaist = 16;

  /// Where the fovea lies round the head, in degrees from its centre
  /// (clockwise on screen from lateral, so 180 is medial), and how far it
  /// reaches to either side of that: bare of cartilage, the ligament of the
  /// head holding there.
  static const double fovea = 168;
  static const double foveaReach = 10;

  // The outline, below the head and the neck: each run of it in turn, round
  // the bone from the neck's upper edge.

  /// The greater trochanter: its tip over the trochanteric fossa, its
  /// crest, its broad lateral face and the vastus ridge below it.
  static const List<Offset> trochanter = <Offset>[
    Offset(1.0, -203.0),
    Offset(5.5, -212.0),
    Offset(10.0, -216.0),
    Offset(15.0, -215.0),
    Offset(21.0, -210.0),
    Offset(26.0, -200.0),
    Offset(28.5, -186.0),
    Offset(28.8, -170.0),
    Offset(27.0, -156.0),
    Offset(22.5, -146.0),
  ];

  /// The shaft's lateral side, down to the lateral epicondyle.
  static const List<Offset> lateralShaft = <Offset>[
    Offset(17.2, -134.0),
    Offset(15.2, -112.0),
    Offset(14.4, -70.0),
    Offset(14.0, -20.0),
    Offset(14.2, 30.0),
    Offset(15.0, 80.0),
    Offset(17.0, 120.0),
    Offset(22.0, 150.0),
    Offset(31.0, 172.0),
    Offset(39.5, 189.0),
  ];

  /// The lateral condyle, the arch of the notch between the two, and the
  /// medial condyle, which hangs the lower in the bone's own frame and as
  /// low as the lateral as the femur stands (Gray 1918).
  static const List<Offset> condyles = <Offset>[
    Offset(44.0, 203.0),
    Offset(42.8, 212.5),
    Offset(37.5, 218.5),
    Offset(29.5, 220.5),
    Offset(21.5, 219.0),
    Offset(17.0, 215.0),
    Offset(13.5, 209.0),
    Offset(8.0, 205.5),
    Offset(2.5, 209.0),
    Offset(-1.0, 215.0),
    Offset(-5.5, 221.0),
    Offset(-14.0, 226.0),
    Offset(-24.0, 227.0),
    Offset(-31.5, 222.0),
    Offset(-35.5, 210.0),
  ];

  /// The medial epicondyle, the adductor tubercle and the shaft's medial
  /// side, up to the lesser trochanter.
  static const List<Offset> medialShaft = <Offset>[
    Offset(-35.0, 196.0),
    Offset(-32.0, 180.0),
    Offset(-26.0, 158.0),
    Offset(-19.0, 128.0),
    Offset(-16.0, 90.0),
    Offset(-14.6, 40.0),
    Offset(-13.9, -10.0),
    Offset(-14.0, -60.0),
    Offset(-14.6, -100.0),
    Offset(-15.8, -124.0),
  ];

  /// The lesser trochanter, and the neck's lower edge rising from it.
  static const List<Offset> lesserTrochanter = <Offset>[
    Offset(-18.0, -134.0),
    Offset(-21.8, -142.0),
    Offset(-23.6, -149.0),
    Offset(-22.6, -156.0),
    Offset(-24.6, -163.0),
  ];

  // Where the articular surfaces are: the condyles' cartilage runs from
  // the outline's point nearest [condyleCartilage].$1 to the one nearest
  // .$2 on each condyle, the notch between them bare.

  static const (Offset, Offset) lateralCartilage = (
    Offset(44.0, 205.0),
    Offset(17.5, 216.0),
  );
  static const (Offset, Offset) medialCartilage = (
    Offset(-1.5, 216.0),
    Offset(-35.5, 210.0),
  );

  /// How thick the cartilage is: on the head round the fovea and toward its
  /// rims, and on the condyles; how far from its margins it thins to them.
  static const double headCartilage = 2.8;
  static const double rimCartilage = 1.2;
  static const double condyleCartilage = 2.3;
  static const double cartilageMargin = 6;

  /// The cortex's thickness down either side of the shaft, at each height:
  /// thickest round the isthmus, thinning to a shell at either end. The
  /// head's and the condyles' shells, under their cartilage, the neck's
  /// upper edge and the greater trochanter's shell, and the notch's roof,
  /// which is thickened where the crucial ligaments hold (Gray 1918).
  static const List<(double, double)> medialCortex = <(double, double)>[
    (-180, 1.4),
    (-168, 3.2),
    (-156, 4.4),
    (-140, 5.0),
    (-120, 6.0),
    (-80, 7.4),
    (-40, 8.2),
    (0, 7.8),
    (60, 6.5),
    (100, 4.8),
    (130, 3.0),
    (150, 2.0),
    (175, 1.3),
    (200, 1.0),
  ];
  static const List<(double, double)> lateralCortex = <(double, double)>[
    (-205, 0.9),
    (-180, 1.0),
    (-160, 1.6),
    (-146, 2.4),
    (-130, 3.6),
    (-110, 5.0),
    (-80, 6.8),
    (-40, 8.0),
    (0, 7.6),
    (60, 6.3),
    (100, 4.6),
    (130, 2.9),
    (150, 1.9),
    (175, 1.2),
    (200, 1.0),
  ];
  static const double subchondral = 1.0;
  static const double neckCortex = 1.5;
  static const double notchRoof = 2.5;

  // The growth plates' scars.

  /// Across the head, between its two junctions with the neck, bowed in
  /// toward its centre, the head a cap on the neck; across the greater trochanter's base; and across
  /// the lower end, its middle risen.
  static const List<Offset> headScar = <Offset>[
    Offset(-16.8, -202.7),
    Offset(-26.1, -196.3),
    Offset(-32.5, -187.8),
    Offset(-36.1, -177.2),
  ];
  static const List<Offset> trochanterScar = <Offset>[
    Offset(2.5, -203.5),
    Offset(11.0, -198.0),
    Offset(19.5, -191.5),
    Offset(27.6, -183.0),
  ];
  static const List<Offset> lowerScar = <Offset>[
    Offset(-32.8, 189.0),
    Offset(-22.0, 186.0),
    Offset(-10.0, 187.5),
    Offset(2.0, 183.0),
    Offset(14.0, 187.0),
    Offset(26.0, 185.0),
    Offset(38.4, 188.5),
  ];

  // The marrow.

  /// The red marrow's lower edge, running in and out across the top of the
  /// shaft's cavity, reaching lowest down the weight-bearing medial side:
  /// the region above it, below the head's scar and the greater
  /// trochanter's, is red.
  static const List<Offset> redEdge = <Offset>[
    Offset(-26.0, -104.0),
    Offset(-18.0, -110.0),
    Offset(-11.0, -103.5),
    Offset(-4.0, -112.0),
    Offset(3.0, -107.0),
    Offset(9.5, -116.0),
    Offset(16.0, -111.5),
    Offset(22.0, -120.0),
    Offset(28.0, -117.0),
  ];

  /// Where the cavity runs between the two ends' spongy bone.
  static const double cavityTop = -122;
  static const double cavityBottom = 112;

  // The trabeculae of the upper femur, in Koch's groups (Gray 1918).

  /// The principal compressive group: from the medial wall of the neck,
  /// just above the secondary group, up in slightly radiating lines to the upper part of the head's
  /// articular surface, meeting it square; the thickest and closest.
  static const Trabeculae principalCompressive = Trabeculae(
    from: Offset(-21.5, -171.0),
    to: Offset(-20.5, -157.0),
    endFrom: Offset(-55.0, -213.5),
    endTo: Offset(-22.0, -214.0),
    leaveFrom: Offset(0.15, -1),
    leaveTo: Offset(0.3, -1),
    apart: 0.75,
    thick: 0.35,
    toHead: true,
  );

  /// The secondary compressive group: from the medial wall from the lesser
  /// trochanter up along the curving shaft, leaving it at about 45°, the upper lines
  /// rising nearly straight to the neck's upper part, the lower curving out
  /// to the greater trochanter; thin, and wide apart.
  static const Trabeculae secondaryCompressive = Trabeculae(
    from: Offset(-20.0, -155.0),
    to: Offset(-15.5, -128.0),
    endFrom: Offset(-9.0, -199.0),
    endTo: Offset(24.0, -168.0),
    leaveFrom: Offset(0.45, -1),
    leaveTo: Offset(1, -1),
    arriveFrom: Offset(0.25, -1),
    arriveTo: Offset(1, -0.45),
    apart: 1.4,
    thick: 0.2,
  );

  /// The greater trochanter group: from the lateral wall just below the
  /// trochanter, in thin curving lines up across it to its upper surface;
  /// slender, some of them poorly defined.
  static const Trabeculae trochanterGroup = Trabeculae(
    from: Offset(22.0, -146.0),
    to: Offset(25.5, -164.0),
    endFrom: Offset(7.0, -211.0),
    endTo: Offset(24.5, -201.0),
    leaveFrom: Offset(-0.25, -1),
    leaveTo: Offset(-0.1, -1),
    arriveFrom: Offset(-0.2, -1),
    arriveTo: Offset(0.35, -1),
    apart: 1.5,
    thick: 0.15,
  );

  /// The principal tensile group: from the lateral wall just below that,
  /// arching up over the neck in nearly parallel lines to end in the lower
  /// part of the head, crossing the compressive groups square; thinner and
  /// wider apart than the principal compressive.
  static const Trabeculae principalTensile = Trabeculae(
    from: Offset(19.0, -142.0),
    to: Offset(15.5, -126.0),
    endFrom: Offset(-58.5, -196.5),
    endTo: Offset(-44.0, -178.5),
    leaveFrom: Offset(-0.12, -1),
    leaveTo: Offset(-0.2, -1),
    apart: 1.0,
    thick: 0.25,
    toHead: true,
  );

  /// The secondary tensile group: from the lateral wall below those, up
  /// and medially across the axis, ending after it, some in the medial wall
  /// of the shaft and the neck.
  static const Trabeculae secondaryTensile = Trabeculae(
    from: Offset(15.2, -126.0),
    to: Offset(14.0, -112.0),
    endFrom: Offset(-20.5, -164.0),
    endTo: Offset(-12.0, -126.0),
    leaveFrom: Offset(-0.35, -1),
    leaveTo: Offset(-0.55, -1),
    arriveFrom: Offset(-0.75, -1),
    arriveTo: Offset(-1, -0.8),
    apart: 1.5,
    thick: 0.2,
  );

  /// The upper femur's groups, in the order they are laid.
  static const List<Trabeculae> upper = <Trabeculae>[
    secondaryCompressive,
    trochanterGroup,
    secondaryTensile,
    principalTensile,
    principalCompressive,
  ];

  // The trabeculae of the lower femur (Gray 1918): longitudinal ones rising
  // from the shaft's inner wall as it flares, straight down and parallel to
  // the axis to the scar, then curving to meet the joint square, braced by
  // lighter transverse ones at right angles to them (`MarrowForm` lays
  // these as struts between neighbours, as it braces every group).

  /// How far apart the longitudinal lines are at the finest, how thick, and
  /// how high up the shaft the first of them leave its wall.
  static const double longitudinalApart = 0.9;
  static const double longitudinalThick = 0.3;
  static const double longitudinalTop = 80;

  // The nutrient artery.

  /// Where its canal opens on the shaft's medial face, 41% of the femur's
  /// length from its top, just inside it, and where it opens into the
  /// cavity, higher.
  static const Offset foramen = Offset(-13.6, -38.0);
  static const Offset canalInner = Offset(-5.6, -52.0);

  /// Its branches in the cavity: the ascending, up toward the red marrow,
  /// and the descending, down toward the lower end; each with its twigs, a
  /// start on it and an end.
  static const List<Offset> ascending = <Offset>[
    Offset(-5.6, -52.0),
    Offset(-3.0, -66.0),
    Offset(-2.2, -84.0),
    Offset(-3.4, -100.0),
    Offset(-2.0, -114.0),
    Offset(-0.5, -124.0),
  ];
  static const List<Offset> descending = <Offset>[
    Offset(-5.6, -52.0),
    Offset(-4.0, -36.0),
    Offset(-2.6, -10.0),
    Offset(-3.6, 20.0),
    Offset(-2.4, 52.0),
    Offset(-3.2, 84.0),
    Offset(-2.0, 112.0),
    Offset(-1.0, 132.0),
  ];
  static const List<(Offset, Offset)> twigs = <(Offset, Offset)>[
    (Offset(-2.6, -78.0), Offset(3.5, -90.0)),
    (Offset(-3.1, -97.0), Offset(-8.0, -106.0)),
    (Offset(-3.0, -2.0), Offset(3.4, 10.0)),
    (Offset(-3.3, 34.0), Offset(-8.5, 46.0)),
    (Offset(-2.8, 70.0), Offset(3.5, 84.0)),
  ];

  /// Over how far its branches' ends fade.
  static const double ascendingFade = 12;
  static const double descendingFade = 20;

  // Where each part is named.

  static const Offset trabecularName = Offset(-37.0, -205.0);
  static const Offset corticalName = Offset(-11.4, 50.0);
  static const Offset yellowName = Offset(4.0, 60.0);
}

/// A group of the femur's trabeculae, as Koch traced them in its frontal
/// section (Gray 1918): its lines arise along the bone's inner wall from
/// [from] to [to], leaving it along [leaveFrom] to [leaveTo], and end from
/// [endFrom] to [endTo], arriving along [arriveFrom] to [arriveTo] or, for
/// a group that ends in the head ([toHead]), square to its articular
/// surface; at their finest [apart] millimetres apart, [thick] thick.
@immutable
final class Trabeculae {
  const Trabeculae({
    required this.from,
    required this.to,
    required this.endFrom,
    required this.endTo,
    required this.leaveFrom,
    required this.leaveTo,
    this.arriveFrom = const Offset(0, -1),
    this.arriveTo = const Offset(0, -1),
    required this.apart,
    required this.thick,
    this.toHead = false,
  });

  final Offset from;
  final Offset to;
  final Offset endFrom;
  final Offset endTo;
  final Offset leaveFrom;
  final Offset leaveTo;
  final Offset arriveFrom;
  final Offset arriveTo;
  final double apart;
  final double thick;
  final bool toHead;
}
