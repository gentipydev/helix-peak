import 'dart:ui';

import '../../tube_course.dart';

/// The blood vessel the zoom goes into: a length of the descending thoracic
/// aorta, from the sixth thoracic vertebra to the tenth, seen from the
/// front in place on the vertebral column, what lies in front of it (the
/// esophagus, the heart, the lungs) taken away. A window is cut in its
/// front wall in steps, as a plate of an artery's coats is: the adventitia
/// turned back over a long oval, the media under it bared, and inside that
/// a smaller window through the media and the intima into the lumen, its
/// back wall's intima seen through it with the openings of a pair of
/// intercostal arteries. Round it the posterior intercostal arteries leave
/// its back in pairs, the azygos vein climbs on the right of the vertebral
/// bodies with the thoracic duct between it and the aorta, and the
/// hemiazygos crosses behind the aorta to the azygos; the aorta is cut
/// short above and below. It is drawn from general anatomy, in millimetres,
/// x across to the body's left, y down, from the middle of the eighth
/// thoracic vertebral body.
///
/// What is measured. After Gray (1918, pp. 568-570 and 601-602, read in
/// the archive.org text of the 20th edition): the descending thoracic aorta
/// begins at the lower border of the fourth thoracic vertebra, on the left
/// of the column, and approaches the median line as it descends, ending in
/// front of the column at the aortic hiatus; the azygos vein ascends on the
/// right of the vertebral bodies, the thoracic duct between it and the
/// aorta; the hemiazygos crosses the column behind the aorta, at about the
/// eighth thoracic vertebra, to end in the azygos; the aortic intercostal
/// arteries arise from the back of the aorta, the right ones longer,
/// crossing the vertebral bodies behind the thoracic duct and the azygos;
/// an artery's wall has three coats, the intima, the media, of smooth
/// muscle in circular layers with elastic lamellae, thickest in the
/// arteries' coats, and the adventitia, the vasa vasorum in it. The
/// descending aorta is 2.33 cm across where it begins and 2.14 cm in its
/// lower part on CT in 129 adults (Euathrongchit et al. 2009, J Med Assoc
/// Thai 92:236); the thoracic aorta's wall is 2.23 mm thick on average on
/// MRI in 1,053 adults of the Multi-Ethnic Study of Atherosclerosis
/// (Malayeri et al. 2008, Am J Cardiol 102:491). GTEx samples the aorta
/// from the "Ascending aorta or other thoracic regions (nonatherosclerotic)"
/// (the GTEx Portal's sampling site for Artery - Aorta, gtex_v10), with the
/// coronary and the tibial arteries the Human Protein Atlas's blood vessel.
///
/// Drawing choices, measured by none of these: the length, the card's 12
/// cm; the aorta 22.6 mm across above and 21.4 below, its course across the
/// column; the vertebral bodies 34 mm wide and 21 mm high, the discs 6 mm;
/// the windows' sizes and where they are cut; the coats' shares of the
/// wall where they are cut through; the media's lamellae, 0.85 mm apart as
/// drawn, many times their true spacing; the intercostals 2 mm across and
/// where they fade out; the azygos 8.4 mm, the duct 2.4 mm and the
/// hemiazygos 4.8 mm across, and their courses; the vasa vasorum's courses;
/// where the tissue is sampled.
abstract final class AortaAnatomy {
  /// How long the length of aorta is: about 12 cm, as the zoom's card has
  /// it.
  static const double length = 120;

  /// The aorta's course, cut short at both ends, and how wide it is along
  /// it.
  static const AnatomyTube aorta = AnatomyTube(
    <Offset>[
      Offset(14.2, -62),
      Offset(13.2, -40),
      Offset(12.2, -20),
      Offset(11.2, 0),
      Offset(10.4, 20),
      Offset(9.6, 40),
      Offset(9, 62),
    ],
    <double>[11.3, 11.2, 11.1, 11, 10.9, 10.8, 10.7],
    cutStart: true,
    cutEnd: true,
  );

  /// How thick its wall is, and the shares of it each coat takes: the
  /// intima, the media and the adventitia.
  static const double wall = 2.2;
  static const double intimaShare = 0.08;
  static const double mediaShare = 0.7;

  /// The window: its middle, how far along the aorta from it, and how far
  /// across, the adventitia is turned back, and the window through the
  /// media and the intima inside that; how square their corners are.
  static const double windowAt = -4;
  static const double outerHigh = 22;
  static const double outerWide = 7.6;
  static const double innerHigh = 14.5;
  static const double innerWide = 4.6;
  static const double windowSquare = 3;

  /// The openings of the pair of intercostal arteries on the back wall,
  /// seen through the inner window: how far below the window's middle, how
  /// far to either side of the aorta's middle, and how big each is.
  static const double ostiaDown = 5.5;
  static const double ostiaApart = 2.9;
  static const double ostiumWide = 1;
  static const double ostiumHigh = 0.75;

  /// The media's lamellae, bared in the window: how far apart they are
  /// drawn.
  static const double lamellaApart = 0.85;

  // The column.

  /// The vertebral bodies: the middle of each, how far each reaches to
  /// either side at its ends and at its waist, how high each is, how round
  /// its corners; the discs between them fill the rest.
  static const List<double> bodies = <double>[-54, -27, 0, 27, 54];
  static const double bodyWide = 17;
  static const double bodyWaist = 15.6;
  static const double bodyHigh = 10.5;
  static const double bodyCorner = 2.6;
  static const double discWide = 17.4;

  /// How far above and below the middle the column fades out.
  static const double columnFrom = 52;
  static const double columnTo = 70;

  // What runs beside the aorta.

  /// The posterior intercostal arteries, one pair at each vertebral body's
  /// middle: the right one's course from under the aorta out across the
  /// column, behind the duct and the azygos, and the left one's, each
  /// fading out, the left ones soon, as they turn back round the column's
  /// side; how wide each is.
  static List<Offset> rightIntercostal(double y, double aorta) => <Offset>[
    Offset(aorta - 6, y + 1),
    Offset(-2, y + 0.6),
    Offset(-12, y - 0.3),
    Offset(-21, y - 0.6),
    Offset(-31, y - 0.2),
    Offset(-41, y + 1.2),
  ];
  static List<Offset> leftIntercostal(double y, double aorta) => <Offset>[
    Offset(aorta + 6, y + 1),
    Offset(aorta + 10, y + 0.5),
    Offset(aorta + 14, y + 0.2),
    Offset(aorta + 18, y + 0.6),
  ];
  static const double intercostal = 1;
  static const double intercostalFade = 13;

  /// The azygos vein, climbing on the right of the vertebral bodies; the
  /// thoracic duct, between it and the aorta; the hemiazygos, climbing on
  /// the left behind the aorta and crossing to the azygos.
  static const AnatomyTube azygos = AnatomyTube(
    <Offset>[
      Offset(-11.8, -68),
      Offset(-12.1, -30),
      Offset(-12.4, 0),
      Offset(-12.6, 30),
      Offset(-12.2, 68),
    ],
    <double>[4.2, 4.2, 4.2, 4.2, 4.1],
    fadeIn: 10,
    fadeOut: 10,
  );
  static const AnatomyTube duct = AnatomyTube(
    <Offset>[
      Offset(-4.2, -68),
      Offset(-4.1, -45),
      Offset(-3.9, -22),
      Offset(-4.1, 0),
      Offset(-4.4, 22),
      Offset(-4.7, 45),
      Offset(-4.9, 68),
    ],
    <double>[1.2, 1.4, 1.15, 1.4, 1.15, 1.4, 1.2],
    fadeIn: 10,
    fadeOut: 10,
  );
  static const AnatomyTube hemiazygos = AnatomyTube(
    <Offset>[
      Offset(25.6, 68),
      Offset(25, 40),
      Offset(24.4, 20),
      Offset(22.6, 8),
      Offset(12, 0.5),
      Offset(0, -4),
      Offset(-9.6, -6),
    ],
    <double>[2.4, 2.4, 2.4, 2.4, 2.3, 2.3, 2.3],
    fadeIn: 10,
  );

  /// The vasa vasorum on the adventitia: how many, how wide each is, and
  /// how far each runs.
  static const int vasa = 7;
  static const double vasum = 0.16;
  static const double vasumRun = 18;

  // Where it is gone into, and where its parts are named.

  /// Where the tissue is sampled: in the media bared in the window, just
  /// outside the inner window on the body's right, at its middle, where
  /// the wall's three coats are cut through beside it.
  static const double siteOut = 5.7;

  /// The intima, through the inner window; the media, bared in the window
  /// on the body's left; the adventitia, beside the window: each across
  /// from the aorta's middle at its height. An intercostal artery on the
  /// left; the azygos; the duct; a vertebral body, where it shows between
  /// the azygos and the duct.
  static const Offset intimaName = Offset(-2, -12);
  static const Offset mediaName = Offset(6.2, -18);
  static const Offset adventitiaName = Offset(9.2, 19);
  static const Offset intercostalName = Offset(21.2, 54.7);
  static const Offset azygosName = Offset(-12.2, -40);
  static const Offset ductName = Offset(-4.6, 33);
  static const Offset bodyName = Offset(-7.4, 49);
}
