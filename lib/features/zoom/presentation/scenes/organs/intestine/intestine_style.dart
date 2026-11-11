/// Every number the intestines' look is tuned by, in one place. Lengths are
/// in millimetres of the real intestines unless they say otherwise; the
/// anatomy itself is in `intestine_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, seen in place from the front, in deep
/// tones that stand out among the body's faint parts round it: the coils
/// and the colon lit tubes of the gut's warm neutral, as the stomach draws
/// the esophagus and the duodenum it runs on into, the jejunum a little
/// warmer than the ileum, the colon a little paler, its free band paler
/// still and its appendices the breast's fat; each coil casting a soft
/// shadow on what it lies on, and the gaps between them the mesentery and
/// the back wall in shade. Through the window, the lining where the zoom's
/// cell lives flat in the mark, as the stomach's mucosa is, cut by its
/// anatomy as crisp lines (the semilunar folds, the valve's lips and
/// frenula, the appendix's orifice, the Peyer's patch and its nodules);
/// the lining where it does not live a deep warm neutral; the cut wall a
/// thin band of its coats round each opening.
abstract final class IntestineStyle {
  // The outline, and the step from the body.

  /// How finely the colon, the coils and the outline are followed, in
  /// millimetres; how many points the step from the body morphs round the
  /// outline by; and how far in from the outline the flat shape is drawn as
  /// it becomes the bed the intestines lie on.
  static const double edgeStep = 1.5;
  static const double outlineStep = 1;
  static const int morphPoints = 320;
  static const double bed = 0.5;

  /// How far along the step from the body the body's outline is drawn in
  /// toward the intestines' own: more slowly than most specimens', as the
  /// gallbladder's, the body's mass of coils being drawn in to the colon
  /// framing them, its coils deeper in the pelvis (at 0.45 the outline
  /// jolted 1.8 px at 60 fps).
  static const double settling = 0.55;

  /// The seed the patch's nodules are laid by.
  static const int seed = 47;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), and warmed toward the home helix's clay.

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the stomach's mucosa is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The bed the intestines lie on, seen between the coils: the mesentery
  /// and the back wall in shade.
  static const double bedLit = 0.08;
  static const double bedWarmth = 0.2;

  /// The gut's serosa, lit: the jejunum, the ileum, the colon; the free
  /// band; the appendices, as the breast's fat.
  static const double jejunumLit = 0.4;
  static const double jejunumWarmth = 0.3;
  static const double ileumLit = 0.42;
  static const double ileumWarmth = 0.24;
  static const double colonLit = 0.44;
  static const double colonWarmth = 0.18;
  static const double bandLit = 0.56;
  static const double bandWarmth = 0.08;
  static const double fatLit = 0.46;
  static const double fatWarmth = 0.14;

  /// The lining where the zoom's cell does not live, as the stomach's
  /// mucosa is drawn there.
  static const double mucosaLit = 0.3;
  static const double mucosaWarmth = 0.3;

  /// The cut wall's coats: the submucosa pale, the muscle a muscle's warm,
  /// the serosa paler.
  static const double submucosaLit = 0.58;
  static const double submucosaWarmth = 0.12;
  static const double muscleLit = 0.28;
  static const double muscleWarmth = 0.42;
  static const double serosaLit = 0.62;
  static const double serosaWarmth = 0.08;

  /// How bright the tubes are lit, and round each at these shares of its
  /// radius; and how far into the shadow a tube runs where it fades, going
  /// back under another into the dark between the coils.
  static const double tubeLight = 1;
  static const List<double> tubeColumns = <double>[
    0,
    0.3,
    0.55,
    0.75,
    0.9,
    0.97,
    1,
  ];
  static const double shadeAway = 0.55;

  /// How deep in the shade the sigmoid colon lies, behind the coils in the
  /// pelvis.
  static const double sigmoidShade = 0.42;

  /// How far a coil's end rounds off past its last row, where it turns
  /// away: a share of its width.
  static const double endRound = 0.45;

  /// How far a sacculus's bulge tips the colon's surface toward or away
  /// from the lamp along it.
  static const double sacculusTilt = 1.6;

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  // The shadows the coils cast.

  /// Each coil's shadow on what it lies on: how far it falls, away from the
  /// lamp, how dark, and how soft its edge.
  static const double castX = 1.6;
  static const double castY = 2.2;
  static const double castAlpha = 0.34;
  static const double castSoft = 3;

  // The anatomy, cut into the lining and the colon as crisp lines.

  /// The folds (semilunar folds, the valve's lips and frenula, the
  /// sacculi's grooves on the colon): the crease along each, how wide, how
  /// far it tapers in from each end, how dark, and never thinner than so
  /// many pixels; the light on its far side, how far over and how bright.
  static const double fold = 1.1;
  static const double foldTaper = 5;
  static const double foldAlpha = 0.32;
  static const double foldFloor = 0.9;
  static const double foldLight = 1.1;
  static const double foldLightLit = 0.75;
  static const double foldLightAlpha = 0.14;

  /// The sacculi's grooves on the colon: how far across it each runs, a
  /// share of its half-width, and how dark.
  static const double grooveReach = 0.92;
  static const double grooveAlpha = 0.3;

  /// The valve's aperture, a slit in the shadow ink: how wide, and how
  /// dark.
  static const double slit = 1.6;
  static const double slitAlpha = 0.75;

  /// The Peyer's patch: its edge, a crease, and its nodules, small pits.
  static const double patchEdge = 0.7;
  static const double patchAlpha = 0.3;
  static const double nodule = 1.4;
  static const double noduleAlpha = 0.3;

  /// The lining along the cut wall: never thinner than so many pixels.
  static const double mucosaFloor = 1;

  // The lines.

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  /// The line between the cut wall and the lining, in the shadow ink.
  static const double coatLine = 0.15;
  static const double coatLineFloor = 0.5;
  static const double coatLineAlpha = 0.3;

  // The shadow the intestines cast.

  static const double shadowX = 1;
  static const double shadowY = 1.5;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2.5;

  // The names.

  /// How far the names keep clear of the outline.
  static const double nameClear = 3;
}
