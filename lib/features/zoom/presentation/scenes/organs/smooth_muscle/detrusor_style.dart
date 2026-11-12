import '../bladder/bladder_style.dart';

/// Every number the smooth muscle's look is tuned by, in one place. Lengths
/// are in millimetres of the bladder specimen's frame unless they say
/// otherwise; the anatomy itself is in `detrusor_anatomy.dart`, and the
/// light is the zoom's one lamp (`SpecimenLamp.zoom`), the other
/// specimens'.
///
/// The look is a dissection's, the peritoneum and the fat taken away: the
/// detrusor, where the zoom's cell lives, flat in the mark over the whole
/// bladder, as the thigh's vastus lateralis is, its bundles crisp creases
/// over it; the patch cut from the outer layer rimmed as an opening is,
/// shadow toward the lamp and light away from it, the circular layer's
/// bundles creases in it; the ureters and the urethra lit tubes, pale, the
/// urachus a pale cord, and the arteries lit tubes in the blood red
/// ramifying over the wall, each cut short.
abstract final class DetrusorStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the bladder's outline the flat shape is drawn as it becomes the
  /// bed it lies on: the bladder specimen's.
  static const int outlineSpan = BladderStyle.outlineSpan;
  static const int morphPoints = BladderStyle.morphPoints;
  static const double bed = BladderStyle.bed;

  /// How finely the bundles and the tubes are followed, and the seed the
  /// bundles' wandering is laid by.
  static const double edgeStep = 0.5;
  static const int seed = 29;

  // The tones.

  /// Where the zoom's cell lives, the whole muscle: one flat tone, the
  /// mark over a neutral, as the thigh's vastus lateralis is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The ureters and the urethra: lit tubes, pale and a little warm, as
  /// the bladder specimen's are; the urachus, a pale cord; under a light a
  /// little dimmer than a cut's own.
  static const double ductLit = BladderStyle.ductLit;
  static const double ductWarmth = BladderStyle.ductWarmth;
  static const double ductLight = BladderStyle.ductLight;
  static const double urachusLit = 0.55;
  static const double urachusWarmth = 0.06;

  /// The arteries: lit tubes in the blood red eased toward the ground, as
  /// the other specimens'; round each at these shares of its radius; a cut
  /// end's length along its tube and its wall, shares of its width.
  static const double artery = BladderStyle.artery;
  static const double tubeLight = BladderStyle.tubeLight;
  static const List<double> tubeColumns = BladderStyle.tubeColumns;
  static const double endLength = BladderStyle.endLength;
  static const double endWall = BladderStyle.endWall;

  // The bundles, cut into the flat tone as creases.

  /// The outer layer's bundles: crisp creases in the shadow ink, how wide,
  /// in pixels at least, and how strong; the oblique bundles fainter; the
  /// circular layer's and the sphincter's rings as the outer's.
  static const double crease = 0.35;
  static const double creaseFloor = 0.8;
  static const double creaseAlpha = 0.32;
  static const double obliqueAlpha = 0.2;

  /// The patch's rim: a shadow just inside its edge that faces the lamp,
  /// and light just inside the edge that turns from it, as the heart's
  /// chambers have; how far in each reaches and how strong; and the cut
  /// edge of the outer layer, a crisp line in the shadow ink, how wide, in
  /// pixels at least, and how strong.
  static const double lipShadow = 1.2;
  static const double lipLight = 0.9;
  static const double lipShadowAlpha = 0.55;
  static const double lipLightAlpha = 0.3;
  static const double lipLit = 0.7;
  static const double patchEdge = 0.12;
  static const double patchEdgeFloor = 0.6;
  static const double patchEdgeAlpha = 0.35;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the bladder casts, the bladder specimen's.

  static const double shadowX = BladderStyle.shadowX;
  static const double shadowY = BladderStyle.shadowY;
  static const double shadowAlpha = BladderStyle.shadowAlpha;
  static const double shadowSoft = BladderStyle.shadowSoft;

  // The names.

  /// How far the names keep clear of a tube beside the bladder, and how
  /// much of it must show for it to count.
  static const double nameClear = BladderStyle.nameClear;
  static const double nameShown = BladderStyle.nameShown;
}
