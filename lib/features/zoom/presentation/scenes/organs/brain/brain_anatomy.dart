import 'dart:ui';

import '../../tube_course.dart';

/// A sulcus of the brain's medial face: its course, and whether it is one of
/// the major sulci, deep, or a minor one, shallower.
final class BrainSulcus {
  const BrainSulcus(this.name, this.points, {this.major = true});

  final String name;
  final List<Offset> points;
  final bool major;
}

/// The brain cut down its middle, drawn from general anatomy: in millimetres
/// on a brain 17 cm from pole to pole, the medial face of its right half seen
/// from the left, front to the left. The origin is the anterior commissure;
/// x runs back, y runs down.
///
/// Where it can be, it is measured: the anterior and posterior commissures,
/// the genu's front and the splenium's foot, the pineal, the colliculi's
/// foot, the interpeduncular fossa, the mammillary bodies, the
/// pontomesencephalic junction and the culmen are the anatomical fiducials
/// raters placed on the MNI152 2009c average of 152 adult brains (Lau et al.
/// 2019, Hum Brain Mapp 40:4163), unscaled, the template being 17 cm long.
/// The rest is drawn over that template's mid-sagittal slice, and the medial
/// face's sulci over the slice 3 mm to its side, after the plates of Gray's
/// Anatomy (Standring 2020) and the atlases of the sulci (Ono et al. 1990)
/// and of the brain's vessels (Duvernoy 1999). Sizes keep to what MRI
/// measures: a corpus callosum some 75 mm long, its genu and splenium about
/// 11 mm thick and its body 6; a pons 23 mm deep, a medulla 13 (Singh et al.
/// 2019); a pituitary 6 mm tall.
abstract final class BrainAnatomy {
  /// The medial face's edge: from the frontal pole up over the superior
  /// border to the occipital pole, forward along the tentorium's edge, under
  /// the diencephalon and the brainstem, which hide it, and along the orbital
  /// surface back to the frontal pole.
  static const List<Offset> hemisphere = <Offset>[
    Offset(-67.4, -2.0),
    Offset(-66.9, -11.0),
    Offset(-65.4, -20.0),
    Offset(-62.6, -29.5),
    Offset(-57.4, -39.0),
    Offset(-50.0, -48.5),
    Offset(-41.0, -57.5),
    Offset(-31.0, -66.0),
    Offset(-20.5, -73.0),
    Offset(-9.5, -78.0),
    Offset(1.0, -80.6),
    Offset(12.0, -81.8),
    Offset(23.0, -82.4),
    Offset(34.0, -81.8),
    Offset(44.0, -79.6),
    Offset(53.0, -75.8),
    Offset(62.0, -71.0),
    Offset(71.0, -65.0),
    Offset(79.5, -58.6),
    Offset(87.0, -51.0),
    Offset(93.2, -42.6),
    Offset(98.4, -33.0),
    Offset(101.8, -23.6),
    Offset(103.3, -14.6),
    Offset(102.6, -5.6),
    Offset(100.0, 2.0),
    Offset(95.6, 7.8),
    Offset(89.0, 8.6),
    Offset(80.0, 3.4),
    Offset(70.0, -2.6),
    Offset(61.0, -8.4),
    Offset(53.5, -10.4),
    Offset(48.4, -9.6),
    Offset(44.4, -4.6),
    Offset(39.0, 2.0),
    Offset(32.0, 9.0),
    Offset(24.0, 13.4),
    Offset(15.0, 15.8),
    Offset(6.0, 15.6),
    Offset(-2.0, 13.4),
    Offset(-9.0, 15.4),
    Offset(-16.0, 20.2),
    Offset(-24.0, 23.4),
    Offset(-33.0, 24.8),
    Offset(-42.0, 24.8),
    Offset(-50.0, 23.4),
    Offset(-57.0, 20.2),
    Offset(-62.6, 14.6),
    Offset(-66.0, 7.2),
  ];

  /// The corpus callosum, cut: from the rostrum's tip forward under the
  /// genu, up its front, along the body, round the splenium, and back along
  /// its underside.
  static const List<Offset> callosum = <Offset>[
    Offset(-17.0, -3.2),
    Offset(-21.6, -2.6),
    Offset(-26.0, -3.4),
    Offset(-29.0, -5.0),
    Offset(-30.4, -7.0),
    Offset(-30.1, -11.6),
    Offset(-28.2, -17.0),
    Offset(-24.6, -21.8),
    Offset(-19.6, -26.2),
    Offset(-13.6, -29.6),
    Offset(-6.6, -32.2),
    Offset(0.5, -33.7),
    Offset(8.0, -34.4),
    Offset(16.0, -34.4),
    Offset(24.0, -33.6),
    Offset(31.0, -32.3),
    Offset(37.0, -30.5),
    Offset(41.8, -27.8),
    Offset(45.0, -24.0),
    Offset(46.4, -19.4),
    Offset(45.6, -15.0),
    Offset(43.2, -12.0),
    Offset(40.5, -10.9),
    Offset(37.6, -11.6),
    Offset(35.4, -13.6),
    Offset(34.4, -16.6),
    Offset(33.4, -20.2),
    Offset(30.0, -24.0),
    Offset(24.0, -27.6),
    Offset(16.0, -28.6),
    Offset(8.0, -28.6),
    Offset(0.0, -28.0),
    Offset(-7.0, -26.6),
    Offset(-13.0, -24.3),
    Offset(-18.0, -21.0),
    Offset(-20.6, -16.6),
    Offset(-21.2, -11.8),
    Offset(-20.4, -7.8),
    Offset(-18.8, -5.0),
  ];

  /// The genu's most anterior point and the splenium's lowest, as the
  /// fiducials place them.
  static const Offset genu = Offset(-30.4, -6.8);
  static const Offset splenium = Offset(40.5, -10.9);

  /// The fornix's middle line, cut: from under the splenium forward over the
  /// thalamus and down its column behind the anterior commissure; and its
  /// half-width.
  static const List<Offset> fornix = <Offset>[
    Offset(32.6, -19.6),
    Offset(26.0, -21.6),
    Offset(19.0, -21.6),
    Offset(12.0, -20.2),
    Offset(6.5, -17.4),
    Offset(2.8, -13.4),
    Offset(0.9, -8.6),
    Offset(1.0, -4.0),
    Offset(2.2, -1.2),
  ];

  static const double fornixHalf = 2.1;

  /// The septum pellucidum, between the corpus callosum and the fornix: the
  /// window onto the lateral ventricle, for the choroid plexus.
  static const List<Offset> septum = <Offset>[
    Offset(30.4, -23.4),
    Offset(24.0, -27.6),
    Offset(16.0, -28.6),
    Offset(8.0, -28.6),
    Offset(0.0, -28.0),
    Offset(-7.0, -26.6),
    Offset(-13.0, -24.3),
    Offset(-18.0, -21.0),
    Offset(-20.6, -16.6),
    Offset(-21.2, -11.8),
    Offset(-20.4, -7.8),
    Offset(-18.8, -5.0),
    Offset(-17.0, -3.2),
    Offset(-11.0, -2.6),
    Offset(-5.0, -2.4),
    Offset(-1.4, -3.0),
    Offset(-1.2, -8.6),
    Offset(0.6, -14.2),
    Offset(4.6, -19.2),
    Offset(11.0, -22.4),
    Offset(19.0, -23.8),
    Offset(26.0, -23.8),
  ];

  /// What lies deep behind the core, seen between its parts: the third
  /// ventricle's roof and recesses, the cisterns round the midbrain and
  /// under the hypothalamus. From the rostrum's tip along the corpus
  /// callosum's underside to the splenium's foot, down the vermis's front
  /// to the lingula, through the brainstem to the pons's top, forward under
  /// the hypothalamus and the chiasm, and up the lamina terminalis.
  static const List<Offset> deep = <Offset>[
    Offset(-17.0, -3.2),
    Offset(-18.8, -5.0),
    Offset(-20.4, -7.8),
    Offset(-21.2, -11.8),
    Offset(-20.6, -16.6),
    Offset(-18.0, -21.0),
    Offset(-13.0, -24.3),
    Offset(-7.0, -26.6),
    Offset(0.0, -28.0),
    Offset(8.0, -28.6),
    Offset(16.0, -28.6),
    Offset(24.0, -27.6),
    Offset(30.0, -24.0),
    Offset(33.4, -20.2),
    Offset(34.4, -16.6),
    Offset(35.4, -13.6),
    Offset(37.6, -11.6),
    Offset(40.5, -10.9),
    Offset(43.0, -10.0),
    Offset(45.0, -7.0),
    Offset(45.4, -3.0),
    Offset(44.0, 3.6),
    Offset(43.4, 8.6),
    Offset(40.8, 12.4),
    Offset(33.0, 14.4),
    Offset(26.0, 16.4),
    Offset(22.0, 18.6),
    Offset(16.0, 18.0),
    Offset(9.0, 18.4),
    Offset(3.0, 19.6),
    Offset(-1.0, 20.6),
    Offset(-6.0, 19.6),
    Offset(-8.0, 17.0),
    Offset(-7.0, 13.6),
    Offset(-3.0, 10.2),
    Offset(-1.6, 7.0),
    Offset(-1.6, 3.0),
    Offset(-2.4, -1.0),
    Offset(-5.0, -2.0),
    Offset(-11.0, -2.4),
  ];

  /// The anterior and posterior commissures, cut.
  static const Rect anteriorCommissure = Rect.fromLTRB(-1.9, -2.3, 1.9, 2.3);
  static const Rect posteriorCommissure = Rect.fromLTRB(26.6, -3.7, 30.0, -1.1);

  /// The thalamus's medial face, the third ventricle's wall above the
  /// hypothalamic sulcus.
  static const List<Offset> thalamus = <Offset>[
    Offset(4.4, -11.4),
    Offset(6.4, -14.6),
    Offset(10.0, -16.6),
    Offset(15.0, -17.6),
    Offset(20.5, -17.4),
    Offset(25.2, -15.6),
    Offset(28.2, -12.4),
    Offset(29.4, -8.8),
    Offset(28.4, -5.4),
    Offset(24.4, -4.0),
    Offset(18.0, -3.4),
    Offset(12.0, -4.0),
    Offset(7.6, -5.6),
    Offset(5.0, -8.2),
  ];

  /// The interthalamic adhesion, cut.
  static const Rect adhesion = Rect.fromLTRB(9.2, -12.8, 17.6, -6.8);

  /// The hypothalamus, the wall below the sulcus, down to the third
  /// ventricle's floor: the lamina terminalis, the infundibular recess, the
  /// tuber cinereum.
  static const List<Offset> hypothalamus = <Offset>[
    Offset(5.0, -8.2),
    Offset(7.6, -5.6),
    Offset(12.0, -4.0),
    Offset(18.0, -3.4),
    Offset(24.4, -4.0),
    Offset(23.4, -0.6),
    Offset(20.2, 2.6),
    Offset(16.5, 6.5),
    Offset(14.0, 7.4),
    Offset(12.2, 9.0),
    Offset(8.6, 10.4),
    Offset(6.0, 11.6),
    Offset(3.6, 12.2),
    Offset(1.4, 10.8),
    Offset(0.2, 8.6),
    Offset(-0.4, 5.4),
    Offset(0.2, 2.4),
    Offset(2.4, 0.6),
    Offset(3.4, -3.6),
  ];

  static const Rect mammillary = Rect.fromLTRB(7.9, 6.5, 13.3, 11.5);

  /// The optic chiasm, cut.
  static const List<Offset> chiasm = <Offset>[
    Offset(-6.4, 17.0),
    Offset(-4.2, 15.0),
    Offset(-0.6, 12.8),
    Offset(3.0, 11.4),
    Offset(5.2, 11.8),
    Offset(4.8, 13.6),
    Offset(1.4, 15.4),
    Offset(-2.4, 17.4),
    Offset(-5.4, 18.6),
  ];

  /// The infundibulum's middle line, from the tuber cinereum to the
  /// pituitary, and how wide it is at either end.
  static const List<Offset> infundibulum = <Offset>[
    Offset(4.6, 12.4),
    Offset(3.8, 16.2),
    Offset(2.8, 20.0),
    Offset(2.0, 24.0),
  ];

  static const double infundibulumTop = 1.9;
  static const double infundibulumFoot = 1.2;

  /// The pituitary's anterior lobe and its posterior lobe, cut.
  static const List<Offset> pituitaryAnterior = <Offset>[
    Offset(-1.0, 23.6),
    Offset(-3.8, 24.0),
    Offset(-5.4, 25.6),
    Offset(-5.6, 27.8),
    Offset(-4.4, 29.8),
    Offset(-1.6, 30.6),
    Offset(1.6, 30.2),
    Offset(2.6, 28.6),
    Offset(2.2, 25.8),
    Offset(1.0, 23.9),
  ];

  static const List<Offset> pituitaryPosterior = <Offset>[
    Offset(1.0, 23.9),
    Offset(2.2, 25.8),
    Offset(2.6, 28.6),
    Offset(1.6, 30.2),
    Offset(3.8, 29.8),
    Offset(5.4, 28.2),
    Offset(5.6, 26.0),
    Offset(4.4, 24.0),
    Offset(2.6, 23.4),
  ];

  /// The pineal gland.
  static const List<Offset> pineal = <Offset>[
    Offset(29.6, -5.0),
    Offset(31.0, -7.8),
    Offset(34.4, -8.8),
    Offset(37.6, -7.4),
    Offset(39.2, -5.4),
    Offset(37.8, -3.4),
    Offset(34.2, -2.4),
    Offset(31.0, -3.0),
  ];

  /// The brainstem, cut: the midbrain from the posterior commissure round
  /// the interpeduncular fossa to the pontomesencephalic junction, the
  /// pons's bulge, the pontomedullary sulcus, the medulla to its cut at the
  /// foramen magnum, and back up its dorsal face and the fourth ventricle's
  /// floor, the tectum's colliculi, to the aqueduct.
  static const List<Offset> brainstem = <Offset>[
    Offset(27.6, -1.2),
    Offset(24.0, 0.4),
    Offset(20.6, 3.4),
    Offset(17.6, 6.4),
    Offset(19.6, 9.6),
    Offset(23.0, 13.2),
    Offset(26.0, 16.4),
    Offset(22.0, 18.6),
    Offset(18.6, 21.8),
    Offset(16.6, 26.4),
    Offset(16.2, 31.4),
    Offset(17.0, 36.6),
    Offset(19.4, 41.0),
    Offset(23.4, 44.0),
    Offset(28.6, 45.4),
    Offset(31.6, 47.4),
    Offset(33.6, 52.4),
    Offset(35.8, 58.0),
    Offset(38.0, 64.0),
    Offset(49.8, 64.0),
    Offset(48.8, 60.0),
    Offset(47.6, 55.6),
    Offset(46.2, 51.0),
    Offset(44.4, 47.2),
    Offset(42.4, 44.0),
    Offset(40.6, 39.0),
    Offset(39.4, 31.0),
    Offset(39.6, 24.0),
    Offset(40.0, 17.6),
    Offset(40.8, 12.4),
    Offset(41.4, 8.4),
    Offset(40.8, 6.4),
    Offset(38.6, 3.8),
    Offset(38.0, 1.6),
    Offset(35.8, -0.4),
    Offset(32.4, -1.6),
  ];

  /// Where the midbrain gives way to the pons, and the pons to the medulla,
  /// across the cut.
  static const List<Offset> ponsTop = <Offset>[
    Offset(26.0, 16.4),
    Offset(40.4, 12.0),
  ];

  static const List<Offset> ponsFoot = <Offset>[
    Offset(28.6, 45.4),
    Offset(42.2, 45.6),
  ];

  /// The cerebral aqueduct's middle line, and its half-width.
  static const List<Offset> aqueduct = <Offset>[
    Offset(29.0, 0.2),
    Offset(32.6, 3.0),
    Offset(36.0, 6.8),
    Offset(38.6, 10.6),
  ];

  static const double aqueductHalf = 0.6;

  /// The fourth ventricle: its roof, the superior medullary velum up to
  /// the fastigium and the inferior down to the obex, and its floor back up
  /// the medulla and the pons.
  static const List<Offset> fourthVentricle = <Offset>[
    Offset(40.8, 12.4),
    Offset(44.6, 13.8),
    Offset(48.6, 17.6),
    Offset(52.2, 21.8),
    Offset(54.9, 25.0),
    Offset(53.6, 28.6),
    Offset(50.8, 33.0),
    Offset(48.2, 38.0),
    Offset(46.0, 43.0),
    Offset(44.4, 47.2),
    Offset(42.4, 44.0),
    Offset(40.6, 39.0),
    Offset(39.4, 31.0),
    Offset(39.6, 24.0),
    Offset(40.0, 17.6),
  ];

  /// The vermis, cut: from the lingula on the superior velum up its front to
  /// the culmen, down its tentorial face and its back, under the uvula to
  /// the nodulus, and up the fourth ventricle's roof to the fastigium.
  static const List<Offset> vermis = <Offset>[
    Offset(44.6, 13.8),
    Offset(43.4, 8.6),
    Offset(44.0, 3.6),
    Offset(46.0, -0.8),
    Offset(49.2, -4.4),
    Offset(52.6, -6.4),
    Offset(55.6, -6.9),
    Offset(59.6, -6.3),
    Offset(65.0, -3.9),
    Offset(70.6, -0.2),
    Offset(75.6, 4.4),
    Offset(79.6, 9.6),
    Offset(82.4, 15.6),
    Offset(83.6, 22.0),
    Offset(83.0, 28.6),
    Offset(80.6, 34.6),
    Offset(76.6, 39.8),
    Offset(71.4, 43.8),
    Offset(65.4, 46.2),
    Offset(59.6, 46.6),
    Offset(55.0, 45.0),
    Offset(52.0, 41.6),
    Offset(50.4, 37.6),
    Offset(47.6, 38.0),
    Offset(50.8, 33.0),
    Offset(53.6, 28.6),
    Offset(54.9, 25.0),
    Offset(52.2, 21.8),
    Offset(48.6, 17.6),
  ];

  /// The vermis's white core, and each lobule's tip, lingula to nodulus.
  static const Offset arborCore = Offset(58.6, 19.6);

  static const List<Offset> lobules = <Offset>[
    Offset(45.8, 9.6),
    Offset(45.6, 1.6),
    Offset(52.6, -4.2),
    Offset(66.8, -1.2),
    Offset(77.6, 8.0),
    Offset(81.6, 20.0),
    Offset(78.6, 34.2),
    Offset(66.0, 44.0),
    Offset(52.6, 36.6),
  ];

  /// The vermis's fissures, each from the surface in: the preculminate,
  /// primary, posterior superior, horizontal, prepyramidal, secondary and
  /// posterolateral.
  static const List<List<Offset>> fissures = <List<Offset>>[
    <Offset>[Offset(47.4, -2.6), Offset(51.8, 4.6), Offset(55.0, 12.4)],
    <Offset>[Offset(61.6, -5.4), Offset(61.2, 3.0), Offset(60.2, 13.0)],
    <Offset>[Offset(73.0, 1.8), Offset(68.6, 8.6), Offset(64.6, 15.6)],
    <Offset>[Offset(81.4, 13.6), Offset(73.6, 15.4), Offset(66.2, 18.0)],
    <Offset>[Offset(83.0, 28.0), Offset(74.6, 27.4), Offset(66.4, 24.2)],
    <Offset>[Offset(74.4, 41.4), Offset(68.4, 35.0), Offset(63.6, 28.0)],
    <Offset>[Offset(54.0, 44.0), Offset(55.4, 37.8), Offset(57.0, 30.8)],
  ];

  /// The medial face's sulci: the major ones, then the minor.
  static const List<BrainSulcus> sulci = <BrainSulcus>[
    BrainSulcus('callosal', <Offset>[
      Offset(-15.0, -1.4),
      Offset(-24.2, -1.0),
      Offset(-30.4, -3.6),
      Offset(-32.6, -8.0),
      Offset(-32.2, -13.4),
      Offset(-30.0, -18.8),
      Offset(-26.0, -23.8),
      Offset(-20.6, -28.4),
      Offset(-14.0, -31.8),
      Offset(-6.6, -34.4),
      Offset(1.0, -35.8),
      Offset(9.0, -36.6),
      Offset(17.0, -36.6),
      Offset(25.0, -35.8),
      Offset(32.0, -34.4),
      Offset(38.4, -32.4),
      Offset(43.4, -29.4),
      Offset(46.8, -25.0),
      Offset(48.4, -19.6),
      Offset(47.8, -14.2),
      Offset(45.2, -10.2),
    ]),
    BrainSulcus('cingulate', <Offset>[
      Offset(-17.0, 6.4),
      Offset(-26.0, 5.4),
      Offset(-34.6, 1.6),
      Offset(-40.4, -5.6),
      Offset(-42.6, -14.4),
      Offset(-41.6, -24.0),
      Offset(-37.0, -32.6),
      Offset(-29.6, -39.6),
      Offset(-20.4, -44.8),
      Offset(-9.6, -48.2),
      Offset(1.6, -50.2),
      Offset(13.0, -51.6),
      Offset(24.0, -52.6),
      Offset(34.0, -53.4),
      Offset(40.6, -54.6),
      Offset(44.2, -59.6),
      Offset(46.4, -66.4),
      Offset(47.8, -73.4),
      Offset(48.4, -77.6),
    ]),
    BrainSulcus('paracentral', <Offset>[
      Offset(7.6, -51.0),
      Offset(6.6, -58.6),
      Offset(5.2, -66.0),
      Offset(4.0, -73.0),
    ]),
    BrainSulcus('central', <Offset>[
      Offset(27.4, -80.8),
      Offset(28.4, -76.4),
      Offset(29.4, -69.6),
      Offset(29.8, -64.6),
    ]),
    BrainSulcus('subparietal', <Offset>[
      Offset(43.2, -54.0),
      Offset(49.4, -52.0),
      Offset(56.0, -50.2),
      Offset(62.0, -48.6),
      Offset(67.0, -46.4),
    ]),
    BrainSulcus('parieto-occipital', <Offset>[
      Offset(84.8, -53.2),
      Offset(82.2, -47.6),
      Offset(77.6, -39.4),
      Offset(72.6, -30.6),
      Offset(67.8, -22.6),
      Offset(63.0, -16.6),
      Offset(58.0, -12.6),
    ]),
    BrainSulcus('calcarine', <Offset>[
      Offset(49.6, -11.4),
      Offset(54.0, -12.0),
      Offset(58.0, -12.6),
      Offset(65.0, -15.6),
      Offset(72.0, -18.8),
      Offset(80.0, -21.0),
      Offset(87.0, -21.0),
      Offset(93.0, -18.2),
      Offset(98.0, -13.0),
      Offset(101.4, -7.6),
    ]),
    BrainSulcus('superior rostral', <Offset>[
      Offset(-27.0, 11.6),
      Offset(-36.0, 11.4),
      Offset(-45.0, 10.8),
      Offset(-54.6, 9.8),
    ]),
    BrainSulcus('frontal 1', <Offset>[
      Offset(-12.6, -48.8),
      Offset(-14.6, -57.0),
      Offset(-18.0, -64.6),
      Offset(-20.6, -70.0),
    ], major: false),
    BrainSulcus('frontal 2', <Offset>[
      Offset(-26.6, -41.6),
      Offset(-31.6, -48.6),
      Offset(-36.6, -55.6),
    ], major: false),
    BrainSulcus('frontal 3', <Offset>[
      Offset(-37.6, -32.4),
      Offset(-44.6, -37.0),
      Offset(-51.0, -42.6),
    ], major: false),
    BrainSulcus('frontal 4', <Offset>[
      Offset(-42.0, -20.6),
      Offset(-50.4, -23.4),
      Offset(-58.0, -27.0),
    ], major: false),
    BrainSulcus('frontal 5', <Offset>[
      Offset(-42.4, -7.0),
      Offset(-51.6, -7.6),
      Offset(-60.6, -9.4),
    ], major: false),
    BrainSulcus('paracingulate', <Offset>[
      Offset(-30.0, -50.6),
      Offset(-18.0, -56.6),
      Offset(-6.0, -60.0),
      Offset(2.0, -61.0),
    ], major: false),
    BrainSulcus('inferior rostral', <Offset>[
      Offset(-30.0, 18.6),
      Offset(-40.0, 19.4),
      Offset(-50.0, 18.0),
    ], major: false),
    BrainSulcus('precuneal 1', <Offset>[
      Offset(56.0, -57.6),
      Offset(58.4, -64.4),
      Offset(60.0, -70.6),
    ], major: false),
    BrainSulcus('precuneal 2', <Offset>[
      Offset(70.6, -45.6),
      Offset(75.0, -51.6),
      Offset(78.6, -58.0),
    ], major: false),
    BrainSulcus('precuneal 3', <Offset>[
      Offset(53.0, -38.0),
      Offset(60.0, -36.0),
      Offset(66.0, -32.6),
    ], major: false),
    BrainSulcus('cuneal', <Offset>[
      Offset(72.0, -26.0),
      Offset(80.0, -31.0),
      Offset(88.0, -34.6),
    ], major: false),
    BrainSulcus('lingual', <Offset>[
      Offset(64.0, -10.4),
      Offset(72.0, -10.6),
      Offset(80.0, -10.2),
      Offset(88.0, -7.6),
    ], major: false),
    BrainSulcus('cuneal 2', <Offset>[
      Offset(78.0, -42.0),
      Offset(86.0, -46.4),
      Offset(90.6, -44.0),
    ], major: false),
    BrainSulcus('precuneal 4', <Offset>[
      Offset(47.6, -63.6),
      Offset(51.6, -70.0),
      Offset(54.8, -73.6),
    ], major: false),
    BrainSulcus('frontal 6', <Offset>[
      Offset(-46.0, -27.6),
      Offset(-53.6, -31.0),
      Offset(-57.8, -35.0),
    ], major: false),
    BrainSulcus('frontal 7', <Offset>[
      Offset(-52.0, 2.6),
      Offset(-58.0, 0.0),
      Offset(-63.0, -1.6),
    ], major: false),
    BrainSulcus('paracentral 2', <Offset>[
      Offset(36.6, -60.6),
      Offset(37.6, -68.0),
      Offset(39.6, -75.0),
    ], major: false),
    BrainSulcus('paracentral notch', <Offset>[
      Offset(14.0, -81.6),
      Offset(15.2, -76.4),
      Offset(15.6, -71.4),
    ], major: false),
  ];

  /// The anterior cerebral artery, rising in front of the lamina terminalis
  /// and round the genu.
  static const AnatomyTube anteriorCerebral = AnatomyTube(
    <Offset>[
      Offset(-8.6, 13.0),
      Offset(-11.6, 7.4),
      Offset(-17.0, 3.0),
      Offset(-24.6, 1.0),
      Offset(-31.6, -2.6),
      Offset(-34.6, -8.4),
    ],
    <double>[1.25, 1.25, 1.20, 1.20, 1.15, 1.10],
    fadeIn: 3.0,
  );

  /// The pericallosal artery, in the callosal sulcus to the splenium.
  static const AnatomyTube pericallosal = AnatomyTube(
    <Offset>[
      Offset(-34.6, -8.4),
      Offset(-33.6, -13.6),
      Offset(-31.0, -19.4),
      Offset(-26.8, -24.6),
      Offset(-21.2, -29.2),
      Offset(-14.4, -32.6),
      Offset(-6.8, -35.2),
      Offset(1.0, -36.6),
      Offset(9.0, -37.4),
      Offset(17.0, -37.4),
      Offset(25.2, -36.6),
      Offset(32.4, -35.2),
      Offset(38.8, -33.2),
      Offset(44.0, -30.0),
      Offset(47.6, -25.4),
      Offset(49.2, -19.8),
      Offset(48.8, -16.6),
    ],
    <double>[
      1.10,
      1.05,
      1.00,
      1.00,
      0.95,
      0.95,
      0.90,
      0.90,
      0.85,
      0.85,
      0.82,
      0.80,
      0.78,
      0.75,
      0.72,
      0.70,
      0.68,
    ],
  );

  /// The callosomarginal artery, in the cingulate sulcus.
  static const AnatomyTube callosomarginal = AnatomyTube(
    <Offset>[
      Offset(-32.6, -16.6),
      Offset(-38.6, -19.4),
      Offset(-41.0, -24.8),
      Offset(-37.6, -32.6),
      Offset(-30.2, -39.6),
      Offset(-20.4, -44.8),
      Offset(-9.4, -48.4),
      Offset(2.0, -50.4),
      Offset(13.2, -51.8),
      Offset(24.2, -52.8),
      Offset(33.0, -53.6),
    ],
    <double>[0.9, 0.88, 0.85, 0.82, 0.8, 0.78, 0.75, 0.72, 0.7, 0.66, 0.62],
    fadeOut: 4.0,
  );

  /// The cortical branches up the medial face, each fading over the
  /// superior border or the frontal pole.
  static const AnatomyTube frontopolar = AnatomyTube(
    <Offset>[
      Offset(-33.6, -13.6),
      Offset(-41.0, -16.6),
      Offset(-48.6, -18.6),
      Offset(-56.0, -20.4),
      Offset(-62.6, -22.6),
    ],
    <double>[0.65, 0.60, 0.58, 0.55, 0.50],
    fadeOut: 4.0,
  );

  static const AnatomyTube anteriorInternalFrontal = AnatomyTube(
    <Offset>[
      Offset(-37.4, -31.4),
      Offset(-44.0, -38.4),
      Offset(-50.0, -45.0),
      Offset(-55.4, -50.2),
    ],
    <double>[0.60, 0.58, 0.55, 0.50],
    fadeOut: 4.0,
  );

  static const AnatomyTube middleInternalFrontal = AnatomyTube(
    <Offset>[
      Offset(-21.8, -44.4),
      Offset(-26.0, -53.0),
      Offset(-30.6, -60.6),
      Offset(-34.6, -66.4),
    ],
    <double>[0.60, 0.58, 0.55, 0.50],
    fadeOut: 4.0,
  );

  static const AnatomyTube posteriorInternalFrontal = AnatomyTube(
    <Offset>[
      Offset(-4.0, -49.4),
      Offset(-6.6, -59.0),
      Offset(-9.6, -68.0),
      Offset(-12.0, -75.6),
    ],
    <double>[0.58, 0.55, 0.52, 0.50],
    fadeOut: 4.0,
  );

  static const AnatomyTube paracentral = AnatomyTube(
    <Offset>[
      Offset(13.6, -52.0),
      Offset(15.6, -61.0),
      Offset(18.0, -70.0),
      Offset(19.6, -78.4),
    ],
    <double>[0.58, 0.55, 0.52, 0.50],
    fadeOut: 4.0,
  );

  static const AnatomyTube precuneal = AnatomyTube(
    <Offset>[
      Offset(33.0, -36.0),
      Offset(39.6, -42.6),
      Offset(47.0, -50.6),
      Offset(54.6, -58.6),
      Offset(61.0, -66.6),
      Offset(66.0, -72.0),
    ],
    <double>[0.62, 0.60, 0.58, 0.55, 0.52, 0.50],
    fadeOut: 5.0,
  );

  /// The posterior cerebral artery, coming out from behind the midbrain, and
  /// its branches in the calcarine and parieto-occipital sulci and round the
  /// splenium.
  static const AnatomyTube posteriorCerebral = AnatomyTube(
    <Offset>[
      Offset(40.6, 4.4),
      Offset(44.6, -1.6),
      Offset(49.6, -7.0),
      Offset(54.6, -10.6),
    ],
    <double>[1.20, 1.15, 1.10, 1.05],
    fadeIn: 4.0,
  );

  static const AnatomyTube calcarine = AnatomyTube(
    <Offset>[
      Offset(54.6, -10.6),
      Offset(60.0, -13.6),
      Offset(66.6, -16.6),
      Offset(73.6, -19.4),
      Offset(81.0, -20.8),
      Offset(88.0, -20.4),
      Offset(94.0, -17.4),
      Offset(98.6, -12.4),
    ],
    <double>[0.80, 0.78, 0.75, 0.72, 0.70, 0.65, 0.60, 0.55],
    fadeOut: 4.0,
  );

  static const AnatomyTube parietoOccipital = AnatomyTube(
    <Offset>[
      Offset(54.6, -10.6),
      Offset(59.4, -16.0),
      Offset(64.4, -22.6),
      Offset(69.6, -30.4),
      Offset(74.6, -38.6),
      Offset(79.4, -46.6),
      Offset(83.6, -53.6),
    ],
    <double>[0.72, 0.70, 0.68, 0.65, 0.62, 0.58, 0.55],
    fadeOut: 4.0,
  );

  static const AnatomyTube splenial = AnatomyTube(
    <Offset>[Offset(48.6, -8.4), Offset(50.4, -13.6), Offset(50.4, -18.6)],
    <double>[0.55, 0.50, 0.45],
    fadeOut: 2.0,
  );

  /// The basilar artery up the front of the pons, the vertebral artery
  /// joining it from below, and the superior and posterior inferior
  /// cerebellar arteries on the vermis.
  static const AnatomyTube basilar = AnatomyTube(
    <Offset>[
      Offset(24.4, 45.8),
      Offset(19.6, 42.4),
      Offset(16.2, 37.0),
      Offset(14.6, 31.0),
      Offset(14.8, 25.4),
      Offset(16.6, 20.4),
      Offset(19.2, 16.4),
      Offset(21.2, 13.4),
    ],
    <double>[1.60, 1.65, 1.65, 1.65, 1.65, 1.60, 1.60, 1.55],
  );

  static const AnatomyTube vertebral = AnatomyTube(
    <Offset>[
      Offset(34.6, 66.0),
      Offset(31.4, 58.6),
      Offset(28.6, 52.0),
      Offset(26.2, 47.6),
      Offset(24.4, 45.8),
    ],
    <double>[1.40, 1.40, 1.40, 1.40, 1.45],
    fadeIn: 6.0,
  );

  static const AnatomyTube superiorCerebellar = AnatomyTube(
    <Offset>[
      Offset(42.6, 0.4),
      Offset(46.6, -4.4),
      Offset(52.0, -7.8),
      Offset(58.4, -8.4),
      Offset(65.0, -6.0),
      Offset(71.6, -2.0),
      Offset(77.0, 2.6),
    ],
    <double>[0.75, 0.72, 0.70, 0.68, 0.65, 0.60, 0.55],
    fadeIn: 3.0,
    fadeOut: 5.0,
  );

  static const AnatomyTube posteriorInferiorCerebellar = AnatomyTube(
    <Offset>[
      Offset(49.4, 54.6),
      Offset(52.8, 51.2),
      Offset(57.4, 49.2),
      Offset(63.0, 48.6),
      Offset(69.0, 46.8),
      Offset(75.0, 42.8),
      Offset(79.6, 37.6),
    ],
    <double>[0.75, 0.72, 0.70, 0.68, 0.65, 0.60, 0.55],
    fadeIn: 3.0,
    fadeOut: 5.0,
  );

  /// The arteries on the medial face, which the core is drawn over, and
  /// those of the posterior fossa, drawn over the brainstem and the vermis.
  static const List<AnatomyTube> faceArteries = <AnatomyTube>[
    anteriorCerebral,
    pericallosal,
    callosomarginal,
    frontopolar,
    anteriorInternalFrontal,
    middleInternalFrontal,
    posteriorInternalFrontal,
    paracentral,
    precuneal,
    posteriorCerebral,
    calcarine,
    parietoOccipital,
    splenial,
  ];
  static const List<AnatomyTube> fossaArteries = <AnatomyTube>[
    vertebral,
    basilar,
    superiorCerebellar,
    posteriorInferiorCerebellar,
  ];

  /// The choroid plexus: of the lateral ventricle, along the fornix's edge
  /// as far as the window through the septum shows it, thickening toward
  /// the atrium; of the third ventricle, along its roof; of the fourth,
  /// along the inferior velum.
  static const List<Offset> lateralPlexus = <Offset>[
    Offset(1.8, -17.3),
    Offset(4.4, -19.8),
    Offset(7.4, -21.7),
    Offset(11.0, -23.4),
    Offset(14.8, -24.2),
    Offset(18.6, -24.8),
    Offset(22.5, -24.9),
    Offset(26.0, -24.8),
    Offset(27.8, -24.4),
  ];

  static const List<Offset> thirdPlexus = <Offset>[
    Offset(4.8, -13.6),
    Offset(9.6, -17.0),
    Offset(15.0, -18.4),
    Offset(20.5, -18.2),
    Offset(25.4, -16.4),
    Offset(28.6, -13.0),
  ];

  static const List<Offset> fourthPlexus = <Offset>[
    Offset(52.4, 28.8),
    Offset(50.0, 32.4),
    Offset(47.6, 36.6),
    Offset(45.6, 41.0),
    Offset(44.0, 44.6),
  ];

  /// Where the tissue is sampled: for the cortex, on a crown of the
  /// precuneus; for the choroid plexus, on the lateral ventricle's.
  static const Offset cortexSite = Offset(65.0, -58.0);
  static const Offset plexusSite = Offset(22.0, -25.4);

  /// Where each landmark is named.
  static const Offset callosumName = Offset(6.0, -31.4);
  static const Offset thalamusName = Offset(15.6, -14.8);
  static const Offset hypothalamusName = Offset(6.0, 5.0);
  static const Offset cerebellumName = Offset(70.0, 26.0);
  static const Offset brainstemName = Offset(24.0, 30.0);
}
