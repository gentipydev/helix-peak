import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/biology/genetic_code.dart';
import 'package:helixpeek/core/biology/nmd.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';
import 'package:helixpeek/shared/format.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

/// Every `t` worth looking at: each phase boundary, and a spread of points
/// inside every beat.
List<double> _samples(TranslationTimeline timeline, {int perBeat = 12}) =>
    <double>[
      ...timeline.boundaries,
      for (int b = 0; b < timeline.beats; b++)
        for (int i = 1; i < perBeat; i++) timeline.beatStart(b + i / perBeat),
    ]..sort();

void main() {
  final GeneRecord insulin = _gene('ins');
  final GeneRecord p53 = _gene('tp53');
  final GeneRecord relaxin = _gene('rln2');

  final TranslationTimeline ins = TranslationTimeline(insulin);
  final TranslationTimeline tp53 = TranslationTimeline(p53);
  final TranslationTimeline rln2 = TranslationTimeline(relaxin);
  final Map<String, TranslationTimeline> all = <String, TranslationTimeline>{
    'insulin': ins,
    'p53, uncleaved': tp53,
    'relaxin 2, minus strand': rln2,
  };

  group('insulin', () {
    test(
      'reads 110 residues off an mRNA whose junctions are at 42 and 246',
      () {
        expect(ins.protein.length, 110);
        expect(ins.junctions, <int>[42, 246]);
        expect(ins.mrna.substring(ins.cdsStart, ins.cdsStart + 3), 'ATG');
        expect(
          GeneticCode.translate(
            ins.mrna.substring(ins.stopCodonStart, ins.stopCodonStart + 3),
          ),
          '*',
        );
        expect(ins.protein, insulin.protein!.translation);
      },
    );

    test('has 3 beats of scanning, 1 of joining, 1 a codon and 3 to end', () {
      expect(ins.beats, 3 + 1 + (110 - 1) + 3);
      expect(ins.phases.first.captionKey, 'scanning');
      expect(ins.phaseAt(ins.beatStart(3))!.captionKey, 'joining');
      expect(
        ins.phaseAt(ins.beatStart(ins.beats - 3))!.captionKey,
        'releaseFactor',
      );
    });

    test('clips its initiator methionine: residue 2 is alanine', () {
      expect(ins.protein[1], 'A');
      expect(ins.initiatorMetClipped, isTrue);
    });

    test('opens the SRP window once all 24 signal residues are out', () {
      expect(ins.signalPeptideLength, 24);
      final (double opens, double closes) = ins.srpWindow!;
      // Residue 24 clears a 35-residue tunnel as the 59th residue joins: at
      // the end of codon 59's peptide bond.
      expect(
        opens,
        closeTo(
          ins.beatStart(ins.beatOfCodon(24 + 35) + TranslationTimeline.bondEnd),
          1e-12,
        ),
      );
      expect(closes, ins.beatStart(ins.firstTerminationBeat));
      expect(ins.stateAt(opens).inTunnel(23), isFalse);
      expect(ins.stateAt(opens - 1e-6).inTunnel(23), isTrue);
    });

    test('knocks off an exon junction complex at each junction it passes', () {
      expect(
        ins.ejcKnockoff.map((({int junction, double t}) e) => e.junction),
        <int>[42, 246],
      );
      final double first = ins.ejcKnockoff[0].t;
      final double second = ins.ejcKnockoff[1].t;
      // 42 is in the 5′ UTR, passed while scanning; 246 is in the coding
      // sequence, passed as codon 64 translocates.
      expect(first, lessThan(ins.beatStart(TranslationTimeline.scanBeats)));
      expect(ins.stateAt(second).ribosome, greaterThanOrEqualTo(246));
      expect(ins.stateAt(second - 1e-9).ribosome, lessThan(246));
      expect(ins.stateAt(second).codon, 64);
      expect(ins.stateAt(second).phase, TranslationPhase.translocation);
    });

    test('puts the last decay codon at 44, where the edit engine does', () {
      expect(ins.nmdThresholdCodon, 44);
      final AnatomyStage mrna = AnatomyModel.derive(insulin).stages
          .firstWhere((AnatomyStage s) => s.kind == StageKind.mrna);
      // Every codon one substitution can turn into a stop: the engine calls
      // that stop degraded exactly when the timeline's threshold says so.
      int checked = 0;
      for (int codon = 2; codon <= ins.protein.length; codon++) {
        final int first = ins.cdsStart + 3 * (codon - 1);
        for (int i = 0; i < 3; i++) {
          for (final String base in <String>['A', 'C', 'G', 'T']) {
            final String edited =
                ins.mrna.substring(first, first + i) +
                base +
                ins.mrna.substring(first + i + 1, first + 3);
            if (base == ins.mrna[first + i] ||
                GeneticCode.translate(edited) != '*') {
              continue;
            }
            final EditOutcomeKind kind = classify(
              insulin,
              Substitution(mrna.positions[first + i], base),
            ).kind;
            expect(
              kind == EditOutcomeKind.mrnaDegraded,
              codon <= ins.nmdThresholdCodon!,
              reason: 'a stop at codon $codon',
            );
            checked++;
          }
        }
      }
      expect(checked, greaterThan(10));
    });
  });

  group('an uncleaved protein: p53', () {
    test('has no signal peptide, so no SRP window', () {
      expect(p53.signalPeptide, isNull);
      expect(tp53.signalPeptideLength, 0);
      expect(tp53.srpWindow, isNull);
    });

    test('keeps its methionine: residue 2 is glutamate', () {
      expect(tp53.protein[1], 'E');
      expect(tp53.initiatorMetClipped, isFalse);
    });

    test('passes the junctions inside its coding sequence, and no others', () {
      final int lastP = tp53.cdsStart + 3 * (tp53.protein.length - 1);
      expect(
        tp53.ejcKnockoff.map((({int junction, double t}) e) => e.junction),
        tp53.junctions.where((int j) => j <= lastP),
      );
    });
  });

  group('a minus-strand record: relaxin 2', () {
    test('reads its mRNA 5′ to 3′ off the reverse-complemented record', () {
      expect(relaxin.strand, -1);
      expect(rln2.mrna.substring(rln2.cdsStart, rln2.cdsStart + 3), 'ATG');
      expect(
        GeneticCode.translate(
          rln2.mrna.substring(rln2.stopCodonStart, rln2.stopCodonStart + 3),
        ),
        '*',
      );
      expect(rln2.junctions, <int>[347]);
      expect(rln2.protein, relaxin.protein!.translation);
    });

    test('derives its events from its own record', () {
      expect(rln2.initiatorMetClipped, rln2.protein[1] == 'P');
      expect(
        rln2.signalPeptideLength,
        relaxin.signalPeptide!.translation.length,
      );
      expect(rln2.srpWindow, isNotNull);
      final int limit = 347 - nmdThresholdBp - 1 - rln2.cdsStart;
      expect(rln2.nmdThresholdCodon, limit ~/ 3 + 1);
    });
  });

  group('what holds for every record', () {
    all.forEach((String name, TranslationTimeline timeline) {
      group(name, () {
        final List<double> ts = _samples(timeline);

        test('is deterministic', () {
          for (final double t in ts) {
            expect(timeline.stateAt(t), timeline.stateAt(t));
          }
        });

        test('never loses a residue', () {
          int last = 0;
          for (final double t in ts) {
            final int now = timeline.stateAt(t).residues;
            expect(now, greaterThanOrEqualTo(last), reason: 't $t');
            last = now;
          }
          expect(last, timeline.protein.length);
        });

        test('never holds more than 35 residues in the tunnel', () {
          for (final double t in ts) {
            final TranslationState s = timeline.stateAt(t);
            int inside = 0;
            for (int r = 0; r < s.residues; r++) {
              if (s.inTunnel(r)) {
                inside++;
              }
            }
            expect(inside, lessThanOrEqualTo(35), reason: 't $t');
            expect(s.inTunnelCount, inside, reason: 't $t');
          }
        });

        test(
          'lets the N terminus out first, and every residue out by the end',
          () {
            for (final double t in ts) {
              final TranslationState s = timeline.stateAt(t);
              for (int r = 1; r < s.residues; r++) {
                if (!s.inTunnel(r)) {
                  expect(
                    s.inTunnel(r - 1),
                    isFalse,
                    reason: 't $t, residue $r',
                  );
                }
              }
            }
            expect(timeline.stateAt(1).inTunnelCount, 0);
          },
        );

        test('only ever moves the ribosome 3′', () {
          double last = -1;
          for (final double t in ts) {
            final double at = timeline.stateAt(t).ribosome;
            expect(at, greaterThanOrEqualTo(last));
            last = at;
          }
        });

        test('partitions every beat exactly into its phase slices', () {
          final List<PhaseMark> marks = timeline.phases;
          // One mark per scanning, joining and termination beat, where it
          // applies, and four per codon, at exactly these fractions.
          const List<double> slices = <double>[
            0,
            TranslationTimeline.decodingEnd,
            TranslationTimeline.bondEnd,
            TranslationTimeline.translocationEnd,
          ];
          expect(
            marks.length,
            2 +
                4 * timeline.elongationBeats +
                TranslationTimeline.terminationBeats,
          );
          for (int codon = 2; codon <= timeline.protein.length; codon++) {
            final int beat = timeline.beatOfCodon(codon);
            final int first = 2 + 4 * (codon - 2);
            for (int i = 0; i < 4; i++) {
              expect(
                marks[first + i].t,
                closeTo(timeline.beatStart(beat + slices[i]), 1e-15),
              );
              // Named by the codon's number alone, at every slice.
              expect(marks[first + i].name, 'Codon ${grouped(codon)}');
            }
            // The four slices cover the beat and nothing else: the next mark
            // is the next beat's start.
            expect(
              marks[first + 4].t,
              closeTo(timeline.beatStart(beat + 1), 1e-15),
            );
          }
          // Inside a codon beat, each state belongs to exactly one slice.
          for (final double u in <double>[
            0,
            0.2,
            0.35,
            0.5,
            0.55,
            0.7,
            0.85,
            0.99,
          ]) {
            final TranslationState s = timeline.stateAt(
              timeline.beatStart(timeline.beatOfCodon(2) + u),
            );
            final TranslationPhase expected = u < 0.35
                ? TranslationPhase.decoding
                : u < 0.55
                ? TranslationPhase.peptideBond
                : u < 0.85
                ? TranslationPhase.translocation
                : TranslationPhase.trnaExit;
            expect(s.phase, expected, reason: 'u $u');
          }
          // Marks are strictly in order.
          for (int i = 1; i < marks.length; i++) {
            expect(marks[i].t, greaterThan(marks[i - 1].t));
          }
        });

        test('never names the protein it translates', () {
          for (final PhaseMark mark in timeline.phases) {
            expect(
              mark.name.toLowerCase(),
              isNot(contains(name.split(',').first)),
            );
          }
        });
      });
    });
  });

  test('refuses a record with nothing to translate', () {
    final GeneRecord bare = _gene('ins');
    final GeneRecord noncoding = GeneRecord(
      gene: bare.gene,
      start: bare.start,
      end: bare.end,
      strand: bare.strand,
      sequence: bare.sequence,
      transcript: bare.transcript,
      protein: null,
      exons: bare.exons,
      signalPeptide: null,
      proprotein: null,
      peptides: const <Peptide>[],
    );
    expect(() => TranslationTimeline(noncoding), throwsArgumentError);
  });
}
