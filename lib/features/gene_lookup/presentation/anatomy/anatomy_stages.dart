import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../domain/entities/gene_record.dart';
import '../format.dart';

/// What a base or residue is, biologically.
enum RoleKind {
  exon,
  intron,
  untranscribed,
  utr5,
  utr3,
  signalPeptide,
  coding,
  maturePeptide,
  dibasic,
  trimmed,
  startCodon,
  stopCodon,
}

/// Which end of the reading frame a cell of the transcript sits at.
///
/// Not a [Role], deliberately. A role is set per genomic position and read by
/// every page, and the first three bases of a coding sequence are already
/// spoken for: they are the front of the signal peptide, and a protein page
/// that answered "the start codon" for residue 1 would be naming the codon
/// where the reader is looking at the methionine it codes for. The frame is a
/// fact about the page that is *drawn in threes*, so it is answered from that
/// page's own block. [RoleKind.startCodon] exists only to hang a note on.
enum CodonMark { none, start, stop }

/// One base's membership of a named feature, with the feature's own size.
///
/// Carrying [lengthBp] here is what turns the tracer's worst moment —
/// "removed with intron 2 · 787 bases" — into a table lookup instead of a
/// special case at the call site.
@immutable
final class Role {
  const Role({
    required this.kind,
    required this.label,
    required this.lengthBp,
    this.index = 0,
  });

  final RoleKind kind;

  /// How the feature is named in the caption: "intron 2", "the 5' UTR",
  /// "insulin B chain", "RR site".
  final String label;

  final int lengthBp;

  /// Ordinal within the kind — which exon, which mature peptide.
  final int index;
}

// DNA is an inspection of a gene feature, not an extra page in the walk.
enum StageKind { gene, dna, mrna, protein, proprotein, maturePeptides }

/// One run of cells drawn as its own grid.
///
/// Two stages have more than one. The mature peptides have been cut apart, so
/// drawing them as a single continuous serpentine would put back the bases the
/// protease just removed; the mRNA is three regions — 5' UTR, coding sequence,
/// 3' UTR — because that division is the whole of what that page has to say.
@immutable
final class StageBlock {
  const StageBlock({
    required this.start,
    required this.count,
    this.label,
    this.caption,
    this.role,
    this.roleIndex = 0,
    this.framed = false,
    this.frame = 0,
    this.prominent = false,
  });

  final int start;
  final int count;

  /// What to write across the block, or null for a stage drawn as one piece.
  final String? label;

  /// What the block's chip says, where that is more than [label].
  ///
  /// The name is also what the tracer reads back for a base in the block —
  /// "base 5,301 · G · coding sequence" — so a count written into it would be
  /// repeated in every gloss. The chip is the one place the size belongs.
  final String? caption;

  /// What the block *is*, for the colour its name band is drawn in.
  ///
  /// Not derivable from the cells: the coding sequence's first base is also the
  /// first base of the signal peptide, so asking the run table what lives at
  /// `start` answers a more specific question than the one the band is asking.
  final RoleKind? role;

  /// Ordinal within [role], for the kinds that are drawn as a cycle of colours.
  /// It is what gives the three insulin chains three name bands rather than
  /// three copies of one.
  final int roleIndex;

  /// Whether this block is read in threes.
  ///
  /// The one flag the layout needs to groove the reading frame: a framed block
  /// gets a few extra pixels after every third cell, and its column count is
  /// held to a multiple of three so that a codon never straddles a row. Only
  /// coding sequence ever sets it — the transcript's, or a coding region opened
  /// into its DNA — which is exactly the point: the frame is visible only where
  /// translation actually happens.
  final bool framed;

  /// Where in its codon a [framed] block's first cell falls: 0 for the first
  /// base of a codon, 1 or 2 for a block that opens mid-codon. The transcript's
  /// coding sequence always opens on its start codon; an exon opened into its
  /// DNA opens wherever the intron before it cut the frame.
  final int frame;

  /// Whether this block is the one the page is *about*.
  ///
  /// Only the name band reads it, and only to decide how far its chip is lifted
  /// off the ground and how much ink its name gets. The transcript page used to
  /// answer this with [framed], which happened to be true of exactly the block
  /// it wanted; the residue pages have no reading frame to borrow, and a
  /// proprotein is no less the subject of its page for never being read in
  /// threes.
  final bool prominent;
}

/// The shortest feature worth a name on the gene page, in bases.
///
/// Under this a feature is punctuation rather than a region: the three-base
/// stop codon, the `RR`, `KR` and `RKKR` sites a protease cuts at, the stray
/// residue or two left at either end of a cut precursor. They are read off the
/// colours around them — a cut site is the seam between two chains — and a name
/// on each would put more type on the page than the runs it names, so they are
/// written only where they happen to hold their own name whole, and never
/// abbreviated to get there. Five codons, because a feature that codes for
/// fewer than five residues is a signal, not a stretch.
///
/// Measured on the feature ([StageRun.lengthBp]) and not on the run, so a
/// signal peptide split across two exons is still a 72-base signal peptide and
/// keeps its name.
const int regionFloor = 15;

/// A maximal run of consecutive cells that are all the same piece of the gene.
///
/// This is what the screen is actually made of. INS is thirteen of these, and
/// one of them — intron 2 — is 55% of the picture. Grouping is by [Role]
/// *identity*, not by kind or by label, because `_set` hands every position of
/// one feature the same object: that is what keeps intron 1 and intron 2 apart
/// without comparing strings.
@immutable
final class StageRun {
  const StageRun({
    required this.label,
    required this.kind,
    required this.start,
    required this.count,
    required this.lengthBp,
    required this.index,
    required this.feature,
    this.qualifier = '',
  });

  /// The feature's own name, from the record: 'intron 2', 'insulin B chain'.
  final String label;

  final RoleKind kind;

  /// First cell of the run, and how many cells it holds.
  final int start;
  final int count;

  /// The whole feature's length, which is not [count] when a feature is split
  /// across runs — the 5' UTR arrives in two pieces either side of intron 1,
  /// and is 59 bases in both of them.
  final int lengthBp;

  /// The feature's ordinal within its kind — which exon, which mature chain.
  /// It is what gives the three insulin chains three colours rather than one.
  final int index;

  /// Which feature this run is a piece of.
  ///
  /// Runs are maximal *consecutive* cells, so one feature can be several of
  /// them: the 5' UTR arrives in two runs either side of intron 1. Selecting it
  /// has to light both, because the caption reports the feature's 59 bases and
  /// lighting only the 42 in exon 1 would contradict the number beneath it.
  /// Two runs share a [feature] exactly when they came from one [Role].
  final int feature;

  /// The protein's own name, where its peptides are all prefixed with it.
  ///
  /// Read off the record rather than named here — 'insulin' for INS, 'Relaxin'
  /// for RLN2 — so that [labelForms] can drop it without knowing which protein
  /// it is looking at. Empty where a record's peptides share no such prefix.
  final String qualifier;

  /// The name as a label, from longest to shortest, for a space that may not
  /// fit it all.
  ///
  /// The article goes first and unconditionally: [label] is written to sit in a
  /// sentence — 'removed with the 5' UTR' — and a thing written *on* the thing
  /// it names is not in a sentence. Past that, only the name of the protein
  /// whose page this already is may go, and only for room. It never cuts into
  /// the name: 'B chain' shortened to 'B' would name nothing, and 'intron 2'
  /// shortened to 'intron' would name the wrong one of the two — which is what
  /// the length floor is for, since [qualifier] is a whole word and 'Ubiquitin'
  /// with 'Ubiquitin' taken off it is not a shorter name but no name at all.
  Iterable<String> get labelForms sync* {
    String text = label;
    if (text.toLowerCase().startsWith('the ')) {
      text = text.substring(4);
    }
    yield text;
    if (qualifier.isEmpty ||
        !text.toLowerCase().startsWith('${qualifier.toLowerCase()} ')) {
      return;
    }
    final String shorter = text.substring(qualifier.length + 1);
    if (shorter.length > 2) {
      yield shorter;
    }
  }

  /// Whether this run is a region of the gene rather than punctuation.
  bool get isRegion => lengthBp >= regionFloor;

  /// The name as it may be *written on* the run, longest to shortest.
  ///
  /// [labelForms] is the name in a sentence, and a sentence has room. A shape
  /// has only the width its own bases bought it, which on p53's third exon is
  /// about eighteen points against a thirty-eight point name. Past the prose
  /// forms the name may therefore be abbreviated, because the page abbreviates
  /// a name rather than write it anywhere but on the run it names.
  ///
  /// Only the category word is ever cut. Whatever identifies the region is kept
  /// whole at every rung — the ordinal, the chain's letter, which end of the
  /// transcript it is — so 'intron 2' may become 'int. 2' and then 'I2', and
  /// may never become 'intron'. The short forms come from [kind] rather than
  /// from reading the name, because every gene's exons are exons however its
  /// record spells its peptides; a peptide's name is the record's own and is
  /// only ever clipped, never initialled, since a first letter taken off each
  /// word of 'cystic fibrosis transmembrane conductance regulator' reads as
  /// CFTR and is not it.
  ///
  /// Punctuation keeps the prose forms and nothing else — see [regionFloor].
  /// Each rung is strictly shorter than the one before it, so a form that saves
  /// nothing is never offered.
  Iterable<String> get writtenForms sync* {
    String written = '';
    for (final String form in _forms) {
      if (form.isEmpty ||
          (written.isNotEmpty && form.length >= written.length)) {
        continue;
      }
      yield form;
      written = form;
    }
  }

  Iterable<String> get _forms sync* {
    yield* labelForms;
    if (!isRegion) {
      return;
    }
    final String name = labelForms.last;
    yield _clipped(name);
    yield _shortest(name);
  }

  /// The category word cut short: 'intron 10' is 'int. 10'.
  ///
  /// A name that ends in an ordinal is one numbered piece of a series, and the
  /// word in front of the number is the only part of it that may be cut. That
  /// is asked of the name rather than of [kind] because an exon inside an uncut
  /// coding sequence is a *coding* role carrying its exon's name — see
  /// `AnatomyModel._geneRoleAt`, which is what stopped every exon of
  /// dystrophin reading 'dystrophin'.
  String _clipped(String name) {
    final String piece = _piece(name, _clipWord);
    if (piece.isNotEmpty) {
      return piece;
    }
    return switch (kind) {
      // The space is all there is to take: "5' UTR" is already an abbreviation.
      RoleKind.utr5 || RoleKind.utr3 => name.replaceAll(' ', ''),
      RoleKind.coding => 'CDS',
      RoleKind.signalPeptide => 'sig. peptide',
      RoleKind.dibasic => name.endsWith(' site')
          ? name.substring(0, name.length - 5)
          : '',
      RoleKind.maturePeptide || RoleKind.trimmed => _clipWords(name),
      _ => '',
    };
  }

  /// The name at its shortest that still names this one region.
  String _shortest(String name) {
    final String piece = _piece(name, (String word) => word[0].toUpperCase());
    if (piece.isNotEmpty) {
      return piece.replaceAll(' ', '');
    }
    return switch (kind) {
      RoleKind.utr5 || RoleKind.utr3 => _sided(name),
      RoleKind.signalPeptide => 'SP',
      RoleKind.maturePeptide => _designator(name),
      _ => '',
    };
  }

  /// [name] as `<word> <ordinal>` with the word put through [cut], or nothing
  /// at all where the name is not one numbered piece of a series.
  ///
  /// The ordinal is never touched: 'intron 2' with its number taken off names
  /// the other one.
  static String _piece(String name, String Function(String) cut) {
    final Match? piece = _numbered.firstMatch(name);
    return piece == null ? '' : '${cut(piece.group(1)!)} ${piece.group(2)}';
  }

  /// "5' UTR" is "5'U": which end of the transcript, and the first letter of
  /// what sits there.
  static String _sided(String name) {
    final int space = name.indexOf(' ');
    return space <= 0 || space + 1 >= name.length
        ? ''
        : '${name.substring(0, space)}${name[space + 1]}';
  }

  /// 'B chain' is 'B'. A chain's letter is its name, which is why this is the
  /// one place a single character is a name at all.
  static String _designator(String name) {
    final List<String> words = name.split(' ');
    return words.length == 2 &&
            words.first.length <= 2 &&
            words.last.toLowerCase() == 'chain'
        ? words.first
        : '';
  }

  /// Every word of six letters or more cut to three and a full stop, and
  /// everything shorter — an ordinal, a chain's letter, a bracketed metal —
  /// left exactly as the record wrote it.
  static String _clipWords(String name) =>
      name.split(' ').map(_clipWord).join(' ');

  static String _clipWord(String token) {
    final List<String> parts = token.split('-');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].length < 6 || !_letters.hasMatch(parts[i])) {
        continue;
      }
      // The full stop marks the cut, and only the end of a hyphenated word
      // carries it: 'amyloid-beta' is 'amy-beta', not 'amy.-beta'.
      parts[i] = parts[i].substring(0, 3) + (i == parts.length - 1 ? '.' : '');
    }
    return parts.join('-');
  }

  static final RegExp _numbered = RegExp(r'^([A-Za-z][A-Za-z-]*) (\d+)$');
  static final RegExp _letters = RegExp(r'^[A-Za-z]+$');

  /// Ordinal within this run, 1-based, for a cell known to be inside it.
  int offsetOf(int cell) => cell - start + 1;
}

/// One state of the molecule: a flat list of cells, each owning the genomic
/// positions it was made from.
///
/// Cells are stored as parallel typed arrays rather than objects, the way
/// `HelixModel` stores its geometry — 1,431 of them are rebuilt on every layout
/// change and none of them should cost an allocation.
@immutable
final class AnatomyStage {
  const AnatomyStage({
    required this.kind,
    required this.label,
    required this.sentence,
    required this.unit,
    required this.blocks,
    required this.positions,
    required this.positionsPerCell,
    required this.letters,
    required this.cellForPosition,
    required this.geneStart,
    required this.runs,
    required this.runOfCell,
    this.realCount,
  });

  final StageKind kind;

  /// The stage's name, taken from the record's own `/product` where it has one.
  final String label;

  /// The single line under the count. Never a paragraph.
  final String sentence;

  /// 'bases' or 'residues', as a sentence or a screen reader says it.
  final String unit;

  /// The unit as a figure is set with: bp for DNA, nt for the transcript, aa
  /// for a chain of residues.
  String get shortUnit => switch (kind) {
    StageKind.gene || StageKind.dna => 'bp',
    StageKind.mrna => 'nt',
    StageKind.protein ||
    StageKind.proprotein ||
    StageKind.maturePeptides => 'aa',
  };

  final List<StageBlock> blocks;

  /// Every cell's genomic positions, concatenated. Cell `i` owns
  /// `positions[i * positionsPerCell]` through `+ positionsPerCell - 1`.
  final Int32List positions;

  /// 1 for a nucleotide stage, 3 for a residue stage.
  final int positionsPerCell;

  /// One glyph per cell — the base letter, or the residue's one-letter code.
  final String letters;

  /// `genomicPosition - geneStart` to cell index, or -1 when this stage no
  /// longer contains that base. This is the whole tracer, and the whole
  /// transition pairing: both are containment lookups, not index arithmetic.
  final Int32List cellForPosition;

  final int geneStart;

  /// The stage's cells grouped into named pieces, in order. Built once; read by
  /// the grid's colour, by the strip under it and by the caption, so all three
  /// are answering off the same table and cannot disagree.
  final List<StageRun> runs;

  /// Cell index to its entry in [runs].
  final Uint16List runOfCell;

  /// One cell per glyph, so the count on screen and the grid can never drift.
  int get count => letters.length;

  /// How long the molecule really is, where the cells are a shortened stand-in
  /// for it, and null where they are not.
  ///
  /// Only a gene whose introns arrive shortened has one. Dystrophin's page is
  /// 24,000 cells of a 2,092,329-base gene, and a badge reading 24,000 was
  /// off by 87 times on the first number a reader sees; the caption's scale
  /// note was the only place the real size appeared.
  final int? realCount;

  /// The number the page's badge reads: the molecule, not the drawing of it.
  int get shownCount => realCount ?? count;

  StageRun runAt(int cell) => runs[runOfCell[cell]];

  /// Which feature [cell] belongs to. Two cells with the same answer are pieces
  /// of one thing even when a run of something else lies between them.
  int featureAt(int cell) => runs[runOfCell[cell]].feature;

  int positionAt(int cell, [int within = 0]) =>
      positions[cell * positionsPerCell + within];

  /// The cell holding [genomicPosition], or -1 if it has been cut.
  int cellAt(int genomicPosition) {
    final int offset = genomicPosition - geneStart;
    if (offset < 0 || offset >= cellForPosition.length) {
      return -1;
    }
    return cellForPosition[offset];
  }

  int blockOf(int cell) {
    for (int b = blocks.length - 1; b >= 0; b--) {
      if (cell >= blocks[b].start) {
        return b;
      }
    }
    return 0;
  }

  /// Whether [cell] is in the first or the last codon of the block that is read
  /// in threes, or in neither.
  ///
  /// Asked of the framed block rather than of the role table: the two ends of
  /// the reading frame are where they are *because* of the frame, and a stage
  /// with no frame — the gene, the residue pages, a non-coding transcript —
  /// has no such cells and needs no special case to say so.
  ///
  /// A coding sequence shorter than two codons would have one triplet claimed
  /// by both ends. Start wins: a lone codon is where translation begins.
  ///
  /// A region's DNA can be read in threes too, and has no ends to mark: it is
  /// a stretch from anywhere in the frame, and its first and last codons are
  /// no more the start and the stop than any others.
  CodonMark codonMarkAt(int cell) {
    if (kind == StageKind.dna) {
      return CodonMark.none;
    }
    for (final StageBlock block in blocks) {
      if (!block.framed || block.count < 3) {
        continue;
      }
      final int within = cell - block.start;
      if (within < 0 || within >= block.count) {
        continue;
      }
      if (within < 3) {
        return CodonMark.start;
      }
      if (within >= block.count - 3) {
        return CodonMark.stop;
      }
      return CodonMark.none;
    }
    return CodonMark.none;
  }

  /// The three cells of the codon [cell] is read in, or empty where it is not
  /// read in threes.
  ///
  /// What a tap on the transcript means. [frameCodon] answers this for the
  /// frame's two ends, which know their own three without being asked about a
  /// cell; every other codon of the block is found the same way, from where the
  /// block opens in the frame.
  ///
  /// A region's DNA is excluded for the reason [codonMarkAt] excludes it: it is
  /// a stretch from anywhere in the frame, and it forms its codons on a groove
  /// of its own. A trailing partial codon answers with nothing, because three
  /// cells is what the answer is.
  List<int> codonCellsAt(int cell) {
    if (kind == StageKind.dna) {
      return const <int>[];
    }
    for (final StageBlock block in blocks) {
      if (!block.framed || block.count < 3) {
        continue;
      }
      final int within = cell - block.start;
      if (within < 0 || within >= block.count) {
        continue;
      }
      final int first = within - (within + block.frame) % 3;
      if (first < 0 || first + 3 > block.count) {
        return const <int>[];
      }
      return <int>[
        block.start + first,
        block.start + first + 1,
        block.start + first + 2,
      ];
    }
    return const <int>[];
  }

  /// The three cells of the frame's [mark] end, or empty where this stage has
  /// no reading frame to have ends.
  List<int> frameCodon(CodonMark mark) {
    if (mark == CodonMark.none || kind == StageKind.dna) {
      return const <int>[];
    }
    for (final StageBlock block in blocks) {
      if (!block.framed || block.count < 3) {
        continue;
      }
      final int first = mark == CodonMark.start
          ? block.start
          : block.start + block.count - 3;
      return <int>[first, first + 1, first + 2];
    }
    return const <int>[];
  }
}

/// Everything the anatomy screen needs, derived once from a parsed record.
@immutable
final class AnatomyModel {
  const AnatomyModel({
    required this.record,
    required this.stages,
    required this.transcriptRoles,
    required this.codingRoles,
  });

  final GeneRecord record;

  /// The stages this particular gene has. Never a fixed list of six: a
  /// single-exon gene has no mRNA stage, a non-coding RNA gene has one, and a
  /// protein with no annotated cleavage stops at four.
  final List<AnatomyStage> stages;

  /// `genomicPosition - record.start` to exon/intron membership.
  final List<Role> transcriptRoles;

  /// `genomicPosition - record.start` to UTR/peptide/cut-site membership, or
  /// null for a base that is not in the transcript at all.
  final List<Role?> codingRoles;

  Role? transcriptRoleAt(int genomicPosition) {
    final int offset = genomicPosition - record.start;
    if (offset < 0 || offset >= transcriptRoles.length) {
      return null;
    }
    return transcriptRoles[offset];
  }

  Role? codingRoleAt(int genomicPosition) {
    final int offset = genomicPosition - record.start;
    if (offset < 0 || offset >= codingRoles.length) {
      return null;
    }
    return codingRoles[offset];
  }

  /// The base at a genomic coordinate.
  ///
  /// `sequence` is the gene slice, already reverse-complemented by the backend
  /// for a minus-strand gene, so the index runs from the far end there.
  String baseAt(int genomicPosition) {
    final int offset = record.strand == -1
        ? record.end - genomicPosition
        : genomicPosition - record.start;
    if (offset < 0 || offset >= record.sequence.length) {
      return 'N';
    }
    return record.sequence[offset];
  }

  /// [chain] names the coding sequence of a protein that is never cut into
  /// chains — see [ProteinTarget.chain]. Ignored where the record names its
  /// own.
  static AnatomyModel derive(GeneRecord record, {String? chain}) =>
      _AnatomyDerivation(record, chain).run();
}

/// Builds the stage list and the two role tables. Pure — no I/O, no widgets, so
/// every number on the screen is testable straight off a saved fixture.
final class _AnatomyDerivation {
  _AnatomyDerivation(this.record, this.chain)
    : _length = record.lengthBp,
      _reversed = record.strand == -1;

  final GeneRecord record;
  final String? chain;
  final int _length;

  /// A minus-strand gene runs 5'->3' down *decreasing* genomic coordinates, and
  /// every ordering on this screen is transcript order, not coordinate order.
  final bool _reversed;

  late final List<Role> _transcriptRoles = List<Role>.filled(
    _length,
    const Role(
      kind: RoleKind.untranscribed,
      label: 'outside the transcript',
      lengthBp: 0,
    ),
  );

  late final List<Role?> _codingRoles = List<Role?>.filled(_length, null);

  /// Each mature peptide's name, numbered where the record names two alike.
  ///
  /// Polyubiquitin is three peptides called 'Ubiquitin', and a page of three
  /// identical chips — and a tracer line that could not say which copy a lysine
  /// was in — is what the record's own names drew.
  late final List<String> _peptideLabels = () {
    final List<String> names = <String>[
      for (int i = 0; i < record.peptides.length; i++)
        record.peptides[i].product ?? 'peptide ${i + 1}',
    ];
    final Map<String, int> seen = <String, int>{};
    return <String>[
      for (final String name in names)
        names.where((String n) => n == name).length > 1
            ? '$name ${seen[name] = (seen[name] ?? 0) + 1}'
            : name,
    ];
  }();

  /// Each mature peptide's colour ordinal: its place among the distinct
  /// products, so identical copies share a colour rather than cycling through
  /// three that say they are different things.
  late final List<int> _peptideOrdinals = () {
    final List<String> distinct = <String>[];
    return <int>[
      for (final Peptide peptide in record.peptides)
        () {
          final String name = peptide.product ?? '';
          if (!distinct.contains(name) || name.isEmpty) {
            distinct.add(name);
          }
          return distinct.lastIndexOf(name);
        }(),
    ];
  }();

  /// The role every base of an uncut coding sequence shares, or null.
  ///
  /// One role, because to the protein page it is one chain. The gene page asks
  /// a different question — which exon — and splits it: see [_exonPiece].
  Role? _wholeCds;

  /// An uncut coding sequence's bases in one exon, as a role of their own.
  final Map<Role, Role> _exonPieces = <Role, Role>{};

  /// The role a gene-page cell at [position] is drawn and selected as.
  ///
  /// The most specific role, except that a base of an uncut coding sequence is
  /// named for its exon. Every exon of dystrophin's gene page read "dystrophin"
  /// — seventy-odd times, with no way to find exon 51 — and a tap on any of
  /// them selected all 11,058 coding bases, because they were one feature.
  Role? _geneRoleAt(int position) {
    final Role? role = _roleAt(position);
    final Role? whole = _wholeCds;
    if (whole == null || !identical(role, whole)) {
      return role;
    }
    final Role exon = _transcriptRoles[position - record.start];
    return _exonPieces.putIfAbsent(exon, () {
      int bases = 0;
      for (int offset = 0; offset < _length; offset++) {
        if (identical(_codingRoles[offset], whole) &&
            identical(_transcriptRoles[offset], exon)) {
          bases++;
        }
      }
      return Role(
        kind: RoleKind.coding,
        label: exon.label,
        lengthBp: bases,
        index: exon.index,
      );
    });
  }

  /// The word every mature peptide's name begins with, where there is one.
  ///
  /// GenBank writes a peptide's product as the protein's name and then the
  /// piece: 'insulin B chain', 'Relaxin A chain'. On the page that is already
  /// this protein's, the first half is the half that can go when a label will
  /// not fit — but only when it really is a shared qualifier, which is what
  /// asking for two of them proves. A record whose peptides are three
  /// 'Ubiquitin' has a shared first word and nothing behind it, and
  /// [StageRun.labelForms] is where that is caught.
  late final String _qualifier = () {
    final List<String> leading = record.peptides
        .map((Peptide p) => (p.product ?? '').split(' ').first)
        .where((String word) => word.isNotEmpty)
        .toList();
    for (final String word in leading) {
      if (leading
              .where((String o) => o.toLowerCase() == word.toLowerCase())
              .length >
          1) {
        return word;
      }
    }
    return '';
  }();

  AnatomyModel run() {
    final List<int> transcript = _expand(_transcriptSegments());
    final List<int> cds = _expand(
      record.protein?.segments ?? const <Segment>[],
    );

    _fillTranscriptRoles();
    _fillCodingRoles(transcript, cds);

    return AnatomyModel(
      record: record,
      stages: _buildStages(transcript, cds),
      transcriptRoles: _transcriptRoles,
      codingRoles: _codingRoles,
    );
  }

  // ---------------------------------------------------------------- segments

  /// The exon structure, preferring the mRNA feature and falling back to the
  /// `exon` features. A record with neither is treated as one uninterrupted
  /// exon, which is exactly what it is.
  List<Segment> _transcriptSegments() {
    final List<Segment>? fromTranscript = record.transcript?.segments;
    if (fromTranscript != null && fromTranscript.isNotEmpty) {
      return fromTranscript;
    }
    if (record.exons.isNotEmpty) {
      return record.exons
          .map((Exon e) => Segment(start: e.start, end: e.end))
          .toList();
    }
    return <Segment>[Segment(start: record.start, end: record.end)];
  }

  /// Segment positions in transcript order.
  List<int> _expand(List<Segment> segments) {
    if (segments.isEmpty) {
      return <int>[];
    }
    final List<Segment> ordered = List<Segment>.of(segments)
      ..sort(
        (Segment a, Segment b) =>
            _reversed ? b.start.compareTo(a.start) : a.start.compareTo(b.start),
      );

    final List<int> positions = <int>[];
    for (final Segment segment in ordered) {
      if (_reversed) {
        for (int p = segment.end; p >= segment.start; p--) {
          positions.add(p);
        }
      } else {
        for (int p = segment.start; p <= segment.end; p++) {
          positions.add(p);
        }
      }
    }
    return positions;
  }

  void _set(List<Role?> table, Iterable<int> positions, Role role) {
    for (final int p in positions) {
      final int offset = p - record.start;
      if (offset >= 0 && offset < table.length) {
        table[offset] = role;
      }
    }
  }

  // ------------------------------------------------------------------- roles

  void _fillTranscriptRoles() {
    final List<Segment> segments = _transcriptSegments();
    final List<Segment> ordered = List<Segment>.of(segments)
      ..sort(
        (Segment a, Segment b) =>
            _reversed ? b.start.compareTo(a.start) : a.start.compareTo(b.start),
      );

    // The `exon` features carry a `/number`, matched to the transcript's
    // segments by coordinates rather than by list position: TP53's record
    // lists three unnumbered exons after the eight it numbers. And a number is
    // only believed when every segment's reads 1 to N in transcript order —
    // TP53's are off by one from its 22-base exon 3 on, and a gene page that
    // read "exon 3" twice and no "exon 2" was the result. Otherwise exons are
    // numbered as the transcript reads them, which is how its reference
    // sequence numbers them.
    final List<int?> numbers = <int?>[
      for (final Segment segment in ordered)
        record.exons
            .where((Exon e) => e.start == segment.start && e.end == segment.end)
            .firstOrNull
            ?.number,
    ];
    final bool numbered = <int>[
      for (int i = 0; i < numbers.length; i++)
        if (numbers[i] == i + 1) i,
    ].length == ordered.length;

    for (int i = 0; i < ordered.length; i++) {
      final Segment segment = ordered[i];
      final int? number = numbered ? numbers[i] : null;
      _set(
        _transcriptRoles,
        _range(segment),
        Role(
          kind: RoleKind.exon,
          label: 'exon ${number ?? i + 1}',
          lengthBp: segment.lengthBp,
          index: i,
        ),
      );
    }

    // A shortened intron is named at its real length, not the length drawn:
    // it is the intron being described, and the drawing is only standing in
    // for it. Trusted only when the record has one length per intron.
    final List<int>? real = record.realIntronBp;
    final bool realLengths = real != null && real.length == ordered.length - 1;

    for (int i = 0; i < ordered.length - 1; i++) {
      final int from = _reversed ? ordered[i + 1].end + 1 : ordered[i].end + 1;
      final int to = _reversed
          ? ordered[i].start - 1
          : ordered[i + 1].start - 1;
      if (to < from) {
        continue;
      }
      _set(
        _transcriptRoles,
        _range(Segment(start: from, end: to)),
        Role(
          kind: RoleKind.intron,
          label: 'intron ${i + 1}',
          lengthBp: realLengths ? real[i] : to - from + 1,
          index: i,
        ),
      );
    }
  }

  Iterable<int> _range(Segment segment) sync* {
    for (int p = segment.start; p <= segment.end; p++) {
      yield p;
    }
  }

  void _fillCodingRoles(List<int> transcript, List<int> cds) {
    if (cds.isEmpty) {
      return;
    }

    final Set<int> coding = cds.toSet();

    // UTRs are the transcript either side of the CDS *in transcript order*,
    // which is why they are found by walking the transcript rather than by
    // comparing coordinates.
    final int firstCoding = transcript.indexWhere(coding.contains);
    final int lastCoding = transcript.lastIndexWhere(coding.contains);
    if (firstCoding > 0) {
      _set(
        _codingRoles,
        transcript.take(firstCoding),
        Role(kind: RoleKind.utr5, label: "the 5' UTR", lengthBp: firstCoding),
      );
    }
    if (lastCoding >= 0 && lastCoding < transcript.length - 1) {
      _set(
        _codingRoles,
        transcript.skip(lastCoding + 1),
        Role(
          kind: RoleKind.utr3,
          label: "the 3' UTR",
          lengthBp: transcript.length - lastCoding - 1,
        ),
      );
    }

    final String translation = record.protein?.translation ?? '';
    final int residueBases = translation.length * 3;

    // An uncut protein's coding sequence *is* its chain, so it is named as one
    // and sized as the residues it codes — the stop codon is its own run. A
    // cut one keeps the generic name, which its chains overwrite everywhere.
    //
    // A precursor can lose its signal peptide and still name no chain, where
    // the record's products overlap rather than divide it — glucagon's, APP's.
    // The signal peptide takes its own bases below, so the chain is sized as
    // what is left of it: counted with the leader, a tap on proglucagon said
    // 540 bases and lit 480.
    final String? named = record.peptides.isEmpty ? chain : null;
    final Peptide? signal = record.signalPeptide;
    final int leaderBases = signal == null
        ? 0
        : _expand(signal.segments).length;
    final Role wholeCds = Role(
      kind: RoleKind.coding,
      label: named ?? 'the coding sequence',
      lengthBp: named == null ? cds.length : residueBases - leaderBases,
    );
    _set(_codingRoles, cds, wholeCds);
    _wholeCds = wholeCds;

    if (residueBases < cds.length) {
      _set(
        _codingRoles,
        cds.skip(residueBases),
        Role(
          kind: RoleKind.stopCodon,
          label: 'the stop codon',
          lengthBp: cds.length - residueBases,
        ),
      );
    }

    if (signal != null) {
      final List<int> positions = _expand(signal.segments);
      _set(
        _codingRoles,
        positions,
        Role(
          kind: RoleKind.signalPeptide,
          label: signal.product ?? 'the signal peptide',
          lengthBp: positions.length,
        ),
      );
    }

    final List<List<int>> peptides = <List<int>>[];
    for (int i = 0; i < record.peptides.length; i++) {
      final Peptide peptide = record.peptides[i];
      final List<int> positions = _expand(peptide.segments);
      peptides.add(positions);
      _set(
        _codingRoles,
        positions,
        Role(
          kind: RoleKind.maturePeptide,
          label: _peptideLabels[i],
          lengthBp: positions.length,
          index: _peptideOrdinals[i],
        ),
      );
    }

    _fillDibasicRoles(cds, peptides, translation);
    if (peptides.isNotEmpty) {
      _fillTrimmedRoles(cds.take(residueBases).toList(), wholeCds);
    }
  }

  /// The residues at either end of a cut precursor that no finished chain keeps.
  ///
  /// Everything inside the frame starts out as [wholeCds], and the signal
  /// peptide, the chains and the cut sites between them each take their share.
  /// What is left sat outside all of them: polyubiquitin's one cysteine after
  /// its third copy. Left alone it answered as the whole coding sequence —
  /// "690 bases" over a tap that lit three — so each leftover run is named for
  /// the end it hangs off and sized as itself.
  void _fillTrimmedRoles(List<int> residueBases, Role wholeCds) {
    bool isLeftover(int position) {
      final int offset = position - record.start;
      return offset >= 0 &&
          offset < _codingRoles.length &&
          identical(_codingRoles[offset], wholeCds);
    }

    int i = 0;
    while (i < residueBases.length) {
      if (!isLeftover(residueBases[i])) {
        i++;
        continue;
      }
      final int from = i;
      while (i < residueBases.length && isLeftover(residueBases[i])) {
        i++;
      }
      // Named for the side of the chains it hangs off, not for whether it is
      // the frame's first base: a leftover behind a signal peptide is still at
      // the N-terminal end of what gets cut.
      final bool afterChain = residueBases.take(from).any((int p) {
        final int offset = p - record.start;
        return _codingRoles[offset]?.kind == RoleKind.maturePeptide;
      });
      final String end = afterChain ? 'C' : 'N';
      _set(
        _codingRoles,
        residueBases.sublist(from, i),
        Role(
          kind: RoleKind.trimmed,
          label: 'the $end-terminal extension',
          lengthBp: i - from,
        ),
      );
    }
  }

  /// The protease recognition sites, found rather than named.
  ///
  /// GenBank does not annotate them: they are simply the coding bases left over
  /// between one `mat_peptide` and the next. Their label comes from the CDS
  /// translation, so a run that happens to read `KR` is called a KR site
  /// without anything in this file knowing that insulin has one.
  void _fillDibasicRoles(
    List<int> cds,
    List<List<int>> peptides,
    String translation,
  ) {
    if (peptides.length < 2) {
      return;
    }

    final Map<int, int> cdsIndex = <int, int>{};
    for (int i = 0; i < cds.length; i++) {
      cdsIndex[cds[i]] = i;
    }

    final List<int> flat = <int>[
      for (final List<int> peptide in peptides) ...peptide,
    ];
    final Set<int> covered = flat.toSet();
    final List<int> bounds = flat
        .map((int p) => cdsIndex[p] ?? -1)
        .where((int i) => i >= 0)
        .toList();
    if (bounds.isEmpty) {
      return;
    }
    bounds.sort();

    List<int> run = <int>[];
    for (int i = bounds.first; i <= bounds.last; i++) {
      final int position = cds[i];
      if (covered.contains(position)) {
        if (run.isNotEmpty) {
          _set(_codingRoles, run, _dibasicRole(run, cdsIndex, translation));
          run = <int>[];
        }
        continue;
      }
      run.add(position);
    }
    if (run.isNotEmpty) {
      _set(_codingRoles, run, _dibasicRole(run, cdsIndex, translation));
    }
  }

  Role _dibasicRole(List<int> run, Map<int, int> cdsIndex, String translation) {
    final StringBuffer residues = StringBuffer();
    int? previous;
    for (final int position in run) {
      final int? index = cdsIndex[position];
      if (index == null) {
        continue;
      }
      final int codon = index ~/ 3;
      if (codon == previous || codon >= translation.length) {
        continue;
      }
      previous = codon;
      residues.write(translation[codon]);
    }
    // Named for its residues, never 'dibasic': vasopressin's copeptin is cut
    // off at a lone `R`, and the caption lists every site by its motif.
    final String name = residues.isEmpty ? 'the cut site' : '$residues site';
    return Role(kind: RoleKind.dibasic, label: name, lengthBp: run.length);
  }

  /// ' · introns 99.3% of span, drawn shortened',
  /// or nothing at all.
  ///
  /// Read off the record rather than decided here: whether a gene had to be
  /// shortened is a fact about the payload, and eight of the ten this build
  /// ships are verbatim.
  ///
  /// It used to read 'Introns shown at 1:252 of 2.1 Mb', which was a map scale
  /// a reader had to know how to read, and not even true: 42 of dystrophin's
  /// 78 introns sit at the bake's floor and were shortened by less. What the
  /// picture hides is the proportion, so the proportion is what is said.
  String _scaleNote() {
    if (!record.isIntronCompressed) {
      return '';
    }
    final int? span = record.realSpanBp;
    if (span == null || span <= 0) {
      return ' · introns drawn shortened';
    }
    final int exonic = _transcriptSegments().fold(
      0,
      (int sum, Segment s) => sum + s.lengthBp,
    );
    final String share = ((span - exonic) * 100 / span).toStringAsFixed(1);
    return ' · introns $share% of span, drawn shortened';
  }

  // ------------------------------------------------------------------ stages

  List<AnatomyStage> _buildStages(List<int> transcript, List<int> cds) {
    final List<AnatomyStage> stages = <AnatomyStage>[];

    final List<int> gene = _expand(<Segment>[
      Segment(start: record.start, end: record.end),
    ]);
    final int exonCount = _transcriptSegments().length;

    // Figures, not a sentence: the page is read by people who know what an
    // exon is, and the counts are what they came for.
    final String exons = exonCount > 1
        ? '${grouped(exonCount)} exons · ${grouped(exonCount - 1)} '
              '${exonCount == 2 ? 'intron' : 'introns'}'
        : '1 exon';

    stages.add(
      _nucleotideStage(
        kind: StageKind.gene,
        label: 'the gene',
        // The proportion, where the record is not to scale. Dystrophin's 2.1
        // megabases at fourteen-point rows would be some two hundred screens,
        // so its introns arrive already shortened and its exons whole. That makes the picture readable and the picture's
        // *proportions* a fiction, and a fiction the reader is not told about
        // is the kind that matters. The sentence is where they are told.
        sentence: '$exons${_scaleNote()}',
        positions: gene,
        realCount: record.isIntronCompressed ? record.realSpanBp : null,
      ),
    );

    final Protein? protein = record.protein;
    final bool coding = protein != null && cds.isNotEmpty;

    // One page for the transcript, drawn as the three regions it is made of.
    //
    // This used to be two pages: 465 undifferentiated bases, and then 333 of
    // them under a sentence claiming 59 fell off the front and 73 off the back.
    // Nothing on either screen showed that subtraction, so the reader had to
    // take it on trust. Drawn as regions it *is* the picture — the ends that
    // fall away are the ends drawn quiet, and the reading frame is grooved into
    // the only stretch that is ever read in threes.
    //
    // Skipped only for a gene that is both single-exon and non-coding: there is
    // nothing to splice out and no frame to groove, and a stage that changes
    // nothing teaches nothing.
    if (exonCount > 1 || coding) {
      final int utr5 = coding ? transcript.indexWhere(cds.toSet().contains) : 0;
      final int utr3 = coding
          ? transcript.length - _lastCoding(transcript, cds) - 1
          : 0;
      // The three regions and their lengths, in the order they are read. The
      // splice needs no words: the introns are simply gone from the page.
      final String regions = <String>[
        if (utr5 > 0) '5\u2032 UTR ${grouped(utr5)}',
        'CDS ${grouped(transcript.length - utr5 - utr3)}',
        if (utr3 > 0) '3\u2032 UTR ${grouped(utr3)}',
      ].join(' · ');
      stages.add(
        _nucleotideStage(
          kind: StageKind.mrna,
          label: 'the mRNA',
          sentence: !coding
              ? '${grouped(exonCount)} exons joined · '
                    '${grouped(transcript.length)} nt'
              : '$regions nt',
          positions: transcript,
          blocks: coding
              ? _transcriptBlocks(transcript.length, utr5, utr3)
              : null,
        ),
      );
    }

    // Spelled out rather than `if (!coding)`: Dart promotes a nullable local
    // across a null check, not across a bool that happens to encode one, and
    // everything below reads `protein` unconditionally.
    if (protein == null || cds.isEmpty) {
      return stages;
    }

    final List<int> proteinPositions = cds
        .take(protein.translation.length * 3)
        .toList();
    final Peptide? proprotein = record.proprotein;
    final List<StageBlock>? precursor = proprotein != null
        ? _precursorBlocks(
            proteinPositions,
            _expand(proprotein.segments).toSet(),
            proprotein.product ?? 'proprotein',
          )
        : _afterSignal(proteinPositions);

    stages.add(
      _residueStage(
        kind: StageKind.protein,
        label: protein.product ?? 'the protein',
        // Where the precursor is drawn in pieces, the pieces and their spans;
        // where it is one piece, the record's full name for it, which the
        // header has no room for.
        sentence: precursor == null
            ? protein.product ?? 'the protein'
            : precursor
                  .map(
                    (StageBlock b) =>
                        '${b.label} ${grouped(b.start + 1)}–'
                        '${grouped(b.start + b.count)}',
                  )
                  .join(' · '),
        positions: proteinPositions,
        translation: protein.translation,
        blocks: precursor,
      ),
    );

    // Only for a proprotein this page could not draw as blocks of itself: one
    // that is not a single unbroken run of the precursor. Then the two stages
    // stay two, and the subtraction goes back to being asserted rather than
    // shown.
    if (proprotein != null && precursor == null) {
      final Peptide? signal = record.signalPeptide;
      final int signalAa = signal == null ? 0 : signal.lengthAa;
      stages.add(
        _residueStage(
          kind: StageKind.proprotein,
          label: proprotein.product ?? 'the proprotein',
          sentence: signalAa > 0
              ? '${proprotein.product ?? 'proprotein'} · signal peptide '
                    '($signalAa) removed'
              : '${proprotein.product ?? 'proprotein'} · trimmed from the '
                    'precursor',
          positions: _expand(proprotein.segments),
          translation: proprotein.translation,
        ),
      );
    }

    if (record.peptides.isNotEmpty) {
      stages.add(_maturePeptideStage());
    }

    return stages;
  }

  /// The precursor split where its signal peptide ends, for a record that
  /// annotates one but no proprotein.
  ///
  /// Insulin's record names proinsulin, so its page was the only one that
  /// showed the leader coming off: lysozyme's 18 residues, growth hormone's 26,
  /// sat unmarked in one grid and were simply gone on the next page. What the
  /// signal peptide leaves is the proprotein by definition, so it is drawn the
  /// same way. It is named for the one mature chain it is exactly, where there
  /// is one — 'lysozyme C' — and 'proprotein' where more cuts are still to come.
  List<StageBlock>? _afterSignal(List<int> positions) {
    final Peptide? signal = record.signalPeptide;
    if (signal == null) {
      return null;
    }
    final Set<int> kept = positions.toSet()
      ..removeAll(_expand(signal.segments));
    String label = 'proprotein';
    if (record.peptides.length == 1) {
      final Peptide only = record.peptides.single;
      final Set<int> chain = _expand(only.segments).toSet();
      if (chain.length == kept.length && chain.containsAll(kept)) {
        label = only.product ?? label;
      }
    }
    return _precursorBlocks(positions, kept, label);
  }

  /// The precursor drawn as the pieces the next cut divides it into, or null
  /// for a proprotein that cannot be drawn that way.
  ///
  /// This is what merged two pages into one. They differed by twenty-four
  /// residues off the front, and neither of them showed that: the reader met
  /// 110 squares, then 86, under a sentence claiming the difference — the same
  /// thing that was wrong with the two transcript pages before them. Drawn as
  /// blocks it *is* the picture, and the swipe that follows removes the leader
  /// in front of the reader instead of between two pages.
  ///
  /// Null unless the surviving residues are one unbroken run, because anything
  /// else is not a leader and a trailer: a proprotein assembled from scattered
  /// pieces of its precursor would need a block per piece, and a page of eight
  /// named fragments teaches less than the two stages it replaced. Null too
  /// when nothing is cut at all, where the proprotein page was only ever a
  /// second copy of this one.
  List<StageBlock>? _precursorBlocks(
    List<int> positions,
    Set<int> kept,
    String keptLabel,
  ) {
    final int residues = positions.length ~/ 3;
    if (residues == 0) {
      return null;
    }

    int first = -1;
    int last = -1;
    for (int r = 0; r < residues; r++) {
      if (!kept.contains(positions[r * 3])) {
        continue;
      }
      if (first < 0) {
        first = r;
      } else if (r != last + 1) {
        // A gap inside the proprotein: not a leader and a trailer.
        return null;
      }
      last = r;
    }
    if (first < 0 || (first == 0 && last == residues - 1)) {
      return null;
    }

    final Peptide? signal = record.signalPeptide;
    return <StageBlock>[
      if (first > 0)
        StageBlock(
          start: 0,
          count: first,
          caption: '${signal == null ? 'propeptide' : signal.product ?? 'signal peptide'}'
              ' \u00b7 ${grouped(first)} aa',
          // No article: this is written *on* the thing it names, and a thing
          // labelled on itself is not in a sentence. Same rule as the
          // transcript's '5\u2032 UTR'.
          //
          // 'propeptide' is what a leader with no `sig_peptide` behind it is
          // called, which is the honest name for residues the record says are
          // cut without saying what they were.
          label: signal == null
              ? 'propeptide'
              : signal.product ?? 'signal peptide',
          role: RoleKind.signalPeptide,
        ),
      StageBlock(
        start: first,
        count: last - first + 1,
        label: keptLabel,
        caption: '$keptLabel \u00b7 ${grouped(last - first + 1)} aa',
        // What it is on this page is the part that survives the next cut, and
        // [RoleKind.coding] is the palette's colour for exactly that. There is
        // no proprotein role because nothing but this band would ever ask for
        // one.
        role: RoleKind.coding,
        prominent: true,
      ),
      if (last < residues - 1)
        StageBlock(
          start: last + 1,
          count: residues - 1 - last,
          label: 'propeptide',
          caption: 'propeptide \u00b7 ${grouped(residues - 1 - last)} aa',
          role: RoleKind.signalPeptide,
        ),
    ];
  }

  int _lastCoding(List<int> transcript, List<int> cds) {
    final Set<int> coding = cds.toSet();
    return transcript.lastIndexWhere(coding.contains);
  }

  AnatomyStage _nucleotideStage({
    required StageKind kind,
    required String label,
    required String sentence,
    required List<int> positions,
    List<StageBlock>? blocks,
    int? realCount,
  }) {
    final StringBuffer letters = StringBuffer();
    for (final int position in positions) {
      letters.write(_baseAt(position));
    }
    return _assemble(
      kind: kind,
      label: label,
      sentence: sentence,
      unit: 'bases',
      positions: positions,
      positionsPerCell: 1,
      letters: letters.toString(),
      blocks:
          blocks ?? <StageBlock>[StageBlock(start: 0, count: positions.length)],
      realCount: realCount,
    );
  }

  /// The transcript's three regions, in transcript order.
  ///
  /// The coding sequence is `transcript[utr5 .. length - utr3 - 1]` by
  /// construction — [_fillCodingRoles] *defines* the UTRs as everything before
  /// the first coding base and everything after the last — so three blocks
  /// always suffice and the middle one is always contiguous.
  ///
  /// An end with no UTR yields an empty block rather than a shorter list, so
  /// the coding sequence is block 1 for every gene and nothing downstream has
  /// to count. The layout gives an empty block no rows and no gap.
  List<StageBlock> _transcriptBlocks(int length, int utr5, int utr3) {
    final int coding = length - utr5 - utr3;
    return <StageBlock>[
      StageBlock(
        start: 0,
        count: utr5,
        label: '5\u2032 UTR',
        caption: '5\u2032 UTR \u00b7 ${grouped(utr5)} nt',
        role: RoleKind.utr5,
      ),
      StageBlock(
        start: utr5,
        count: coding,
        label: 'coding sequence',
        caption: 'CDS \u00b7 ${grouped(coding)} nt',
        role: RoleKind.coding,
        framed: true,
      ),
      StageBlock(
        start: utr5 + coding,
        count: utr3,
        label: '3\u2032 UTR',
        caption: '3\u2032 UTR \u00b7 ${grouped(utr3)} nt',
        role: RoleKind.utr3,
      ),
    ];
  }

  AnatomyStage _residueStage({
    required StageKind kind,
    required String label,
    required String sentence,
    required List<int> positions,
    required String translation,
    List<StageBlock>? blocks,
  }) {
    final int residues = positions.length ~/ 3;
    return _assemble(
      kind: kind,
      label: label,
      sentence: sentence,
      unit: 'residues',
      positions: positions.take(residues * 3).toList(),
      positionsPerCell: 3,
      letters: _padTranslation(translation, residues),
      blocks: blocks ?? <StageBlock>[StageBlock(start: 0, count: residues)],
    );
  }

  AnatomyStage _maturePeptideStage() {
    final List<int> positions = <int>[];
    final List<StageBlock> blocks = <StageBlock>[];
    final StringBuffer letters = StringBuffer();

    for (int i = 0; i < record.peptides.length; i++) {
      final Peptide peptide = record.peptides[i];
      final List<int> own = _expand(peptide.segments);
      final int residues = own.length ~/ 3;
      blocks.add(
        StageBlock(
          start: letters.length,
          count: residues,
          label: _peptideLabels[i],
          caption: '${_peptideLabels[i]} \u00b7 ${grouped(residues)} aa',
          // These names have been in the model since the page was written and
          // have never been drawn: the fitted layout had no room reserved for a
          // band, so three chains arrived anonymous. They are the answer the
          // whole walk is heading for, and they are worth 32 points each.
          role: RoleKind.maturePeptide,
          roleIndex: _peptideOrdinals[i],
          prominent: true,
        ),
      );
      positions.addAll(own.take(residues * 3));
      letters.write(_padTranslation(peptide.translation, residues));
    }

    // Each chain with its length, in the order the precursor holds them, and
    // the motifs it is cut at. A run of identical products is one entry.
    final List<String> chains = <String>[];
    for (int i = 0; i < record.peptides.length;) {
      final String? product = record.peptides[i].product;
      int j = i;
      while (j + 1 < record.peptides.length &&
          product != null &&
          record.peptides[j + 1].product == product &&
          blocks[j + 1].count == blocks[i].count) {
        j++;
      }
      final String name = _shortName(product ?? 'peptide ${i + 1}');
      chains.add(
        j > i
            ? '${j - i + 1} \u00d7 $name (${grouped(blocks[i].count)})'
            : '$name (${grouped(blocks[i].count)})',
      );
      i = j + 1;
    }
    final List<String> motifs = <String>[
      for (final Role site in _cutSitesInOrder())
        site.label.endsWith(' site')
            ? site.label.substring(0, site.label.length - 5)
            : 'cut',
    ];
    return _assemble(
      kind: StageKind.maturePeptides,
      label: record.peptides.length == 1
          ? (record.peptides.first.product ?? 'the mature peptide')
          : 'mature peptides',
      sentence:
          '${chains.join(' · ')}'
          '${motifs.isEmpty ? '' : ' · cut at ${motifs.join(', ')}'}',
      unit: 'residues',
      positions: positions,
      positionsPerCell: 3,
      letters: letters.toString(),
      blocks: blocks,
    );
  }

  /// The cut sites, in the order the precursor is read.
  List<Role> _cutSitesInOrder() {
    final List<Role> seen = <Role>[];
    for (final int position in _expand(
      record.protein?.segments ?? const <Segment>[],
    )) {
      final Role? role = _codingRoles[position - record.start];
      if (role != null &&
          role.kind == RoleKind.dibasic &&
          !seen.any((Role r) => identical(r, role))) {
        seen.add(role);
      }
    }
    return seen;
  }

  /// A peptide's name as a caption lists it: without the article, and without
  /// the protein's own name where every chain carries it — 'B chain' on
  /// insulin's page — so long as something is left to name.
  String _shortName(String name) {
    String text = name.toLowerCase().startsWith('the ')
        ? name.substring(4)
        : name;
    if (_qualifier.isNotEmpty &&
        text.toLowerCase().startsWith('${_qualifier.toLowerCase()} ') &&
        text.length - _qualifier.length - 1 > 2) {
      text = text.substring(_qualifier.length + 1);
    }
    return text;
  }

  /// A `/translation` should be exactly one letter per codon, but a partial CDS
  /// (`<137..193`) can disagree. Trust the coordinates and mark the surplus
  /// unknown rather than dropping cells the tracer might be pointing at.
  String _padTranslation(String translation, int residues) {
    if (translation.length >= residues) {
      return translation.substring(0, residues);
    }
    return translation + 'X' * (residues - translation.length);
  }

  String _baseAt(int position) {
    final int offset = _reversed
        ? record.end - position
        : position - record.start;
    if (offset < 0 || offset >= record.sequence.length) {
      return 'N';
    }
    return record.sequence[offset];
  }

  AnatomyStage _assemble({
    required StageKind kind,
    required String label,
    required String sentence,
    required String unit,
    required List<int> positions,
    required int positionsPerCell,
    required String letters,
    required List<StageBlock> blocks,
    int? realCount,
  }) {
    final Int32List flat = Int32List.fromList(positions);
    final Int32List index = Int32List(_length)..fillRange(0, _length, -1);
    for (int cell = 0; cell < letters.length; cell++) {
      for (int k = 0; k < positionsPerCell; k++) {
        final int offset = flat[cell * positionsPerCell + k] - record.start;
        if (offset >= 0 && offset < _length) {
          index[offset] = cell;
        }
      }
    }

    final List<StageRun> runs = <StageRun>[];
    final Uint16List runOfCell = Uint16List(letters.length);
    // Role object to feature id, by identity for the same reason the run break
    // below is by identity: one object per feature, so a feature split across
    // two runs is recognised as one thing and two introns are not.
    final List<Role?> features = <Role?>[];
    Role? open;
    for (int cell = 0; cell < letters.length; cell++) {
      final int position = flat[cell * positionsPerCell];
      final Role? role = kind == StageKind.gene
          ? _geneRoleAt(position)
          : _roleAt(position);
      // Identity, not equality: one Role object per feature, so two introns are
      // two runs even though both are `RoleKind.intron`.
      if (runs.isEmpty || !identical(role, open)) {
        int feature = -1;
        for (int f = 0; f < features.length; f++) {
          if (identical(features[f], role)) {
            feature = f;
            break;
          }
        }
        if (feature < 0) {
          feature = features.length;
          features.add(role);
        }
        runs.add(
          StageRun(
            label: role?.label ?? 'outside the transcript',
            kind: role?.kind ?? RoleKind.untranscribed,
            start: cell,
            count: 0,
            lengthBp: role?.lengthBp ?? 0,
            index: role?.index ?? 0,
            feature: feature,
            qualifier: _qualifier,
          ),
        );
        open = role;
      }
      runOfCell[cell] = runs.length - 1;
    }
    for (int i = 0; i < runs.length; i++) {
      final int end = i + 1 < runs.length ? runs[i + 1].start : letters.length;
      runs[i] = StageRun(
        label: runs[i].label,
        kind: runs[i].kind,
        start: runs[i].start,
        count: end - runs[i].start,
        lengthBp: runs[i].lengthBp,
        index: runs[i].index,
        feature: runs[i].feature,
        qualifier: runs[i].qualifier,
      );
    }

    return AnatomyStage(
      kind: kind,
      label: label,
      sentence: sentence,
      unit: unit,
      blocks: blocks,
      positions: flat,
      positionsPerCell: positionsPerCell,
      letters: letters,
      cellForPosition: index,
      geneStart: record.start,
      runs: runs,
      runOfCell: runOfCell,
      realCount: realCount,
    );
  }

  /// The most specific thing true about a base: what it codes for if it codes
  /// for anything, and otherwise whether it is transcribed at all.
  Role? _roleAt(int position) {
    final int offset = position - record.start;
    if (offset < 0 || offset >= _length) {
      return null;
    }
    return _codingRoles[offset] ?? _transcriptRoles[offset];
  }
}
