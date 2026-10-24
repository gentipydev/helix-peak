/// Every number the fallopian tube's look is tuned by, in one place.
/// Lengths are in millimetres of the real tube unless they say otherwise;
/// the anatomy itself is in `fallopian_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, opened along its length, in deep tones
/// that stand out among the body's faint parts round it: where the zoom's
/// cell lives flat in the mark, as the stomach's mucosa is, the folds crisp
/// cut lines over it; else the mucosa a deep warm pink-grey; the wall's cut
/// edges, its muscle, warmed toward the clay as the stomach's is; the
/// tube's outside a lit tube; the fimbriae lit fingers; the mesosalpinx a
/// thin pale sheet; the artery in the blood red.
abstract final class FallopianStyle {
  // The outline, and the step from the body.

  /// How finely the tube is followed, how many points the step from the
  /// body morphs round it by, and how far in from the tube's outline the
  /// flat shape is drawn as it becomes the bed it lies on.
  static const double edgeStep = 0.3;
  static const int morphPoints = 360;
  static const double bed = 0.5;

  /// Over how much of its detail the body's outline is drawn in to the
  /// tube's: more than other specimens' (`SpecimenStep`, 0.45), more than
  /// the liver's and the thigh's, the tube being much thinner than the
  /// outline it is drawn in from, fimbriae and all (at 0.55 a point of it
  /// moved 1.68 pixels a frame more than the frame before, at 0.65 1.56,
  /// over the 1.5 the zoom allows).
  static const double settling = 0.75;

  // The tones.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the stomach's mucosa is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The mucosa, where it is not the home: pink-grey, warmed toward the
  /// clay; the wall's muscle, deeper and warmer; the serosa, the outside.
  static const double mucosaLit = 0.36;
  static const double mucosaWarmth = 0.24;
  static const double muscleLit = 0.28;
  static const double muscleWarmth = 0.42;
  static const double serosaLit = 0.36;
  static const double serosaWarmth = 0.22;

  /// The mesosalpinx: pale, see-through, fading out below.
  static const double sheetLit = 0.5;
  static const double sheetAlpha = 0.2;

  /// The artery: lit, in the blood red eased toward the ground; round each
  /// tube at these shares of its radius.
  static const double artery = 0.25;
  static const double tubeLight = 0.75;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];

  /// How much a cut face shines.
  static const double cutSheen = 0.6;

  // The lines.

  /// The folds: in the shadow ink, in pixels at least.
  static const double fold = 0.08;
  static const double foldFloor = 0.7;
  static const double foldAlpha = 0.34;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the tube casts.

  static const double shadowX = 0.8;
  static const double shadowY = 1.2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2;

  // The names.

  /// How far the names keep from what is drawn.
  static const double nameClear = 1.6;
}
