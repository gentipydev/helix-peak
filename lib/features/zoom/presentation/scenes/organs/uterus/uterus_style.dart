/// Every number the uterus's look is tuned by, in one place. Lengths are in
/// millimetres of the real uterus unless they say otherwise; the anatomy
/// itself is in `uterus_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, bivalved, in deep tones that stand out
/// among the body's faint parts round it: its endometrium, where the zoom's
/// cell lives, flat in the mark, as the cervix's ectocervix is, cut by its
/// anatomy as crisp lines (its glands running out from the cavity, the
/// line its basal layer meets its functional layer at, the openings of its
/// glands on the cavity's back wall); round it the muscle, cut, grey and a
/// little warm, the vessels of its middle layer cut across in it; below the
/// isthmus the cervix as the cervix specimen draws it, its stroma pale and
/// fibrous, its canal a deep warm mucosa thrown into palmate folds; the
/// tubes and the ovarian ligaments lit, running out and fading; the
/// arteries lit tubes in the blood red, cut short.
abstract final class UterusStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the uterus's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// How far along the step from the body the body's endometrium is drawn
  /// in toward the uterus's outline: more slowly than most specimens', the
  /// body's drawing being half as wide again as the uterus (at 0.6 its
  /// outline jolted 1.71 px at 60 fps).
  static const double settling = 0.7;

  /// How finely the edges, glands and tubes are followed, and the seed the
  /// glands, pits, vessels and branches are laid by.
  static const double edgeStep = 0.3;
  static const int seed = 41;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives, the endometrium: one flat tone, the mark
  /// over a neutral, as the cervix's ectocervix is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cut faces: the muscle, grey and a little warm, and the cervix's
  /// stroma below the isthmus, pale and fibrous, as the cervix specimen's.
  static const double muscleLit = 0.36;
  static const double muscleWarmth = 0.3;
  static const double stromaLit = 0.6;
  static const double stromaWarmth = 0.07;

  /// The canal's mucosa, seen from in front, deep and warm, as the cervix
  /// specimen's.
  static const double canalLit = 0.34;
  static const double canalWarmth = 0.36;

  /// The vessels of the muscle's middle layer, cut across: their lumens in
  /// the shadow ink, and their walls a hair of the bright ink.
  static const double vesselAlpha = 0.55;
  static const double vesselWallLit = 0.6;
  static const double vesselWallAlpha = 0.3;
  static const double vesselWall = 0.14;

  /// The tube's intramural part, cut along: its lumen in the shadow ink,
  /// its lining a pale line round it.
  static const double intramuralAlpha = 0.5;
  static const double intramuralLining = 0.18;
  static const double intramuralLiningLit = 0.62;
  static const double intramuralLiningAlpha = 0.4;

  /// The tubes and the ligaments, lit: the tube's serosa pale and a little
  /// warm, the ligament pale and fibrous.
  static const double tubeLit = 0.52;
  static const double tubeWarmth = 0.22;
  static const double ligamentLit = 0.56;
  static const double ligamentWarmth = 0.1;

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

  /// A crease along a fold or a gland, crisp in the shadow ink: how wide,
  /// how far it tapers in from each end, how dark, and never thinner than
  /// so many pixels. The light on a fold's far side, toward the lamp: how
  /// far over and how bright.
  static const double crease = 0.4;
  static const double creaseTaper = 1.2;
  static const double creaseAlpha = 0.3;
  static const double creaseFloor = 0.9;
  static const double ridge = 0.45;
  static const double ridgeLit = 0.75;
  static const double ridgeAlpha = 0.14;

  /// The endometrium's glands: how wide, and how dark.
  static const double gland = 0.18;
  static const double glandAlpha = 0.26;

  /// The openings of its glands on the cavity's back wall: how dark, and
  /// never smaller across than so many pixels.
  static const double pitAlpha = 0.2;
  static const double pitFloor = 0.5;

  /// The line its basal layer meets its functional layer at, and the line
  /// where it meets the muscle.
  static const double basalLine = 0.1;
  static const double basalAlpha = 0.22;
  static const double junctionLine = 0.14;
  static const double junctionAlpha = 0.4;

  /// The canal's palmate folds and the crypts running from it, as the
  /// cervix specimen's.
  static const double foldAlpha = 0.26;
  static const double crypt = 0.3;
  static const double cryptAlpha = 0.2;

  /// The Nabothian cysts, cut: pale, their rim in the shadow ink.
  static const double cystLit = 0.68;
  static const double cystWarmth = 0.04;
  static const double cystRim = 0.12;
  static const double cystRimAlpha = 0.32;

  /// The rim of the cavity and the canal, sunk below the cut: a shadow just
  /// inside the edges that face the lamp, and light just inside those that
  /// turn from it.
  static const double rimShadow = 1;
  static const double rimLight = 0.6;
  static const double rimShadowAlpha = 0.34;
  static const double rimLightAlpha = 0.14;

  /// The squamous epithelium on the vaginal part, the internal orifice, and
  /// the line between the cut and a mucosa: each in the shadow ink.
  static const double epithelium = 0.25;
  static const double epitheliumAlpha = 0.3;
  static const double osLine = 0.12;
  static const double osAlpha = 0.24;
  static const double coatLine = 0.1;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the uterus casts.

  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;

  // The names.

  /// How far a name keeps clear of a tube beside the uterus at its height,
  /// and how much of the tube must show for it to count.
  static const double nameClear = 2;
  static const double nameShown = 0.3;
}
