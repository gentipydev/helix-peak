/// Every number the tongue's look is tuned by, in one place. Lengths are in
/// millimetres of the real tongue unless they say otherwise; the anatomy
/// itself is in `tongue_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh section's, in deep tones: the intrinsic muscle,
/// where the zoom's cell lives, flat in the mark, as the thigh's vastus
/// lateralis and the detrusor are, its fibres crisp creases over it, the
/// transverse sheets and the vertical fibres woven, the longitudinal layers
/// cut across as a fine cobble; the extrinsic muscles and the floor's cut
/// faces in the thigh's warmed muscle tone, their fibres faint grooves; the
/// mucous membrane pale and warm, its papillae a comb over the back; the
/// sublingual gland in lobules; the mandible's cortex a mid ivory over its
/// spongy bone in shade, the molar's enamel pale and glossy over its
/// dentine; the vessels cut across in the blood red, the nerves in the home
/// helix's honey.
abstract final class TongueStyle {
  // The outline, and the step from the body.

  /// How many points each span of the outline's knots is followed by, how
  /// many the step from the body morphs round it by, and how far in from
  /// the outline the flat shape is drawn as it becomes its bed.
  static const int outlineSpan = 8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// Over how much of its detail the body's outline is drawn in to the
  /// tongue's own (`SpecimenStep`).
  static const double settling = 0.55;

  /// How finely an open curve is followed, in millimetres.
  static const double step = 0.25;

  /// The seeds the cobbles and the trabeculae are laid by.
  static const int seed = 47;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), warmed a share of the way toward the home helix's
  // clay.

  /// The intrinsic muscle: one flat tone, the mark over a neutral, as the
  /// thigh's vastus lateralis is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The other muscles' cut faces, as the thigh's other muscles.
  static const double muscleLit = 0.36;
  static const double muscleWarmth = 0.2;

  /// What fills the floor between the muscles and round the vessels: loose
  /// tissue and fat, deep, a little toward the honey.
  static const double looseLit = 0.27;
  static const double looseHoney = 0.16;

  /// The mucous membrane, as the stomach's; the aponeurosis and the septum
  /// paler; the gingiva a little warmer.
  static const double mucosaLit = 0.58;
  static const double mucosaWarmth = 0.12;
  static const double fibrousLit = 0.66;
  static const double fibrousWarmth = 0.06;
  static const double gingivaLit = 0.56;
  static const double gingivaWarmth = 0.18;

  /// The sublingual gland's lobules.
  static const double glandLit = 0.42;
  static const double glandWarmth = 0.18;

  /// The mandible: its cortex a mid ivory, as the femur's; its spongy bone's
  /// spaces in shade, its trabeculae lit lines.
  static const double cortexLit = 0.5;
  static const double cortexWarmth = 0.14;
  static const double spongyShade = 0.45;
  static const double trabeculaLit = 0.42;
  static const double trabeculaWarmth = 0.12;

  /// How much of each space of the spongy bone is marrow, the rest of it
  /// the trabeculae round it: between these shares of the cell.
  static const double spaceLeast = 0.5;
  static const double spaceMost = 0.9;

  /// The molar: enamel pale, dentine a warmer ivory, the pulp in the blood
  /// red eased toward the ground.
  static const double enamelLit = 0.84;
  static const double enamelWarmth = 0.04;
  static const double dentineLit = 0.56;
  static const double dentineWarmth = 0.12;
  static const double pulp = 0.64;

  /// The periodontal ligament round the root, a dark hairline, and the
  /// lamina dura round it in the cortex's tone.
  static const double ligament = 0.22;
  static const double ligamentAlpha = 0.55;
  static const double laminaDura = 0.5;

  /// The vessels and the nerves cut across: the artery in the blood red
  /// eased toward the ground, the veins more; the nerves in the honey eased
  /// a little; the duct pale; each lumen in shade, a share of its radius.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double nerve = 0.36;
  static const double ductLit = 0.6;
  static const double arteryLumen = 0.42;
  static const double veinLumen = 0.66;
  static const double ductLumen = 0.5;
  static const double lumenShade = 0.85;

  /// The cut face's sheen, a share of a fresh surface's.
  static const double cutSheen = 0.6;

  // Lines.

  /// The intrinsic muscle's fibres: creases in the shadow ink, never
  /// thinner than a pixel or so; the cobbles of the fibres cut across
  /// fainter.
  static const double crease = 0.14;
  static const double creaseFloor = 0.8;
  static const double creaseAlpha = 0.3;
  static const double cobbleAlpha = 0.22;

  /// The other muscles' fibres: grooves, fainter.
  static const double groove = 0.16;
  static const double grooveFloor = 0.7;
  static const double grooveAlpha = 0.2;

  /// The gland's lobules' borders.
  static const double lobuleAlpha = 0.32;

  /// The edges between the parts: a fine shadowed line.
  static const double seam = 0.12;
  static const double seamFloor = 0.6;
  static const double seamAlpha = 0.32;

  /// The sulcus's cleft: in shade, a lip of light on its far side.
  static const double cleftShade = 0.85;
  static const double lipShadow = 0.5;
  static const double lipLight = 0.4;
  static const double lipShadowAlpha = 0.5;
  static const double lipLightAlpha = 0.3;
  static const double lipLit = 0.7;

  /// The outline's edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow.

  /// The shadow under it: offset down and to the right, away from the
  /// lamp, and softened.
  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;

  // The names.

  /// How much room the names keep from what they are set round.
  static const double nameClear = 1.5;
}
