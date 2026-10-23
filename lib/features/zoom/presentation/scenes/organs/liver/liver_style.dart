/// Every number the liver's look is tuned by, in one place. Lengths are in
/// millimetres of the real liver unless they say otherwise; the anatomy
/// itself is in `liver_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, cut open from front to back, in deep
/// tones that stand out among the body's faint parts round it: where the
/// zoom's cell lives flat in the mark, as the kidney's cortex is; else the
/// parenchyma a deep warm cut face, its edge turning away under the
/// capsule; the hepatic veins and the vena cava emptied, in shade, rimmed as
/// the heart's chambers are; the portal veins emptied too, each in its pale
/// sheath, the bile ducts in it in the home helix's honey and the arteries
/// in the blood red; the small vessels the cut crosses holes in the face,
/// the portal tracts among them in their sheaths; the gallbladder cut open,
/// its wall pale and its bile honey in shade; the trunks lit tubes, cut
/// short below and above, the bile duct and the round ligament fading out.
abstract final class LiverStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the liver's outline the flat shape is drawn as it becomes the bed
  /// it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 360;
  static const double bed = 0.6;

  /// Over how much of its detail the body's outline is drawn in to the
  /// liver's: a little more than other specimens' (`SpecimenStep`), as the
  /// heart's, so that no point of it jolts (at the specimens' own 0.45, one
  /// moved 1.6 pixels a frame more than the frame before, over the 1.5 the
  /// zoom allows).
  static const double settling = 0.55;

  /// How finely the vessels' edges are followed.
  static const double edgeStep = 0.5;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The parenchyma, lit, warmed toward the home helix's clay, deeper and
  /// redder than the kidney's cortex.
  static const double parenchymaLit = 0.3;
  static const double parenchymaWarmth = 0.3;

  /// The emptied veins, as the kidney's calyces are.
  static const double cavityShade = 0.85;

  /// A portal sheath: pale, a little warm.
  static const double sheathLit = 0.62;
  static const double sheathWarmth = 0.12;

  /// The bile, toward the home helix's honey from the shade, and a duct
  /// beside a portal vein in it, in pixels at least.
  static const double bileShade = 0.55;
  static const double bileHoney = 0.55;
  static const double ductFloor = 0.7;
  static const double homeDuctFloor = 1.1;

  /// The gallbladder's wall, pale, as a cut face.
  static const double wallLit = 0.55;
  static const double wallWarmth = 0.1;

  /// The vessels outside the liver: lit tubes in the blood red eased toward
  /// the ground, the veins more, under a light a little dimmer than the
  /// liver's own, as the other specimens' are; round each at these shares
  /// of its radius; a cut end's length along its tube and its wall, shares
  /// of its width.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  /// An artery beside a portal vein, in pixels at least.
  static const double arteryFloor = 0.6;

  /// The bile duct and the round ligament outside the liver: lit tubes
  /// under the liver's own light; the bile duct in the honey, the ligament
  /// pale.
  static const double ductLit = 0.45;
  static const double ductHoney = 0.5;
  static const double ligamentLit = 0.55;
  static const double ligamentWarmth = 0.1;
  static const double paleLight = 0.9;

  // The cut face's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The parenchyma's edge under the capsule, turning away from the eye:
  /// how wide, and how far its middle and its outer edge turn.
  static const double rim = 2.4;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // A rim round the emptied veins: a shadow just inside their edges that
  // face the lamp, and light just inside those that turn from it, as the
  // heart's chambers have.

  static const double lipShadow = 1.6;
  static const double lipShadowAlpha = 0.7;
  static const double lipLight = 0.8;
  static const double lipLightAlpha = 0.3;
  static const double lipLit = 0.7;

  // The small vessels.

  /// How far a small vessel keeps from a large one's wall or sheath, the
  /// capsule, the gallbladder and the site, past its own radius.
  static const double smallClear = 2;
  static const double siteClear = 7;

  /// How far a small portal tract's sheath reaches past its vein.
  static const double smallSheath = 1;
  static const int seed = 31;

  // The lines.

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The crisp line round each emptied vein, in the shadow ink.
  static const double edgeLine = 0.15;
  static const double edgeLineFloor = 0.6;
  static const double edgeLineAlpha = 0.45;

  // The shadow the liver casts.

  static const double shadowX = 2;
  static const double shadowY = 3;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 5;

  // The names.

  /// How far the names keep clear of a tube beside the liver, and how much
  /// of it must show for it to count: any of it that can be seen.
  static const double nameClear = 4;
  static const double nameShown = 0.1;
}
