/// Every number the bladder's look is tuned by, in one place. Lengths are
/// in millimetres of the real bladder unless they say otherwise; the
/// anatomy itself is in `bladder_anatomy.dart`, and the light is the zoom's
/// one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, opened from the front, in deep tones
/// that stand out among the body's faint parts round it: its urothelium,
/// where the zoom's cell lives, flat in the mark, as the stomach's mucosa
/// is, cut by its anatomy as crisp lines (the low folds as creases, the
/// torus uretericus and the plicae as ridges, the ureters' slits and the
/// urethral orifice dark); the cut wall a band round it of its coats, the
/// lamina propria pale and the detrusor a muscle's warm, thickening into
/// the sphincter round the neck; the ureters and the urethra lit tubes,
/// pale, and the arteries lit tubes in the blood red, each cut short.
abstract final class BladderStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the bladder's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// How finely the folds and the tubes are followed, and the seed the
  /// arteries' branches are laid by.
  static const double edgeStep = 0.4;
  static const int seed = 23;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the stomach's mucosa is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cut wall's coats: the lamina propria pale, the detrusor a
  /// muscle's warm, the serosa paler still.
  static const double laminaLit = 0.58;
  static const double laminaWarmth = 0.12;
  static const double muscleLit = 0.28;
  static const double muscleWarmth = 0.42;
  static const double serosaLit = 0.62;
  static const double serosaWarmth = 0.08;

  /// The ureters and the urethra: lit tubes, pale and a little warm, as
  /// the kidney's ureter is, under a light a little dimmer than the
  /// bladder's own.
  static const double ductLit = 0.6;
  static const double ductWarmth = 0.1;
  static const double ductLight = 0.9;

  /// The arteries: lit tubes in the blood red eased toward the ground, as
  /// the other specimens' are; round each at these shares of its radius;
  /// a cut end's length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  // The urothelium's anatomy, cut into it.

  /// The crease along a fold, crisp in the shadow ink: how wide, how far
  /// it tapers in from each end, how dark, and never thinner than so many
  /// pixels. The light on its far side, toward the lamp: how far over and
  /// how bright. The folds are low, so fainter than the stomach's rugae.
  static const double crease = 0.55;
  static const double creaseTaper = 4;
  static const double creaseAlpha = 0.24;
  static const double creaseFloor = 0.9;
  static const double ridge = 0.7;
  static const double ridgeLit = 0.75;
  static const double ridgeAlpha = 0.13;

  /// The torus uretericus and the plicae: ridges, a pale band toward the
  /// lamp over a crease: how wide the crease is, how far the light lies
  /// over from it and how wide and bright it is; the plicae fade out over
  /// this share of their length.
  static const double torusCrease = 0.6;
  static const double torusAlpha = 0.34;
  static const double torusLight = 0.9;
  static const double torusLightWidth = 0.9;
  static const double torusLightAlpha = 0.22;
  static const double plicaFade = 0.55;

  /// The trigone's sides, from each ureter's orifice down to the urethra's:
  /// a faint line, where the mucosa is bound to the muscle beneath.
  static const double trigoneEdge = 0.3;
  static const double trigoneEdgeAlpha = 0.14;

  /// The ureters' slits and the urethral orifice: dark, with a hair of
  /// light on the lip toward the lamp.
  static const double orificeAlpha = 0.72;
  static const double lipLit = 0.75;
  static const double lipAlpha = 0.28;
  static const double lipOffset = 0.35;

  /// The urothelium, the home, along the cut wall: never thinner than so
  /// many pixels.
  static const double urotheliumFloor = 1;

  // The lines.

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The line between the cut wall and the urothelium, and between its
  /// coats, in the shadow ink.
  static const double coatLine = 0.1;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  // The shadow the bladder casts.

  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;

  // The names.

  /// How far the names keep clear of a tube beside the bladder, and how
  /// much of it must show for it to count: any of it that can be seen.
  static const double nameClear = 2.5;
  static const double nameShown = 0.1;

  /// How finely the place a name of the figure's neighbour points at is
  /// looked for, and how much being inside it counts against being out
  /// from the bladder and off the urethra: four times, so that on the
  /// uterus's thin band the place lies about 4 mm out from both.
  static const double neighbourStep = 0.5;
  static const double neighbourInside = 4;
}
