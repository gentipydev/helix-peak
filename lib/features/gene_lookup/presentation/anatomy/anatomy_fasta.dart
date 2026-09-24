import '../../domain/entities/protein_target.dart';
import 'anatomy_stages.dart';

/// A page's sequence as FASTA, the way a reader takes it into BLAST, an
/// aligner or a primer tool.
///
/// Every sequence is one the walk draws — the transcript's letters, the
/// precursor's residues, the chains the protease leaves — so what is copied is
/// exactly what was on screen, headed by where it came from.
abstract final class AnatomyFasta {
  /// The width FASTA is conventionally wrapped at.
  static const int _width = 60;

  static String _entry(String header, String sequence) {
    final StringBuffer out = StringBuffer('>$header\n');
    for (int i = 0; i < sequence.length; i += _width) {
      out.writeln(
        sequence.substring(
          i,
          i + _width < sequence.length ? i + _width : sequence.length,
        ),
      );
    }
    return out.toString();
  }

  static AnatomyStage? _stage(AnatomyModel model, StageKind kind) =>
      model.stages.where((AnatomyStage s) => s.kind == kind).firstOrNull;

  /// The precursor the record translates.
  static String? protein(AnatomyModel model, ProteinTarget target) {
    final AnatomyStage? stage = _stage(model, StageKind.protein);
    if (stage == null) {
      return null;
    }
    return _entry(
      '${target.gene} ${target.uniprot} precursor 1-${stage.count}',
      stage.letters,
    );
  }

  /// The transcript, T rather than U, as the page letters it.
  static String? mrna(AnatomyModel model, ProteinTarget target) {
    final AnatomyStage? stage = _stage(model, StageKind.mrna);
    if (stage == null) {
      return null;
    }
    return _entry(
      '${target.gene} ${target.accession} mRNA ${stage.count} nt',
      stage.letters,
    );
  }

  /// The coding sequence alone, start codon to stop codon.
  static String? cds(AnatomyModel model, ProteinTarget target) {
    final AnatomyStage? stage = _stage(model, StageKind.mrna);
    if (stage == null || stage.blocks.length != 3 || !stage.blocks[1].framed) {
      return null;
    }
    final StageBlock block = stage.blocks[1];
    return _entry(
      '${target.gene} ${target.accession} CDS c.1-${block.count}',
      stage.letters.substring(block.start, block.start + block.count),
    );
  }

  /// The proprotein its page draws, numbered as the precursor numbers it.
  ///
  /// Its page used to copy the whole precursor under a toast that gave the
  /// proprotein's length: the reader was told one sequence and handed another.
  static String? proprotein(AnatomyModel model, ProteinTarget target) {
    final AnatomyStage? stage = _stage(model, StageKind.proprotein);
    final AnatomyStage? precursor = _stage(model, StageKind.protein);
    if (stage == null || stage.count == 0) {
      return null;
    }
    final int first = precursor?.cellAt(stage.positionAt(0)) ?? -1;
    final int last =
        precursor?.cellAt(stage.positionAt(stage.count - 1)) ?? -1;
    final String span = first < 0 || last < 0
        ? ''
        : ' precursor ${first + 1}-${last + 1}';
    return _entry(
      '${target.gene} ${target.uniprot} proprotein$span',
      stage.letters,
    );
  }

  /// Each chain the precursor is cut into, one entry apiece.
  static String? chains(AnatomyModel model, ProteinTarget target) {
    final AnatomyStage? stage = _stage(model, StageKind.maturePeptides);
    final AnatomyStage? precursor = _stage(model, StageKind.protein);
    if (stage == null) {
      return null;
    }
    final StringBuffer out = StringBuffer();
    for (final StageBlock block in stage.blocks) {
      final int first = precursor?.cellAt(stage.positionAt(block.start)) ?? -1;
      final String span = first < 0
          ? ''
          : ' precursor ${first + 1}-${first + block.count}';
      out.write(
        _entry(
          '${target.gene} ${block.label ?? 'chain'}$span',
          stage.letters.substring(block.start, block.start + block.count),
        ),
      );
    }
    return out.toString();
  }

  /// A region of the gene opened into its DNA, or null for one drawn
  /// shortened, which is not the sequence it names.
  static String? region(
    AnatomyStage dna,
    ProteinTarget target, {
    required bool shortened,
  }) {
    if (shortened) {
      return null;
    }
    return _entry(
      '${target.gene} ${target.accession} ${dna.label} ${dna.count} bp',
      dna.letters,
    );
  }

  /// The gene as the record holds it, or null where its introns are drawn
  /// shortened and the letters on the page are not the gene.
  static String? gene(AnatomyModel model, ProteinTarget target) {
    if (model.record.isIntronCompressed) {
      return null;
    }
    final AnatomyStage gene = model.stages.first;
    final String strand = model.record.strand == -1 ? '-' : '+';
    return _entry(
      '${target.gene} ${target.accession}:${model.record.start}-'
      '${model.record.end}($strand) gene ${gene.count} bp',
      gene.letters,
    );
  }

  /// What a long press on [stage] copies, or null where it has nothing honest
  /// to copy.
  static String? ofStage(
    AnatomyModel model,
    ProteinTarget target,
    AnatomyStage stage,
  ) => switch (stage.kind) {
    StageKind.gene => gene(model, target),
    StageKind.mrna => mrna(model, target),
    StageKind.protein => protein(model, target),
    StageKind.proprotein => proprotein(model, target),
    StageKind.maturePeptides => chains(model, target),
    StageKind.dna => null,
  };

  /// How much a copied entry holds, for the confirmation: '110 aa'.
  static String sizeOf(AnatomyStage stage) =>
      '${stage.count} ${stage.shortUnit}';
}
