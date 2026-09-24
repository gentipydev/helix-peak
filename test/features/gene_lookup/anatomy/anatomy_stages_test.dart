import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import 'anatomy_fixture.dart';

List<int> _positionsOf(AnatomyStage stage, int cell) => <int>[
  for (int k = 0; k < stage.positionsPerCell; k++) stage.positionAt(cell, k),
];

void main() {
  final GeneRecord record = insulin();
  final AnatomyModel model = AnatomyModel.derive(record);

  group('stage list', () {
    test('INS derives four stages, in order', () {
      // Four, not five. The proprotein was a second copy of the precursor
      // twenty-four residues shorter, and neither page showed the subtraction;
      // it is a named block of the precursor now, and the swipe to the mature
      // peptides is where the reader watches it go.
      expect(
        model.stages.map((AnatomyStage s) => s.kind).toList(),
        <StageKind>[
          StageKind.gene,
          StageKind.mrna,
          StageKind.protein,
          StageKind.maturePeptides,
        ],
      );
    });

    test('the counts read 1,431 -> 465 -> 110 -> 82', () {
      expect(
        model.stages.map((AnatomyStage s) => s.count).toList(),
        <int>[1431, 465, 110, 82],
      );
    });

    test('names each stage from the record, not from a constant', () {
      expect(model.stages[2].label, 'insulin preproprotein');
      expect(model.stages[3].label, 'mature peptides');
      expect(
        model.stages[3].blocks.map((StageBlock b) => b.label).toList(),
        <String>['insulin B chain', 'C-peptide', 'insulin A chain'],
      );
    });

    test('draws the precursor as the leader and what survives it', () {
      final AnatomyStage protein = model.stages[2];
      expect(
        protein.blocks.map((StageBlock b) => b.label).toList(),
        <String>['signal peptide', 'proinsulin'],
      );
      expect(
        protein.blocks.map((StageBlock b) => b.count).toList(),
        <int>[24, 86],
      );
      // The leader is named and quiet; what survives it is the subject of the
      // page and is the one the band draws at full strength.
      expect(protein.blocks.first.role, RoleKind.signalPeptide);
      expect(protein.blocks.first.prominent, isFalse);
      expect(protein.blocks.last.prominent, isTrue);
    });

    test('writes one derived caption of figures per stage', () {
      expect(model.stages[0].sentence, '3 exons · 2 introns');
      expect(
        model.stages[1].sentence,
        '5\u2032 UTR 59 · CDS 333 · 3\u2032 UTR 73 nt',
      );
      // The precursor's pieces and their spans, in precursor numbering.
      expect(
        model.stages[2].sentence,
        'signal peptide 1–24 · proinsulin 25–110',
      );
      expect(
        model.stages[3].sentence,
        'B chain (30) · C-peptide (31) · A chain (21) · cut at RR, KR',
      );
      expect(
        <String>[for (final AnatomyStage s in model.stages) s.shortUnit],
        <String>['bp', 'nt', 'aa', 'aa'],
      );
    });

    test('a single-exon coding gene still gets its transcript page', () {
      // There is no splicing to show, but there is still a reading frame — and
      // the frame is the reason that page exists now that it carries the CDS.
      final AnatomyModel other = AnatomyModel.derive(
        insulinWithout(introns: true),
      );
      expect(other.stages.first.sentence, '1 exon');
      expect(other.stages[1].kind, StageKind.mrna);
      expect(
        other.stages[1].blocks.where((StageBlock b) => b.framed).length,
        1,
      );
      // Nothing was spliced, so the sentence may not say anything was.
      expect(other.stages[1].sentence, isNot(contains('intron')));
    });

    test('a single-exon non-coding gene has no transcript page at all', () {
      final AnatomyModel other = AnatomyModel.derive(
        insulinWithout(introns: true, cds: true),
      );
      expect(
        other.stages.map((AnatomyStage s) => s.kind),
        isNot(contains(StageKind.mrna)),
      );
    });

    test('a non-coding gene stops after the mRNA, and frames nothing', () {
      final AnatomyModel other = AnatomyModel.derive(insulinWithout(cds: true));
      expect(
        other.stages.map((AnatomyStage s) => s.kind).toList(),
        <StageKind>[StageKind.gene, StageKind.mrna],
      );
      expect(other.stages[1].blocks, hasLength(1));
      expect(other.stages[1].blocks.single.framed, isFalse);
      expect(other.stages[1].sentence, '3 exons joined · 465 nt');
    });

    test('a gene with no proprotein is still split at its signal peptide', () {
      final AnatomyModel other = AnatomyModel.derive(
        insulinWithout(proprotein: true),
      );
      expect(
        other.stages.map((AnatomyStage s) => s.kind),
        isNot(contains(StageKind.proprotein)),
      );
      expect(other.stages.last.kind, StageKind.maturePeptides);
      // What the signal peptide leaves is the proprotein whether or not the
      // record names it. Three chains are still to be cut from it, so it takes
      // the generic name rather than any one of theirs.
      expect(
        other.stages[2].blocks.map((StageBlock b) => b.label).toList(),
        <String>['signal peptide', 'proprotein'],
      );
      expect(
        other.stages[2].blocks.map((StageBlock b) => b.count).toList(),
        <int>[24, 86],
      );
      expect(
        other.stages[2].sentence,
        'signal peptide 1–24 · proprotein 25–110',
      );
    });

    test('a gene with no mat_peptide stops at the precursor', () {
      final AnatomyModel other = AnatomyModel.derive(
        insulinWithout(maturePeptides: true),
      );
      expect(other.stages.length, 3);
      expect(other.stages.last.kind, StageKind.protein);
      // Still drawn as its two pieces. The page after it is what is missing,
      // not the cut it is naming.
      expect(
        other.stages.last.blocks.map((StageBlock b) => b.label).toList(),
        <String>['signal peptide', 'proinsulin'],
      );
    });

    test('a leader with no chain behind it leaves a chain of its own size', () {
      // Glucagon's and APP's records name overlapping products rather than
      // pieces, so their walks stop at the precursor with a signal peptide and
      // no chain. What the leader leaves is named as the coding sequence, and
      // it used to be sized with the leader's bases in it: a tap said more
      // bases than it lit.
      final AnatomyModel other = AnatomyModel.derive(
        insulinWithout(maturePeptides: true, proprotein: true),
        chain: 'proinsulin',
      );
      final Role? leader = other.codingRoleAt(5224);
      final Role? kept = other.codingRoleAt(5296);
      expect(leader?.kind, RoleKind.signalPeptide);
      expect(leader?.lengthBp, 72);
      expect(kept?.label, 'proinsulin');
      expect(kept?.lengthBp, 86 * 3);
    });

    test('a cut at a lone basic residue is not called dibasic', () {
      // Vasopressin's copeptin is cut off at a single arginine. Insulin's B
      // chain run one residue on turns the `RR` after it into that shape.
      final Map<String, dynamic> json = insulinJson();
      final Map<String, dynamic> chainB = (json['peptides']! as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (Map<String, dynamic> p) => p['product'] == 'insulin B chain',
          );
      ((chainB['segments']! as List<dynamic>).single
              as Map<String, dynamic>)['end'] =
          5388;
      chainB['translation'] = '${chainB['translation']}R';
      final AnatomyModel other = AnatomyModel.derive(
        GeneRecordDto.fromJson(json).toEntity(),
      );
      expect(other.codingRoleAt(5389)?.label, 'R site');
      expect(
        other.stages.last.sentence,
        'B chain (31) · C-peptide (31) · A chain (21) · cut at R, KR',
      );
      expect(other.stages.last.sentence, isNot(contains('dibasic')));
    });

    test('a proprotein that is not one run keeps its own stage', () {
      final AnatomyModel other = AnatomyModel.derive(
        insulinWithout(splitProprotein: true),
      );
      expect(
        other.stages.map((AnatomyStage s) => s.kind),
        contains(StageKind.proprotein),
      );
      // The precursor goes back to one unnamed block and one sentence, and the
      // subtraction goes back to being asserted between two pages.
      expect(other.stages[2].blocks, hasLength(1));
      expect(other.stages[2].sentence, 'insulin preproprotein');
    });
  });

  group('the transcript, as three regions', () {
    final AnatomyStage mrna = model.stages[1];

    test('465 bases split 59 / 333 / 73, in transcript order', () {
      expect(mrna.count, 465);
      expect(
        mrna.blocks.map((StageBlock b) => b.count).toList(),
        <int>[59, 333, 73],
      );
      expect(
        mrna.blocks.map((StageBlock b) => b.start).toList(),
        <int>[0, 59, 392],
      );
      expect(
        mrna.blocks.map((StageBlock b) => b.label).toList(),
        <String>['5\u2032 UTR', 'coding sequence', '3\u2032 UTR'],
      );
      // Every chip carries its size; the name the tracer reads back does not.
      expect(
        mrna.blocks.map((StageBlock b) => b.caption).toList(),
        <String?>[
          '5\u2032 UTR \u00b7 59 nt',
          'CDS \u00b7 333 nt',
          '3\u2032 UTR \u00b7 73 nt',
        ],
      );
    });

    test('only the coding sequence is read in threes', () {
      expect(
        mrna.blocks.map((StageBlock b) => b.framed).toList(),
        <bool>[false, true, false],
      );
      expect(mrna.blocks[1].count % 3, 0);
    });

    test('each region carries the role its name band is coloured by', () {
      expect(
        mrna.blocks.map((StageBlock b) => b.role).toList(),
        <RoleKind>[RoleKind.utr5, RoleKind.coding, RoleKind.utr3],
      );
    });

    test('the blocks tile the transcript exactly, with no base in two', () {
      int next = 0;
      for (final StageBlock block in mrna.blocks) {
        expect(block.start, next);
        next += block.count;
      }
      expect(next, mrna.count);
    });

    test('every cell of the middle block is a coding base, and only those', () {
      for (int cell = 0; cell < mrna.count; cell++) {
        final bool framed = mrna.blocks[mrna.blockOf(cell)].framed;
        final RoleKind? kind = model.codingRoleAt(mrna.positionAt(cell))?.kind;
        final bool untranslated =
            kind == RoleKind.utr5 || kind == RoleKind.utr3;
        expect(framed, !untranslated, reason: 'cell $cell');
      }
    });
  });

  group('the reading frame', () {
    final AnatomyStage mrna = model.stages[1];
    final AnatomyStage protein = model.stages[2];

    test('333 bases give 110 residues; the stop codon merges into nothing', () {
      expect(mrna.blocks[1].count, 333);
      expect(protein.count, 110);
      expect(mrna.blocks[1].count ~/ 3, 111);
    });

    test('the stop codon is TAG at 6341..6343 and is absent from the protein', () {
      final List<int> stop = <int>[6341, 6342, 6343];
      expect(
        stop.map(model.baseAt).join(),
        'TAG',
      );
      for (final int position in stop) {
        expect(mrna.cellAt(position), isNot(-1));
        expect(protein.cellAt(position), -1);
      }
      expect(model.codingRoleAt(6341)?.kind, RoleKind.stopCodon);
    });

    test('codon 63 spans the intron, and is the only one that does', () {
      final List<int> straddling = <int>[
        for (int cell = 0; cell < protein.count; cell++)
          if (protein.positionAt(cell, 2) - protein.positionAt(cell, 0) != 2)
            cell + 1,
      ];
      expect(straddling, <int>[63]);
      expect(_positionsOf(protein, 62), <int>[5410, 6198, 6199]);
    });

    test('every residue reads the letter the record translated', () {
      expect(protein.letters, record.protein!.translation);
      // The proprotein is a slice of the precursor now rather than a page of
      // its own, so the record's own translation of it has to be exactly the
      // letters under its name band.
      final StageBlock proinsulin = protein.blocks.last;
      expect(
        protein.letters.substring(
          proinsulin.start,
          proinsulin.start + proinsulin.count,
        ),
        record.proprotein!.translation,
      );
      expect(
        model.stages[3].letters,
        record.peptides.map((Peptide p) => p.translation).join(),
      );
    });
  });

  group('roles', () {
    test('derives the dibasic sites without being told they exist', () {
      expect(model.codingRoleAt(5386)?.label, 'RR site');
      expect(model.codingRoleAt(5391)?.label, 'RR site');
      expect(model.codingRoleAt(5385)?.label, 'insulin B chain');
      expect(model.codingRoleAt(5392)?.label, 'C-peptide');

      expect(model.codingRoleAt(6272)?.label, 'KR site');
      expect(model.codingRoleAt(6277)?.label, 'KR site');
      expect(model.codingRoleAt(6278)?.label, 'insulin A chain');

      expect(
        <int>[5386, 5387, 5388, 5389, 5390, 5391]
            .map(model.baseAt)
            .join(),
        'CGCCGG',
      );
      expect(
        <int>[6272, 6273, 6274, 6275, 6276, 6277]
            .map(model.baseAt)
            .join(),
        'AAGCGT',
      );
    });

    test('names the exon a base sits in, honouring the /number qualifier', () {
      expect(model.transcriptRoleAt(4986)?.label, 'exon 1');
      expect(model.transcriptRoleAt(5301)?.label, 'exon 2');
      expect(model.transcriptRoleAt(6416)?.label, 'exon 3');
    });

    test('carries each intron its own length, for the cut message', () {
      expect(model.transcriptRoleAt(5028)?.label, 'intron 1');
      expect(model.transcriptRoleAt(5028)?.lengthBp, 179);
      expect(model.transcriptRoleAt(6000)?.label, 'intron 2');
      expect(model.transcriptRoleAt(6000)?.lengthBp, 787);
    });

    test('the fate census accounts for all 1,431 bases', () {
      final Map<RoleKind, int> census = <RoleKind, int>{};
      for (int p = record.start; p <= record.end; p++) {
        final Role? coding = model.codingRoleAt(p);
        final RoleKind kind = coding?.kind ?? model.transcriptRoleAt(p)!.kind;
        census[kind] = (census[kind] ?? 0) + 1;
      }

      expect(census[RoleKind.intron], 966);
      expect((census[RoleKind.utr5] ?? 0) + (census[RoleKind.utr3] ?? 0), 132);
      expect(census[RoleKind.signalPeptide], 72);
      expect(census[RoleKind.stopCodon], 3);
      expect(census[RoleKind.dibasic], 12);
      expect(census[RoleKind.maturePeptide], 246);
      expect(
        census.values.reduce((int a, int b) => a + b),
        record.lengthBp,
      );
    });
  });

  group('containment', () {
    test('a base in intron 2 is gone from the mRNA onward', () {
      expect(model.stages[0].cellAt(6000), isNot(-1));
      for (int i = 1; i < model.stages.length; i++) {
        expect(model.stages[i].cellAt(6000), -1, reason: 'stage $i');
      }
    });

    test('a B chain base survives every stage', () {
      for (final AnatomyStage stage in model.stages) {
        expect(stage.cellAt(5301), isNot(-1), reason: stage.label);
      }
    });

    test('all three bases of a codon land in one residue cell', () {
      final AnatomyStage protein = model.stages[2];
      final int cell = protein.cellAt(5301);

      // 5,301 is the *third* base of its codon, not the middle one: it sits at
      // CDS offset 77, and 77 ~/ 3 is codon 25. Its siblings run backwards.
      expect(cell, 25);
      expect(protein.cellAt(5299), cell);
      expect(protein.cellAt(5300), cell);
      expect(protein.cellAt(5302), isNot(cell));
      expect(_positionsOf(protein, cell), <int>[5299, 5300, 5301]);

      // Residue 26 of the record's own translation, one-based.
      expect(protein.letters[cell], 'V');
      expect(record.protein!.translation[25], 'V');
    });

    test('a base of the transcript answers with the codon it is read in', () {
      final AnatomyStage mrna = model.stages[1];
      final StageBlock cds = mrna.blocks[1];
      expect(cds.framed, isTrue);

      // The three bases of codon 26 — CDS offsets 75, 76, 77 — all answer with
      // the same three cells, whichever of them is asked.
      final List<int> codon = <int>[
        cds.start + 75,
        cds.start + 76,
        cds.start + 77,
      ];
      for (final int cell in codon) {
        expect(mrna.codonCellsAt(cell), codon, reason: 'cell $cell');
      }
      expect(mrna.cellAt(5301), codon.last);

      // The frame's two ends are codons like any other, and answer with the
      // same three cells [frameCodon] gives them.
      expect(mrna.codonCellsAt(cds.start), mrna.frameCodon(CodonMark.start));
      expect(
        mrna.codonCellsAt(cds.start + cds.count - 1),
        mrna.frameCodon(CodonMark.stop),
      );

      // Nothing outside the frame is read in threes: not an untranslated base,
      // not a residue, and not a region opened into its DNA, which is a stretch
      // from anywhere in the frame and grooves itself.
      expect(mrna.codonCellsAt(0), isEmpty);
      expect(mrna.codonCellsAt(mrna.count - 1), isEmpty);
      expect(model.stages[2].codonCellsAt(25), isEmpty);
      expect(model.stages.first.codonCellsAt(0), isEmpty);
    });
  });

  group('the run table', () {
    final AnatomyModel model = AnatomyModel.derive(insulin());

    test('the gene is thirteen named pieces, in order', () {
      final List<StageRun> runs = model.stages[0].runs;
      expect(
        runs.map((StageRun r) => '${r.label} ${r.count}').toList(),
        <String>[
          'the 5′ UTR 42',
          'intron 1 179',
          'the 5′ UTR 17',
          'the signal peptide 72',
          'insulin B chain 90',
          'RR site 6',
          'C-peptide 19',
          'intron 2 787',
          'C-peptide 74',
          'KR site 6',
          'insulin A chain 63',
          'the stop codon 3',
          'the 3′ UTR 73',
        ],
      );
    });

    test('every cell belongs to exactly one run, at every stage', () {
      for (final AnatomyStage stage in model.stages) {
        int total = 0;
        for (int i = 0; i < stage.runs.length; i++) {
          expect(stage.runs[i].start, total, reason: '${stage.label} run $i');
          total += stage.runs[i].count;
        }
        expect(total, stage.count, reason: stage.label);
        for (int cell = 0; cell < stage.count; cell++) {
          final StageRun run = stage.runAt(cell);
          expect(cell, greaterThanOrEqualTo(run.start));
          expect(cell, lessThan(run.start + run.count));
        }
      }
    });

    test('the two introns are two runs, not one repeated', () {
      final List<StageRun> introns = model.stages[0].runs
          .where((StageRun r) => r.kind == RoleKind.intron)
          .toList();
      expect(introns.length, 2);
      expect(introns.first.label, 'intron 1');
      expect(introns.last.label, 'intron 2');
      // Grouping is by Role identity, so two features of one kind stay apart.
      expect(introns.first.lengthBp, isNot(introns.last.lengthBp));
    });

    test("a split feature reports the whole feature's length", () {
      // The 5' UTR arrives in two pieces either side of intron 1, and is 59
      // bases in both of them.
      final List<StageRun> utr = model.stages[0].runs
          .where((StageRun r) => r.label == 'the 5′ UTR')
          .toList();
      expect(utr.map((StageRun r) => r.count), <int>[42, 17]);
      expect(utr.every((StageRun r) => r.lengthBp == 59), isTrue);
    });

    test('the mature chains carry their ordinal, so they can differ', () {
      final List<StageRun> chains = model.stages[0].runs
          .where((StageRun r) => r.kind == RoleKind.maturePeptide)
          .toList();
      expect(
        chains.map((StageRun r) => r.index).toSet(),
        <int>{0, 1, 2},
        reason: 'B chain, C-peptide and A chain are three different colours',
      );
    });

    test('a run names itself as a label, shortest form last', () {
      Map<String, List<String>> formsOf(int stage) => <String, List<String>>{
        for (final StageRun r in model.stages[stage].runs)
          r.label: r.labelForms.toList(),
      };
      expect(formsOf(0), <String, List<String>>{
        // The article always goes: these are written on the thing they name.
        'the 5′ UTR': <String>['5′ UTR'],
        'the signal peptide': <String>['signal peptide'],
        'the stop codon': <String>['stop codon'],
        'the 3′ UTR': <String>['3′ UTR'],
        // The protein's own name may go, but only for room.
        'insulin B chain': <String>['insulin B chain', 'B chain'],
        'insulin A chain': <String>['insulin A chain', 'A chain'],
        // Nothing that would name the wrong thing, or nothing at all.
        'intron 1': <String>['intron 1'],
        'intron 2': <String>['intron 2'],
        'C-peptide': <String>['C-peptide'],
        'RR site': <String>['RR site'],
        'KR site': <String>['KR site'],
      });
    });

    test('a run written on itself may abbreviate its category word', () {
      // What [labelForms] is for a sentence, [writtenForms] is for the shape:
      // the same names, and then as much abbreviation as a narrow run needs.
      // Only the category word is ever cut — the ordinal, the chain's letter
      // and which end of the transcript it is are what tell two runs apart.
      Map<String, List<String>> writtenOf(int stage) =>
          <String, List<String>>{
            for (final StageRun r in model.stages[stage].runs)
              r.label: r.writtenForms.toList(),
          };
      expect(writtenOf(0), <String, List<String>>{
        'the 5′ UTR': <String>['5′ UTR', '5′UTR', '5′U'],
        'the signal peptide': <String>[
          'signal peptide',
          'sig. peptide',
          'SP',
        ],
        // Punctuation is written whole or not at all: three bases are read off
        // the colours either side of them.
        'the stop codon': <String>['stop codon'],
        'the 3′ UTR': <String>['3′ UTR', '3′UTR', '3′U'],
        // A chain's letter is its name, which is the one place a single
        // character names anything.
        'insulin B chain': <String>['insulin B chain', 'B chain', 'B'],
        'insulin A chain': <String>['insulin A chain', 'A chain', 'A'],
        'intron 1': <String>['intron 1', 'int. 1', 'I1'],
        'intron 2': <String>['intron 2', 'int. 2', 'I2'],
        'C-peptide': <String>['C-peptide', 'C-pep.'],
        'RR site': <String>['RR site'],
        'KR site': <String>['KR site'],
      });
    });

    test('every run of the gene has a name worth drawing', () {
      for (final StageRun run in model.stages[0].runs) {
        expect(run.labelForms, isNotEmpty, reason: run.label);
        for (final String form in run.labelForms) {
          expect(form.trim(), form);
          expect(
            form.length,
            greaterThan(2),
            reason: '"$form" is too short to name anything',
          );
        }
      }
    });

    test('a gene with no CDS still has runs, from the transcript alone', () {
      // One exon and nothing translated: the only thing left to say about a
      // base is whether it is in the transcript at all. That is the fallback
      // the INS record never exercises, because every one of its bases has a
      // more specific role.
      final AnatomyModel plain = AnatomyModel.derive(
        insulinWithout(introns: true, cds: true),
      );
      final List<StageRun> runs = plain.stages[0].runs;
      expect(
        runs.map((StageRun r) => r.kind).toList(),
        <RoleKind>[RoleKind.exon, RoleKind.untranscribed],
      );
      expect(runs.first.count, 42, reason: 'exon 1');
      expect(
        runs.first.count + runs.last.count,
        plain.stages[0].count,
        reason: 'the run table still covers the whole gene',
      );
    });
  });

  group('split features', () {
    final AnatomyStage gene = AnatomyModel.derive(insulin()).stages[0];

    test('the 5′ UTR is two runs of one feature', () {
      final List<StageRun> utr = gene.runs
          .where((StageRun r) => r.kind == RoleKind.utr5)
          .toList();

      expect(utr.length, 2, reason: 'intron 1 splits it');
      expect(utr.first.count, 42, reason: 'in exon 1');
      expect(utr.last.count, 17, reason: 'in exon 2');

      // The two pieces are one thing, and both report the whole thing's size —
      // which is what the caption prints, so both have to light when either is
      // tapped.
      expect(utr.first.feature, utr.last.feature);
      expect(utr.map((StageRun r) => r.lengthBp).toList(), <int>[59, 59]);
      expect(utr.first.count + utr.last.count, 59);
    });

    test('a tap on either half selects the same feature', () {
      final int inExon1 = gene.cellAt(4986);
      final int inExon2 = gene.cellAt(5207);

      expect(gene.runOfCell[inExon1], isNot(gene.runOfCell[inExon2]));
      expect(gene.featureAt(inExon1), gene.featureAt(inExon2));
    });

    test('features that merely share a kind stay apart', () {
      // Two introns are two features, or selecting one would light both.
      final int intron1 = gene.featureAt(gene.cellAt(5100));
      final int intron2 = gene.featureAt(gene.cellAt(6000));

      expect(gene.runAt(gene.cellAt(5100)).kind, RoleKind.intron);
      expect(gene.runAt(gene.cellAt(6000)).kind, RoleKind.intron);
      expect(intron1, isNot(intron2));
    });

    test('every run belongs to exactly one feature, ids left dense', () {
      final Set<int> ids = gene.runs.map((StageRun r) => r.feature).toSet();
      expect(ids.length, lessThan(gene.runs.length), reason: 'the split one');
      expect(ids.reduce((int a, int b) => a > b ? a : b), ids.length - 1);
    });
  });
}
