import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/anatomy/anatomy_layout.dart';
import 'package:helixpeek/shared/helix/helix_geometry.dart';

/// The strand points, the rung points and the transcript points, by index,
/// as `HelixModel` lays them out.
int _strandB(HelixModel m, int i) => m.sampleCount + i;
int _rung(HelixModel m, int r) =>
    2 * m.sampleCount + HelixModel.rungPointStride * r;
int _transcript(HelixModel m, int i) =>
    2 * m.sampleCount + HelixModel.rungPointStride * m.rungCount + i;

/// The tables a model holds, by name, as bytes.
Map<String, Uint8List> _tables(HelixModel m) => <String, Uint8List>{
  for (final MapEntry<String, TypedData> t in <String, TypedData>{
    'pointCos': m.pointCos,
    'pointSin': m.pointSin,
    'pointAxial': m.pointAxial,
    'pointWander': m.pointWander,
    'pointRole': m.pointRole,
    'primStart': m.primStart,
    'primEnd': m.primEnd,
    'primPalette': m.primPalette,
    'primKind': m.primKind,
    'bubbleSeparation': m.bubbleSeparation,
    'bubbleCosUnwind': m.bubbleCosUnwind,
    'bubbleSinUnwind': m.bubbleSinUnwind,
    'bubblePairing': m.bubblePairing,
    'trailPeel': m.trailPeel,
    'trailReveal': m.trailReveal,
  }.entries)
    t.key: t.value.buffer.asUint8List(
      t.value.offsetInBytes,
      t.value.lengthInBytes,
    ),
};

void main() {
  group('at 0, the default', () {
    test(
      'is the helix the home screen drew before the move, byte for byte',
      () {
        final Map<String, dynamic> captured = jsonDecode(
          File('test/shared/helix/fixtures/helix_vertices.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>;
        final Map<String, dynamic> home = (captured['models'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .singleWhere(
              (Map<String, dynamic> m) =>
                  m['rungCount'] == HelixModel.defaultRungCount,
            );
        final Map<String, dynamic> was = home['tables'] as Map<String, dynamic>;

        for (final HelixModel model in <HelixModel>[
          HelixModel(),
          HelixModel(unzip: 0),
        ]) {
          _tables(model).forEach((String name, Uint8List bytes) {
            final String before =
                (was[name] as Map<String, dynamic>)['bytes'] as String;
            expect(
              bytes,
              base64Decode(before),
              reason: '$name moved at unzip ${model.unzip}',
            );
          });
        }
      },
    );

    test('and the rows it would unzip to leave it untouched', () {
      final HelixModel model = HelixModel();
      expect(model.unzip, 0);
      // The rows are there to be read, and the helix is still the helix.
      expect(model.rowCos.any((double c) => c != 0), isTrue);
      expect(model.pointSin.any((double s) => s != 0), isTrue);
    });
  });

  group('at 1', () {
    for (final int rungs in <int>[24, 48, 120]) {
      test('lays both strands flat, one row each, at $rungs base pairs', () {
        final HelixModel helix = HelixModel(rungCount: rungs);
        final HelixModel rows = HelixModel(rungCount: rungs, unzip: 1);
        final double backbone = rows.rowBackbone;

        for (int i = 0; i < rows.pointCount; i++) {
          expect(rows.pointSin[i], 0, reason: 'point $i keeps some depth');
          expect(rows.pointCos[i], rows.rowCos[i]);
          expect(
            rows.pointAxial[i],
            helix.pointAxial[i],
            reason: 'point $i moved along the axis',
          );
        }
        for (int i = 0; i < rows.sampleCount; i++) {
          expect(rows.pointCos[i], closeTo(-backbone, 1e-6));
          expect(rows.pointCos[_strandB(rows, i)], closeTo(backbone, 1e-6));
          // The transcript lies along the strand it was read from.
          expect(
            rows.pointCos[_transcript(rows, i)],
            rows.pointCos[_strandB(rows, i)],
          );
        }
      });
    }

    test('makes each base one square tile of its row, in the grid style', () {
      final HelixModel rows = HelixModel(unzip: 1);
      const int k = HelixModel.rungSegments;
      final double pitchAlong = rows.modelHeight / rows.rungCount;

      // Square in pixels: the axis drawn at the model's height and the width
      // at its radius, the tile is the rung pitch less the grid's mortar.
      expect(
        rows.rowTileSide * rows.radius,
        closeTo(pitchAlong * (1 - AnatomyLayout.tileGapRatio), 1e-9),
      );
      expect(rows.rowPitch * rows.radius, closeTo(pitchAlong, 1e-9));

      for (int r = 0; r < rows.rungCount; r++) {
        final int a = _rung(rows, r);
        final int far = a + k + 1;
        // A's base: from A's backbone across A's row, in equal pieces.
        expect(rows.pointCos[a], closeTo(-rows.rowBackbone, 1e-6));
        expect(
          rows.pointCos[a + k] - rows.pointCos[a],
          closeTo(rows.rowTileSide, 1e-6),
        );
        // B's base: from the inner edge of B's row out to B's backbone.
        expect(rows.pointCos[far + k], closeTo(rows.rowBackbone, 1e-6));
        expect(
          rows.pointCos[far + k] - rows.pointCos[far],
          closeTo(rows.rowTileSide, 1e-6),
        );
        for (int j = 0; j < k; j++) {
          expect(
            rows.pointCos[a + j + 1] - rows.pointCos[a + j],
            closeTo(rows.rowTileSide / k, 1e-6),
          );
          expect(
            rows.pointCos[far + j + 1] - rows.pointCos[far + j],
            closeTo(rows.rowTileSide / k, 1e-6),
          );
        }
      }
    });

    test('parts the rows by one row of the grid', () {
      final HelixModel rows = HelixModel(unzip: 1);
      final int a = _rung(rows, 0);
      final double innerA = rows.pointCos[a + HelixModel.rungSegments];
      final double innerB = rows.pointCos[a + HelixModel.rungSegments + 1];
      final double mortar = rows.rowPitch - rows.rowTileSide;

      expect(innerA, lessThan(0));
      expect(innerB, greaterThan(0));
      // Room for one more tile between them, with the grid's mortar either
      // side of it: the pairs have let go.
      expect(innerB - innerA, closeTo(rows.rowTileSide + 2 * mortar, 1e-6));
    });

    test('keeps each base facing its partner, antiparallel', () {
      final HelixModel rows = HelixModel(unzip: 1);
      const int k = HelixModel.rungSegments;
      final List<double> along = <double>[];

      for (int r = 0; r < rows.rungCount; r++) {
        final int a = _rung(rows, r);
        final int b = a + 2 * k + 1;
        // One axial position for the whole rung: a base and its partner face
        // each other across the gap.
        for (int j = a; j <= b; j++) {
          expect(rows.pointAxial[j], rows.pointAxial[a]);
        }
        along.add(rows.pointAxial[a]);
      }
      // A's bases run one way along its row, and the partners that face them
      // run the same positions in the same order: read from its own 5' end,
      // B's row therefore runs back the other way.
      for (int r = 1; r < along.length; r++) {
        expect(along[r], greaterThan(along[r - 1]));
      }

      // Each half keeps its colour: a base, and the complement facing it.
      for (int p = 0; p < rows.primitiveCount; p++) {
        if (rows.primKind[p] != HelixPrimitiveKind.node) {
          continue;
        }
        final int point = rows.primStart[p];
        if (rows.pointCos[point] < 0) {
          final int partner = point + 2 * k + 1;
          final int q = List<int>.generate(rows.primitiveCount, (int i) => i)
              .firstWhere(
                (int i) =>
                    rows.primKind[i] == HelixPrimitiveKind.node &&
                    rows.primStart[i] == partner,
              );
          expect(
            rows.primPalette[q],
            HelixPalette.complementOf(rows.primPalette[p]),
          );
        }
      }
    });
  });

  group('in between', () {
    test('every point moves in a straight line, eased, from helix to rows', () {
      final HelixModel helix = HelixModel();
      for (final double u in <double>[0.1, 0.25, 0.5, 0.8, 0.95]) {
        final HelixModel part = HelixModel(unzip: u);
        final double eased = u * u * (3 - 2 * u);
        for (int i = 0; i < part.pointCount; i++) {
          expect(
            part.pointCos[i],
            closeTo(
              helix.pointCos[i] + (part.rowCos[i] - helix.pointCos[i]) * eased,
              1e-6,
            ),
          );
          expect(
            part.pointSin[i],
            closeTo(helix.pointSin[i] * (1 - eased), 1e-6),
          );
          expect(part.pointAxial[i], helix.pointAxial[i]);
        }
      }
    });

    test('is the path a caller unzipping one stretch at a time can follow', () {
      // A fork unzips point by point: from a model at 0, each point moved by
      // `unzipped` lands exactly where a model built at that value puts it.
      final HelixModel helix = HelixModel();
      final HelixModel part = HelixModel(unzip: 0.4);
      for (int i = 0; i < helix.pointCount; i++) {
        expect(
          Float32List.fromList(<double>[
            HelixModel.unzipped(helix.pointCos[i], helix.rowCos[i], 0.4),
          ]).single,
          part.pointCos[i],
        );
        expect(
          Float32List.fromList(<double>[
            HelixModel.unzipped(helix.pointSin[i], 0, 0.4),
          ]).single,
          part.pointSin[i],
        );
      }
    });

    test('lands on each end exactly, and never passes either', () {
      expect(HelixModel.unzipped(0.3, 0.9, 0), 0.3);
      expect(HelixModel.unzipped(0.3, 0.9, 1), 0.9);
      expect(HelixModel.unzipped(0.3, 0.9, -1), 0.3);
      expect(HelixModel.unzipped(0.3, 0.9, 2), 0.9);
      double previous = 0.3;
      for (int i = 1; i <= 100; i++) {
        final double now = HelixModel.unzipped(0.3, 0.9, i / 100);
        expect(now, greaterThanOrEqualTo(previous));
        previous = now;
      }
    });

    test('never changes what is drawn, only where', () {
      final Map<String, Uint8List> helix = _tables(HelixModel());
      for (final double u in <double>[0.3, 1]) {
        final Map<String, Uint8List> part = _tables(HelixModel(unzip: u));
        for (final String name in <String>[
          'pointAxial',
          'pointWander',
          'pointRole',
          'primStart',
          'primEnd',
          'primPalette',
          'primKind',
          'bubbleSeparation',
          'bubbleCosUnwind',
          'bubbleSinUnwind',
          'bubblePairing',
          'trailPeel',
          'trailReveal',
        ]) {
          expect(part[name], helix[name], reason: '$name changed at $u');
        }
      }
    });
  });
}
