/// Every number the gallbladder's look is tuned by, in one place. Lengths
/// are in millimetres of the real gallbladder unless they say otherwise;
/// the anatomy itself is in `gallbladder_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, laid open from the front, in deep tones
/// that stand out among the body's faint parts round it: its mucosa, where
/// the zoom's cell lives, flat in the mark, as the bladder's urothelium is,
/// cut by its anatomy as crisp lines (the honeycomb's folds and the neck's
/// and the cystic duct's oblique folds, each a crease with the light on its
/// far side); the cut wall a band round it of its coats, the perimuscular
/// tissue pale and the fibromuscular coat between a fibrous pale and a
/// muscle's warm; the cystic duct laid open on with it, its wall pale; the
/// hepatic and bile duct a lit tube in the honey the liver draws its bile
/// ducts in, and the cystic artery a lit tube in the blood red, each cut
/// short.
abstract final class GallbladderStyle {
  // The outline, and the step from the body.

  /// How finely the outline is followed, in millimetres; how many points
  /// the step from the body morphs round it by; and how far in from the
  /// gallbladder's outline the flat shape is drawn as it becomes the bed it
  /// lies on.
  static const double outlineStep = 0.8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// How far along the step from the body the body's outline is drawn in
  /// toward the gallbladder's own: more slowly than most specimens', the
  /// body's comma being much broader than the gallbladder's neck (at 0.45
  /// its outline jolted 1.52 px at 60 fps).
  static const double settling = 0.55;

  /// How finely the tubes and the folds are followed, and the seed the
  /// honeycomb is laid by.
  static const double edgeStep = 0.4;
  static const int seed = 31;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the bladder's urothelium is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cut wall's coats: the perimuscular tissue pale, the fibromuscular
  /// coat between a fibrous pale and a muscle's warm, the serosa paler
  /// still; the cystic duct's wall as the perimuscular tissue.
  static const double perimuscularLit = 0.56;
  static const double perimuscularWarmth = 0.1;
  static const double muscleLit = 0.34;
  static const double muscleWarmth = 0.36;
  static const double serosaLit = 0.62;
  static const double serosaWarmth = 0.08;

  /// The hepatic and bile duct: a lit tube in the honey, as the liver's
  /// bile duct outside it is.
  static const double ductLit = 0.45;
  static const double ductHoney = 0.5;

  /// The artery: a lit tube in the blood red eased toward the ground, as
  /// the other specimens' are; round each tube at these shares of its
  /// radius; a cut end's length along its tube and its wall, shares of its
  /// width.
  static const double artery = 0.25;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  // The mucosa's anatomy, cut into it.

  /// The honeycomb's folds: the crease along each, crisp in the shadow
  /// ink, how wide and how dark, and the light on its far side, toward the
  /// lamp, how far over and how bright; neither thinner than so many
  /// pixels. They are laid over the mark's flat tone, so drawn as the
  /// colours they make there.
  static const double mesh = 0.3;
  static const double meshAlpha = 0.24;
  static const double meshLight = 0.3;
  static const double meshLightLit = 0.75;
  static const double meshLightAlpha = 0.1;
  static const double meshFloor = 0.8;

  /// The neck's and the cystic duct's oblique folds: the crease along each,
  /// how wide, how far it tapers in from each end, how dark, and never
  /// thinner than so many pixels; the light on its far side, how far over
  /// and how bright.
  static const double fold = 0.5;
  static const double foldTaper = 1.2;
  static const double foldAlpha = 0.34;
  static const double foldFloor = 0.9;
  static const double foldLight = 0.45;
  static const double foldLightLit = 0.75;
  static const double foldLightAlpha = 0.16;

  /// The mucosa, the home, along the cut wall: never thinner than so many
  /// pixels.
  static const double mucosaFloor = 1;

  // The lines.

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The line between the cut wall and the mucosa, in the shadow ink.
  static const double coatLine = 0.1;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  // The shadow the gallbladder casts.

  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;

  // The names.

  /// How far the names keep clear of a tube beside the gallbladder, and
  /// how much of it must show for it to count: any of it that can be seen.
  static const double nameClear = 2.5;
  static const double nameShown = 0.1;
}
