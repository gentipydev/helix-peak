import 'dart:ui';

import '../../tube_course.dart';

/// The left parotid gland seen from the side, in place, as a dissection of
/// the face shows it with the skin and the fascia taken away, drawn from
/// general anatomy: in millimetres on a gland 60 mm from its upper pole to
/// its lower, the face to the left and the ear to the right. The origin is
/// the middle of the body's own outline of it, where the zoom goes in, and
/// about the gland's own; x runs back toward the ear, y down.
///
/// The gland lies on the side of the face below and in front of the ear,
/// reaching nearly to the zygomatic arch above and tapering below, past the
/// angle of the jaw; its front edge lies over the masseter, and a part of
/// it below the arch, the accessory part, is detached (Gray 1918). Its duct
/// leaves that edge and runs forward over the masseter, turning in at the
/// masseter's front edge to pierce the buccinator (Iwanaga et al. 2026).
/// The facial nerve's five branches, temporal, zygomatic, buccal, marginal
/// mandibular and cervical, leave the gland's front edge and its lower
/// pole: the temporal over the arch, the zygomatic crossing above the duct,
/// the buccal leaving below it and running along it, as it does in three
/// sides of four (Sagkriotis et al. 2026, Laryngoscope Investig
/// Otolaryngol 11). The superficial temporal vessels leave its upper border
/// in front of the ear (Nguyen et al. 2026). The submandibular gland lies
/// below the jaw, in front of its angle (Gray 1918).
///
/// Sizes keep to what is measured. The gland is 60 mm from pole to pole,
/// as the zoom's tissue table gives it and as its bounds put it, from just
/// below the arch to below the jaw's angle (Gray 1918); on ultrasound its
/// superficial lobe is a median 36 mm from front to back and 44 mm from
/// top to bottom, and the submandibular gland 35 by 23 mm (Fang et al.
/// 2019, Sci Rep 9:8885). From where it enters the gland to its bend round
/// the masseter's front edge the duct runs 35 ± 8 mm, its lumen 0.8 to 2
/// mm across (Avishai et al. 2022, Diagnostics 12:1868); at that edge it
/// lies just above the line from the tragus to the corner of the mouth in
/// 27 of 32 sides (Iwanaga et al. 2026, Sci Rep 16:11082). An accessory
/// gland, on a tenth of sides on CT, is a mean 15.8 by 5.0 mm and 10.5 mm
/// in front of the main gland (Ahn et al. 2017, PLoS One 12:e0184633). The
/// facial nerve's trunk is 2.5 mm across and its two divisions 2 and 1.4
/// (Khoa et al. 2019, Open Access Maced J Med Sci 7:4230); the branches
/// past them are drawn thinner. The superficial temporal artery is 1.88 mm
/// across at the arch, 10.9 mm in front of the tragus (Nguyen et al. 2026,
/// Surg Radiol Anat 48:221), and its vein a median 1.3 mm (Nokovitch et
/// al. 2021, Ann Chir Plast Esthet 66:250). The ear is 66 mm long and 28
/// wide, the mean of men's 67.1 by 29.2 and women's 64.5 by 27.3 (Cho et
/// al. 2025, J Korean Med Sci 40:e107).
///
/// No measure of the parotid's lobules was found: they are drawn about 3
/// mm across, as plates of the fresh gland show them.
abstract final class SalivaryAnatomy {
  /// How long the parotid is, pole to pole.
  static const double length = 60;

  /// The parotid's outline: from the top of its back edge, in front of the
  /// tragus, forward under the arch, down its front edge over the masseter
  /// to its lower pole, and up its back edge, under the ear's lobule and
  /// along the front of the ear.
  static const List<Offset> parotid = <Offset>[
    Offset(12.5, -29.0),
    Offset(7.0, -30.5),
    Offset(1.0, -31.0),
    Offset(-5.0, -30.5),
    Offset(-11.0, -29.0),
    Offset(-15.5, -26.5),
    Offset(-18.5, -22.5),
    Offset(-19.8, -17.5),
    Offset(-20.0, -12.0),
    Offset(-19.6, -6.0),
    Offset(-18.6, 0.0),
    Offset(-16.8, 6.0),
    Offset(-14.2, 12.0),
    Offset(-10.8, 17.5),
    Offset(-6.8, 22.5),
    Offset(-2.5, 27.0),
    Offset(2.0, 29.8),
    Offset(6.5, 30.4),
    Offset(10.0, 28.6),
    Offset(12.2, 24.8),
    Offset(14.0, 19.5),
    Offset(15.0, 13.0),
    Offset(16.8, 7.0),
    Offset(17.2, 1.0),
    Offset(16.2, -5.0),
    Offset(14.5, -10.0),
    Offset(13.8, -15.0),
    Offset(13.8, -20.5),
    Offset(13.6, -25.5),
  ];

  /// Where the duct enters the gland, under its front part.
  static const Offset hilum = Offset(-9.0, -13.0);

  /// The parotid duct, from under the gland's front edge forward over the
  /// masseter to its front edge, where it turns in toward the buccinator
  /// and goes out of view.
  static const AnatomyTube duct = AnatomyTube(
    <Offset>[
      Offset(-17.0, -14.6),
      Offset(-19.5, -14.2),
      Offset(-26.0, -12.2),
      Offset(-33.0, -10.0),
      Offset(-39.0, -8.0),
      Offset(-43.0, -6.6),
      Offset(-44.8, -5.9),
      Offset(-46.2, -4.9),
    ],
    <double>[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.95, 0.8],
    fadeOut: 3.5,
  );

  /// The accessory gland, above the duct: its middle, its length along the
  /// duct, and its width.
  static const Offset accessory = Offset(-37.9, -12.6);
  static const double accessoryLength = 15.8;
  static const double accessoryWidth = 5.0;

  /// The masseter's superficial part: from the arch's lower border, its
  /// back reaching the angle under the gland, its lower edge along the
  /// jaw's lower border and up its front edge.
  static const List<Offset> masseter = <Offset>[
    Offset(-45.0, -32.5),
    Offset(-22.0, -32.5),
    Offset(0.0, -32.5),
    Offset(1.0, -20.0),
    Offset(2.0, -5.0),
    Offset(3.0, 10.0),
    Offset(3.5, 20.0),
    Offset(2.5, 24.0),
    Offset(0.0, 26.5),
    Offset(-8.0, 27.5),
    Offset(-20.0, 27.5),
    Offset(-32.0, 26.0),
    Offset(-38.5, 24.0),
    Offset(-41.0, 16.0),
    Offset(-43.0, 6.0),
    Offset(-44.5, -5.0),
    Offset(-45.5, -16.0),
    Offset(-46.0, -26.0),
  ];

  /// The zygomatic arch above the gland, from its root in front of the ear
  /// forward to the cheekbone, its lower edge where the masseter hangs.
  static const AnatomyTube arch = AnatomyTube(
    <Offset>[
      Offset(13.0, -35.2),
      Offset(0.0, -35.5),
      Offset(-15.0, -35.8),
      Offset(-30.0, -36.2),
      Offset(-45.0, -37.2),
      Offset(-58.0, -38.6),
    ],
    <double>[2.6, 3.0, 3.0, 3.0, 3.4, 4.0],
    fadeIn: 3,
    fadeOut: 10,
  );

  /// The jaw's lower border, from its angle under the gland forward toward
  /// the chin.
  static const AnatomyTube mandible = AnatomyTube(
    <Offset>[
      Offset(2.5, 20.0),
      Offset(1.0, 24.5),
      Offset(-4.0, 26.2),
      Offset(-20.0, 26.2),
      Offset(-35.0, 25.6),
      Offset(-50.0, 24.8),
      Offset(-64.0, 24.4),
    ],
    <double>[2.4, 2.8, 3.0, 3.0, 3.0, 3.0, 3.0],
    fadeOut: 12,
  );

  /// The submandibular gland below the jaw, in front of its angle, its top
  /// under the jaw's border.
  static const List<Offset> submandibular = <Offset>[
    Offset(-35.0, 27.0),
    Offset(-26.0, 26.0),
    Offset(-16.0, 26.5),
    Offset(-8.0, 28.5),
    Offset(-5.0, 32.5),
    Offset(-5.5, 38.0),
    Offset(-8.5, 43.5),
    Offset(-14.0, 47.5),
    Offset(-22.0, 49.4),
    Offset(-30.0, 48.5),
    Offset(-36.5, 45.0),
    Offset(-39.5, 38.5),
    Offset(-39.0, 30.0),
  ];

  /// The ear: from the root of the helix down in front of the gland's upper
  /// part, up round the helix, down its back to the lobule and up the front
  /// past the tragus.
  static const List<Offset> ear = <Offset>[
    Offset(15.5, -30.0),
    Offset(15.8, -37.5),
    Offset(17.5, -45.0),
    Offset(21.0, -51.0),
    Offset(26.0, -55.0),
    Offset(32.0, -56.0),
    Offset(37.5, -54.5),
    Offset(41.5, -50.0),
    Offset(43.8, -43.5),
    Offset(44.5, -35.5),
    Offset(43.8, -27.0),
    Offset(41.8, -19.0),
    Offset(38.8, -11.5),
    Offset(35.0, -4.5),
    Offset(31.5, 1.5),
    Offset(29.0, 6.5),
    Offset(26.5, 10.0),
    Offset(23.0, 11.0),
    Offset(20.2, 8.8),
    Offset(18.8, 4.5),
    Offset(18.6, -0.5),
    Offset(18.2, -6.0),
    Offset(16.8, -10.5),
    Offset(16.8, -15.5),
    Offset(15.4, -18.5),
    Offset(15.2, -24.0),
  ];

  /// The concha, the bowl in the ear, and the opening of its canal behind
  /// the tragus: its middle and its two radii.
  static const List<Offset> concha = <Offset>[
    Offset(20.5, -29.0),
    Offset(25.0, -34.0),
    Offset(30.5, -33.0),
    Offset(33.5, -27.0),
    Offset(33.0, -19.0),
    Offset(30.0, -12.5),
    Offset(25.0, -10.5),
    Offset(21.5, -13.0),
    Offset(20.0, -18.5),
    Offset(19.8, -24.0),
  ];
  static const Offset meatus = Offset(21.5, -20.5);
  static const (double, double) meatusRadii = (2.2, 3.0);

  /// The groove inside the rim of the helix, round the ear's back.
  static const List<Offset> scapha = <Offset>[
    Offset(21.5, -46.0),
    Offset(26.0, -50.5),
    Offset(32.0, -51.0),
    Offset(37.0, -47.5),
    Offset(39.5, -40.0),
    Offset(40.0, -31.0),
    Offset(38.5, -21.0),
    Offset(35.5, -11.0),
    Offset(31.5, -3.0),
  ];

  /// The facial nerve's branches, each from under the gland's edge: the
  /// temporal up over the arch, two zygomatic toward the eye above the duct,
  /// the buccal below the duct and along it, the marginal mandibular along
  /// the jaw's lower border, and the cervical down into the neck.
  static const List<AnatomyTube> nerves = <AnatomyTube>[
    AnatomyTube(
      <Offset>[
        Offset(-13.0, -27.0),
        Offset(-16.5, -31.0),
        Offset(-20.0, -36.0),
        Offset(-24.0, -42.0),
        Offset(-28.0, -48.0),
        Offset(-31.0, -54.0),
      ],
      <double>[0.5, 0.48, 0.45, 0.42, 0.4, 0.38],
      fadeOut: 10,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-16.5, -23.5),
        Offset(-21.0, -25.5),
        Offset(-28.0, -28.0),
        Offset(-36.0, -30.5),
        Offset(-44.0, -32.0),
        Offset(-52.0, -33.0),
      ],
      <double>[0.5, 0.48, 0.45, 0.42, 0.4, 0.38],
      fadeOut: 10,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-18.5, -19.5),
        Offset(-25.0, -20.0),
        Offset(-33.0, -19.8),
        Offset(-41.0, -19.0),
        Offset(-49.0, -18.0),
        Offset(-57.0, -17.0),
      ],
      <double>[0.5, 0.48, 0.45, 0.42, 0.4, 0.38],
      fadeOut: 10,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-17.5, -9.5),
        Offset(-24.0, -8.8),
        Offset(-31.0, -6.8),
        Offset(-38.0, -4.6),
        Offset(-46.0, -1.8),
        Offset(-55.0, 0.8),
      ],
      <double>[0.5, 0.48, 0.45, 0.42, 0.4, 0.38],
      fadeOut: 10,
    ),
    AnatomyTube(
      <Offset>[
        Offset(-11.5, 13.0),
        Offset(-15.5, 17.5),
        Offset(-21.0, 21.5),
        Offset(-28.0, 24.5),
        Offset(-38.0, 25.0),
        Offset(-47.0, 24.0),
        Offset(-56.0, 22.6),
      ],
      <double>[0.5, 0.48, 0.46, 0.44, 0.42, 0.4, 0.38],
      fadeOut: 10,
    ),
    AnatomyTube(
      <Offset>[
        Offset(1.5, 27.5),
        Offset(2.0, 33.5),
        Offset(1.5, 40.0),
        Offset(0.5, 48.0),
        Offset(-0.5, 56.0),
      ],
      <double>[0.5, 0.48, 0.45, 0.42, 0.4],
      fadeOut: 10,
    ),
  ];

  /// The superficial temporal artery, out of the gland's upper border, up
  /// over the arch in front of the ear; its vein just behind it.
  static const AnatomyTube artery = AnatomyTube(
    <Offset>[
      Offset(4.8, -27.0),
      Offset(4.6, -31.0),
      Offset(4.2, -36.0),
      Offset(4.8, -42.0),
      Offset(3.6, -48.0),
      Offset(4.5, -54.0),
      Offset(3.2, -60.0),
    ],
    <double>[0.94, 0.94, 0.94, 0.92, 0.9, 0.88, 0.86],
    fadeOut: 12,
  );
  static const AnatomyTube vein = AnatomyTube(
    <Offset>[
      Offset(7.6, -27.0),
      Offset(7.7, -31.0),
      Offset(7.9, -36.0),
      Offset(8.8, -42.0),
      Offset(8.2, -48.0),
      Offset(9.4, -55.0),
    ],
    <double>[0.65, 0.65, 0.65, 0.65, 0.65, 0.65],
    fadeOut: 12,
  );

  /// Where each part is named.
  static const Offset ductName = Offset(-31.0, -10.6);
  static const Offset nerveName = Offset(-40.0, -3.9);
  static const Offset submandibularName = Offset(-22.0, 40.0);
}
