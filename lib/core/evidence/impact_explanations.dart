import 'package:flutter/foundation.dart';

import 'gene_impact.dart';

/// An exact alternative of a validated impact track. Estimated neighbours and
/// reference alleles never acquire explanations.
@immutable
final class ImpactExplanationRequest {
  const ImpactExplanationRequest._(
    this.track,
    this.position,
    this.ref,
    this.alt,
  );
  final GeneImpact track;
  final int position;
  final String ref;
  final String alt;

  static ImpactExplanationRequest? forAllele(
    GeneImpact? track,
    int position,
    String ref,
    String alt,
  ) {
    final BaseImpact? base = track?.at(position);
    if (track == null ||
        !track.target.impactExplanationsAvailable ||
        base == null ||
        base.estimated ||
        base.wildtype != ref ||
        !base.ranked.any((s) => s.base == alt)) {
      return null;
    }
    return ImpactExplanationRequest._(track, position, ref, alt);
  }
}

@immutable
final class ImpactContribution {
  const ImpactContribution(this.feature, this.value);
  final String feature;
  final double value;

  String get label => labels[feature] ?? feature;
  static const Map<String, String> labels = <String, String>{
    'MERGED_SPLICING': 'Splicing',
    'MAX_ABS_RNA_SEQ': 'RNA abundance',
    'MAX_ABS_ATAC': 'DNA accessibility · ATAC',
    'MAX_ABS_DNASE': 'DNA accessibility · DNase',
    'MAX_ABS_CONTACT_MAPS': 'DNA contacts',
    'MAX_ABS_CHIP_TF': 'Transcription factor binding',
    'MAX_ABS_CHIP_HISTONE': 'Histone marks',
    'MAX_ABS_CAGE': 'Transcription initiation · CAGE',
    'MAX_ABS_PROCAP': 'Transcription initiation · PRO-cap',
    'MAX_ABS_POLYADENYLATION': 'RNA end processing',
    'ALPHAMISSENSE': 'Protein effects · AlphaMissense',
    'CACTUS_241_WAY': 'Conservation · Cactus',
    'PHASTCONS_470_WAY': 'Conservation · PhastCons',
    'PROTEIN_TERMINATION': 'Protein termination',
    'START_LOST': 'Start codon loss',
    'STOP_LOST': 'Stop codon loss',
    'IS_INSERTION': 'Insertion',
    'IS_DELETION': 'Deletion',
  };
}

/// The AVI features a contributions page totals together, each named as the
/// Atlas names its assay. The insertion and deletion flags belong to none: a
/// substitution's are zero, which the bake holds.
enum ContributionGroup {
  coding('Coding', <String, String>{
    'ALPHAMISSENSE': 'AlphaMissense',
    'PROTEIN_TERMINATION': 'Termination',
    'START_LOST': 'Start lost',
    'STOP_LOST': 'Stop lost',
  }),
  conservation('Conservation', <String, String>{
    'PHASTCONS_470_WAY': 'PhastCons 470',
    'CACTUS_241_WAY': 'Cactus 241',
  }),
  splicing('Splicing', <String, String>{'MERGED_SPLICING': 'Splicing'}),
  expression('Expression & chromatin', <String, String>{
    'MAX_ABS_RNA_SEQ': 'RNA-seq',
    'MAX_ABS_CAGE': 'CAGE',
    'MAX_ABS_PROCAP': 'PRO-cap',
    'MAX_ABS_POLYADENYLATION': 'Polyadenylation',
    'MAX_ABS_DNASE': 'DNase-seq',
    'MAX_ABS_ATAC': 'ATAC-seq',
    'MAX_ABS_CHIP_TF': 'ChIP-TF',
    'MAX_ABS_CHIP_HISTONE': 'ChIP-histone',
    'MAX_ABS_CONTACT_MAPS': '3D contacts',
  });

  const ContributionGroup(this.label, this.features);
  final String label;

  /// Whether the group's features describe the base rather than the change
  /// at it (how conserved the base is). Its attributions come out level
  /// across a base's substitutions by their nature: in insulin they vary
  /// between bases and not within one.
  bool get ofBase => this == conservation;

  /// Feature id → the assay's name, in the order the page lists them.
  final Map<String, String> features;
}

/// The track behind an assay feature for one substitution: the one with the
/// largest absolute effect, as the Atlas's AVI skill reconstructs it. The
/// model itself reports only the feature's attribution.
@immutable
final class TrackWinner {
  const TrackWinner({
    required this.scorer,
    required this.assay,
    required this.biosample,
    required this.ontology,
    required this.gene,
    required this.target,
    required this.value,
  });
  final String scorer;
  final String assay;
  final String biosample;
  final String ontology;
  final String gene;

  /// The factor or mark a ChIP track reads, or the kind of splice site.
  final String target;

  /// The assay's own effect on that track, alternative against reference.
  final double value;

  /// Whether [value] has a direction. The Atlas scores splice sites, their
  /// usage, junctions, polyadenylation and 3D contacts as sizes alone
  /// (`is_signed` false in AlphaGenome's `variant_scorers.py`); its other
  /// assays as signed log ratios.
  bool get signed => !_unsigned.contains(scorer);

  static const Set<String> _unsigned = <String>{
    'SPLICE_SITES',
    'SPLICE_SITE_USAGE',
    'SPLICE_JUNCTIONS',
    'POLYADENYLATION',
    'CONTACT_MAPS',
  };
}

@immutable
final class AlleleExplanation {
  const AlleleExplanation({
    required this.phred,
    required this.raw,
    required this.values,
    this.winners = const <String, TrackWinner>{},
  });
  final double phred;

  /// The Atlas's raw AVI score, before its genome-wide calibration.
  final double raw;

  /// Every feature's signed attribution, by Atlas feature id.
  final Map<String, double> values;
  final Map<String, TrackWinner> winners;

  /// Up to the three largest non-zero attributions, by magnitude, sign kept.
  List<ImpactContribution> get contributions {
    final List<MapEntry<String, double>> entries = values.entries
        .where((MapEntry<String, double> e) => e.value != 0)
        .toList();
    final List<String> order = values.keys.toList();
    entries.sort((MapEntry<String, double> a, MapEntry<String, double> b) {
      final int byMagnitude = b.value.abs().compareTo(a.value.abs());
      return byMagnitude != 0
          ? byMagnitude
          : order.indexOf(a.key).compareTo(order.indexOf(b.key));
    });
    return <ImpactContribution>[
      for (final MapEntry<String, double> e in entries.take(3))
        ImpactContribution(e.key, e.value),
    ];
  }

  /// What [group]'s features add up to.
  double total(ContributionGroup group) => <double>[
    for (final String feature in group.features.keys) values[feature] ?? 0,
  ].fold(0, (double a, double b) => a + b);

  /// Every attribution added up.
  double get sum => values.values.fold(0, (double a, double b) => a + b);

  String get summary {
    final List<ImpactContribution> top = contributions;
    if (top.isEmpty) {
      return 'No non-zero contributions in this snapshot.';
    }
    final ImpactContribution first = top.first;
    return '${first.label} has the largest contribution, '
        '${first.value < 0 ? 'lowering' : 'raising'} the AVI score.';
  }
}

/// Versioned transport payload, matched to the full coordinate/sequence/score
/// identity of the AVI track before any one of its explanations is available.
@immutable
final class GeneImpactExplanations {
  const GeneImpactExplanations._(
    this.track,
    this.generatedAt,
    this.clientVersion,
    this.urlTemplate,
    this.baseline,
    this._positions,
  );
  final GeneImpact track;
  final String generatedAt;
  final String clientVersion;
  final String urlTemplate;

  /// The raw score with every attribution at zero, where the Atlas's raw
  /// scores less their attributions hold to one value; null where they don't.
  final double? baseline;
  final Map<int, Map<String, AlleleExplanation>> _positions;

  AlleleExplanation? at(ImpactExplanationRequest request) {
    final bool matches =
        request.track.gene == track.gene &&
        request.track.transcript == track.transcript &&
        request.track.sequence == track.sequence &&
        request.track.start == track.start &&
        request.track.chromosome == track.chromosome &&
        request.track.complemented == track.complemented &&
        request.track.genomicOf(request.position) ==
            track.genomicOf(request.position) &&
        track.baseAt(request.position) == request.ref;
    if (!matches) return null;
    return _positions[request.position]?[request.alt];
  }

  Uri atlasUrl(ImpactExplanationRequest request) {
    String genomic(String base) => track.complemented
        ? const <String, String>{'A': 'T', 'T': 'A', 'C': 'G', 'G': 'C'}[base]!
        : base;
    final String variant =
        '${track.chromosome}:${track.genomicOf(request.position)}:'
        '${genomic(request.ref)}>${genomic(request.alt)}';
    return Uri.parse(
      urlTemplate.replaceFirst('{variant}', Uri.encodeComponent(variant)),
    );
  }

  factory GeneImpactExplanations.fromJson(
    Map<String, dynamic> json,
    GeneImpact track,
  ) {
    try {
      return GeneImpactExplanations._parse(json, track);
    } on TypeError {
      throw const FormatException('Malformed AVI explanations');
    } on RangeError {
      throw const FormatException('Invalid AVI explanation index');
    }
  }

  static GeneImpactExplanations _parse(
    Map<String, dynamic> json,
    GeneImpact track,
  ) {
    void require(bool valid) {
      if (!valid) {
        throw const FormatException('AVI explanations do not match this track');
      }
    }

    require(
      json['schema_version'] == 2 &&
          json['scorer'] == 'AVI_SCORE_FEATURE_IMPORTANCE' &&
          json['units'] == 'raw_score_attribution' &&
          json['scope'] == 'across_atlas_genes_and_biosamples' &&
          json['selection'] == 'all' &&
          json['alt_order'] == 'ACGT minus wildtype' &&
          json['assembly'] == 'GRCh38' &&
          json['annotation'] == 'GENCODE v46' &&
          json['gene'] == track.gene &&
          json['uniprot'] == track.target.uniprot &&
          json['accession'] == track.target.accession &&
          json['chromosome'] == track.chromosome &&
          json['transcript'] == track.transcript &&
          json['start'] == track.start &&
          json['sequence'] == track.sequence &&
          json['orientation'] == track.orientation &&
          json['complemented'] == track.complemented,
    );
    final String generated = json['generated_at'] as String;
    final String client = json['client_version'] as String;
    require(
      RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(generated) &&
          DateTime.tryParse(generated) != null &&
          client.isNotEmpty &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(json['impact_sha256'] as String),
    );
    final String template = json['atlas_url_template'] as String;
    final Uri url = Uri.parse(
      template.replaceFirst('{variant}', 'chr1:1:A%3EC'),
    );
    require(
      '{variant}'.allMatches(template).length == 1 &&
          url.scheme == 'https' &&
          url.host == 'deepmind.google.com' &&
          url.path == '/science/alphagenome/atlas' &&
          url.queryParameters['q'] == 'chr1:1:A>C',
    );
    final List<String> features = (json['features'] as List<dynamic>)
        .cast<String>();
    require(
      features.length == ImpactContribution.labels.length &&
          features.toSet().length == features.length &&
          features.every(ImpactContribution.labels.containsKey),
    );
    final List<TrackWinner Function(double)> tracks =
        <TrackWinner Function(double)>[
          for (final dynamic raw in json['tracks'] as List<dynamic>)
            _track((raw as List<dynamic>).cast<String>()),
        ];
    final num? baseline = json['baseline'] as num?;
    require(baseline == null || baseline.isFinite);
    int next = track.start;
    for (final dynamic raw in json['runs'] as List<dynamic>) {
      final Map<String, dynamic> run = raw as Map<String, dynamic>;
      final int local = run['local'] as int;
      final int genomic = run['genomic'] as int;
      final int step = run['step'] as int;
      final int length = run['length'] as int;
      require(
        local == next &&
            length > 0 &&
            (step == -1 || step == 1) &&
            length <= track.sequence.length - (local - track.start),
      );
      for (int i = 0; i < length; i++) {
        require(track.genomicOf(local + i) == genomic + step * i);
      }
      next += length;
    }
    require(next == track.start + track.sequence.length);
    final Map<String, dynamic> rawPositions =
        json['positions'] as Map<String, dynamic>;
    require(rawPositions.length == track.length);
    final Map<int, Map<String, AlleleExplanation>> positions = {};
    for (final MapEntry<String, dynamic> entry in rawPositions.entries) {
      final int position = int.parse(entry.key);
      require(entry.key == '$position');
      final BaseImpact? base = track.at(position);
      require(base != null && !base.estimated);
      final List<String> alts = GeneImpact.bases
          .split('')
          .where((b) => b != base!.wildtype)
          .toList();
      final List<dynamic> rows = entry.value as List<dynamic>;
      require(rows.length == 3);
      final Map<String, AlleleExplanation> alleles = {};
      for (int a = 0; a < 3; a++) {
        final List<dynamic> row = rows[a] as List<dynamic>;
        require(row.length == 4);
        final double phred = (row[0] as num).toDouble();
        final double expected = base!.ranked
            .firstWhere((s) => s.base == alts[a])
            .phred;
        require(phred.isFinite && (phred - expected).abs() < 0.00001);
        final double raw = (row[1] as num).toDouble();
        final List<dynamic> weights = row[2] as List<dynamic>;
        require(raw.isFinite && weights.length == features.length);
        final Map<String, double> values = <String, double>{};
        for (int f = 0; f < features.length; f++) {
          final double weight = (weights[f] as num).toDouble();
          require(weight.isFinite);
          values[features[f]] = weight;
        }
        final Map<String, TrackWinner> winners = <String, TrackWinner>{};
        for (final dynamic won in row[3] as List<dynamic>) {
          final List<dynamic> triple = won as List<dynamic>;
          require(triple.length == 3);
          final String feature = features[triple[0] as int];
          final double value = (triple[2] as num).toDouble();
          require(!winners.containsKey(feature) && value.isFinite);
          winners[feature] = tracks[triple[1] as int](value);
        }
        alleles[alts[a]] = AlleleExplanation(
          phred: phred,
          raw: raw,
          values: Map.unmodifiable(values),
          winners: Map.unmodifiable(winners),
        );
      }
      positions[position] = Map.unmodifiable(alleles);
    }
    return GeneImpactExplanations._(
      track,
      generated,
      client,
      template,
      baseline?.toDouble(),
      Map.unmodifiable(positions),
    );
  }

  /// A row of the payload's track table, waiting for its value.
  static TrackWinner Function(double) _track(List<String> fields) {
    if (fields.length != 6) {
      throw const FormatException('Malformed AVI track');
    }
    return (double value) => TrackWinner(
      scorer: fields[0],
      assay: fields[1],
      biosample: fields[2],
      ontology: fields[3],
      gene: fields[4],
      target: fields[5],
      value: value,
    );
  }
}
