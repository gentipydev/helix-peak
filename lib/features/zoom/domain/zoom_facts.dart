import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/biology/gene_record.dart';
import '../../../shared/format.dart';
import 'anatomy_figure.dart';
import 'anatomy_tables.dart';
import 'cell_archetypes.dart';
import 'locus_track.dart';
import 'zoom_depth.dart';
import 'zoom_path.dart';

/// What the card says at one stop: the place, and one line of what is known
/// of it, or none where the stop has nothing to add to its name.
@immutable
final class ZoomFact {
  const ZoomFact({required this.stop, required this.title, this.line = ''});

  final ZoomStop stop;

  /// The place: `Bone marrow`, `Chromosome 11`, `HBB · 1,606 bases`.
  final String title;

  /// One line, data only: `Tissue enriched · 125,481 nTPM`. Empty where the
  /// stop has none.
  final String line;
}

/// The words of the zoom: a [ZoomFact] for each stop, and the credit the
/// body carries. Every number about the protein comes from its locus track
/// or its record; the rest are what bodies, cells and DNA measure, said once
/// for every protein. Only the gene's own stop names the gene, as its record
/// does; no other line names a gene or a protein. Nothing explains: what a
/// stop shows is drawn, and the card names it.
final class ZoomFacts {
  ZoomFacts({required this.track, required this.path, required this.record});

  final LocusTrack track;
  final ZoomPath path;
  final GeneRecord record;

  ZoomFact of(ZoomStop stop) => switch (stop) {
    ZoomStop.body => _body(),
    ZoomStop.organ => _organ(),
    ZoomStop.tissue => ZoomFact(stop: stop, title: architecture),
    ZoomStop.cell => _cell(),
    ZoomStop.nucleus => ZoomFact(
      stop: stop,
      title: 'Chromosome ${track.chromosome} territory',
    ),
    ZoomStop.chromosome => ZoomFact(
      stop: stop,
      title: 'Chromosome ${track.chromosome}',
      line:
          '${grouped(track.length)} bp · '
          '${spelled(track.bands.length)} bands',
    ),
    ZoomStop.band => ZoomFact(
      stop: stop,
      title: track.locus,
      line:
          '${basePairLabel(track.bandLengthBp.toDouble())} · gene at '
          '${grouped(track.spanStart)}–${grouped(track.spanEnd)}',
    ),
    ZoomStop.gene => ZoomFact(
      stop: stop,
      title: '${record.gene} · ${grouped(geneBases)} bases',
      line:
          '${spelledLeading(record.exons.length)} '
          '${record.exons.length == 1 ? 'exon' : 'exons'} · '
          '${track.strand < 0 ? 'reverse' : 'forward'} strand',
    ),
    ZoomStop.dna => ZoomFact(
      stop: stop,
      title: 'First ${grouped(dnaBases)} bases',
      line:
          '5′ ${record.sequence.substring(0, math.min(dnaBases, record.sequence.length))} 3′',
    ),
  };

  /// How many bases the gene spans, as its record says and as the walk shows:
  /// its real span where the record's introns are shortened.
  int get geneBases => record.realSpanBp ?? record.lengthBp;

  /// How many of its first bases the DNA stop draws.
  int get dnaBases => math.min(ZoomDepth.helixBases, record.sequence.length);

  /// The credit the body carries for what it is drawn from: the
  /// anatomogram's makers and the Atlas's version, under their licence,
  /// named once where the two share it.
  String get credit {
    final String atlas = 'HPA ${track.atlasVersion}';
    return track.atlasLicence == AnatomyFigure.licence
        ? '${AnatomyFigure.credit} · $atlas · ${AnatomyFigure.licence}'
        : '${AnatomyFigure.credit}, ${AnatomyFigure.licence} · $atlas, '
              '${track.atlasLicence}';
  }

  /// What the tissue stop shows, by the recipe its slide is laid by: the
  /// architecture a pathologist would name, the same for every gene whose
  /// path goes there with the same kind of cell.
  String get architecture {
    final String? tissue = path.tissue;
    final TissueRecipe recipe =
        (tissue == null ? null : tissueAnatomy[tissue])?.recipe ??
        TissueRecipe.squamous;
    final CellShape shape = archetypeOf(path).shape;
    return switch (recipe) {
      TissueRecipe.acinar => switch (shape) {
        CellShape.endocrine => 'Islet',
        CellShape.epithelial => 'Ducts',
        _ => 'Acini',
      },
      TissueRecipe.adipose => 'Fat lobules',
      TissueRecipe.alveolar => 'Alveoli',
      TissueRecipe.cardiac => 'Cardiac muscle',
      TissueRecipe.choroidPlexus => 'Choroid plexus',
      TissueRecipe.endocrine => 'Endocrine cords',
      TissueRecipe.follicular => 'Follicles',
      TissueRecipe.gastric => 'Gastric glands',
      TissueRecipe.glandular => 'Mucosal folds',
      TissueRecipe.hepatic => 'Hepatic plates',
      TissueRecipe.intestinal => 'Villi and crypts',
      TissueRecipe.lymphoid => 'Lymph node',
      TissueRecipe.marrow =>
        shape == CellShape.erythroid ? 'Erythroblastic island' : 'Marrow',
      TissueRecipe.neural => 'Grey matter',
      TissueRecipe.ovarian => 'Ovarian stroma',
      TissueRecipe.placental => 'Chorionic villi',
      TissueRecipe.renal => 'Tubules',
      TissueRecipe.retina => 'Retina',
      TissueRecipe.seminiferous => 'Seminiferous tubules',
      TissueRecipe.skeletalMuscle => 'Muscle fibres',
      TissueRecipe.smoothMuscle => 'Smooth muscle',
      TissueRecipe.squamous => 'Squamous epithelium',
      TissueRecipe.urothelial => 'Urothelium',
      TissueRecipe.vascular => 'Vessel wall',
    };
  }

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
      );
    }
    final String line = switch (path.tissueFrom) {
      TissueFrom.reading => () {
        final double ntpm = reading.specific.first.$2;
        final List<String> others = otherTissues;
        return '${reading.specificity} · ${grouped(ntpm.round())} nTPM'
            '${others.isEmpty ? '' : ' · also ${others.join(', ')}'}';
      }(),
      _ => reading.specificity,
    };
    return ZoomFact(stop: ZoomStop.body, title: capital(tissue), line: line);
  }

  ZoomFact _organ() {
    final String? tissue = path.tissue;
    final TissueAnatomy? anatomy = tissue == null
        ? null
        : tissueAnatomy[tissue];
    if (tissue == null || anatomy == null) {
      return const ZoomFact(stop: ZoomStop.organ, title: 'An organ');
    }
    final String size = lengthLabel(anatomy.metres);
    return ZoomFact(
      stop: ZoomStop.organ,
      title: capital(tissue),
      line: anatomy.inBrain != null && tissue != 'brain'
          ? 'In the brain · about $size'
          : 'About $size',
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
            ' · no nucleus',
      );
    }
    if (cell != null) {
      final double? ncpm = _ncpm(path.cellType!);
      return ZoomFact(
        stop: ZoomStop.cell,
        title: capital(cell),
        line: path.cellFrom == CellFrom.pair || ncpm == null
            ? 'Tissue cell type enriched'
            : '${grouped(ncpm.round())} nCPM · ${track.cellType.specificity}',
      );
    }
    final String? top = track.cellType.first;
    final String? tissue = path.tissue;
    return ZoomFact(
      stop: ZoomStop.cell,
      title: tissue == null ? 'A cell' : '${capital(tissue)} cell',
      line: top == null
          ? track.cellType.specificity
          : 'Top cell type: ${lower(top)}',
    );
  }
}
