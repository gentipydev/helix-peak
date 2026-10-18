/// Every number the brain's look is tuned by, in one place. Lengths are in
/// millimetres of the real brain unless they say otherwise; the anatomy
/// itself is in `brain_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the pancreas's.
///
/// The look is a fresh specimen's, cut down its middle: the medial face's
/// gyri lit as rounded ridges with a moist sheen, dark in their sulci and
/// rolling away at the superior border; the cut faces flat and cushioned a
/// little, white matter bright and grey matter darker; the third
/// ventricle's walls smooth domes; the vermis's arbor vitae white in its
/// grey; its arteries in the blood red, dimmer than the brain.
abstract final class BrainStyle {
  // The medial face.

  /// The grid its surface is laid on.
  static const double faceCell = 0.6;

  /// How high the face stands where it has turned to face the eye, and how
  /// soft its rolling away toward its edge is.
  static const double faceHeight = 9;
  static const double faceRoll = 4.5;

  /// A sulcus: how deep and how wide to either side the gyri round down
  /// into it, a major one and a minor; how far into the shade its floor
  /// goes, the shade gathered toward its middle by [shadePower]; and over
  /// how much of its length an end inside the face comes up out of
  /// nothing.
  static const double sulcusDepth = 3.6;
  static const double sulcusWidth = 4.2;
  static const double minorDepth = 1.9;
  static const double minorWidth = 3.0;
  static const double sulcusShade = 0.42;
  static const double shadePower = 1.4;
  static const double sulcusTaper = 4;

  /// How a sulcus wanders from the line drawn for it: how far to either
  /// side, and over how long a wave.
  static const double sulcusWander = 0.4;
  static const double sulcusWave = 11;

  /// The cleft down a sulcus's middle, drawn crisp over the face: how wide,
  /// a major one's and a minor one's, at least so many pixels, and how
  /// dark.
  static const double crease = 0.55;
  static const double minorCrease = 0.36;
  static const double creaseFloor = 0.9;
  static const double creaseAlpha = 0.62;

  /// How far the face darkens toward the cut core it lies behind, and over
  /// how far.
  static const double coreShade = 0.5;
  static const double coreReach = 2.6;

  /// The gyri's tone, a share of the way toward the bright ink, and the
  /// share of the mark in it for a cell that lives in the cortex.
  static const double faceLit = 0.52;
  static const double cortexWash = 0.34;

  // The core: the cut and what the cut lays open.

  /// The grid its parts are laid on, and how far each part's cut face is
  /// cushioned; the third ventricle's walls are domes.
  static const double coreCell = 0.5;
  static const double cutInflation = 0.22;
  static const double wallInflation = 0.5;
  static const int reliefSweeps = 45;

  /// The parts' tones: white matter, lifted past its tone by [whiteGain];
  /// the cut grey of the brainstem and the vermis; the third ventricle's
  /// walls; the septum; the pituitary's two lobes; the pineal; the
  /// fourth ventricle's dark, and what lies deep between the parts.
  static const double whiteLit = 0.74;
  static const double whiteGain = 1.22;
  static const double greyLit = 0.56;
  static const double cerebellarLit = 0.42;
  static const double wallLit = 0.5;
  static const double septumLit = 0.3;
  static const double anteriorLobeLit = 0.38;
  static const double posteriorLobeLit = 0.52;
  static const double pinealLit = 0.44;
  static const double cavityShade = 0.24;
  static const double deepShade = 0.16;

  /// How much the cut faces shine: less than the face, being flat.
  static const double cutSheen = 0.8;

  /// The lines over the cut: how wide a part's edge and a fissure are, in
  /// pixels at least.
  static const double edgeLine = 0.8;
  static const double fissureLine = 1.1;

  // The arbor vitae.

  /// A lamina's width at the core and at its tip, and a branch's at its
  /// root; how far its tip stops short of the vermis's surface; how far a
  /// branch turns from its lamina, at least and at most, in radians; the
  /// core's radii.
  static const double laminaRoot = 3.6;
  static const double laminaTip = 1.3;
  static const double branchRoot = 1.7;
  static const double branchTip = 0.8;
  static const double laminaShort = 2.2;
  static const double branchTurn = 0.38;
  static const double branchSpread = 0.22;
  static const double coreRadiusX = 5.6;
  static const double coreRadiusY = 4.4;

  /// The folia between the laminae's branches: how far apart round the
  /// vermis's edge, and how far in a groove between two runs.
  static const double foliumStep = 2.4;
  static const double foliumDepth = 1.4;

  /// How far the vermis's edge is drawn in between two folia, and where a
  /// fissure comes up to it, and over how much of the edge either way.
  static const double foliumNotch = 0.55;
  static const double fissureNotch = 1.0;
  static const double notchWidth = 0.5;

  // The arteries.

  /// Blood eased toward the ground, and the share of the brain's own light
  /// they are drawn in; how far apart their rows are.
  static const double artery = 0.25;
  static const double arteryLight = 0.62;
  static const double tubeRow = 0.8;
  static const List<double> columns = <double>[0, 0.38, 0.7, 0.92, 1];

  /// How close a bend's inner side may come to its middle, a share of the
  /// bend's radius.
  static const double bend = 0.9;

  // The choroid plexus.

  /// Its beads along each course: how far apart, how big at the front and
  /// at the back of the lateral ventricle's, the third's and the fourth's;
  /// how they are drawn, a core and a halo at least so many pixels across.
  static const double beadStep = 0.9;
  static const double lateralFront = 0.55;
  static const double lateralBack = 1.25;
  static const double thirdBead = 0.45;
  static const double fourthBead = 0.6;
  static const double coreFloor = 1.1;
  static const double haloFloor = 2.6;
  static const double halo = 3.2;
  static const double haloAlpha = 0.2;

  /// The window onto the lateral ventricle: the ventricle's dark, the
  /// caudate's light on its far wall; the cut's shadow on the side facing
  /// the light and its lit wall on the other, in millimetres and at most
  /// how strong.
  static const double ventricleShade = 0.14;
  static const double caudateLit = 0.26;
  static const double lipShadow = 2.2;
  static const double lipShadowAlpha = 0.5;
  static const double lipWall = 0.8;
  static const double lipWallAlpha = 0.5;

  // The shadow the specimen casts, and its vessels, in millimetres.

  static const double shadowX = 2.5;
  static const double shadowY = 4;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 8;

  // The names.

  /// How far the names set round the brain keep clear of a vessel where it
  /// leaves the silhouette, and how faint a vessel's end may be and still
  /// keep them clear of it.
  static const double nameClear = 4;
  static const double nameShown = 0.5;

  /// How many points the outlines are followed by between two of their own.
  static const int outlineSpan = 6;
}
