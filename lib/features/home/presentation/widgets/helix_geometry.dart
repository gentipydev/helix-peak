import 'dart:math' as math;
import 'dart:typed_data';

/// Slots in the painter's colour lookup tables.
///
/// The ordering of the four bases is load-bearing: Watson-Crick partners are
/// adjacent pairs, so the complement of a base is `index ^ 1` — A(0) to T(1),
/// G(2) to C(3) and back. That replaces a map lookup in the hot path with a
/// single XOR, and it makes an incorrect pairing impossible to express.
///
/// The same ordering encodes ring count for free. A and G are the two-ring
/// purines and sit at the even indices; T and C are the one-ring pyrimidines
/// and sit at the odd ones. So [isPurine] is a bit test — and because a base
/// and its complement differ in exactly that bit, *every* pair is one purine
/// joined to one pyrimidine, which is what lets a rung be split into two
/// unequal halves without consulting a table.
abstract final class HelixPalette {
  static const int adenine = 0;
  static const int thymine = 1;
  static const int guanine = 2;
  static const int cytosine = 3;

  /// The sugar-phosphate backbone of the duplex.
  static const int backbone = 4;

  /// The backbone of the RNA transcript. A separate slot so the product of the
  /// reaction can be coloured differently from the template it came off.
  static const int transcript = 5;

  static const int count = 6;

  /// The first slot that is lit rather than pair-faded. See the note on the
  /// two lookup tables in the painter.
  static const int firstLit = backbone;

  /// The base that pairs with [base]. See the note on ordering above.
  static int complementOf(int base) => base ^ 1;

  /// Whether [base] is a purine — two fused rings, so the physically larger
  /// half of whatever pair it is in. See the note on ordering above.
  static bool isPurine(int base) => (base & 1) == 0;
}

/// Kinds of drawable primitive. Every one of them goes into the same depth
/// sort, which is the only reason the structure reads as solid.
abstract final class HelixPrimitiveKind {
  static const int strandSegment = 0;
  static const int rungHalf = 1;
  static const int node = 2;
  static const int transcriptSegment = 3;
  static const int transcriptNode = 4;
}

/// Which deformation a point follows when a polymerase passes over it.
abstract final class HelixPointRole {
  /// On the duplex: opens and untwists inside the bubble.
  static const int duplex = 0;

  /// On the RNA transcript: follows the template, then peels away.
  static const int transcript = 1;
}

/// The rotation-independent half of the helix, computed once.
///
/// ## What is precomputed, and why it can be
///
/// A point on a strand is `(cos(t + phase), sin(t + phase))` scaled by the
/// radius. Rotating the whole structure adds `r` to every angle, and the angle
/// addition identity turns that into arithmetic on values that do not depend
/// on `r` at all:
///
/// ```
/// cos(t + r) = cos(t)*cos(r) - sin(t)*sin(r)
/// sin(t + r) = sin(t)*cos(r) + cos(t)*sin(r)
/// ```
///
/// So this class stores `cos(t)` and `sin(t)` for every point, and the painter
/// evaluates `cos(r)` and `sin(r)` *once per frame* before deriving every
/// rotated point with two multiplies and an add. There is not a single
/// trigonometric call inside the draw loop.
///
/// ## How that survives the transcription bubble
///
/// A polymerase untwists the duplex as it passes, which changes each point's
/// angle — apparently fatal to the argument above, since the angle is exactly
/// what was precomputed. It survives because the same identity applies a
/// second time. [bubbleCosUnwind] and [bubbleSinUnwind] hold the cosine and
/// sine of the local untwist, so the painter composes the frame's rotation
/// with a point's untwist using nothing but multiplies. Still no trigonometry
/// in the draw loop.
///
/// Everything here is also independent of the canvas size — the model is
/// defined in its own units and the painter fits it — which is what allows the
/// precompute to happen in the constructor rather than on first paint.
final class HelixModel {
  HelixModel({
    this.radius = defaultRadius,
    this.pitch = defaultPitch,
    this.rungCount = defaultRungCount,
    this.sampleCount = defaultSampleCount,
  })  : assert(rungCount > 1, 'a helix needs base pairs'),
        assert(sampleCount > 1, 'a strand needs at least one segment'),
        pointCount = 3 * sampleCount + 4 * rungCount,
        primitiveCount = 3 * (sampleCount - 1) + 4 * rungCount + rungCount {
    _build();
  }

  /// Cylinder radius, in model units.
  final double radius;

  /// Rise per full revolution, in model units. Together with [radius] this is
  /// what sets how stretched or squat the helix looks.
  final double pitch;

  /// Base pairs in the model. Some of them sit outside the viewport by
  /// design — see [modelHeight].
  final int rungCount;

  /// Points sampled along each backbone, and along the transcript track.
  final int sampleCount;

  /// Cylinder radius.
  ///
  /// Sized by what one base has to carry, not by the silhouette. The rise
  /// between adjacent base pairs on screen works out to `pitch /
  /// basePairsPerTurn`, and [pitch] is derived from this radius, so the radius
  /// alone decides how much room a base gets: 90 gives about 29 logical
  /// pixels of it, which is what a disc with a letter in it needs to be read
  /// at arm's length. Going wider starts clamping the free transcript against
  /// the edge of a phone screen — see the tail limit in the painter — and
  /// costs a turn of the coil for legibility that is already there.
  static const double defaultRadius = 90;

  /// The default [pitch], derived rather than chosen.
  ///
  /// B-DNA is 3.4nm per turn on a 2nm diameter, so the pitch is 1.7 times the
  /// diameter — see [pitchPerDiameter]. Picking a pitch by eye instead is what
  /// produces the squat, over-wide helix of most illustrations: too squat and
  /// the rungs grow long relative to their spacing and the whole thing reads
  /// as a ladder rather than a coil.
  static const double defaultPitch = defaultRadius * 2 * pitchPerDiameter;

  /// Base pairs in the model.
  ///
  /// Read together with [defaultPitch]: what matters is their product, since
  /// that is [modelHeight], and the model only has to be tall enough to
  /// overrun the frame. A taller pitch needs proportionally fewer rungs to do
  /// that, and fewer, larger bases is the entire point — this is not a length
  /// anyone counts.
  static const int defaultRungCount = 48;

  static const int defaultSampleCount = 200;

  /// Rise per turn as a multiple of the diameter: 3.4nm over 2nm in B-DNA.
  static const double pitchPerDiameter = 1.7;

  /// The phase offset between the two backbones, in radians.
  ///
  /// Deliberately *not* pi. An exact half-turn offset produces two evenly
  /// spaced sine waves — a symmetric ladder that reads as generic, and looks
  /// subtly wrong in a way most viewers cannot name. Real B-DNA strands sit
  /// about 140 degrees apart, which is what opens one wide gap and one narrow
  /// gap per turn: the major and minor grooves.
  ///
  /// This single constant is most of what makes the shape read as DNA rather
  /// than as a decorative twist.
  static const double grooveOffset = 140 * math.pi / 180;

  /// Base pairs per full turn of B-DNA. Fixing this to the real value, rather
  /// than picking a number that looks nice, is what keeps the rung spacing in
  /// proportion to the twist.
  static const double basePairsPerTurn = 10.5;

  /// Rotation, in turns, used when animations are disabled.
  static const double staticRotationTurns = 0.13;

  /// Transcription progress, in turns, used when animations are disabled.
  ///
  /// Places a polymerase in the middle of the frame with its bubble open and a
  /// length of transcript already run off, so the still frame shows the
  /// process rather than a bare helix.
  static const double staticTranscriptionTurns = 0.30;

  // --- The base pair ---------------------------------------------------------

  /// How far across the pair the purine reaches, as a fraction of the span
  /// between the two backbones.
  ///
  /// Not one half. A purine is bicyclic and a pyrimidine is not, so the larger
  /// base genuinely occupies more of the distance between the two glycosidic
  /// bonds and the hydrogen bonds joining them sit off-centre, nearer the
  /// pyrimidine. Splitting at the midpoint gives a bar that happens to change
  /// colour halfway; splitting here gives two molecules of unequal size that
  /// meet, which is both what a base pair is and the only cue that survives
  /// once the rung is too short to show anything else.
  static const double purineReach = 0.58;

  /// The hydrogen-bond gap at that junction, as a fraction of the same span.
  ///
  /// Proportional rather than a fixed number of pixels, so it foreshortens
  /// away with the rest of the rung as the pair turns edge-on, instead of
  /// persisting as a notch in a line that has no length left to notch.
  static const double bondGapFraction = 0.075;

  // --- Transcription ---------------------------------------------------------

  /// Half the width of the transcription bubble, in base pairs.
  ///
  /// RNA polymerase holds roughly 12 to 14 base pairs open, and the bubble is
  /// *centred* on the active site: the duplex unwinds ahead of the enzyme and
  /// rewinds behind it at the same rate. That symmetry is why the profile
  /// below is an even function of distance.
  ///
  /// The low end of that range is used deliberately. Only about 21 bases are
  /// in frame at once, so even a real bubble takes up a large share of the
  /// view — this is a high magnification, not a whole gene.
  static const double bubbleHalfWidthBases = 6;

  /// How far the duplex untwists at the centre of the bubble, in radians.
  ///
  /// A local bump that returns to zero at both edges, rather than a persistent
  /// change in twist rate. Real unwinding does propagate as supercoiling, but
  /// modelling that would shift every base pair downstream of the enzyme and
  /// break the model's periodicity for no visible gain.
  static const double bubbleUnwind = 1.1;

  /// Length of the RNA:DNA hybrid, in bases.
  ///
  /// The nascent transcript stays base-paired to the template for roughly nine
  /// bases before it separates. Rendering that is what stops the RNA looking
  /// like it is merely drawn next to the helix.
  static const double hybridBases = 9;

  /// How much of the molecule a visible transcript spans, in bases.
  ///
  /// A real transcript stays attached until termination and would trail the
  /// whole length of the gene. Capping it keeps the frame readable; the far
  /// end fades out rather than being cut.
  ///
  /// Counted in bases rather than as a fraction of the model, and that is not
  /// cosmetic. The peel ramp in [_buildProfiles] is driven by [hybridBases]
  /// over this span, so measuring either one against the model would make
  /// their ratio a function of [rungCount] — and a ratio that drifts with rung
  /// count is exactly what once ran it past its clamp and turned the ramp
  /// inside out. Counted in bases, [rungCount] cancels and it cannot recur.
  static const double transcriptSpanBases = 22;

  /// Where the free transcript settles, in radii from the axis, and how deep.
  static const double transcriptTailX = -1.75;
  static const double transcriptTailZ = -0.35;

  /// The two rates the free transcript wanders at, in radii.
  ///
  /// Summed, and incommensurate, so a released strand drifts without ever
  /// repeating over the length of the model.
  static const double _wanderSlow = 0.18;
  static const double _wanderFast = 0.08;

  /// The widest the free transcript can swing away from its tail.
  ///
  /// Published because the painter has to leave room for it: the tail says
  /// where the strand settles, and this says how far either side of that it
  /// can actually be when a base is drawn there.
  static const double wanderAmplitude = _wanderSlow + _wanderFast;

  /// Points projected per frame.
  final int pointCount;

  /// Drawables in the table.
  final int primitiveCount;

  /// Full revolutions spanned by the model.
  double get turns => rungCount / basePairsPerTurn;

  /// Height of the whole model, in model units.
  ///
  /// Intentionally taller than any phone viewport. The helix is meant to run
  /// off the top and bottom of the frame and fade out, reading as a section of
  /// a longer molecule rather than an object floating in a box.
  double get modelHeight => turns * pitch;

  /// Half the bubble width, in the normalised axial units the painter works in.
  double get bubbleHalfWidth => bubbleHalfWidthBases / rungCount;

  /// Length of the RNA:DNA hybrid, in normalised axial units.
  double get hybridLength => hybridBases / rungCount;

  /// How much of the model a visible transcript spans, normalised. Derived
  /// rather than stored — see the note on [transcriptSpanBases].
  double get transcriptSpan => transcriptSpanBases / rungCount;

  /// Unit-circle cosine of each point's angle, before rotation.
  late final Float32List pointCos = Float32List(pointCount);

  /// Unit-circle sine of each point's angle, before rotation. This doubles as
  /// the depth axis: `z = radius * pointSin`.
  late final Float32List pointSin = Float32List(pointCount);

  /// Axial position of each point, normalised to `-0.5 .. +0.5`.
  late final Float32List pointAxial = Float32List(pointCount);

  /// Lateral wander of the free transcript at each point, in radii. Zero for
  /// every duplex point.
  late final Float32List pointWander = Float32List(pointCount);

  /// Which deformation each point follows, from [HelixPointRole].
  late final Uint8List pointRole = Uint8List(pointCount);

  /// First endpoint of each primitive, as an index into the point arrays.
  late final Int32List primStart = Int32List(primitiveCount);

  /// Second endpoint of each primitive. A node sets this to its first.
  late final Int32List primEnd = Int32List(primitiveCount);

  /// Colour slot of each primitive, indexing [HelixPalette].
  late final Uint8List primPalette = Uint8List(primitiveCount);

  /// Kind of each primitive, from [HelixPrimitiveKind].
  late final Uint8List primKind = Uint8List(primitiveCount);

  // --- Bubble profile --------------------------------------------------------

  /// Resolution of the profile tables below.
  static const int profileSteps = 129;

  /// How far the duplex is pushed open, sampled across the bubble.
  late final Float32List bubbleSeparation = Float32List(profileSteps);

  /// Cosine of the local untwist, sampled across the bubble.
  late final Float32List bubbleCosUnwind = Float32List(profileSteps);

  /// Sine of the local untwist, sampled across the bubble.
  late final Float32List bubbleSinUnwind = Float32List(profileSteps);

  /// How intact the base pairing is, sampled across the bubble. Falls to zero
  /// well before the separation peaks — the pair breaks, then the strands move.
  late final Float32List bubblePairing = Float32List(profileSteps);

  /// How far the transcript has peeled away, sampled along its length.
  late final Float32List trailPeel = Float32List(profileSteps);

  /// How present the transcript is, sampled along its length.
  late final Float32List trailReveal = Float32List(profileSteps);

  void _build() {
    final double totalAngle = turns * 2 * math.pi;
    final int strandStride = sampleCount;
    final int rungBase = 2 * sampleCount;
    final int rnaBase = rungBase + 4 * rungCount;
    final Uint8List track = _baseTrack();

    // --- Backbone samples ---------------------------------------------------
    for (int i = 0; i < sampleCount; i++) {
      final double u = i / (sampleCount - 1);
      final double angle = u * totalAngle;
      final double axial = u - 0.5;

      pointCos[i] = math.cos(angle);
      pointSin[i] = math.sin(angle);
      pointAxial[i] = axial;

      final int j = strandStride + i;
      pointCos[j] = math.cos(angle + grooveOffset);
      pointSin[j] = math.sin(angle + grooveOffset);
      pointAxial[j] = axial;

      // The transcript track shadows the template strand exactly, so that at
      // the active site — where peel is zero — the RNA sits on the template
      // rather than merely near it.
      final int k = rnaBase + i;
      pointCos[k] = pointCos[j];
      pointSin[k] = pointSin[j];
      pointAxial[k] = axial;
      pointRole[k] = HelixPointRole.transcript;

      // Two summed sines at incommensurate rates — see [wanderAmplitude].
      pointWander[k] =
          _wanderSlow * math.sin(u * 31) + _wanderFast * math.sin(u * 53 + 1.3);
    }

    // --- Rung endpoints and junction ----------------------------------------
    for (int r = 0; r < rungCount; r++) {
      final double u = (r + 0.5) / rungCount;
      final double angle = u * totalAngle;
      final double axial = u - 0.5;

      final double ca = math.cos(angle);
      final double sa = math.sin(angle);
      final double cb = math.cos(angle + grooveOffset);
      final double sb = math.sin(angle + grooveOffset);

      final int a = rungBase + 4 * r;
      final int midA = a + 1;
      final int midB = a + 2;
      final int b = a + 3;

      // Whichever end holds the purine reaches further across the pair, so the
      // junction is pushed toward the pyrimidine. Exactly one end is a purine,
      // always — see the note on the palette ordering.
      final double junction =
          HelixPalette.isPurine(track[r]) ? purineReach : 1 - purineReach;
      final double fa = junction - bondGapFraction / 2;
      final double fb = junction + bondGapFraction / 2;

      pointCos[a] = ca;
      pointSin[a] = sa;
      pointAxial[a] = axial;

      // Because the strands are 140 degrees apart rather than 180, a rung is a
      // chord, not a diameter — the junction sits inside the cylinder, off the
      // axis. Interpolating between the two unit vectors lands exactly there,
      // and stays correct under both rotation and the bubble's untwist,
      // because interpolation is linear: the rotation of a blend is the blend
      // of the rotations. That the blend is weighted rather than even changes
      // nothing about that argument.
      pointCos[midA] = ca + (cb - ca) * fa;
      pointSin[midA] = sa + (sb - sa) * fa;
      pointAxial[midA] = axial;

      pointCos[midB] = ca + (cb - ca) * fb;
      pointSin[midB] = sa + (sb - sa) * fb;
      pointAxial[midB] = axial;

      pointCos[b] = cb;
      pointSin[b] = sb;
      pointAxial[b] = axial;
    }

    _buildPrimitives(strandStride, rungBase, rnaBase, track);
    _buildProfiles();
  }

  void _buildPrimitives(
    int strandStride,
    int rungBase,
    int rnaBase,
    Uint8List track,
  ) {
    int p = 0;

    // --- Backbone segments --------------------------------------------------
    for (int strand = 0; strand < 2; strand++) {
      final int offset = strand * strandStride;
      for (int i = 0; i < sampleCount - 1; i++) {
        primStart[p] = offset + i;
        primEnd[p] = offset + i + 1;
        primPalette[p] = HelixPalette.backbone;
        primKind[p] = HelixPrimitiveKind.strandSegment;
        p++;
      }
    }

    // --- Transcript backbone ------------------------------------------------
    for (int i = 0; i < sampleCount - 1; i++) {
      primStart[p] = rnaBase + i;
      primEnd[p] = rnaBase + i + 1;
      primPalette[p] = HelixPalette.transcript;
      primKind[p] = HelixPrimitiveKind.transcriptSegment;
      p++;
    }

    // --- Rung halves, nucleotide nodes, transcript bases ---------------------
    for (int r = 0; r < rungCount; r++) {
      final int a = rungBase + 4 * r;
      final int midA = a + 1;
      final int midB = a + 2;
      final int b = a + 3;

      final int base = track[r];
      final int partner = HelixPalette.complementOf(base);

      // Two halves rather than one line, so each end carries the colour of the
      // base actually sitting on that strand and the rung shows a real
      // complementary pair. They stop short of one another at the junction,
      // where the hydrogen bonds would be. They sort independently, which is
      // correct: a backbone segment can legitimately pass between them.
      primStart[p] = a;
      primEnd[p] = midA;
      primPalette[p] = base;
      primKind[p] = HelixPrimitiveKind.rungHalf;
      p++;

      primStart[p] = midB;
      primEnd[p] = b;
      primPalette[p] = partner;
      primKind[p] = HelixPrimitiveKind.rungHalf;
      p++;

      // The nucleotides themselves. These are *not* faded by the bubble: when
      // a pair breaks the hydrogen bonds go, but both bases are still there on
      // their own strands. Only the rung between them disappears.
      primStart[p] = a;
      primEnd[p] = a;
      primPalette[p] = base;
      primKind[p] = HelixPrimitiveKind.node;
      p++;

      primStart[p] = b;
      primEnd[p] = b;
      primPalette[p] = partner;
      primKind[p] = HelixPrimitiveKind.node;
      p++;

      // The transcript reads off the template strand, so its base at this
      // position is the complement of the template — which is the base on the
      // *coding* strand, exactly as the biology says. Uracil is not a separate
      // colour: the palette documents thymine as standing in for RNA's U. It
      // is a separate glyph, which the painter substitutes when it labels a
      // transcript node.
      final int rnaSample =
          (((r + 0.5) / rungCount) * (sampleCount - 1)).round();
      primStart[p] = rnaBase + rnaSample;
      primEnd[p] = rnaBase + rnaSample;
      primPalette[p] = base;
      primKind[p] = HelixPrimitiveKind.transcriptNode;
      p++;
    }

    assert(p == primitiveCount, 'primitive table under-filled');
  }

  /// Builds the tables that describe what a passing polymerase does to the
  /// geometry around it.
  ///
  /// Every deformation is a function of one scalar — axial distance from the
  /// active site — so all of it collapses into a handful of lookup tables and
  /// the painter never evaluates a curve at runtime.
  void _buildProfiles() {
    // Both ends of the peel ramp come off this one quantity, so the
    // denominator below cannot go negative and turn the ramp inside out. It is
    // a ratio of two lengths both counted in bases, which is what makes it
    // independent of [rungCount] — see the note on [transcriptSpanBases].
    final double hybridFraction =
        (hybridBases / transcriptSpanBases).clamp(0.05, 0.6);
    final double peelEnd = hybridFraction + 0.3;

    for (int i = 0; i < profileSteps; i++) {
      final double t = i / (profileSteps - 1);

      // --- Across the bubble, from one edge to the other --------------------
      // A raised cosine: peaks at the active site, and lands on zero with zero
      // slope at both edges, so the duplex closes smoothly instead of kinking.
      final double bump = 0.5 * (1 + math.cos((t * 2 - 1) * math.pi));

      bubbleSeparation[i] = bump;

      final double unwind = bump * bubbleUnwind;
      bubbleCosUnwind[i] = math.cos(unwind);
      bubbleSinUnwind[i] = math.sin(unwind);

      // Pairing is lost faster than the strands part — the hydrogen bonds
      // break first and the geometry follows. Squaring the complement pulls
      // the fade forward without introducing a hard edge.
      final double intact = (1 - bump * 1.7).clamp(0.0, 1.0);
      bubblePairing[i] = intact * intact;

      // --- Along the transcript, from the active site backwards -------------
      // Held at zero through the RNA:DNA hybrid, then eased out to fully free
      // over a comparable stretch.
      final double peel =
          ((t - hybridFraction) / (peelEnd - hybridFraction)).clamp(0.0, 1.0);
      trailPeel[i] = peel * peel * (3 - 2 * peel);

      // Present for most of its length, then faded out at the far end so the
      // cap reads as the strand trailing off rather than as a cut.
      trailReveal[i] = 1 - ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    }
  }

  /// The base occupying each rung's first strand.
  ///
  /// Fixed for the life of the model, so a given rung is always the same
  /// colour. Generating it per frame would make the helix strobe.
  ///
  /// A small linear congruential generator with a fixed seed: deterministic
  /// across runs and hot reloads, but without the visible ABCD banding that
  /// `r % 4` would produce.
  Uint8List _baseTrack() {
    final Uint8List track = Uint8List(rungCount);
    int state = 20240516;
    for (int r = 0; r < rungCount; r++) {
      state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
      track[r] = (state >> 16) % 4;
    }
    return track;
  }
}
