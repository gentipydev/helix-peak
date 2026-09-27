import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';
import 'package:helixpeek/features/lab/replication/domain/fidelity.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_plan.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../../support/test_catalog.dart';
import '../replication_fixtures.dart';

void main() {
  test('each level keeps an order of magnitude the literature gives it', () {
    expect(Fidelity.polymerase.range, (1e-5, 1e-4));
    expect(Fidelity.proofreading.range, (1e-7, 1e-7));
    expect(Fidelity.repair.range, (1e-10, 1e-9));
    for (final Fidelity f in Fidelity.values) {
      expect(f.rate, inInclusiveRange(f.range.$1, f.range.$2));
    }
    expect(Fidelity.proofreading.rate, lessThan(Fidelity.polymerase.rate));
    expect(Fidelity.repair.rate, lessThan(Fidelity.proofreading.rate));
    // Each lets through its own rate of what reached it.
    expect(
      Fidelity.polymerase.rate * Fidelity.proofreading.letThrough,
      closeTo(Fidelity.proofreading.rate, 1e-15),
    );
    expect(
      Fidelity.proofreading.rate * Fidelity.repair.letThrough,
      closeTo(Fidelity.repair.rate, 1e-18),
    );
  });

  test('errors fall at the polymerase\'s rate, through every record', () {
    int made = 0;
    int copied = 0;
    for (final ProteinTarget t in copyable) {
      final ErrorTally tally = ErrorTally.of(planOf(t));
      made += tally.made.length;
      copied += tally.basesCopied;
    }
    // Across all of them about a hundred thousand errors: the rate is held
    // to a few per cent.
    expect(made / copied, closeTo(Fidelity.polymerase.rate, 0.03 * 3.2e-5));
  });

  for (final ProteinTarget t in copyable) {
    test(
      '${t.slug}: what gets through one level got through the one before',
      () {
        final ReplicationPlan plan = planOf(t);
        final ErrorTally tally = ErrorTally.of(plan);
        final List<CopyingError> polymerase = tally.survivors(
          Fidelity.polymerase,
        );
        final List<CopyingError> proofread = tally.survivors(
          Fidelity.proofreading,
        );
        final List<CopyingError> repaired = tally.survivors(Fidelity.repair);
        expect(polymerase, tally.made);
        expect(polymerase.toSet().containsAll(proofread), isTrue);
        expect(proofread.toSet().containsAll(repaired), isTrue);
        for (final CopyingError e in tally.made) {
          expect(e.copy, inInclusiveRange(1, tally.copies));
          expect(e.index, inInclusiveRange(0, plan.length - 1));
          expect(e.newBase, isNot(plan.baseAt(e.index)));
          expect(<String>['A', 'C', 'G', 'T'], contains(e.newBase));
        }
      },
    );
  }

  test('the same record always makes the same errors', () {
    final ReplicationPlan plan = planOf(TestCatalog.insulin);
    final List<(int, int, String)> a = <(int, int, String)>[
      for (final CopyingError e in ErrorTally.of(plan).made)
        (e.copy, e.index, e.newBase),
    ];
    final List<(int, int, String)> b = <(int, int, String)>[
      for (final CopyingError e in ErrorTally.of(plan).made)
        (e.copy, e.index, e.newBase),
    ];
    expect(a, b);
    expect(a, isNotEmpty);
  });

  test('switching a layer off lets errors through; with all three, the '
      'expectation is a small fraction of one', () {
    final ErrorTally tally = ErrorTally.of(planOf(TestCatalog.insulin));
    expect(tally.expected(Fidelity.polymerase), greaterThan(10));
    expect(tally.expected(Fidelity.proofreading), lessThan(1));
    expect(tally.expected(Fidelity.repair), lessThan(0.01));
    expect(tally.survivors(Fidelity.polymerase).length, greaterThan(10));
  });

  test(
    'an error that gets through opens as an edit the mutate engine reads',
    () {
      for (final ProteinTarget t in <ProteinTarget>[
        TestCatalog.insulin,
        TestCatalog.glucagon, // a minus-strand record
        TestCatalog.relaxin, // and another
      ]) {
        final ReplicationPlan plan = planOf(t);
        final GeneRecord record = recordOf(t);
        final AnatomyModel model = AnatomyModel.derive(record);
        final ErrorTally tally = ErrorTally.of(plan);
        for (final CopyingError e in tally.made.take(12)) {
          final Substitution edit = e.editOf(plan);
          expect(edit.newBase, e.newBase);
          expect(EditEligibility.of(record, edit.position), isA<Eligible>());
          // The base it replaces is the record's own at that index.
          expect(model.baseAt(edit.position), plan.baseAt(e.index));
          expect(() => classify(record, edit), returnsNormally);
          expect(applyEdit(record, edit).sequence, isNot(record.sequence));
        }
      }
    },
  );
}
