/// Every number the prostate's look is tuned by, in one place. Lengths are
/// in millimetres of the real prostate unless they say otherwise; the
/// anatomy itself is in `prostate_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh section's, in deep tones that stand out among the
/// body's faint parts round it: where the zoom's cell lives flat in the
/// mark (the glands of its peripheral and central zones, cut by their
/// ducts; its stroma; or its urethra's lining); else the peripheral zone a
/// pale reddish grey cut face, Gray's, the central zone a shade deeper,
/// turning away under the capsule, the ducts fine shadowed lines and the
/// glands' lumens pores; the urethra laid open, its lumen emptied in shade
/// and rimmed as the kidney's calyces are, its lining pale, the colliculus
/// a pale mound on its floor; the ejaculatory ducts pale lit walls round
/// their lumens; the muscle round the urethra and the sphincter below
/// warmed toward the home helix's clay, as the thigh's muscle is; the
/// seminal vesicles lit coiled sacs of a whitish brown, the ampullae pale
/// lit cords; the arteries lit tubes in the blood red.
abstract final class ProstateStyle {
  // The outline, and the step from the body.

  /// How finely the outline is followed, how many points the step from
  /// the body morphs round it by, and how far in from the prostate's
  /// outline the flat shape is drawn as it becomes the bed it lies on.
  static const double outlineStep = 0.3;
  static const int morphPoints = 300;
  static const double bed = 0.3;

  /// How finely the zones' edges, the ducts and the urethra are followed,
  /// and how far apart a tube's rows lie.
  static const double edgeStep = 0.2;
  static const double tubeRow = 0.35;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), warmed a share of the way toward the home helix's
  // clay, or its honey.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The peripheral zone, Gray's pale reddish grey, and the central zone,
  /// denser and a shade deeper.
  static const double peripheralLit = 0.46;
  static const double peripheralWarmth = 0.14;
  static const double centralLit = 0.37;
  static const double centralWarmth = 0.2;

  /// The muscle round the urethra and the sphincter below the apex, warmed
  /// as the thigh's muscle is.
  static const double muscleLit = 0.32;
  static const double muscleWarmth = 0.3;

  /// The urethra's lining, pale and a little warm; the colliculus and the
  /// crest, paler; the emptied lumen, and the light and shadow just inside
  /// its rim, as the kidney's calyces have.
  static const double liningLit = 0.56;
  static const double liningWarmth = 0.16;
  static const double colliculusLit = 0.62;
  static const double colliculusWarmth = 0.12;
  static const double lumenShade = 0.82;
  static const double lipShadow = 0.6;
  static const double lipShadowAlpha = 0.6;
  static const double lipLight = 0.35;
  static const double lipLightAlpha = 0.3;
  static const double lipLit = 0.7;

  /// The lining's width round the lumen, and in pixels at least.
  static const double lining = 0.35;
  static const double liningFloor = 0.9;

  /// The ejaculatory ducts' walls, pale; their lumens and the slits and
  /// the utricle, in shade.
  static const double ductLit = 0.6;
  static const double ductWarmth = 0.1;
  static const double slitShade = 0.85;

  /// The seminal vesicles, Gray's whitish brown, a little toward the honey;
  /// the ampullae, pale; the sphincter's cut end; the arteries in the blood
  /// red eased toward the ground; the lit tubes under a light a little
  /// dimmer than the cut's own, round each at these shares of its radius; a
  /// cut end's length along its tube and its wall, shares of its width.
  static const double vesicleLit = 0.52;
  static const double vesicleWarmth = 0.16;
  static const double vesicleHoney = 0.08;
  static const double ampullaLit = 0.54;
  static const double ampullaWarmth = 0.1;
  static const double artery = 0.25;
  static const double tubeLight = 0.78;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.3;

  /// The creases between a vesicle's coils: how far across it they reach,
  /// a share of its radius, how wide, and the shadow ink's alpha.
  static const double coilReach = 0.62;
  static const double coilCrease = 0.2;
  static const double coilAlpha = 0.2;

  // The cut face's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The capsule's edge, the cut face turning away under it: how wide, and
  /// how far its middle and its outer edge turn.
  static const double rim = 1.1;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // The lines.

  /// The ducts: how wide, in pixels at least, and the shadow ink's alpha;
  /// where the glands are the cell's home, a little stronger, so they cut
  /// the flat tone crisply.
  static const double ductLine = 0.13;
  static const double ductFloor = 0.6;
  static const double ductAlpha = 0.24;
  static const double homeDuctAlpha = 0.3;

  /// The pores: the shadow ink's alpha.
  static const double poreAlpha = 0.32;

  /// The crisp line where the central zone meets the peripheral, in the
  /// shadow ink.
  static const double zoneLine = 0.1;
  static const double zoneFloor = 0.7;
  static const double zoneAlpha = 0.3;

  /// Where the stroma is the cell's home, the capsule's band under the
  /// edge, and in pixels at least.
  static const double capsule = 0.5;
  static const double capsuleFloor = 1.2;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The pores' places, the same every time.
  static const int seed = 83;

  // The shadow the prostate casts, as the ovary's, an organ of its size.

  static const double shadowX = 0.8;
  static const double shadowY = 1.2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2;

  // The names.

  /// Above what share of the way in a tube is set clear of names, and how
  /// far they keep from it.
  static const double nameShown = 0.25;
  static const double nameClear = 1.2;
}
