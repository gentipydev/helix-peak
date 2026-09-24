import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_tracer.dart';

import 'anatomy_fixture.dart';

void main() {
  final AnatomyModel model = AnatomyModel.derive(insulin());

  List<String> linesFor(int position) => <String>[
    for (int i = 0; i < model.stages.length; i++)
      TracerReader.resolve(
        model: model,
        tracer: Tracer(position),
        stageIndex: i,
      ).line,
  ];

  group('the common path — most taps lose', () {
    test('a base in intron 2 is cut at splicing, and named', () {
      final TracerStatus status = TracerReader.resolve(
        model: model,
        tracer: const Tracer(6000),
        stageIndex: 1,
      );
      expect(status.alive, isFalse);
      expect(status.line, 'removed with intron 2 · 787 bp');
      expect(status.fate?.kind, RoleKind.intron);
      expect(TracerReader.cutAt(model, const Tracer(6000)), 1);
    });

    test('it stays visible and inert for every stage after', () {
      final TracerStatus atGene = TracerReader.resolve(
        model: model,
        tracer: const Tracer(6000),
        stageIndex: 0,
      );
      for (int i = 1; i < model.stages.length; i++) {
        final TracerStatus status = TracerReader.resolve(
          model: model,
          tracer: const Tracer(6000),
          stageIndex: i,
        );
        expect(status.alive, isFalse);
        // Anchored where it left the story, not dropped.
        expect(status.anchorStage, 0);
        expect(status.anchorCell, atGene.cell);
        expect(status.line, 'removed with intron 2 · 787 bp');
      }
    });

    test('names each other way of losing', () {
      // The untranslated ends now leave at translation, with the stop codon,
      // rather than on a page of their own.
      expect(TracerReader.cutAt(model, const Tracer(4986)), 2);
      expect(
        linesFor(4986)[2],
        'removed with the 5′ UTR · 59 bp',
      );
      expect(linesFor(6416)[2], 'removed with the 3′ UTR · 73 bp');

      // The stop codon is spent, not discarded.
      expect(linesFor(6341)[2], 'read as the stop codon · 3 bp');

      // The signal peptide and the dibasic sites go together now, on the one
      // swipe off the precursor.
      expect(TracerReader.cutAt(model, const Tracer(5224)), 3);
      expect(
        linesFor(5224)[3],
        'removed with the signal peptide · 72 bp',
      );

      expect(TracerReader.cutAt(model, const Tracer(5386)), 3);
      expect(linesFor(5386)[3], 'consumed as the RR site · 6 bp');
      expect(linesFor(6272)[3], 'consumed as the KR site · 6 bp');
    });
  });

  group('the rare path — a base that survives', () {
    test('base 5,301 reaches the mature B chain', () {
      expect(TracerReader.cutAt(model, const Tracer(5301)), -1);
      expect(linesFor(5301), <String>[
        // A base of the gene by its coding-DNA position.
        'c.78 · G · exon 2',
        // On the transcript a base answers for its codon.
        'c.76–78 · GTG · Val26',
        // 26 on the precursor, and still 26 on the mature chains, where the
        // chain's own count follows: the precursor's blocks are named stretches
        // of one unbroken chain, the mature blocks three chains a protease has
        // already separated.
        'Val26 · insulin B chain',
        'Val26 · B chain residue 2',
      ]);
    });

    test('the residue numbering matches what is on screen', () {
      final AnatomyStage mature = model.stages.last;
      final TracerStatus status = TracerReader.resolve(
        model: model,
        tracer: const Tracer(5301),
        stageIndex: model.stages.length - 1,
      );
      final StageBlock block = mature.blocks[mature.blockOf(status.cell)];
      expect(block.label, 'insulin B chain');
      expect(status.cell - block.start + 1, 2);
      expect(mature.letters[status.cell], 'V');
    });

    test('a cysteine that anchors a disulfide bond is followable too', () {
      // B7 — the record does not annotate the bond, but the residue is real.
      final TracerStatus status = TracerReader.resolve(
        model: model,
        tracer: const Tracer(5314),
        stageIndex: model.stages.length - 1,
      );
      expect(status.alive, isTrue);
      expect(status.line, 'Cys31 · B chain residue 7');
    });
  });

  group('codon siblings', () {
    // They now light on the transcript page — the same page that draws the
    // reading frame as a gap after every third base. Tapping a base there
    // lights the two it will be read with, on the page where you can see why.
    test('are marked in the stage before translation', () {
      final TracerStatus status = TracerReader.resolve(
        model: model,
        tracer: const Tracer(5301),
        stageIndex: 1,
      );
      final AnatomyStage mrna = model.stages[1];
      expect(
        status.siblings.map(mrna.positionAt).toList()..sort(),
        <int>[5299, 5300],
      );
    });

    test('follow the codon that straddles the intron', () {
      // Codon 63 is 5410, 6198, 6199 — its siblings are not its neighbours.
      final TracerStatus status = TracerReader.resolve(
        model: model,
        tracer: const Tracer(5410),
        stageIndex: 1,
      );
      final AnatomyStage mrna = model.stages[1];
      expect(
        status.siblings.map(mrna.positionAt).toList()..sort(),
        <int>[6198, 6199],
      );
    });

    test('are absent when the next stage is not a translation', () {
      for (final int stage in <int>[0, 2, 3]) {
        expect(
          TracerReader.resolve(
            model: model,
            tracer: const Tracer(5301),
            stageIndex: stage,
          ).siblings,
          isEmpty,
          reason: 'stage $stage',
        );
      }
    });
  });

  group('running backwards', () {
    test('a mature residue splits into three bases at the right places', () {
      final AnatomyStage mature = model.stages.last;
      final AnatomyStage gene = model.stages.first;

      // Tap residue 2 of the B chain in the final stage...
      final int cell = mature.blocks.first.start + 1;
      final int tapped = mature.positionAt(cell);
      expect(tapped, 5299);

      // ...and every position of that residue is a real base of the gene.
      final List<int> positions = <int>[
        for (int k = 0; k < mature.positionsPerCell; k++)
          mature.positionAt(cell, k),
      ];
      expect(positions, <int>[5299, 5300, 5301]);
      for (final int position in positions) {
        expect(gene.cellAt(position), isNot(-1));
      }

      // GTG, and the record translated it V. The frame checks out against the
      // genetic code without this file knowing the genetic code.
      expect(
        positions.map(model.baseAt).join(),
        'GTG',
      );
      expect(mature.letters[cell], 'V');
      expect(
        TracerReader.resolve(
          model: model,
          tracer: Tracer(tapped),
          stageIndex: 0,
        ).line,
        'c.76 · G · exon 2',
      );
    });
  });

  group('the note under the line', () {
    TracerStatus select(int position, {bool asRun = true, int stage = 0}) =>
        TracerReader.resolve(
          model: model,
          tracer: Tracer(position, asRun: asRun),
          stageIndex: stage,
        );

    test('states a fact about what was tapped', () {
      final TracerStatus utr = select(4986);
      expect(utr.line, startsWith('the 5′ UTR'));
      expect(utr.note, 'Kozak TCTGCC ATG G');

      final TracerStatus intron = select(6000);
      expect(intron.note, 'GT…AG · phase 1');

      expect(select(5224).note, 'precursor 1–24 · cleaved after Ala24');
      expect(select(5301).note, 'precursor 25–54');
      expect(select(5386).note, 'precursor 55–56');
      expect(select(6341).note, 'c.331–333 · TAG · stop');
    });

    test('both halves of a split feature give the same note', () {
      // 4,986 is the 42 bases in exon 1; 5,207 the 17 in exon 2.
      expect(select(5207).line, startsWith('the 5′ UTR'));
      expect(select(5207).note, select(4986).note);
    });

    test('a cut base is told what the thing that took it was', () {
      final TracerStatus cut = select(6000, asRun: false, stage: 1);
      expect(cut.alive, isFalse);
      expect(cut.line, 'removed with intron 2 · 787 bp');
    });

    test('a codon on the transcript names its exon, and says where one splits', () {
      // Codon 63 is 5410, 6198, 6199: two bases in exon 3, one in exon 2.
      final TracerStatus split = select(5410, asRun: false, stage: 1);
      expect(split.line, 'c.187–189 · GTG · Val63');
      expect(split.note, 'exons 2–3 · split codon');
      expect(select(5301, asRun: false, stage: 1).note, 'exon 2');
      expect(
        select(5224, asRun: false, stage: 1).line,
        'c.1–3 · ATG · Met1 · start codon',
      );
    });
  });
}
