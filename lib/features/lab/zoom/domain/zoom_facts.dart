import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../shared/format.dart';
import 'anatomy_tables.dart';
import 'locus_track.dart';
import 'zoom_depth.dart';
import 'zoom_path.dart';

/// What the level card says at one stop: the place, one line of what is
/// known of it, and where that comes from: a source, or `drawn` where the
/// stop is an illustration.
@immutable
final class ZoomFact {
  const ZoomFact({
    required this.stop,
    required this.title,
    required this.line,
    required this.source,
  });

  final ZoomStop stop;

  /// The place: `Bone marrow`, `Chromosome 11`, `HBB · 1,606 bases`.
  final String title;

  /// One line, data first: `Tissue enriched · 125,481 nTPM`.
  final String line;

  /// `HPA 25.1`, `UCSC hg38`, `RefSeq record`, or [drawn].
  final String source;

  /// The tag of a stop that is illustration, drawn the same way for every
  /// gene.
  static const String drawn = 'drawn';

  bool get isDrawn => source == drawn;
}

/// One paragraph of the About sheet: a lead, what it says, and where to read
/// it.
@immutable
final class ZoomSource {
  const ZoomSource({required this.name, required this.text, this.uri});

  final String name;
  final String text;
  final String? uri;
}

/// The words of the zoom: a [ZoomFact] for each stop and the About sheet's
/// paragraphs. Every number about the protein comes from its locus track or
/// its record; the rest are what bodies, cells and DNA measure, said once for
/// every protein. Only the gene's own stop names the gene, as its record
/// does; no other line names a gene or a protein.
final class ZoomFacts {
  ZoomFacts({
    required this.track,
    required this.path,
    required this.record,
  });

  final LocusTrack track;
  final ZoomPath path;
  final GeneRecord record;

  String get _atlas => 'HPA ${track.atlasVersion}';

  ZoomFact of(ZoomStop stop) => switch (stop) {
    ZoomStop.body => _body(),
    ZoomStop.organ => _organ(),
    ZoomStop.tissue => _tissue(),
    ZoomStop.cell => _cell(),
    ZoomStop.nucleus => ZoomFact(
      stop: stop,
      title: 'Chromosome ${track.chromosome} territory',
      line: 'One of 46 in the nucleus, each in a territory of its own',
      source: ZoomFact.drawn,
    ),
    ZoomStop.chromosome => ZoomFact(
      stop: stop,
      title: 'Chromosome ${track.chromosome}',
      line:
          '${grouped(track.length)} bp · ${spelled(track.bands.length)} bands '
          '· condensed for division',
      source: 'UCSC hg38',
    ),
    ZoomStop.band => ZoomFact(
      stop: stop,
      title: track.locus,
      line:
          '${basePairLabel(track.bandLengthBp.toDouble())} of '
          '${track.bandNames.length == 1 ? 'band' : 'bands'} · the gene at '
          '${grouped(track.spanStart)}–${grouped(track.spanEnd)}',
      source: track.maneRelease.isEmpty
          ? 'UCSC hg38'
          : 'UCSC hg38 · MANE ${track.maneRelease}',
    ),
    ZoomStop.gene => ZoomFact(
      stop: stop,
      title: '${record.gene} · ${grouped(geneBases)} bases',
      line:
          '${spelledLeading(record.exons.length)} '
          '${record.exons.length == 1 ? 'exon' : 'exons'} · '
          '${track.strand < 0 ? 'reverse' : 'forward'} strand',
      source: 'RefSeq record',
    ),
    ZoomStop.dna => ZoomFact(
      stop: stop,
      title: 'Its first ${grouped(dnaBases)} bases',
      line: '5′ ${record.sequence.substring(0, math.min(dnaBases, record.sequence.length))} 3′',
      source: 'RefSeq record',
    ),
  };

  /// How many bases the gene spans, as its record says and as the walk shows:
  /// its real span where the record's introns are shortened.
  int get geneBases => record.realSpanBp ?? record.lengthBp;

  /// How many of its first bases the DNA stop draws.
  int get dnaBases => math.min(ZoomDepth.helixBases, record.sequence.length);

  static String capital(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  static String lower(String text) =>
      text.isEmpty ? text : '${text[0].toLowerCase()}${text.substring(1)}';

  /// The other tissues the reading names, without the path's own, each once.
  List<String> get otherTissues {
    final List<String> out = <String>[];
    for (final (String name, double _) in track.tissue.specific) {
      final String tissue = ZoomPath.tissueName(name);
      if (tissue != path.tissue && !out.contains(tissue)) {
        out.add(tissue);
      }
    }
    return out;
  }

  ZoomFact _body() {
    final String? tissue = path.tissue;
    final AtlasReading reading = track.tissue;
    if (tissue == null) {
      return ZoomFact(
        stop: ZoomStop.body,
        title: reading.distribution == 'Detected in all'
            ? 'Every tissue'
            : 'No tissue stands out',
        line: '${reading.specificity} · ${lower(reading.distribution)}',
        source: _atlas,
      );
    }
    final String line = switch (path.tissueFrom) {
      TissueFrom.reading => () {
        final double ntpm = reading.specific.first.$2;
        final List<String> others = otherTissues;
        return '${reading.specificity} · ${grouped(ntpm.round())} nTPM'
            '${others.isEmpty ? '' : ' · also ${others.join(', ')}'}';
      }(),
      TissueFrom.cellHome =>
        '${reading.specificity} · home of its top cell type',
      TissueFrom.pair || null =>
        '${reading.specificity} · its tissue cell type pair',
    };
    return ZoomFact(
      stop: ZoomStop.body,
      title: capital(tissue),
      line: line,
      source: _atlas,
    );
  }

  ZoomFact _organ() {
    final String? tissue = path.tissue;
    final TissueAnatomy? anatomy = tissue == null
        ? null
        : tissueAnatomy[tissue];
    return ZoomFact(
      stop: ZoomStop.organ,
      title: tissue == null ? 'An organ' : capital(tissue),
      line: anatomy == null
          ? 'Any organ it is read in'
          : 'About ${lengthLabel(anatomy.metres)} across',
      source: ZoomFact.drawn,
    );
  }

  ZoomFact _tissue() {
    final String? tissue = path.tissue;
    return ZoomFact(
      stop: ZoomStop.tissue,
      title: tissue == null ? 'A tissue' : '${capital(tissue)}, magnified',
      line:
          'A field ${lengthLabel(ZoomDepth.tissueField)} across, stained '
          'with H&E',
      source: ZoomFact.drawn,
    );
  }

  /// The single cell reading's level for [name], or null where it names none.
  double? _ncpm(String name) {
    for (final (String n, double value) in track.cellType.specific) {
      if (n.toLowerCase() == name.toLowerCase()) {
        return value;
      }
    }
    return null;
  }

  ZoomFact _cell() {
    final String? cell = path.cellName;
    final Anucleate? anucleate = path.anucleate;
    final LandsIn? lands = path.landsIn;
    if (cell != null && (anucleate != null || lands != null)) {
      final double? ncpm = _ncpm(path.cellType!);
      final String precursor = lands?.cell ?? anucleate!.precursor;
      return ZoomFact(
        stop: ZoomStop.cell,
        title: capital(precursor),
        line:
            '${capital(cell)}${ncpm == null ? '' : ' · ${grouped(ncpm.round())} nCPM'}'
            ' · no nucleus, so its precursor',
        source: _atlas,
      );
    }
    if (cell != null) {
      final double? ncpm = _ncpm(path.cellType!);
      return ZoomFact(
        stop: ZoomStop.cell,
        title: capital(cell),
        line: path.cellFrom == CellFrom.pair || ncpm == null
            ? 'Enriched in the ${path.tissue ?? 'tissue'} · tissue cell type'
            : '${grouped(ncpm.round())} nCPM · ${track.cellType.specificity}',
        source: _atlas,
      );
    }
    final String? top = track.cellType.first;
    final String? tissue = path.tissue;
    return ZoomFact(
      stop: ZoomStop.cell,
      title: tissue == null ? 'A cell' : 'A cell of the $tissue',
      line: top == null
          ? track.cellType.specificity
          : 'Its single cell reading is highest in ${lower(top)}, elsewhere',
      source: ZoomFact.drawn,
    );
  }

  /// The About sheet: what is data and what is drawn, and every source.
  List<ZoomSource> get about => <ZoomSource>[
    const ZoomSource(
      name: 'What is drawn',
      text:
          'The body, the organ, the tissue, the cell and the nucleus are '
          'illustrations of general anatomy: every gene that goes to a tissue '
          'or to a kind of cell is shown the same one. The tissue is drawn '
          'as a section stained with haematoxylin and eosin, the cell as '
          'immunofluorescence. Which organ and which cell they are is the '
          'Human Protein Atlas’s reading; the chromosome’s bands, where the '
          'gene lies and its exons are data.',
    ),
    ZoomSource(
      name: 'Human Protein Atlas',
      text:
          'Where the gene is read: the consensus RNA reading of tissues, the '
          'single cell types, the tissue cell type pairs and where in a cell '
          'the protein is found. Version ${track.atlasVersion}, '
          '${track.atlasLicence}. The tissue and the cell are each the Atlas’s '
          'reading of many samples, not a measurement in one body.',
      uri: track.atlasUrl.isEmpty
          ? null
          : track.atlasUrl.replaceFirst(RegExp(r'\.json$'), ''),
    ),
    ZoomSource(
      name: 'Bands',
      text:
          'The UCSC Genome Browser’s cytoBand table for hg38, updated '
          '${track.cytobandUpdated.split('T').first}. A band is a stain '
          'pattern seen down a microscope at low resolution, millions of base '
          'pairs long: it says where the gene lies, and the gene itself is '
          'far too small to see in it.',
      uri: 'https://genome.ucsc.edu/',
    ),
    ZoomSource(
      name: 'Where it lies',
      text:
          'The span of its MANE Select transcript on GRCh38'
          '${track.maneRelease.isEmpty ? '' : ', release ${track.maneRelease}'}. '
          'Its exons and first bases are the RefSeq record the walk reads, '
          'whose outer ends can differ from the span by a few bases.',
    ),
    const ZoomSource(
      name: 'Territories',
      text:
          'Gene-dense chromosomes are drawn toward the nucleus’s centre and '
          'gene-poor ones at its rim, in the order Boyle et al. (2001) and '
          'Croft et al. (1999) measured; the places themselves are drawn.',
    ),
  ];
}
