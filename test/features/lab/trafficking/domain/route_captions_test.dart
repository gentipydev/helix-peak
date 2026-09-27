import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/trafficking/domain/route_captions.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_route.dart';
import 'package:helixpeek/shared/format.dart';

import '../../../../support/test_catalog.dart';
import '../trafficking_fixtures.dart';

/// Every caption of [target]'s route, in order.
List<String> _captions(ProteinTarget target, {bool topology = true}) {
  final TraffickingRoute route = routeOf(target, topology: topology);
  final RouteCaptions captions = RouteCaptions(
    route,
    chains: target.facts.chains,
  );
  return <String>[
    for (int i = 0; i < route.steps.length; i++) captions.captionOf(i),
  ];
}

void main() {
  group('built from the record, for every protein', () {
    for (final bool topology in <bool>[true, false]) {
      test(topology ? 'with its topology' : 'from its records alone', () {
        for (final ProteinTarget target in TestCatalog.all) {
          for (final String caption in _captions(target, topology: topology)) {
            expect(caption, isNotEmpty, reason: target.slug);
            expect(
              namesAProtein(caption),
              isFalse,
              reason: '${target.slug}: $caption',
            );
            expect(
              caption,
              isNot(contains(tissueWords)),
              reason: '${target.slug}: $caption',
            );
            expect(caption, endsWith('.'), reason: target.slug);
          }
        }
      });
    }
  });

  test('insulin: its leader, its three bridges, and its cut', () {
    expect(_captions(TestCatalog.insulin), <String>[
      'A ribosome in the cytosol begins the chain. Its first 24 residues are '
          'a signal peptide, which takes the ribosome to the ER as the rest '
          'is made.',
      'In the ER, the signal peptide, residues 1–24, is cut off. Three '
          'disulfide bridges form.',
      'It moves on through the Golgi.',
      'A vesicle buds from the Golgi and carries it toward the surface. On '
          'the way, the precursor is cut into three pieces.',
      'The vesicle fuses with the membrane and lets it out of the cell.',
    ]);
  });

  test('without topology, the last step says what is missing', () {
    expect(
      _captions(TestCatalog.insulin, topology: false).last,
      'The vesicle fuses with the membrane. Whether the chain is let go or '
      'stays in it turns on whether any stretch of it crosses a membrane, '
      'and its record does not say.',
    );
    expect(_captions(TestCatalog.sod1, topology: false), <String>[
      'A ribosome in the cytosol makes the chain, which has no signal '
          'peptide to take it to the ER.',
      'Whether it stays in the cytosol or goes into the ER membrane turns on '
          'whether any stretch of it crosses a membrane, and its record does '
          'not say. So does where its one disulfide bridge forms.',
    ]);
  });

  test('SOD1 stays in the cytosol, and bridges itself there', () {
    expect(_captions(TestCatalog.sod1), <String>[
      'A ribosome in the cytosol makes all 154 residues, with no signal '
          'peptide and no stretch that crosses a membrane to send the chain '
          'elsewhere. Here, in the cytosol, its one disulfide bridge forms.',
    ]);
  });

  test('the prion protein trades its last residues for an anchor', () {
    final List<String> captions = _captions(TestCatalog.prion);
    expect(
      captions[1],
      'In the ER, the signal peptide, residues 1–22, is cut off. One '
      'disulfide bridge forms. Residues 231–253 are cut off, and a GPI anchor '
      'is attached to residue 230 in their place.',
    );
    expect(
      captions.last,
      'The vesicle fuses with the membrane, and the chain stays on its outer '
      'face, held by the anchor.',
    );
  });

  test('CFTR is threaded through the membrane twelve times', () {
    final List<String> captions = _captions(TestCatalog.cftr);
    expect(
      captions.first,
      'A ribosome in the cytosol begins the chain. Its first stretch that '
      'crosses a membrane, residues 78–98, takes the ribosome to the ER as '
      'the rest is made.',
    );
    expect(
      captions[1],
      'In the ER, twelve stretches of it cross the membrane, back and forth, '
      'and hold it there.',
    );
    expect(
      captions.last,
      'The vesicle fuses with the membrane, and the chain stays in it, held '
      'by the twelve stretches that cross it.',
    );
  });

  test('TNF is anchored by one span and shed at the surface', () {
    final List<String> captions = _captions(TestCatalog.tnf);
    expect(
      captions[1],
      'In the ER, residues 36–56 cross the membrane and hold the chain in it. '
      'One disulfide bridge forms.',
    );
    expect(
      captions[3],
      'A vesicle buds from the Golgi and carries it toward the surface.',
    );
    expect(
      captions.last,
      'The vesicle fuses with the membrane, and the chain stays in it, held '
      'by the stretch that crosses it. There it is cut between residues 76 '
      'and 77: the piece outside the membrane is let go, and the piece that '
      'crosses it stays.',
    );
  });

  test('APP is held by one span after its leader is cut off', () {
    expect(
      _captions(TestCatalog.app)[1],
      'In the ER, the signal peptide, residues 1–17, is cut off. Residues '
      '702–722 cross the membrane and hold the chain in it. Nine disulfide '
      'bridges form.',
    );
  });

  test('polyubiquitin is cut in the cytosol, its last residue trimmed', () {
    expect(
      _captions(TestCatalog.ubiquitin).single,
      endsWith(
        'Here, in the cytosol, the precursor is cut into three pieces, and '
        'residue 229 is trimmed off its end.',
      ),
    );
  });

  test('pieces that overlap as alternatives are not named', () {
    // Glucagon's table divides its precursor six ways, but the walk draws it
    // as one chain: what it becomes is a choice this page does not make.
    expect(TestCatalog.glucagon.facts.chains, 1);
    expect(
      _captions(TestCatalog.glucagon)[3],
      'A vesicle buds from the Golgi and carries it toward the surface. On '
      'the way, the precursor is cut.',
    );
  });

  test('the count of pieces is the walk’s own', () {
    for (final ProteinTarget target in <ProteinTarget>[
      TestCatalog.oxytocin,
      TestCatalog.vasopressin,
      TestCatalog.relaxin,
    ]) {
      expect(
        _captions(target)[3],
        endsWith(
          'the precursor is cut into ${spelled(target.facts.chains)} pieces.',
        ),
        reason: target.slug,
      );
    }
  });
}
