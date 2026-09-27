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

/// Where the zoom goes for one protein on its way down to the gene: the
/// organ its RNA is highest in, the kind of cell, and whether that kind has
/// a nucleus to land in. All of it is the Atlas's reading, from the locus
/// track, and none of it is written per protein.
@immutable
final class ZoomPath {
  const ZoomPath({this.tissue, this.cellType, this.anucleate});

  factory ZoomPath.of(LocusTrack track) {
    final String? cellType = track.cellType.first;
    final String? tissue = track.tissue.first;
    return ZoomPath(
      tissue: tissue?.replaceFirst(_sample, ''),
      cellType: cellType,
      anucleate: cellType == null ? null : anucleateCellTypes[cellType],
    );
  }

  /// The tissue the Atlas finds the RNA highest in, by its name without the
  /// sample number some carry (`stomach 1`), or null where no tissue stands
  /// out.
  final String? tissue;

  static final RegExp _sample = RegExp(r'\s+\d+$');

  /// The kind of cell it finds it highest in, or null where there is none.
  final String? cellType;

  /// Set where that kind has no nucleus: the zoom lands in its precursor.
  final Anucleate? anucleate;
}
