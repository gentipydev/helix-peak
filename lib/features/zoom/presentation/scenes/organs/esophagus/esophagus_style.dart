/// Every number the esophagus's look is tuned by, in one place. Lengths
/// are in millimetres of the real esophagus unless they say otherwise; the
/// anatomy itself is in `esophagus_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, opened from the front, in deep tones
/// that stand out among the body's faint parts round it: where the zoom's
/// cell lives flat in the mark, as the stomach's mucosa is, its lining
/// with its folds cut into it as crisp creases, or its glands; else the
/// lining pale, turning up to the cut toward its edges; the cut wall a band
/// down either side of its coats, the submucosa pale and the muscle warm,
/// thickening into its two sphincters; the stomach's mucosa past the
/// Z-line in the stomach's own deep tone; the aorta a lit tube in the blood
/// red, the diaphragm in a muscle's warm, and the pharynx and the stomach
/// lit tubes in the gut's warm neutral, each cut short.
abstract final class EsophagusStyle {
  // The outline, and the step from the body.

  /// How finely its course is followed, how many points the body's outline
  /// is followed by between two of its own, how many the step from the
  /// body morphs round it by, and how far in from its outline the flat
  /// shape is drawn as it becomes the bed it lies on.
  static const double edgeStep = 0.5;
  static const int outlineSpan = 8;
  static const int morphPoints = 360;
  static const double bed = 0.6;

  /// How far the cut across its top, where it meets the pharynx, arches
  /// up in its middle, as the cut through a tube does.
  static const double topArch = 1.5;

  /// Where the step from the body meets the two outlines besides their
  /// tops and the site's height: so far along it from its top, and so far
  /// below the site, below which the outermost point toward the body's left
  /// is met.
  static const double markTop = 10;
  static const double markLow = 40;

  /// Over how much of its detail the body's outline is drawn in to the
  /// esophagus's: the other specimens' own (`SpecimenStep`).
  static const double settling = 0.45;

  /// The seed its glands are laid by.
  static const int seed = 43;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the stomach's mucosa is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The lining, pale, barely warm, as the stomach draws it above its
  /// Z-line.
  static const double liningLit = 0.5;
  static const double liningWarmth = 0.1;

  /// The stomach's mucosa past the Z-line, in the stomach's own tone.
  static const double gastricLit = 0.3;
  static const double gastricWarmth = 0.3;

  /// The cut wall's coats: the submucosa pale, the muscularis a muscle's
  /// warm, the fibrous coat paler still; the glands in the submucosa a
  /// little deeper than it.
  static const double submucosaLit = 0.58;
  static const double submucosaWarmth = 0.12;
  static const double muscleLit = 0.28;
  static const double muscleWarmth = 0.42;
  static const double fibrousLit = 0.62;
  static const double fibrousWarmth = 0.08;
  static const double glandLit = 0.44;
  static const double glandWarmth = 0.18;

  /// The pharynx and the stomach outside it: lit tubes in the gut's warm
  /// neutral, under the specimen's light; the diaphragm in the muscle's.
  static const double gutLit = 0.42;
  static const double gutWarmth = 0.22;

  /// The aorta: a lit tube in the blood red eased toward the ground, under
  /// a light a little dimmer than the esophagus's own, as the other
  /// specimens' vessels are; round each tube at these shares of its radius;
  /// a cut end's length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  // The cut's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The lining's edges, turning up to the cut wall: how wide, and how far
  /// their middle and their outer edge turn.
  static const double rim = 1.6;
  static const double rimMiddle = 0.4;
  static const double rimOuter = 0.8;

  // The folds.

  /// The crease along a fold, crisp in the shadow ink: how wide, how far
  /// it tapers in from each end, how dark, and never thinner than so many
  /// pixels. The light on its far side, toward the lamp: how far over and
  /// how bright.
  static const double crease = 0.55;
  static const double creaseTaper = 9;
  static const double creaseAlpha = 0.3;
  static const double creaseFloor = 0.8;
  static const double ridge = 0.7;
  static const double ridgeLit = 0.75;
  static const double ridgeAlpha = 0.14;

  /// The Z-line, the lining's edge on the stomach's mucosa: a crisp line in
  /// the shadow ink, so wide at least in pixels.
  static const double zLine = 0.3;
  static const double zLineFloor = 0.7;
  static const double zLineAlpha = 0.4;

  /// The glands, where they are the cell's home, never smaller across than
  /// so many pixels; and where they are not, never smaller than this.
  static const double glandFloor = 1.4;
  static const double glandLeast = 0.6;

  // The lines.

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The line round the lining's edges and between the muscle's two
  /// planes, in the shadow ink.
  static const double coatLine = 0.1;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;
  static const double planeLineAlpha = 0.16;

  // The shadow the esophagus casts.

  static const double shadowX = 1.5;
  static const double shadowY = 2.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 4;

  // The names.

  /// How far the names keep clear of a tube beside the esophagus, and how
  /// much of it must show for it to count.
  static const double nameClear = 4;
  static const double nameShown = 0.5;
}
