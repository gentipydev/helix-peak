/// Every number the stomach's look is tuned by, in one place. Lengths are
/// in millimetres of the real stomach unless they say otherwise; the
/// anatomy itself is in `stomach_anatomy.dart`, and the light is the zoom's
/// one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, opened from the front, in deep tones
/// that stand out among the body's faint parts round it: where the zoom's
/// cell lives flat in the mark, as the liver's parenchyma is, its mucosa
/// with its rugae cut into it as crisp creases, as the brain's sulci are,
/// or its muscularis; else the mucosa a deep warm surface, turning up to
/// the cut toward its edge; the cut wall a band round it of its coats, the
/// submucosa pale and the muscle warm, thickening into the pyloric ring;
/// the esophagus's lining pale above the Z-line; the arteries lit tubes in
/// the blood red, the esophagus and the duodenum lit tubes in the
/// stomach's own warm neutral, each cut short.
abstract final class StomachStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the stomach's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 360;
  static const double bed = 0.6;

  /// Over how much of its detail the body's outline is drawn in to the
  /// stomach's: the other specimens' own (`SpecimenStep`).
  static const double settling = 0.45;

  /// How finely the rugae and the tubes are followed, and the seed the
  /// arcades' branches are laid by.
  static const double edgeStep = 0.5;
  static const int seed = 41;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the liver's parenchyma is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The mucosa, lit, warmed toward the clay: the reddish brown of a fresh
  /// stomach's, deep.
  static const double mucosaLit = 0.3;
  static const double mucosaWarmth = 0.3;

  /// The cut wall's coats: the submucosa pale, the muscularis a muscle's
  /// warm, the serosa paler still.
  static const double submucosaLit = 0.58;
  static const double submucosaWarmth = 0.12;
  static const double muscleLit = 0.28;
  static const double muscleWarmth = 0.42;
  static const double serosaLit = 0.62;
  static const double serosaWarmth = 0.08;

  /// The esophagus's lining, pale, barely warm.
  static const double liningLit = 0.5;
  static const double liningWarmth = 0.1;

  /// The esophagus and the duodenum outside it: lit tubes in the stomach's
  /// own warm neutral, under the stomach's light.
  static const double gutLit = 0.42;
  static const double gutWarmth = 0.22;

  /// The arteries: lit tubes in the blood red eased toward the ground,
  /// under a light a little dimmer than the stomach's own, as the other
  /// specimens' are; round each at these shares of its radius; a cut end's
  /// length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  // The cut's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The mucosa's edge, turning up to the cut wall: how wide, and how far
  /// its middle and its outer edge turn.
  static const double rim = 3;
  static const double rimMiddle = 0.4;
  static const double rimOuter = 0.8;

  // The rugae.

  /// The crease along a ruga, crisp in the shadow ink: how wide, how far
  /// it tapers in from each end, how dark, and never thinner than so many
  /// pixels; the esophagus's own folds, fainter. The light on its far side,
  /// toward the lamp: how far over and how bright.
  static const double crease = 0.7;
  static const double creaseTaper = 7;
  static const double creaseAlpha = 0.36;
  static const double liningCreaseAlpha = 0.2;
  static const double creaseFloor = 0.9;
  static const double ridge = 0.9;
  static const double ridgeLit = 0.75;
  static const double ridgeAlpha = 0.16;

  /// The Z-line, the esophagus's lining's edge: a crisp line in the shadow
  /// ink, so wide at least in pixels.
  static const double zLine = 0.35;
  static const double zLineFloor = 0.7;
  static const double zLineAlpha = 0.4;

  /// The muscularis, where it is the cell's home, never thinner than so
  /// many pixels.
  static const double muscleFloor = 1.5;

  // The lines.

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The line between the wall's coats and round the mucosa's edge, in the
  /// shadow ink.
  static const double coatLine = 0.12;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  // The shadow the stomach casts.

  static const double shadowX = 2;
  static const double shadowY = 3;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 5;

  // The names.

  /// How far the names keep clear of a tube beside the stomach, and how
  /// much of it must show for it to count: any of it that can be seen.
  static const double nameClear = 4;
  static const double nameShown = 0.1;
}
