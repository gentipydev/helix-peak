import 'package:flutter/foundation.dart';

import '../../../../shared/anatomy/anatomy_stages.dart';
import 'playhead.dart';

enum DnaStepKind { codon, intron }

/// One thing DNA mode plays: a codon's chord, or one base of an intron.
@immutable
final class DnaStep {
  const DnaStep({
    required this.kind,
    required this.onset,
    required this.length,
    required this.positions,
    required this.bases,
    this.codon,
    this.intron,
  });

  final DnaStepKind kind;

  /// When it starts and how long it lasts, in samples.
  final int onset;
  final int length;

  /// The genomic positions it sounds: a codon's three, 5' to 3', or the
  /// intron's one base. A tap on any of them is a tap on this step.
  final List<int> positions;

  /// The one the playhead marks while it sounds: a codon's first base.
  int get position => positions.first;

  /// A codon's three letters, 5' to 3', or an intron base's one.
  final String bases;

  /// Which codon, from 0; the stop codon is the last. Null for an intron base.
  final int? codon;

  /// Which intron of the gene, as the page names it (`intron 2`). Null for a
  /// codon.
  final String? intron;
}

/// DNA mode: a protein's coding sequence as a chord a codon, and, unspliced,
/// every drawn base of the introns that interrupt it as a grain of its own.
///
/// From the start codon to the stop codon, in the order the gene reads 5' to
/// 3'. Each codon lasts as long as the residue it codes for does on the
/// protein's own track ([ListenTempo]), so a codon and its residue share a
/// length; the stop codon ends the piece. An intron plays base by base, a
/// short grain each ([grainSamples]): an intron is not read, and as sound it
/// is a rustle between chords, as long as the intron is drawn long. Spliced,
/// the introns are gone and the codons run on, as on the mRNA page.
///
/// A codon an intron splits sounds whole where its first base is; its other
/// bases, beyond the intron, are part of that chord. A gene whose introns
/// arrive shortened (R2.4) plays the bases its page draws, no more.
@immutable
final class DnaScore {
  const DnaScore({
    required this.spliced,
    required this.noteSamples,
    required this.grainSamples,
    required this.steps,
    required this.onsetMs,
    required this.samples,
    required this.codons,
    required this.introns,
    required this.intronBases,
    required this.intronLengthBp,
  });

  /// Derives the score from [model]'s own pages: the protein page for the
  /// codons (each residue's three bases), the role table for the stop codon,
  /// and the gene page for the order the introns fall in.
  ///
  /// Throws [StateError] for a record [refusal] refuses.
  factory DnaScore.of(
    AnatomyModel model, {
    required bool spliced,
    int grainSamples = grain,
  }) {
    final String? refused = refusal(model);
    if (refused != null) {
      throw StateError(refused);
    }
    final AnatomyStage protein = model.stages.firstWhere(
      (AnatomyStage s) => s.kind == StageKind.protein,
    );
    final AnatomyStage gene = model.stages.firstWhere(
      (AnatomyStage s) => s.kind == StageKind.gene,
    );
    final int noteSamples = ListenTempo.noteSamplesFor(protein.count)!;

    // Each codon's three positions: the residues', then the stop codon's.
    final List<List<int>> codons = <List<int>>[
      for (int i = 0; i < protein.count; i++)
        <int>[
          protein.positionAt(i),
          protein.positionAt(i, 1),
          protein.positionAt(i, 2),
        ],
    ];
    final List<int> stop = <int>[
      for (int cell = 0; cell < gene.count; cell++)
        if (model.codingRoleAt(gene.positionAt(cell))?.kind ==
            RoleKind.stopCodon)
          gene.positionAt(cell),
    ];
    if (stop.length == 3) {
      codons.add(stop);
    }

    final List<DnaStep> steps = <DnaStep>[];
    int onset = 0;
    void codon(int k) {
      final List<int> at = codons[k];
      steps.add(
        DnaStep(
          kind: DnaStepKind.codon,
          onset: onset,
          length: noteSamples,
          positions: List<int>.unmodifiable(at),
          bases: at.map(model.baseAt).join(),
          codon: k,
        ),
      );
      onset += noteSamples;
    }

    int intronBases = 0;
    // Each intron inside the coding sequence, by the page's name for it, and
    // its real length: a shortened one plays only the bases drawn of it.
    final Map<String, int> introns = <String, int>{};
    if (spliced) {
      for (int k = 0; k < codons.length; k++) {
        codon(k);
      }
    } else {
      final Map<int, int> codonOf = <int, int>{
        for (int k = 0; k < codons.length; k++)
          for (final int position in codons[k]) position: k,
      };
      final int first = gene.cellAt(codons.first.first);
      final int last = gene.cellAt(codons.last.last);
      final Set<int> sounded = <int>{};
      for (int cell = first; cell <= last; cell++) {
        final int position = gene.positionAt(cell);
        final int? k = codonOf[position];
        if (k != null) {
          if (sounded.add(k)) {
            codon(k);
          }
          continue;
        }
        final Role? role = model.transcriptRoleAt(position);
        if (role?.kind != RoleKind.intron) {
          continue;
        }
        introns[role!.label] = role.lengthBp;
        intronBases++;
        steps.add(
          DnaStep(
            kind: DnaStepKind.intron,
            onset: onset,
            length: grainSamples,
            positions: <int>[position],
            bases: model.baseAt(position),
            intron: role.label,
          ),
        );
        onset += grainSamples;
      }
    }

    return DnaScore(
      spliced: spliced,
      noteSamples: noteSamples,
      grainSamples: grainSamples,
      steps: List<DnaStep>.unmodifiable(steps),
      onsetMs: Int32List.fromList(<int>[
        for (final DnaStep step in steps)
          ListenTempo.millisecondsOf(step.onset),
      ]),
      samples: onset,
      codons: codons.length,
      introns: introns.length,
      intronBases: intronBases,
      intronLengthBp: introns.values.fold<int>(
        0,
        (int sum, int bp) => sum + bp,
      ),
    );
  }

  /// Why [model] has no DNA mode, or null where it has one: a gene that makes
  /// no protein has no codons, and a protein too long for 25 ms notes in two
  /// minutes plays no track at all.
  static String? refusal(AnatomyModel model) {
    final int protein = model.stages.indexWhere(
      (AnatomyStage s) => s.kind == StageKind.protein,
    );
    if (protein < 0 ||
        !model.stages.any((AnatomyStage s) => s.kind == StageKind.gene)) {
      return 'This gene makes no protein, so it has no codons to play.';
    }
    if (ListenTempo.noteSamplesFor(model.stages[protein].count) == null) {
      return 'This protein is too long to play a note a codon in two minutes.';
    }
    return null;
  }

  /// An intron base's grain: 5 ms. An intron is drawn base by base, and a
  /// long one would play for minutes at a codon's pace; this keeps its length
  /// audible and the piece listenable.
  static const int grain = 80;

  final bool spliced;
  final int noteSamples;
  final int grainSamples;
  final List<DnaStep> steps;

  /// When each step starts, in milliseconds: the timing map the playhead
  /// reads, as the protein's track has one.
  final Int32List onsetMs;

  /// The whole piece, in samples at [ListenTempo.sampleRate].
  final int samples;

  /// Codons played, the stop codon's included.
  final int codons;

  /// How many introns lie inside the coding sequence, and how many of their
  /// bases the page draws and the piece plays. Zero where the coding sequence
  /// is all in one exon: then the gene and its mRNA sound the same.
  final int introns;
  final int intronBases;

  /// Those introns' real length: more than [intronBases] where the gene's
  /// introns arrive shortened.
  final int intronLengthBp;

  int get durationMs => ListenTempo.millisecondsOf(samples);
}
