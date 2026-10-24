/// Every number the adrenal's look is tuned by, in one place. Lengths are
/// in millimetres of the real gland unless they say otherwise; the anatomy
/// itself is in `adrenal_anatomy.dart`, and the light is the zoom's one
/// lamp (`SpecimenLamp.zoom`), the other specimens'.
///
/// The look is a fresh specimen's, cut through the middle of its thickness,
/// in deep tones that stand out among the body's faint parts round it:
/// where the zoom's cell lives flat in the mark, as the kidney's cortex is;
/// else the cortex a deep yellow, warmed toward the home helix's honey, the
/// medulla a dark red-brown, the zona reticularis's edge a faint line round
/// it, each turning away under the capsule; the central vein's channel
/// emptied, in shade; the kidney's upper pole under it lit, fading out
/// below; the central vein and the arteries lit tubes in the blood red.
abstract final class AdrenalStyle {
  // The outline, and the step from the body.

  /// How many points the outline is followed by between two of its own,
  /// how many the step from the body morphs round it by, and how far in
  /// from the gland's outline the flat shape is drawn as it becomes the bed
  /// it lies on.
  static const int outlineSpan = 8;
  static const int morphPoints = 280;
  static const double bed = 0.4;

  /// Over how much of its detail the body's outline is drawn in to the
  /// gland's: a little more than other specimens' (`SpecimenStep`), as the
  /// liver's, so that no point of it jolts (at the specimens' own 0.45, one
  /// moved 1.56 pixels a frame more than the frame before, over the 1.5 the
  /// zoom allows).
  static const double settling = 0.55;

  /// How finely the parts' edges and the vessels are followed.
  static const double edgeStep = 0.3;

  // The tones, each a share of the way from the outline toward the bright
  // ink (`ZoomInks.lit`), or into the shade (`ZoomInks.shade`).

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the kidney's cortex is.
  static const double homeLit = 0.2;
  static const double homeMark = 0.42;

  /// The cortex: deep yellow, a neutral warmed toward the home helix's
  /// honey; the medulla dark red-brown, warmed toward its clay.
  static const double cortexLit = 0.36;
  static const double cortexHoney = 0.36;
  static const double medullaLit = 0.22;
  static const double medullaClay = 0.4;

  /// The central vein's channel, emptied, as the kidney's calyces are.
  static const double cavityShade = 0.8;

  /// The kidney's upper pole: lit, warmed toward the clay as the kidney's
  /// cortex is, a little dimmer than the gland.
  static const double kidneyLit = 0.28;
  static const double kidneyWarmth = 0.4;
  static const double kidneyLight = 0.85;

  /// The vessels: lit tubes in the blood red eased toward the ground, the
  /// veins more, under a light a little dimmer than the gland's own, as the
  /// other specimens' are; round each at these shares of its radius; a cut
  /// end's length along its tube and its wall, shares of its width.
  static const double artery = 0.25;
  static const double vein = 0.5;
  static const double tubeLight = 0.62;
  static const List<double> tubeColumns = <double>[0, 0.38, 0.7, 0.92, 1];
  static const double endLength = 0.45;
  static const double endWall = 0.25;

  // The relief the kidney's pole is lit by.

  static const double reliefCell = 0.8;
  static const double meshCell = 0.7;
  static const double reliefInflation = 0.7;
  static const int reliefSweeps = 220;

  // The cut face's light.

  /// How much a cut face shines: less than a fresh surface, being cut.
  static const double cutSheen = 0.6;

  /// The cut face's edge under the capsule, turning away from the eye: how
  /// wide, and how far its middle and its outer edge turn.
  static const double rim = 1.2;
  static const double rimMiddle = 0.45;
  static const double rimOuter = 0.85;

  // The lines.

  /// The zona reticularis's edge round the medulla, and the medulla's own,
  /// in the shadow ink, in pixels at least.
  static const double zoneLine = 0.1;
  static const double zoneFloor = 0.7;
  static const double zoneAlpha = 0.3;
  static const double medullaEdgeAlpha = 0.45;

  /// The outline's own edge, as the other specimens'.
  static const double edgeLit = 0.42;
  static const double edgeAlpha = 0.85;

  // The shadow the gland casts.

  static const double shadowX = 0.8;
  static const double shadowY = 1.2;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 2;

  // The names.

  /// Above what share of the way in a vessel is set clear of names, and how
  /// far they keep from it.
  static const double nameShown = 0.1;
  static const double nameClear = 2;
}
