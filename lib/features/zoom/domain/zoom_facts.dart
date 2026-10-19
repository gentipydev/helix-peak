import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/biology/gene_record.dart';
import '../../../shared/format.dart';
import 'anatomy_figure.dart';
import 'anatomy_tables.dart';
import 'cell_archetypes.dart';
import 'cell_parts.dart';
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

  /// One line, data only: `Tissue enriched · 125,481 nTPM`; at the cell,
  /// what its drawing shows ([ZoomFacts.cellStory]). Empty where the stop
  /// has none.
  final String line;
}

/// The words of the zoom: a [ZoomFact] for each stop, and the credit the
/// body carries. Every number about the protein comes from its locus track
/// or its record; the rest are what bodies, cells and DNA measure, said once
/// for every protein. Only the gene's own stop names the gene, as its record
/// does; no other line names a gene or a protein. Nothing explains, but at
/// the cell: what a stop shows is drawn, and the card names it; the cell's
/// line says what its drawing shows, which a reader could not tell at first
/// sight (the user's ask, 2026-10-19).
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

  ZoomFact _cell() {
    final String? cell = path.cellName;
    final String? cellClass = path.cellClass;
    final String? tissue = path.tissue;
    final String? precursor = path.landsIn?.cell ?? path.anucleate?.precursor;
    final String title = cell == null
        ? (tissue == null ? 'A cell' : '${capital(tissue)} cell')
        : capital(precursor ?? cell);
    return ZoomFact(
      stop: ZoomStop.cell,
      title: cell == null || cellClass == null ? title : '$cellClass · $title',
      line: cellStory,
    );
  }

  /// The Atlas's words for where it finds a protein secreted to, as each
  /// ends the cell's story. Every one of its secretome words that says
  /// secreted has one; the others say the protein stays in the cell.
  static const Map<String, String> secretedTo = <String, String>{
    'Secreted to blood': 'it is secreted to the blood',
    'Secreted to digestive system': 'it is secreted to the digestive system',
    'Secreted in brain': 'it is secreted in the brain',
    'Secreted in female reproductive system':
        'it is secreted in the female reproductive system',
    'Secreted in male reproductive system':
        'it is secreted in the male reproductive system',
    'Secreted in other tissues': 'it is secreted in other tissues',
    'Secreted to extracellular matrix':
        'it is secreted to the extracellular matrix',
    'Secreted - unknown location':
        'the Atlas does not say where it is secreted to',
  };

  /// What the cell's drawing shows, in a few sentences, from the track
  /// alone (the user's ask, 2026-10-19): the nucleus ringed in the mark,
  /// where its gene is transcribed; the protein glowing where the Atlas
  /// finds it; and, where the Atlas finds it secreted, the vesicles carrying
  /// it from the Golgi to the granules that store it, or else to the
  /// membrane, as the cell's scene draws them.
  String get cellStory {
    final List<String> said = <String>[];
    final String? cell = path.cellName;
    final String? precursor = path.landsIn?.cell ?? path.anucleate?.precursor;
    if (cell == null) {
      final String? top = track.cellType.first;
      said.add(
        top == null
            ? '${track.cellType.specificity}.'
            : 'Top cell type: ${lower(top)}.',
      );
    }
    said.add(
      cell != null && precursor != null
          ? '${capital(cell)} have no nucleus; the gene is transcribed in the '
                'ringed nucleus of the $precursor they come from.'
          : 'Its gene is transcribed in the ringed nucleus.',
    );
    final SubcellularReading where = track.subcellular;
    if (where.main.isNotEmpty) {
      said.add(
        where.additional.isEmpty
            ? 'The protein glows where the Atlas finds it.'
            : 'The protein glows where the Atlas finds it, fainter at its '
                  'additional locations.',
      );
    } else if (where.additional.isNotEmpty) {
      said.add('The protein glows faintly where the Atlas finds it.');
    } else if (!track.secreted) {
      said.add('The Atlas has not placed the protein in the cell.');
    }
    if (track.secreted) {
      final String word = track.secretome!;
      final bool granules = recipeOf(archetypeOf(path).shape).drawn
          .contains(CellPart.secretoryGranules);
      said.add(
        'Vesicles carry ${where.isEmpty ? 'the protein' : 'it'} from the '
        'Golgi to ${granules ? 'secretory granules' : 'the membrane'}; '
        '${secretedTo[word] ?? 'it is ${lower(word)}'}.',
      );
    }
    return said.join(' ');
  }
}
