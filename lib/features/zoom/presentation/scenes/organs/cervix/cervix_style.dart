/// Every number the cervix's look is tuned by, in one place. Lengths are in
/// millimetres of the real cervix unless they say otherwise; the anatomy
/// itself is in `cervix_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, opened along its canal, in deep tones
/// that stand out among the body's faint parts round it: its vaginal part,
/// the ectocervix, where the zoom goes in, flat in the mark, as the
/// bladder's urothelium is, cut by its anatomy as crisp lines (its
/// epithelium along its surface, the transformation zone's edge, the
/// cysts); the cut stroma pale and fibrous, giving way above the isthmus to
/// the uterus's muscle, grey and a little warm; the canal's back wall a deep
/// warm mucosa thrown into palmate folds, and the uterine cavity's paler;
/// the vagina's wall cut round its vault, its back wall's mucosa seen from
/// in front with its column and rugae; the arteries lit tubes in the blood
/// red, cut short.
abstract final class CervixStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the cervix's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// How far along the step from the body the body's half of the cervix is
  /// drawn in toward the cervix's own: more slowly than other specimens',
  /// the body's half being much wider than the cervix's (at 0.45 its
  /// outline jolted 1.53 px at 60 fps).
  static const double settling = 0.6;

  /// How finely the edges, folds, crypts and tubes are followed, and the
  /// seed the folds, crypts and branches are laid by.
  static const double edgeStep = 0.3;
  static const int seed = 29;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom goes in, the ectocervix: one flat tone, the mark over a
  /// neutral, as the bladder's urothelium is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cut faces: the cervix's stroma, pale and fibrous, and the uterus's
  /// muscle, grey and a little warm.
  static const double stromaLit = 0.6;
  static const double stromaWarmth = 0.07;
  static const double muscleLit = 0.36;
  static const double muscleWarmth = 0.3;

  /// The mucosae seen from in front: the canal's, deep and warm; the
  /// uterine cavity's, paler; the vagina's, deep, lying back behind the
  /// vaginal part.
  static const double canalLit = 0.34;
  static const double canalWarmth = 0.36;
  static const double cavityLit = 0.4;
  static const double cavityWarmth = 0.32;
  static const double vaginaLit = 0.38;
  static const double vaginaWarmth = 0.26;

  /// The vagina's wall, cut: its epithelium a pale line, its lamina propria
  /// and its muscularis.
  static const double vaginaEpitheliumLit = 0.64;
  static const double vaginaEpitheliumWarmth = 0.08;
  static const double vaginaLaminaLit = 0.52;
  static const double vaginaLaminaWarmth = 0.12;
  static const double vaginaMuscleLit = 0.3;
  static const double vaginaMuscleWarmth = 0.38;

  /// The Nabothian cysts, cut: pale, their rim in the shadow ink, a hair of
  /// light on the side away from the lamp, where the cut cyst's hollow
  /// faces it.
  static const double cystLit = 0.68;
  static const double cystWarmth = 0.04;
  static const double cystRim = 0.12;
  static const double cystRimAlpha = 0.32;
  static const double cystLight = 0.78;
  static const double cystLightAlpha = 0.3;

  /// The arteries: lit tubes in the blood red eased toward the ground, as
  /// the other specimens' are; round each at these shares of its radius;
  /// a cut end's length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.5;

  // The lines.

  /// A crease along a fold, a crypt or a ruga, crisp in the shadow ink: how
  /// wide, how far it tapers in from each end, how dark, and never thinner
  /// than so many pixels. The light on a fold's far side, toward the lamp:
  /// how far over and how bright.
  static const double crease = 0.4;
  static const double creaseTaper = 1.2;
  static const double creaseAlpha = 0.3;
  static const double creaseFloor = 0.9;
  static const double ridge = 0.45;
  static const double ridgeLit = 0.75;
  static const double ridgeAlpha = 0.14;

  /// The lower half's finer folds, and the vagina's rugae, fainter.
  static const double finerAlpha = 0.18;
  static const double rugaAlpha = 0.16;

  /// The crypts: how wide, and how dark.
  static const double crypt = 0.3;
  static const double cryptAlpha = 0.2;

  /// The ridge down the canal's back wall, and the vagina's column: a pale
  /// band toward the lamp over a crease.
  static const double columnCrease = 0.45;
  static const double columnAlpha = 0.3;
  static const double columnLight = 0.6;
  static const double columnLightWidth = 0.6;
  static const double columnLightAlpha = 0.2;

  /// The rim of the canal and of the vagina's vault, sunk below the cut: a
  /// shadow just inside the edges that face the lamp, and light just inside
  /// those that turn from it.
  static const double rimShadow = 1;
  static const double rimLight = 0.6;
  static const double rimShadowAlpha = 0.34;
  static const double rimLightAlpha = 0.14;

  /// The vaginal part's shadow on the vagina's back wall below it: how far
  /// over and down, and how dark.
  static const double lipShadowX = 0.6;
  static const double lipShadowY = 1.4;
  static const double lipShadowAlpha = 0.3;

  /// The line inside the ectocervix where its epithelium meets the stroma,
  /// the transformation zone's edge, the line where the uterus's mucosa
  /// meets the canal's at the internal orifice, and the line between the
  /// cut and a mucosa: each in the shadow ink.
  static const double epitheliumAlpha = 0.34;
  static const double zoneLine = 0.12;
  static const double zoneAlpha = 0.42;
  static const double osLine = 0.12;
  static const double osAlpha = 0.24;
  static const double coatLine = 0.1;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the cervix and the vagina cast.

  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;

  // The names.

  /// How far a name keeps clear of a tube beside the cervix at its height,
  /// and how much of the tube must show for it to count: any of it that
  /// can be seen.
  static const double nameClear = 2;
  static const double nameShown = 0.1;
}
