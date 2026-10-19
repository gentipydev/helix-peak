import 'dart:math' as math;

/// Every number the eye's look is tuned by, in one place. Lengths are in
/// millimetres of the real eye unless they say otherwise; the anatomy
/// itself is in `eye_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the pancreas's, the brain's and the testis's.
///
/// The look is a specimen's, cut level through its nerve: the retina one
/// flat tone, in the mark where the zoom's cell lives in it, as the brain's
/// cortex is; every other cut face lit softly, cushioned a little across,
/// as the brain's cut core is: the sclera pale, its outer edge lit as it
/// turns away; the cornea clear; the choroid, the iris and the ciliary body
/// dark with pigment, the ciliary muscle lighter; the lens pearly; the
/// vitreous a clear film; the optic nerve in the honey, as a nerve is drawn
/// in the zoom, in its sheath; the recti dimmer, their fibres faint; the
/// vessels in the blood red.
abstract final class EyeStyle {
  // The outlines.

  /// How far apart the points the coats are followed by lie, and how many
  /// go round the lens.
  static const double step = 0.12;
  static const int lensPoints = 160;

  // The coats.

  /// The choroid: drawn this thin at the ora serrata, and over how far
  /// temporal of the fovea it keeps most of its thickness.
  static const double choroidFront = 0.1;
  static const double choroidReach = 6;

  /// The retina: over how far from the fovea's rim it thins most of the
  /// way to its thickness at the ora serrata.
  static const double retinaFalloff = 4;

  // The ciliary body, from the scleral spur back to the ora serrata.

  /// How thick it is drawn at its front face, at the end of its pars
  /// plicata and over its pars plana; how many of its processes the cut
  /// shows across the pars plicata, and how far each stands up.
  static const double ciliaryFront = 0.9;
  static const double plicataEnd = 0.3;
  static const double plana = 0.14;
  static const int processesCut = 3;
  static const double processRise = 0.32;

  /// How thick the ciliary muscle is drawn at its front.
  static const double muscle = 0.6;

  // The iris.

  /// How thick it is drawn at its pupillary margin, how far from the margin
  /// it is thickest, and how far forward it bows.
  static const double irisMargin = 0.4;
  static const double collarette = 1.5;
  static const double irisBow = 0.25;

  // The lens.

  /// How much of the lens its nucleus is, and how far its cut face's
  /// cushion tilts.
  static const double nucleus = 0.62;
  static const double lensTilt = 0.32;

  /// How many zonular fibres are drawn on each side.
  static const int zonules = 7;

  // The optic nerve, its sheath and its vessels.

  /// Its course: how far behind the globe it is drawn, over how much of
  /// that it fades out, and how far it waves to either side of its way
  /// toward the orbit's apex, which lies about 23° nasal of straight back,
  /// along the orbit's axis.
  static const double nerveShown = 9;
  static const double nerveFade = 4;
  static const double nerveWave = 0.45;
  static const double heading = 23 * math.pi / 180;

  /// How far behind the globe the orbit's apex lies, where the recti run
  /// to.
  static const double apex = 20;

  /// Where the sheath meets the sclera it is drawn this wide, flaring, and
  /// its dura this thick.
  static const double sheathFlare = 5.8;
  static const double dura = 0.4;

  /// The nerve's fascicles, faint lines along it, so many; the lamina
  /// cribrosa, so many fine lines across the scleral canal, and where in
  /// the sclera's thickness, from its inner face.
  static const int fascicles = 6;
  static const List<double> lamina = <double>[0.2, 0.4, 0.6];

  /// The disc's cup: how far across and how deep.
  static const double cup = 0.6;
  static const double cupDeep = 0.25;

  /// The central retinal artery and vein, drawn so far across, and how far
  /// to either side of the nerve's middle; over how far they come up out
  /// of nothing where they come into the nerve, from below the cut.
  static const double centralArtery = 0.16;
  static const double centralVein = 0.2;
  static const double centralApart = 0.17;
  static const double centralFade = 1.5;

  /// The long posterior ciliary arteries, drawn so far across: how far
  /// behind the globe they come up beside the nerve, how far from its
  /// sheath they run there, and over how far they fade at either end.
  static const double ciliaryArtery = 0.14;
  static const double ciliaryArteryFrom = 6;
  static const double ciliaryArteryBeside = 0.6;
  static const double ciliaryArteryFade = 2;

  // The recti.

  /// How thick a tendon is drawn where it inserts, and over how far from
  /// its insertion its belly comes to its full thickness; how far each
  /// runs on once it leaves the globe, and over how much of that it fades.
  static const double tendon = 0.5;
  static const double belly = 8;
  static const double rectusShown = 8;
  static const double rectusFade = 4;

  /// Over how much of it from its insertion it is tendon, paling into the
  /// muscle; its fibres, faint lines along it, where across it.
  static const double tendonRun = 3;
  static const List<double> fibres = <double>[-0.62, -0.22, 0.22, 0.62];

  // Schlemm's canal.

  /// How far behind the limbus it lies, how far in from the sclera's inner
  /// face, and how long and how wide it is drawn, in pixels at least.
  static const double schlemmAt = 0.5;
  static const double schlemmIn = 0.12;
  static const double schlemmLong = 0.3;
  static const double schlemmWide = 0.06;
  static const double schlemmFloor = 1.6;

  // The tubes.

  /// How far apart a tube's rows are, at most, and how close a bend's
  /// inner side may come to its middle, a share of the bend's radius.
  static const double tubeRow = 0.25;
  static const double bend = 0.9;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  /// The retina's one tone, and the share of the mark over it for a cell
  /// that lives there: flat, as the brain's cortex is.
  static const double retinaLit = 0.2;
  static const double retinaMark = 0.42;

  /// Its halo in the mark, or the pigment epithelium's, where the cell
  /// lives there: how wide, in pixels, and how strong. The retina is a
  /// fine band at its true thickness, and has a halo as the brain's
  /// choroid plexus has one; once the view is close enough for the retina
  /// to be wider than its halo, the halo lies under it.
  static const double halo = 6;
  static const double haloAlpha = 0.2;

  static const double scleraLit = 0.78;
  static const double corneaLit = 0.62;
  static const double corneaAlpha = 0.55;
  static const double choroidLit = 0.1;
  static const double pigmentShade = 0.3;
  static const double ciliaryLit = 0.15;
  static const double muscleLit = 0.36;
  static const double irisLit = 0.2;
  static const double lensLit = 0.66;
  static const double nucleusLit = 0.55;
  static const double capsuleLit = 0.85;
  static const double zonuleLit = 0.62;
  static const double zonuleAlpha = 0.5;
  static const double duraLit = 0.58;
  static const double gapShade = 0.22;
  static const double rectusLit = 0.3;
  static const double tendonLit = 0.72;
  static const double fibreAlpha = 0.16;
  static const double laminaLit = 0.78;
  static const double laminaAlpha = 0.6;
  static const double cupShade = 0.3;
  static const double schlemmShade = 0.2;

  /// The nerve: the honey eased toward the ground, its fascicles' lines.
  static const double nerve = 0.22;
  static const double fascicleAlpha = 0.14;

  /// The vitreous and the chambers, a clear film over the ground, and how
  /// far its cushion tilts it at its rim.
  static const double filmLit = 0.42;
  static const double filmAlpha = 0.32;
  static const double vitreousTilt = 0.5;

  /// The vessels: blood eased toward the ground, a vein more than an
  /// artery, and the fine ciliary arteries more still.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double ciliaryArteryEase = 0.45;

  /// The share of the eye's own light what lies round it is drawn in: the
  /// recti, their tendons and the ciliary arteries outside the globe.
  static const double neighbourLight = 0.55;

  // The cut faces' light.

  /// How far a cut face's cushion tilts it at its edges, and how much it
  /// shines: less than a fresh surface, being cut.
  static const double cushion = 0.22;
  static const double cutSheen = 0.6;

  /// The sclera's outer edge, the globe's surface curving away: how far its
  /// middle and its edge turn from the eye, over how much of the sclera's
  /// thickness.
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;
  static const double rim = 0.35;

  // The lines, in pixels at least.

  static const double pigmentFloor = 1;
  static const double homeFloor = 1.6;
  static const double fineFloor = 0.6;

  /// How wide the fine lines are drawn: the zonules, the lamina, the
  /// capsule, the fibres.
  static const double zonule = 0.03;
  static const double laminaLine = 0.03;
  static const double capsule = 0.02;
  static const double fibre = 0.05;

  // The shadow the specimen casts.

  static const double shadowX = 0.6;
  static const double shadowY = 1;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2;

  // The names.

  /// How far the names set round the eye keep clear of a tube where it
  /// leaves the globe, and how faint a tube's end may be and still keep
  /// them clear of it.
  static const double nameClear = 2;
  static const double nameShown = 0.5;
}
