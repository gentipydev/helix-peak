/// Every number the aorta's look is tuned by, in one place. Lengths are in
/// millimetres of the real aorta unless they say otherwise; the anatomy
/// itself is in `aorta_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, in place, in deep tones: the coat the
/// zoom's cell lives in flat in the mark, as every specimen's home is, cut
/// by its anatomy as crisp lines (the media's lamellae, the vasa vasorum on
/// the adventitia, the intercostal openings in the intima); the other coats
/// warm neutrals, the adventitia lit as the aorta rounds, the media bared
/// in the window a deeper tan, the intima pale and glistening through the
/// inner window, sunk below the cut; round it the vertebral bodies in the
/// bone's ivory and the discs paler, fading out above and below; the
/// intercostal arteries lit tubes in the blood red, the azygos and the
/// hemiazygos in the veins' darker red, the thoracic duct pale.
abstract final class AortaStyle {
  /// How finely the tubes, the windows and the lines are followed, and the
  /// seed the vasa vasorum are laid by.
  static const double edgeStep = 0.3;
  static const int seed = 61;

  /// Where across what is drawn the scene's origin is laid: near the
  /// aorta's middle, so that the names in the column on its left, the
  /// body's, have room on the narrowest phones (at 3.5 mm, between the
  /// column's middle and the aorta's, the adventitia's name had none).
  static const double middleX = 8;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as every specimen's home is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The coats: the adventitia, yellowish white, lit as the aorta rounds;
  /// the media, a deeper tan; the intima, pale and glistening.
  static const double adventitiaLit = 0.58;
  static const double adventitiaWarmth = 0.22;
  static const double mediaLit = 0.42;
  static const double mediaWarmth = 0.32;
  static const double intimaLit = 0.7;
  static const double intimaWarmth = 0.06;

  /// The column: the vertebral bodies in the bone's ivory, the discs paler
  /// and cooler, and their edges.
  static const double boneLit = 0.48;
  static const double boneWarmth = 0.22;
  static const double discLit = 0.68;
  static const double discWarmth = 0.02;
  static const double boneEdgeAlpha = 0.45;

  /// The vessels beside it: arteries in the blood red eased toward the
  /// ground, veins further, the duct pale with a hair of honey; round each
  /// at these shares of its radius.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double ductLit = 0.62;
  static const double ductHoney = 0.18;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];

  /// The aorta's cut ends: their length along it and their wall, shares of
  /// its width.
  static const double endLength = 0.42;
  static const double endWall = 0.2;

  // The lines.

  /// The media's lamellae, bared in the window: how wide, how dark, and
  /// never thinner than so many pixels.
  static const double lamella = 0.1;
  static const double lamellaAlpha = 0.2;
  static const double lineFloor = 0.5;

  /// The vasa vasorum: in the blood red eased this far, at this alpha.
  static const double vasa = 0.4;
  static const double vasaAlpha = 0.45;

  /// The adventitia's cut edge round the outer window, turned back: a pale
  /// band, and its shadow on the media inside it.
  static const double turnedBack = 0.6;
  static const double turnedBackLit = 0.66;
  static const double turnedBackAlpha = 0.7;
  static const double turnedShadow = 0.5;
  static const double turnedShadowAlpha = 0.28;

  /// The intima's cut edge round the inner window, a pale line; the rim
  /// of the opening, sunk below the cut.
  static const double intimaEdge = 0.2;
  static const double intimaEdgeAlpha = 0.55;
  static const double rimShadow = 1.2;
  static const double rimLight = 0.6;
  static const double rimShadowAlpha = 0.4;
  static const double rimLightAlpha = 0.14;
  static const double ridgeLit = 0.75;

  /// The intercostal openings: in the shadow ink, a pale lip below each.
  static const double ostiumAlpha = 0.7;
  static const double ostiumLip = 0.15;
  static const double ostiumLipAlpha = 0.4;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the aorta casts on the column.

  static const double shadowX = 1.2;
  static const double shadowY = 1.6;
  static const double shadowAlpha = 0.32;
  static const double shadowSoft = 2.5;

  // The names.

  /// How far a name's column keeps clear of what is drawn at its height,
  /// and how much of a tube must show for it to count.
  static const double nameClear = 2;
  static const double nameShown = 0.3;
}
