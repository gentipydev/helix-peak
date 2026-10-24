/// Every number the abdominal wall's look is tuned by, in one place.
/// Lengths are in millimetres of the real wall unless they say otherwise;
/// the anatomy itself is in `adipose_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, a block cut through the abdominal wall:
/// its top the skin's surface, lit, its furrows faint; its front a flat
/// cut, the skin's dermis a warm neutral under its paler epidermis, the
/// fat of both its layers one flat tone in the mark, where the zoom's cell
/// lives, cut by pale septa, the membranous layer and the rectus sheath
/// pale bands, the rectus warmed toward the clay, its fascicles faint, the
/// vessels in the blood red; its right side a second cut, in shade.
abstract final class AdiposeStyle {
  // The block.

  /// How its top and its side are foreshortened: each millimetre back into
  /// the block runs so far across and up the screen, as the skin's block.
  static const double backAcross = 0.3;
  static const double backUp = 0.42;

  /// How far right of the middle of the drawn block the scene's origin
  /// lies, in millimetres.
  static const double offCentre = 0;

  /// How many points its wandering edges are followed by to a millimetre.
  static const double perMm = 4;

  /// The seed its lobes, its fascicles and its furrows are laid by.
  static const int seed = 73;

  // The faces' light: how each faces, out of the screen and toward the
  // lamp, which shines from the upper left.

  /// The front face, the cut, flat to the view.
  static const (double, double, double) front = (0, 0, 1);

  /// The top, the skin's surface, turned up toward the light.
  static const (double, double, double) top = (-0.05, -0.62, 0.78);

  /// The right side, turned away from the light.
  static const (double, double, double) side = (0.6, -0.1, 0.8);

  /// How much a cut face shines, a share of a fresh surface's sheen.
  static const double cutSheen = 0.4;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the other specimens draw it.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The skin's surface, its epidermis cut, and its dermis, as the skin's
  /// block draws them.
  static const double surfaceLit = 0.52;
  static const double surfaceWarmth = 0.12;
  static const double epidermisLit = 0.58;
  static const double epidermisWarmth = 0.1;
  static const double dermisLit = 0.32;
  static const double dermisWarmth = 0.2;

  /// The septa, and the membranous layer and the rectus sheath, paler.
  static const double septumLit = 0.62;
  static const double septumWarmth = 0.08;
  static const double fasciaLit = 0.66;
  static const double fasciaWarmth = 0.05;

  /// The rectus, warmed as the stomach's muscle is.
  static const double muscleLit = 0.3;
  static const double muscleWarmth = 0.42;

  /// The vessels, in the blood red eased toward the ground, the veins
  /// further.
  static const double artery = 0.25;
  static const double vein = 0.5;

  // The lines.

  /// The septa: how wide at least, in pixels.
  static const double septumFloor = 0.9;

  /// The rectus's fascicles: how dark, and how wide, in pixels.
  static const double fascicleAlpha = 0.12;
  static const double fascicleWidth = 0.7;

  /// The skin's furrows on the top: how far apart, how far each strays, and
  /// how dark.
  static const double furrowSpacing = 3;
  static const double furrowJitter = 0.6;
  static const double furrowAlpha = 0.16;

  /// The block's edges: lit where the top meets the front, dark where the
  /// side does.
  static const double edgeLit = 0.62;
  static const double edgeAlpha = 0.7;
  static const double edgeShadeAlpha = 0.5;

  /// The lines between the layers on the cut, and how wide at least, in
  /// pixels.
  static const double layerAlpha = 0.3;
  static const double layerFloor = 0.6;

  /// The pixel floors: the epidermis, the membranous layer and the sheath,
  /// a vessel.
  static const double epidermisFloor = 1;
  static const double fasciaFloor = 1.4;
  static const double vesselFloor = 1.2;

  // The shadow.

  /// The block's shadow, cast down and to the right of it, and how soft.
  static const double shadowX = 1.6;
  static const double shadowY = 2.6;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 4;
}
