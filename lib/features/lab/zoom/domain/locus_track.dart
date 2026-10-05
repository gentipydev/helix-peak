import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/track_source.dart';

/// How a band takes Giemsa stain, as UCSC's cytoBand table names it.
enum Stain {
  /// Takes none: the pale bands.
  gneg,

  /// Takes it, from lightly to fully.
  gpos25,
  gpos50,
  gpos75,
  gpos100,

  /// The centromere.
  acen,

  /// Variable heterochromatin.
  gvar,

  /// The stalk of an acrocentric chromosome's short arm.
  stalk;

  static Stain fromWire(String wire) => Stain.values.byName(wire);

  /// How dark the band stains, from 0 to 1, for the bands that take stain.
  double get depth => switch (this) {
    Stain.gneg => 0,
    Stain.gpos25 => 0.25,
    Stain.gpos50 => 0.5,
    Stain.gpos75 => 0.75,
    Stain.gpos100 => 1,
    Stain.acen || Stain.gvar || Stain.stalk => 0.5,
  };
}

/// One band of a chromosome: 1-based and inclusive, on GRCh38.
@immutable
final class CytoBand {
  const CytoBand({
    required this.name,
    required this.start,
    required this.end,
    required this.stain,
  });

  factory CytoBand.fromJson(Map<String, dynamic> json) => CytoBand(
    name: json['name'] as String,
    start: json['start'] as int,
    end: json['end'] as int,
    stain: Stain.fromWire(json['stain'] as String),
  );

  /// `p15.5`: its arm and number.
  final String name;
  final int start;
  final int end;
  final Stain stain;

  bool get onShortArm => name.startsWith('p');

  int get lengthBp => end - start + 1;
}

/// What the Human Protein Atlas says of where a gene's RNA is found, at one
/// grain: tissues, or single cell types.
@immutable
final class AtlasReading {
  const AtlasReading({
    required this.specificity,
    required this.distribution,
    required this.specific,
  });

  factory AtlasReading.fromJson(Map<String, dynamic> json, String unit) =>
      AtlasReading(
        specificity: json['specificity'] as String? ?? 'Not detected',
        distribution: json['distribution'] as String? ?? '',
        specific: <(String, double)>[
          for (final dynamic raw
              in json['specific'] as List<dynamic>? ?? <dynamic>[])
            (
              (raw as Map<String, dynamic>)['name'] as String,
              (raw[unit] as num).toDouble(),
            ),
        ],
      );

  /// In the Atlas's own words: `Tissue enriched`, `Low tissue specificity`.
  final String specificity;

  /// `Detected in all`, `Detected in some`.
  final String distribution;

  /// The ones the gene is specific to, and its level in each, highest first.
  /// Empty where it is specific to none.
  final List<(String, double)> specific;

  /// The one it is highest in, or null where it is specific to none.
  String? get first => specific.isEmpty ? null : specific.first.$1;
}

/// One of the Atlas's tissue cell type pairs: a cell type it finds the gene
/// enriched in within a tissue, both in its own words
/// (`Pancreas - Beta cells`).
@immutable
final class TissueCellPair {
  const TissueCellPair({required this.tissue, required this.cellType});

  final String tissue;
  final String cellType;
}

/// Where in a cell the Atlas finds the protein: its main locations and its
/// additional ones, in its own words (`Golgi apparatus`). Empty where it
/// gives none.
@immutable
final class SubcellularReading {
  const SubcellularReading({
    this.main = const <String>[],
    this.additional = const <String>[],
  });

  final List<String> main;
  final List<String> additional;

  bool get isEmpty => main.isEmpty && additional.isEmpty;
}

/// The cell with a nucleus the zoom enters where the path's cell type has
/// none, and where it is found.
@immutable
final class LandsIn {
  const LandsIn({required this.cell, required this.place, required this.why});

  /// `erythroblasts`.
  final String cell;

  /// `bone marrow`.
  final String place;

  /// `no nucleus`.
  final String why;
}

/// The zoom's one way down for this gene, as the bake chose it from the
/// Atlas's readings (`path_of` in `pipeline/locus/bake_locus.py`, schema 2):
/// an organ, and a cell that lives in it.
@immutable
final class LocusPath {
  const LocusPath({
    this.tissue,
    this.tissueFrom,
    this.cellType,
    this.cellClass,
    this.cellFrom,
    this.landsIn,
  });

  factory LocusPath.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? lands =
        json['lands_in'] as Map<String, dynamic>?;
    return LocusPath(
      tissue: json['tissue'] as String?,
      tissueFrom: json['tissue_from'] as String?,
      cellType: json['cell_type'] as String?,
      cellClass: json['cell_class'] as String?,
      cellFrom: json['cell_from'] as String?,
      landsIn: lands == null
          ? null
          : LandsIn(
              cell: lands['cell'] as String,
              place: lands['place'] as String,
              why: lands['why'] as String,
            ),
    );
  }

  /// The consensus tissue, lower case (`bone marrow`), or null where the
  /// readings name none.
  final String? tissue;

  /// How the tissue was chosen: `tissue` (the RNA is highest there),
  /// `cell_type` (the home of its top cell type) or `tissue_cell_type` (its
  /// first tissue cell type pair).
  final String? tissueFrom;

  /// The cell type as the Atlas wrote it, or null where none lives in the
  /// tissue and the zoom draws the tissue's own cells.
  final String? cellType;

  /// The Atlas's class for it: `Endocrine cells`.
  final String? cellClass;

  /// How the cell was chosen: `tissue_cell_type` or `single_cell_type`.
  final String? cellFrom;

  /// Set where the cell type has no nucleus.
  final LandsIn? landsIn;
}

/// The `locus` track: where a protein's gene lies on its chromosome, by
/// band, with every band of that chromosome, and where in the body its RNA
/// is read.
///
/// Baked by `pipeline/locus/` in the backend: the span MANE Select gives the
/// gene on GRCh38, the bands from UCSC's cytoBand table for hg38, and the
/// Human Protein Atlas's reading of the gene. Schema 2 adds the Atlas's
/// tissue cell type pairs, where in a cell and where to it finds the protein
/// secreted, and the zoom's [path]; a schema 1 payload reads without them.
@immutable
final class LocusTrack {
  const LocusTrack({
    required this.chromosome,
    required this.sequence,
    required this.length,
    required this.spanStart,
    required this.spanEnd,
    required this.strand,
    required this.bandNames,
    required this.bandStart,
    required this.bandEnd,
    required this.locus,
    required this.bands,
    required this.tissue,
    required this.cellType,
    required this.cytobandUpdated,
    required this.atlasVersion,
    required this.atlasLicence,
    this.schemaVersion = 1,
    this.path,
    this.tissueCellTypes = const <TissueCellPair>[],
    this.subcellular = const SubcellularReading(),
    this.secretome,
    this.maneRelease = '',
    this.atlasUrl = '',
  });

  /// Parses one payload, refusing one that names another protein or whose
  /// bands are not the chromosome whole.
  factory LocusTrack.fromJson(Map<String, dynamic> json, ProteinTarget target) {
    if (json['gene'] != target.gene || json['uniprot'] != target.uniprot) {
      throw FormatException(
        'A locus track for another protein, not ${target.slug}',
      );
    }
    final List<CytoBand> bands = <CytoBand>[
      for (final dynamic raw in json['bands'] as List<dynamic>? ?? <dynamic>[])
        CytoBand.fromJson(raw as Map<String, dynamic>),
    ];
    final int length = json['length'] as int;
    int at = 1;
    for (final CytoBand band in bands) {
      if (band.start != at || band.end < band.start) {
        throw FormatException(
          'The locus track for ${target.slug} has a gap or an overlap at '
          '${band.name}',
        );
      }
      at = band.end + 1;
    }
    if (bands.isEmpty || at - 1 != length) {
      throw FormatException(
        'The locus track for ${target.slug} does not draw its chromosome whole',
      );
    }
    final Map<String, dynamic> span = json['span'] as Map<String, dynamic>;
    final Map<String, dynamic> band = json['band'] as Map<String, dynamic>;
    final Map<String, dynamic> expression =
        json['expression'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> sources =
        json['sources'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> atlas =
        sources['hpa'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> cytoband =
        sources['cytoband'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return LocusTrack(
      chromosome: json['chromosome'] as String,
      sequence: json['sequence'] as String,
      length: length,
      spanStart: span['start'] as int,
      spanEnd: span['end'] as int,
      strand: span['strand'] as int,
      bandNames: <String>[
        for (final dynamic name in band['names'] as List<dynamic>)
          name as String,
      ],
      bandStart: band['start'] as int,
      bandEnd: band['end'] as int,
      locus: json['locus'] as String,
      bands: List<CytoBand>.unmodifiable(bands),
      tissue: AtlasReading.fromJson(
        expression['tissue'] as Map<String, dynamic>? ?? <String, dynamic>{},
        'ntpm',
      ),
      cellType: AtlasReading.fromJson(
        expression['cell_type'] as Map<String, dynamic>? ?? <String, dynamic>{},
        'ncpm',
      ),
      cytobandUpdated: cytoband['updated'] as String? ?? '',
      atlasVersion: atlas['version'] as String? ?? '',
      atlasLicence: atlas['licence'] as String? ?? '',
      schemaVersion: json['schema_version'] as int? ?? 1,
      path: json['path'] == null
          ? null
          : LocusPath.fromJson(json['path'] as Map<String, dynamic>),
      tissueCellTypes: <TissueCellPair>[
        for (final dynamic raw
            in expression['tissue_cell_type'] as List<dynamic>? ??
                <dynamic>[])
          TissueCellPair(
            tissue: (raw as Map<String, dynamic>)['tissue'] as String,
            cellType: raw['cell_type'] as String,
          ),
      ],
      subcellular: _subcellular(
        expression['subcellular'] as Map<String, dynamic>?,
      ),
      secretome: expression['secretome'] as String?,
      maneRelease:
          (sources['mane'] as Map<String, dynamic>?)?['release'] as String? ??
          '',
      atlasUrl: atlas['url'] as String? ?? '',
    );
  }

  static SubcellularReading _subcellular(Map<String, dynamic>? json) =>
      json == null
      ? const SubcellularReading()
      : SubcellularReading(
          main: <String>[
            for (final dynamic name in json['main'] as List<dynamic>? ??
                <dynamic>[])
              name as String,
          ],
          additional: <String>[
            for (final dynamic name
                in json['additional'] as List<dynamic>? ?? <dynamic>[])
              name as String,
          ],
        );

  /// [target]'s track, read through [tracks].
  static Future<LocusTrack> load(
    ProteinTarget target, {
    required TrackSource tracks,
  }) async {
    final Uint8List bytes = await tracks.read(target.slug, TrackKind.locus);
    return LocusTrack.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      target,
    );
  }

  /// `11`, `X`.
  final String chromosome;

  /// `NC_000011.10`.
  final String sequence;

  /// The chromosome's length in base pairs.
  final int length;

  /// The gene's span, 1-based and inclusive, and its strand.
  final int spanStart;
  final int spanEnd;
  final int strand;

  /// The band or bands the gene lies in, and where they begin and end.
  final List<String> bandNames;
  final int bandStart;
  final int bandEnd;

  /// The place as cytogenetics writes it: `11p15.5`, `Xp21.2-p21.1`.
  final String locus;

  /// Every band of the chromosome, from the end of the short arm.
  final List<CytoBand> bands;

  /// Where in the body the Atlas finds the gene's RNA.
  final AtlasReading tissue;
  final AtlasReading cellType;

  /// When UCSC last updated the cytoBand table the bands are from.
  final String cytobandUpdated;

  /// The Human Protein Atlas version read, and its licence.
  final String atlasVersion;
  final String atlasLicence;

  /// The payload's schema: 1, or 2 with the fields below.
  final int schemaVersion;

  /// The zoom's one way down, as the bake chose it; null in schema 1.
  final LocusPath? path;

  /// The Atlas's tissue cell type pairs, as it lists them.
  final List<TissueCellPair> tissueCellTypes;

  /// Where in a cell the Atlas finds the protein.
  final SubcellularReading subcellular;

  /// Where the Atlas finds it secreted to (`Secreted to blood`), or null.
  final String? secretome;

  /// The MANE release the span is from: `v1.5`.
  final String maneRelease;

  /// The Atlas's page for the gene, as JSON.
  final String atlasUrl;

  /// The gene's real length on the chromosome, in base pairs: its span,
  /// whatever the record drawn from it keeps of its introns.
  int get geneLengthBp => spanEnd - spanStart + 1;

  /// The band or bands' length, in base pairs.
  int get bandLengthBp => bandEnd - bandStart + 1;
}
