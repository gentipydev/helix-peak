import 'dart:ui';

import '../../tube_course.dart';

/// The esophagus the anatomogram draws for the esophagus, opened from the
/// front and seen from the front, as the body shows it: its front wall cut
/// away down its whole length, so that what is seen is the inside of its
/// back wall, and the wall cut through down either side. It is drawn from
/// general anatomy, in millimetres, x across to the body's left, y down,
/// from the lower border of the cricoid cartilage on the midline, where it
/// begins. Lengths along it ([course]) are from there.
///
/// The cut is a composite, as an anatomy plate of the gullet's inside is:
/// the pharynx above it and the stomach below it cut short, the cut run on
/// a little way into the cardia so that the Z-line shows, where the
/// esophagus's pale lining meets the stomach's; round it, the diaphragm cut
/// either side of the hiatus, and the aortic arch and the descending aorta,
/// which pass to its left and behind it, what lies in front of it (the
/// trachea, the left bronchus, the heart) taken away with its front wall.
///
/// What is measured: after Gray (1918, the twentieth edition, read in the
/// Internet Archive's copy), it is 23 to 25 cm long, from the lower border
/// of the cricoid cartilage, opposite the sixth cervical vertebra, to the
/// cardiac orifice, opposite the eleventh thoracic; it inclines to the left
/// as far as the root of the neck, comes back to the middle line at the
/// fifth thoracic vertebra and deviates to the left again as it passes
/// forward to the hiatus, which it goes through at the tenth; it is most
/// contracted at its beginning and where it goes through the diaphragm, and
/// just above the diaphragm it is distinctly dilated; its abdominal part is
/// about 1.25 cm long and conical, its base on the cardia; it passes behind
/// and to the right of the aortic arch, then down the right side of the
/// descending aorta, and then in front of it and a little to its left. Its
/// four coats are the fibrous, the muscular, of an outer longitudinal and
/// an inner circular plane, striped above and unstriped below, the
/// submucous, holding its mucous glands, each opening by a long duct, and
/// the mucous, thick, in longitudinal folds that open out when it is
/// distended, under stratified squamous epithelium. Its wall on CT is 4.67
/// mm thick in the neck, 4.56 in the thorax, 4.05 behind the heart and 5.68
/// in the abdomen where it is contracted, and 1.87 to 2.70 mm where it is
/// distended, in 110 adults (Xia et al. 2009, Eur J Radiol 72:406). Its
/// muscle is thickest at the oblique gastroesophageal ring, the inner coat
/// thickened, tapering over 31 ± 2.5 mm above and below it (Liebermann-
/// Meffert et al. 1979, Gastroenterology 76:31). The cricopharyngeus, at its
/// beginning, behind and to the sides, is the lower third of the upper
/// sphincter (Sivarao and Goyal 2000, Am J Med 108 Suppl 4a:27S). The aorta
/// is 2.61 ± 0.41 cm across at the end of its arch, 2.47 ± 0.40 at its
/// isthmus and 2.43 ± 0.35 at the diaphragm, on helical CT in 70 adults
/// (Hager et al. 2002, J Thorac Cardiovasc Surg 123:1060). Its tissue is
/// gone into in its lower third, at least 4 cm above the gastroesophageal
/// junction, where GTEx takes its mucosa (the GTEx Portal's sampling site
/// for Esophagus - Mucosa, gtex_v10).
///
/// Drawing choices, measured by none of these: its course, 250 mm long, its
/// curves as Gray words them, the turn to the left from about the seventh
/// thoracic vertebra, and its cardia laid where the anatomogram's two
/// figures draw theirs; 22 mm across through most of its length, narrower
/// at its beginning and at the hiatus, the dilatation above it, widening
/// into the cardia; the wall between Xia's contracted and distended
/// measures, the coats' shares of it, the cricopharyngeus's 10 mm and the
/// lower sphincter's thickening; the thoracic inlet 45 mm down, from the
/// vertebral levels; the folds, how many, where, how far they wander and
/// where they end; the Z-line's tongues; the glands' spacing and size; and
/// the pharynx, the stomach, the diaphragm and the aorta's courses and
/// where each is cut short.
abstract final class EsophagusAnatomy {
  /// How long the esophagus is, along its course, from the cricoid to the
  /// gastroesophageal junction; and how far on into the cardia it is cut
  /// open, so that the Z-line and the stomach's mucosa show.
  static const double length = 250;
  static const double opened = 262;

  /// Its course, along its middle, from where it begins on into the
  /// cardia: Gray's two slight curves, to the left at the root of the neck
  /// and back by the fifth thoracic vertebra, then the turn to the left
  /// through the hiatus.
  static const List<Offset> course = <Offset>[
    Offset(0.0, 0.0),
    Offset(0.6, 10.0),
    Offset(2.0, 20.0),
    Offset(3.4, 30.0),
    Offset(4.0, 40.0),
    Offset(3.6, 55.0),
    Offset(2.7, 70.0),
    Offset(1.6, 85.0),
    Offset(0.6, 100.0),
    Offset(0.0, 120.0),
    Offset(0.0, 140.0),
    Offset(0.0, 150.0),
    Offset(0.3, 160.0),
    Offset(1.1, 170.0),
    Offset(2.5, 179.9),
    Offset(4.4, 189.7),
    Offset(6.9, 199.4),
    Offset(10.0, 208.9),
    Offset(13.5, 218.2),
    Offset(17.6, 227.4),
    Offset(22.1, 236.3),
    Offset(27.2, 244.9),
    Offset(33.6, 255.1),
  ];

  /// How far it reaches to either side of its middle, at so far along it:
  /// most contracted at its beginning and at the hiatus, dilated just
  /// above the diaphragm, conical below it, its base on the cardia.
  static const List<(double, double)> half = <(double, double)>[
    (0, 8.5),
    (8, 9),
    (20, 10.5),
    (40, 11),
    (205, 11),
    (218, 12.2),
    (226, 12.4),
    (235, 10.2),
    (243, 11.5),
    (250, 13.5),
    (262, 16.5),
  ];

  /// How thick its wall is, at so far along it: the cricopharyngeus
  /// thickening its beginning, the lower sphincter its end, thickest at the
  /// gastroesophageal ring and tapering over 31 mm either way.
  static const List<(double, double)> wall = <(double, double)>[
    (0, 5.2),
    (6, 5),
    (14, 3.4),
    (45, 3.3),
    (150, 3.2),
    (219, 3.2),
    (235, 4.6),
    (250, 6.2),
    (262, 4.6),
  ];

  /// The wall's coats, from the outside in, each a share of the wall at
  /// most so many millimetres: the fibrous coat, the submucosa and the
  /// mucosa; the muscularis is the rest, so that it is what thickens into
  /// the sphincters. Its outer, longitudinal plane is so thick, and its
  /// inner, circular plane the rest of it, the plane the sphincters
  /// thicken.
  static const double fibrousShare = 0.06;
  static const double fibrousMost = 0.25;
  static const double submucosaShare = 0.2;
  static const double submucosaMost = 0.7;
  static const double mucosaShare = 0.26;
  static const double mucosaMost = 0.9;
  static const double longitudinal = 0.75;

  /// Where along it its parts are: the cricopharyngeus, the thoracic
  /// inlet, the hiatus, and the gastroesophageal junction, its end.
  static const double cricopharyngeus = 10;
  static const double inlet = 45;
  static const double hiatus = 235;

  /// Where the body goes into the esophagus, so far along it, on its
  /// middle, in its lower third: the drawing is laid so that this lies on
  /// the place the body's outline of it is gone into.
  static const double siteAlong = 187;

  // The folds.

  /// Each fold of its lining: how far across it lies (from -1 at the
  /// lining's edge on the body's right to 1 on its left), from and to how
  /// far along it it runs, and the seed of its wandering. They run its
  /// length, gathered where it is narrow.
  static const List<(double, double, double, int)> folds =
      <(double, double, double, int)>[
        (-0.62, 4, 236, 1),
        (-0.25, 10, 150, 2),
        (-0.3, 158, 246, 3),
        (0, 14, 95, 4),
        (0.2, 6, 120, 5),
        (0.32, 130, 244, 6),
        (0.66, 8, 240, 7),
        (0.02, 210, 247, 8),
      ];

  /// How far a fold wanders to either side, a share of the way across, and
  /// the two wavelengths it wanders by, along it.
  static const double wander = 0.05;
  static const double wave = 64;
  static const double ripple = 27;

  /// The Z-line: how many tongues of the stomach's mucosa reach up into
  /// the esophagus's, and how far.
  static const int tongues = 5;
  static const double tongue = 2.6;

  /// Its glands in its submucosa: about how far apart along it, how much
  /// more or less, and how big.
  static const double glandApart = 8;
  static const double glandJitter = 3;
  static const double gland = 0.45;

  // What runs on beside it, cut short.

  /// The pharynx above it, the laryngopharynx widening up from the
  /// cricopharyngeus; and the stomach below, the cardia, past where the
  /// esophagus is cut open; each cut short.
  static const AnatomyTube pharynx = AnatomyTube(
    <Offset>[
      Offset(0, 3),
      Offset(-0.5, -6),
      Offset(-1, -15),
      Offset(-1.5, -24),
    ],
    <double>[8.5, 10.5, 12.8, 14.5],
    cutEnd: true,
  );
  static const AnatomyTube stomach = AnatomyTube(
    <Offset>[
      Offset(28.4, 246.6),
      Offset(33.6, 255.1),
      Offset(38.9, 263.6),
      Offset(44.2, 272.0),
    ],
    <double>[13.5, 17.2, 20, 22],
    cutEnd: true,
  );

  /// The aorta, from behind the diaphragm, where it runs on down, up the
  /// esophagus's left side behind it and beside it to the end of its arch,
  /// cut where the arch crosses in front of it.
  static const AnatomyTube aorta = AnatomyTube(
    <Offset>[
      Offset(2, 288),
      Offset(3, 270),
      Offset(6, 250),
      Offset(10, 230),
      Offset(16, 210),
      Offset(21, 190),
      Offset(24, 170),
      Offset(25, 150),
      Offset(27, 130),
      Offset(31, 112),
      Offset(32, 98),
      Offset(27, 88),
      Offset(19, 85),
      Offset(13, 89),
    ],
    <double>[
      12.2, 12.2, 12.2, 12.2, 12.2, 12.2, 12.3, 12.3, 12.4, 12.6, 12.9, 13, //
      13, 13,
    ],
    fadeIn: 24,
    cutEnd: true,
  );

  /// The diaphragm either side of the hiatus, each from under the
  /// esophagus out to where it is cut short: its right half rising toward
  /// its higher dome, its left half lower.
  static const List<AnatomyTube> diaphragm = <AnatomyTube>[
    AnatomyTube(
      <Offset>[
        Offset(12, 236),
        Offset(4, 231),
        Offset(-6, 223),
        Offset(-17, 213),
      ],
      <double>[3.5, 3.5, 3.5, 3.5],
      cutEnd: true,
    ),
    AnatomyTube(
      <Offset>[
        Offset(27, 229),
        Offset(33, 227.9),
        Offset(38.5, 227.1),
        Offset(43, 226.7),
      ],
      <double>[3.5, 3.5, 3.5, 3.5],
      cutEnd: true,
    ),
  ];

  // Where the parts are named, those not named on its course or its wall.

  static const Offset pharynxName = Offset(-1, -15);
  static const Offset archName = Offset(25, 85);
  static const Offset stomachName = Offset(40, 266);

  /// So far along it its parts and its sphincters are named.
  static const double cervicalName = 24;
  static const double thoracicName = 70;
  static const double abdominalName = 247;
  static const double upperSphincterName = 5;
  static const double lowerSphincterName = 222;
}
