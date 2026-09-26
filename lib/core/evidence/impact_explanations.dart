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

@immutable
final class AlleleExplanation {
  const AlleleExplanation(this.contributions);
  final List<ImpactContribution> contributions;

  String get summary {
    if (contributions.isEmpty) {
      return 'No non-zero contributions in this snapshot.';
    }
    final ImpactContribution first = contributions.first;
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
    this._positions,
  );
  final GeneImpact track;
  final String generatedAt;
  final String clientVersion;
  final String urlTemplate;
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
      json['schema_version'] == 1 &&
          json['scorer'] == 'AVI_SCORE_FEATURE_IMPORTANCE' &&
          json['units'] == 'raw_score_attribution' &&
          json['scope'] == 'across_atlas_genes_and_biosamples' &&
          json['selection'] == 'top_3_absolute_signed' &&
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
      features.isNotEmpty &&
          features.toSet().length == features.length &&
          features.every(ImpactContribution.labels.containsKey),
    );
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
        require(row.length == 2);
        final double phred = (row[0] as num).toDouble();
        final double expected = base!.ranked
            .firstWhere((s) => s.base == alts[a])
            .phred;
        require(phred.isFinite && (phred - expected).abs() < 0.00001);
        final List<dynamic> values = row[1] as List<dynamic>;
        require(values.length <= 3);
        final Set<int> seen = {};
        final List<ImpactContribution> contributions = [];
        double previous = double.infinity;
        for (final dynamic value in values) {
          final List<dynamic> pair = value as List<dynamic>;
          require(pair.length == 2);
          final int index = pair[0] as int;
          final double weight = (pair[1] as num).toDouble();
          require(
            index >= 0 &&
                index < features.length &&
                seen.add(index) &&
                weight.isFinite &&
                weight != 0 &&
                weight.abs() <= previous,
          );
          previous = weight.abs();
          contributions.add(ImpactContribution(features[index], weight));
        }
        alleles[alts[a]] = AlleleExplanation(List.unmodifiable(contributions));
      }
      positions[position] = Map.unmodifiable(alleles);
    }
    return GeneImpactExplanations._(
      track,
      generated,
      client,
      template,
      Map.unmodifiable(positions),
    );
  }
}
