import 'package:flutter/foundation.dart';

import '../../../../../core/theme/chromosome_colors.dart';
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
///
/// These are the numbers of that look, the stone, which the code reads
/// through [ChromosomeLookSpec.stone], as it reads another look's through
/// its own spec.
///
/// A second look, the vivid (the user's ask of 2026-10-23, after a picture
/// of chromosome 16 they sent), draws the same form as a micrograph's
/// globules rather than a stone's lobes: dense, overlapping spheres of
/// chromatin in a saturated blue, each lit with a highlight of its own and
/// shadowing the next, a lumpy silhouette, deep crevices, a long neck of
/// coral globules at the centromere, gold caps at the telomeres, a dark
/// cleft down between the sisters, and the gene's spots glowing cyan, the
/// globules round them teal ([ChromosomeLookSpec.vivid],
/// [ChromosomeGlobules]). The vivid is the zoom's chromosome, everywhere,
/// since the user's word the same day; the stone is drawn as it was where a
/// build asks for it ([ChromosomeLook]).
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

/// A look the chromosome is drawn in: every number its form, its light and
/// its relief are tuned by, as [ChromosomeStyle] names them for the stone.
/// Lengths are in chromatid half-widths unless they say otherwise.
@immutable
final class ChromosomeLookSpec {
  const ChromosomeLookSpec({
    required this.apart,
    required this.pinch,
    required this.waistLength,
    required this.endRound,
    required this.opening,
    required this.openingPower,
    required this.bend,
    required this.rowStep,
    required this.waistRowStep,
    required this.waistRows,
    required this.feather,
    required this.featherShare,
    required this.bow,
    required this.columns,
    required this.sheen,
    required this.occlusion,
    required this.wash,
    required this.ambientScale,
    required this.diffuseGain,
    required this.lobe,
    required this.lobeSpread,
    required this.lobeWaist,
    required this.lobeLattice,
    required this.lobeTilt,
    required this.skirtInner,
    required this.skirtOuter,
    required this.skirtAlpha,
    required this.granule,
    required this.granuleSpread,
    required this.granuleFloor,
    required this.granules,
    required this.bumpLift,
    required this.bumpAlpha,
    required this.pitAlpha,
    required this.shadowX,
    required this.shadowY,
    required this.shadowAlpha,
    required this.shadowSoft,
    required this.plateX,
    required this.plateY,
    required this.plateOut,
    required this.centromereTint,
    required this.centromereReach,
    required this.kinetochoreTint,
    required this.telomereTint,
    required this.telomereReach,
    required this.fish,
    required this.fishShare,
    required this.fishGlow,
    required this.fishOnStrip,
    required this.paleLit,
    required this.deepShade,
    required this.warmth,
    required this.boundsInflate,
    this.globules,
  });

  /// The stone, today's look, from [ChromosomeStyle]'s own numbers.
  static const ChromosomeLookSpec stone = ChromosomeLookSpec(
    apart: ChromosomeStyle.apart,
    pinch: ChromosomeStyle.pinch,
    waistLength: 0.9,
    endRound: 1,
    opening: ChromosomeStyle.opening,
    openingPower: ChromosomeStyle.openingPower,
    bend: ChromosomeStyle.bend,
    rowStep: ChromosomeStyle.rowStep,
    waistRowStep: ChromosomeStyle.waistRowStep,
    waistRows: ChromosomeStyle.waistRows,
    feather: ChromosomeStyle.feather,
    featherShare: ChromosomeStyle.featherShare,
    bow: ChromosomeStyle.bow,
    columns: ChromosomeStyle.columns,
    sheen: ChromosomeStyle.sheen,
    occlusion: ChromosomeStyle.occlusion,
    wash: ChromosomeStyle.wash,
    ambientScale: 1,
    diffuseGain: 1,
    lobe: ChromosomeStyle.lobe,
    lobeSpread: ChromosomeStyle.lobeSpread,
    lobeWaist: ChromosomeStyle.lobeWaist,
    lobeLattice: ChromosomeStyle.lobeLattice,
    lobeTilt: ChromosomeStyle.lobeTilt,
    skirtInner: ChromosomeStyle.skirtInner,
    skirtOuter: ChromosomeStyle.skirtOuter,
    skirtAlpha: ChromosomeStyle.skirtAlpha,
    granule: ChromosomeStyle.granule,
    granuleSpread: ChromosomeStyle.granuleSpread,
    granuleFloor: ChromosomeStyle.granuleFloor,
    granules: ChromosomeStyle.granules,
    bumpLift: ChromosomeStyle.bumpLift,
    bumpAlpha: ChromosomeStyle.bumpAlpha,
    pitAlpha: ChromosomeStyle.pitAlpha,
    shadowX: ChromosomeStyle.shadowX,
    shadowY: ChromosomeStyle.shadowY,
    shadowAlpha: ChromosomeStyle.shadowAlpha,
    shadowSoft: ChromosomeStyle.shadowSoft,
    plateX: ChromosomeStyle.plateX,
    plateY: ChromosomeStyle.plateY,
    plateOut: ChromosomeStyle.plateOut,
    centromereTint: ChromosomeStyle.centromereTint,
    centromereReach: ChromosomeStyle.centromereReach,
    kinetochoreTint: ChromosomeStyle.kinetochoreTint,
    telomereTint: ChromosomeStyle.telomereTint,
    telomereReach: ChromosomeStyle.telomereReach,
    fish: ChromosomeStyle.fish,
    fishShare: ChromosomeStyle.fishShare,
    fishGlow: ChromosomeStyle.fishGlow,
    fishOnStrip: ChromosomeStyle.fishOnStrip,
    paleLit: ChromosomeStyle.paleLit,
    deepShade: ChromosomeStyle.deepShade,
    warmth: ChromosomeStyle.warmth,
    boundsInflate: 1.2,
  );

  // The form.

  /// How far apart the sisters' middles lie, and how far they draw together
  /// at the waist.
  final double apart;
  final double pinch;

  /// How far either side of the centromere the waist reaches: where it is
  /// pinched 1/e of the way it is at the centromere.
  final double waistLength;

  /// How far in from either end a chromatid rounds to nothing.
  final double endRound;

  /// How far each sister opens from the other at the far end of the longer
  /// arm, and how sharply the opening grows toward it.
  final double opening;
  final double openingPower;

  /// How far both arms bend the same way at the far end of the longer arm.
  final double bend;

  /// The body's rows: one every so far along, closer round the waist.
  final double rowStep;
  final double waistRowStep;
  final double waistRows;

  /// How far a band's edge is softened to either side, at most, and at most
  /// what share of the thinner band beside it.
  final double feather;
  final double featherShare;

  /// How far a band's edges bow, as the ring round a tube they are.
  final double bow;

  /// How far across the tube the body's columns lie (the sine of their angle
  /// round it), from the middle out.
  final List<double> columns;

  // Its light.

  /// How much the chromatin shines: the share of the lamp's sheen it takes.
  final double sheen;

  /// How dark the side of a sister turned to the other is, where they touch.
  final double occlusion;

  /// The share of the mark in the gene's band.
  final double wash;

  /// What the lamp's ambient light and the light it adds are scaled by for
  /// the chromatin: 1, the organs' lamp as it is, or a look of its own's
  /// contrast under the same lamp.
  final double ambientScale;
  final double diffuseGain;

  // Its relief.

  /// Lobes: their radius (a share of a half-width, plus up to
  /// [lobeSpread]), how much finer they are at the centromere, and how far
  /// apart their lattice lies against their mean radius.
  final double lobe;
  final double lobeSpread;
  final double lobeWaist;
  final double lobeLattice;

  /// How far a lobe's ring tilts its normal outward, and its crevice ring.
  final double lobeTilt;
  final double skirtInner;
  final double skirtOuter;
  final double skirtAlpha;

  /// Granules: their radius, its floor in the scene's units, and how many to
  /// a chromatid, for each half-width of its length.
  final double granule;
  final double granuleSpread;
  final double granuleFloor;
  final double granules;

  /// A granule standing out of the surface is the chromatin's own colour
  /// where it lies, lit [bumpLift] of the way on to its full tone, at its
  /// heart [bumpAlpha]; one sunk into it is in shade, at [pitAlpha].
  final double bumpLift;
  final double bumpAlpha;
  final double pitAlpha;

  /// The shadow each sister casts: how far it falls to the lower right, how
  /// dark it is, and its soft edge's width.
  final double shadowX;
  final double shadowY;
  final double shadowAlpha;
  final double shadowSoft;

  /// The kinetochore's plate: its half-width across, its half-height, and how
  /// far out on the waist it sits.
  final double plateX;
  final double plateY;
  final double plateOut;

  // The centromere and the telomeres, each in an earth of its own.

  /// The share of the centromere's ink in the chromatin at the centromere,
  /// and how far either side of it the tint reaches; its share in a
  /// kinetochore's plate.
  final double centromereTint;
  final double centromereReach;
  final double kinetochoreTint;

  /// The share of the telomeres' ink at a chromatid's very end, and how far
  /// in from it the cap reaches.
  final double telomereTint;
  final double telomereReach;

  // The gene.

  /// A FISH spot's radius, at most, and at most what share of the
  /// chromatid's half-width where it lies; its glow's reach.
  final double fish;
  final double fishShare;
  final double fishGlow;

  /// A FISH spot's core as the chromosome lies down into the band's map,
  /// in pixels: where the map's own glow round the gene takes over.
  final double fishOnStrip;

  /// The chromatin's colour at the two ends of [ChromosomeStyle.tone], and
  /// how far both are warmed toward the home helix's honey.
  final double paleLit;
  final double deepShade;
  final double warmth;

  /// How far round the sisters' outlines the chromosome at rest may draw:
  /// its shadow and its relief.
  final double boundsInflate;

  /// How a look of globules draws its chromatin: null for a look of lobes
  /// on a tube, as the stone's are.
  final ChromosomeGlobules? globules;

  /// The vivid: the stone's form drawn as a micrograph's globules (the
  /// user's ask of 2026-10-23). Where it starts from the numbers the user
  /// gave, and where it went from them as it was laid beside their picture,
  /// is said by each.
  static final ChromosomeLookSpec vivid = ChromosomeLookSpec(
    // The sisters a little apart down their arms, so a thin cleft runs
    // between them, closing where they fuse at a longer, tighter waist, and
    // all but straight and parallel.
    apart: 1.10,
    // The user's start was 0.85; at it the neck was a third of the arms'
    // width, the picture's two fifths.
    pinch: 0.78,
    waistLength: 1.3,
    // Ends rounded as domes, which the caps' globules crown.
    endRound: 1.5,
    opening: 0.15,
    openingPower: ChromosomeStyle.openingPower,
    bend: 0.05,
    rowStep: ChromosomeStyle.rowStep,
    waistRowStep: ChromosomeStyle.waistRowStep,
    waistRows: ChromosomeStyle.waistRows,
    feather: ChromosomeStyle.feather,
    featherShare: ChromosomeStyle.featherShare,
    bow: ChromosomeStyle.bow,
    columns: ChromosomeStyle.columns,
    // A brighter sheen on each globule's lit side.
    sheen: 0.9,
    // The sisters meet only at the waist, where the coral runs across.
    occlusion: 0.15,
    // The gene's chromatin is its own material, not a wash of its band.
    wash: 0,
    // The same lamp, harder: less of what every surface has, more of what
    // the light adds.
    ambientScale: 0.7,
    diffuseGain: 1.25,
    // Globules packed all but touching, seven or eight across a chromatid as
    // in the user's picture, finer at the waist. The user's start was 0.21
    // and 0.20 at a lattice of 1.15: half again the picture's size, and
    // piled so deep that each showed only its top.
    lobe: 0.14,
    lobeSpread: 0.12,
    lobeWaist: 0.45,
    lobeLattice: 1.75,
    lobeTilt: ChromosomeStyle.lobeTilt,
    skirtInner: ChromosomeStyle.skirtInner,
    skirtOuter: ChromosomeStyle.skirtOuter,
    skirtAlpha: 0.95,
    // Fewer granules, larger: small spheres among the globules.
    granule: 0.06,
    granuleSpread: 0.05,
    granuleFloor: ChromosomeStyle.granuleFloor,
    granules: 12,
    bumpLift: ChromosomeStyle.bumpLift,
    bumpAlpha: ChromosomeStyle.bumpAlpha,
    pitAlpha: ChromosomeStyle.pitAlpha,
    shadowX: 0.12,
    shadowY: 0.25,
    shadowAlpha: 0.55,
    shadowSoft: ChromosomeStyle.shadowSoft,
    plateX: ChromosomeStyle.plateX,
    plateY: ChromosomeStyle.plateY,
    plateOut: ChromosomeStyle.plateOut,
    // The whole neck coral, and the caps gold, globule by globule.
    centromereTint: 0.95,
    centromereReach: 1.1,
    kinetochoreTint: ChromosomeStyle.kinetochoreTint,
    telomereTint: 0.95,
    // The user's start was 0.6, which left the caps one globule deep; the
    // picture's are about two thirds of a half-width.
    telomereReach: 1.7,
    fish: ChromosomeStyle.fish,
    fishShare: ChromosomeStyle.fishShare,
    fishGlow: 2.8,
    fishOnStrip: ChromosomeStyle.fishOnStrip,
    paleLit: ChromosomeStyle.paleLit,
    deepShade: ChromosomeStyle.deepShade,
    warmth: ChromosomeStyle.warmth,
    // Room for globules standing out of the outline, and a soft shadow.
    boundsInflate: 1.7,
    globules: ChromosomeGlobules(colours: ChromosomeColors.vivid, back: 0),
  );
}

/// How a look of globules draws its chromatin (the vivid's, the user's ask
/// of 2026-10-23): every knob a sphere of one material, blue, coral, gold or
/// teal, lit as a sphere is, with a highlight of its own and a crevice that
/// falls away from the light onto the globules beside it; drawn from the
/// back of the tube to its front, so the front ones stand over the rim's,
/// whose globules make its edge; over a narrower tube left in the shade of
/// the crevices, a cleft dark between the sisters, a shadow blurred under
/// them, and the gene's spots glowing over the chromatin they light.
/// Lengths are in chromatid half-widths unless they say otherwise.
@immutable
final class ChromosomeGlobules {
  const ChromosomeGlobules({
    required this.colours,
    this.bodyWidth = 0.82,
    this.bodyOcclusion = 0.85,
    this.surface = 0.9,
    this.rim = 1.55,
    this.capShrink = 0.35,
    this.back = 0.75,
    this.backOcclusion = 0.3,
    this.cleftGap = 0.04,
    this.cleft = 0.7,
    this.cleftWidth = 0.35,
    this.pickJitter = 0.3,
    this.pickAt = 0.5,
    this.geneReach = 1.2,
    this.geneAt = 0.4,
    this.glowLit = 0.6,
    this.lift = 0.07,
    this.bandShade = 0.14,
    this.shadowAt = 0.35,
    this.baseAt = 0.72,
    this.highlightAt = 0.92,
    this.rings = const <double>[0.4, 0.75, 0.95],
    this.edge = 1.06,
    this.wobble = 0.07,
    this.normalBlend = 0.15,
    this.ring = 18,
    this.leastRing = 10,
    this.skirtShift = 0.15,
    this.specular = 0.38,
    this.specularShift = 0.36,
    this.specularRadius = 0.45,
    this.granuleRing = 8,
    this.spotGlow = 0.6,
    this.spotCore = 0.35,
    this.spotFade = 0.7,
    this.spotFadeAlpha = 0.35,
    this.shadowBlur = 0.35,
    this.grain = 0.08,
    this.grainTile = 0.8,
    this.clearOfLumps = 0.15,
  });

  /// Its colours, a ramp for each material.
  final ChromosomeColors colours;

  // The tube under the globules.

  /// How wide the tube is under the globules, of a chromatid's width, and
  /// how far into the shade of their crevices it lies: it shows only
  /// between them.
  final double bodyWidth;
  final double bodyOcclusion;

  // The globules.

  /// How far out the globules' middles lie, of a chromatid's half-width, and
  /// how far round the tube they are laid, in radians: those at the rim
  /// stand out of the outline and make the chromatid's lumpy edge.
  final double surface;
  final double rim;

  /// How much smaller, and so how much closer, the globules are at the very
  /// ends, where the telomeres' caps are: frilly.
  final double capShrink;

  /// A second layer behind the first, half a cell off its lattice, each of
  /// it [back] the size, [backOcclusion] of the way into its crevice's
  /// shade: it fills between the first.
  final double back;
  final double backOcclusion;

  // The cleft between the sisters.

  /// How far off the middle of the pair a sister's globules keep, down its
  /// arms; at the waist they meet. The shade along each sister's side
  /// facing the other: how dark at most, and how far in it reaches.
  final double cleftGap;
  final double cleft;
  final double cleftWidth;

  // What each globule is made of.

  /// A globule is a telomere's where the telomeres' tint there, moved up or
  /// down by its own jitter of up to [pickJitter], passes [pickAt]; then
  /// the centromere's likewise; else the arms'. So the edges of the caps
  /// and of the neck are a frill of the two.
  final double pickJitter;
  final double pickAt;

  /// A globule is the gene's where the gene's weight there, which falls
  /// from 1 at a FISH spot to 0 [geneReach] from it, moved by the same
  /// jitter, passes [geneAt]. The spot's glow lights the gene's globules:
  /// those at its edge [glowLit] as brightly as those by the spot.
  final double geneReach;
  final double geneAt;
  final double glowLit;

  // How each is lit.

  /// How much lighter or darker each globule is than the next, at most, so
  /// some are navy and some bright; and how much darker the deepest band's
  /// stain makes its chromatin: bands as faint as the picture's.
  final double lift;
  final double bandShade;

  /// Where along a ramp the light lies: its crevice in no light, its shadow
  /// at [shadowAt], its own colour at [baseAt] and its highlight at
  /// [highlightAt], where a surface faces the lamp; its sheen runs on to its
  /// specular.
  final double shadowAt;
  final double baseAt;
  final double highlightAt;

  /// A sphere's rings, from its top out, of its radius, and the ring its
  /// soft edge fades out at; how far each ring's normal leans toward the
  /// surface's under it; how many points the largest globules' rings have,
  /// and the smallest's.
  final List<double> rings;
  final double edge;

  /// How far from round a globule is, at most, of its radius: chromatin
  /// gathers in lumps, not beads.
  final double wobble;
  final double normalBlend;
  final int ring;
  final int leastRing;

  /// How far a globule's crevice is shifted away from the light, of its
  /// radius: the shadow it casts on the globules beside it.
  final double skirtShift;

  /// A globule's highlight: how bright at its heart, how far toward the
  /// light from its middle, and how wide, of its radius.
  final double specular;
  final double specularShift;
  final double specularRadius;

  /// How many points a granule's rings have: a granule standing out of the
  /// surface is a small sphere, lit as a globule is, with no highlight.
  final int granuleRing;

  /// A FISH spot: its glow's heart, added to the light of what lies under
  /// it; and its core, the gene's cyan from [spotCore] of its radius, at
  /// [spotFadeAlpha] by [spotFade], gone at its edge.
  final double spotGlow;
  final double spotCore;
  final double spotFade;
  final double spotFadeAlpha;

  /// How soft the shadow under the sisters is: its blur's sigma.
  final double shadowBlur;

  /// A fine grain in the globules, as a micrograph's: how much darker it
  /// makes them on the whole (0 for none), its darkest specks twice that,
  /// their colours lifted as much to make up for it; and how wide its tile
  /// is.
  final double grain;
  final double grainTile;

  /// How far out past a chromatid's width the gene's bracket and its band's
  /// name keep, clear of the globules standing out of it.
  final double clearOfLumps;
}

/// The looks the zoom can draw a chromosome in.
enum ChromosomeLook {
  /// Warm stone lobes on a tube, lightly tinted (the zoom's from 2026-10-22
  /// to 2026-10-23).
  stone,

  /// Lit globules in a saturated blue, a coral neck, gold caps and a cyan
  /// gene: the zoom's (the user's ask of 2026-10-23, and their word that
  /// day that it be the chromosome everywhere).
  vivid;

  /// Its numbers.
  ChromosomeLookSpec get spec => switch (this) {
    ChromosomeLook.stone => ChromosomeLookSpec.stone,
    ChromosomeLook.vivid => ChromosomeLookSpec.vivid,
  };

  /// The look a build draws its chromosomes in: the vivid, unless it was
  /// built with `--dart-define=CHROMOSOME_LOOK=stone`, to see the stone.
  static const ChromosomeLook chosen =
      String.fromEnvironment('CHROMOSOME_LOOK') == 'stone'
      ? ChromosomeLook.stone
      : ChromosomeLook.vivid;
}

/// What a knob of chromatin is made of, in a look that draws each in one
/// material ([ChromosomeGlobules]).
enum ChromatinMaterial { body, centromere, telomere, gene }
