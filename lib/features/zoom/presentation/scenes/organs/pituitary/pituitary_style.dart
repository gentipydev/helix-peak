/// Every number the pituitary's look is tuned by, in one place. Lengths are
/// in millimetres of the real gland unless they say otherwise; the anatomy
/// itself is in `pituitary_anatomy.dart`, and the light is the zoom's one
/// lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is the brain's own, cut down its middle, the part of it round
/// the pituitary seen closer: where the zoom's cell lives flat in the
/// mark, as the brain's cortex is; else the anterior lobe and the posterior
/// in the brain's tones for them, the posterior paler; the stalk and the
/// hypothalamus in the brain's tone for the third ventricle's walls, the
/// chiasm white; the sphenoid bone cut in a deep ivory, the sinus
/// in it emptied, in shade, rimmed as the heart's chambers are; the dura of
/// the diaphragma sellae a pale line; the arteries in the blood red.
abstract final class PituitaryStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the gland's outline the flat shape is drawn as it becomes the bed
  /// it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 200;
  static const double bed = 0.1;

  /// How finely the parts' edges and the vessels are followed.
  static const double edgeStep = 0.08;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`): the brain's
  // own for what the brain draws.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the brain's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The brain's tones: its anterior and posterior lobes, the third
  /// ventricle's walls, white matter lifted past its tone, cut grey.
  static const double anteriorLit = 0.38;
  static const double posteriorLit = 0.52;
  static const double wallLit = 0.5;
  static const double whiteLit = 0.74;
  static const double whiteGain = 1.22;
  static const double greyLit = 0.56;

  /// The sphenoid bone, cut, in an ivory a little deeper than the femur's,
  /// so the gland stands out on it; its sinus emptied; the dura pale.
  static const double boneLit = 0.46;
  static const double sinusShade = 0.72;
  static const double duraLit = 0.62;

  /// The arteries: lit tubes in the blood red eased toward the ground,
  /// under a light a little dimmer than the gland's own; round each at
  /// these shares of its radius.
  static const double artery = 0.25;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];

  // The relief each part is lit by.

  /// The grids the reliefs are solved on and the meshes laid on, for the
  /// small parts and for the bone; how high they stand; how many sweeps.
  static const double reliefCell = 0.07;
  static const double meshCell = 0.07;
  static const double boneCell = 0.22;
  static const double boneMesh = 0.2;
  static const double reliefInflation = 0.5;

  /// How many cells at most a part's grid has along its longest side.
  static const double gridMost = 160;
  static const double boneInflation = 0.25;
  static const int reliefSweeps = 200;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  // A rim round the sinus: a shadow just inside its edges that face the
  // lamp, and light just inside those that turn from it.

  static const double lipShadow = 0.7;
  static const double lipShadowAlpha = 0.65;
  static const double lipLight = 0.35;
  static const double lipLightAlpha = 0.3;
  static const double lipLit = 0.7;

  // The lines.

  /// The cleft between the pars anterior and the pars intermedia, and the
  /// dura, in pixels at least.
  static const double cleft = 0.05;
  static const double cleftFloor = 0.8;
  static const double cleftAlpha = 0.5;
  static const double dura = 0.12;
  static const double duraFloor = 1;

  /// The parts' edges, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the gland casts.

  static const double shadowX = 0.15;
  static const double shadowY = 0.25;
  static const double shadowAlpha = 0.3;
  static const double shadowSoft = 0.4;

  // The names.

  /// How far the names keep from a vessel.
  static const double nameClear = 0.4;
}
