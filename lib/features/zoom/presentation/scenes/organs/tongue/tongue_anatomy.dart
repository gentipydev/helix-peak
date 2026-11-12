import 'dart:ui';

/// The tongue cut across at the lower first molars, seen from the front in
/// place between the two halves of its mandible, the upper jaw taken away
/// and what lies below the mylohyoid with it, as Gray draws the tongue's
/// muscles cut across (Gray 1918, Fig. 1020, "Coronal section of tongue,
/// showing intrinsic muscles", altered from Krause), widened to the jaw: in
/// millimetres, x from the midline toward the body's left, which from the
/// front is the screen's right, y down from the middle of the tongue's
/// back. The two sides are one another's mirror; every list here is the
/// body's left half, and a side's parts are mirrored for the right.
///
/// What is measured. After Gray (1918, Fig. 1020 and the text of the
/// tongue's muscles beside it): under the mucous membrane of the tongue's
/// back the superior longitudinal fibres run its length, cut across here;
/// the transverse fibres run from the median septum out to the margins,
/// where they insert into the mucous membrane; the vertical fibres run from
/// the back down toward the underside, and the genioglossus's fibres rise
/// from below either side of the septum, fanning up through the transverse
/// fibres to the back; the inferior longitudinal lies on the underside
/// between the genioglossus and the hyoglossus, with the styloglossus
/// outside the hyoglossus at the margin, and the lingual artery lies
/// between the genioglossus and the inferior longitudinal. The back's
/// filiform papillae stand as a fine comb over it, a fungiform papilla here
/// and there. The tongue's muscles interweave in three directions, which
/// thick coronal sections show (Sanders and Mu 2013, Anat Rec 296:1102).
/// At the molars the inferior alveolar nerve's canal lies most often in the
/// lingual third of the mandible's body and in its lower half (Balel,
/// Coşkun and Kaplan 2025, BMC Oral Health 25:1813, on CBCT).
///
/// Drawing choices, measured by none of these: the plane, through the
/// mesial roots of the first molars, where the sublingual glands lie on
/// either side above the mylohyoid; the tongue 43 mm across at rest, its
/// margins resting on the molars' lingual cusps, its back a low dome with
/// the median sulcus a shallow dip; the mucous membrane 1.1 mm thick over
/// the back and 0.7 at the sides, the lingual aponeurosis under it; the
/// superior longitudinal layer 2.6 mm thick at the middle, thinning out to
/// the margins; nine transverse sheets and the vertical fibres between
/// them, the inferior longitudinal a bundle 4.6 by 3.5 mm; the
/// genioglossus 8 mm across a side where it enters the tongue, the
/// geniohyoid 6.3 by 5.8 mm, the mylohyoid 3.2 mm thick; the sublingual
/// gland 6 by 8 mm cut across, the sulcus between the tongue and the
/// alveolar mucosa a narrow cleft; the deep lingual artery 1.9 mm across
/// and its vein 2.3 mm, the lingual and hypoglossal nerves 2.1 and 2 mm,
/// the submandibular duct 2.2 mm; the mandible's body 28 mm high from its
/// crest and 13.6 mm thick, its cortex 1.2 to 3 mm, its canal 2.8 mm; the
/// molar's crown 10.7 mm across and 7.5 mm high, its mesial root 13.5 mm
/// long with its two canals; the gingiva 1 mm over the crest; the place
/// the body goes in, in the transverse fibres on the body's right, between
/// the superior longitudinal layer and the inferior longitudinal.
abstract final class TongueAnatomy {
  /// Where the zoom goes into the tongue: in its transverse fibres, on the
  /// body's right.
  static const Offset site = Offset(-7.2, 8.6);

  // The tongue.

  /// The tongue's free surface, from the middle of its back out to its
  /// margin, over the molar's lingual cusp, down the crown's lingual face
  /// and along its underside to where it meets the floor of the mouth: the
  /// median sulcus a dip at its start.
  static const List<Offset> surface = <Offset>[
    Offset(0, 0.55),
    Offset(1.5, 0.08),
    Offset(5, 0.18),
    Offset(10, 0.72),
    Offset(14, 1.6),
    Offset(17.3, 2.85),
    Offset(19.8, 4.25),
    Offset(21.3, 5.4),
    Offset(21.65, 6.15),
    Offset(21.25, 6.85),
    Offset(20.5, 7.05),
    Offset(19.85, 7.1),
    Offset(19.3, 8.3),
    Offset(18.75, 9.4),
    Offset(18.3, 10.5),
    Offset(17.65, 12.0),
    Offset(17.05, 13.9),
    Offset(16.15, 15.8),
    Offset(14.9, 17.4),
    Offset(13.6, 18.4),
  ];

  /// How many of [surface]'s knots are the tongue's back and margin, which
  /// the papillae stand on; and where its side meets the molar's crown.
  static const int back = 9;
  static const int crown = 14;

  /// The soft tissue between the two halves of the mandible, the outline
  /// the step from the body draws in to: the tongue's back and margin as
  /// [surface], then the crown's lingual face, the mandible's lingual face
  /// down to the mylohyoid line, and the mylohyoid's lower face across to
  /// the midline.
  static const List<Offset> soft = <Offset>[
    Offset(0, 0.55),
    Offset(1.5, 0.08),
    Offset(5, 0.18),
    Offset(10, 0.72),
    Offset(14, 1.6),
    Offset(17.3, 2.85),
    Offset(19.8, 4.25),
    Offset(21.3, 5.4),
    Offset(21.65, 6.15),
    Offset(21.25, 6.85),
    Offset(20.5, 7.05),
    Offset(19.85, 7.1),
    Offset(19.3, 8.3),
    Offset(18.75, 9.4),
    Offset(18.3, 10.5),
    Offset(18.35, 12.4),
    Offset(18.85, 14.6),
    Offset(18.55, 15.8),
    Offset(18.25, 17.0),
    Offset(17.85, 20.5),
    Offset(17.4, 24.0),
    Offset(17.05, 27.0),
    Offset(17.25, 29.9),
    Offset(15.2, 31.6),
    Offset(12.0, 34.0),
    Offset(8.0, 36.5),
    Offset(4.0, 38.2),
    Offset(0, 38.8),
  ];

  /// The mucous membrane's thickness over the back and at the sides, and
  /// the lingual aponeurosis's under it.
  static const double mucosaBack = 1.1;
  static const double mucosaSide = 0.7;
  static const double aponeurosis = 0.5;

  /// The superior longitudinal layer's thickness at the middle, and how far
  /// out it keeps to that before thinning away at the margin.
  static const double superior = 2.6;
  static const double superiorKeeps = 12;
  static const double superiorEnds = 20.5;

  /// The filiform papillae: how far apart along the back, how tall and how
  /// wide at their feet, and how far from the margin they stand; the
  /// fungiform papillae, where on the back, how tall and how wide.
  static const double filiformPitch = 0.8;
  static const double filiformHeight = 0.8;
  static const double filiformFoot = 0.48;
  static const double filiformFrom = 1.2;
  static const double filiformTo = 20.4;
  static const double fungiformAt = 11.2;
  static const double fungiformHeight = 0.9;
  static const double fungiformWidth = 1.1;

  /// The genioglossus where it enters the tongue, across the midline, down
  /// to the geniohyoid: its body's half.
  static const List<Offset> genioglossus = <Offset>[
    Offset(0, 15.55),
    Offset(4.0, 15.6),
    Offset(7.7, 15.95),
    Offset(7.3, 18.6),
    Offset(6.55, 22.4),
    Offset(5.65, 26.0),
    Offset(4.85, 28.25),
    Offset(2.8, 28.7),
    Offset(0, 28.8),
  ];

  /// The intrinsic muscle's lower edge, from the hyoglossus's foot in to
  /// the genioglossus: above the deep lingual vessels, round the inferior
  /// longitudinal.
  static const List<Offset> intrinsicFloor = <Offset>[
    Offset(12.6, 16.3),
    Offset(11.4, 16.05),
    Offset(9.7, 15.6),
    Offset(7.9, 16.0),
    Offset(4.0, 15.75),
    Offset(0, 15.7),
  ];

  /// The inferior longitudinal, cut across: its middle and half-widths.
  static const Offset inferior = Offset(11.15, 13.5);
  static const Size inferiorHalf = Size(2.3, 1.75);

  /// The hyoglossus and the styloglossus along the underside at the margin,
  /// from the side's foot to the floor: how far in from the surface, how
  /// thick together, and over which share of the underside they run.
  static const double sheetIn = 0.7;
  static const double sheet = 1.8;
  static const double sheetFrom = 0.08;
  static const double sheetTo = 0.92;

  /// The transverse fibres: how many sheets, from how far below the
  /// superior longitudinal layer at the septum to how deep, and the heights
  /// at the margin they insert at.
  static const int transverse = 9;
  static const double transverseTop = 0.7;
  static const double transverseBottom = 14.4;
  static const double insertTop = 5.4;
  static const double insertBottom = 11.4;

  /// The vertical fibres: from how far out to how far, how far apart, and
  /// how much the outermost bow out at their feet.
  static const double verticalFrom = 9.2;
  static const double verticalTo = 16.4;
  static const double verticalPitch = 1.5;
  static const double verticalBow = 0.9;

  /// The genioglossus's fibres: how many, and where they spread from below
  /// and to above.
  static const int genioFibres = 10;
  static const double genioFoot = 28.4;
  static const double genioFootTo = 4.4;
  static const double genioEntryTo = 7.5;
  static const double genioTopTo = 11.0;

  /// How far below the back the septum begins, and its thickness.
  static const double septumFrom = 2.0;
  static const double septum = 0.45;

  // The floor of the mouth.

  /// The geniohyoid, cut across, either side of the midline: its middle and
  /// half-widths.
  static const Offset geniohyoid = Offset(3.55, 32.0);
  static const Size geniohyoidHalf = Size(3.15, 2.9);

  /// The mylohyoid, from the midline out to the mylohyoid line: its upper
  /// face and its lower.
  static const List<Offset> mylohyoidUpper = <Offset>[
    Offset(0, 35.6),
    Offset(3.8, 35.0),
    Offset(7.6, 33.3),
    Offset(11.5, 30.8),
    Offset(14.8, 28.45),
    Offset(17.05, 27.0),
  ];
  static const List<Offset> mylohyoidLower = <Offset>[
    Offset(0, 38.8),
    Offset(4.0, 38.2),
    Offset(8.0, 36.5),
    Offset(12.0, 34.0),
    Offset(15.2, 31.6),
    Offset(17.25, 29.9),
  ];

  /// The sublingual gland, cut across, on the mylohyoid against the
  /// mandible under the sublingual fold.
  static const List<Offset> gland = <Offset>[
    Offset(16.7, 20.55),
    Offset(17.3, 22.5),
    Offset(17.1, 25.3),
    Offset(16.45, 27.05),
    Offset(14.6, 28.15),
    Offset(12.6, 27.4),
    Offset(11.4, 25.2),
    Offset(11.55, 22.6),
    Offset(12.75, 20.95),
    Offset(14.6, 20.25),
  ];

  /// How wide the gland's lobules are.
  static const double lobule = 1.5;

  /// The sulcus between the tongue's underside and the alveolar mucosa, a
  /// narrow cleft down to the floor of the mouth: down the tongue's side
  /// from the crown, along the floor and back up the alveolar mucosa.
  static const List<Offset> sulcus = <Offset>[
    Offset(18.3, 10.5),
    Offset(17.65, 12.0),
    Offset(17.05, 13.9),
    Offset(16.15, 15.8),
    Offset(14.9, 17.4),
    Offset(13.6, 18.4),
    Offset(14.6, 18.55),
    Offset(15.75, 18.6),
    Offset(16.55, 18.25),
    Offset(16.85, 17.2),
    Offset(17.25, 15.6),
    Offset(17.7, 13.8),
    Offset(18.1, 12.1),
  ];

  /// How many of [sulcus]'s knots are the tongue's underside.
  static const int sulcusTongue = 6;

  /// What runs along under the tongue and in the floor, cut across: each
  /// its middle and radius.
  static const (Offset, double) artery = (Offset(9.4, 17.3), 0.95);
  static const (Offset, double) vein = (Offset(12.9, 17.05), 1.15);
  static const (Offset, double) duct = (Offset(10.35, 19.85), 1.1);
  static const (Offset, double) lingualNerve = (Offset(9.6, 22.4), 1.05);
  static const (Offset, double) hypoglossal = (Offset(8.45, 25.6), 1.0);
  static const (Offset, double) comitans = (Offset(9.75, 26.45), 0.7);

  // The mandible and the molar.

  /// The mandible's body, cut across: from its lingual crest down its
  /// lingual face, along its lower border and up its buccal face to its
  /// buccal crest.
  static const List<Offset> bone = <Offset>[
    Offset(18.55, 15.8),
    Offset(18.25, 17.0),
    Offset(17.85, 20.5),
    Offset(17.4, 24.0),
    Offset(17.05, 27.0),
    Offset(17.25, 29.9),
    Offset(17.85, 33.0),
    Offset(18.8, 36.8),
    Offset(20.1, 40.2),
    Offset(22.0, 42.8),
    Offset(24.6, 43.9),
    Offset(27.4, 43.8),
    Offset(29.6, 42.6),
    Offset(31.0, 40.0),
    Offset(31.7, 36.0),
    Offset(31.8, 31.0),
    Offset(31.3, 25.5),
    Offset(30.2, 20.8),
    Offset(29.3, 17.6),
    Offset(28.95, 16.0),
    Offset(23.7, 15.6),
  ];

  /// The spongy bone inside its cortex, the root's socket in its top.
  static const List<Offset> cancellous = <Offset>[
    Offset(19.4, 17.3),
    Offset(19.0, 20.5),
    Offset(18.75, 24.0),
    Offset(18.6, 27.2),
    Offset(18.85, 30.0),
    Offset(19.4, 33.0),
    Offset(20.3, 36.4),
    Offset(21.6, 39.0),
    Offset(23.2, 40.4),
    Offset(25.3, 40.9),
    Offset(27.3, 40.7),
    Offset(28.8, 39.6),
    Offset(29.8, 37.4),
    Offset(30.2, 33.5),
    Offset(30.25, 30.0),
    Offset(29.85, 25.5),
    Offset(28.95, 21.3),
    Offset(28.0, 18.0),
    Offset(27.6, 16.9),
    Offset(23.6, 16.6),
  ];

  /// How far apart the trabeculae's spaces are.
  static const double trabecula = 1.15;

  /// The inferior alveolar canal, its middle and radius, and in it the
  /// nerve, the artery and the vein.
  static const (Offset, double) canal = (Offset(21.6, 35.2), 1.4);
  static const (Offset, double) alveolarNerve = (Offset(21.75, 35.55), 0.85);
  static const (Offset, double) alveolarArtery = (Offset(21.95, 34.35), 0.3);
  static const (Offset, double) alveolarVein = (Offset(20.95, 34.75), 0.4);

  /// The molar's crown, from its lingual cemento-enamel junction up its
  /// lingual face, over its cusps and down its buccal face.
  static const List<Offset> crownOutline = <Offset>[
    Offset(18.85, 14.6),
    Offset(18.35, 12.4),
    Offset(18.3, 10.5),
    Offset(18.75, 9.4),
    Offset(19.3, 8.3),
    Offset(19.85, 7.05),
    Offset(20.9, 7.25),
    Offset(22.1, 8.4),
    Offset(23.7, 9.2),
    Offset(25.2, 8.2),
    Offset(26.3, 7.45),
    Offset(27.2, 7.5),
    Offset(28.3, 8.6),
    Offset(28.95, 10.4),
    Offset(29.05, 11.7),
    Offset(28.85, 13.4),
    Offset(28.55, 14.9),
  ];

  /// The dentine under the enamel, from junction to junction.
  static const List<Offset> enamelFloor = <Offset>[
    Offset(18.9, 14.6),
    Offset(19.15, 12.3),
    Offset(19.45, 10.6),
    Offset(20.3, 9.2),
    Offset(21.25, 9.3),
    Offset(22.3, 10.2),
    Offset(23.7, 10.75),
    Offset(25.0, 10.0),
    Offset(26.5, 9.3),
    Offset(27.5, 10.4),
    Offset(27.95, 11.8),
    Offset(28.2, 13.5),
    Offset(28.5, 14.9),
  ];

  /// The mesial root, from the buccal junction down to its apex and back up
  /// to the lingual.
  static const List<Offset> root = <Offset>[
    Offset(28.55, 14.9),
    Offset(28.2, 16.6),
    Offset(27.3, 20.5),
    Offset(26.0, 24.6),
    Offset(24.4, 27.4),
    Offset(23.2, 28.1),
    Offset(22.05, 27.3),
    Offset(20.65, 24.5),
    Offset(19.55, 20.5),
    Offset(18.95, 16.5),
    Offset(18.85, 14.6),
  ];

  /// The pulp chamber, its horns under the cusps, and the root's two
  /// canals from its floor to the apex.
  static const List<Offset> pulp = <Offset>[
    Offset(20.55, 12.6),
    Offset(20.95, 11.1),
    Offset(21.6, 12.0),
    Offset(23.6, 12.5),
    Offset(25.5, 11.95),
    Offset(26.1, 10.95),
    Offset(26.55, 12.6),
    Offset(26.4, 15.4),
    Offset(25.6, 16.4),
    Offset(23.6, 15.9),
    Offset(21.6, 16.4),
    Offset(20.75, 15.4),
  ];
  static const List<List<Offset>> canals = <List<Offset>>[
    <Offset>[
      Offset(21.6, 16.0),
      Offset(22.0, 20.5),
      Offset(22.5, 24.5),
      Offset(22.95, 27.5),
    ],
    <Offset>[
      Offset(25.6, 16.0),
      Offset(25.15, 20.5),
      Offset(24.4, 24.5),
      Offset(23.5, 27.5),
    ],
  ];

  /// How wide a canal is at the chamber and at the apex.
  static const double canalWide = 0.7;
  static const double canalNarrow = 0.25;

  /// The buccal gingiva, over the crest and down the bone's buccal face,
  /// cut short where the cheek was taken away.
  static const List<Offset> buccalGingiva = <Offset>[
    Offset(28.7, 13.75),
    Offset(28.6, 14.9),
    Offset(28.95, 16.0),
    Offset(29.3, 17.6),
    Offset(29.85, 19.6),
    Offset(30.45, 19.45),
    Offset(30.0, 17.3),
    Offset(29.55, 15.3),
    Offset(29.15, 14.0),
  ];

  // Where the parts are named.

  /// The genioglossus on the body's left, the hyoglossus on its right; the
  /// sublingual gland on its left, the mylohyoid on its right, and the
  /// mandible on its left, high in its buccal cortex: three names above it,
  /// three below.
  static const Offset genioglossusName = Offset(3.6, 22.5);
  static const Offset hyoglossusName = Offset(-15.75, 12.4);
  static const Offset glandName = Offset(14.3, 24.0);
  static const Offset mylohyoidName = Offset(-9.6, 33.4);
  static const Offset mandibleName = Offset(29.1, 19.0);
}
