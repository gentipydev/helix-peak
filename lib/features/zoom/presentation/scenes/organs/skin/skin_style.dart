import '../../lobules.dart';

/// Every number the skin's look is tuned by, in one place. Lengths are in
/// millimetres of the real skin unless they say otherwise; the anatomy
/// itself is in `skin_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, a block cut from the skin: its top the
/// skin's surface, lit, its furrows faint creases, its hairs dark; its
/// front a flat cut, the epidermis pale on its ridges, the dermis a warm
/// neutral, paler under the epidermis, its bands of fibres faint, and the
/// fat in lit lobules between pale septa; the follicle's sheaths pale round
/// a dark hair, its gland paler still and foamy, its muscle warm; the
/// sweat glands' coils pale, the vessels in the blood red and the nerve in
/// the honey; its right side a second cut, in shade. Where the zoom's cell
/// lives is one flat tone in the mark, as the other specimens draw it.
abstract final class SkinStyle {
  // The step on to the tissue.

  /// How far along the step on to the tissue its names are gone by: its
  /// step is little more than a decade, and quick, and they would blink out
  /// over the organ scene's own share (`OrganScene.leaving`, 0.24).
  static const double namesLeaving = 0.3;

  // The block.

  /// How its top and its side are foreshortened: each millimetre back into
  /// the block runs so far across and up the screen.
  static const double backAcross = 0.3;
  static const double backUp = 0.42;

  /// How far right of the middle of the drawn block the scene's origin
  /// lies: the block a little left of the canvas's middle, where its names'
  /// widest column, on its right, needs the more room.
  static const double offCentre = 0.2;

  /// How many points its ridged edges are followed by to a millimetre.
  static const double perMm = 60;

  /// The seeds its fibres, its furrows and its fat are laid by.
  static const int seed = 47;

  // The faces' light: how each faces, out of the screen and toward the
  // lamp, which shines from the upper left.

  /// The front face, the cut, flat to the view.
  static const (double, double, double) front = (0, 0, 1);

  /// The top, the skin's surface, turned up toward the light.
  static const (double, double, double) top = (-0.05, -0.62, 0.78);

  /// The right side, turned away from the light.
  static const (double, double, double) side = (0.6, -0.1, 0.8);

  /// How much a cut face shines, a share of a fresh surface's sheen.
  static const double cutSheen = 0.4;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the other specimens draw it.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The surface; the epidermis, cut, and its horny layer, paler.
  static const double surfaceLit = 0.52;
  static const double surfaceWarmth = 0.12;
  static const double epidermisLit = 0.58;
  static const double epidermisWarmth = 0.1;
  static const double corneumLit = 0.72;

  /// The papillary dermis, paler than the reticular under it.
  static const double papillaryLit = 0.42;
  static const double papillaryWarmth = 0.16;
  static const double dermisLit = 0.32;
  static const double dermisWarmth = 0.2;

  /// The fat's lobules, and its septa between them.
  static const double fatLit = 0.56;
  static const double fatWarmth = 0.1;
  static const double septumLit = 0.66;

  /// The follicle's sheaths, its bulb and its papilla; the hair, dark.
  static const double sheathLit = 0.55;
  static const double sheathWarmth = 0.08;
  static const double papillaLit = 0.36;
  static const double hairShade = 0.62;
  static const double hairWarmth = 0.35;

  /// The sebaceous gland, paler still; the flecks of its fat-filled cells.
  static const double glandLit = 0.74;
  static const double glandWarmth = 0.14;
  static const double fleckAlpha = 0.18;

  /// The arrector pili, a muscle's warm.
  static const double muscleLit = 0.5;
  static const double muscleWarmth = 0.62;

  /// The sweat glands' coils and ducts; how broad the tube is drawn in its
  /// coil, and how strongly the coil's ball shows round it.
  static const double coilLit = 0.66;
  static const double coilWarmth = 0.06;
  static const double coilTube = 0.05;
  static const double coilBall = 0.3;

  /// The vessels, in the blood red eased toward the ground, the venules
  /// further; their lumens; the nerve, in the honey eased likewise.
  static const double artery = 0.25;
  static const double vein = 0.45;
  static const double nerve = 0.35;

  // The lines.

  /// The bands of fibres in the reticular dermis: how many, how long, how
  /// far each waves, and how faint.
  static const int fibres = 70;
  static const double fibreLength = 0.5;
  static const double fibreWave = 0.03;
  static const double fibreAlpha = 0.12;

  /// The surface's furrows: how far apart its two sets of lines lie, how
  /// far each strays, and how dark.
  static const double furrowSpacing = 0.55;
  static const double furrowJitter = 0.18;
  static const double furrowAlpha = 0.28;

  /// The pores and the follicles' openings on the surface.
  static const double pore = 0.035;
  static const double openingRadius = 0.07;

  /// A hair: how wide it is drawn at least, in pixels, and over how much
  /// of its length it fades.
  static const double hairFloor = 1.3;
  static const double hairFade = 0.45;

  /// The block's edges: lit where the top meets the front, dark where the
  /// side does.
  static const double edgeLit = 0.62;
  static const double edgeAlpha = 0.7;
  static const double edgeShadeAlpha = 0.5;

  /// The lines between the layers on the cut, and how wide at least.
  static const double layerAlpha = 0.35;
  static const double layerFloor = 0.6;

  /// The fine dark line round a small part on the cut, the muscle and the
  /// sweat glands' tubes, in pixels, and how dark.
  static const double cutLine = 0.7;
  static const double edgeCutAlpha = 0.5;

  /// The pixel floors: the basal layer in the mark, the epidermis in it, a
  /// duct, a vessel's cut.
  static const double basalFloor = 1.4;
  static const double epidermisFloor = 2.2;
  static const double ductFloor = 1;
  static const double vesselFloor = 1.2;

  // The fat.

  /// Its lobules, laid in the fat of the front face.
  static const LobuleStyle lobules = LobuleStyle(
    spacing: 0.62,
    edgeStep: 0.92,
    edgeInset: 0.5,
    jitter: 0.2,
    clearOfEdge: 0.8,
    cap: 0.6,
    crevice: 0.05,
    cleft: 0.12,
    lobe: 2,
    rings: <double>[0.45, 0.8, 1],
    tilts: <double>[0.1, 0.28, 0.55],
    tilt: 0.05,
    cleftTilt: 0.14,
    lobeTilt: 0.12,
    nudge: 0.1,
    feather: 0.08,
    rimShade: 0.06,
    lobeTone: 0.04,
    lobuleTone: 0.03,
  );

  /// How the fat's cut face is cushioned under its lobules.
  static const double reliefCell = 0.05;
  static const double reliefInflation = 0.04;
  static const int reliefSweeps = 120;

  // The shadow.

  /// The block's shadow, cast down and to the right of it, and how soft.
  static const double shadowX = 0.12;
  static const double shadowY = 0.2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 0.3;
}
