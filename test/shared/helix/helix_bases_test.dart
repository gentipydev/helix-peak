import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/helix/helix_geometry.dart';

/// Strand A's base at each rung, read back off a model's own primitives: the
/// first half of every rung carries it.
Uint8List _trackOf(HelixModel model) {
  final Uint8List track = Uint8List(model.rungCount);
  int rung = 0;
  for (int p = 0; p < model.primitiveCount && rung < model.rungCount; p++) {
    if (model.primKind[p] != HelixPrimitiveKind.rungHalf) {
      continue;
    }
    track[rung] = model.primPalette[p];
    // Skip the rest of this rung: both halves, in their pieces.
    p += 2 * HelixModel.rungSegments - 1;
    rung++;
  }
  return track;
}

double _gap(HelixModel model, int i, int j) {
  final double dx = model.pointCos[i] - model.pointCos[j];
  final double dy = model.pointSin[i] - model.pointSin[j];
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  test('reads a base letter into its slot, and nothing else', () {
    expect(HelixPalette.ofBase('A'), HelixPalette.adenine);
    expect(HelixPalette.ofBase('t'), HelixPalette.thymine);
    expect(HelixPalette.ofBase('G'), HelixPalette.guanine);
    expect(HelixPalette.ofBase('c'), HelixPalette.cytosine);
    expect(() => HelixPalette.ofBase('N'), throwsArgumentError);
    expect(() => HelixPalette.ofBase('U'), throwsArgumentError);
  });

  test('given its own track, it is the default model, byte for byte', () {
    // So the path a real sequence takes computes exactly what the home
    // screen's does: only where the bases come from differs.
    for (final int rungs in <int>[24, 48, 120]) {
      final HelixModel own = HelixModel(rungCount: rungs);
      final HelixModel given = HelixModel(
        rungCount: rungs,
        bases: _trackOf(own),
      );
      for (final (TypedData a, TypedData b) in <(TypedData, TypedData)>[
        (own.pointCos, given.pointCos),
        (own.pointSin, given.pointSin),
        (own.pointAxial, given.pointAxial),
        (own.pointWander, given.pointWander),
        (own.pointRole, given.pointRole),
        (own.rowCos, given.rowCos),
        (own.primStart, given.primStart),
        (own.primEnd, given.primEnd),
        (own.primPalette, given.primPalette),
        (own.primKind, given.primKind),
      ]) {
        expect(
          b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes),
          a.buffer.asUint8List(a.offsetInBytes, a.lengthInBytes),
        );
      }
    }
  });

  test('colours and splits every rung by the base it is given', () {
    // Every base, then every pair of neighbours, so no rung is like the one
    // the default track would have put there by chance.
    final List<String> letters = 'ATGCAATTGGCCAGTCGATC'.split('');
    final Uint8List bases = Uint8List.fromList(<int>[
      for (final String letter in letters) HelixPalette.ofBase(letter),
    ]);
    final HelixModel model = HelixModel(rungCount: bases.length, bases: bases);
    final int rungBase = 2 * model.sampleCount;

    expect(_trackOf(model), bases);
    for (int r = 0; r < model.rungCount; r++) {
      final int a = rungBase + HelixModel.rungPointStride * r;
      final int b = a + 2 * HelixModel.rungSegments + 1;
      final double span = _gap(model, a, b);
      final double reach =
          _gap(model, a, a + HelixModel.rungSegments) / span +
          HelixModel.bondGapFraction / 2;
      // A purine reaches past the middle; the pyrimidine opposite does not.
      expect(
        reach,
        closeTo(
          HelixPalette.isPurine(bases[r])
              ? HelixModel.purineReach
              : 1 - HelixModel.purineReach,
          1e-4,
        ),
        reason: 'rung $r, ${letters[r]}',
      );
    }

    // The far half of each rung, and its node, carry the complement.
    int rung = 0;
    for (int p = 0; p < model.primitiveCount; p++) {
      if (model.primKind[p] == HelixPrimitiveKind.node &&
          model.primStart[p] == rungBase + HelixModel.rungPointStride * rung) {
        expect(model.primPalette[p], bases[rung]);
        expect(
          model.primPalette[p + 1],
          HelixPalette.complementOf(bases[rung]),
        );
        rung++;
      }
    }
    expect(rung, model.rungCount);
  });

  test('refuses a track that is not one base slot per rung', () {
    expect(
      () => HelixModel(rungCount: 4, bases: Uint8List(3)),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => HelixModel(
        rungCount: 2,
        bases: Uint8List.fromList(<int>[0, HelixPalette.backbone]),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
