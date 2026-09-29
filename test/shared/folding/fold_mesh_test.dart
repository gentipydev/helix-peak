import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_mesh.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';

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

  double ringRadius(FoldTube tube, int station) {
    final List<double> centre = ringCentre(tube, station);
    final int v = station * FoldMesh.ring;
    return math.sqrt(<double>[
      for (int a = 0; a < 3; a++)
        math.pow(tube.positions[3 * v + a] - centre[a], 2).toDouble(),
    ].reduce((double x, double y) => x + y));
  }

  test('a thread only where the entry placed nothing, hung from its anchors', () {
    // Insulin and lysozyme are placed whole: the model's own mesh is all.
    expect(meshOf('insulin').tubes, isEmpty);
    expect(meshOf('lysozyme').tubes, isEmpty);
    for (final String slug in <String>['prion', 'somatotropin', 'cftr']) {
      final FoldMesh mesh = meshOf(slug);
      final FoldGeometry g = mesh.geometry;
      expect(mesh.tubes, hasLength(g.loose.length), reason: slug);
      for (int k = 0; k < g.loose.length; k++) {
        final LooseRun run = g.loose[k];
        final FoldTube tube = mesh.tubes[k];
        expect(tube.start, run.before >= 0 ? run.before : run.start);
        expect(tube.end, run.after >= 0 ? run.after + 1 : run.end);
        for (int i = tube.start; i < tube.end; i++) {
          expect(
            g.drawn[i].isOrdered,
            i == run.before || i == run.after,
            reason: '$slug ${g.drawn[i].number}',
          );
        }
      }
    }
  });

  test('the topology never changes, so buffers update in place', () {
    final FoldMesh mesh = meshOf('prion');
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
    // A ring on every residue and the samples between.
    final FoldTube first = mesh.tubes.first;
    expect(first.stations, (first.end - first.start - 1) * mesh.samples + 1);
  });

  test('a thread closes to a point where the model’s own mesh takes over', () {
    for (final String slug in <String>['prion', 'somatotropin']) {
      final FoldMesh mesh = meshOf(slug)..update(0.5);
      final FoldGeometry g = mesh.geometry;
      final double thread = FoldMesh.threadRadius * g.unit;
      for (final FoldTube tube in mesh.tubes) {
        final int last = tube.stations - 1;
        final bool fromAnchor = g.drawn[tube.start].isOrdered;
        final bool toAnchor = g.drawn[tube.end - 1].isOrdered;
        expect(ringRadius(tube, 0), fromAnchor ? closeTo(0, 1e-12) : closeTo(thread, 1e-7));
        expect(ringRadius(tube, last), toAnchor ? closeTo(0, 1e-12) : closeTo(thread, 1e-7));
        // Half a residue in, it is the thread again.
        if (fromAnchor && last > mesh.samples) {
          expect(ringRadius(tube, mesh.samples ~/ 2), closeTo(thread, 1e-7));
        }
      }
    }
  });

  test('what the entry never placed shrinks away as the fold finishes', () {
    final FoldMesh mesh = meshOf('prion');
    final FoldGeometry g = mesh.geometry;
    final FoldTube tail = mesh.tubes.first;
    final int middle = tail.stations ~/ 2;
    mesh.update(FoldTimeline.bridgesClosedAt);
    expect(ringRadius(tail, middle), closeTo(FoldMesh.threadRadius * g.unit, 1e-7));
    mesh.update(1);
    expect(ringRadius(tail, middle), closeTo(0, 1e-12));
    for (int i = 0; i < g.length; i++) {
      expect(mesh.sphereRadii[i], 0, reason: '${g.drawn[i].number}');
    }
  });

  test('every residue starts as a bead, and the placed ones melt away', () {
    final FoldMesh mesh = meshOf('prion');
    final FoldGeometry g = mesh.geometry;
    for (int i = 0; i < g.length; i++) {
      expect(mesh.sphereRadii[i], greaterThan(0), reason: '$i');
    }
    mesh.update(FoldTimeline.bridgesClosedAt);
    for (int i = 0; i < g.length; i++) {
      // What the entry never placed is still a bead as the bridges close;
      // the model does not draw it, and it goes as the fold finishes.
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

  test('a bead is as large as the unfolded chain leaves room for', () {
    // Insulin's 51 residues spread out; lysozyme's 130 are packed closer,
    // and CFTR's 1,480 as close as a bead can be drawn.
    expect(meshOf('insulin').bead, closeTo(1.2, 0.1));
    expect(meshOf('lysozyme').bead, closeTo(0.75, 0.05));
    expect(meshOf('cftr').bead, FoldMesh.beadRange.$1);
  });

  test('the same moment is the same mesh', () {
    final FoldMesh one = meshOf('prion')..update(0.6);
    final FoldMesh two = FoldMesh(one.timeline, palette)..update(0.6);
    expect(two.tubes.first.positions, one.tubes.first.positions);
    expect(two.sphereRadii, one.sphereRadii);
  });
}

LinearColour _grey(String letter) => (0.5, 0.5, 0.5);
