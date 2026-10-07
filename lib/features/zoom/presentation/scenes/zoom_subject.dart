import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import '../../domain/anatomy_figure.dart';
import '../../domain/anatomy_tables.dart';
import '../../domain/gene_layout.dart';
import '../../domain/locus_track.dart';
import '../../domain/zoom_depth.dart';
import '../../domain/zoom_path.dart';

/// Everything a scene draws one protein's zoom from: its locus track, the
/// path the bake chose, the depths of its stops, and its record.
@immutable
final class ZoomSubject {
  ZoomSubject({required this.track, required this.record})
    : path = ZoomPath.of(track),
      layout = GeneLayout.of(record) {
    depth = ZoomDepth(track, path: path);
  }

  final LocusTrack track;
  final GeneRecord record;
  final ZoomPath path;
  final GeneLayout layout;
  late final ZoomDepth depth;

  /// How the path's tissue is drawn, or null where the path names none.
  TissueAnatomy? get anatomy =>
      path.tissue == null ? null : tissueAnatomy[path.tissue];

  /// The standing figure the body is drawn as: one that has the path's
  /// tissue, and as many of the others the gene is raised in as either has.
  late final AnatomyFigure body = AnatomyFigure.bodyFor(path.tissue, <String>[
    for (final (String name, double _) in track.tissue.specific)
      ZoomPath.tissueName(name),
  ]);

  /// The part of [body] the zoom goes into, or null where the path names
  /// no tissue.
  AnatomyPart? get bodyPart => body.parts[anatomy?.uberon];

  /// [metres] in [stop]'s scene units.
  double unitsOf(ZoomStop stop, double metres) => metres / depth.widthOf(stop);

  /// The genome position of a point [offset] base pairs into the gene from
  /// its 5′ end, on the span MANE gives it.
  double genomeAt(double offset) {
    final double along = offset / layout.length * track.geneLengthBp;
    return track.strand < 0 ? track.spanEnd - along : track.spanStart + along;
  }

  /// The middle of the gene's span, on the genome.
  double get geneMiddle => (track.spanStart + track.spanEnd) / 2;

  /// The middle of the band or bands it lies in, on the genome.
  double get bandMiddle => (track.bandStart + track.bandEnd) / 2;

  /// How many of the record's first bases the DNA stop draws, and where
  /// the middle of them lies, in base pairs from the gene's 5′ end.
  int get dnaBases => record.sequence.length < ZoomDepth.helixBases
      ? record.sequence.length
      : ZoomDepth.helixBases;
  double get dnaMiddle => dnaBases / 2;
}
