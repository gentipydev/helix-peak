/// Every number the pancreas's look is tuned by, in one place. Lengths are
/// in millimetres of the real gland unless they say otherwise; the anatomy
/// itself is in `pancreas_anatomy.dart`.
///
/// The look is a fresh specimen's under one lamp: a soft gland of lobules,
/// each a lit dome with a moist sheen, dark crevices between them, the
/// gland rounder and darker toward its edges; round it the duodenum, the
/// spleen and the vessels, dimmer, so the gland is what the eye goes to.
abstract final class PancreasStyle {
  // The form.

  /// The relief's grid, and how tall the gland stands over the page against
  /// its width there: a flattened gland, round in section.
  static const double reliefCell = 2;
  static const double inflation = 0.6;
  static const int reliefSweeps = 90;

  /// How many points the outline is followed by between two of its own,
  /// and how many the step from the body's outline morphs round it by.
  static const int outlineSpan = 8;
  static const int morphPoints = 360;

  // Its lobules.

  /// How far apart the lobules lie, centre to centre.
  static const double lobule = 4.6;

  /// The seeds round the edge: how far apart along it, and how far in.
  static const double edgeStep = 0.92;
  static const double edgeInset = 0.48;

  /// The seeds inside: how far each strays from its lattice, and how far
  /// it keeps from those round the edge. Shares of [lobule].
  static const double jitter = 0.15;
  static const double clearOfEdge = 0.8;

  /// How far a lobule reaches at most, a share of [lobule]: past the edge
  /// it bulges out by this less [edgeInset], which makes the edge knobbly.
  static const double cap = 0.6;

  /// How far round a lobule its outline is followed; the crevice between
  /// two lobules of one lobe, and the deeper cleft between two lobes; and
  /// how far apart the lobes lie.
  static const int rays = 24;
  static const double crevice = 0.15;
  static const double cleft = 0.7;
  static const double lobe = 12;

  /// A lobule's rings, out from its middle, and how far each tilts its
  /// normal outward; its middle's nudge toward the light, a share of its
  /// radius; its feathered edge, a share of [lobule].
  static const List<double> rings = <double>[0.4, 0.75, 1];
  static const List<double> tilts = <double>[0.3, 0.7, 1];

  /// How far a lobule's edge turns away, inside its lobe and at a cleft;
  /// and how far each lobe rounds off toward its own edge.
  static const double tilt = 0.12;
  static const double cleftTilt = 0.45;
  static const double lobeTilt = 0.35;
  static const double nudge = 0.25;
  static const double feather = 0.12;

  /// How dark a lobule's rim is drawn at a cleft, in its shade; how much
  /// lighter or darker one lobe is than the next, and one lobule than the
  /// next, at most.
  static const double rimShade = 0.22;
  static const double lobeTone = 0.06;
  static const double lobuleTone = 0.03;

  // The light, from the upper left and in front, as the chromosome's.

  static const double lightX = -0.48;
  static const double lightY = -0.57;
  static const double lightZ = 0.66;

  /// What every surface has, what the light adds, how much darker the
  /// gland is toward its silhouette, and its sheen.
  static const double ambient = 0.3;
  static const double diffuse = 0.7;
  static const double edgeDark = 0.45;
  static const double edgePower = 0.6;
  static const double sheen = 0.3;
  static const int sheenPower = 24;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  static const double glandLit = 0.58;
  static const double creviceShade = 0.55;
  static const double duodenumLit = 0.2;
  static const double spleenLit = 0.06;
  static const double bileLit = 0.3;
  static const double cutLit = 0.5;

  /// The vessels: blood eased toward the ground, a vein more than an
  /// artery.
  static const double artery = 0.25;
  static const double vein = 0.5;

  /// How much the neighbours give way to the gland: the share of the
  /// gland's own light they are drawn in.
  static const double neighbourLight = 0.62;

  /// The share of the mark in the gland's lobules, for a cell that is the
  /// gland itself.
  static const double wash = 0.22;

  // The tubes.

  /// How far apart a tube's rows are, at most, and how far across its
  /// columns lie (the sine of their angle round it).
  static const double tubeRow = 2;
  static const double ductRow = 0.6;
  static const List<double> columns = <double>[0, 0.38, 0.7, 0.92, 1];

  /// How long a cut end is drawn along its tube, a share of its radius, and
  /// its wall, a share of its radius.
  static const double cutLength = 0.45;
  static const double cutWall = 0.25;

  /// How far a tube's inner side may come to its bend's centre, a share of
  /// the bend's radius.
  static const double bend = 0.9;

  // The shadows the gland and its neighbours cast, in centimetres.

  static const double shadowX = 0.25;
  static const double shadowY = 0.4;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 0.8;

  // The islets, for an endocrine cell.

  /// How many, and how their chance rises toward the tail and with the
  /// gland's thickness.
  static const int islets = 480;
  static const double isletHead = 0.4;
  static const double isletThick = 0.3;

  /// Their true radii, in micrometres, and the share of each; the one at
  /// the place the tissue is sampled.
  static const List<double> isletRadii = <double>[40, 70, 120];
  static const List<double> isletShares = <double>[0.55, 0.3, 0.15];
  static const double siteIslet = 120;

  /// How they are drawn: a core and a halo, each at least so many pixels
  /// across, the halo so many times the core.
  static const double coreFloor = 1.1;
  static const double haloFloor = 2.8;
  static const double halo = 5;
  static const double haloAlpha = 0.16;

  // The window, for a duct cell: in centimetres, how far it opens either
  // side of the main duct.

  static const double windowTail = 0.45;
  static const double windowBody = 0.6;
  static const double windowHeadBelow = 0.95;
  static const double windowHeadAbove = 1.6;

  /// Where along the gland, in centimetres across, the tail gives way to
  /// the body and the body to the head, and over how far.
  static const double tailFrom = 4.5;
  static const double headFrom = -1.8;
  static const double windowEase = 1.2;

  /// The cut's shadow on the side facing the light, and its lit wall on the
  /// other, in millimetres across and at most how strong.
  static const double lipShadow = 2.5;
  static const double lipShadowAlpha = 0.5;
  static const double lipWall = 0.9;
  static const double lipWallAlpha = 0.55;

  /// The duct's side branches: about how far apart along it, at what angle
  /// to it in degrees give or take how many, how long in centimetres
  /// (longer in the head), most forking once; their true width in
  /// millimetres; and how far the place the tissue is sampled may lie from
  /// the duct before a branch reaches it.
  static const double branchStep = 0.9;
  static const double branchAngle = 88;
  static const double branchSpread = 22;
  static const double branchLength = 0.3;
  static const double branchLonger = 0.7;
  static const double branchHead = 1.3;
  static const double branchWidth = 0.4;
  static const double siteReach = 1.5;

  /// The septa the cut face shows, in pixels.
  static const double septum = 0.7;

  // The step from the body.

  /// Over how much of its detail the outline morphs from the body's to its
  /// own; when, and over how much, the gland and its neighbours come up;
  /// when the figure's own parts start to go; how far in the flat shape is
  /// drawn as it becomes the gland's bed, a share of [lobule].
  static const double settle = 0.45;
  static const double comeFrom = 0.4;
  static const double comeOver = 0.6;
  static const double figureFrom = 0.2;
  static const double bed = 0.12;
}
