import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_mesh.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';

import 'folding_fixtures.dart';

void main() {
  const FoldPalette palette = FoldPalette(
    chains: <String, LinearColour>{
      'chainA': (0.1, 0.5, 0.3),
      'chainB': (0.1, 0.3, 0.1),
      'bonds': (0.8, 0.7, 0.4),
    },
    loose: (0.3, 0.3, 0.3),
    bridge: (0.8, 0.7, 0.4),
    property: _grey,
  );

  FoldMesh meshOf(String slug) =>
      FoldMesh(FoldTimeline(geometryOf(target(slug))), palette);

  /// The centre of ring [station] of [tube]: its vertices are symmetric
  /// about it.
  List<double> ringCentre(FoldTube tube, int station) => <double>[
    for (int a = 0; a < 3; a++)
      <double>[
            for (int j = 0; j < FoldMesh.ring; j++)
              tube.positions[3 * (station * FoldMesh.ring + j) + a],
          ].reduce((double x, double y) => x + y) /
          FoldMesh.ring,
  ];

  double ringReach(FoldTube tube, int station, int vertex) {
    final List<double> centre = ringCentre(tube, station);
    final int v = station * FoldMesh.ring + vertex;
    return math.sqrt(<double>[
      for (int a = 0; a < 3; a++)
        math.pow(tube.positions[3 * v + a] - centre[a], 2).toDouble(),
    ].reduce((double x, double y) => x + y));
  }

  test('the topology never changes, so buffers update in place', () {
    final FoldMesh mesh = meshOf('insulin');
    final List<int> vertices = <int>[
      for (final FoldTube tube in mesh.tubes) tube.positions.length,
    ];
    final List<Uint32List> indices = <Uint32List>[
      for (final FoldTube tube in mesh.tubes) tube.indices,
    ];
    for (final double t in <double>[0.1, 0.4, 0.7, 0.9, 1]) {
      mesh.update(t);
      expect(<int>[
        for (final FoldTube tube in mesh.tubes) tube.positions.length,
      ], vertices);
      for (int i = 0; i < mesh.tubes.length; i++) {
        expect(identical(mesh.tubes[i].indices, indices[i]), isTrue);
      }
    }
    // One tube a chain, a ring on every residue and the samples between.
    expect(mesh.tubes, hasLength(2));
    expect(mesh.tubes.first.stations, (21 - 1) * mesh.samples + 1);
  });

  test('at the end the backbone runs where the model’s ribbon does', () {
    for (final String slug in <String>['insulin', 'myoglobin', 'prion', 'tnf']) {
      final FoldMesh mesh = meshOf(slug)..update(1);
      final FoldGeometry g = mesh.geometry;
      int measured = 0;
      for (final FoldTube tube in mesh.tubes) {
        for (int k = 0; k < tube.end - tube.start; k++) {
          final FoldResidue r = g.drawn[tube.start + k];
          if (!r.isOrdered ||
              (r.shape == FoldShape.strand && r.ribbonAt == null)) {
            continue;
          }
          // The measured ribbon where there is one, the CA where not.
          final ModelPoint at = r.ribbonAt ?? r.ca!;
          if (r.ribbonAt != null) {
            measured++;
          }
          final List<double> centre = ringCentre(tube, k * mesh.samples);
          // flutter_scene holds the model with its z turned round.
          expect(centre[0], closeTo(at.$1, 1e-5), reason: '$slug ${r.number}');
          expect(centre[1], closeTo(at.$2, 1e-5), reason: '$slug ${r.number}');
          expect(centre[2], closeTo(-at.$3, 1e-5), reason: '$slug ${r.number}');
        }
      }
      expect(measured, greaterThan(0), reason: slug);
    }
  });

  test('at the end the ribbon lies across the way the model’s does', () {
    // The measured direction, turned square to the tube's own way: the same
    // direction but where the tube and the model's ribbon part at an end.
    final List<double> alignment = <double>[];
    for (final String slug in <String>['insulin', 'ubiquitin', 'sod1']) {
      final FoldMesh mesh = meshOf(slug)..update(1);
      final FoldGeometry g = mesh.geometry;
      for (final FoldTube tube in mesh.tubes) {
        for (int k = 1; k + 1 < tube.end - tube.start; k++) {
          final ModelPoint? lies = g.drawn[tube.start + k].ribbonAcross;
          if (lies == null) {
            continue;
          }
          final int station = k * mesh.samples;
          final List<double> centre = ringCentre(tube, station);
          final int v = station * FoldMesh.ring;
          final List<double> across = <double>[
            for (int a = 0; a < 3; a++) tube.positions[3 * v + a] - centre[a],
          ];
          final double length = math.sqrt(
            across.map((double x) => x * x).reduce((double x, double y) => x + y),
          );
          alignment.add(
            ((across[0] * lies.$1 + across[1] * lies.$2 - across[2] * lies.$3) /
                    length)
                .abs(),
          );
        }
      }
    }
    alignment.sort();
    expect(alignment[alignment.length ~/ 2], greaterThan(0.995));
    expect(alignment.first, greaterThan(0.85));
  });

  test('at the end each residue is as wide and as thick as the model draws it', () {
    final FoldMesh mesh = meshOf('insulin')..update(1);
    final FoldGeometry g = mesh.geometry;
    final FoldCartoon cartoon = g.track.cartoon;
    final FoldTube b = mesh.tubes[1];
    for (int k = 1; k + 1 < b.end - b.start; k++) {
      final FoldResidue r = g.drawn[b.start + k];
      final int station = k * mesh.samples;
      final (double width, double thickness) = switch (r.shape!) {
        FoldShape.helix => (cartoon.helixHalfWidth, cartoon.helixHalfThickness),
        _ => (cartoon.loopRadius, cartoon.loopRadius),
      };
      // Vertex 0 lies across the ribbon, vertex 2 a quarter turn round.
      expect(ringReach(b, station, 0), closeTo(width * g.unit, 1e-5));
      expect(ringReach(b, station, 2), closeTo(thickness * g.unit, 1e-5));
    }
  });

  test('a peptide the model draws as a tube ends as that tube', () {
    final FoldMesh mesh = meshOf('oxytocin')..update(1);
    final FoldGeometry g = mesh.geometry;
    final FoldTube tube = mesh.tubes.single;
    for (int k = 0; k < tube.end - tube.start; k++) {
      for (int j = 0; j < FoldMesh.ring; j++) {
        expect(
          ringReach(tube, k * mesh.samples, j),
          closeTo(g.track.cartoon.tubeRadius * g.unit, 1e-5),
        );
      }
    }
  });

  test('a strand ends as a flat slab, its arrow wider still', () {
    final FoldMesh mesh = meshOf('ubiquitin')..update(1);
    final FoldGeometry g = mesh.geometry;
    final FoldTube tube = mesh.tubes.single;
    final FoldCartoon cartoon = g.track.cartoon;
    // Ubiquitin's first strand is residues 1 to 7: 3 is its body, 6 the
    // arrow's base, 7 its point.
    int indexOf(int number) =>
        g.drawn.indexWhere((FoldResidue r) => r.number == number) - tube.start;
    expect(
      ringReach(tube, indexOf(3) * mesh.samples, 0),
      closeTo(cartoon.strandHalfWidth * g.unit, 1e-5),
    );
    expect(
      ringReach(tube, indexOf(6) * mesh.samples, 0),
      closeTo(cartoon.strandHalfWidth * FoldMesh.arrowWidening * g.unit, 1e-5),
    );
    expect(
      ringReach(tube, indexOf(7) * mesh.samples, 0),
      closeTo(cartoon.loopRadius * g.unit, 1e-5),
    );
  });

  test('every residue starts as a bead, and the placed ones melt away', () {
    final FoldMesh mesh = meshOf('prion');
    final FoldGeometry g = mesh.geometry;
    for (int i = 0; i < g.length; i++) {
      expect(mesh.sphereRadii[i], greaterThan(0), reason: '$i');
    }
    mesh.update(1);
    for (int i = 0; i < g.length; i++) {
      // What the entry never placed stays a bead; the model does not draw it,
      // and it goes as the fold hands over.
      expect(
        mesh.sphereRadii[i] > 0,
        !g.drawn[i].isOrdered,
        reason: '${g.drawn[i].number}',
      );
    }
  });

  test('a bridge’s cysteines stay beads until it closes', () {
    final FoldMesh mesh = meshOf('insulin');
    final FoldGeometry g = mesh.geometry;
    final (int a, int b) = g.bridges.first;
    mesh.update(0.8);
    expect(mesh.sphereRadii[a], closeTo(mesh.bead * g.unit, 1e-6));
    expect(mesh.sphereRadii[b], closeTo(mesh.bead * g.unit, 1e-6));
    mesh.update(1);
    expect(mesh.sphereRadii[a], 0);
    expect(mesh.sphereRadii[b], 0);
  });

  test('closed, a bridge is the model’s rods: CA, CB, SG and across', () {
    final FoldMesh mesh = meshOf('insulin');
    final FoldGeometry g = mesh.geometry;
    expect(mesh.rodRadii.every((double r) => r == 0), isTrue);
    mesh.update(1);
    for (int b = 0; b < g.bridges.length; b++) {
      final List<ModelPoint> path = g.bridgePaths[b];
      List<double> native(ModelPoint p) => <double>[p.$1, p.$2, -p.$3];
      final List<double> middle = <double>[
        for (int a = 0; a < 3; a++) (native(path[2])[a] + native(path[3])[a]) / 2,
      ];
      final List<List<List<double>>> halves = <List<List<double>>>[
        <List<double>>[native(path[0]), native(path[1]), native(path[2]), middle],
        <List<double>>[native(path[5]), native(path[4]), native(path[3]), middle],
      ];
      for (int half = 0; half < 2; half++) {
        for (int s = 0; s < 3; s++) {
          final int r = b * 6 + half * 3 + s;
          expect(mesh.rodRadii[r], closeTo(g.track.cartoon.rodRadius * g.unit, 1e-6));
          for (int a = 0; a < 3; a++) {
            expect(mesh.rodFrom[3 * r + a], closeTo(halves[half][s][a], 1e-5));
            expect(mesh.rodTo[3 * r + a], closeTo(halves[half][s + 1][a], 1e-5));
          }
        }
      }
    }
  });

  test('a bead is as large as the unfolded chain leaves room for', () {
    // Insulin's 51 residues spread out; lysozyme's 130 are packed closer,
    // and CFTR's 1,480 as close as a bead can be drawn.
    expect(meshOf('insulin').bead, closeTo(1.2, 0.1));
    expect(meshOf('lysozyme').bead, closeTo(0.75, 0.05));
    expect(meshOf('cftr').bead, FoldMesh.beadRange.$1);
  });

  test('the same moment is the same mesh', () {
    final FoldMesh one = meshOf('lysozyme')..update(0.6);
    final FoldMesh two = FoldMesh(one.timeline, palette)..update(0.6);
    expect(two.tubes.first.positions, one.tubes.first.positions);
    expect(two.sphereRadii, one.sphereRadii);
  });
}

LinearColour _grey(String letter) => (0.5, 0.5, 0.5);
