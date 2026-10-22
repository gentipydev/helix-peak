/// Every number the heart's look is tuned by, in one place. Lengths are in
/// millimetres of the real heart unless they say otherwise; the anatomy
/// itself is in `heart_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, cut open from front to back, in deep
/// tones that stand out among the body's faint parts round it: the heart
/// muscle flat in the mark where the zoom's cell lives, as the brain's
/// cortex and the femur's red marrow are, cut sharply along its inner edge;
/// the chambers and the vessels emptied, in shade, their rims lit where they
/// face the lamp; the great vessels' walls cut faces; the valves' leaflets
/// pale and thin on their chordae; the coronary arteries in the blood red
/// in the fat of their grooves.
abstract final class HeartStyle {
  // The outline, and the step from the body.

  /// How far apart the outline's points are followed, how many the step
  /// from the body morphs round it by, and how far in from the heart's
  /// outline the flat shape is drawn as it becomes the bed it lies on.
  static const double outlineStep = 0.5;
  static const int morphSpan = 8;
  static const int morphPoints = 360;
  static const double bed = 0.6;

  /// Over how much of its detail the body's outline is drawn in to the
  /// heart's: a little more than other specimens' (`SpecimenStep`), since
  /// the anatomogram's heart, a sign more than a heart, lies further from
  /// it, so that no point of it jolts.
  static const double settling = 0.55;

  /// How finely the heart's parts are followed along their edges.
  static const double edgeStep = 0.6;

  /// How far past its openings a ventricle's cavity reaches, under the
  /// next chamber's, so no seam of the muscle shows across a valve.
  static const double openingOverlap = 1.2;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  /// The heart muscle where the zoom's cell lives: one flat tone, the mark
  /// over a neutral, as the brain's cortex is.
  static const double muscleLit = 0.2;
  static const double muscleMark = 0.42;

  /// The heart muscle where it does not: a deep neutral cut face.
  static const double muscleCut = 0.3;

  /// The chambers' and the vessels' insides, emptied.
  static const double cavityShade = 0.85;

  /// The valves' leaflets and cusps, and the chordae.
  static const double leafletLit = 0.72;
  static const double chordaLit = 0.66;
  static const double chordaAlpha = 0.8;

  /// The great vessels where they are whole: lit tubes in the blood red
  /// eased toward the ground, the veins more, under a light a little dimmer
  /// than the heart's own, as the other specimens' vessels are; round each
  /// at these shares of its radius; and a cut end's length along its tube
  /// and its wall, shares of its radius.
  static const double wholeArtery = 0.25;
  static const double wholeVein = 0.5;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  /// The fat in the grooves, and the coronary arteries' walls round their
  /// lumens, in the blood red eased toward the ground.
  static const double fatLit = 0.55;

  /// How far the fat is warmed toward the home helix's honey.
  static const double fatWarmth = 0.3;
  static const double coronaryWallLit = 0.66;
  static const double coronary = 0.25;

  // A rim round each opening: a shadow just inside its edges that face the
  // lamp, and light just inside those that turn from it, as the brain's
  // window has.

  static const double lipShadow = 6;
  static const double lipShadowAlpha = 0.75;
  static const double lipLight = 3;
  static const double lipLightAlpha = 0.35;

  /// How far up the right ventricle's outflow its walls grow out of the
  /// cavity.
  static const double outflowTaper = 12;

  /// The crisp line along the muscle's inner edge and round its papillary
  /// muscles, in the shadow ink: how wide, in pixels at least, and how
  /// strong.
  static const double edgeLine = 0.15;
  static const double edgeLineFloor = 0.8;
  static const double edgeLineAlpha = 0.5;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The epicardium where the zoom's cell lives there: its line in the
  /// mark, how wide, in pixels at least.
  static const double epicardium = 0.4;
  static const double epicardiumFloor = 1.6;
  static const double epicardiumGlow = 0.95;

  /// How far in from the outline it is looked for a great vessel, to tell
  /// the heart's own surface from the vessels' edges.
  static const double epicardiumProbe = 0.4;

  /// The chordae's width, in pixels at least, and the leaflets' thickness
  /// at their hinge and at their free edge.
  static const double chorda = 0.8;
  static const double chordaFloor = 0.7;
  static const double leafletHinge = 1.2;
  static const double leafletEdge = 0.6;

  // The cut faces' light.

  /// How far a cut face's cushion tilts it at its edges, and how much it
  /// shines: less than a fresh surface, being cut.
  static const double cushion = 0.22;
  static const double cutSheen = 0.6;

  // The trabeculae: how far the inner edge of a ventricle's wall rises and
  // falls, over how long a wave, the right's coarser.

  static const double trabeculaRight = 1.5;
  static const double trabeculaLeft = 1.0;
  static const double trabeculaWave = 5;
  static const int seed = 41;

  // The shadow the heart casts.

  static const double shadowX = 1.5;
  static const double shadowY = 2.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 4;
}
