/// Every number the lymph node's look is tuned by, in one place. Lengths
/// are in millimetres of the real node unless they say otherwise; the
/// anatomy itself is in `node_anatomy.dart`, and the light is the zoom's
/// one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh section's, in deep tones: where the zoom's cell
/// lives flat in the mark, as the kidney's cortex is (its sinuses, its
/// follicles, its paracortex, its medullary cords, or its cortex); else
/// the cortex the lightest, its follicles darker mantles round pale
/// germinal centres, the paracortex a shade deeper, the medulla the
/// darkest, its cords paler in it, the sinuses fine pale lines; the
/// capsule's edge turning away; the lymphatics pale lit tubes, the artery
/// and the vein in the blood red.
abstract final class NodeStyle {
  /// How finely the outline and the vessels are followed.
  static const int outlinePoints = 240;
  static const double edgeStep = 0.06;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`), warmed a
  // little toward the home helix's clay, as lymphoid tissue is pink-grey.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  static const double warmth = 0.16;
  static const double cortexLit = 0.5;
  static const double mantleLit = 0.3;
  static const double germinalLit = 0.58;
  static const double paracortexLit = 0.38;
  static const double medullaLit = 0.22;
  static const double cordLit = 0.34;

  /// The sinuses, pale, where they are not the home; and in pixels at
  /// least, either way.
  static const double sinusLit = 0.56;
  static const double sinusAlpha = 0.7;
  static const double sinusFloor = 0.8;
  static const double homeSinusFloor = 1.2;

  /// The trabeculae and the medullary cords' widths, in millimetres, and in
  /// pixels at least.
  static const double trabecula = 0.12;
  static const double cord = 0.34;
  static const double lineFloor = 0.7;

  /// The lymphatics: pale, a little toward the honey; the artery and the
  /// vein in the blood red eased toward the ground; under a light a little
  /// dimmer than the node's own; round each at these shares of its
  /// radius; a cut end's length along its tube and its wall.
  static const double lymphLit = 0.55;
  static const double lymphHoney = 0.16;
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double tubeLight = 0.7;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  // The cut face's light.

  static const double cutSheen = 0.6;

  /// The cut face's edge under the capsule, turning away from the eye.
  static const double rim = 0.45;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the node casts.

  static const double shadowX = 0.25;
  static const double shadowY = 0.4;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 0.7;

  /// The follicles' and the trabeculae's places, the same every time.
  static const int seed = 53;

  // The names.

  /// How far along the step on to the tissue its names are gone by: a
  /// little more than other organs' (`OrganScene.leaving`, 0.24), as the
  /// node's step to its tissue is short, so that none blinks out (at 0.24
  /// the home's faded 0.0805 a frame at 60 fps, over the 0.08 the zoom
  /// allows).
  static const double namesLeaving = 0.27;

  /// Above what share of the way in a vessel is set clear of names, and how
  /// far they keep from it.
  static const double nameShown = 0.1;
  static const double nameClear = 0.5;
}
