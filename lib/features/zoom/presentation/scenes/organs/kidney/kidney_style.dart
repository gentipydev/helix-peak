/// Every number the kidney's look is tuned by, in one place. Lengths are in
/// millimetres of the real kidney unless they say otherwise; the anatomy
/// itself is in `kidney_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, cut open from front to back, in deep
/// tones that stand out among the body's faint parts round it: where the
/// zoom's cell lives flat in the mark, as the brain's cortex and the heart's
/// muscle are; the cortex a warm cut face, its edge turning away under the
/// capsule; the pyramids darker and redder, each a low cushion, striated
/// down to its papilla; the calyces and the pelvis emptied, in shade,
/// rimmed as the heart's chambers are; the fat of the sinus warmed toward
/// the home helix's honey; the vessels lit tubes in the blood red, cut
/// short past the hilum as a plate cuts them; the ureter pale, fading out
/// below; the glomeruli a fine dust of the blood red.
abstract final class KidneyStyle {
  // The outline, and the step from the body.

  /// How many points the outlines are followed by between two of their
  /// own, how many the step from the body morphs round them by, and how far
  /// in from the kidney's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 360;
  static const double bed = 0.6;

  /// How finely the parts' edges are followed.
  static const double edgeStep = 0.5;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the brain's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cortex and the pyramids, lit, warmed toward the home helix's clay,
  /// as the thigh's muscles are: `lit` alone runs to the cool bright ink.
  /// The pyramids darker and redder than the cortex, their papillae a
  /// little paler.
  static const double cortexLit = 0.36;
  static const double cortexWarmth = 0.14;
  static const double medullaLit = 0.25;
  static const double medullaWarmth = 0.26;
  static const double papillaLit = 0.32;

  /// The calyces and the pelvis, emptied, as the heart's chambers are.
  static const double cavityShade = 0.85;

  /// The fat of the sinus, warmed toward the home helix's honey, as the
  /// heart's grooves' fat is.
  static const double fatLit = 0.5;
  static const double fatWarmth = 0.3;

  /// The vessels: lit tubes in the blood red eased toward the ground, the
  /// veins more, under a light a little dimmer than the kidney's own, as
  /// the other specimens' are; round each at these shares of its radius;
  /// a cut end's length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  /// The ureter: pale, a little warm, lit as a tube.
  static const double ureterLit = 0.55;
  static const double ureterWarmth = 0.1;

  // The cut faces' light.

  /// How far a pyramid's cushion tilts it at its sides, and how much a cut
  /// face shines: less than a fresh surface, being cut.
  static const double cushion = 0.24;
  static const double cutSheen = 0.6;

  /// The cortex's edge under the capsule, turning away from the eye: how
  /// wide, and how far its middle and its outer edge turn.
  static const double rim = 2.2;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // A rim round the calyces and the pelvis: a shadow just inside their
  // edges that face the lamp, and light just inside those that turn from
  // it, as the heart's chambers have.

  static const double lipShadow = 2.4;
  static const double lipShadowAlpha = 0.7;
  static const double lipLight = 1.2;
  static const double lipLightAlpha = 0.3;
  static const double lipLit = 0.7;

  // The lines.

  /// A pyramid's striations, converging on its papilla: how many, and how
  /// strong, in the shadow ink, in pixels at least.
  static const int striations = 11;
  static const double striation = 0.18;
  static const double striationFloor = 0.6;
  static const double striationAlpha = 0.22;

  /// Where the zoom's cell does not live in them, the medullary rays: a
  /// faint line in the shadow ink, in pixels at least.
  static const double rayFloor = 0.6;
  static const double rayAlpha = 0.16;

  /// Where it does, the rays in the mark, in pixels at least.
  static const double homeRayFloor = 0.9;

  /// The crisp line along the pyramids' edges, in the shadow ink.
  static const double edgeLine = 0.15;
  static const double edgeLineFloor = 0.7;
  static const double edgeLineAlpha = 0.4;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The glomeruli.

  /// The blood red they are drawn in, eased toward the ground, and at
  /// least how wide, in pixels; in the mark, at least how wide.
  static const double glomerulusBlood = 0.35;
  static const double glomerulusFloor = 0.9;
  static const double homeGlomerulusFloor = 1.3;

  /// How far a glomerulus keeps from a ray, the capsule, a pyramid and the
  /// sinus, past its own radius; how far from the site, but for one at it.
  static const double glomerulusClear = 0.25;
  static const double siteClear = 0.6;
  static const int seed = 23;

  // The shadow the kidney casts.

  static const double shadowX = 1.5;
  static const double shadowY = 2.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 4;

  // The names.

  /// How far the names' columns keep clear of a tube beside the kidney.
  static const double nameClear = 3;
}
