/// Every number the epididymis's look is tuned by, in one place. Lengths
/// are in millimetres of the real epididymis unless they say otherwise; the
/// anatomy itself is in `epididymis_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, cut down its length on the back of its
/// testis, in deep tones that stand out among the body's faint parts round
/// it: where the zoom's cell lives flat in the mark, as the bladder's
/// urothelium is, cut by its anatomy as crisp lines (the duct's profiles
/// and the septa across it, or the ductules coiled in their cones); the
/// rest of the cut a warm, quiet tone, the head's cones a shade deeper than
/// the duct; the testis whole beside it, its tunica albuginea pale under
/// the lamp, the sinus a groove along the body; the vas deferens a pale,
/// firm tube, the cord's vessels lit tubes in the blood red, fading out
/// above; the tunica vaginalis laid open round them, a faint film.
abstract final class EpididymisStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the epididymis's outline the flat shape is drawn as it becomes
  /// the bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// How finely the coils, septa and tubes are followed, and the seed the
  /// profiles and the septa's wander are laid by.
  static const double edgeStep = 0.1;
  static const int seed = 37;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the bladder's urothelium is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cut: the duct's part, the body and the tail, a warm, quiet tone;
  /// the head's cones a shade deeper and warmer.
  static const double ductLit = 0.5;
  static const double ductWarmth = 0.18;
  static const double conesLit = 0.44;
  static const double conesWarmth = 0.24;

  /// The testis, whole: its tunica albuginea, pale.
  static const double testisLit = 0.56;
  static const double testisWarmth = 0.06;

  /// How high the testis stands up off the page, a share of how deep it is
  /// from front to back, and the grid it is laid on.
  static const double testisDome = 0.6;
  static const double meshCell = 0.4;

  /// The vas deferens, pale and firm; the cord's vessels, blood eased
  /// toward the ground, a vein more than an artery, as the testis's are.
  static const double vasLit = 0.58;
  static const double vasWarmth = 0.1;
  static const double artery = 0.25;
  static const double vein = 0.5;

  /// The tubes: how far apart their rows are, at most; round each at these
  /// shares of its radius, and how bright.
  static const double tubeRow = 0.3;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double tubeLight = 0.8;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.5;

  // The lines.

  /// The septa between the cones and across the duct, and where the head
  /// ends: how wide, how dark, and never thinner than so many pixels.
  static const double septum = 0.12;
  static const double septumAlpha = 0.34;
  static const double ductSeptumAlpha = 0.24;
  static const double lineFloor = 0.5;

  /// The ductules coiled in their cones: how wide, how dark.
  static const double ductule = 0.08;
  static const double ductuleAlpha = 0.26;

  /// The duct's profiles: each one's wall, a line round it, and its lumen,
  /// the share of it that is lumen and how dark.
  static const double wall = 0.07;
  static const double wallAlpha = 0.3;
  static const double lumen = 0.5;
  static const double lumenAlpha = 0.16;

  /// The tunica's inner face, a line in from the outline.
  static const double tunicaLine = 0.08;
  static const double tunicaAlpha = 0.3;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The sinus, a groove on the testis along the body's front edge: how far
  /// it reaches out from the edge, and how dark; and the epididymis's own
  /// shadow on the testis, how far over and down, and how dark.
  static const double sinus = 1.2;
  static const double sinusAlpha = 0.3;
  static const double castX = 0.5;
  static const double castY = 0.9;
  static const double castAlpha = 0.22;

  // The tunica vaginalis, as the testis's.

  /// Its film's tone and how much of it shows, and its edge's.
  static const double sacLit = 0.3;
  static const double sacAlpha = 0.14;
  static const double sacEdgeAlpha = 0.32;

  // The shadow the specimen casts, as the testis's.

  static const double shadowX = 1.2;
  static const double shadowY = 2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 4;

  // The names.

  /// How far a name keeps clear of a tube beside the epididymis at its
  /// height, and how much of the tube must show for it to count.
  static const double nameClear = 2;
  static const double nameShown = 0.5;
}
