import 'package:flutter/foundation.dart';

import 'locus_track.dart';

/// A kind of cell that has lost its nucleus by the time it is what the
/// Atlas measures, and the cell that still has one.
///
/// A general fact about cells, not about any gene: whatever gene the Atlas
/// finds read in one of these, the zoom cannot land in its nucleus, because
/// it has none.
@immutable
final class Anucleate {
  const Anucleate({
    required this.mature,
    required this.precursor,
    required this.place,
    required this.size,
  });

  /// What the cell is, grown: `mature red blood cells`.
  final String mature;

  /// The cell with a nucleus it comes from: `erythroblasts`.
  final String precursor;

  /// Where that one is found: `the bone marrow`.
  final String place;

  /// How wide the grown cell is, in metres.
  final double size;
}

/// The Atlas's single cell types that have no nucleus, by its own name for
/// them. Red cells lose theirs as they mature in the marrow; platelets are
/// fragments shed by megakaryocytes and never had one.
const Map<String, Anucleate> anucleateCellTypes = <String, Anucleate>{
  'Erythrocytes': Anucleate(
    mature: 'mature red blood cells',
    precursor: 'erythroblasts',
    place: 'the bone marrow',
    size: 7.5e-6,
  ),
  'Platelets': Anucleate(
    mature: 'platelets',
    precursor: 'megakaryocytes',
    place: 'the bone marrow',
    size: 2.5e-6,
  ),
};

/// How the path's organ was chosen.
enum TissueFrom {
  /// The tissue the gene's RNA is highest in.
  reading,

  /// No tissue stands out: the home of the cell type it is highest in.
  cellHome,

  /// Neither stands out: the Atlas's first tissue cell type pair.
  pair,
}

/// How the path's cell was chosen.
enum CellFrom {
  /// The Atlas's tissue cell type pair for the organ.
  pair,

  /// The single cell type it is highest in among those of the organ.
  singleCell,
}

/// Where the zoom goes for one protein on its way down to the gene: an organ
/// and a kind of cell that lives in it, and whether that kind has a nucleus
/// to land in. All of it is the Atlas's reading as the bake chose it into
/// the locus track (schema 2), and none of it is written per protein.
///
/// A schema 1 track has no path: the zoom then takes the Atlas's top tissue
/// and its top cell type each on its own, as it did before schema 2.
@immutable
final class ZoomPath {
  const ZoomPath({
    this.tissue,
    this.cellType,
    this.cellClass,
    this.anucleate,
    this.landsIn,
    this.tissueFrom,
    this.cellFrom,
    this.baked = false,
  });

  factory ZoomPath.of(LocusTrack track) {
    final LocusPath? path = track.path;
    if (path != null) {
      final String? cell = path.cellType;
      return ZoomPath(
        tissue: path.tissue,
        cellType: cell,
        cellClass: path.cellClass,
        anucleate: cell == null || path.landsIn == null
            ? null
            : anucleateCellTypes[cell],
        landsIn: path.landsIn,
        tissueFrom: switch (path.tissueFrom) {
          'tissue' => TissueFrom.reading,
          'cell_type' => TissueFrom.cellHome,
          'tissue_cell_type' => TissueFrom.pair,
          _ => null,
        },
        cellFrom: switch (path.cellFrom) {
          'tissue_cell_type' => CellFrom.pair,
          'single_cell_type' => CellFrom.singleCell,
          _ => null,
        },
        baked: true,
      );
    }
    final String? cellType = track.cellType.first;
    final String? tissue = track.tissue.first;
    return ZoomPath(
      tissue: tissue == null ? null : tissueName(tissue),
      cellType: cellType,
      anucleate: cellType == null ? null : anucleateCellTypes[cellType],
      tissueFrom: tissue == null ? null : TissueFrom.reading,
      cellFrom: cellType == null ? null : CellFrom.singleCell,
    );
  }

  /// The tissue the zoom goes to, by the Atlas's consensus name without the
  /// sample number some carry (`stomach 1`), or null where none stands out.
  final String? tissue;

  /// The kind of cell, as the Atlas wrote it, or null where none that lives
  /// in [tissue] stands out and the zoom draws the tissue's own cells.
  final String? cellType;

  /// The Atlas's class for [cellType]: `Endocrine cells`. Null in schema 1.
  final String? cellClass;

  /// Set where that kind has no nucleus: the zoom lands in its precursor.
  final Anucleate? anucleate;

  /// The bake's word for where the zoom lands instead.
  final LandsIn? landsIn;

  final TissueFrom? tissueFrom;
  final CellFrom? cellFrom;

  /// Whether the bake chose this path (schema 2), so organ and cell agree.
  final bool baked;

  static final RegExp _sample = RegExp(r'\s+\d+$');
  static final RegExp _qualifier = RegExp(r'\s*\([^)]*\)$');

  /// [name] as a consensus tissue: `stomach 1` is the stomach.
  static String tissueName(String name) =>
      name.replaceFirst(_sample, '').toLowerCase();

  /// [cellType] as it reads in a sentence, without the qualifier the Atlas
  /// sometimes puts after a pair's cell (`Mitotic cells (Stomach)`).
  String? get cellName => cellType?.replaceFirst(_qualifier, '');
}
