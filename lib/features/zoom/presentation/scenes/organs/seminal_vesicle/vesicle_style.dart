import '../prostate/prostate_style.dart';

/// Every number the seminal vesicles' look is tuned by, in one place.
/// Lengths are in millimetres of the real vesicle unless they say
/// otherwise; the anatomy itself is in `vesicle_anatomy.dart`, and the
/// light is the zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, in deep tones: the vesicle on the body's
/// left laid open, its mucosa, where the zoom's cell lives, flat in the
/// mark, as the gallbladder's is, cut by its anatomy as crisp lines (the
/// honeycomb's folds, the septa between its coils, the diverticula dark
/// pits), the cut wall a warm band round it; the vesicle on the body's
/// right whole, a lit coiled sac of Gray's whitish brown, as the prostate
/// specimen draws the vesicles above its base, the creases between its
/// coils; the deferent ducts and their ampullae lit cords, pale, the one
/// on the body's left laid open with its lining pale and folded; the
/// ejaculatory ducts pale, going into the base; the arteries lit tubes in
/// the blood red; the prostate's base below, lit as a cushion in the
/// prostate specimen's own tone, fading out below.
abstract final class SeminalVesicleStyle {
  // The outline, and the step from the body.

  /// How finely the sacs' spines are followed, how many points the step
  /// from the body morphs round the opened vesicle by, and how far in from
  /// its outline the flat shape is drawn as it becomes the bed it lies on.
  static const double spineStep = 0.3;
  static const int morphPoints = 300;
  static const double bed = 0.3;

  /// Over how much of its detail the body's outline is drawn in to the
  /// vesicle's own: more than other specimens' (`SpecimenStep`), since the
  /// anatomogram's coiled band turns into the leaning sac.
  static const double settling = 0.55;

  /// How far apart a tube's rows lie, and how finely the folds are
  /// followed.
  static const double tubeRow = 0.35;
  static const double edgeStep = 0.2;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), warmed a share of the way toward the home helix's
  // clay, or its honey.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The whole vesicle and the opened one's cut wall seen from outside,
  /// Gray's whitish brown, a little toward the honey: the prostate
  /// specimen's own vesicles.
  static const double vesicleLit = ProstateStyle.vesicleLit;
  static const double vesicleWarmth = ProstateStyle.vesicleWarmth;
  static const double vesicleHoney = ProstateStyle.vesicleHoney;

  /// The cut wall where the vesicle and the ampulla are laid open: their
  /// muscular coat, a muscle's warm, as the prostate's sleeve is.
  static const double wallLit = ProstateStyle.muscleLit;
  static const double wallWarmth = ProstateStyle.muscleWarmth;

  /// The deferent ducts and their ampullae, pale, as the prostate specimen
  /// draws the ampullae; the opened ampulla's lining, paler and a little
  /// warm; the ejaculatory ducts, pale.
  static const double ductLit = ProstateStyle.ampullaLit;
  static const double ductWarmth = ProstateStyle.ampullaWarmth;
  static const double liningLit = ProstateStyle.liningLit;
  static const double liningWarmth = ProstateStyle.liningWarmth;
  static const double ejaculatoryLit = ProstateStyle.ductLit;
  static const double ejaculatoryWarmth = ProstateStyle.ductWarmth;

  /// The prostate's base below, in the prostate specimen's peripheral
  /// zone's tone.
  static const double prostateLit = ProstateStyle.peripheralLit;
  static const double prostateWarmth = ProstateStyle.peripheralWarmth;

  /// The arteries in the blood red eased toward the ground; the lit tubes
  /// under a light a little dimmer than a cut's own, round each at these
  /// shares of its radius.
  static const double artery = ProstateStyle.artery;
  static const double tubeLight = ProstateStyle.tubeLight;
  static const List<double> tubeColumns = ProstateStyle.tubeColumns;

  /// The creases between the whole vesicle's coils: how far across it they
  /// reach, a share of its radius, how wide, and the shadow ink's alpha.
  static const double coilReach = ProstateStyle.coilReach;
  static const double coilCrease = ProstateStyle.coilCrease;
  static const double coilAlpha = ProstateStyle.coilAlpha;

  // The relief the prostate's base is lit by.

  static const double reliefCell = 1;
  static const double meshCell = 0.8;
  static const double reliefInflation = 0.55;
  static const int reliefSweeps = 120;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  // The mucosa's anatomy, cut into it.

  /// The honeycomb's folds: the crease along each, crisp in the shadow
  /// ink, how wide and how dark, and the light on its far side, toward the
  /// lamp, how far over and how bright; neither thinner than so many
  /// pixels. Finer than the gallbladder's, as the net is.
  static const double mesh = 0.22;
  static const double meshAlpha = 0.24;
  static const double meshLight = 0.25;
  static const double meshLightLit = 0.75;
  static const double meshLightAlpha = 0.1;
  static const double meshFloor = 0.8;

  /// The septa between the coils and the opened ampulla's folds: the
  /// crease along each, how wide, how far it tapers in from each end, how
  /// dark, never thinner than so many pixels; and the light on its far
  /// side, how far over, how bright.
  static const double septum = 0.5;
  static const double septumTaper = 1;
  static const double septumAlpha = 0.3;
  static const double septumFloor = 0.9;
  static const double fold = 0.32;
  static const double foldTaper = 0.5;
  static const double foldAlpha = 0.26;
  static const double foldLight = 0.4;
  static const double foldLightLit = 0.75;
  static const double foldLightAlpha = 0.16;

  /// The diverticula's pits: dark, with a hair of light on the lip toward
  /// the lamp.
  static const double pitAlpha = 0.7;
  static const double lipLit = 0.75;
  static const double lipAlpha = 0.28;
  static const double lipOffset = 0.3;

  // The lines.

  /// The line where the cut wall meets the mucosa or the lining, in the
  /// shadow ink: how wide, in pixels at least, and how strong.
  static const double coatLine = 0.1;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  /// The outlines' own edges, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The honeycomb's places, the same every time.
  static const int seed = 97;

  // The shadow each sac casts, as the prostate's, an organ of its size.

  static const double shadowX = 0.8;
  static const double shadowY = 1.2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2;

  // The names.

  /// Above what share of the way in a tube is set clear of names, and how
  /// far they keep from it; below what share of its fade the prostate is
  /// set clear of them.
  static const double nameShown = 0.25;
  static const double nameClear = 1.2;
  static const double prostateNamed = 0.5;
}
