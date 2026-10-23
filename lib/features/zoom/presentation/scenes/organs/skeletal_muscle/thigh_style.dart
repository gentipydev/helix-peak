/// Every number the thigh's look is tuned by, in one place. Lengths are in
/// millimetres of the real thigh unless they say otherwise; the anatomy
/// itself is in `thigh_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a dissection's, the skin, the fat and the fascia lata taken
/// away but for its iliotibial tract, in deep tones that stand out among
/// the body's faint parts round it: the vastus lateralis flat in the mark,
/// as the brain's cortex and the heart's muscle are, its fascicles crisp
/// creases over it; every other muscle lit as a rounded form under the
/// lamp, its fascicles faint grooves running its own way; the tendons and
/// the patella pale and glossy; the femoral artery and vein in the blood
/// red and the nerve in the home helix's honey, as the other specimens'
/// are.
abstract final class ThighStyle {
  // The outline, and the step from the body.

  /// How far apart the outline's points are followed, how many the step
  /// from the body morphs round it by, and how far in from the vastus
  /// lateralis's outline the flat shape is drawn as it becomes its bed.
  static const double outlineStep = 1;
  static const int morphSpan = 8;
  static const int morphPoints = 360;
  static const double bed = 0.6;

  /// Over how much of its detail the body's outline is drawn in to the
  /// vastus lateralis's: more than other specimens' (`SpecimenStep`), since
  /// the anatomogram's thin strip widens about three times into it.
  static const double settling = 0.7;

  /// How finely the muscles' outlines are followed between their knots.
  static const int knotSpan = 8;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`).

  /// The vastus lateralis: one flat tone, the mark over a neutral, as the
  /// brain's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The other muscles, lit, warmed toward the home helix's clay, as the
  /// chromosome's chromatin is toward its honey: `lit` alone runs to the
  /// cool bright ink.
  static const double muscleLit = 0.36;
  static const double muscleWarmth = 0.2;

  /// What lies deeper, where the muscles part, in shade
  /// (`ZoomInks.shade`), as the other specimens' crevices are.
  static const double deepShade = 0.55;

  /// The tendons, the iliotibial tract and the patella: pale, glossy; the
  /// retinacula round the patella a little deeper, so it stands out.
  static const double tendonLit = 0.62;
  static const double tractLit = 0.58;
  static const double patellaLit = 0.6;
  static const double retinaculumLit = 0.48;

  /// The vessels and the nerve: lit tubes in the blood red eased toward the
  /// ground, the vein more, and in the honey eased a little, under a light
  /// a little dimmer than the muscles', as the other specimens' are; round
  /// each at these shares of its radius.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double nerve = 0.05;
  static const double tubeLight = 0.7;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];

  /// How far the femoral vessels and the nerve's branches fade out under
  /// the sartorius, from their ends.
  static const double tubeFade = 30;

  // The muscles' forms: each inflated as a cushion from its outline, on a
  // grid this fine, and laid as a lit mesh on a grid this fine.

  static const double reliefCell = 2.5;
  static const double reliefInflation = 0.35;
  static const int reliefSweeps = 90;
  static const double meshCell = 2;

  /// How much of the lamp the tendons and the patella take, and how much
  /// they shine.
  static const double tendonLight = 0.9;
  static const double tendonSheen = 0.6;

  // The fascicles.

  /// How far apart the fascicles are drawn, across them.
  static const double fascicle = 5;

  /// Over the vastus lateralis, crisp creases in the shadow ink: how wide,
  /// in pixels at least, and how strong.
  static const double crease = 0.3;
  static const double creaseFloor = 0.8;
  static const double creaseAlpha = 0.32;

  /// Over the other muscles, a groove in the shadow ink and the light along
  /// its side, a share of the spacing away, as the masseter's are.
  static const double grooveShade = 0.16;
  static const double grooveLight = 0.07;
  static const double ridge = 0.35;

  /// The iliotibial tract's and the tendons' fine lines along them.
  static const double strandAlpha = 0.1;

  // The lines.

  /// Where one muscle lies on another, a crisp line in the shadow ink: how
  /// wide, in pixels at least, and how strong.
  static const double border = 0.35;
  static const double borderFloor = 0.9;
  static const double borderAlpha = 0.55;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the thigh casts.

  static const double shadowX = 2;
  static const double shadowY = 3.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 5;
}
