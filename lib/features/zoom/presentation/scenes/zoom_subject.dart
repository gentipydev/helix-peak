import 'dart:math' as math;

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

  /// How strongly each part of [body] is lit, by UBERON id, from 0 to 1:
  /// the gene's level there against its highest, and the part the zoom goes
  /// into at least half, whether or not the Atlas calls the gene raised
  /// there.
  late final Map<String, double> litLevels = () {
    final Map<String, double> out = <String, double>{};
    final List<(String, double)> specific = track.tissue.specific;
    double top = 0;
    for (final (String _, double level) in specific) {
      top = math.max(top, level);
    }
    for (final (String name, double level) in specific) {
      final String? part = tissueAnatomy[ZoomPath.tissueName(name)]?.uberon;
      if (part != null && body.parts.containsKey(part)) {
        out[part] = math.max(out[part] ?? 0, top <= 0 ? 1 : level / top);
      }
    }
    final String? own = anatomy?.uberon;
    if (own != null && body.parts.containsKey(own)) {
      out.putIfAbsent(own, () => 0.5);
    }
    return Map<String, double>.unmodifiable(out);
  }();

  /// How strongly the part the zoom goes into is lit, or 0 where the body
  /// does not draw it.
  double get followedLevel => litLevels[anatomy?.uberon] ?? 0;

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
