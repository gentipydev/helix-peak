import 'dart:ui';

import '../../tube_course.dart';

/// The thyroid gland the anatomogram draws for the thyroid, seen from the
/// front in place, as the body shows it: its right lobe on the left, over
/// the larynx and the trachea, the carotid arteries and the jugular veins
/// at its sides. The lobe the body goes into, its right one, is cut open
/// from front to back, its front half taken away, to show its parenchyma
/// parted into lobules by the septa its capsule sends in. It is drawn from
/// general anatomy, in millimetres, x across to the body's left, y down,
/// from the notch of the thyroid cartilage.
///
/// Sizes keep to what is measured. Each lobe is about 5 cm long, its apex
/// as high as the junction of the middle and lower thirds of the thyroid
/// cartilage and its base level with the fifth or sixth tracheal ring; the
/// isthmus joins the lobes' lower thirds, about 1.25 cm across and deep,
/// over the second and third rings, the superior thyroid arteries' branches
/// meeting along its upper border and the inferior thyroid veins leaving
/// its lower; the lobes' posterior borders overlap the common carotid
/// arteries, which divide opposite the upper border of the thyroid
/// cartilage, the internal jugular veins lateral to them; the middle
/// thyroid vein crosses the artery a little below the cricoid to end in the
/// jugular; the superior thyroid artery leaves the external carotid and
/// arches down to the gland; cut, the gland is brownish red, of closed
/// vesicles parted by connective tissue its capsule sends in, in masses of
/// irregular form and size (Gray 1918, pp. 550–551 and 1269–1271). The
/// trachea is about 11 cm long, its cartilages sixteen to twenty, each about
/// 4 mm deep, with narrow intervals between (Gray 1918, pp. 1084–1086). In
/// 132 women the gland held 17.5 ± 4.2 ml on ultrasound (Hegedüs et al.
/// 1983, J Clin Endocrinol Metab 56:260): two lobes 50 mm long, 20 across
/// and 17 deep hold 17.8 ml as ellipsoids, where Gray's 3 by 2 cm would
/// hold 31, so the lobes here are 20 mm across. In women the common
/// carotid artery is 6.10 ± 0.80 mm across and the internal 4.66 ± 0.78 mm
/// on ultrasound (Krejza et al. 2006, Stroke 37:1103); the trachea's lumen
/// 14.8 ± 2.0 mm across in its upper part on CT (Zahedi-Nejad et al. 2011,
/// Pol J Radiol 76:28). The thyroid cartilage's laminae are 27 ± 1.4 mm
/// tall in cadavers (Vadgaonkar et al. 2024, F1000Res 13:115). A pyramidal
/// lobe rises from the isthmus in 42.8% of people (Ostrowski et al. 2023,
/// Clin Anat 36:937), so in less than half: none is drawn.
///
/// Drawing choices, measured by none of these: the outlines' curves; the
/// laminae seen from the front, turned 30 degrees from it, so 23 mm out to
/// either side; the notch 7.6 mm deep and the cartilage 19.6 mm tall at the
/// midline; the cricothyroid membrane 10.6 mm tall; the cricoid's arch 7 mm;
/// the trachea 18.4 mm across outside, its lumen and two walls of 1.8 mm,
/// a ring every 6 mm; the external carotid 4 mm across, the internal
/// jugular vein 8, the superior thyroid artery 2, the middle thyroid vein
/// 2.4 and the inferior thyroid veins 2.2; the vessels' courses; the
/// lobules about 3.5 mm across; the place the body goes in, low in the
/// right lobe's middle, where the slide after it is cut.
abstract final class ThyroidAnatomy {
  /// How wide the gland is, across its two lobes.
  static const double width = 56;

  /// The body's right lobe's outline, the one cut open: from where it
  /// leaves the isthmus's lower border, round its base, up its lateral
  /// border, over its apex and down its medial border to the isthmus's
  /// upper border.
  static const List<Offset> cutRun = <Offset>[
    Offset(-5.6, 58.6),
    Offset(-6.4, 63.2),
    Offset(-8.6, 66.6),
    Offset(-12.6, 67.6),
    Offset(-18.6, 66),
    Offset(-23.6, 62.4),
    Offset(-26.8, 57),
    Offset(-28, 50),
    Offset(-27.8, 42),
    Offset(-26.4, 33),
    Offset(-23.5, 24.5),
    Offset(-19.5, 17.5),
    Offset(-16, 14),
    Offset(-13.6, 15.6),
    Offset(-11.8, 20),
    Offset(-10.2, 26),
    Offset(-8.6, 32),
    Offset(-7.4, 37.4),
    Offset(-5.4, 41.4),
  ];

  /// The isthmus's upper border, under the superior thyroid arteries'
  /// meeting, and its lower, where the inferior thyroid veins leave it:
  /// each from the body's right to its left.
  static const List<Offset> isthmusTop = <Offset>[
    Offset(-2.8, 42.6),
    Offset(0, 42.5),
    Offset(2.8, 42.6),
  ];
  static const List<Offset> isthmusFoot = <Offset>[
    Offset(-3.6, 55.8),
    Offset(0, 55),
    Offset(3.6, 55.8),
  ];

  /// The whole gland's outline: the right lobe, the isthmus's upper border,
  /// the left lobe, the right one turned over, and the isthmus's lower
  /// border back.
  static final List<Offset> outline = <Offset>[
    ...cutRun,
    ...isthmusTop,
    for (final Offset p in cutRun.reversed) Offset(-p.dx, p.dy),
    ...isthmusFoot.reversed,
  ];

  /// Where the cut lobe's face ends at the isthmus, which the cut leaves
  /// whole: from the notch's foot down to the isthmus's lower border.
  static const List<Offset> lobeEnd = <Offset>[
    Offset(-5.4, 41.4),
    Offset(-6.2, 45),
    Offset(-6.6, 50),
    Offset(-6.4, 54.6),
    Offset(-5.6, 58.6),
  ];

  /// Where the body goes in: low in the cut lobe's middle.
  static const Offset site = Offset(-17, 50);

  /// How long each lobe is, apex to base, and where along it, from its
  /// apex, the C cells gather, between these shares of it.
  static const double lobeLength = 53.6;
  static const double cFrom = 0.25;
  static const double cTo = 0.65;

  /// About how far apart the lobules' middles lie, and how far one may
  /// stray from its place on a lattice.
  static const double lobule = 3.5;
  static const double lobuleStray = 0.38;

  // The larynx and the trachea.

  /// The thyroid cartilage's body's right half, seen from the front: from
  /// the notch out along its upper border, up its superior horn and down
  /// the lamina's posterior border to its inferior horn, and back along its
  /// lower border to the midline.
  static const List<Offset> cartilageHalf = <Offset>[
    Offset(0, 0),
    Offset(-2.4, -4.2),
    Offset(-5.4, -7.6),
    Offset(-9, -7.2),
    Offset(-13, -6),
    Offset(-17, -4.6),
    Offset(-19.2, -6.4),
    Offset(-20.4, -10.4),
    Offset(-21.4, -13.4),
    Offset(-22.4, -12.6),
    Offset(-22.2, -7.4),
    Offset(-22.4, 0),
    Offset(-22.2, 9),
    Offset(-21.4, 18),
    Offset(-21.2, 23.6),
    Offset(-20.4, 27.4),
    Offset(-19.2, 26.6),
    Offset(-18.4, 23.4),
    Offset(-15.4, 22.4),
    Offset(-10.6, 21.2),
    Offset(-5.4, 20.2),
    Offset(0, 19.6),
  ];

  /// The cricothyroid membrane between the thyroid cartilage and the
  /// cricoid's arch, and the cricothyroid muscle of the body's right
  /// either side of it.
  static const List<Offset> membrane = <Offset>[
    Offset(-6.4, 19.8),
    Offset(6.4, 19.8),
    Offset(8.6, 30.4),
    Offset(-8.6, 30.4),
  ];
  static const List<Offset> cricothyroid = <Offset>[
    Offset(-6.4, 30.2),
    Offset(-7.4, 20.5),
    Offset(-11.4, 21.2),
    Offset(-15.4, 22.8),
    Offset(-17.8, 24.6),
    Offset(-13.8, 27.6),
    Offset(-9.6, 29.6),
  ];

  /// The cricoid's arch, its body's right half: from the midline at its
  /// upper border out and round to the midline at its lower.
  static const List<Offset> cricoidHalf = <Offset>[
    Offset(0, 29.8),
    Offset(-5, 30),
    Offset(-9.2, 29.2),
    Offset(-12.2, 27.6),
    Offset(-13.6, 29.6),
    Offset(-13, 33.4),
    Offset(-10, 35.8),
    Offset(-5, 36.8),
    Offset(0, 37),
  ];

  /// The trachea: its middle line from under the cricoid down, cut short
  /// below the gland, how wide it is, and its rings, the first's top, each
  /// how deep and the next how far below.
  static const AnatomyTube trachea = AnatomyTube(
    <Offset>[Offset(0, 36), Offset(0, 56), Offset(0, 75)],
    <double>[9.2, 9.2, 9.2],
    cutEnd: true,
  );
  static const double ringTop = 38;
  static const double ringDepth = 4;
  static const double ringPitch = 6;
  static const int rings = 6;

  // The vessels, the body's right's; its left's are these turned over.

  /// The common carotid artery, from where it divides down past the gland,
  /// cut short below; the internal and external carotids out of it, cut
  /// short above.
  static const AnatomyTube carotid = AnatomyTube(
    <Offset>[
      Offset(-29.4, -4),
      Offset(-30.2, 6),
      Offset(-30.8, 28),
      Offset(-30, 52),
      Offset(-28.6, 66),
      Offset(-27.6, 74),
    ],
    <double>[3.05, 3.05, 3.05, 3.05, 3.05, 3.05],
    cutEnd: true,
  );
  static const AnatomyTube internalCarotid = AnatomyTube(
    <Offset>[Offset(-29.4, -4), Offset(-30.4, -6.8), Offset(-31.4, -9.6)],
    <double>[2.6, 2.4, 2.33],
    cutEnd: true,
  );
  static const AnatomyTube externalCarotid = AnatomyTube(
    <Offset>[Offset(-29.4, -4), Offset(-27.8, -6.8), Offset(-26.8, -9.6)],
    <double>[2.2, 2, 2],
    cutEnd: true,
  );

  /// The superior thyroid artery, from the external carotid arching down to
  /// the cut lobe's apex, where the cut takes it; the left's runs on down
  /// the left lobe's medial border to meet the right's along the isthmus.
  static const AnatomyTube superiorArtery = AnatomyTube(
    <Offset>[
      Offset(-27.6, -7),
      Offset(-25, -8.6),
      Offset(-21.8, -7.6),
      Offset(-19.4, -3.4),
      Offset(-17.6, 4.6),
      Offset(-16.4, 13.8),
    ],
    <double>[1, 1, 1, 1, 1, 1],
    cutEnd: true,
  );
  static const AnatomyTube anteriorBranch = AnatomyTube(
    <Offset>[
      Offset(16.4, 13.6),
      Offset(14.6, 18),
      Offset(12.4, 24),
      Offset(10.6, 31),
      Offset(8.8, 37),
      Offset(6.2, 41.8),
      Offset(3, 43.8),
      Offset(0, 44.4),
      Offset(-3, 44),
      Offset(-5.4, 43.2),
    ],
    <double>[0.9, 0.9, 0.9, 0.85, 0.85, 0.8, 0.8, 0.8, 0.8, 0.8],
    cutEnd: true,
  );

  /// The internal jugular vein, lateral to the artery, cut short above and
  /// below.
  static const AnatomyTube jugular = AnatomyTube(
    <Offset>[
      Offset(-36.8, -6),
      Offset(-37.4, 4),
      Offset(-38.2, 28),
      Offset(-37.6, 52),
      Offset(-36.4, 66),
      Offset(-35.6, 74),
    ],
    <double>[4, 4, 4, 4, 4, 4],
    cutStart: true,
    cutEnd: true,
  );

  /// The middle thyroid vein, from the lobe's lateral border across the
  /// front of the artery into the jugular.
  static const AnatomyTube middleVein = AnatomyTube(
    <Offset>[Offset(-27, 46.6), Offset(-30.4, 47.6), Offset(-34.4, 47.8)],
    <double>[1.2, 1.2, 1.2],
  );

  /// The inferior thyroid vein, down from the isthmus's lower border over
  /// the trachea's front, cut short with it.
  static const AnatomyTube inferiorVein = AnatomyTube(
    <Offset>[Offset(-3.2, 54.8), Offset(-3.6, 64), Offset(-4, 73.6)],
    <double>[1.1, 1.1, 1.1],
    cutEnd: true,
  );

  // Where the parts are named.

  static const Offset isthmusName = Offset(1.6, 49);
  static const Offset larynxName = Offset(10, 7);
  static const Offset tracheaName = Offset(0, 66);
  static const Offset carotidName = Offset(30.8, 20);
  static const Offset jugularName = Offset(-38, 14);
}
