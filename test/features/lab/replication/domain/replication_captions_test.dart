import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/replication/domain/fidelity.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_captions.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_plan.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_timeline.dart';
import 'package:helixpeek/shared/format.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';

import '../../../../support/test_catalog.dart';
import '../replication_fixtures.dart';

void main() {
  test('names no protein and no gene, in any chapter, at any fidelity', () {
    final List<String> names = <String>[
      for (final ProteinTarget t in TestCatalog.all) ...<String>[
        t.display.toLowerCase(),
        t.gene.toLowerCase(),
        t.slug,
      ],
    ];
    for (final ProteinTarget t in copyable) {
      final ReplicationPlan plan = planOf(t);
      final ReplicationTimeline timeline = ReplicationTimeline(plan);
      final ReplicationCaptions captions = ReplicationCaptions(plan);
      final ErrorTally tally = ErrorTally.of(plan);
      for (final PhaseMark mark in timeline.phases) {
        for (final Fidelity f in Fidelity.values) {
          final String words = <String>[
            captions.captionOf(timeline.stateAt(mark.t), f),
            ReplicationCaptions.rateOf(f),
            captions.perCopy(f),
            captions.tallyOf(tally, f),
          ].join(' ').toLowerCase();
          for (final String name in names) {
            expect(
              RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(words),
              isFalse,
              reason: '${t.slug}, ${mark.name}: names $name',
            );
          }
        }
      }
    }
  });

  test('counts off the record: its length, the first fragment, the site', () {
    final ReplicationPlan plan = planOf(TestCatalog.insulin);
    final ReplicationTimeline timeline = ReplicationTimeline(plan);
    final ReplicationCaptions captions = ReplicationCaptions(plan);
    String at(String key) => captions.captionOf(
      timeline.stateAt(
        timeline.phases.firstWhere((PhaseMark m) => m.captionKey == key).t,
      ),
      Fidelity.repair,
    );
    expect(at('origin'), contains('${grouped(plan.length)} base pairs'));
    expect(
      at('lagging'),
      contains(
        '${grouped(plan.fragmentsOf(Fork.right).first.length)} bases back',
      ),
    );
    expect(
      at('proofreading'),
      contains('At base ${grouped(plan.positionOf(plan.setPieceSite))}'),
    );
    expect(at('done'), contains('${grouped(plan.length)} base pairs'));
  });

  test('the set piece says what the reader chose', () {
    final ReplicationPlan plan = planOf(TestCatalog.insulin);
    final ReplicationCaptions captions = ReplicationCaptions(plan);
    final String wrong = plan.setPieceWrong;
    final String right = plan.baseAt(plan.setPieceSite);
    expect(
      captions.proofreading(Fidelity.polymerase),
      allOf(
        contains('the $wrong stays'),
        contains('the record reads $wrong there, not $right'),
      ),
    );
    for (final Fidelity f in <Fidelity>[
      Fidelity.proofreading,
      Fidelity.repair,
    ]) {
      expect(
        captions.proofreading(f),
        allOf(contains('cuts the $wrong out'), contains('puts in $right')),
      );
    }
  });

  test('says how often a copy of this record keeps an error', () {
    final ReplicationPlan plan = planOf(TestCatalog.insulin);
    final ReplicationCaptions captions = ReplicationCaptions(plan);
    for (final Fidelity f in Fidelity.values) {
      final double each = 2 * plan.length * f.rate;
      expect(
        captions.perCopy(f),
        contains('one copy in ${ReplicationCaptions.roughly(1 / each)}'),
      );
    }
    expect(ReplicationCaptions.roughly(11.06), '11');
    expect(ReplicationCaptions.roughly(3496.2), '3,500');
    expect(ReplicationCaptions.roughly(1104779), '1,100,000');
  });
}
