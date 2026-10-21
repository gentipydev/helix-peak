/// Every number the bone marrow's look is tuned by, in one place. Lengths
/// are in millimetres of the real femur unless they say otherwise; the
/// anatomy itself is in `marrow_anatomy.dart`, and the light is the zoom's
/// one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, cut down its length, in deep tones that
/// stand out against the body's faint parts round it, as the old study's
/// dark shaft did (the user's ask of 2026-10-21: the bone had looked pale):
/// the marrow flat, the red marrow in the mark where the zoom's cell lives,
/// as the brain's cortex is, the yellow marrow in shade, both crossed by
/// the trabeculae of the spongy bone in the bone's own tone; the cortex a
/// cut face in a mid ivory, its outer edge lit as the bone's surface turns
/// away; the cartilage glassy over the head and the condyles; the growth
/// plates' scars fine lines; the nutrient artery in the blood red.
abstract final class MarrowStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// and how many the step from the body morphs round it by.
  static const int outlineSpan = 8;
  static const int morphPoints = 360;

  /// How far in from the femur's outline the flat shape is drawn as it
  /// becomes the bed the femur lies on.
  static const double bed = 0.6;

  /// How far down the femur, besides its ends, the step from the body meets
  /// the femur's outline and the body's on either side of the shaft.
  static const List<double> shaftMarks = <double>[0.3, 0.5, 0.7];

  /// Over which heights of the posed outline the shaft's lean is fitted to
  /// the body's outline of it.
  static const double leanFrom = -120;
  static const double leanTo = 130;

  /// How many times the cortex's thickness is evened out along the outline,
  /// so its runs meet without a step.
  static const int cortexSmoothing = 6;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  /// The red marrow: one flat tone, the mark over a neutral, as the brain's
  /// cortex is; the yellow marrow in shade, as the old study drew the
  /// shaft's cavity.
  static const double redLit = 0.2;
  static const double redMark = 0.42;
  static const double yellowShade = 0.62;

  static const double cortexLit = 0.55;
  static const double cartilageLit = 0.45;
  static const double cartilageAlpha = 0.85;
  static const double trabeculaLit = 0.55;
  static const double scarLit = 0.62;
  static const double canalShade = 0.3;
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The artery: blood eased toward the ground.
  static const double artery = 0.25;

  // The cut faces' light.

  /// How far a cut face's cushion tilts it at its edges, and how much it
  /// shines: less than a fresh surface, being cut.
  static const double cushion = 0.22;
  static const double cutSheen = 0.6;

  /// The cortex's outer edge, the bone's surface curving away: how far its
  /// middle and its edge turn from the eye, over how much of its thickness.
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;
  static const double rim = 0.35;

  // The trabeculae.

  /// Each level of them: L1, every fourth line of a group, always drawn;
  /// L2, every second, and L3, the rest, the true lattice, coming in as the
  /// view closes on the bone, over these densities in pixels a millimetre
  /// (a level's lines are about three pixels apart when it is half in).
  static const List<(double, double)> levelIn = <(double, double)>[
    (0, 0),
    (1.4, 6.5),
    (4.5, 21),
  ];

  /// Each level's least width, in pixels, and how strong it is.
  static const List<double> levelFloor = <double>[0.8, 0.7, 0.6];
  static const List<double> levelAlpha = <double>[0.5, 0.45, 0.4];

  /// How far apart the points a line is laid by are, how big a tile of
  /// them is, and how fine the mask they are kept inside the marrow by.
  static const double lineStep = 0.8;
  static const double tile = 20;
  static const double maskCell = 0.5;

  /// How far a line's start and end lie in from the wall they leave and the
  /// surface they meet, and how far along it its handles reach.
  static const double wallClear = 0.4;
  static const double leaveReach = 0.45;
  static const double arriveReach = 0.35;

  /// The lower end's central longitudinal lines, thin and delicate: how
  /// far from the cavity's middle they are, and how much fainter.
  static const double centralReach = 7;
  static const double centralAlpha = 0.5;

  /// The seed every irregularity of the lattice is drawn from, so it is the
  /// same every time.
  static const int seed = 83;

  /// How far a stream's place in its group strays from an even spacing, a
  /// share of the spacing; how far it wavers about its course, a share of
  /// the gap to its neighbour, over how long a wave.
  static const double streamJitter = 0.5;
  static const double waveAmp = 0.14;
  static const double waveLength = 6;

  /// The struts bracing each stream to its neighbour: every so many gaps
  /// along it, give or take, only where the neighbour is within so many
  /// gaps, and so thick a share of the streams.
  static const double strutEvery = 2.6;
  static const double strutJitter = 1.2;
  static const double strutReach = 2.2;
  static const double strutThick = 0.6;

  /// The ligament of the head, in the fovea, the share of the way from the
  /// cartilage's tone toward the mark's neutral.
  static const double ligamentLit = 0.42;

  // The scars and the nutrient artery: how wide, and in pixels at least.

  static const double scar = 0.8;
  static const double scarFloor = 1.0;
  static const double nutrient = 0.8;
  static const double branch = 0.6;
  static const double twig = 0.35;
  static const double vesselFloor = 1.0;
  static const double twigFloor = 0.7;
  static const double canal = 1.4;

  // The shadow the femur casts.

  static const double shadowX = 1.5;
  static const double shadowY = 2.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 4;

  // The names.

  /// How far apart the points of the outline the names' columns are found
  /// at may be, in height, from the name's own.
  static const double columnBand = 1.5;
}
