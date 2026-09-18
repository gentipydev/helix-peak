import 'package:flutter/foundation.dart';

import '../../../../core/biology/amino_acids.dart';
import '../format.dart';
import 'anatomy_stages.dart';

/// Where a base or residue of one gene is, in the coordinates a reader already
/// uses: coding-DNA numbering, codons, precursor residues, exons.
///
/// Pure, and derived from the stages the walk already draws — the transcript's
/// three blocks are the coding-DNA reference, the protein page's cells are the
/// precursor's residues — so it can never number a thing the pages do not show.
/// Read by the ruler, the tracer's lines and facts, and a region opened into
/// its DNA.
@immutable
final class AnatomyAddress {
  AnatomyAddress._(this.model)
    : _transcript = model.stages
          .where((AnatomyStage s) => s.kind == StageKind.mrna)
          .firstOrNull,
      _protein = model.stages
          .where((AnatomyStage s) => s.kind == StageKind.protein)
          .firstOrNull;

  static final Expando<AnatomyAddress> _cache = Expando<AnatomyAddress>();

  /// The address book for [model], built once.
  static AnatomyAddress of(AnatomyModel model) =>
      _cache[model] ??= AnatomyAddress._(model);

  final AnatomyModel model;
  final AnatomyStage? _transcript;
  final AnatomyStage? _protein;

  /// Whether the transcript carries a reading frame to number against.
  bool get coding =>
      _transcript != null &&
      _transcript.blocks.length == 3 &&
      _transcript.blocks[1].framed;

  int get _utr5 => coding ? _transcript!.blocks[0].count : 0;
  int get _cds => coding ? _transcript!.blocks[1].count : 0;

  /// The base's place in the coding-DNA reference, or null for a base the
  /// transcript does not hold (an intron, the flanks).
  ///
  /// `c.1` is the A of the start codon; the 5′ UTR counts back from it
  /// (`c.−1`), and the 3′ UTR counts on after the stop (`c.*1`).
  String? cOf(int position) {
    final AnatomyStage? transcript = _transcript;
    if (!coding || transcript == null) {
      return null;
    }
    final int cell = transcript.cellAt(position);
    if (cell < 0) {
      return null;
    }
    if (cell < _utr5) {
      return 'c.−${_utr5 - cell}';
    }
    if (cell < _utr5 + _cds) {
      return 'c.${grouped(cell - _utr5 + 1)}';
    }
    return 'c.*${grouped(cell - _utr5 - _cds + 1)}';
  }

  /// The base's offset into the coding sequence, 0-based, or null outside it.
  int? cdsOffsetOf(int position) {
    final AnatomyStage? transcript = _transcript;
    if (!coding || transcript == null) {
      return null;
    }
    final int within = transcript.cellAt(position) - _utr5;
    return within >= 0 && within < _cds ? within : null;
  }

  /// The 1-based codon a coding base is in, or null.
  int? codonOf(int position) {
    final int? offset = cdsOffsetOf(position);
    return offset == null ? null : offset ~/ 3 + 1;
  }

  /// The three letters of codon [codon], as the transcript spells them.
  String? tripletOf(int codon) {
    final AnatomyStage? transcript = _transcript;
    final int start = _utr5 + (codon - 1) * 3;
    if (transcript == null || codon < 1 || start + 3 > _utr5 + _cds) {
      return null;
    }
    return transcript.letters.substring(start, start + 3);
  }

  /// The c. span of codon [codon]: `c.73–75`.
  String cSpanOf(int codon) =>
      'c.${grouped((codon - 1) * 3 + 1)}–${grouped(codon * 3)}';

  /// The precursor residue codon [codon] codes for, or null for the stop.
  int? residueOfCodon(int codon) {
    final AnatomyStage? protein = _protein;
    return protein != null && codon >= 1 && codon <= protein.count
        ? codon
        : null;
  }

  /// Residue [number] of the precursor as the field cites it: `Ala25`.
  String? residueName(int number) {
    final AnatomyStage? protein = _protein;
    if (protein == null || number < 1 || number > protein.count) {
      return null;
    }
    return '${AminoAcids.abbreviationOf(protein.letters[number - 1])}$number';
  }

  /// The precursor residue number a residue-page cell stands for.
  int? precursorNumberOf(AnatomyStage stage, int cell) {
    final AnatomyStage? protein = _protein;
    if (protein == null || stage.positionsPerCell != 3) {
      return null;
    }
    final int found = protein.cellAt(stage.positionAt(cell));
    return found < 0 ? null : found + 1;
  }

  /// The exon a base lies in, by its number in the record, or null.
  int? exonOf(int position) {
    final Role? role = model.transcriptRoleAt(position);
    return role?.kind == RoleKind.exon
        ? int.tryParse(role!.label.split(' ').last)
        : null;
  }

  /// The run of the gene page that [role] is drawn as, or null.
  StageRun? _runOf(Role role) {
    final AnatomyStage gene = model.stages.first;
    for (final StageRun run in gene.runs) {
      if (run.label == role.label && run.kind == role.kind) {
        return run;
      }
    }
    return null;
  }

  /// An intron's two splice-site dinucleotides and its phase: `GT…AG · phase 1`.
  ///
  /// The phase is how far into a codon the intron falls: 0 between codons, 1
  /// after a codon's first base, 2 after its second. An intron outside the
  /// coding sequence has none, and says which untranslated end it is in.
  String? intronFacts(Role intron) {
    if (intron.kind != RoleKind.intron) {
      return null;
    }
    final AnatomyStage gene = model.stages.first;
    final StageRun? run = _runOf(intron);
    if (run == null || run.count < 4) {
      return null;
    }
    final String donor = gene.letters.substring(run.start, run.start + 2);
    final String acceptor = gene.letters.substring(
      run.start + run.count - 2,
      run.start + run.count,
    );
    final String sites = '$donor…$acceptor';
    if (!coding || run.start == 0) {
      return sites;
    }
    // The last exonic base before the intron, in the transcript.
    final AnatomyStage transcript = _transcript!;
    final int before = transcript.cellAt(gene.positionAt(run.start - 1));
    if (before < 0) {
      return sites;
    }
    final int upstream = before - _utr5 + 1;
    if (upstream <= 0) {
      return '$sites · in the 5′ UTR';
    }
    if (upstream >= _cds) {
      return '$sites · in the 3′ UTR';
    }
    return '$sites · phase ${upstream % 3}';
  }

  /// The coding stretch an exon carries, `CDS c.1–150`, or what it holds
  /// instead.
  String? exonFacts(int exon) {
    final AnatomyStage gene = model.stages.first;
    final AnatomyStage? transcript = _transcript;
    if (transcript == null) {
      return null;
    }
    int? first;
    int? last;
    bool utr5 = false;
    bool utr3 = false;
    for (int cell = 0; cell < gene.count; cell++) {
      final int position = gene.positionAt(cell);
      if (exonOf(position) != exon) {
        continue;
      }
      final int? offset = cdsOffsetOf(position);
      if (offset == null) {
        final int at = transcript.cellAt(position);
        if (at >= 0 && at < _utr5) {
          utr5 = true;
        } else if (at >= _utr5 + _cds) {
          utr3 = true;
        }
        continue;
      }
      first = first == null || offset < first ? offset : first;
      last = last == null || offset > last ? offset : last;
    }
    final List<String> parts = <String>[
      if (utr5) '5′ UTR',
      if (first != null && last != null)
        'CDS c.${grouped(first + 1)}–${grouped(last + 1)}',
      if (utr3) '3′ UTR',
    ];
    return parts.isEmpty ? null : parts.join(' + ');
  }

  /// The start codon in its Kozak context, −6 to +4: `GCCACC ATG G`.
  String? kozak() {
    final AnatomyStage? transcript = _transcript;
    if (!coding || transcript == null || _cds < 4) {
      return null;
    }
    final int from = (_utr5 - 6).clamp(0, _utr5);
    final String before = transcript.letters.substring(from, _utr5);
    final String start = transcript.letters.substring(_utr5, _utr5 + 3);
    final String after = transcript.letters.substring(_utr5 + 3, _utr5 + 4);
    return 'Kozak $before $start $after';
  }

  /// The polyadenylation signal nearest the end of the 3′ UTR, if the record's
  /// last 50 bases hold one: `AATAAA at c.*54`.
  String? polyadenylationSignal() {
    final AnatomyStage? transcript = _transcript;
    if (!coding || transcript == null) {
      return null;
    }
    final int end = transcript.count;
    final int utr3Start = _utr5 + _cds;
    final int from = (end - 50).clamp(utr3Start, end);
    final String tail = transcript.letters.substring(from, end);
    int best = -1;
    String? hexamer;
    for (final String motif in <String>['AATAAA', 'ATTAAA']) {
      final int at = tail.lastIndexOf(motif);
      if (at > best) {
        best = at;
        hexamer = motif;
      }
    }
    if (hexamer == null || best < 0) {
      return null;
    }
    return '$hexamer at c.*${grouped(from + best - utr3Start + 1)}';
  }
}
