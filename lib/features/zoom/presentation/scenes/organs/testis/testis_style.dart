/// Every number the testis's look is tuned by, in one place. Lengths are in
/// millimetres of the real testis unless they say otherwise; the anatomy
/// itself is in `testis_anatomy.dart`, and the light is the zoom's one lamp
/// (`SpecimenLamp.zoom`), the pancreas's and the brain's.
///
/// The look is a fresh specimen's, cut down its length: the lobules each a
/// low cushion of coiled tubules, lit, on the darker interstitium between
/// them, pale septa between the lobules, the pearly tunica round them, the
/// fibrous mediastinum with the rete's dark channels; the epididymis
/// knobbly and darker; the vas deferens pale; the vessels in the blood red,
/// dimmer than the testis; the tunica vaginalis a faint film round it all.
abstract final class TestisStyle {
  // The outline, and the step from the body.

  /// How many points the outlines are followed by between two of their
  /// own, and how many the step from the body morphs round them by.
  static const int outlineSpan = 8;
  static const int morphPoints = 360;

  /// How far in from the testis's outline the flat shape is drawn as it
  /// becomes the bed the testis lies on.
  static const double bed = 0.35;

  // The septa.

  /// How wide a septum is, and in pixels at least.
  static const double septum = 0.16;
  static const double septumFloor = 0.9;

  /// How far a septum runs out from the mediastinum before it bends toward
  /// the tunica, and comes in to the tunica square to it, shares of its
  /// length; how far it wanders to either side of its course.
  static const double septumLeave = 0.38;
  static const double septumArrive = 0.3;
  static const double septumWander = 0.16;

  /// Which septa fork on their way to the tunica, one in so many, and how
  /// far along them.
  static const int forkEvery = 2;
  static const double forkAt = 0.62;

  // The lobules: each a low cushion.

  /// The grid each lobule's cushion is solved on, how high it stands
  /// against its width, and how far it tilts the tubules lying on it.
  static const double cushionCell = 0.4;
  static const double cushion = 0.6;
  static const int cushionSweeps = 30;
  static const double cushionTilt = 1.2;

  // The seminiferous tubules.

  /// How wide a tubule is, and how far apart two lie, middle to middle.
  static const double tubule = 0.17;
  static const double pitch = 0.27;

  /// How far a tubule keeps from a septum or the mediastinum, past its own
  /// half-width.
  static const double tubuleClear = 0.03;

  /// How far a lobule's tubules wander from the grid they are laid on, and
  /// over how long a wave: a long one that bends whole runs, and a short
  /// one that sets each winding. Two tubules side by side wander nearly
  /// together, so the gap between them closes by less than it is.
  static const double warp = 0.11;
  static const double warpWave = 3;
  static const double wiggle = 0.04;
  static const double wiggleWave = 1.2;

  /// Over how much of a lobule from its edge its tubules come to wander
  /// so: they keep to its edge, and wander only further in.
  static const double warpFade = 0.6;

  /// How much of a lobule each tubule fills, in square millimetres, at
  /// most four to a lobule; how often a tubule's course runs on from where
  /// it last turned rather than from anywhere it has reached.
  static const double lobulePerTubule = 12;
  static const int tubulesPerLobule = 4;
  static const double runOn = 0.15;

  /// How far the straight tubules run on into the mediastinum.
  static const double rectus = 0.7;

  // The rete testis.

  /// How far apart its spaces lie, and how long and how wide each is at
  /// most and at least.
  static const double reteStep = 0.5;
  static const double reteLong = 0.95;
  static const double reteShort = 0.3;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  static const double tubuleLit = 0.56;
  static const double interstitiumShade = 0.5;
  static const double septumLit = 0.55;
  static const double tunicaLit = 0.8;
  static const double mediastinumLit = 0.58;
  static const double reteShade = 0.28;
  static const double epididymisLit = 0.5;
  static const double ductuleLit = 0.56;
  static const double vasLit = 0.85;

  /// The vessels: blood eased toward the ground, a vein more than an
  /// artery.
  static const double artery = 0.25;
  static const double vein = 0.5;

  /// The share of the testis's own light what lies round it is drawn in:
  /// the epididymis, the ductules and the cord.
  static const double neighbourLight = 0.8;

  /// How much lighter or darker one lobule is than the next, and one
  /// tubule than the next in it, at most.
  static const double lobuleTone = 0.05;
  static const double tubuleTone = 0.025;

  /// The share of the mark in the tubules, for a cell that lives in them.
  static const double wash = 0.42;

  // The tunica albuginea: a rim of the testis's surface, curving away.

  /// How far its middle and its outer edge turn away from the eye.
  static const double tunicaMiddle = 0.45;
  static const double tunicaOuter = 0.85;

  // The epididymis's knobs: the head's lobules, the body's and the tail's
  // coils.

  /// How far apart, in the head and in the rest, and how much nearer
  /// along it than across in the rest, where they are coils lying across
  /// it; how far each tilts the surface; how deep the crevice between two
  /// is shaded, and how far the edge is drawn in there, a share of the
  /// epididymis's radius.
  static const double headKnob = 3.0;
  static const double bodyKnob = 1.6;
  static const double coilSqueeze = 1.8;
  static const double knobTilt = 0.7;
  static const double knobCrevice = 0.45;
  static const double knobNotch = 0.16;

  /// How many columns round it, and how far apart its rows are.
  static const int epididymisColumns = 15;
  static const double epididymisRow = 0.2;

  // The efferent ductules.

  /// How wide each is; how far it zigzags to either side as it coils, at
  /// the testis and at the head; over how long a wave.
  static const double ductule = 0.36;
  static const double coilFrom = 0.05;
  static const double coilTo = 0.45;
  static const double coilWave = 1.6;
  static const double ductuleRow = 0.12;

  /// How far into the head of the epididymis each ends.
  static const double ductuleInto = 0.6;

  // The tubes: the vas deferens and the vessels.

  /// How far apart their rows are, at most, and how far across their
  /// columns lie (the sine of their angle round them); how close a bend's
  /// inner side may come to its middle, a share of the bend's radius.
  static const double tubeRow = 0.5;
  static const List<double> columns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double bend = 0.9;

  // The tunica vaginalis.

  /// Its film's tone and how much of it shows, and its edge's.
  static const double sacLit = 0.3;
  static const double sacAlpha = 0.14;
  static const double sacEdgeAlpha = 0.32;

  // The Leydig cells, for an endocrine cell.

  /// How many clusters, their true radii in micrometres and the share of
  /// each; the one at the place the tissue is sampled.
  static const int leydig = 520;
  static const List<double> leydigRadii = <double>[22, 34, 50];
  static const List<double> leydigShares = <double>[0.5, 0.35, 0.15];
  static const double siteLeydig = 60;

  /// How they are drawn: a core and a halo, each at least so many pixels
  /// across, the halo so many times the core.
  static const double coreFloor = 1.1;
  static const double haloFloor = 2.8;
  static const double halo = 4.5;
  static const double haloAlpha = 0.16;

  // The shadow the specimen casts.

  static const double shadowX = 1.2;
  static const double shadowY = 2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 4;

  // The names.

  /// How far the names set round the testis keep clear of a tube where it
  /// leaves it, and how faint a tube's end may be and still keep them
  /// clear of it.
  static const double nameClear = 3;
  static const double nameShown = 0.5;
}
