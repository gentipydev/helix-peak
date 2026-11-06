import '../../lobules.dart';
import 'breast_anatomy.dart';

/// Every number the breast's look is tuned by, in one place. Lengths are in
/// millimetres of the real breast unless they say otherwise; the anatomy
/// itself is in `breast_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a dissection's, in deep tones that stand out among the
/// body's faint parts round it: the upper half's skin a lit dome, pale and
/// a little warm, the areola and the nipple deeper and warmer on it, the
/// areolar glands small domes; the lower half's skin cut, a band of its
/// dermis under its paler epidermis, the upper skin's edge casting a thin
/// shadow on the dissection; the gland's lobes, and the ducts running in
/// to the nipple through the fibrous tissue under the areola, where the
/// zoom's cell lives flat in the mark, its lobules and its ducts cut into
/// it as crisp lines, else lit in a pale warm tone; the fat in lit lobules
/// between pale septa, or flat in the mark for a fat cell; the ligaments
/// paler strands through it; the pectoralis major lit round it, warmed
/// toward the home helix's clay as the thigh's muscles are, its fascicles
/// faint grooves, fading out with its distance from the breast; the
/// arteries lit tubes in the blood red, cut short.
abstract final class BreastStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the breast's outline the flat shape is drawn as it becomes the
  /// bed it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 300;
  static const double bed = 0.5;

  /// Over how much of its detail the body's oval is drawn in to the
  /// breast's mound: more than other specimens' (`SpecimenStep`), since the
  /// mound settles a centimetre above the oval.
  static const double settling = 0.7;

  /// How finely the ducts, the ligaments and the tubes are followed, and
  /// the seed the gland, the fat and the arteries' branches are laid by.
  static const double edgeStep = 0.4;
  static const int seed = 31;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the other specimens draw it.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The skin's surface, as the skin's block draws it; the areola and the
  /// nipple on it, deeper and warmer.
  static const double skinLit = 0.42;
  static const double skinWarmth = 0.18;
  static const double areolaLit = 0.28;
  static const double areolaWarmth = 0.38;
  static const double nippleLit = 0.25;
  static const double nippleWarmth = 0.42;

  /// The skin where it is cut, its epidermis paler over its dermis, as the
  /// skin's block draws them.
  static const double epidermisLit = 0.52;
  static const double epidermisWarmth = 0.1;
  static const double dermisLit = 0.3;
  static const double dermisWarmth = 0.24;

  /// The gland's lobes, "of a pale reddish color" (Gray), and its ducts,
  /// paler, where neither is where the zoom's cell lives.
  static const double glandLit = 0.4;
  static const double glandWarmth = 0.24;
  static const double ductLit = 0.52;
  static const double ductWarmth = 0.12;

  /// The fat's lobules, as the skin's block draws its fat; the septa and
  /// the fibrous tissue under the areola, as the fat block draws its
  /// septa; the ligaments paler still.
  static const double fatLit = 0.46;
  static const double fatWarmth = 0.14;
  static const double septumLit = 0.52;
  static const double septumWarmth = 0.1;
  static const double ligamentLit = 0.6;
  static const double ligamentWarmth = 0.08;

  /// The pectoralis major, lit, warmed as the thigh's other muscles are.
  static const double muscleLit = 0.36;
  static const double muscleWarmth = 0.2;

  /// The arteries: lit tubes in the blood red eased toward the ground, as
  /// the other specimens' are, under a light a little dimmer than the
  /// breast's own; round each at these shares of its radius; a cut end's
  /// length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double tubeLight = 0.7;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.4;

  // The forms: each inflated as a cushion from its outline, on a grid this
  // fine, and laid as a lit mesh on a grid this fine.

  /// The skin's dome over the whole breast; how much of a moist surface's
  /// sheen dry skin has.
  static const double skinReliefCell = 2;
  static const double skinInflation = 0.9;
  static const int skinSweeps = 140;
  static const double skinMeshCell = 1.5;
  static const double skinSheen = 0.45;

  /// The areola, a little raised on the dome, its rim turning away; the
  /// nipple, a dome standing on it; how many rings and ways round each is
  /// laid by.
  static const double areolaRise = 0.2;
  static const double nippleRise = 0.85;
  static const int rays = 48;

  /// The lobes' cushions, where they are not the home.
  static const double glandReliefCell = 1;
  static const double glandInflation = 0.25;
  static const int glandSweeps = 80;
  static const double glandMeshCell = 1;

  /// The pectoralis's cushion, and how far out from the breast it shows
  /// whole, and by where it has faded out; in how many steps of fading its
  /// grooves are drawn, and how long a step of a groove is.
  static const double muscleReliefCell = 4;
  static const double muscleInflation = 0.35;
  static const int muscleSweeps = 90;
  static const double muscleMeshCell = 2.5;
  static const double fadeFrom = 5;
  static const double fadeTo = 28;
  static const int fadeLevels = 6;
  static const double fibreStep = 3;

  /// Over the pectoralis, a groove in the shadow ink and the light along
  /// its side, a share of the spacing away, as the thigh's are; its border
  /// a little stronger.
  static const double grooveShade = 0.16;
  static const double grooveLight = 0.07;
  static const double ridge = 0.35;
  static const double borderShade = 0.3;

  /// The fat's lobules, laid in the dissection, and the cushion they lie
  /// on.
  static const LobuleStyle fat = LobuleStyle(
    spacing: BreastAnatomy.fatLobule,
    edgeStep: 0.92,
    edgeInset: 0.5,
    jitter: 0.22,
    clearOfEdge: 0.8,
    cap: 0.62,
    crevice: 0.35,
    cleft: 0.9,
    lobe: 20,
    rings: <double>[0.45, 0.8, 1],
    tilts: <double>[0.1, 0.28, 0.55],
    tilt: 0.05,
    cleftTilt: 0.14,
    lobeTilt: 0.12,
    nudge: 0.1,
    feather: 0.06,
    rimShade: 0.06,
    lobeTone: 0.04,
    lobuleTone: 0.03,
  );
  static const double fatReliefCell = 1.5;
  static const double fatInflation = 0.08;
  static const int fatSweeps = 100;

  // The lines.

  /// A lobe's edge where it meets the fat, a crisp line in the shadow ink:
  /// how wide, how strong, and never thinner than so many pixels.
  static const double lobeEdge = 0.3;
  static const double lobeEdgeAlpha = 0.3;
  static const double creaseFloor = 0.9;

  /// The ducts: their lumen, a crisp line along each in the shadow ink, how
  /// wide and how strong, there and where they are not the home; and the
  /// home's own floor, in pixels, so the ducts under the areola read as its
  /// tone.
  static const double lumen = 0.3;
  static const double lumenAlpha = 0.28;
  static const double lumenAlphaElsewhere = 0.2;
  static const double ductFloor = 1.6;

  /// The lobules: crisp dots in the shadow ink, how strong, there and where
  /// they are not the home, and never smaller across than so many pixels.
  static const double lobuleAlpha = 0.32;
  static const double lobuleAlphaElsewhere = 0.22;
  static const double lobuleFloor = 1.3;

  /// A ligament tapers in from its gland end over so many millimetres, and
  /// is never thinner than so many pixels.
  static const double ligamentTaper = 3;
  static const double ligamentFloor = 0.9;

  /// The upper skin's edge casts a shadow on the dissection: how far down,
  /// and how dark at the edge.
  static const double cutShadow = 3;
  static const double cutShadowAlpha = 0.28;

  /// The epidermis, along the cut and round the lower edge, never thinner
  /// than so many pixels.
  static const double epidermisFloor = 1;

  /// The areolar glands: each a small dome, its shadow cast away from the
  /// lamp so far and so dark; for a cell of the nipple and the areola, each
  /// a crisp ring this strong.
  static const double glandShadow = 0.3;
  static const double glandShadowAlpha = 0.22;
  static const double glandLight = 1.12;
  static const double ringAlpha = 0.3;

  /// The nipple's shadow on the areola, cast away from the lamp so far and
  /// so dark; its orifices, dark dots, and never smaller across than so many
  /// pixels.
  static const double nippleShadow = 1.4;
  static const double nippleShadowAlpha = 0.3;
  static const double orificeAlpha = 0.35;
  static const double orificeFloor = 0.9;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The line where the cut skin meets the dissection, in the shadow ink.
  static const double coatLine = 0.1;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  // The shadow the breast casts, as the thigh's.

  static const double shadowX = 2;
  static const double shadowY = 3.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 5;

  // The names.

  /// How far the names keep clear of a tube beside the breast, and how
  /// much of it must show for it to count: any of it that can be seen.
  static const double nameClear = 2.5;
  static const double nameShown = 0.1;

  /// How finely the place the figure's axillary nodes are named at is
  /// looked for, and how much being inside them counts against being out
  /// from the breast and its muscle: four times, so the place lies well
  /// inside them; and how far from the view's middle it may lie, a share of
  /// the view's width, so its name's line ends on the canvas.
  static const double nodeStep = 1;
  static const double nodeInside = 4;
  static const double nodeReach = 0.44;
}
