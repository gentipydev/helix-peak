import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/replication/domain/replication_plan.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../../support/test_catalog.dart';
import '../replication_fixtures.dart';

void main() {
  test('refuses exactly the records whose introns arrive shortened', () {
    final List<String> refused = <String>[
      for (final ProteinTarget t in TestCatalog.all)
        if (ReplicationPlan.refusal(recordOf(t)) case final String reason)
          '${t.slug}: $reason',
    ];
    expect(refused, hasLength(3));
    for (final ProteinTarget t in TestCatalog.all) {
      final GeneRecord record = recordOf(t);
      expect(
        ReplicationPlan.refusal(record) != null,
        record.isIntronCompressed,
        reason: t.slug,
      );
      if (record.isIntronCompressed) {
        expect(() => ReplicationPlan.of(record), throwsArgumentError);
      }
    }
    expect(copyable, hasLength(17));
  });

  for (final ProteinTarget t in copyable) {
    group(t.slug, () {
      late final ReplicationPlan plan = planOf(t);

      test('opens in the middle, a leading strand running out each way', () {
        expect(plan.origin, plan.length ~/ 2);
        expect(plan.rightLeading.strand, NewStrand.sense);
        expect(plan.rightLeading.from, plan.origin);
        expect(plan.rightLeading.to, plan.length - 1);
        expect(plan.leftLeading.strand, NewStrand.antisense);
        expect(plan.leftLeading.from, 0);
        expect(plan.leftLeading.to, plan.origin - 1);
        // A polymerase builds 5' to 3' only: both are made the way their
        // fork runs, from a primer at the origin.
        expect(plan.rightLeading.growsUp, isTrue);
        expect(plan.rightLeading.fivePrime, plan.origin);
        expect(plan.leftLeading.growsUp, isFalse);
        expect(plan.leftLeading.fivePrime, plan.origin - 1);
      });

      test(
        'makes each lagging strand backwards, 100 to 200 bases at a time',
        () {
          for (final Fork fork in Fork.values) {
            final List<NewPiece> fragments = plan.fragmentsOf(fork);
            expect(fragments.length, greaterThanOrEqualTo(2));
            for (final NewPiece f in fragments) {
              expect(
                f.length,
                inInclusiveRange(
                  ReplicationPlan.shortestFragment,
                  ReplicationPlan.longestFragment,
                ),
              );
              expect(f.leading, isFalse);
              // Made away from its fork: 5' at the end nearest the fork.
              expect(
                f.strand,
                fork == Fork.right ? NewStrand.antisense : NewStrand.sense,
              );
              expect(f.fivePrime, fork == Fork.right ? f.to : f.from);
              final (int a, int b) = f.primer;
              expect(b - a + 1, ReplicationPlan.primerLength);
              expect(f.covers(a) && f.covers(b), isTrue);
              expect(f.covers(f.fivePrime), isTrue);
            }
            // In the order the fork primes them, each further from the origin.
            for (int k = 1; k < fragments.length; k++) {
              expect(fragments[k].ordinal, k + 1);
              if (fork == Fork.right) {
                expect(fragments[k].from, fragments[k - 1].to + 1);
              } else {
                expect(fragments[k].to, fragments[k - 1].from - 1);
              }
            }
            // The last runs past the end of the record, primer and all.
            final NewPiece last = fragments.last;
            expect(
              fork == Fork.right ? last.to >= plan.length - 1 : last.from <= 0,
              isTrue,
            );
          }
        },
      );

      test('covers every base of both new strands exactly once', () {
        for (final NewStrand strand in NewStrand.values) {
          for (int i = 0; i < plan.length; i++) {
            final int covering = plan.pieces
                .where((NewPiece p) => p.strand == strand && p.covers(i))
                .length;
            expect(covering, 1, reason: '${strand.name} $i');
            expect(plan.pieceAt(strand, i)!.covers(i), isTrue);
          }
        }
      });

      test('primes each fragment as the fork unwinds its 5\' end', () {
        for (final Fork fork in Fork.values) {
          for (final NewPiece f in plan.fragmentsOf(fork)) {
            final double fork_ = fork == Fork.right
                ? plan.rightFork(f.primedAt)
                : plan.leftFork(f.primedAt);
            expect(fork_, f.fivePrime);
            // Nothing of it before; its primer, as RNA, once primed.
            final (int a, int b) = f.primer;
            for (int i = a; i <= b; i++) {
              if (i < 0 || i >= plan.length) {
                continue;
              }
              expect(plan.madeAt(f.strand, i, f.primedAt - 0.01), Made.none);
              expect(plan.madeAt(f.strand, i, f.primedAt), Made.rna);
            }
          }
        }
      });

      test(
        'finishes each fragment as the next is primed: one loop at a time',
        () {
          for (final Fork fork in Fork.values) {
            final List<NewPiece> fragments = plan.fragmentsOf(fork);
            for (int k = 0; k + 1 < fragments.length; k++) {
              expect(fragments[k].doneAt, fragments[k + 1].primedAt);
            }
          }
        },
      );

      test('keeps each leading strand\'s end just behind its fork', () {
        for (final double travel in <double>[20, 60.5, 150, 300]) {
          final int end =
              (plan.rightFork(travel).floor() - ReplicationPlan.trail).clamp(
                0,
                plan.length - 1,
              );
          expect(plan.madeAt(NewStrand.sense, end, travel), Made.dna);
          if (end + 1 < plan.length) {
            expect(plan.madeAt(NewStrand.sense, end + 1, travel), Made.none);
          }
          final int start =
              (plan.leftFork(travel).ceil() + ReplicationPlan.trail).clamp(
                0,
                plan.length - 1,
              );
          expect(plan.madeAt(NewStrand.antisense, start, travel), Made.dna);
          if (start > 0) {
            expect(
              plan.madeAt(NewStrand.antisense, start - 1, travel),
              Made.none,
            );
          }
        }
      });

      test('stitches: a fragment replaces the primer it meets, then seals', () {
        for (final NewPiece piece in plan.pieces) {
          final NewPiece? replacer = plan.replacerOf(piece);
          if (replacer == null) {
            continue;
          }
          expect(replacer.leading, isFalse);
          expect(replacer.strand, piece.strand);
          final (int a, int b) = piece.primer;
          final double filled = replacer.doneAt - ReplicationPlan.sealSpan;
          final int boundary = piece.growsUp ? b : a - 1;
          if (a < 0 || b >= plan.length) {
            continue;
          }
          // Filled in, and a nick left between the primer's place and the
          // piece's own DNA ...
          for (int i = a; i <= b; i++) {
            expect(plan.madeAt(piece.strand, i, filled), Made.dna);
          }
          expect(plan.nickAbove(piece.strand, boundary, filled), isTrue);
          // ... which ligase seals.
          expect(
            plan.nickAbove(piece.strand, boundary, replacer.doneAt),
            isFalse,
          );
          expect(plan.sealedAt(piece, replacer.doneAt), isTrue);
        }
      });

      test('leaves two whole new strands of DNA, no primer and no nick', () {
        final double end = plan.travelEnd;
        for (final NewStrand strand in NewStrand.values) {
          for (int i = 0; i < plan.length; i++) {
            expect(plan.madeAt(strand, i, end), Made.dna, reason: '$strand $i');
            if (i + 1 < plan.length) {
              expect(plan.nickAbove(strand, i, end), isFalse);
            }
          }
        }
      });

      test('writes the record\'s letters on one new strand, and their '
          'complement on the other', () {
        const Map<String, String> pair = <String, String>{
          'A': 'T',
          'T': 'A',
          'G': 'C',
          'C': 'G',
        };
        for (int i = 0; i < plan.length; i += 7) {
          expect(plan.newBaseAt(NewStrand.sense, i), plan.baseAt(i));
          expect(plan.newBaseAt(NewStrand.antisense, i), pair[plan.baseAt(i)]);
        }
      });

      test('names each base by the record position the mutate screen uses', () {
        final GeneRecord record = recordOf(t);
        final AnatomyModel model = AnatomyModel.derive(record);
        for (int i = 0; i < plan.length; i += 53) {
          final int position = plan.positionOf(i);
          expect(position, inInclusiveRange(record.start, record.end));
          expect(model.baseAt(position), plan.baseAt(i), reason: 'index $i');
        }
      });

      test('puts the wrong base in on the leading strand, past the second '
          'primer', () {
        final int site = plan.setPieceSite;
        expect(plan.rightLeading.covers(site), isTrue);
        expect(site, greaterThan(plan.fragmentsOf(Fork.right)[1].to));
        final String wrong = plan.setPieceWrong;
        expect(wrong, isNot(plan.baseAt(site)));
        // A wobble, not a pair: the wrong base is not the template's
        // partner.
        expect(
          wrong,
          isNot(ReplicationPlan.complementOf(plan.partnerAt(site))),
        );
        // The leading polymerase's 3' end sits on the base before the site.
        final double at = plan.setPieceTravel;
        expect(plan.madeAt(NewStrand.sense, site - 1, at), Made.dna);
        expect(plan.madeAt(NewStrand.sense, site, at), Made.none);
      });
    });
  }

  test('the same record always gives the same fragments', () {
    final ProteinTarget insulin = TestCatalog.insulin;
    final ReplicationPlan again = ReplicationPlan.of(recordOf(insulin));
    expect(
      <int>[for (final NewPiece p in again.pieces) p.length],
      <int>[for (final NewPiece p in planOf(insulin).pieces) p.length],
    );
    // And another record, other ones.
    expect(<int>[
      for (final NewPiece p in planOf(TestCatalog.hemoglobin).pieces) p.length,
    ], isNot(<int>[for (final NewPiece p in again.pieces) p.length]));
  });

  test('draws the fragment lengths across their range', () {
    final List<int> lengths = <int>[
      for (final ProteinTarget t in copyable)
        for (final NewPiece p in planOf(t).pieces)
          if (!p.leading) p.length,
    ];
    expect(lengths.length, greaterThan(200));
    final double mean =
        lengths.reduce((int a, int b) => a + b) / lengths.length;
    expect(mean, closeTo(150, 6));
    expect(lengths.where((int l) => l < 125), isNotEmpty);
    expect(lengths.where((int l) => l > 175), isNotEmpty);
  });
}
