import '../../lobules.dart';

/// Every number the salivary gland's look is tuned by, in one place.
/// Lengths are in millimetres of the real gland unless they say otherwise;
/// the anatomy itself is in `salivary_anatomy.dart`, and the light is the
/// zoom's one lamp (`SpecimenLamp.zoom`), the pancreas's, the brain's and
/// the testis's.
///
/// The look is a fresh dissection's under one lamp: the parotid a soft
/// gland of small lobules, each a lit dome with a moist sheen, dark
/// crevices between them; its duct a pale cord over the masseter, the
/// facial nerve's branches fine cords in the home helix's honey, the
/// superficial temporal vessels in the blood red; round it the masseter,
/// the ear, the bones and the submandibular gland, dimmer, so the parotid
/// is what the eye goes to.
abstract final class SalivaryStyle {
  // The outlines, and the step from the body.

  /// How many points the outlines are followed by between two of their
  /// own, and how many the step from the body morphs round them by.
  static const int outlineSpan = 8;
  static const int morphPoints = 360;

  /// How far in from the parotid's outline the flat shape is drawn as it
  /// becomes the bed its lobules lie on.
  static const double bed = 0.4;

  // The forms' reliefs: the grid each is solved on, and how tall each
  // stands against its width.

  static const double reliefCell = 0.8;
  static const int reliefSweeps = 90;
  static const double glandInflation = 0.55;
  static const double masseterInflation = 0.3;
  static const double earInflation = 0.45;
  static const double conchaInflation = 0.5;

  // The lobules.

  /// How far apart the lobules lie, centre to centre.
  static const double lobule = 3;

  /// How the lobules are laid and lit, the lobes about a centimetre across.
  static const LobuleStyle lobules = LobuleStyle(
    spacing: lobule,
    edgeStep: 0.92,
    edgeInset: 0.48,
    jitter: 0.15,
    clearOfEdge: 0.8,
    cap: 0.6,
    crevice: 0.12,
    cleft: 0.5,
    lobe: 9,
    rings: <double>[0.4, 0.75, 1],
    tilts: <double>[0.3, 0.7, 1],
    tilt: 0.12,
    cleftTilt: 0.45,
    lobeTilt: 0.35,
    nudge: 0.25,
    feather: 0.12,
    rimShade: 0.22,
    lobeTone: 0.06,
    lobuleTone: 0.03,
  );

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  static const double glandLit = 0.58;
  static const double creviceShade = 0.55;
  static const double submandibularLit = 0.42;
  static const double ductLit = 0.55;
  static const double masseterLit = 0.3;
  static const double earLit = 0.42;
  static const double conchaLit = 0.3;
  static const double meatusShade = 0.15;
  static const double boneLit = 0.72;

  /// The masseter's fibres: how far apart, how far each leans back over
  /// its length, a share of it, and how strong their shade and their
  /// light.
  static const double fibre = 1.4;
  static const double fibreLean = 0.18;
  static const double fibreShade = 0.16;
  static const double fibreLight = 0.07;

  /// The vessels: blood eased toward the ground, a vein more than an
  /// artery.
  static const double artery = 0.25;
  static const double vein = 0.5;

  /// The nerves: the honey eased toward the ground, and the share of the
  /// gland's light they are drawn in; the bones' share of it.
  static const double nerve = 0.05;
  static const double nerveLight = 0.9;
  static const double boneLight = 0.9;

  /// How much the neighbours give way to the gland: the share of the
  /// gland's own light they are drawn in.
  static const double neighbourLight = 0.62;

  /// The share of the mark in the glands' lobules, for a cell that lives
  /// in them.
  static const double wash = 0.22;

  // The tubes.

  /// How far apart a tube's rows are, at most, and how far across its
  /// columns lie (the sine of their angle round it).
  static const double tubeRow = 1;
  static const List<double> columns = <double>[0, 0.38, 0.7, 0.92, 1];

  /// How far a tube's inner side may come to its bend's centre, a share of
  /// the bend's radius.
  static const double bend = 0.9;

  /// How far the names set round the gland keep clear of a tube, and how
  /// faint a tube may be and still keep them clear of it.
  static const double nameClear = 4;
  static const double nameShown = 0.5;

  // The shadows the gland and its neighbours cast.

  static const double shadowX = 1.2;
  static const double shadowY = 2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 3;

  // The window, for a duct cell: the gland's superficial part cut away
  // round the duct's way in, the ducts inside it laid bare.

  /// Its middle and radii.
  static const double windowX = -6.5;
  static const double windowY = -9;
  static const double windowRx = 13.5;
  static const double windowRy = 10;

  /// The ducts inside: how many leave the hilum, how long the first are,
  /// how many times they fork, and how much shorter each fork is; their
  /// true width at the hilum and at their ends, and in pixels at least.
  static const int ductBranches = 6;
  static const double ductReach = 6;
  static const int ductForks = 3;
  static const double ductShrink = 0.7;
  static const double branchWidth = 0.6;
  static const double coreFloor = 1.1;

  /// The cut's shadow on the side facing the light, and its lit wall on the
  /// other, in millimetres across and at most how strong; the septa on the
  /// cut face, in pixels.
  static const double lipShadow = 1.2;
  static const double lipShadowAlpha = 0.5;
  static const double lipWall = 0.5;
  static const double lipWallAlpha = 0.55;
  static const double septum = 0.7;
  static const double cutLit = 0.5;
}
