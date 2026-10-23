import 'dart:ui';

/// A block cut from the skin of the left leg, 2 cm below the knee on its
/// inner side, where the zoom goes into the skin, drawn from general
/// anatomy in millimetres: x across the block's front face from its left
/// edge, y down from the skin's surface, z back into the block from the
/// front face. Its front face is the cut, flat to the view, with every
/// layer and what lies in them; its top is the skin's surface; its right
/// side is a second cut, seen in shade.
///
/// What is measured:
/// - GTEx takes the skin it reads as sun-exposed from the "left or right
///   leg 2 cm below patella on medial side" (the GTEx Portal's sampling
///   site for Skin - Sun Exposed (Lower leg), gtex_v10).
/// - On histology in 71 adults, the stratum corneum is 18.3, 11.0 and
///   14.9 µm thick and the cellular epidermis 56.6, 70.3 and 81.5 µm at the
///   forearm, the shoulder and the buttock (Sandby-Møller et al. 2003, Acta
///   Derm Venereol 83:410); 76.5 µm of epidermis, pooled over the studies
///   off the palms and soles (Xu et al. 2017, J Am Acad Dermatol 77:1133).
/// - On 50 MHz ultrasound of the calf in 74 adults, the left leg's dermis is
///   1.72 mm thick and its whole skin 1.83 mm, the right's 1.80 and 1.90
///   (Wang et al. 2025, Quant Imaging Med Surg 15:5218).
/// - After Gray (1918, the twentieth edition, pp. 1060–1070, read in the
///   Internet Archive's copy): the surface is marked by a network of linear
///   furrows dividing it into polygonal or lozenge-shaped areas; the dermis
///   is thicker on the lateral than on the medial sides of the limbs; its
///   papillae are, on the general surface, few and exceedingly minute, each
///   with a capillary loop; its reticular layer is of strong interlacing
///   bands, coarse toward the fat, between which lie fat and sweat glands;
///   a long hair's follicle reaches into the subcutaneous tissue, obliquely,
///   dilated at its deep end into the bulb over its papilla, its outer root
///   sheath continuous with the epidermis, and the ducts of its sebaceous
///   glands open into it near its free end; some cells of the bulb hold the
///   pigment that colours the hair; the arrectores pilorum arise from the
///   superficial layer of the corium and are inserted into the follicle
///   below the sebaceous duct, on the side toward which the hair slopes,
///   and the sebaceous gland lies in the angle the muscle makes with the
///   follicle's superficial part; a sebaceous gland is a cluster of two to
///   five flask-shaped alveoli; a sweat gland is a single tube whose deep
///   part is rolled into a ball, in a pit on the under surface of the corium
///   or, more often, in the subcutaneous fat, its duct convoluted in the
///   deeper corium, straight in the superficial, opening by a funnel-shaped
///   pore; there are 60 to 80 of them to the square centimetre on the leg;
///   Pacinian corpuscles lie on the nerves of the palm, the sole and the
///   genitals, so none is drawn here.
/// - Eccrine sweat glands number 57 to the square centimetre on the leg,
///   each coil about 3.5 mm of tube about 40 µm across (Taylor and
///   Machado-Moreira 2013, Extrem Physiol Med 2:4).
/// - The skin's vessels form two horizontal plexuses, one 1–1.5 mm below the
///   surface and one at the junction of the dermis and the fat, joined by
///   paired ascending arterioles and descending venules; the upper sends up
///   the papillary loops (Braverman 1997, Microcirculation 4:329).
/// - Melanocytes lie in the epidermis's basal layer, 955 to the square
///   millimetre pooled (Xu et al. 2017), and in the hair bulb, where they
///   pass their melanin to the hair's cortex (Slominski et al. 2005, J
///   Invest Dermatol 124:13).
/// - The calf has the fewest hair follicles of seven sites measured
///   (Otberg et al. 2004, J Invest Dermatol 122:14).
///
/// Drawing choices, measured by none of these: the block, 3 mm across and 2.2
/// deep, and how its top is foreshortened; the fat cut 2.6 mm below the dermis;
/// the papillary dermis's depth; the rete ridges' depth and how far apart they
/// lie; the upper plexus 1 mm down, Braverman's shallowest, for skin this thin;
/// the follicle's slope, breadth and sheaths, its bulb just into the fat, its
/// shaft; one more follicle cut through obliquely beside it; three alveoli to
/// its sebaceous gland; the muscle's breadth; where the two coils lie and how
/// large they are, a ball that holds Taylor's tube; where the vessels and the
/// nerve lie and how large they are; the fat's lobules; the furrows' pattern;
/// two hairs on the top as well as the one cut, each drawn 1.2 mm long and
/// fading, where a leg's hair is longer.
abstract final class SkinAnatomy {
  // The block.

  /// How wide its front face is, and how far back into the skin its top
  /// and its side reach.
  static const double width = 3;
  static const double depth = 2.2;

  // The layers, down from the surface.

  /// The stratum corneum, and the whole epidermis with it.
  static const double corneum = 0.015;
  static const double epidermis = 0.085;

  /// The whole skin, the epidermis and the dermis, on the left leg.
  static const double skin = 1.83;

  /// How deep the papillary dermis reaches under the epidermis's ridges.
  static const double papillary = 0.2;

  /// The rete ridges: how far each reaches down into the dermis below the
  /// epidermis's mean floor, and how far apart they lie.
  static const double ridgeDepth = 0.025;
  static const double ridgeSpacing = 0.11;

  /// How much of the fat under the dermis the block keeps.
  static const double fat = 2.6;

  /// How deep the block's front face reaches.
  static const double faceDepth = skin + fat;

  // The vessels.

  /// How far below the surface the upper plexus lies; the lower lies where
  /// the dermis meets the fat.
  static const double upperPlexus = 1;

  /// The cut vessels of each plexus: across the face, and each one's
  /// radius.
  static const List<(double, double)> upperVessels = <(double, double)>[
    (0.2, 0.018),
    (0.72, 0.014),
    (1.02, 0.02),
    (1.86, 0.016),
    (2.38, 0.022),
    (2.86, 0.017),
  ];
  static const List<(double, double)> lowerVessels = <(double, double)>[
    (0.18, 0.04),
    (1.36, 0.055),
    (1.76, 0.035),
    (2.4, 0.05),
    (2.88, 0.045),
  ];

  /// The ascending arteriole and the descending venule that join the two,
  /// across the face, with their radii.
  static const (double, double) arteriole = (2.12, 0.016);
  static const (double, double) venule = (2.2, 0.022);

  /// Vessels cut in the fat's septa: where each lies and its radius.
  static const List<(Offset, double)> septalVessels = <(Offset, double)>[
    (Offset(1.1, 2.7), 0.05),
    (Offset(2.2, 3.6), 0.045),
    (Offset(0.55, 3.8), 0.04),
  ];

  /// A nerve cut across in a septum, and its radius.
  static const Offset nerve = Offset(1.6, 3.1);
  static const double nerveRadius = 0.07;

  // The follicle cut along its length.

  /// Where it opens on the surface, how far it slopes from the surface,
  /// its sheaths' breadth, and how deep its bulb's middle lies.
  static const double opening = 2.1;
  static const double slope = 60;
  static const double follicleBreadth = 0.15;
  static const double bulbDepth = 2;

  /// Its bulb's breadth and length, its papilla's breadth and height; the
  /// hair's shaft; the funnel it opens by, how deep and how wide at the
  /// surface.
  static const double bulbBreadth = 0.26;
  static const double bulbLength = 0.3;
  static const double papillaBreadth = 0.09;
  static const double papillaHeight = 0.13;
  static const double shaft = 0.05;
  static const double funnelDepth = 0.12;
  static const double funnelWidth = 0.22;

  /// Its sebaceous gland's alveoli, down the follicle from its opening:
  /// how far along each lies, and its radius at most, each as large as the
  /// angle between the follicle and the muscle leaves room for; and where
  /// its duct enters.
  static const List<(double, double)> alveoli = <(double, double)>[
    (0.26, 0.11),
    (0.42, 0.11),
    (0.58, 0.1),
  ];
  static const double ductAlong = 0.22;

  /// The arrector pili: how far down the follicle it is inserted, and
  /// where it arises in the papillary dermis; its breadth there and at its
  /// insertion.
  static const double insertionAlong = 1.2;
  static const Offset origin = Offset(2.78, 0.15);
  static const double muscleOrigin = 0.1;
  static const double muscleInsertion = 0.06;

  // The follicle cut through obliquely.

  /// Its bulb's middle, how far its sheaths are seen rising from it before
  /// they leave the cut, and which way.
  static const Offset otherBulb = Offset(2.55, 2.28);
  static const double otherShown = 0.45;
  static const double otherSlope = 60;

  // The sweat glands.

  /// Each coil's middle, its breadth and height, and where its duct opens
  /// on the surface: one in a pit under the dermis, one in the fat.
  static const List<(Offset, double, double, double)> coils =
      <(Offset, double, double, double)>[
        (Offset(2.5, 1.62), 0.28, 0.2, 2.92),
        (Offset(0.4, 2.55), 0.3, 0.22, 0.5),
      ];

  /// The duct's breadth.
  static const double duct = 0.03;

  // The surface.

  /// Hairs on the top, besides the one cut: where each leaves the surface,
  /// across and back.
  static const List<Offset> hairs = <Offset>[
    Offset(0.6, 1.1),
    Offset(2.4, 1.7),
  ];

  /// How long a hair is drawn above the surface.
  static const double hairShown = 1.2;

  /// The sweat pores on the top, across and back: about 57 to the square
  /// centimetre, four on its 6.6 square millimetres.
  static const List<Offset> pores = <Offset>[
    Offset(0.4, 0.45),
    Offset(1.4, 0.35),
    Offset(2.6, 0.9),
    Offset(1.2, 1.8),
  ];

  /// Where in the front face its tissue is sampled: a third of the way
  /// across, in the epidermis.
  static const Offset site = Offset(width / 3, 0.05);
}
