import '../../../domain/locus_track.dart';

/// Every number the chromosome's look is tuned by, in one place. Lengths are
/// in chromatid half-widths unless they say otherwise.
///
/// The look is a scanning micrograph's: two velvety sisters, a knobbly
/// surface bright at its edges and dark in its crevices, a soft coat round
/// them, bands as soft changes of tone, and the gene as two FISH spots.
abstract final class ChromosomeStyle {
  // The form.

  /// How far apart the sisters' middles lie: touching, along a hairline.
  static const double apart = 0.97;

  /// How far the middles draw together at the waist.
  static const double pinch = 0.72;

  /// How far each sister opens from the other at the far end of the longer
  /// arm, and how sharply the opening grows toward it.
  static const double opening = 0.32;
  static const double openingPower = 2.4;

  /// How far both arms bend the same way at the far end of the longer arm.
  static const double bend = 0.3;

  /// The body's rows: one every so far along, closer round the waist.
  static const double rowStep = 0.18;
  static const double waistRowStep = 0.08;
  static const double waistRows = 1.5;

  /// How far a band's edge is softened to either side, at most, and at most
  /// what share of the thinner band beside it.
  static const double feather = 0.3;
  static const double featherShare = 0.4;

  /// How far a band's edges bow, as the ring round a tube they are.
  static const double bow = 0.14;

  /// How far across the tube the body's columns lie (the sine of their angle
  /// round it), from the middle out.
  static const List<double> columns = <double>[0, 0.38, 0.66, 0.86, 0.96, 1];

  // Its light, from the upper left and a little in front.

  static const double lightX = -0.48;
  static const double lightY = -0.57;
  static const double lightZ = 0.66;

  /// Brightness: what every surface has, what the light adds, how much the
  /// edges glow on the side facing the light and darken on the other.
  static const double ambient = 0.34;
  static const double diffuse = 0.62;
  static const double edgeLit = 0.55;
  static const double edgeShade = 0.25;
  static const double edgePower = 1.6;

  /// How dark the side of a sister turned to the other is, where they touch.
  static const double occlusion = 0.7;

  /// The share of the mark in the gene's band.
  static const double wash = 0.2;

  // Its relief.

  /// Lobes: their radius (a share of [half], plus up to [lobeSpread]), how
  /// much finer they are at the centromere, and how far apart their
  /// lattice lies against their mean radius.
  static const double lobe = 0.16;
  static const double lobeSpread = 0.15;
  static const double lobeWaist = 0.45;
  static const double lobeLattice = 1.8;

  /// How far a lobe's ring tilts its normal outward, and its crevice ring.
  static const double lobeTilt = 0.75;
  static const double skirtInner = 0.95;
  static const double skirtOuter = 1.45;
  static const double skirtAlpha = 0.35;

  /// Granules: their radius, its floor in the scene's units, and how many to
  /// a chromatid, for each half-width of its length.
  static const double granule = 0.035;
  static const double granuleSpread = 0.025;
  static const double granuleFloor = 0.0032;
  static const double granules = 60;
  static const double bumpAlpha = 0.07;
  static const double pitAlpha = 0.14;

  /// The soft coat round each sister, and the shadow it casts.
  static const double coat = 0.42;
  static const double coatInner = 0.22;
  static const double shadowX = 0.12;
  static const double shadowY = 0.22;

  /// The kinetochore's plate: its half-width across, its half-height, and how
  /// far out on the waist it sits.
  static const double plateX = 0.14;
  static const double plateY = 0.42;
  static const double plateOut = 0.8;

  // The gene.

  /// A FISH spot's radius, at most, and at most what share of the
  /// chromatid's half-width where it lies; its glow's reach.
  static const double fish = 0.5;
  static const double fishShare = 0.8;
  static const double fishGlow = 2.1;

  /// A FISH spot's core as the chromosome lies down into the band's map,
  /// in pixels: where the map's own glow round the gene takes over.
  static const double fishOnStrip = 6;

  /// How dark a band's stain is, from 0 (pale) to 1 (as deep as the
  /// chromatin is drawn).
  static double tone(Stain stain) => switch (stain) {
    Stain.gvar => 0.45,
    Stain.acen => 0.6,
    Stain.stalk => 0.2,
    _ => 0.04 + 0.78 * stain.depth,
  };

  /// The chromatin's colour at the two ends of [tone]: the lit outline for
  /// the palest bands, the surfaces for the deepest.
  static const double paleLit = 0.5;
  static const double deepShade = 0.55;
}
