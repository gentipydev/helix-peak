/// Every number the placenta's look is tuned by, in one place. Lengths are
/// in millimetres of the real placenta unless they say otherwise; the
/// anatomy itself is in `placenta_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, a block cut through a placenta in its
/// uterine wall: its top the fetal surface, lit, a cool grey under the
/// amnion, its chorionic vessels lit tubes over it, the arteries over the
/// veins, and the cord rising from it, pale and glistening, cut across;
/// its front a flat cut, the villi pale among the intervillous space's
/// maternal blood, eased toward the ground, the septa, the basal plate and
/// the decidua a warm neutral, the spiral arteries in the blood red, the
/// uterine muscle warmed toward the clay; its right side a second cut, in
/// shade. Where the zoom's cell lives is one flat tone in the mark, as the
/// other specimens draw it.
abstract final class PlacentaStyle {
  // The block.

  /// How its top and its side are foreshortened: each millimetre back into
  /// the block runs so far across and up the screen, as the skin's block.
  static const double backAcross = 0.3;
  static const double backUp = 0.42;

  /// How far right of the middle of the drawn block the scene's origin
  /// lies, in millimetres: the block a little left of the canvas's middle,
  /// where its names' widest column, on its right, needs the more room.
  static const double offCentre = 4;

  /// How many points its wandering edges are followed by to a millimetre.
  static const double perMm = 4;

  /// The seed its villi, its fibres and its edges are laid by.
  static const int seed = 61;

  // The faces' light: how each faces, out of the screen and toward the
  // lamp, which shines from the upper left.

  /// The front face, the cut, flat to the view.
  static const (double, double, double) front = (0, 0, 1);

  /// The top, the fetal surface, turned up toward the light.
  static const (double, double, double) top = (-0.05, -0.62, 0.78);

  /// The right side, turned away from the light.
  static const (double, double, double) side = (0.6, -0.1, 0.8);

  /// How much a cut face shines, a share of a fresh surface's sheen.
  static const double cutSheen = 0.4;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay or cooled
  // toward its denim.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the other specimens draw it.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The fetal surface under the amnion, a bluish grey; the amnion's cut
  /// edge, paler; the chorionic plate, cut.
  static const double surfaceLit = 0.5;
  static const double surfaceCool = 0.14;
  static const double amnionLit = 0.72;
  static const double plateLit = 0.5;
  static const double plateWarmth = 0.08;

  /// The villi, a pale warm grey.
  static const double villousLit = 0.52;
  static const double villousWarmth = 0.2;

  /// The intervillous space's maternal blood, the blood red eased toward
  /// the ground.
  static const double space = 0.62;

  /// The basal plate, the septa and the decidua.
  static const double deciduaLit = 0.4;
  static const double deciduaWarmth = 0.18;

  /// The uterine muscle, warmed as the stomach's is.
  static const double muscleLit = 0.3;
  static const double muscleWarmth = 0.42;

  /// The vessels, in the blood red eased toward the ground, the veins
  /// further.
  static const double artery = 0.25;
  static const double vein = 0.5;

  /// The cord's Wharton's jelly, pale and a little cool; how bright its
  /// flank is lit.
  static const double jellyLit = 0.8;
  static const double jellyCool = 0.1;
  static const double cordLight = 1.1;

  /// The chorionic vessels' and the cord's light, and the columns round a
  /// tube it is lit at.
  static const double tubeLight = 0.9;
  static const List<double> tubeColumns = <double>[
    0,
    0.3,
    0.55,
    0.75,
    0.88,
    0.96,
    1,
  ];

  // The lines.

  /// The bundles of the uterine muscle: how many, how long, how far each
  /// waves, and how faint.
  static const int fibres = 80;
  static const double fibreLength = 3.2;
  static const double fibreWave = 0.18;
  static const double fibreAlpha = 0.16;

  /// The cord's arteries seen through its jelly, winding round it: how
  /// strongly where they lie nearest the eye, and how much of that where
  /// they pass behind its vein.
  static const double windingAlpha = 0.45;
  static const double windingBehind = 0.3;

  /// The block's edges: lit where the top meets the front, dark where the
  /// side does.
  static const double edgeLit = 0.62;
  static const double edgeAlpha = 0.7;
  static const double edgeShadeAlpha = 0.5;

  /// The lines between the layers on the cut, and how wide at least, in
  /// pixels.
  static const double layerAlpha = 0.3;
  static const double layerFloor = 0.6;

  /// The pixel floors: the amnion's edge, a spiral artery, a vessel's cut.
  static const double amnionFloor = 1;
  static const double spiralFloor = 1.2;
  static const double vesselFloor = 1.4;

  // The villi.

  /// How many clumps of villi are laid along each millimetre of a branch,
  /// and how many fill the strips beyond the edge septa and the side face,
  /// to a square millimetre.
  static const double clumpsPerMm = 4.2;
  static const double fillPerMm2 = 1.1;

  /// How the stem villi branch: how many times, how many branches each
  /// time, how far each runs before it branches again, a share of the one
  /// before, and how far it turns away from its parent.
  static const int branchings = 4;
  static const double shorten = 0.72;
  static const double spread = 0.5;

  // The shadow.

  /// The block's shadow, cast down and to the right of it, and how soft.
  static const double shadowX = 2;
  static const double shadowY = 3.2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 5;
}
