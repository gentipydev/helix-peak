import 'package:flutter/foundation.dart';

import '../../../../core/biology/amino_acids.dart';
import '../format.dart';
import 'anatomy_address.dart';
import 'anatomy_stages.dart';

/// A place in the gene the user has tapped, followed through the whole journey.
///
/// Held as a **genomic coordinate**, never as a cell index. Every stage answers
/// "where is this base now?" by containment, so a codon absorbing three bases
/// and a chain splitting back into three need no special case in either
/// direction — which is what makes running the screen backwards free.
@immutable
final class Tracer {
  const Tracer(this.genomicPosition, {this.asRun = false});

  final int genomicPosition;

  /// Whether the tap was asking about the whole run this position sits in
  /// rather than about this one base.
  ///
  /// A tap on a nucleotide stage cannot honestly mean a single base — at nine
  /// pixels nobody hits the one they meant, and one base of 1,431 is not a
  /// question anyone has. It means the region, which is why the answer is
  /// "intron 2 · 787 bases" and not "base 6,000 · T". A tap on a residue is
  /// the opposite: the square is large, lettered, and exactly one amino acid,
  /// so it means what it touches. The flag records which question was asked,
  /// and it travels with the tracer so swiping backwards from a traced residue
  /// still splits it into three bases rather than selecting their run.
  final bool asRun;

  @override
  bool operator ==(Object other) =>
      other is Tracer &&
      other.genomicPosition == genomicPosition &&
      other.asRun == asRun;

  @override
  int get hashCode => Object.hash(genomicPosition, asRun);
}

/// Where the traced base is at one stage, and what to say about it.
@immutable
final class TracerStatus {
  const TracerStatus({
    required this.alive,
    required this.cell,
    required this.anchorStage,
    required this.anchorCell,
    required this.siblings,
    required this.line,
    this.note,
    this.fate,
  });

  /// False once the base has been cut. The ring stays on screen either way.
  final bool alive;

  /// The cell in the stage that was asked about, or -1.
  final int cell;

  /// The stage and cell the ring is drawn on. Once cut, this stops advancing —
  /// the tracer settles where it left the story rather than disappearing.
  final int anchorStage;
  final int anchorCell;

  /// The other two bases of this base's codon, in the current stage's cells.
  /// Empty unless the next stage is where translation happens.
  final List<int> siblings;

  /// The caption line, replacing the stage's sentence.
  final String line;

  /// The second line: a fact about what was tapped that its name and size do
  /// not already say — an intron's splice sites and phase, the start codon's
  /// Kozak context, the precursor span a chain is cut from.
  final String? note;

  /// What removed it, once it is gone.
  final Role? fate;
}

abstract final class TracerReader {
  /// Resolves [tracer] against [stageIndex].
  ///
  /// [hidden] answers whether a cell of the stage is folded out of view on
  /// the page as it is laid out — see `AnatomyLayout.foldAbove`. Only the
  /// layout knows, because where a fold falls depends on how wide the page is.
  static TracerStatus resolve({
    required AnatomyModel model,
    required Tracer tracer,
    required int stageIndex,
    bool Function(int cell)? hidden,
  }) {
    final int position = tracer.genomicPosition;
    final AnatomyStage stage = model.stages[stageIndex];
    final int cell = stage.cellAt(position);

    if (cell >= 0 && !tracer.asRun && (hidden?.call(cell) ?? false)) {
      // Still on this page, and still this base: the ring sits on the fold
      // that stands in for it, and the note says why it is not a square.
      return TracerStatus(
        alive: true,
        cell: cell,
        anchorStage: stageIndex,
        anchorCell: cell,
        siblings: const <int>[],
        line: _liveLine(model, stage, cell, position),
        note: foldedNote,
      );
    }

    if (cell >= 0) {
      return TracerStatus(
        alive: true,
        cell: cell,
        anchorStage: stageIndex,
        anchorCell: cell,
        siblings: tracer.asRun
            ? const <int>[]
            : _siblings(model, stageIndex, position),
        line: tracer.asRun
            ? _runLine(model, stage, cell)
            : _liveLine(model, stage, cell, position),
        note: tracer.asRun
            ? _runNote(model, stage, cell)
            : _liveFact(model, stage, cell, position),
      );
    }

    int lastStage = 0;
    int lastCell = 0;
    for (int i = stageIndex - 1; i >= 0; i--) {
      final int found = model.stages[i].cellAt(position);
      if (found >= 0) {
        lastStage = i;
        lastCell = found;
        break;
      }
    }

    final Role? fate =
        model.codingRoleAt(position) ?? model.transcriptRoleAt(position);
    return TracerStatus(
      alive: false,
      cell: -1,
      anchorStage: lastStage,
      anchorCell: lastCell,
      siblings: const <int>[],
      line: _cutLine(fate),
      note: null,
      fate: fate,
    );
  }

  /// The stage at which this base leaves, or -1 if it survives to the end.
  static int cutAt(AnatomyModel model, Tracer tracer) {
    for (int i = 0; i < model.stages.length; i++) {
      if (model.stages[i].cellAt(tracer.genomicPosition) < 0) {
        return i;
      }
    }
    return -1;
  }

  /// What a selected region is, and how much of the gene it accounts for.
  ///
  /// The share is of the *gene*, not of the stage, at every stage — so watching
  /// one run keep its number while the total collapses is the point. Intron 2
  /// is 55% of the gene and 0% of the mRNA, and it is the same 787 bases in
  /// both sentences.
  static String _runLine(AnatomyModel model, AnatomyStage stage, int cell) {
    final StageRun run = stage.runAt(cell);
    // The real gene, where the drawing is a shortened one: dystrophin's
    // largest intron is 12% of 2.1 Mb, not 4% of the 24,000 bases drawn.
    final int whole = model.record.isIntronCompressed
        ? model.record.realSpanBp ?? model.record.lengthBp
        : model.record.lengthBp;
    final String share = whole > 0
        ? ' · ${(run.lengthBp * 100 / whole).round()}% of the gene'
        : '';
    return '${run.label}${exonsOf(model, stage, run)} · '
        '${grouped(run.lengthBp)} bp$share';
  }

  /// Which exons a gene-page feature lies in — ' · exon 2', ' · exons 2–3' —
  /// or nothing, for a feature that is not in an exon or is named for one.
  ///
  /// A coding feature is named for what it becomes, and a reader thinking in
  /// exons had no way to find out which one the signal peptide is encoded in.
  static String exonsOf(AnatomyModel model, AnatomyStage stage, StageRun run) {
    if (stage.kind != StageKind.gene ||
        run.kind == RoleKind.intron ||
        run.kind == RoleKind.untranscribed ||
        run.label.startsWith('exon ')) {
      return '';
    }
    final List<int> numbers = <int>[];
    for (final StageRun piece in stage.runs) {
      if (piece.feature != run.feature) {
        continue;
      }
      // A run never crosses an intron, so its first base says which exon it
      // is in.
      final Role? exon = model.transcriptRoleAt(stage.positionAt(piece.start));
      final int? number = exon?.kind == RoleKind.exon
          ? int.tryParse(exon!.label.split(' ').last)
          : null;
      if (number != null && !numbers.contains(number)) {
        numbers.add(number);
      }
    }
    if (numbers.isEmpty) {
      return '';
    }
    numbers.sort();
    if (numbers.length == 1) {
      return ' · exon ${numbers.single}';
    }
    final bool consecutive = numbers.last - numbers.first == numbers.length - 1;
    return consecutive
        ? ' · exons ${numbers.first}–${numbers.last}'
        : ' · exons ${numbers.join(', ')}';
  }

  /// What a selected region is, and — for an intron drawn shortened — how much
  /// of it the page is actually showing.
  ///
  /// The line above already gives the real length. Without this the reader
  /// has no way to square 248,401 bases with a block of 985 cells, and every
  /// other number on the page stops being believable.
  static String? _runNote(AnatomyModel model, AnatomyStage stage, int cell) {
    final StageRun run = stage.runAt(cell);
    final AnatomyAddress address = AnatomyAddress.of(model);
    final int position = stage.positionAt(cell);
    final String? fact = switch (run.kind) {
      RoleKind.intron => address.intronFacts(
        model.transcriptRoleAt(position)!,
      ),
      RoleKind.exon => address.exonFacts(address.exonOf(position) ?? 0),
      RoleKind.coding when run.label.startsWith('exon ') => address.exonFacts(
        address.exonOf(position) ?? 0,
      ),
      RoleKind.utr5 => address.kozak(),
      RoleKind.utr3 => address.polyadenylationSignal(),
      RoleKind.untranscribed => 'outside the transcript',
      RoleKind.stopCodon => _codonFact(address, position),
      RoleKind.signalPeptide ||
      RoleKind.maturePeptide ||
      RoleKind.dibasic ||
      RoleKind.trimmed ||
      RoleKind.coding => _precursorSpan(model, stage, run),
      RoleKind.startCodon => address.kozak(),
    };
    if (run.kind == RoleKind.intron &&
        model.record.isIntronCompressed &&
        run.count < run.lengthBp) {
      final String shortened =
          'drawn shortened: ${grouped(run.count)} of '
          '${grouped(run.lengthBp)} bp shown';
      return fact == null ? shortened : '$fact · $shortened';
    }
    return fact;
  }

  /// The precursor residues a coding feature's bases translate to:
  /// `precursor 25–54`, `precursor 1–24 · cleaved after Ala24`.
  static String? _precursorSpan(
    AnatomyModel model,
    AnatomyStage gene,
    StageRun run,
  ) {
    final AnatomyAddress address = AnatomyAddress.of(model);
    int? first;
    int? last;
    for (final StageRun piece in gene.runs) {
      if (piece.feature != run.feature) {
        continue;
      }
      for (int c = piece.start; c < piece.start + piece.count; c++) {
        final int? codon = address.codonOf(gene.positionAt(c));
        final int? residue = codon == null
            ? null
            : address.residueOfCodon(codon);
        if (residue == null) {
          continue;
        }
        first = first == null || residue < first ? residue : first;
        last = last == null || residue > last ? residue : last;
      }
    }
    if (first == null || last == null) {
      return null;
    }
    final String span = first == last
        ? 'precursor ${grouped(first)}'
        : 'precursor ${grouped(first)}–${grouped(last)}';
    if (run.kind == RoleKind.signalPeptide) {
      final String? end = address.residueName(last);
      return end == null ? span : '$span · cleaved after $end';
    }
    return span;
  }

  /// A codon and what it codes for: `c.73–75 · GCC · Ala25`, or the stop.
  static String? _codonFact(AnatomyAddress address, int position) {
    final int? codon = address.codonOf(position);
    if (codon == null) {
      return null;
    }
    final String? triplet = address.tripletOf(codon);
    final int? residue = address.residueOfCodon(codon);
    final String meaning = residue == null
        ? 'stop'
        : address.residueName(residue) ?? '';
    return '${address.cSpanOf(codon)} · ${triplet ?? ''} · $meaning';
  }

  static String _liveLine(
    AnatomyModel model,
    AnatomyStage stage,
    int cell,
    int position,
  ) {
    final AnatomyAddress address = AnatomyAddress.of(model);
    if (stage.positionsPerCell == 1) {
      // On the transcript a tap asks about the codon it landed in, and answers
      // in the coordinates the field uses: its c. span, its bases, and the
      // residue it codes for. An untranslated base answers with its own c.
      // position.
      if (stage.kind == StageKind.mrna && address.coding) {
        final CodonMark mark = stage.codonMarkAt(cell);
        final String? codon = _codonFact(address, position);
        if (codon != null) {
          return switch (mark) {
            CodonMark.start => '$codon · start codon',
            CodonMark.stop => '$codon codon',
            CodonMark.none => codon,
          };
        }
        final String? c = address.cOf(position);
        final String where = stage.blocks[stage.blockOf(cell)].label ?? '';
        return '${c ?? ''} · ${model.baseAt(position)} · $where';
      }
      // What the page a reader is looking at is actually drawn as. The gene is
      // drawn as exons and introns; the transcript is drawn as three named
      // regions, so a base there says which of the three it is in rather than
      // that it survived splicing — which every base on that page did, and so
      // told nobody anything. 'survived splicing' is what is left for a
      // non-coding gene's mRNA, which is drawn as one piece and has no regions
      // to name.
      final String where = stage.kind == StageKind.gene
          ? model.transcriptRoleAt(position)?.label ?? 'in the gene'
          : stage.blocks[stage.blockOf(cell)].label ?? 'survived splicing';
      final String? c = address.cOf(position);
      return '${c ?? where} · ${model.baseAt(position)}'
          '${c == null ? '' : ' · $where'}';
    }

    final StageBlock block = stage.blocks[stage.blockOf(cell)];
    final String code = stage.letters[cell];

    // Cited by its precursor number first, the way the score sheet cites it.
    // On the mature peptides the chains the protease has separated also number
    // themselves, so the chain's own position follows; on the precursor a
    // named stretch is part of one unbroken chain and has no numbering of its
    // own.
    final int number = address.precursorNumberOf(stage, cell) ?? cell + 1;
    final String cited = '${AminoAcids.abbreviationOf(code)}$number';
    final String where =
        model.codingRoleAt(position)?.label ?? block.label ?? stage.label;
    if (stage.kind == StageKind.maturePeptides) {
      final StageRun run = stage.runAt(cell);
      final String name = run.labelForms.last;
      return '$cited · $name residue ${cell - block.start + 1}';
    }
    return '$cited · $where';
  }

  /// The second line for a single base or residue: the codon behind it.
  static String? _liveFact(
    AnatomyModel model,
    AnatomyStage stage,
    int cell,
    int position,
  ) {
    final AnatomyAddress address = AnatomyAddress.of(model);
    if (stage.positionsPerCell == 1) {
      if (stage.kind == StageKind.mrna) {
        final CodonMark mark = stage.codonMarkAt(cell);
        if (mark == CodonMark.start) {
          return address.kozak();
        }
        final int? exon = address.exonOf(position);
        if (address.codonOf(position) == null) {
          final String where = stage.blocks[stage.blockOf(cell)].label ?? '';
          return where.startsWith('3')
              ? address.polyadenylationSignal()
              : address.kozak();
        }
        return exon == null ? null : _codonExons(model, stage, cell, exon);
      }
      return null;
    }
    // A residue: the codon it was read from, and the exons that hold it.
    final int? codon = address.codonOf(stage.positionAt(cell));
    if (codon == null) {
      return null;
    }
    return '${address.cSpanOf(codon)} · ${address.tripletOf(codon) ?? ''}';
  }

  /// Which exon a codon was read from — or both, where an intron split it.
  static String _codonExons(
    AnatomyModel model,
    AnatomyStage stage,
    int cell,
    int exon,
  ) {
    final AnatomyAddress address = AnatomyAddress.of(model);
    final int? codon = address.codonOf(stage.positionAt(cell));
    if (codon == null) {
      return 'exon $exon';
    }
    final Set<int> exons = <int>{};
    for (final int c in stage.frameCodon(CodonMark.start).isEmpty
        ? const <int>[]
        : <int>[0, 1, 2]) {
      final int at = stage.blocks[1].start + (codon - 1) * 3 + c;
      if (at < stage.count) {
        final int? e = address.exonOf(stage.positionAt(at));
        if (e != null) {
          exons.add(e);
        }
      }
    }
    if (exons.length > 1) {
      final List<int> sorted = exons.toList()..sort();
      return 'exons ${sorted.first}–${sorted.last} · split codon';
    }
    return 'exon ${exons.isEmpty ? exon : exons.single}';
  }

  /// What a fold stands in for, for a base drawn inside one.
  static const String foldedNote =
      'Folded out of view, with the middle of a region too long to draw '
      'whole. The fold says how many bases it holds.';

  static String _cutLine(Role? fate) {
    if (fate == null) {
      return 'gone from here';
    }
    final String size = '${grouped(fate.lengthBp)} bp';
    return switch (fate.kind) {
      // Not removed — spent. The ribosome read these three and stopped.
      RoleKind.stopCodon => 'read as ${fate.label} · $size',
      RoleKind.dibasic => 'consumed as the ${fate.label} · $size',
      _ => 'removed with ${fate.label} · $size',
    };
  }

  /// The two bases sharing a codon with [position], as cells of the current
  /// stage — but only when the next stage is the one that merges them.
  ///
  /// Nothing else in the app makes the three-to-one ratio this concrete, and
  /// asking the *next* stage which cell owns the base is what finds them: no
  /// reading frame arithmetic here, and it stays right for the codon that
  /// straddles the intron.
  static List<int> _siblings(AnatomyModel model, int stageIndex, int position) {
    final AnatomyStage stage = model.stages[stageIndex];
    if (stage.positionsPerCell != 1) {
      return const <int>[];
    }
    // A frame end knows its own three without asking the next page, and the
    // stop codon has to: it codes for no residue, so there is nothing over
    // there to ask. Without this the caption would name a codon while the ring
    // marked one square of it.
    final int here = stage.cellAt(position);
    if (here >= 0) {
      final List<int> codon = stage.frameCodon(stage.codonMarkAt(here));
      if (codon.isNotEmpty) {
        return codon.where((int c) => c != here).toList(growable: false);
      }
    }
    if (stageIndex + 1 >= model.stages.length) {
      return const <int>[];
    }
    final AnatomyStage next = model.stages[stageIndex + 1];
    if (next.positionsPerCell == 1) {
      return const <int>[];
    }

    final int residue = next.cellAt(position);
    if (residue < 0) {
      return const <int>[];
    }

    final List<int> siblings = <int>[];
    for (int k = 0; k < next.positionsPerCell; k++) {
      final int sibling = next.positionAt(residue, k);
      if (sibling == position) {
        continue;
      }
      final int cell = stage.cellAt(sibling);
      if (cell >= 0) {
        siblings.add(cell);
      }
    }
    return siblings;
  }
}
