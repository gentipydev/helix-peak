import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_catalog.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_constraint.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_layout.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_ruler.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_selection.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_tracer.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

GeneRecord _record(ProteinTarget target) =>
    GeneRecordDto.fromJson(_json(target.mockAsset)).toEntity();

/// Every protein in the catalog, checked against its own three baked assets.
///
/// These are the tests that make twenty proteins cheaper than one was. The walk
/// is derived — from the record's exons, its peptides, its reading frame — so
/// nothing about it can be verified by reading the code, only by deriving it.
/// A bake that produced a record the derivation cannot walk, a constraint track
/// a residue longer than the protein it describes, or a model the build hook
/// never saw, all fail here rather than as a blank page on a phone.
/// The paths `flutter: assets:` actually lists, and not the comments among
/// them. The list is contiguous, so it ends at the first line that is neither
/// an entry nor a comment.
Set<String> _bundledPaths() {
  final List<String> lines = File('pubspec.yaml').readAsLinesSync();
  final int assets = lines.indexWhere((String line) => line.trim() == 'assets:');
  expect(assets, isNot(-1), reason: 'pubspec.yaml has no assets list');
  final RegExp entry = RegExp(r'^    - (.+)$');
  final Set<String> found = <String>{};
  for (final String line in lines.skip(assets + 1)) {
    if (line.trim().startsWith('#')) {
      continue;
    }
    final RegExpMatch? match = entry.firstMatch(line);
    if (match == null) {
      break;
    }
    found.add(match.group(1)!);
  }
  return found;
}

void main() {
  test('slugs, genes and asset paths are unique', () {
    expect(
      ProteinCatalog.all.map((ProteinTarget t) => t.slug).toSet().length,
      ProteinCatalog.all.length,
    );
    expect(
      ProteinCatalog.all.map((ProteinTarget t) => t.gene).toSet().length,
      ProteinCatalog.all.length,
    );
    expect(ProteinCatalog.all, contains(ProteinCatalog.fallback));
  });

  test('every path the fixture server can be asked for resolves', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      expect(
        ProteinCatalog.byPath(target.accession, target.gene),
        target,
        reason: 'GET /gene/${target.accession}/${target.gene}',
      );
      expect(ProteinCatalog.bySlug(target.slug), target);
    }
    expect(ProteinCatalog.byPath('NG_007114', 'INS-IGF2'), isNull);
    expect(ProteinCatalog.bySlug('haemoglobin'), isNull);
  });

  test('search finds every protein by name and by gene symbol', () {
    expect(ProteinCatalog.matching(''), ProteinCatalog.all);
    expect(ProteinCatalog.matching('   '), ProteinCatalog.all);
    for (final ProteinTarget target in ProteinCatalog.all) {
      expect(ProteinCatalog.matching(target.gene), contains(target));
      expect(ProteinCatalog.matching(target.gene.toLowerCase()), contains(target));
      expect(ProteinCatalog.matching(target.display), contains(target));
    }
    expect(ProteinCatalog.matching('TP53'), <ProteinTarget>[ProteinCatalog.p53]);
    expect(ProteinCatalog.matching('titin'), isEmpty);
  });

  test('search leads with what a query names, not with what mentions it', () {
    // A name the query begins a word of, ahead of a summary that happens to
    // say it — in catalog order, insulin's summary came first.
    expect(
      ProteinCatalog.matching('hormone'),
      <ProteinTarget>[ProteinCatalog.somatotropin, ProteinCatalog.insulin],
    );
    expect(ProteinCatalog.matching('protein'), <ProteinTarget>[
      ProteinCatalog.app,
      ProteinCatalog.prion,
      ProteinCatalog.myoglobin,
    ]);
    expect(ProteinCatalog.matching('precursor').first, ProteinCatalog.app);
    // Among the summaries alone, the catalog's order stands.
    expect(ProteinCatalog.matching('precursor').skip(1), <ProteinTarget>[
      ProteinCatalog.oxytocin,
      ProteinCatalog.vasopressin,
      ProteinCatalog.glucagon,
    ]);
  });

  group('assets', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      test('${target.slug} ships the files it names', () {
        expect(File(target.mockAsset).existsSync(), isTrue, reason: target.mockAsset);
        // A track exactly where the row says the protein is scored. An unscored
        // protein is drawn without one, and a track beside it would be a file
        // nothing reads.
        expect(
          File(target.constraintAsset).existsSync(),
          target.scored,
          reason: target.constraintAsset,
        );
        expect(
          File(target.structureAsset).existsSync(),
          isTrue,
          reason: '${target.structureAsset} — run pipeline/structure/bake.py',
        );
      });

      test('${target.slug} record parses and describes the gene it claims', () {
        final GeneRecord record = _record(target);
        expect(record.gene, target.gene);
        expect(record.sequence.length, record.lengthBp);
        expect(record.protein, isNotNull);
        // Introns are the only thing ever shortened, so a compressed record
        // still has to hold every base of its own transcript.
        final int exonic = record.exons.fold(
          0,
          (int sum, Exon e) => sum + (e.end - e.start + 1),
        );
        expect(exonic, greaterThan(0));
        expect(exonic, lessThanOrEqualTo(record.lengthBp));
        if (record.isIntronCompressed) {
          expect(record.realSpanBp, greaterThan(record.lengthBp));
        } else {
          expect(record.intronScale, isNull);
        }
      });

      if (target.scored) {
        test('${target.slug} constraint track describes that exact protein', () {
          final ProteinConstraint constraint = ProteinConstraint.fromJson(
            _json(target.constraintAsset),
            target,
          );
          // The invariant the whole feature rests on. The protein page colours
          // itself only where the stage's letters are the track's sequence, so
          // if these two ever disagree the page silently loses its colour — and
          // the two are baked by different tools, hours apart.
          expect(constraint.sequence, _record(target).protein!.translation);
          expect(constraint.positions.length, constraint.sequence.length);
          for (final ResidueConstraint residue in constraint.positions) {
            expect(residue.region.contains(residue.index + 1), isTrue);
            expect(residue.domainPosition, greaterThan(0));
            expect(residue.note, isNotEmpty);
            expect(residue.title, isNotEmpty);
          }
        });
      }

      test('${target.slug} walks every stage the record supports', () {
        final GeneRecord record = _record(target);
        final AnatomyModel model = AnatomyModel.derive(record);
        expect(model.stages, isNotEmpty);
        expect(model.stages.first.kind, StageKind.gene);
        for (final AnatomyStage stage in model.stages) {
          expect(stage.count, stage.letters.length);
          expect(stage.runs, isNotEmpty);
          expect(stage.sentence, isNotEmpty);
          expect(
            stage.positions.length,
            stage.count * stage.positionsPerCell,
          );
          // Every cell has to resolve to a run, and every run to a feature.
          for (int cell = 0; cell < stage.count; cell++) {
            expect(stage.runAt(cell).label, isNotEmpty);
          }
        }
      });

      test('${target.slug} protein page is the page the track colours', () {
        final AnatomyModel model = AnatomyModel.derive(_record(target));
        final Iterable<AnatomyStage> protein = model.stages.where(
          (AnatomyStage s) => s.kind == StageKind.protein,
        );
        expect(protein, hasLength(1));
        if (!target.scored) {
          return;
        }
        final ProteinConstraint constraint = ProteinConstraint.fromJson(
          _json(target.constraintAsset),
          target,
        );
        // `AnatomyScreen._supportsConstraint` gates on exactly this comparison.
        expect(protein.single.letters, constraint.sequence);
      });
    }
  });

  test('a peptide label drops the protein name, and only that', () {
    Map<String, List<String>> forms(ProteinTarget target) {
      final AnatomyModel model = AnatomyModel.derive(_record(target));
      return <String, List<String>>{
        for (final AnatomyStage stage in model.stages)
          for (final StageRun run in stage.runs) run.label: run.labelForms.toList(),
      };
    }

    // The rule generalised with the catalog: it used to be the literal word
    // 'insulin', and relaxin's peptides are named the same way.
    expect(forms(ProteinCatalog.relaxin)['Relaxin B chain'], <String>[
      'Relaxin B chain',
      'B chain',
    ]);
    // Three peptides all called 'Ubiquitin' are numbered apart, and share a
    // first word with nothing but a numeral behind it. Dropping it would name
    // nothing at all.
    expect(forms(ProteinCatalog.ubiquitin)['Ubiquitin 2'], <String>['Ubiquitin 2']);

    for (final ProteinTarget target in ProteinCatalog.all) {
      forms(target).forEach((String label, List<String> written) {
        expect(written, isNotEmpty, reason: '$label in ${target.slug}');
        for (final String form in written) {
          expect(form.trim(), form);
          expect(
            form.length,
            greaterThan(2),
            reason: '"$form" is too short to name anything',
          );
        }
      });
    }
  });

  test('a name written on a run keeps whatever tells it from its neighbours', () {
    // The page may abbreviate a name to keep it inside the run it names. What
    // it may never do is drop the part that says *which* run: 'intron 2' cut
    // to 'intron' would name the other one just as well.
    for (final ProteinTarget target in ProteinCatalog.all) {
      final AnatomyModel model = AnatomyModel.derive(_record(target));
      for (final AnatomyStage stage in model.stages) {
        for (final StageRun run in stage.runs) {
          final List<String> written = run.writtenForms.toList();
          final List<String> prose = run.labelForms.toList();
          expect(
            written.take(prose.length),
            prose,
            reason: '${run.label} in ${target.slug} does not open with the '
                'name it is given in a sentence',
          );
          final RegExp ordinal = RegExp(r'(\d+)\$');
          final Match? number = ordinal.firstMatch(prose.last);
          for (int i = 0; i < written.length; i++) {
            expect(written[i].trim(), written[i], reason: written[i]);
            if (i > 0) {
              expect(
                written[i].length,
                lessThan(written[i - 1].length),
                reason: '"${written[i]}" saves nothing on '
                    '"${written[i - 1]}" in ${target.slug}',
              );
            }
            if (number != null) {
              expect(
                written[i],
                endsWith(number.group(1)!),
                reason: '"${written[i]}" in ${target.slug} lost the ordinal '
                    'that tells ${run.label} from its neighbours',
              );
            }
          }
        }
      }
    }
  });

  test('no base of a cut precursor answers as the whole coding sequence', () {
    // A tap on polyubiquitin's trailing cysteine lit its three bases under
    // "the coding sequence · 690 bases": everything the chains, the cut sites
    // and the stop codon did not claim fell back to the role for all of it.
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      if (record.peptides.isEmpty) {
        continue;
      }
      final AnatomyModel model = AnatomyModel.derive(record);
      for (int p = record.start; p <= record.end; p++) {
        expect(
          model.codingRoleAt(p)?.kind,
          isNot(RoleKind.coding),
          reason: '${target.slug} at $p',
        );
      }
    }

    final AnatomyModel ubiquitin = AnatomyModel.derive(
      _record(ProteinCatalog.ubiquitin),
    );
    final Role? tail = ubiquitin.codingRoleAt(6540);
    expect(tail?.kind, RoleKind.trimmed);
    expect(tail?.label, 'the C-terminal extension');
    expect(tail?.lengthBp, 3);

    // The prion protein's GPI-anchor signal is the same leftover at length:
    // 23 residues after its one chain, cut off before it reaches the membrane.
    final GeneRecord prion = _record(ProteinCatalog.prion);
    final AnatomyModel prionModel = AnatomyModel.derive(prion);
    final Set<Role> trimmed = <Role>{
      for (int p = prion.start; p <= prion.end; p++)
        if (prionModel.codingRoleAt(p) case final Role role
            when role.kind == RoleKind.trimmed)
          role,
    };
    expect(trimmed.map((Role r) => r.label), <String>['the C-terminal extension']);
    expect(trimmed.single.lengthBp, 69);
  });

  test('a record with no chain ends at its protein page', () {
    // Glucagon's and APP's products overlap rather than divide the precursor,
    // SOD1's one peptide is a fragment of the finished enzyme, and CFTR's and
    // TNF's records annotate none. Each walk stops at the protein, where a
    // page after it would have to invent what it shows.
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      expect(
        AnatomyModel.derive(record).stages.last.kind,
        record.peptides.isEmpty ? StageKind.protein : StageKind.maturePeptides,
        reason: target.slug,
      );
    }
  });

  test('every coding role is the size of the bases that answer with it', () {
    // A role carries its feature's length so a tap can say it. Where the two
    // came apart a tap said one number and lit another: glucagon's chain was
    // sized with its signal peptide's 60 bases still in it.
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
      // Keyed by identity: every base of one feature holds the same `Role`.
      final Map<Role, int> bases = <Role, int>{};
      for (int p = record.start; p <= record.end; p++) {
        if (model.codingRoleAt(p) case final Role role) {
          bases[role] = (bases[role] ?? 0) + 1;
        }
      }
      bases.forEach((Role role, int count) {
        expect(role.lengthBp, count, reason: '${target.slug}: ${role.label}');
      });
    }
  });

  test('a precursor with a signal peptide is drawn split, named or not', () {
    // Insulin was the only record naming a proprotein, so it was the only
    // protein page that showed its leader. Lysozyme's 18 residues sat unmarked
    // in one grid and were gone on the next page.
    final AnatomyStage lysozyme = AnatomyModel.derive(
      _record(ProteinCatalog.lysozyme),
    ).stages.firstWhere((AnatomyStage s) => s.kind == StageKind.protein);
    expect(
      lysozyme.blocks.map((StageBlock b) => b.label).toList(),
      <String>['signal peptide', 'lysozyme C'],
    );
    expect(
      lysozyme.blocks.map((StageBlock b) => b.count).toList(),
      <int>[18, 130],
    );
    expect(lysozyme.sentence, 'signal peptide 1–18 · lysozyme C 19–148');

    // A precursor still to be cut into several chains is named for itself.
    // Neither chromosome slice annotates one; the table names them.
    String proproteinOf(ProteinTarget target) => AnatomyModel.derive(
      _record(target),
    ).stages.firstWhere((AnatomyStage s) => s.kind == StageKind.protein).blocks[1].label!;
    expect(proproteinOf(ProteinCatalog.oxytocin), 'oxytocin-neurophysin 1');
    expect(proproteinOf(ProteinCatalog.relaxin), 'prorelaxin');
    expect(proproteinOf(ProteinCatalog.insulin), 'proinsulin');
    // Vasopressin's RefSeqGene names none either. Glucagon's names its own;
    // APP's precursor stops here, and the table names what it becomes.
    expect(
      proproteinOf(ProteinCatalog.vasopressin),
      'vasopressin-neurophysin 2-copeptin',
    );
    expect(proproteinOf(ProteinCatalog.glucagon), 'pro-glucagon proprotein');
    expect(proproteinOf(ProteinCatalog.app), 'amyloid-beta precursor protein');

    // Erythropoietin's record names its signal peptide and no chain. The bake
    // fills the chain from UniProt, so the page reads as lysozyme's does.
    final AnatomyStage erythropoietin = AnatomyModel.derive(
      _record(ProteinCatalog.erythropoietin),
    ).stages.firstWhere((AnatomyStage s) => s.kind == StageKind.protein);
    expect(
      erythropoietin.blocks.map((StageBlock b) => b.label).toList(),
      <String>['signal peptide', 'Erythropoietin'],
    );
    expect(
      erythropoietin.blocks.map((StageBlock b) => b.count).toList(),
      <int>[27, 166],
    );

    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      final AnatomyStage protein = AnatomyModel.derive(record).stages
          .firstWhere((AnatomyStage s) => s.kind == StageKind.protein);
      expect(
        protein.blocks.first.role == RoleKind.signalPeptide,
        record.signalPeptide != null,
        reason: target.slug,
      );
    }
  });

  test('an uncut protein names its coding sequence as its chain', () {
    // Every cut precursor's gene page reads the chains it becomes; an uncut
    // one read "coding sequence", because its record has no chain to name.
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      expect(
        target.chain != null,
        record.peptides.isEmpty,
        reason: '${target.slug}: a name exactly where there is no chain',
      );
    }

    final GeneRecord hbb = _record(ProteinCatalog.hemoglobin);
    final AnatomyModel model = AnatomyModel.derive(
      hbb,
      chain: ProteinCatalog.hemoglobin.chain,
    );
    final int start = hbb.protein!.segments
        .map((Segment s) => s.start)
        .reduce((int a, int b) => a < b ? a : b);
    final Role? role = model.codingRoleAt(start);
    expect(role?.kind, RoleKind.coding);
    expect(role?.label, 'hemoglobin beta chain');
    // 147 codons, not 148: the stop codon is its own run.
    expect(role?.lengthBp, 441);

    // Ignored where the record names chains of its own.
    final AnatomyModel insulin = AnatomyModel.derive(
      _record(ProteinCatalog.insulin),
      chain: 'ignored',
    );
    for (int p = 0; p < 20000; p++) {
      expect(insulin.codingRoleAt(p)?.label, isNot('ignored'));
    }
  });

  test('a stage caption agrees with its own numbers', () {
    String captionOf(ProteinTarget target, StageKind kind) => AnatomyModel.derive(
      _record(target),
    ).stages.firstWhere((AnatomyStage s) => s.kind == kind).sentence;

    // Every chain with its length, and every cut by its motif. Insulin is cut
    // twice into three; oxytocin once into two.
    expect(
      captionOf(ProteinCatalog.insulin, StageKind.maturePeptides),
      'B chain (30) · C-peptide (31) · A chain (21) · cut at RR, KR',
    );
    expect(
      captionOf(ProteinCatalog.oxytocin, StageKind.maturePeptides),
      'Oxytocin (9) · Neurophysin 1 (94) · cut at GKR',
    );
    // Relaxin is cut as insulin is. Its GenBank record does not annotate the
    // C-peptide, and without it the residues between B and A were one cut.
    expect(
      captionOf(ProteinCatalog.relaxin, StageKind.maturePeptides),
      'B chain (29) · C-peptide (102) · A chain (24) · cut at KR, RKKR',
    );
    // Vasopressin's copeptin comes off at a lone arginine, and the motif says
    // so rather than a word that would call it dibasic.
    expect(
      captionOf(ProteinCatalog.vasopressin, StageKind.maturePeptides),
      'Arg-vasopressin (9) · Neurophysin 2 (93) · Copeptin (39) · cut at GKR, R',
    );
    expect(
      captionOf(ProteinCatalog.ubiquitin, StageKind.maturePeptides),
      '3 × Ubiquitin (76)',
    );

    // Dystrophin is not drawn to scale, and its caption has to say so.
    expect(
      captionOf(ProteinCatalog.dystrophin, StageKind.gene),
      '79 exons · 78 introns · introns 99.3% of span, drawn shortened',
    );
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
      final String gene = captionOf(target, StageKind.gene);
      expect(
        gene.contains('drawn shortened'),
        record.isIntronCompressed,
        reason: target.slug,
      );
      // The chains listed add up to the residues the page draws.
      for (final AnatomyStage stage in model.stages) {
        if (stage.kind != StageKind.maturePeptides) {
          continue;
        }
        int listed = 0;
        for (final RegExpMatch m in RegExp(
          r'(?:(\d+) × )?[^·()]+\((\d+)\)',
        ).allMatches(stage.sentence)) {
          listed += int.parse(m.group(1) ?? '1') * int.parse(m.group(2)!);
        }
        expect(listed, stage.count, reason: '${target.slug}: ${stage.sentence}');
      }
      // Every caption fits the strip's two lines at about 80 characters.
      for (final AnatomyStage stage in model.stages) {
        expect(
          stage.sentence.length,
          lessThanOrEqualTo(80),
          reason: '${target.slug} ${stage.kind.name}: ${stage.sentence}',
        );
      }
    }
  });

  test('a shortened intron is named at its real length, and says how much is drawn', () {
    TracerStatus tapRun(AnatomyModel model, StageRun run) => TracerReader.resolve(
      model: model,
      tracer: Tracer(model.stages.first.positionAt(run.start, 0), asRun: true),
      stageIndex: 0,
    );

    final GeneRecord record = _record(ProteinCatalog.dystrophin);
    final AnatomyModel model = AnatomyModel.derive(record);
    final List<StageRun> introns = model.stages.first.runs
        .where((StageRun r) => r.kind == RoleKind.intron)
        .toList();
    expect(introns.length, record.realIntronBp!.length);
    expect(
      introns.fold<int>(0, (int sum, StageRun r) => sum + r.lengthBp),
      record.realSpanBp! - (record.lengthBp - introns.fold<int>(0, (int sum, StageRun r) => sum + r.count)),
      reason: 'the introns and the exons add back up to the real gene',
    );

    // Dystrophin's largest intron: 248,401 bases, drawn as 985.
    final StageRun largest = introns.reduce(
      (StageRun a, StageRun b) => a.lengthBp >= b.lengthBp ? a : b,
    );
    final TracerStatus status = tapRun(model, largest);
    expect(status.line, '${largest.label} · 248,401 bp · 12% of the gene');
    expect(status.note, matches(RegExp(r'^[ACGT]{2}…[ACGT]{2} · ')));
    expect(status.note, endsWith('drawn shortened: 985 of 248,401 bp shown'));

    // A gene drawn to scale says only what the intron is.
    final AnatomyModel insulin = AnatomyModel.derive(_record(ProteinCatalog.insulin));
    final StageRun intron = insulin.stages.first.runs.firstWhere(
      (StageRun r) => r.kind == RoleKind.intron,
    );
    expect(intron.count, intron.lengthBp);
    expect(tapRun(insulin, intron).note, 'GT…AG · in the 5\u2032 UTR');
  });

  test('a long transcript is folded to its ends, and a short one is not', () {
    const Size phone = Size(390, 560);
    for (final ProteinTarget target in ProteinCatalog.all) {
      final AnatomyModel model = AnatomyModel.derive(_record(target));
      final AnatomyStage mrna = model.stages.firstWhere(
        (AnatomyStage s) => s.kind == StageKind.mrna,
      );
      final AnatomyLayout layout = AnatomyLayout.forStage(mrna, phone, phone);
      for (int b = 0; b < mrna.blocks.length; b++) {
        final StageBlock block = mrna.blocks[b];
        expect(
          layout.foldBandOf(b) != null,
          block.count > AnatomyLayout.foldAbove,
          reason: '${target.slug} block $b (${block.count} bases)',
        );
        if (block.count == 0) {
          continue;
        }
        // Each region's first and last base are always drawn.
        expect(layout.isHidden(block.start), isFalse, reason: target.slug);
        expect(
          layout.isHidden(block.start + block.count - 1),
          isFalse,
          reason: target.slug,
        );
      }
    }

    // Dystrophin's 13,993 bases were about twenty-five screens. Under five
    // now rather than under four: the bases grew from 21pt to 26pt so that one
    // of them could be tapped, and the page grew with them.
    final AnatomyStage dystrophin = AnatomyModel.derive(
      _record(ProteinCatalog.dystrophin),
    ).stages[1];
    expect(AnatomyLayout.heightFor(dystrophin, phone), lessThan(5 * phone.height));
    final TracerStatus folded = TracerReader.resolve(
      model: AnatomyModel.derive(_record(ProteinCatalog.dystrophin)),
      tracer: Tracer(dystrophin.positionAt(dystrophin.blocks[1].start + 6000, 0)),
      stageIndex: 1,
      hidden: AnatomyLayout.forStage(dystrophin, phone, phone).isHidden,
    );
    expect(folded.alive, isTrue);
    expect(folded.note, TracerReader.foldedNote);
  });

  test('a shortened gene counts itself at its real length', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      final AnatomyModel model = AnatomyModel.derive(record);
      final AnatomyStage gene = model.stages.first;
      if (record.isIntronCompressed) {
        // The badge is the first number on the page; the drawing's length is
        // the scale note's business, not the badge's.
        expect(gene.shownCount, record.realSpanBp, reason: target.slug);
        expect(gene.shownCount, greaterThan(gene.count), reason: target.slug);
      } else {
        expect(gene.shownCount, gene.count, reason: target.slug);
        expect(gene.count, record.lengthBp, reason: target.slug);
      }
      for (final AnatomyStage stage in model.stages.skip(1)) {
        expect(stage.shownCount, stage.count, reason: '${target.slug} ${stage.kind.name}');
      }
    }
    final AnatomyStage dystrophin = AnatomyModel.derive(
      _record(ProteinCatalog.dystrophin),
    ).stages.first;
    expect(dystrophin.shownCount, 2092329);
  });

  test('every gene page has rows tall enough to name, and scrolls for them', () {
    // The canvas a 390pt phone gives the gene: full width, less header,
    // caption and paginator.
    const Size phone = Size(390, 498);
    for (final ProteinTarget target in ProteinCatalog.all) {
      final AnatomyStage gene = AnatomyModel.derive(
        _record(target),
      ).stages.first;
      final AnatomyLayout layout = AnatomyLayout.forStage(gene, phone, phone);

      // The painter caps a name at four fifths of its row and will not set one
      // under 11pt, so a row under [AnatomyLayout.geneRow] names nothing.
      expect(
        layout.rowHeight,
        greaterThanOrEqualTo(AnatomyLayout.geneRow),
        reason: target.slug,
      );
      expect(layout.rowHeight * 0.8, greaterThanOrEqualTo(11), reason: target.slug);

      // A gene that outgrows the screen tells the screen so, from the top.
      final double height = AnatomyLayout.heightFor(gene, phone);
      if (layout.size.height > phone.height + 1e-9) {
        expect(height, closeTo(layout.size.height, 1e-9), reason: target.slug);
        expect(layout.origin.dy, 0, reason: target.slug);
      } else {
        expect(height, 0, reason: target.slug);
      }
    }

    // Myoglobin's 10,566 bases are past what one screen holds at that height,
    // which is the case that lost every exon's name.
    final AnatomyStage myoglobin = AnatomyModel.derive(
      _record(ProteinCatalog.myoglobin),
    ).stages.first;
    expect(AnatomyLayout.heightFor(myoglobin, phone), greaterThan(phone.height));
    expect(
      AnatomyLayout.heightFor(
        AnatomyModel.derive(_record(ProteinCatalog.insulin)).stages.first,
        phone,
      ),
      0,
    );
  });

  test('every residue page has tiles large enough to letter, and scrolls for them', () {
    // A protein page as a 390pt phone gives it, with the conservation toolbar.
    const Size phone = Size(390, 560);
    final Set<String> scrolling = <String>{};
    for (final ProteinTarget target in ProteinCatalog.all) {
      final AnatomyModel model = AnatomyModel.derive(_record(target));
      for (final AnatomyStage stage in model.stages) {
        if (stage.kind == StageKind.gene || stage.kind == StageKind.mrna) {
          continue;
        }
        final AnatomyLayout layout = AnatomyLayout.forStage(stage, phone, phone);
        final String reason = '${target.slug} ${stage.kind.name}';
        expect(
          layout.cell,
          greaterThanOrEqualTo(AnatomyLayout.residuePitch - 1e-9),
          reason: reason,
        );
        expect(layout.isLettered, isTrue, reason: reason);

        final double height = AnatomyLayout.heightFor(stage, phone);
        if (layout.size.height > phone.height + 1e-9) {
          expect(height, closeTo(layout.size.height, 1e-9), reason: reason);
          expect(layout.origin.dy, 0, reason: reason);
          scrolling.add(target.slug);
        } else {
          expect(height, 0, reason: reason);
        }
      }
    }
    // 3,685 residues are the case that came out as eight-point squares.
    expect(scrolling, contains(ProteinCatalog.dystrophin.slug));
    expect(scrolling, isNot(contains(ProteinCatalog.insulin.slug)));
  });

  test('every track is fetched, and none of them ships', () {
    // This replaced a test that read `flutter_scene_generated/manifest.json`
    // and held every model to a compiled scene. Nothing compiles them now: all
    // four families are fetched from storage, and the one way to undo that
    // silently is to put a directory back under `flutter: assets:`. So the
    // bundle's own list is what is checked, rather than the prose around it —
    // every one of these names appears in the comments there, explaining why it
    // is gone.
    final Set<String> bundled = _bundledPaths();
    expect(bundled, contains('assets/mock/'));
    for (final String gone in <String>[
      'assets/constraint/',
      'assets/impact/',
      'assets/clinvar/',
      'flutter_scene_generated/',
    ]) {
      expect(bundled, isNot(contains(gone)), reason: '$gone is shipping again');
    }
    expect(
      File('hook/build.dart').readAsStringSync(),
      isNot(contains('buildScenes(')),
      reason: 'the build hook is compiling the folds into the bundle again',
    );

    // And every source is still in the repo, because the bake, the uploader
    // and the tests above all read them off it.
    for (final ProteinTarget target in ProteinCatalog.all) {
      for (final String path in <String>[
        target.structureAsset,
        target.constraintAsset,
        target.impactAsset,
        target.clinvarAsset,
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('every lettered page reads like text, and its ruler clears the screen edge', () {
    const Size phone = Size(390, 560);
    for (final ProteinTarget target in ProteinCatalog.all) {
      final AnatomyModel model = AnatomyModel.derive(
        _record(target),
        chain: target.chain,
      );
      for (final AnatomyStage stage in model.stages) {
        final AnatomyLayout layout = AnatomyLayout.forStage(stage, phone, phone);
        final String reason = '${target.slug} ${stage.kind.name}';
        expect(layout.serpentine, stage.kind == StageKind.gene, reason: reason);
        if (!AnatomyRuler.rules(stage)) {
          continue;
        }
        // The widest label, set right-aligned against the first square, must
        // start on the screen.
        final double labelWidth = AnatomyRuler.widest(stage) *
            AnatomyRuler.fontSize *
            AnatomyRuler.advance;
        expect(
          layout.origin.dx + (layout.cell - layout.side) / 2 - AnatomyRuler.pad - labelWidth,
          greaterThanOrEqualTo(0),
          reason: reason,
        );
        // Every row start has a label no wider than the widest.
        for (final StageBlock block in stage.blocks) {
          for (int cell = block.start; cell < block.start + block.count; cell += layout.columns) {
            final String? label = AnatomyRuler.labelAt(stage, cell);
            expect(label, isNotNull, reason: reason);
            expect(label!.length, lessThanOrEqualTo(AnatomyRuler.widest(stage)), reason: '$reason $label');
          }
        }
      }
    }
  });

  test('an uncut coding sequence is named and selected exon by exon', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
      final AnatomyStage gene = model.stages.first;
      final Iterable<StageRun> coding = gene.runs.where(
        (StageRun run) => run.kind == RoleKind.coding,
      );
      if (target.chain == null) {
        // A cut precursor's coding bases all answer as the chains they become.
        expect(coding, isEmpty, reason: target.slug);
        continue;
      }
      expect(coding, isNotEmpty, reason: target.slug);
      final Set<int> features = <int>{};
      for (final StageRun run in coding) {
        final Role exon = model.transcriptRoleAt(gene.positionAt(run.start))!;
        expect(run.label, exon.label, reason: target.slug);
        expect(features.add(run.feature), isTrue, reason: '${target.slug} ${run.label} shares a feature');
        // Selected, it is that exon's coding bases and nothing else.
        final AnatomySelection selection = AnatomySelection.of(
          model,
          gene.positionAt(run.start),
        );
        expect(selection.pieces, 1, reason: '${target.slug} ${run.label}');
        expect(selection.stage.count, run.lengthBp, reason: '${target.slug} ${run.label}');
        expect(selection.stage.blocks.single.framed, isTrue, reason: '${target.slug} ${run.label}');
      }
      // Everywhere but the gene page it is still the one chain.
      final bool named = record.protein!.segments.any(
        (Segment segment) => <int>[
          for (int p = segment.start; p <= segment.end; p++) p,
        ].any((int p) => model.codingRoleAt(p)?.label == target.chain),
      );
      expect(named, isTrue, reason: target.slug);
    }
  });

  test('a coding feature on the gene says which exons encode it', () {
    final AnatomyModel insulin = AnatomyModel.derive(_record(ProteinCatalog.insulin));
    final AnatomyStage gene = insulin.stages.first;
    String exons(String label) => TracerReader.exonsOf(
      insulin,
      gene,
      gene.runs.firstWhere((StageRun run) => run.label == label),
    );
    expect(exons('the signal peptide'), ' · exon 2');
    expect(exons('C-peptide'), ' · exons 2–3');
    expect(exons('insulin A chain'), ' · exon 3');
    expect(exons('intron 1'), '');
  });

  test('the facts a search card leads with are the assets\' own', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
      final ProteinFacts facts = target.facts;
      final AnatomyStage protein = model.stages.firstWhere(
        (AnatomyStage s) => s.kind == StageKind.protein,
      );
      expect(facts.residues, protein.count, reason: target.slug);
      expect(
        facts.exons,
        model.stages.first.runs
            .map((StageRun r) => model.transcriptRoleAt(model.stages.first.positionAt(r.start)))
            .where((Role? role) => role?.kind == RoleKind.exon)
            .map((Role? role) => role!.label)
            .toSet()
            .length,
        reason: target.slug,
      );
      final Iterable<AnatomyStage> mature = model.stages.where(
        (AnatomyStage s) => s.kind == StageKind.maturePeptides,
      );
      expect(
        facts.chains,
        mature.isEmpty ? 1 : mature.single.blocks.length,
        reason: target.slug,
      );
      expect(
        facts.bridges,
        (_json(target.constraintAsset)['disulfides'] as List<dynamic>).length,
        reason: target.slug,
      );
      if (target.structure.modelled case (final int from, final int to)) {
        expect(to - from + 1, target.structure.count, reason: target.slug);
        expect(to, lessThanOrEqualTo(facts.residues), reason: target.slug);
      }
    }
  });

  test('every gene numbers its exons 1 to N in the order they are read', () {
    for (final ProteinTarget target in ProteinCatalog.all) {
      final GeneRecord record = _record(target);
      final AnatomyModel model = AnatomyModel.derive(record, chain: target.chain);
      final AnatomyStage gene = model.stages.first;
      final List<String> seen = <String>[];
      for (int cell = 0; cell < gene.count; cell++) {
        final Role? role = model.transcriptRoleAt(gene.positionAt(cell));
        if (role?.kind == RoleKind.exon && (seen.isEmpty || seen.last != role!.label)) {
          seen.add(role!.label);
        }
      }
      expect(
        seen,
        <String>[for (int i = 1; i <= target.facts.exons; i++) 'exon $i'],
        reason: target.slug,
      );
    }
  });
}
