import '../../../domain/locus_track.dart';

/// Every number the chromosome's look is tuned by, in one place. Lengths are
/// in chromatid half-widths unless they say otherwise.
///
/// The look is a specimen's under the zoom's one lamp, as the organs are
/// (`SpecimenLamp.zoom`; the user's ask of 2026-10-22, the micrograph's
/// glowing edges and soft coat having read as washed out): two sisters in
/// a warm stone, a knobbly surface of opaque lobes, each lit from the upper
/// left with a moist sheen and dark in the crevices round it, each sister
/// darker toward its edges, only a shadow round them; bands as soft changes
/// of tone, the centromere and the telomeres tinted lightly, and the gene
/// as two FISH spots.
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

  // Its light is the zoom's one lamp, the organs' (`SpecimenLamp.zoom`).

  /// How much the chromatin shines: the share of the lamp's sheen it takes,
  /// as much as a cut face does.
  static const double sheen = 0.6;

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

  /// A granule standing out of the surface is the chromatin's own colour
  /// where it lies, lit [bumpLift] of the way on to its full tone, at its
  /// heart [bumpAlpha]; one sunk into it is in shade, at [pitAlpha].
  static const double bumpLift = 0.35;
  static const double bumpAlpha = 0.5;
  static const double pitAlpha = 0.14;

  /// The shadow each sister casts, as the organs cast theirs: how far it
  /// falls to the lower right, how dark it is, and its soft edge's width.
  static const double shadowX = 0.12;
  static const double shadowY = 0.22;
  static const double shadowAlpha = 0.35;
  static const double shadowSoft = 0.5;

  /// The kinetochore's plate: its half-width across, its half-height, and how
  /// far out on the waist it sits.
  static const double plateX = 0.14;
  static const double plateY = 0.42;
  static const double plateOut = 0.8;

  // The centromere and the telomeres, each tinted in an earth of its own,
  // lightly, so the light and the relief read through (the user's ask of
  // 2026-10-19).

  /// The share of the centromere's ink in the chromatin at the centromere,
  /// and how far either side of it the tint reaches.
  static const double centromereTint = 0.3;
  static const double centromereReach = 1.3;

  /// The share of the centromere's ink in a kinetochore's plate.
  static const double kinetochoreTint = 0.75;

  /// The share of the telomeres' ink at a chromatid's very end, and how far
  /// in from it the cap reaches.
  static const double telomereTint = 0.55;
  static const double telomereReach = 0.75;

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
  /// the palest bands, as the organs' lit tissue is, and all but the
  /// ground for the deepest, so that once warmed, which lifts the deepest
  /// most, the bands lie as far apart in tone as they did in grey.
  static const double paleLit = 0.55;
  static const double deepShade = 0.05;

  /// How far both are warmed toward the home helix's honey: a warm stone,
  /// in the ground's own hue, where the lit outline alone is a cool grey
  /// (the user's choice of 2026-10-22).
  static const double warmth = 0.12;
}
