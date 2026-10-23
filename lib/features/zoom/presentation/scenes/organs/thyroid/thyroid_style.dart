/// Every number the thyroid's look is tuned by, in one place. Lengths are in
/// millimetres of the real gland unless they say otherwise; the anatomy
/// itself is in `thyroid_anatomy.dart`, and the light is the zoom's one
/// lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, in deep tones that stand out among the
/// body's faint parts round it: where the zoom's cell lives flat in the
/// mark, as the kidney's cortex is, cut by the septa that part its
/// lobules; else its cut face a deep warm red-brown, turning away under
/// the capsule; the rest of the gland, its other lobe and its isthmus, a
/// lit surface in the same tone; the thyroid and cricoid cartilages pale
/// and cool, as hyaline cartilage is, the trachea's rings pale over the
/// warmer membrane between them; the cricothyroid muscles warmed toward
/// the home helix's clay, as the thigh's are; the arteries and the veins
/// lit tubes in the blood red, cut short above, the veins fading out below.
abstract final class ThyroidStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the gland's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 320;
  static const double bed = 0.5;

  /// How finely the parts' edges and the vessels are followed.
  static const double edgeStep = 0.4;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The gland, lit, warmed toward the home helix's clay: brownish red, a
  /// little deeper and redder than the liver's parenchyma.
  static const double glandLit = 0.3;
  static const double glandWarmth = 0.34;

  /// The cartilages: pale and cool, the bright ink's own; the ligaments
  /// between them, the cricothyroid membrane and the trachea's between its
  /// rings, a little deeper and warm, as fibrous tissue is.
  static const double cartilageLit = 0.5;
  static const double membraneLit = 0.4;
  static const double membraneWarmth = 0.14;

  /// The cricothyroid muscles, warmed toward the clay as the thigh's are.
  static const double muscleLit = 0.3;
  static const double muscleWarmth = 0.28;

  /// The vessels: lit tubes in the blood red eased toward the ground, the
  /// veins more, under a light a little dimmer than the gland's own, as the
  /// other specimens' are; round each at these shares of its radius; a cut
  /// end's length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  // The relief the uncut parts are lit by.

  /// The grid the relief is solved on and the mesh laid on, how high it
  /// stands, and how many sweeps it is solved by.
  static const double reliefCell = 0.6;
  static const double meshCell = 0.5;
  static const double reliefInflation = 0.75;
  static const int reliefSweeps = 260;

  /// The cartilages' relief: lower, as they curve round less.
  static const double cartilageInflation = 0.45;

  /// How brightly the cartilages and the membrane take the light, and how
  /// much they shine.
  static const double cartilageLight = 0.9;
  static const double cartilageSheen = 0.5;

  // The cut face's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The cut face's edge under the capsule, turning away from the eye: how
  /// wide, and how far its middle and its outer edge turn.
  static const double rim = 1.6;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // The lines.

  /// The septa between the lobules: in the shadow ink, in pixels at least.
  static const double septum = 0.12;
  static const double septumFloor = 0.6;
  static const double septumAlpha = 0.32;

  /// The line where the cut face meets the isthmus the cut leaves whole.
  static const double lobeEndAlpha = 0.55;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The trachea's rings' edges, faint, in the shadow ink.
  static const double ringEdgeAlpha = 0.22;

  // The C cells.

  /// How far apart, about, and how wide in pixels at least, where they are
  /// the cell's home; how far one keeps from the cut face's edge.
  static const double cApart = 1.2;
  static const double cFloor = 1.2;
  static const double cClear = 1.4;
  static const int seed = 41;

  // The shadow the gland casts.

  static const double shadowX = 1;
  static const double shadowY = 1.6;
  static const double shadowAlpha = 0.32;
  static const double shadowSoft = 2.4;

  // The names.

  /// Above what share of the way in a vessel is set clear of names, and how
  /// far they keep from it.
  static const double nameShown = 0.1;
  static const double nameClear = 2.4;
}
