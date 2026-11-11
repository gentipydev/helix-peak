/// Every number the ovary's look is tuned by, in one place. Lengths are in
/// millimetres of the real ovary unless they say otherwise; the anatomy
/// itself is in `ovary_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh section's, in deep tones that stand out among the
/// body's faint parts round it: where the zoom's cell lives in the mark,
/// its follicles (each one's granulosa and cumulus, and the dust of the
/// earliest under the surface) or its stroma, flat; else the cortex a pale
/// warm cut face turning away under its covering, the medulla deeper and
/// redder about the hilum, its helicine vessels cut across in the blood
/// red; the follicles' antra emptied, in shade, rimmed as the kidney's
/// calyces are, each ringed by its granulosa and its warmer theca; the
/// corpus luteum a band of the adrenal cortex's yellow thrown into folds
/// round a pale core; the corpora albicantia pale, convoluted scars; the
/// tube a lit tube in the fallopian tube's own tone, its fimbriae lit
/// fingers; the ligament of the ovary a pale lit cord; the ovarian vessels
/// lit tubes in the blood red; all of them cut short where they leave.
abstract final class OvaryStyle {
  // The outline, and the step from the body.

  /// How finely the outline is followed, how many points the step from
  /// the body morphs round it by, and how far in from the ovary's outline
  /// the flat shape is drawn as it becomes the bed it lies on.
  static const double outlineStep = 0.25;
  static const int morphPoints = 300;
  static const double bed = 0.3;

  /// Over how much of its detail the body's outline is drawn in to the
  /// ovary's: the specimens' own (`SpecimenStep.settling`).
  static const double settling = 0.45;

  /// How finely the medulla's, the corpora's and the follicles' edges are
  /// followed, and how far apart a tube's rows lie.
  static const double edgeStep = 0.15;
  static const double tubeRow = 0.35;

  /// How far from the hilum's ends the cortex comes to its full depth
  /// under the surface, and so the rim and the dust.
  static const double taper = 3;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`), warmed a
  // share of the way toward the home helix's clay, or its honey.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cortex, a dense pale stroma, and the medulla about the hilum,
  /// looser, deeper and redder: paler than the kidney's.
  static const double cortexLit = 0.42;
  static const double cortexWarmth = 0.12;
  static const double medullaLit = 0.3;
  static const double medullaWarmth = 0.24;

  /// A follicle's granulosa where the follicles are not the cell's home,
  /// and its theca, warmer.
  static const double granulosaLit = 0.62;
  static const double granulosaWarmth = 0.06;
  static const double thecaLit = 0.3;
  static const double thecaWarmth = 0.4;

  /// The oocyte in its cumulus, pale.
  static const double oocyteLit = 0.82;

  /// An antrum, emptied, and the light and shadow just inside its rim.
  static const double antrumShade = 0.85;
  static const double lipShadow = 0.9;
  static const double lipShadowAlpha = 0.6;
  static const double lipLight = 0.45;
  static const double lipLightAlpha = 0.3;
  static const double lipLit = 0.7;

  /// The corpus luteum's band, the adrenal cortex's yellow, and its core.
  static const double luteumLit = 0.36;
  static const double luteumHoney = 0.36;
  static const double coreLit = 0.55;
  static const double coreWarmth = 0.08;

  /// A corpus albicans, pale.
  static const double albicansLit = 0.66;
  static const double albicansWarmth = 0.04;

  /// The helicine vessels' walls, the blood red eased toward the ground,
  /// the veins more, as the other specimens' vessels are; and their
  /// emptied lumens.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double lumenShade = 0.85;

  /// The tube and its fimbriae, in the fallopian tube's own serosa; the
  /// ligament of the ovary, pale; the lit tubes under a light a little
  /// dimmer than the cut's own, round each at these shares of its radius;
  /// a cut end's length along its tube and its wall, shares of its width.
  static const double tubeLit = 0.36;
  static const double tubeWarmth = 0.22;
  static const double ligamentLit = 0.5;
  static const double ligamentWarmth = 0.16;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  // The cut face's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The cortex's edge under its covering, turning away from the eye: how
  /// wide, and how far its middle and its outer edge turn.
  static const double rim = 1;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // The lines.

  /// The pixel floors of the thin parts where the follicles are the cell's
  /// home, in the mark: the granulosa and the cumulus, and the dust.
  static const double homeLineFloor = 1.2;
  static const double homeDustFloor = 1.3;

  /// The pixel floors of the thin parts elsewhere: a granulosa, a theca.
  static const double lineFloor = 0.8;

  /// How far apart the dust of the earliest follicles lies along the
  /// surface, the primordial and the growing; the seed that scatters it.
  static const double primordialApart = 0.55;
  static const double growingApart = 1.6;
  static const int seed = 61;

  /// The corpus luteum's folds: how far its lining's festoons reach into
  /// its core and its outer edge swells, shares of its band; the creases
  /// between them, how far out into the band they reach, a share of it,
  /// their width, and the shadow ink's alpha.
  static const double festoon = 0.22;
  static const double swell = 0.04;
  static const double creaseReach = 0.55;
  static const double crease = 0.1;
  static const double creaseFloor = 0.8;
  static const double creaseAlpha = 0.22;

  /// A corpus albicans's convolutions, shares of its radius, and the
  /// creases in it.
  static const double convolution = 0.16;
  static const double albicansCreaseAlpha = 0.2;

  /// The crisp line round each corpus and the medulla, in the shadow ink.
  static const double edgeLine = 0.08;
  static const double edgeLineFloor = 0.6;
  static const double edgeLineAlpha = 0.35;
  static const double medullaEdgeAlpha = 0.18;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the ovary casts, as the adrenal's.

  static const double shadowX = 0.8;
  static const double shadowY = 1.2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2;

  // The names.

  /// Above what share of the way in a tube is set clear of names, and how
  /// far they keep from it.
  static const double nameShown = 0.1;
  static const double nameClear = 1.2;
}
