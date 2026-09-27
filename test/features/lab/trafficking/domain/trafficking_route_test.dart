import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/evidence/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/trafficking/domain/route_evidence.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_route.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../../support/test_catalog.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

ProteinConstraint _constraint(ProteinTarget target) =>
    ProteinConstraint.fromJson(_json(target.constraintAsset), target);

GeneRecord _record(ProteinTarget target) =>
    GeneRecordDto.fromJson(_json(target.mockAsset)).toEntity();

/// What the records say, which is nothing about topology.
RouteEvidence _records(ProteinTarget target) =>
    RouteEvidence.of(_constraint(target));

/// The same, with topology added as a trafficking track would add it:
/// [spans] cross the membrane, and nothing else does.
RouteEvidence _topology(ProteinTarget target, List<(int, int)> spans) =>
    RouteEvidence.of(_constraint(target), transmembrane: spans);

TraffickingRoute _route(RouteEvidence evidence) =>
    TraffickingRoute.derive(evidence);

/// CFTR's twelve helices, `Transmembrane` in UniProt P13569 (release
/// 2026_03).
const List<(int, int)> _cftrSpans = <(int, int)>[
  (78, 98),
  (123, 146),
  (196, 216),
  (223, 243),
  (299, 319),
  (340, 358),
  (859, 879),
  (919, 939),
  (991, 1011),
  (1014, 1034),
  (1096, 1116),
  (1131, 1151),
];

/// A made-up precursor, for the rules the twenty do not exercise. Each entry
/// is (start, end, kept); every kept piece is numbered from its own start.
RouteEvidence _synthetic(
  List<(int, int, bool)> spans, {
  String? first,
  String? last,
  List<(int, int)> bridges = const <(int, int)>[],
  List<(int, int)>? transmembrane,
}) {
  final List<ConstraintRegion> regions = <ConstraintRegion>[
    for (int i = 0; i < spans.length; i++)
      ConstraintRegion(
        label: i == 0 && first != null
            ? first
            : i == spans.length - 1 && last != null
            ? last
            : 'piece $i',
        short: '',
        start: spans[i].$1,
        end: spans[i].$2,
        origin: spans[i].$3 ? spans[i].$1 : 1,
        kept: spans[i].$3,
      ),
  ];
  return RouteEvidence(
    regions: regions,
    bridges: bridges,
    transmembrane: transmembrane,
  );
}

void main() {
  group('insulin: secreted, cut, three disulfides', () {
    final TraffickingRoute route = _route(
      _topology(TestCatalog.insulin, const <(int, int)>[]),
    );

    test('goes out through the ER, the Golgi and a vesicle', () {
      expect(route.compartments, <Compartment>[
        Compartment.cytosol,
        Compartment.er,
        Compartment.golgi,
        Compartment.vesicle,
        Compartment.extracellular,
      ]);
      expect(route.resolved, isTrue);
    });

    test('loses its leader and forms its three bridges in the ER', () {
      expect(route.steps[1].events, <RouteEvent>[
        RouteEvent.signalPeptideCleaved,
        RouteEvent.disulfidesFormed,
      ]);
      expect(route.evidence.bridges, hasLength(3));
      expect(route.evidence.signalPeptide?.end, 24);
    });

    test('is cut in the vesicle, into two chains', () {
      expect(route.whereOf(RouteEvent.proproteinCut), Compartment.vesicle);
      expect(
        route.evidence.pieces.map((ConstraintRegion r) => r.label),
        <String>['B chain', 'A chain'],
      );
      expect(
        route.evidence.cutOut.map((ConstraintRegion r) => r.label),
        <String>['B / C cleavage site', 'C-peptide', 'C / A cleavage site'],
      );
    });
  });

  group('SOD1: cytosolic, uncut', () {
    final TraffickingRoute route = _route(
      _topology(TestCatalog.sod1, const <(int, int)>[]),
    );

    test('stays where it is made, and its bridge forms there', () {
      expect(route.steps.single.compartment, Compartment.cytosol);
      expect(route.steps.single.events, <RouteEvent>[
        RouteEvent.disulfidesFormed,
      ]);
      expect(route.resolved, isTrue);
    });

    test('losing the initiator methionine is not a cut', () {
      expect(route.evidence.regions.first.kept, isFalse);
      expect(route.evidence.regions.first.end, 1);
      expect(route.evidence.cut, isFalse);
      expect(route.whereOf(RouteEvent.proproteinCut), isNull);
    });
  });

  group('prion: GPI-anchored', () {
    final TraffickingRoute route = _route(_records(TestCatalog.prion));

    test('ends anchored to the surface, from the records alone', () {
      expect(route.compartments, <Compartment>[
        Compartment.cytosol,
        Compartment.er,
        Compartment.golgi,
        Compartment.vesicle,
        Compartment.gpiAnchored,
      ]);
      expect(route.resolved, isTrue);
      expect(route.steps[1].events, <RouteEvent>[
        RouteEvent.signalPeptideCleaved,
        RouteEvent.disulfidesFormed,
        RouteEvent.gpiAnchorAttached,
      ]);
    });

    test('its anchor signal is what the walk draws as the C-terminal '
        'extension (R3.6)', () {
      final ConstraintRegion gpi = route.evidence.gpiSignal!;
      expect((gpi.start, gpi.end), (231, 253));
      expect(gpi, same(route.evidence.regions.last));

      final GeneRecord record = _record(TestCatalog.prion);
      final AnatomyModel model = AnatomyModel.derive(record);
      final Set<Role> trimmed = <Role>{
        for (int p = record.start; p <= record.end; p++)
          if (model.codingRoleAt(p) case final Role role
              when role.kind == RoleKind.trimmed)
            role,
      };
      expect(trimmed.single.label, 'the C-terminal extension');
      expect(trimmed.single.lengthBp, 3 * (gpi.end - gpi.start + 1));
    });

    test('and swapping it for the anchor is not a proprotein cut', () {
      expect(route.evidence.cut, isFalse);
      expect(route.whereOf(RouteEvent.proproteinCut), isNull);
    });
  });

  group('CFTR: membrane', () {
    test('its helices take it into the ER and hold it in the membrane', () {
      final TraffickingRoute route = _route(
        _topology(TestCatalog.cftr, _cftrSpans),
      );
      expect(route.compartments, <Compartment>[
        Compartment.cytosol,
        Compartment.er,
        Compartment.golgi,
        Compartment.vesicle,
        Compartment.membrane,
      ]);
      expect(route.steps[1].events, <RouteEvent>[RouteEvent.membraneInserted]);
      expect(route.evidence.signalPeptide, isNull);
      expect(route.resolved, isTrue);
    });

    test('from its record alone, the route stops after the cytosol', () {
      final TraffickingRoute route = _route(_records(TestCatalog.cftr));
      expect(route.compartments, <Compartment>[
        Compartment.cytosol,
        Compartment.unknown,
      ]);
      expect(route.unresolved, Unresolved.topology);
    });
  });

  group('the twenty, from their records alone', () {
    final Map<ProteinTarget, TraffickingRoute> routes =
        <ProteinTarget, TraffickingRoute>{
          for (final ProteinTarget target in TestCatalog.all)
            target: _route(_records(target)),
        };

    test('only a GPI-anchor signal settles a route without topology', () {
      for (final MapEntry<ProteinTarget, TraffickingRoute> entry
          in routes.entries) {
        final TraffickingRoute route = entry.value;
        expect(
          route.resolved,
          route.evidence.gpiSignal != null,
          reason: entry.key.slug,
        );
        if (!route.resolved) {
          expect(route.unresolved, Unresolved.topology, reason: entry.key.slug);
          expect(route.destination, Compartment.unknown);
        }
      }
    });

    test('a leader takes the chain as far as the vesicle; no leader, no '
        'further than the cytosol', () {
      for (final MapEntry<ProteinTarget, TraffickingRoute> entry
          in routes.entries) {
        final TraffickingRoute route = entry.value;
        final List<Compartment> before = route.compartments.sublist(
          0,
          route.compartments.length - 1,
        );
        expect(
          before,
          route.evidence.signalPeptide == null
              ? <Compartment>[Compartment.cytosol]
              : <Compartment>[
                  Compartment.cytosol,
                  Compartment.er,
                  Compartment.golgi,
                  Compartment.vesicle,
                ],
          reason: entry.key.slug,
        );
      }
    });

    test('the leader the table names is the record\'s own signal peptide', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final ConstraintRegion? leader = routes[target]!.evidence.signalPeptide;
        final Peptide? signal = _record(target).signalPeptide;
        expect(
          leader == null ? null : leader.end - leader.start + 1,
          signal?.lengthAa,
          reason: target.slug,
        );
      }
    });

    test('nothing reaches the nucleus', () {
      for (final TraffickingRoute route in routes.values) {
        expect(route.compartments, isNot(contains(Compartment.nucleus)));
      }
    });
  });

  group('topology decides the rest', () {
    test('a leader and no span: released', () {
      for (final ProteinTarget target in <ProteinTarget>[
        TestCatalog.lysozyme,
        TestCatalog.amylase,
        TestCatalog.erythropoietin,
      ]) {
        final TraffickingRoute route = _route(
          _topology(target, const <(int, int)>[]),
        );
        expect(route.destination, Compartment.extracellular);
        expect(route.whereOf(RouteEvent.proproteinCut), isNull);
      }
    });

    test('a leader and a span: held in the membrane, and not cut', () {
      // UniProt P05067's one helix, 702-722.
      final TraffickingRoute route = _route(
        _topology(TestCatalog.app, const <(int, int)>[(702, 722)]),
      );
      expect(route.destination, Compartment.membrane);
      expect(route.steps[1].events, <RouteEvent>[
        RouteEvent.signalPeptideCleaved,
        RouteEvent.membraneInserted,
        RouteEvent.disulfidesFormed,
      ]);
      expect(route.evidence.cut, isFalse);
    });

    test('a signal anchor in one piece of two: the other is shed at the '
        'surface', () {
      // UniProt P01375's signal-anchor helix, 36-56, inside the membrane
      // anchor the table cuts the soluble chain away from.
      final TraffickingRoute route = _route(
        _topology(TestCatalog.tnf, const <(int, int)>[(36, 56)]),
      );
      expect(route.compartments, <Compartment>[
        Compartment.cytosol,
        Compartment.er,
        Compartment.golgi,
        Compartment.vesicle,
        Compartment.membrane,
      ]);
      expect(route.steps[1].events, <RouteEvent>[
        RouteEvent.membraneInserted,
        RouteEvent.disulfidesFormed,
      ]);
      expect(route.whereOf(RouteEvent.proproteinCut), Compartment.membrane);
    });

    test('a cut with no span anywhere is made in the cytosol', () {
      final TraffickingRoute route = _route(
        _topology(TestCatalog.ubiquitin, const <(int, int)>[]),
      );
      expect(route.steps.single.compartment, Compartment.cytosol);
      expect(route.steps.single.events, <RouteEvent>[RouteEvent.proproteinCut]);
      expect(route.evidence.pieces, hasLength(3));
    });

    test('without topology, the bridges and the cut wait with the unknown', () {
      final TraffickingRoute route = _route(_records(TestCatalog.tnf));
      expect(route.steps.last.compartment, Compartment.unknown);
      expect(route.steps.last.events, <RouteEvent>[
        RouteEvent.disulfidesFormed,
        RouteEvent.proproteinCut,
      ]);
    });
  });

  group('rules the twenty do not reach', () {
    test('a GPI-anchor signal with no leader contradicts itself', () {
      final TraffickingRoute route = _route(
        _synthetic(
          <(int, int, bool)>[(1, 80, true), (81, 100, false)],
          last: RouteEvidence.gpiSignalLabel,
          transmembrane: const <(int, int)>[],
        ),
      );
      expect(route.compartments, <Compartment>[
        Compartment.cytosol,
        Compartment.unknown,
      ]);
      expect(route.unresolved, Unresolved.conflict);
    });

    test('so does one with a span besides it', () {
      final TraffickingRoute route = _route(
        _synthetic(
          <(int, int, bool)>[(1, 20, false), (21, 80, true), (81, 100, false)],
          first: RouteEvidence.signalPeptideLabel,
          last: RouteEvidence.gpiSignalLabel,
          transmembrane: const <(int, int)>[(40, 60)],
        ),
      );
      expect(route.unresolved, Unresolved.conflict);
    });

    test('a leader named anything else is not one', () {
      final RouteEvidence evidence = _synthetic(
        <(int, int, bool)>[(1, 20, false), (21, 100, true)],
        first: 'Propeptide',
        transmembrane: const <(int, int)>[],
      );
      expect(evidence.signalPeptide, isNull);
      expect(evidence.cutOut.single.label, 'Propeptide');
    });

    test('a propeptide cut off a single chain is still a cut', () {
      final TraffickingRoute route = _route(
        _synthetic(
          <(int, int, bool)>[(1, 20, false), (21, 90, true), (91, 100, false)],
          first: RouteEvidence.signalPeptideLabel,
          transmembrane: const <(int, int)>[],
        ),
      );
      expect(route.evidence.pieces, isEmpty);
      expect(route.whereOf(RouteEvent.proproteinCut), Compartment.vesicle);
    });

    test('pieces that all hold a span are cut on the way, not shed', () {
      final TraffickingRoute route = _route(
        _synthetic(
          <(int, int, bool)>[(1, 50, true), (51, 100, true)],
          transmembrane: const <(int, int)>[(10, 30), (60, 80)],
        ),
      );
      expect(route.whereOf(RouteEvent.proproteinCut), Compartment.vesicle);
      expect(route.destination, Compartment.membrane);
    });
  });
}
