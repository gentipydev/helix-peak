/// Every number the vagina's look is tuned by, in one place. Lengths are in
/// millimetres of the real vagina unless they say otherwise; the anatomy
/// itself is in `vagina_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, opened and pinned flat, in deep tones:
/// the front wall's two halves, where the zoom goes in, flat in the mark, as
/// the cervix's ectocervix is, cut by their anatomy as crisp lines (the
/// rugae, the anterior column's halves and the urethral carina as ridges);
/// the back wall between them a deep warm mucosa, its posterior column and
/// rugae alike; the vaginal part of the cervix standing out of the vault,
/// lit, its os a dark slit, its shadow on the mucosa below it; the hymen's
/// caruncles pale along the introitus.
abstract final class VaginaStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the vagina's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// How far along the step from the body the body's outline is drawn in
  /// toward the vagina's own.
  static const double settling = 0.6;

  /// How finely the edges and ridges are followed, and the seed the rugae
  /// and the caruncles are laid by.
  static const double edgeStep = 0.3;
  static const int seed = 53;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom goes in, the front wall: one flat tone, the mark over a
  /// neutral, as the cervix's ectocervix is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The back wall's mucosa, deep and warm, as the cervix specimen draws
  /// the vagina's; the cervix's vaginal part, paler, lit as it rounds; the
  /// caruncles, paler still.
  static const double backLit = 0.38;
  static const double backWarmth = 0.26;
  static const double portioLit = 0.5;
  static const double portioWarmth = 0.3;
  static const double caruncleLit = 0.44;
  static const double caruncleWarmth = 0.28;

  /// How the vaginal part is inflated into its round end: the grid it is
  /// solved on, how high it stands for its width, and how many sweeps.
  static const double portioCell = 0.5;
  static const double portioInflation = 0.42;
  static const int portioSweeps = 140;

  /// The external os: its slit in the shadow ink.
  static const double osAlpha = 0.75;

  /// The vaginal part's shadow on the mucosa below it: how far over and
  /// down, how dark, and how soft.
  static const double portioShadowX = 0.8;
  static const double portioShadowY = 1.6;
  static const double portioShadowAlpha = 0.32;
  static const double portioShadowSoft = 1.6;

  // The lines.

  /// A crease along a ruga, crisp in the shadow ink: how wide, how far it
  /// tapers in from each end, how dark, and never thinner than so many
  /// pixels. The light on a ruga's far side, toward the lamp: how far over
  /// and how bright.
  static const double crease = 0.38;
  static const double creaseTaper = 1.6;
  static const double creaseAlpha = 0.24;
  static const double creaseFloor = 0.9;
  static const double ridge = 0.45;
  static const double ridgeLit = 0.75;
  static const double ridgeAlpha = 0.13;

  /// A column: a pale band toward the lamp over a crease.
  static const double columnCrease = 0.45;
  static const double columnAlpha = 0.28;
  static const double columnLight = 0.6;
  static const double columnLightAlpha = 0.12;

  /// The lateral sulci between the walls: a line in the shadow ink.
  static const double sulcusLine = 0.16;
  static const double sulcusAlpha = 0.34;
  static const double lineFloor = 0.5;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the vagina casts.

  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;
}
