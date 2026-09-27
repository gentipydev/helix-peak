import 'dart:math' as math;

import '../../../../shared/format.dart';
import 'locus_track.dart';
import 'zoom_path.dart';
import 'zoom_scale.dart';

/// The words under the zoom: one caption per level, and the line naming the
/// sources. Every number about the protein comes from its locus track; the
/// rest are what bodies, cells and DNA measure, said once for every protein.
/// No caption names a gene or a protein.
final class ZoomCaptions {
  ZoomCaptions(this.track) : path = ZoomPath.of(track);

  final LocusTrack track;
  final ZoomPath path;

  String captionOf(ZoomLevel level) => switch (level) {
    ZoomLevel.body => _body(),
    ZoomLevel.organ => _organ(),
    ZoomLevel.tissue =>
      'A slice of tissue half a millimetre across: cells packed side by side, '
          'each tens of micrometres wide.',
    ZoomLevel.cell => _cell(),
    ZoomLevel.nucleus =>
      'Its nucleus, about ten micrometres across. It holds 46 chromosomes, '
          'about 2 metres of DNA, each in a territory of its own.',
    ZoomLevel.chromosome => _chromosome(),
    ZoomLevel.gene => _gene(),
  };

  /// Where the bands and the body's reading come from, and on what terms.
  String get sources =>
      'Bands: the UCSC Genome Browser’s cytoBand table for hg38, updated '
      '${track.cytobandUpdated.split('T').first}. Where it is read: the Human '
      'Protein Atlas, version ${track.atlasVersion}, ${track.atlasLicence}.';

  String _body() {
    final String? tissue = path.tissue;
    return tissue == null
        ? 'A body, about 1.7 metres tall. The Human Protein Atlas finds this '
              'gene’s RNA ${_found(track.tissue, 'tissue', 'tissues')}, and '
              'no one tissue stands out.'
        : 'A body, about 1.7 metres tall. The Human Protein Atlas finds this '
              'gene’s RNA highest in the $tissue.';
  }

  String _organ() {
    final String? tissue = path.tissue;
    if (tissue == null) {
      return 'An organ, seen at the scale of centimetres. No one tissue stands '
          'out for this gene, so this one stands for any it is read in.';
    }
    final String reading = switch (track.tissue.specificity) {
      'Tissue enriched' =>
        'The Atlas calls the gene tissue enriched here: its RNA is at least '
            'four times higher than in any other tissue.',
      'Group enriched' =>
        'The Atlas calls the gene group enriched: its RNA is at least four '
            'times higher in a few tissues, this among them, than in any '
            'other.',
      'Tissue enhanced' =>
        'The Atlas calls the gene tissue enhanced here: its RNA is at least '
            'four times its average in the other tissues.',
      _ =>
        'The Atlas reads it here as ${track.tissue.specificity.toLowerCase()}.',
    };
    return 'The $tissue, seen at the scale of centimetres. $reading';
  }

  String _cell() {
    final String? cellType = path.cellType;
    final Anucleate? anucleate = path.anucleate;
    if (cellType != null && anucleate != null) {
      return 'The Atlas finds this gene’s RNA highest in '
          '${_lower(cellType)}. But ${anucleate.mature} have no nucleus, so no '
          'gene is read in them: the zoom lands instead in one of the '
          '${anucleate.precursor} of ${anucleate.place} they come from, which '
          'still has its nucleus.';
    }
    return cellType == null
        ? 'One cell, tens of micrometres across. The Atlas finds this gene’s '
              'RNA ${_found(track.cellType, 'kind of cell', 'kinds of cell')}, '
              'and no one kind stands out.'
        : 'One cell, tens of micrometres across. Among the body’s kinds of '
              'cell, the Atlas finds this gene’s RNA highest in '
              '${_lower(cellType)}.';
  }

  String _chromosome() {
    final List<String> names = track.bandNames;
    final String where = names.length == 1
        ? 'band ${names.single}, a stripe of stain '
              '${_millions(track.bandLengthBp)} base pairs across,'
        : 'bands ${names.first} to ${names.last}, stripes of stain '
              '${_millions(track.bandLengthBp)} base pairs across between them,';
    return 'Chromosome ${track.chromosome}, ${_millions(track.length)} base '
        'pairs, drawn condensed as it is when a cell divides and stained with '
        'Giemsa. The gene lies in $where seen down a microscope at low '
        'resolution. The gene itself, ${grouped(track.geneLengthBp)} base '
        'pairs, is too small to see at this scale.';
  }

  String _gene() {
    final double stretched = ZoomScale.stretchedLength(track.geneLengthBp);
    final int shown = math.min(ZoomScale.helixBases, track.geneLengthBp);
    return 'The gene, ${grouped(track.geneLengthBp)} base pairs. Stretched '
        'out, its DNA would run about ${lengthLabel(_round2(stretched))}; the '
        'double helix is 2 nm wide, a base pair 0.34 nm thick. Drawn here are '
        'its first $shown, as its record reads them. Its walk begins at the '
        'gene page.';
  }

  /// Where the Atlas detects the RNA, as its distribution says: of every
  /// [one] it measured, many or some of its [many], or none.
  static String _found(AtlasReading reading, String one, String many) =>
      switch (reading.distribution) {
        'Detected in all' => 'in every $one it measured',
        'Detected in many' => 'in many of the $many it measured',
        'Detected in some' => 'in some of the $many it measured',
        'Detected in single' => 'in a single $one',
        'Not detected' => 'in none of the $many it measured',
        _ => 'in the $many it measured',
      };

  static String _lower(String name) =>
      name.isEmpty ? name : '${name[0].toLowerCase()}${name.substring(1)}';

  /// 135.1 million, or 2.8 million: millions to a decimal place, or none
  /// past a hundred.
  static String _millions(int basePairs) {
    final double m = basePairs / 1e6;
    return m >= 100
        ? '${grouped(m.round())} million'
        : '${m.toStringAsFixed(1)} million';
  }

  /// [value] to two significant figures.
  static double _round2(double value) {
    if (value <= 0) {
      return value;
    }
    double scale = 1;
    while (value * scale < 10) {
      scale *= 10;
    }
    while (value * scale >= 100) {
      scale /= 10;
    }
    return (value * scale).round() / scale;
  }
}
