/// Every number the parathyroid's look is tuned by, in one place. Lengths
/// are in millimetres of the real gland unless they say otherwise; the
/// anatomy itself is in `parathyroid_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, in deep tones: where the zoom's cell
/// lives flat in the mark, as the kidney's cortex is (its chief cells, its
/// oxyphil nodules, or its fat); else the gland's cut face a tan brown,
/// paler and yellower than the thyroid it lies on, turning away under its
/// capsule, its oxyphil nodules a deeper, warmer brown, its fat pale
/// specks, its septa fine shadowed lines, its vessels finer lines in the
/// blood red; the lobe behind it lit in the thyroid specimen's own deep
/// red-brown, fading out round it; the artery and its branches lit tubes in
/// the blood red, going into the lobe; the nerve a lit cord in the home
/// helix's honey.
abstract final class ParathyroidStyle {
  /// How many points the gland's outline is followed by, and how finely
  /// the vessels and the nerve are.
  static const int outlinePoints = 220;
  static const double tubeRow = 0.08;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), warmed a share of the way toward the home
  // helix's clay, or its honey.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The parenchyma's cut face: Gray's brownish red, the tan a surgeon
  /// tells it from the thyroid by, paler and yellower than the lobe.
  static const double glandLit = 0.42;
  static const double glandWarmth = 0.2;
  static const double glandHoney = 0.18;

  /// The oxyphil nodules, deeper and warmer, as their cells are dense
  /// with mitochondria.
  static const double oxyphilLit = 0.44;
  static const double oxyphilWarmth = 0.34;

  /// The fat: pale, a little toward the honey; and where it is the cell's
  /// home, in the mark.
  static const double fatLit = 0.72;
  static const double fatHoney = 0.2;
  static const double fatAlpha = 0.75;

  /// The thyroid lobe behind it, the thyroid specimen's own tone.
  static const double lobeLit = 0.3;
  static const double lobeWarmth = 0.34;

  /// The nerve: the honey eased toward the ground, as the salivary gland's
  /// facial nerve is, but more: it is wide; the vessels in the blood red eased toward the
  /// ground, the veins more; their lit tubes under a light a little
  /// dimmer than the gland's own, round each at these shares of its radius.
  static const double nerve = 0.15;
  static const double nerveLight = 0.8;
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];

  // The relief the lobe is lit by.

  static const double reliefCell = 0.4;
  static const double meshCell = 0.3;
  static const double reliefInflation = 0.75;
  static const int reliefSweeps = 220;

  // The cut face's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The cut face's edge under the capsule, turning away from the eye:
  /// how wide, and how far its middle and its outer edge turn.
  static const double rim = 0.3;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // The lines.

  /// The septa: in the shadow ink, how wide, and in pixels at least.
  static const double septum = 0.035;
  static const double septumFloor = 0.6;
  static const double septumAlpha = 0.32;

  /// The vessels in the gland: how wide, in pixels at least, the veins a
  /// little apart from the arteries.
  static const double vessel = 0.05;
  static const double vesselFloor = 0.7;
  static const double veinApart = 0.07;

  /// The crisp line round each oxyphil nodule, in the shadow ink.
  static const double edgeLine = 0.03;
  static const double edgeLineFloor = 0.6;
  static const double edgeLineAlpha = 0.3;

  /// The fat cells' pixel floor, and where the fat is the cell's home.
  static const double fatFloor = 1;
  static const double homeFatFloor = 1.3;

  /// How far a fat cell keeps inside the capsule and out of a nodule.
  static const double fatClear = 0.12;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The lobe's medial border: a soft line where its surface turns away.
  static const double lobeEdgeAlpha = 0.45;

  /// The fat's places, the same every time.
  static const int seed = 71;

  // The shadow the gland casts on the lobe.

  static const double shadowX = 0.15;
  static const double shadowY = 0.25;
  static const double shadowAlpha = 0.4;
  static const double shadowSoft = 0.35;

  // The names.

  /// How far along the step on to the tissue its names are gone by: a
  /// little more than other organs' (`OrganScene.leaving`, 0.24), as the
  /// gland's step to its tissue is short, so that none blinks out (at 0.24
  /// the home's faded 0.0806 a frame at 60 fps, over the 0.08 the zoom
  /// allows), as the lymph node's are.
  static const double namesLeaving = 0.27;

  /// Above what share of the way in a tube is set clear of names, and how
  /// far they keep from it.
  static const double nameShown = 0.1;
  static const double nameClear = 0.35;
}
