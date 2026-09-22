import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/biology/genetic_code.dart';
import 'gene_impact.dart';
import 'gene_record.dart';
import 'protein_target.dart';

/// Colors/grouping never replace the verbatim submitted classification.
/// Conflicting and unfamiliar classifications must never become pathogenic.
///
/// Declared in the order a reader scans them: the classified ends first, then
/// what is still open, then what does not sit on that axis at all.
enum ClinVarGroup {
  pathogenic('Pathogenic / likely pathogenic', 'P/LP'),
  conflicting('Conflicting classifications', 'Conflicting'),
  uncertain('Uncertain significance', 'VUS'),
  benign('Benign / likely benign', 'B/LB'),
  other('Other classifications', 'Other');

  const ClinVarGroup(this.label, this.short);
  final String label;

  /// The field's own abbreviation, for chips and counts.
  final String short;

  static const Set<String> _pathogenicTerms = <String>{
    'pathogenic',
    'likely pathogenic',
    'pathogenic, low penetrance',
    'likely pathogenic, low penetrance',
  };
  static const Set<String> _benignTerms = <String>{'benign', 'likely benign'};

  /// Reads ClinVar's aggregate wording one term at a time.
  ///
  /// A record's classification joins its submissions' terms with `/`:
  /// `Pathogenic/Likely risk allele` is pathogenic for one condition and a risk
  /// allele for another. Terms off the Mendelian axis follow a `;`: CFTR's
  /// `Pathogenic; drug response`. The Mendelian terms decide the group; risk
  /// allele, association, protective and drug response neither promote nor
  /// demote a record. Pathogenic and benign terms together are a conflict,
  /// whatever ClinVar's own wording says, and anything unfamiliar is [other] —
  /// never [pathogenic].
  static ClinVarGroup of(String text) => _read[text] ??= _classify(text);

  /// Each wording read once: a snapshot repeats a few dozen of them across
  /// thousands of records, and every list, count and mark asks again.
  static final Map<String, ClinVarGroup> _read = <String, ClinVarGroup>{};

  static final RegExp _joins = RegExp('[/;]');

  static ClinVarGroup _classify(String text) {
    final List<String> terms = <String>[
      for (final String term in text.toLowerCase().split(_joins)) term.trim(),
    ];
    if (terms.any((String term) => term.startsWith('conflicting'))) {
      return conflicting;
    }
    final bool pathogenicTerm = terms.any(_pathogenicTerms.contains);
    final bool benignTerm = terms.any(_benignTerms.contains);
    return switch ((pathogenicTerm, benignTerm)) {
      (true, true) => conflicting,
      (true, false) => pathogenic,
      (false, true) => benign,
      _ when terms.contains('uncertain significance') => uncertain,
      _ => other,
    };
  }

  /// Most severe first: what a single mark stands for when a residue or a base
  /// carries several records. Other outranks benign because it says nothing
  /// either way, and a benign mark over it would claim more than the records do.
  static const List<ClinVarGroup> bySeverity = <ClinVarGroup>[
    pathogenic,
    conflicting,
    uncertain,
    other,
    benign,
  ];

  static ClinVarGroup mostSevere(Iterable<ClinVarGroup> groups) => groups
      .reduce((a, b) => bySeverity.indexOf(a) <= bySeverity.indexOf(b) ? a : b);
}

/// A condition as ClinVar identifies it: its name and, where ClinVar has mapped
/// it, its MedGen concept, OMIM entry, symbol and MONDO class.
///
/// Identifiers only. The definitions that travel with these concepts are not
/// taken: MedGen gives type 2 diabetes the WFS1 GeneReviews summary.
@immutable
final class ClinVarTrait {
  const ClinVarTrait({
    required this.name,
    this.medgen,
    this.symbol,
    this.omim,
    this.mondo,
  });

  factory ClinVarTrait.of(String name, Map<String, dynamic>? ids) =>
      ClinVarTrait(
        name: name,
        medgen: ids?['medgen'] as String?,
        symbol: ids?['symbol'] as String?,
        omim: ids?['omim'] as String?,
        mondo: ids?['mondo'] as String?,
      );

  final String name;
  final String? medgen;

  /// The symbol OMIM gives the condition's own entry, `MODY10`, else
  /// ClinVar's preferred one.
  final String? symbol;

  /// A phenotype entry, `613370`, or a phenotypic series, `PS606176`.
  final String? omim;
  final String? mondo;

  /// ClinVar's words for a submission that named no condition.
  bool get placeholder => name == 'not provided' || name == 'not specified';

  /// How the field cites the entry: `MIM 613370`.
  String? get mim => omim == null ? null : 'MIM $omim';
}

@immutable
final class ClinVarCondition {
  const ClinVarCondition({
    required this.accession,
    required this.names,
    required this.traits,
    required this.classification,
    required this.reviewStatus,
    this.lastEvaluated,
  });
  final String accession;
  final List<String> names;

  /// [names], each with the identifiers ClinVar gives it.
  final List<ClinVarTrait> traits;
  final String classification;
  final String reviewStatus;
  final String? lastEvaluated;

  /// [identifiers] is the snapshot's `traits`: condition name to identifiers.
  factory ClinVarCondition.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> identifiers = const <String, dynamic>{},
  }) {
    final List<String> names = List<String>.unmodifiable(
      (json['names'] as List<dynamic>).cast<String>(),
    );
    return ClinVarCondition(
      accession: json['accession'] as String,
      names: names,
      traits: List<ClinVarTrait>.unmodifiable(<ClinVarTrait>[
        for (final String name in names)
          ClinVarTrait.of(name, identifiers[name] as Map<String, dynamic>?),
      ]),
      classification: json['classification'] as String,
      reviewStatus: json['review_status'] as String,
      lastEvaluated: json['last_evaluated'] as String?,
    );
  }
}

@immutable
final class ClinVarVariant {
  const ClinVarVariant({
    required this.id,
    required this.accession,
    required this.name,
    required this.position,
    required this.genomic,
    required this.ref,
    required this.alt,
    required this.classification,
    required this.reviewStatus,
    required this.conditions,
    required this.collectionMethods,
    this.residue,
    this.proteinChange,
    this.codingChange,
    this.consequence,
    this.lastEvaluated,
    this.lastUpdated,
  });
  final String id;
  final String accession;
  final String name;
  final int position;
  final int genomic;

  /// Transcript-strand alleles, just like the drawn DNA and AVI alternatives.
  final String ref;
  final String alt;
  final int? residue;
  final String? proteinChange;
  final String? codingChange;
  final String? consequence;
  final String classification;
  final String reviewStatus;
  final String? lastEvaluated;
  final String? lastUpdated;
  final List<ClinVarCondition> conditions;
  final List<String> collectionMethods;

  ClinVarGroup get group => ClinVarGroup.of(classification);
  String get label => [
    ?codingChange,
    ?proteinChange,
    if (codingChange == null) '$ref→$alt · GRCh38 $genomic',
  ].join(' · ');
  String get url => 'https://www.ncbi.nlm.nih.gov/clinvar/variation/$id/';

  static final RegExp _protein = RegExp(r'^p\.([A-Z])(\d+)([A-Z*=])$');

  /// The alternative amino acid of a missense record: `Y` for `p.C96Y`.
  String? get altResidue {
    if (consequence != 'missense') {
      return null;
    }
    final String? alt = _protein.firstMatch(proteinChange ?? '')?.group(3);
    return alt == null || alt == '*' || alt == '=' ? null : alt;
  }

  /// The residue the record replaces, `C` for `p.C96Y`.
  String? get wildtypeResidue =>
      _protein.firstMatch(proteinChange ?? '')?.group(1);

  /// The transcript-level change as the field writes it — `c.287G>A`,
  /// `c.188-31G>A`, `c.*59A>G` — read from the record's own name where the
  /// snapshot carries no coding change, as it does for every intronic or UTR
  /// record.
  String get transcriptChange {
    if (codingChange case final String change) {
      return change;
    }
    final int colon = name.indexOf(':c.');
    if (colon < 0) {
      return '$ref>$alt';
    }
    final String tail = name.substring(colon + 1);
    final int space = tail.indexOf(' ');
    return space < 0 ? tail : tail.substring(0, space);
  }

  /// How the record is cited in a list: `Cys96Tyr`, `Cys43Ter`, `Cys31=`,
  /// `Met1Val`, and the transcript change where nothing in the protein moves.
  String get shortLabel {
    final RegExpMatch? match = _protein.firstMatch(proteinChange ?? '');
    if (match == null) {
      return transcriptChange;
    }
    final String to = match.group(3)!;
    return '${AminoAcids.abbreviationOf(match.group(1)!)}${match.group(2)}'
        '${switch (to) {
          '*' => 'Ter',
          '=' => '=',
          _ => AminoAcids.abbreviationOf(to),
        }}';
  }

  /// NCBI's review stars, from the aggregate review status.
  int get stars => switch (reviewStatus.toLowerCase()) {
    'practice guideline' => 4,
    'reviewed by expert panel' => 3,
    'criteria provided, multiple submitters, no conflicts' ||
    'criteria provided, multiple submitters' => 2,
    'criteria provided, single submitter' ||
    'criteria provided, conflicting classifications' ||
    'criteria provided, conflicting interpretations' => 1,
    _ => 0,
  };

  /// Each classification a condition was given, as ClinVar words it, with the
  /// conditions it was given for: most severe first, and under each the named
  /// conditions before ClinVar's placeholders.
  ///
  /// This is what a conflicting record is split between, and which condition
  /// each side is about — the thing its own label hides. `Likely pathogenic`
  /// for four named diabetes forms and `Pathogenic` for "not provided" is what
  /// Met1Val's `Pathogenic/Likely pathogenic` is made of.
  List<(String, List<ClinVarTrait>)> get conditionsByClass {
    final Map<String, List<ClinVarTrait>> byClass =
        <String, List<ClinVarTrait>>{};
    for (final ClinVarCondition condition in conditions) {
      final List<ClinVarTrait> into = byClass[condition.classification] ??=
          <ClinVarTrait>[];
      for (final ClinVarTrait trait in condition.traits) {
        if (!into.any((ClinVarTrait t) => t.name == trait.name)) {
          into.add(trait);
        }
      }
    }
    // Within a group, the field's own order: the definite call before the
    // likely one on the pathogenic side, and after it on the benign side.
    const List<String> terms = <String>[
      'pathogenic',
      'pathogenic/likely pathogenic',
      'likely pathogenic',
      'uncertain significance',
      'likely benign',
      'benign/likely benign',
      'benign',
    ];
    int term(String text) {
      final int at = terms.indexOf(text.toLowerCase());
      return at < 0 ? terms.length : at;
    }

    final List<String> order = byClass.keys.toList()
      ..sort((String a, String b) {
        final int severity = ClinVarGroup.bySeverity
            .indexOf(ClinVarGroup.of(a))
            .compareTo(ClinVarGroup.bySeverity.indexOf(ClinVarGroup.of(b)));
        if (severity != 0) {
          return severity;
        }
        final int known = term(a).compareTo(term(b));
        return known != 0 ? known : a.compareTo(b);
      });
    return <(String, List<ClinVarTrait>)>[
      for (final String text in order)
        (
          text,
          List<ClinVarTrait>.unmodifiable(<ClinVarTrait>[
            ...byClass[text]!.where((ClinVarTrait t) => !t.placeholder),
            ...byClass[text]!.where((ClinVarTrait t) => t.placeholder),
          ]),
        ),
    ];
  }

  /// Match this alternative, never the strongest alternative at the same base.
  double? aviScore(BaseImpact? impact) {
    if (impact == null ||
        impact.estimated ||
        impact.position != position ||
        impact.genomic != genomic ||
        impact.wildtype != ref) {
      return null;
    }
    for (final AltScore score in impact.ranked) {
      if (score.base == alt) return score.phred;
    }
    return null;
  }

  /// [identifiers] is the snapshot's `traits`: condition name to identifiers.
  factory ClinVarVariant.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> identifiers = const <String, dynamic>{},
  }) => ClinVarVariant(
    id: json['variation_id'] as String,
    accession: json['accession'] as String,
    name: json['name'] as String,
    position: json['position'] as int,
    genomic: json['genomic'] as int,
    ref: json['ref'] as String,
    alt: json['alt'] as String,
    residue: json['residue'] as int?,
    proteinChange: json['protein_change'] as String?,
    codingChange: json['coding_change'] as String?,
    consequence: json['consequence'] as String?,
    classification: json['classification'] as String,
    reviewStatus: json['review_status'] as String,
    lastEvaluated: json['last_evaluated'] as String?,
    lastUpdated: json['last_updated'] as String?,
    collectionMethods: List<String>.unmodifiable(
      (json['collection_methods'] as List<dynamic>).cast<String>(),
    ),
    conditions: List<ClinVarCondition>.unmodifiable(
      (json['conditions'] as List<dynamic>).map(
        (dynamic c) => ClinVarCondition.fromJson(
          c as Map<String, dynamic>,
          identifiers: identifiers,
        ),
      ),
    ),
  );
}

/// An offline snapshot, with its coverage separate from its clinical content.
@immutable
final class GeneClinVar {
  const GeneClinVar._({
    required this.gene,
    required this.chromosome,
    required this.start,
    required this.sequence,
    required this.proteinSequence,
    required this.retrievedAt,
    required this.searchedRecords,
    required this.excluded,
    required this.variants,
    required this.runs,
    required this.complemented,
  });
  final String gene;
  final String chromosome;
  final int start;

  /// Letters in increasing record-local coordinate order.
  final String sequence;
  final String proteinSequence;
  final String retrievedAt;
  final int searchedRecords;
  final Map<String, int> excluded;
  final List<ClinVarVariant> variants;
  final List<ImpactRun> runs;
  final bool complemented;
  String get snapshotDate => retrievedAt.substring(0, 10);
  int get excludedCount =>
      excluded.values.fold<int>(0, (int a, int b) => a + b);

  List<ClinVarVariant> at(int position) =>
      variants.where((v) => v.position == position).toList();
  List<ClinVarVariant> atResidue(int residue) =>
      variants.where((v) => v.residue == residue).toList();

  bool matchesRecord(GeneRecord record) {
    if (gene != record.gene ||
        start != record.start ||
        sequence !=
            (record.strand == -1
                ? record.sequence.split('').reversed.join()
                : record.sequence) ||
        proteinSequence != record.protein?.translation) {
      return false;
    }
    final List<Segment> segments = List<Segment>.of(record.protein!.segments)
      ..sort(
        (a, b) => record.strand == -1
            ? b.start.compareTo(a.start)
            : a.start.compareTo(b.start),
      );
    final List<int> cds = <int>[
      for (final Segment segment in segments)
        if (record.strand == -1)
          for (int p = segment.end; p >= segment.start; p--) p
        else
          for (int p = segment.start; p <= segment.end; p++) p,
    ];
    final Map<int, int> offsets = <int, int>{
      for (int i = 0; i < cds.length; i++) cds[i]: i,
    };
    for (final ClinVarVariant v in variants) {
      final int? offset = offsets[v.position];
      if (offset == null) {
        if (v.residue != null ||
            v.codingChange != null ||
            v.proteinChange != null) {
          return false;
        }
        continue;
      }
      final int first = offset ~/ 3 * 3;
      if (first + 2 >= cds.length) return false;
      final String triplet = cds
          .sublist(first, first + 3)
          .map((p) => sequence[p - start])
          .join();
      final String? ref = GeneticCode.translate(triplet);
      final String? alt = GeneticCode.translate(
        triplet.replaceRange(offset % 3, offset % 3 + 1, v.alt),
      );
      if (v.codingChange != 'c.${offset + 1}${v.ref}>${v.alt}') return false;
      if (ref == '*') {
        if (v.residue != null || v.proteinChange != null) return false;
      } else {
        final int residue = offset ~/ 3 + 1;
        if (v.residue != residue ||
            ref != proteinSequence[residue - 1] ||
            v.proteinChange != 'p.$ref$residue${alt == ref ? '=' : alt}' ||
            v.consequence !=
                (alt == ref
                    ? 'synonymous'
                    : residue == 1
                    ? 'start codon'
                    : alt == '*'
                    ? 'stop gained'
                    : 'missense')) {
          return false;
        }
      }
    }
    return true;
  }

  bool matchesImpact(GeneImpact impact) =>
      gene == impact.gene &&
      chromosome == impact.chromosome &&
      start == impact.start &&
      sequence == impact.sequence &&
      complemented == impact.complemented &&
      runs.every(
        (run) =>
            impact.genomicOf(run.local) == run.genomic &&
            impact.genomicOf(run.local + run.length - 1) ==
                run.genomic + run.step * (run.length - 1),
      );

  /// Read as bytes and parsed off the UI isolate: a large gene's snapshot runs
  /// to megabytes, and decoding it in a frame stalls the walk. Bytes rather
  /// than a string, because the bundle caches every string it loads for the
  /// life of the app.
  static Future<GeneClinVar> load(
    ProteinTarget target, {
    AssetBundle? bundle,
  }) async {
    final ByteData bytes = await (bundle ?? rootBundle).load(
      target.clinvarAsset,
    );
    return compute(_decode, (bytes, target));
  }

  static GeneClinVar _decode((ByteData, ProteinTarget) file) {
    final (ByteData bytes, ProteinTarget target) = file;
    final Object? json = jsonDecode(utf8.decode(Uint8List.sublistView(bytes)));
    if (json is! Map<String, dynamic>) {
      throw FormatException('Malformed ClinVar snapshot for ${target.slug}');
    }
    return GeneClinVar.fromJson(json, target);
  }

  factory GeneClinVar.fromJson(
    Map<String, dynamic> json,
    ProteinTarget target,
  ) {
    try {
      return GeneClinVar._parse(json, target);
    } on TypeError {
      throw FormatException('Malformed ClinVar snapshot for ${target.slug}');
    }
  }

  static final RegExp _variationId = RegExp(r'^\d+$');
  static final RegExp _vcvAccession = RegExp(r'^VCV\d+\.\d+$');

  static GeneClinVar _parse(Map<String, dynamic> json, ProteinTarget target) {
    if (json['schema_version'] != 1 ||
        json['source'] != 'NCBI ClinVar' ||
        json['gene'] != target.gene ||
        json['accession'] != target.accession ||
        json['assembly'] != 'GRCh38' ||
        json['scope'] !=
            'reference-matched single nucleotide variants in the drawn gene') {
      throw FormatException('Unsupported ClinVar snapshot for ${target.slug}');
    }
    final String sequence = json['sequence'] as String;
    final String protein = json['protein_sequence'] as String;
    final int start = json['start'] as int;
    final String retrieved = json['retrieved_at'] as String;
    if (sequence.isEmpty ||
        protein.isEmpty ||
        start < 1 ||
        DateTime.tryParse(retrieved) == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(retrieved)) {
      throw const FormatException('Incomplete ClinVar provenance');
    }
    final List<ImpactRun> runs = <ImpactRun>[];
    final Map<int, int> coordinates = <int, int>{};
    int cursor = start;
    for (final dynamic raw in json['runs'] as List<dynamic>) {
      final Map<String, dynamic> r = raw as Map<String, dynamic>;
      final ImpactRun run = ImpactRun(
        local: r['local'] as int,
        genomic: r['genomic'] as int,
        step: r['step'] as int,
        length: r['length'] as int,
      );
      if (run.local != cursor ||
          run.length < 1 ||
          run.step.abs() != 1 ||
          run.genomic < 1 ||
          run.genomic + run.step * (run.length - 1) < 1) {
        throw const FormatException('Invalid ClinVar coordinate map');
      }
      for (int i = 0; i < run.length; i++) {
        coordinates[run.local + i] = run.genomic + run.step * i;
      }
      runs.add(run);
      cursor += run.length;
    }
    if (cursor != start + sequence.length ||
        coordinates.values.toSet().length != sequence.length) {
      throw const FormatException(
        'Incomplete or ambiguous ClinVar coordinate map',
      );
    }
    final bool complemented = json['complemented'] as bool;
    // Optional: a snapshot baked before conditions carried identifiers names
    // them and nothing more.
    final Map<String, dynamic> identifiers =
        (json['traits'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Set<String> ids = <String>{};
    final List<ClinVarVariant> variants = <ClinVarVariant>[];
    const Map<String, String> complement = <String, String>{
      'A': 'T',
      'T': 'A',
      'C': 'G',
      'G': 'C',
    };
    for (final dynamic raw in json['variants'] as List<dynamic>) {
      final Map<String, dynamic> v = raw as Map<String, dynamic>;
      final ClinVarVariant variant = ClinVarVariant.fromJson(
        v,
        identifiers: identifiers,
      );
      final int offset = variant.position - start;
      if (!ids.add(variant.id) ||
          !_variationId.hasMatch(variant.id) ||
          !_vcvAccession.hasMatch(variant.accession) ||
          variant.accession.split('.').first !=
              'VCV${variant.id.padLeft(9, '0')}' ||
          offset < 0 ||
          offset >= sequence.length ||
          sequence[offset] != variant.ref ||
          variant.alt.length != 1 ||
          !'ACGT'.contains(variant.alt) ||
          variant.alt == variant.ref ||
          coordinates[variant.position] != variant.genomic ||
          (complemented ? complement[variant.ref] : variant.ref) !=
              v['genomic_ref'] ||
          (complemented ? complement[variant.alt] : variant.alt) !=
              v['genomic_alt'] ||
          variant.classification.isEmpty ||
          variant.reviewStatus.isEmpty ||
          (variant.residue != null &&
              (variant.residue! < 1 || variant.residue! > protein.length))) {
        throw FormatException('Invalid ClinVar allele ${variant.id}');
      }
      variants.add(variant);
    }
    final Map<String, int> excluded = (json['excluded'] as Map<String, dynamic>)
        .map((String key, dynamic value) => MapEntry(key, value as int));
    final int searched = json['searched_records'] as int;
    if (excluded.values.any((int n) => n < 0) ||
        variants.length +
                excluded.values.fold<int>(0, (int a, int b) => a + b) !=
            searched) {
      throw const FormatException('Incomplete ClinVar search');
    }
    return GeneClinVar._(
      gene: target.gene,
      chromosome: json['chromosome'] as String,
      start: start,
      sequence: sequence,
      proteinSequence: protein,
      retrievedAt: retrieved,
      searchedRecords: searched,
      excluded: Map<String, int>.unmodifiable(excluded),
      variants: List<ClinVarVariant>.unmodifiable(variants),
      runs: List<ImpactRun>.unmodifiable(runs),
      complemented: complemented,
    );
  }
}
