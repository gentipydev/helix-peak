import 'package:flutter/foundation.dart';

import '../../../../../core/theme/chromosome_colors.dart';
import '../../../domain/locus_track.dart';

/// Every number the chromosome's look is tuned by, in one place. Lengths are
/// in chromatid half-widths unless they say otherwise.
///
/// The look is a scanning micrograph's form under the zoom's one lamp, the
/// organs' (`SpecimenLamp.zoom`), taken as the organs take it: two sisters
/// of dense, overlapping globules of chromatin, each a sphere of one
/// material lit with a soft highlight of its own and shadowing the next, a
/// lumpy silhouette, crevices, a cleft down between the sisters and a
/// blurred shadow under them; the bands faint changes of the arms' value, a
/// neck of finer globules at the centromere, caps at the telomeres, and the
/// globules of the gene's band in the mark ([ChromosomeGlobules], in
/// [ChromosomeColors.zoom]). Where it starts from the numbers the user gave
/// on 2026-10-23, and where it went from them as it was laid beside the
/// picture of chromosome 16 they sent, is said by each; its light was
/// softened on 2026-10-26, when the user read its shade as artificial.
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
    required this.lobe,
    required this.lobeSpread,
    required this.lobeWaist,
    required this.lobeLattice,
    required this.skirtInner,
    required this.skirtOuter,
    required this.skirtAlpha,
    required this.granule,
    required this.granuleSpread,
    required this.granuleFloor,
    required this.granules,
    required this.pitAlpha,
    required this.shadowX,
    required this.shadowY,
    required this.shadowAlpha,
    required this.centromereTint,
    required this.centromereReach,
    required this.telomereTint,
    required this.telomereReach,
    required this.bandFloor,
    required this.ping,
    required this.pingShare,
    required this.boundsInflate,
    required this.globules,
  });

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

  // Its relief.

  /// Globules: their radius (a share of a half-width, plus up to
  /// [lobeSpread]), how much finer they are at the centromere, and how far
  /// apart their lattice lies against their mean radius.
  final double lobe;
  final double lobeSpread;
  final double lobeWaist;
  final double lobeLattice;

  /// A globule's crevice: the ring it is darkest at and the ring it fades
  /// out by, of its radius, and how dark.
  final double skirtInner;
  final double skirtOuter;
  final double skirtAlpha;

  /// Granules: their radius, its floor in the scene's units, and how many to
  /// a chromatid, for each half-width of its length.
  final double granule;
  final double granuleSpread;
  final double granuleFloor;
  final double granules;

  /// A granule sunk into the surface is a dark dot, at [pitAlpha].
  final double pitAlpha;

  /// The shadow each sister casts: how far it falls to the lower right, and
  /// how dark it is.
  final double shadowX;
  final double shadowY;
  final double shadowAlpha;

  // The centromere and the telomeres, each in an earth of its own.

  /// The share of the centromere's chromatin at the centromere, and how far
  /// either side of it it reaches.
  final double centromereTint;
  final double centromereReach;

  /// The share of the telomeres' chromatin at a chromatid's very end, and
  /// how far in from it the cap reaches.
  final double telomereTint;
  final double telomereReach;

  // The gene.

  /// How tall the stretch of chromatin marked as the gene's band is at the
  /// least, in half-widths: a band thinner than that is widened about its
  /// middle, so a thin band still shows as one.
  final double bandFloor;

  /// The ring that pings round the gene's place on each sister as the
  /// chromosome is reached: its radius, at most, and at most what share of
  /// the chromatid's half-width where it lies.
  final double ping;
  final double pingShare;

  /// How far round the sisters' outlines the chromosome at rest may draw:
  /// its shadow and its relief.
  final double boundsInflate;

  /// How the chromatin is drawn, globule by globule.
  final ChromosomeGlobules globules;

  /// How dark a band's stain is, from 0 (pale) to 1 (as deep as the
  /// chromatin is drawn).
  static double tone(Stain stain) => switch (stain) {
    Stain.gvar => 0.45,
    Stain.acen => 0.6,
    Stain.stalk => 0.2,
    _ => 0.04 + 0.78 * stain.depth,
  };

  /// The zoom's chromosome.
  static final ChromosomeLookSpec zoom = ChromosomeLookSpec(
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
    openingPower: 2.4,
    bend: 0.05,
    rowStep: 0.18,
    waistRowStep: 0.08,
    waistRows: 1.5,
    feather: 0.3,
    featherShare: 0.4,
    bow: 0.14,
    columns: const <double>[0, 0.38, 0.66, 0.86, 0.96, 1],
    // A moist sheen on each globule's lit side, half the 0.9 it had under a
    // lamp made harder than the organs' (ambient 0.7, diffuse 1.25 of
    // theirs), which read as artificial beside them.
    sheen: 0.45,
    // The sisters meet only at the waist, where the neck runs across.
    occlusion: 0.15,
    // Globules packed all but touching, seven or eight across a chromatid as
    // in the user's picture, finer at the waist. The user's start was 0.21
    // and 0.20 at a lattice of 1.15: half again the picture's size, and
    // piled so deep that each showed only its top.
    lobe: 0.14,
    lobeSpread: 0.12,
    lobeWaist: 0.45,
    lobeLattice: 1.75,
    skirtInner: 0.95,
    skirtOuter: 1.45,
    // Crevices in shade, not black: 0.95 left them so.
    skirtAlpha: 0.6,
    // Few granules, large: small spheres among the globules.
    granule: 0.06,
    granuleSpread: 0.05,
    granuleFloor: 0.0032,
    granules: 12,
    pitAlpha: 0.14,
    shadowX: 0.12,
    shadowY: 0.25,
    shadowAlpha: 0.55,
    // The whole neck the centromere's, and the caps the telomeres', globule
    // by globule.
    centromereTint: 0.95,
    centromereReach: 1.1,
    telomereTint: 0.95,
    // The user's start was 0.6, which left the caps one globule deep; the
    // picture's are about two thirds of a half-width.
    telomereReach: 1.7,
    // Two rows of globules, about.
    bandFloor: 0.8,
    ping: 0.5,
    pingShare: 0.8,
    // Room for globules standing out of the outline, and a soft shadow.
    boundsInflate: 1.7,
    globules: ChromosomeGlobules(colours: ChromosomeColors.zoom, back: 0),
  );
}

/// How the chromatin is drawn: every knob a sphere of one material, the
/// arms', the centromere's, the telomeres' or the gene's band's, lit as a
/// sphere is, with a highlight of its own and a crevice that falls away from
/// the light onto the globules beside it; drawn from the back of the tube to
/// its front, so the front ones stand over the rim's, whose globules make
/// its edge; over a narrower tube left in the shade of the crevices, a cleft
/// dark between the sisters, and a shadow blurred under them. Lengths are in
/// chromatid half-widths unless they say otherwise.
@immutable
final class ChromosomeGlobules {
  const ChromosomeGlobules({
    required this.colours,
    this.bodyWidth = 0.82,
    this.bodyOcclusion = 0.7,
    this.surface = 0.9,
    this.rim = 1.55,
    this.capShrink = 0.35,
    this.back = 0.75,
    this.backOcclusion = 0.3,
    this.cleftGap = 0.04,
    this.cleft = 0.55,
    this.cleftWidth = 0.35,
    this.pickJitter = 0.3,
    this.pickAt = 0.5,
    this.geneAt = 0.4,
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
    this.specular = 0.16,
    this.specularShift = 0.36,
    this.specularRadius = 0.45,
    this.granuleRing = 8,
    this.shadowBlur = 0.35,
    this.grain = 0.05,
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

  /// A globule is the gene's band's where the band's weight at its row
  /// (`ChromosomeForm.geneAt`), moved by the same jitter, passes [geneAt]:
  /// all round both sisters, so the band is a ring of the mark round each.
  final double geneAt;

  // How each is lit.

  /// How much lighter or darker each globule is than the next, at most, so
  /// some are deeper and some brighter; and how much darker the deepest
  /// band's stain makes its chromatin: bands as faint as the picture's.
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

/// What a knob of chromatin is made of ([ChromosomeGlobules]).
enum ChromatinMaterial { body, centromere, telomere, gene }
