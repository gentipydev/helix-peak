import 'dart:math' as math;
import 'dart:typed_data';

abstract final class HelixPalette {
  static const int adenine = 0;
  static const int thymine = 1;
  static const int guanine = 2;
  static const int cytosine = 3;

  static const int backbone = 4;

  static const int transcript = 5;

  static const int count = 6;

  static const int firstLit = backbone;

  static int complementOf(int base) => base ^ 1;

  static bool isPurine(int base) => (base & 1) == 0;
}

abstract final class HelixPrimitiveKind {
  static const int strandSegment = 0;
  static const int rungHalf = 1;
  static const int node = 2;
  static const int transcriptSegment = 3;
  static const int transcriptNode = 4;
}

abstract final class HelixPointRole {
  static const int duplex = 0;

  static const int transcript = 1;
}

final class HelixModel {
  HelixModel({
    this.radius = defaultRadius,
    this.pitch = defaultPitch,
    this.rungCount = defaultRungCount,
    this.sampleCount = defaultSampleCount,
  })  : assert(rungCount > 1, 'a helix needs base pairs'),
        assert(sampleCount > 1, 'a strand needs at least one segment'),
        pointCount = 3 * sampleCount + rungPointStride * rungCount,
        primitiveCount =
            3 * (sampleCount - 1) + rungPrimitiveStride * rungCount {
    _build();
  }

  final double radius;

  final double pitch;

  final int rungCount;

  final int sampleCount;

  static const double defaultRadius = 90;

  static const double defaultPitch = defaultRadius * 2 * pitchPerDiameter;

  static const int defaultRungCount = 48;

  static const int defaultSampleCount = 140;

  /// B-DNA is 34 A per turn across a 20 A duplex.
  static const double pitchPerDiameter = 1.7;

  /// Angle from one backbone to the other, measured across the minor groove.
  ///
  /// The glycosidic bonds of a base pair subtend about 120 degrees on the
  /// minor-groove side and 240 on the major-groove side, which is what makes
  /// the two grooves unequal. 127 degrees splits the turn 127:233 — a ratio of
  /// 1.83, matching B-DNA's measured 22 A major to 12 A minor. Drawing the
  /// strands exactly opposite (180) is the usual illustration mistake: it
  /// erases the grooves entirely.
  static const double grooveOffset = 127 * math.pi / 180;

  static const double basePairsPerTurn = 10.5;

  /// Pieces each half-rung is tessellated into.
  ///
  /// A half-rung is a chord reaching most of the way across the duplex, so its
  /// two ends can sit far apart in depth. The painter sorts a primitive by one
  /// averaged depth, and one average for that whole chord is wrong at both
  /// ends — the rung pops in front of a strand it should pass behind. Cutting
  /// it into shorter pieces keeps every piece close to its own depth.
  static const int rungSegments = 3;

  /// Points per rung: both halves, each with `rungSegments` pieces.
  static const int rungPointStride = 2 * (rungSegments + 1);

  /// Primitives per rung: the tessellated halves, two nodes, one RNA node.
  static const int rungPrimitiveStride = 2 * rungSegments + 3;

  static const double staticRotationTurns = 0.13;

  /// Places a polymerase in the upper half with its transcript running down
  /// behind it, so the still frame reduced motion falls back to still shows
  /// what the animation is about. Reads against [headReach], not the model.
  static const double staticTranscriptionTurns = 0.53;

  static const double purineReach = 0.58;

  static const double bondGapFraction = 0.075;

  static const double bubbleHalfWidthBases = 6;

  static const double bubbleUnwind = 0.7;

  static const double hybridBases = 9;

  static const double transcriptSpanBases = 22;

  static const double transcriptTailX = -1.75;
  static const double transcriptTailZ = -0.35;

  static const double _wanderSlow = 0.11;
  static const double _wanderFast = 0.05;

  static const double wanderAmplitude = _wanderSlow + _wanderFast;

  final int pointCount;

  final int primitiveCount;

  double get turns => rungCount / basePairsPerTurn;

  double get modelHeight => turns * pitch;

  double get bubbleHalfWidth => bubbleHalfWidthBases / rungCount;

  double get hybridLength => hybridBases / rungCount;

  double get transcriptSpan => transcriptSpanBases / rungCount;

  /// How far past each end of the model a polymerase travels.
  ///
  /// A head that turned round at the model edge would strand its transcript:
  /// the trail lags a whole [transcriptSpan] behind, so at the wrap a still
  /// mostly-opaque length of RNA would be on screen one frame and gone the
  /// next. Running the head a span past the edge lets the trail finish fading
  /// before either can be seen.
  double get headReach => 0.5 + transcriptSpan;

  /// Worst-case depth error of one tessellated rung piece.
  ///
  /// The painter sorts a piece at its midpoint, so it can be wrong by half the
  /// depth the piece spans. Taken over the longer of the two halves, which is
  /// the one that reaches past the duplex centre.
  double get rungDepthError =>
      math.sin(grooveOffset / 2) *
      (purineReach - bondGapFraction / 2) /
      (2 * rungSegments);

  /// Angle between adjacent backbone samples, in radians.
  ///
  /// A rung's node sits at its own angle, which in general falls *between* two
  /// backbone samples, so the segment spanning it can average out up to
  /// `sampleAngleStep / 4` nearer in depth than the node itself — the bound
  /// follows from `|sin a - sin b| <= |a - b|`. The painter biases a node
  /// forward by at least this much so a base is never sliced by its own strand.
  double get sampleAngleStep => turns * 2 * math.pi / (sampleCount - 1);

  late final Float32List pointCos = Float32List(pointCount);

  late final Float32List pointSin = Float32List(pointCount);

  late final Float32List pointAxial = Float32List(pointCount);

  late final Float32List pointWander = Float32List(pointCount);

  late final Uint8List pointRole = Uint8List(pointCount);

  late final Int32List primStart = Int32List(primitiveCount);

  late final Int32List primEnd = Int32List(primitiveCount);

  late final Uint8List primPalette = Uint8List(primitiveCount);

  late final Uint8List primKind = Uint8List(primitiveCount);

  static const int profileSteps = 129;

  late final Float32List bubbleSeparation = Float32List(profileSteps);

  late final Float32List bubbleCosUnwind = Float32List(profileSteps);

  late final Float32List bubbleSinUnwind = Float32List(profileSteps);

  late final Float32List bubblePairing = Float32List(profileSteps);

  late final Float32List trailPeel = Float32List(profileSteps);

  late final Float32List trailReveal = Float32List(profileSteps);

  void _build() {
    final double totalAngle = turns * 2 * math.pi;
    final int strandStride = sampleCount;
    final int rungBase = 2 * sampleCount;
    final int rnaBase = rungBase + rungPointStride * rungCount;
    final Uint8List track = _baseTrack();

    for (int i = 0; i < sampleCount; i++) {
      final double u = i / (sampleCount - 1);

      // Negative, because the painter puts +y down the screen and +z away from
      // the viewer. Advancing down while turning +x toward +z would wind the
      // duplex the wrong way; B-DNA is right-handed, so its near-side strands
      // must read as a rising diagonal, the way a standard screw thread does.
      final double angle = -u * totalAngle;
      final double axial = u - 0.5;

      pointCos[i] = math.cos(angle);
      pointSin[i] = math.sin(angle);
      pointAxial[i] = axial;

      final int j = strandStride + i;
      pointCos[j] = math.cos(angle + grooveOffset);
      pointSin[j] = math.sin(angle + grooveOffset);
      pointAxial[j] = axial;

      final int k = rnaBase + i;
      pointCos[k] = pointCos[j];
      pointSin[k] = pointSin[j];
      pointAxial[k] = axial;
      pointRole[k] = HelixPointRole.transcript;

      pointWander[k] =
          _wanderSlow * math.sin(u * 31) + _wanderFast * math.sin(u * 53 + 1.3);
    }

    for (int r = 0; r < rungCount; r++) {
      final double u = (r + 0.5) / rungCount;
      final double angle = -u * totalAngle;
      final double axial = u - 0.5;

      final double ca = math.cos(angle);
      final double sa = math.sin(angle);
      final double cb = math.cos(angle + grooveOffset);
      final double sb = math.sin(angle + grooveOffset);

      final int a = rungBase + rungPointStride * r;

      final double junction =
          HelixPalette.isPurine(track[r]) ? purineReach : 1 - purineReach;
      final double fa = junction - bondGapFraction / 2;
      final double fb = junction + bondGapFraction / 2;

      // Walk both halves at once: `near` runs from strand A out to the bond
      // gap, `far` runs from the gap on to strand B.
      for (int k = 0; k <= rungSegments; k++) {
        final double t = k / rungSegments;

        final double fNear = fa * t;
        final double fFar = fb + (1 - fb) * t;

        final int near = a + k;
        final int far = a + rungSegments + 1 + k;

        pointCos[near] = ca + (cb - ca) * fNear;
        pointSin[near] = sa + (sb - sa) * fNear;
        pointAxial[near] = axial;

        pointCos[far] = ca + (cb - ca) * fFar;
        pointSin[far] = sa + (sb - sa) * fFar;
        pointAxial[far] = axial;
      }
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

    for (int i = 0; i < sampleCount - 1; i++) {
      primStart[p] = rnaBase + i;
      primEnd[p] = rnaBase + i + 1;
      primPalette[p] = HelixPalette.transcript;
      primKind[p] = HelixPrimitiveKind.transcriptSegment;
      p++;
    }

    for (int r = 0; r < rungCount; r++) {
      final int a = rungBase + rungPointStride * r;
      final int b = a + 2 * rungSegments + 1;

      final int base = track[r];
      final int partner = HelixPalette.complementOf(base);

      for (int k = 0; k < rungSegments; k++) {
        primStart[p] = a + k;
        primEnd[p] = a + k + 1;
        primPalette[p] = base;
        primKind[p] = HelixPrimitiveKind.rungHalf;
        p++;
      }

      for (int k = 0; k < rungSegments; k++) {
        final int far = a + rungSegments + 1 + k;
        primStart[p] = far;
        primEnd[p] = far + 1;
        primPalette[p] = partner;
        primKind[p] = HelixPrimitiveKind.rungHalf;
        p++;
      }

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

  void _buildProfiles() {
    final double hybridFraction =
        (hybridBases / transcriptSpanBases).clamp(0.05, 0.6);
    final double peelEnd = hybridFraction + 0.3;

    for (int i = 0; i < profileSteps; i++) {
      final double t = i / (profileSteps - 1);

      final double bump = 0.5 * (1 + math.cos((t * 2 - 1) * math.pi));

      bubbleSeparation[i] = bump;

      final double unwind = bump * bubbleUnwind;
      bubbleCosUnwind[i] = math.cos(unwind);
      bubbleSinUnwind[i] = math.sin(unwind);

      final double intact = (1 - bump * 1.7).clamp(0.0, 1.0);
      bubblePairing[i] = intact * intact;

      final double peel =
          ((t - hybridFraction) / (peelEnd - hybridFraction)).clamp(0.0, 1.0);
      trailPeel[i] = peel * peel * (3 - 2 * peel);

      // Ramped in as well as out. The head passes one sampled point every half
      // second or so, and a table that starts at full strength let each point
      // switch on between one frame and the next, marching the head forward in
      // visible ten-pixel steps.
      final double lead = (t / 0.06).clamp(0.0, 1.0);
      final double reveal = 1 - ((t - 0.55) / 0.45).clamp(0.0, 1.0);
      trailReveal[i] = lead * lead * (3 - 2 * lead) * reveal;
    }
  }

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
