import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/lab/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/lab/zoom/domain/gene_layout.dart';
import 'package:helixpeek/features/lab/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_camera.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_facts.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_path.dart';

import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';
import '../zoom_fixtures.dart';

/// The Human Protein Atlas's consensus tissues, version 25.1, as its search
/// vocabulary lists them: every name a gene's tissue reading can give.
const List<String> atlasTissues = <String>[
  'adipose tissue', 'adrenal gland', 'blood vessel', 'bone marrow', 'brain', //
  'breast', 'cervix', 'choroid plexus', 'endometrium', 'epididymis',
  'esophagus', 'fallopian tube', 'gallbladder', 'heart muscle', 'intestine',
  'kidney', 'liver', 'lung', 'lymphoid tissue', 'ovary', 'pancreas',
  'parathyroid gland', 'pituitary gland', 'placenta', 'prostate', 'retina',
  'salivary gland', 'seminal vesicle', 'skeletal muscle', 'skin',
  'smooth muscle', 'stomach', 'testis', 'thyroid gland', 'tongue',
  'urinary bladder', 'vagina',
];

/// The path the bake chose for each protein, as its README tabulates it:
/// organ, how it was chosen, cell (null where none of the organ's is named),
/// how that was chosen.
const Map<String, (String, TissueFrom, String?, CellFrom?)> bakedPaths =
    <String, (String, TissueFrom, String?, CellFrom?)>{
      'insulin': ('pancreas', TissueFrom.reading, 'Beta cells', CellFrom.pair),
      'glucagon': ('pancreas', TissueFrom.reading, 'Alpha cells', CellFrom.pair),
      'cftr': (
        'pancreas',
        TissueFrom.reading,
        'Pancreatic duct cells',
        CellFrom.singleCell,
      ),
      'amylase': (
        'salivary gland',
        TissueFrom.reading,
        'Salivary acinar cells',
        CellFrom.singleCell,
      ),
      'lysozyme': (
        'salivary gland',
        TissueFrom.reading,
        'Minor salivary glandular cells',
        CellFrom.pair,
      ),
      'hemoglobin': (
        'bone marrow',
        TissueFrom.reading,
        'Erythrocytes',
        CellFrom.singleCell,
      ),
      'tnf': ('bone marrow', TissueFrom.reading, null, null),
      'erythropoietin': (
        'liver',
        TissueFrom.reading,
        'Hepatocytes',
        CellFrom.singleCell,
      ),
      'sod1': ('liver', TissueFrom.reading, 'Hepatocytes', CellFrom.pair),
      'leptin': (
        'adipose tissue',
        TissueFrom.reading,
        'Adipocytes (Subcutaneous)',
        CellFrom.pair,
      ),
      'myoglobin': (
        'skeletal muscle',
        TissueFrom.reading,
        'Skeletal myocytes',
        CellFrom.pair,
      ),
      'dystrophin': (
        'skeletal muscle',
        TissueFrom.cellHome,
        'Myonuclei',
        CellFrom.singleCell,
      ),
      'oxytocin': (
        'brain',
        TissueFrom.reading,
        'Other brain neurons',
        CellFrom.singleCell,
      ),
      'vasopressin': (
        'brain',
        TissueFrom.reading,
        'Other brain neurons',
        CellFrom.singleCell,
      ),
      'prion': ('choroid plexus', TissueFrom.reading, null, null),
      'somatotropin': (
        'pituitary gland',
        TissueFrom.reading,
        'Somatotropes',
        CellFrom.pair,
      ),
      'relaxin': (
        'fallopian tube',
        TissueFrom.reading,
        'Fallopian tube ciliated cells',
        CellFrom.singleCell,
      ),
      'ubiquitin': (
        'testis',
        TissueFrom.cellHome,
        'Late primary spermatocytes',
        CellFrom.singleCell,
      ),
      'app': (
        'lymphoid tissue',
        TissueFrom.cellHome,
        'Lymphatic endothelial cells',
        CellFrom.singleCell,
      ),
      'p53': ('stomach', TissueFrom.pair, 'Mitotic cells (Stomach)', CellFrom.pair),
    };

ZoomPath _path(ProteinTarget t) => ZoomPath.of(locusOf(t));

ZoomDepth _depth(ProteinTarget t) => ZoomDepth(locusOf(t), path: _path(t));

ZoomFacts _facts(ProteinTarget t) =>
    ZoomFacts(track: locusOf(t), path: _path(t), record: recordOf(t));

void main() {
  group('the locus track', () {
    test('reads all twenty at schema 2, each its chromosome whole', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final LocusTrack track = locusOf(t);
        expect(track.schemaVersion, 2, reason: t.slug);
        expect(track.path, isNotNull, reason: t.slug);
        expect(track.bands.first.start, 1, reason: t.slug);
        expect(track.bands.last.end, track.length);
        expect(track.bandStart, lessThanOrEqualTo(track.spanStart));
        expect(track.bandEnd, greaterThanOrEqualTo(track.spanEnd));
        expect(track.locus, startsWith(track.chromosome));
        expect(track.atlasLicence, 'CC BY 4.0');
        expect(track.maneRelease, 'v1.5');
      }
    });

    test('places the known genes at their bands', () {
      expect(locusOf(TestCatalog.insulin).locus, '11p15.5');
      expect(locusOf(TestCatalog.hemoglobin).locus, '11p15.4');
      final LocusTrack dmd = locusOf(TestCatalog.dystrophin);
      expect(dmd.bandNames, <String>['p21.2', 'p21.1']);
      expect(dmd.locus, 'Xp21.2-p21.1');
      expect(dmd.geneLengthBp, greaterThan(2000000));
    });

    test('reads the Atlas’s pairs, locations and secretome', () {
      final LocusTrack insulin = locusOf(TestCatalog.insulin);
      expect(
        insulin.tissueCellTypes.map((TissueCellPair p) => p.cellType),
        contains('Beta cells'),
      );
      expect(insulin.secretome, 'Secreted to blood');
      final LocusTrack p53 = locusOf(TestCatalog.p53);
      expect(p53.subcellular.main, <String>['Nucleoplasm']);
      expect(p53.subcellular.additional, <String>['Vesicles', 'Cytosol']);
      expect(locusOf(TestCatalog.myoglobin).subcellular.isEmpty, isTrue);
    });

    test('reads a schema 1 payload, with no path', () {
      final Map<String, dynamic> json =
          jsonDecode(
                File(
                  'test/features/lab/zoom/fixtures/v1/hemoglobin_locus.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final LocusTrack track = LocusTrack.fromJson(json, TestCatalog.hemoglobin);
      expect(track.schemaVersion, 1);
      expect(track.path, isNull);
      expect(track.tissueCellTypes, isEmpty);
      final ZoomPath path = ZoomPath.of(track);
      expect(path.baked, isFalse);
      expect(path.tissue, 'bone marrow');
      expect(path.anucleate, same(anucleateCellTypes['Erythrocytes']));
    });

    test('refuses a payload for another protein', () {
      expect(
        () => LocusTrack.fromJson(
          locusJson(TestCatalog.insulin),
          TestCatalog.hemoglobin,
        ),
        throwsFormatException,
      );
    });

    test('refuses bands that are not the chromosome whole', () {
      final Map<String, dynamic> json = locusJson(TestCatalog.insulin);
      (json['bands'] as List<dynamic>).removeAt(3);
      expect(
        () => LocusTrack.fromJson(json, TestCatalog.insulin),
        throwsFormatException,
      );
    });
  });

  group('the path', () {
    test('is the one the bake chose, for every protein', () {
      expect(bakedPaths.keys.toSet(), <String>{
        for (final ProteinTarget t in TestCatalog.all) t.slug,
      });
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomPath path = _path(t);
        final (String tissue, TissueFrom from, String? cell, CellFrom? how) =
            bakedPaths[t.slug]!;
        expect(path.baked, isTrue);
        expect(path.tissue, tissue, reason: t.slug);
        expect(path.tissueFrom, from, reason: t.slug);
        expect(path.cellType, cell, reason: t.slug);
        expect(path.cellFrom, how, reason: t.slug);
        expect(path.cellClass == null, cell == null, reason: t.slug);
      }
    });

    test('lands in a precursor where the cells have no nucleus, read from the '
        'Atlas, not from the protein', () {
      final ZoomPath hemoglobin = _path(TestCatalog.hemoglobin);
      expect(hemoglobin.landsIn?.cell, 'erythroblasts');
      expect(hemoglobin.anucleate, same(anucleateCellTypes['Erythrocytes']));
      expect(
        <String>[
          for (final ProteinTarget t in TestCatalog.all)
            if (_path(t).anucleate != null) t.slug,
        ],
        <String>[TestCatalog.hemoglobin.slug],
      );
    });

    test('names a cell without the qualifier the Atlas puts on a pair', () {
      expect(_path(TestCatalog.p53).cellName, 'Mitotic cells');
      expect(_path(TestCatalog.leptin).cellName, 'Adipocytes');
      expect(_path(TestCatalog.insulin).cellName, 'Beta cells');
    });

    test('names a tissue without the sample number the Atlas gives some', () {
      expect(ZoomPath.tissueName('stomach 1'), 'stomach');
      expect(ZoomPath.tissueName('bone marrow'), 'bone marrow');
    });
  });

  group('the anatomy tables', () {
    test('draw every tissue the Atlas names, once each', () {
      expect(tissueAnatomy.keys.toSet(), atlasTissues.toSet());
      for (final String tissue in atlasTissues) {
        expect(placeOf(tissue), isNotNull, reason: tissue);
        final TissueAnatomy anatomy = tissueAnatomy[tissue]!;
        expect(anatomy.metres, inExclusiveRange(1e-3, 1.0), reason: tissue);
        expect(anatomy.uberon, startsWith('UBERON_'), reason: tissue);
      }
    });

    test('keep a body’s own organs for the body that has them', () {
      final Set<String> female = <String>{
        for (final MapEntry<String, TissueAnatomy> e in tissueAnatomy.entries)
          if (e.value.sex == BodySex.female) e.key,
      };
      final Set<String> male = <String>{
        for (final MapEntry<String, TissueAnatomy> e in tissueAnatomy.entries)
          if (e.value.sex == BodySex.male) e.key,
      };
      expect(female, <String>{
        'cervix', 'endometrium', 'fallopian tube', 'ovary', 'placenta', //
        'vagina',
      });
      expect(male, <String>{
        'epididymis', 'prostate', 'seminal vesicle', 'testis',
      });
    });

    test('place every chromosome’s territory inside the nucleus', () {
      for (int n = 1; n <= 22; n++) {
        expect(territoryRadius['$n'], inExclusiveRange(0, 1), reason: '$n');
      }
      expect(territoryRadius['X'], inExclusiveRange(0, 1));
      expect(territoryRadius['Y'], inExclusiveRange(0, 1));
      // Gene-dense 19 inward, gene-poor 18 at the rim.
      expect(territoryRadius['19']!, lessThan(territoryRadius['18']!));
    });
  });

  group('the cells', () {
    test('draw each of the twenty’s cells in its own kind’s shape', () {
      const Map<String, CellShape> expected = <String, CellShape>{
        'insulin': CellShape.endocrine,
        'glucagon': CellShape.endocrine,
        'somatotropin': CellShape.endocrine,
        'cftr': CellShape.epithelial,
        'amylase': CellShape.acinar,
        'lysozyme': CellShape.acinar,
        'hemoglobin': CellShape.erythroid,
        'tnf': CellShape.leukocyte,
        'erythropoietin': CellShape.hepatocyte,
        'sod1': CellShape.hepatocyte,
        'leptin': CellShape.adipocyte,
        'myoglobin': CellShape.myofibre,
        'dystrophin': CellShape.myofibre,
        'oxytocin': CellShape.neuron,
        'vasopressin': CellShape.neuron,
        'prion': CellShape.ciliated,
        'relaxin': CellShape.ciliated,
        'ubiquitin': CellShape.germ,
        'app': CellShape.endothelial,
        'p53': CellShape.dividing,
      };
      for (final ProteinTarget t in TestCatalog.all) {
        expect(
          archetypeOf(_path(t)).shape,
          expected[t.slug],
          reason: t.slug,
        );
      }
    });

    test('give every one of the Atlas’s classes a shape', () {
      for (final String cellClass in <String>[
        'Neuronal cells', 'Glial cells', 'Endocrine cells', //
        'Squamous epithelial cells', 'Pigment cells', 'Ciliated cells',
        'Specialized epithelial cells', 'Glandular epithelial cells',
        'Germ cells', 'Trophoblast cells', 'Muscle cells',
        'Endothelial and mural cells', 'Mesenchymal cells',
        'Blood and immune cells', 'Stem and proliferating cells',
      ]) {
        expect(shapeOfCell('Any cells', cellClass), isNotNull);
      }
      for (final TissueRecipe recipe in TissueRecipe.values) {
        expect(shapeOfTissue(recipe), isNotNull);
      }
    });

    test('draw every subcellular word the Atlas uses, and every one the '
        'twenty name', () {
      const List<String> atlasWords = <String>[
        'Acrosome', 'Actin filaments', 'Aggresome', 'Annulus', 'Basal body', //
        'Calyx', 'Cell Junctions', 'Centriolar satellite', 'Centrosome',
        'Cleavage furrow', 'Connecting piece', 'Cytokinetic bridge',
        'Cytoplasmic bodies', 'Cytosol', 'End piece', 'Endoplasmic reticulum',
        'Endosomes', 'Equatorial segment', 'Flagellar centriole',
        'Focal adhesion sites', 'Golgi apparatus', 'Intermediate filaments',
        'Kinetochore', 'Lipid droplets', 'Lysosomes', 'Microtubule ends',
        'Microtubules', 'Mid piece', 'Midbody', 'Midbody ring',
        'Mitochondria', 'Mitotic chromosome', 'Mitotic spindle',
        'Nuclear bodies', 'Nuclear membrane', 'Nuclear speckles', 'Nucleoli',
        'Nucleoli fibrillar center', 'Nucleoli rim', 'Nucleoplasm',
        'Perinuclear theca', 'Peroxisomes', 'Plasma membrane',
        'Primary cilium', 'Primary cilium tip',
        'Primary cilium transition zone', 'Principal piece', 'Rods & Rings',
        'Vesicles',
      ];
      expect(compartmentOf.keys.toSet(), atlasWords.toSet());
      for (final ProteinTarget t in TestCatalog.all) {
        final LocusTrack track = locusOf(t);
        for (final String word in <String>[
          ...track.subcellular.main,
          ...track.subcellular.additional,
        ]) {
          expect(compartmentOf[word], isNotNull, reason: '${t.slug} $word');
        }
      }
    });

    test('frame a nucleus with room for its chromosome, and a cell with '
        'room for its nucleus', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomDepth depth = _depth(t);
        expect(
          depth.widthOf(ZoomStop.nucleus),
          greaterThanOrEqualTo(1.15 * depth.widthOf(ZoomStop.chromosome) - 1e-18),
          reason: t.slug,
        );
        expect(
          depth.widthOf(ZoomStop.cell),
          greaterThanOrEqualTo(1.3 * depth.widthOf(ZoomStop.nucleus) - 1e-18),
          reason: t.slug,
        );
        expect(
          depth.widthOf(ZoomStop.nucleus),
          greaterThanOrEqualTo(depth.archetype.nucleus),
          reason: t.slug,
        );
      }
    });
  });

  group('the depth', () {
    test('runs from the body down to the DNA without turning back, for all '
        'twenty', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomDepth depth = _depth(t);
        for (int k = 0; k + 1 < ZoomStop.values.length; k++) {
          expect(depth.ratioOf(k), lessThan(1), reason: '${t.slug} $k');
          expect(
            depth.travelOf(k),
            greaterThanOrEqualTo(ZoomDepth.minimumTravel),
          );
          expect(
            depth.depthOf(ZoomStop.values[k + 1]),
            greaterThan(depth.depthOf(ZoomStop.values[k])),
          );
        }
        expect(depth.depthOf(ZoomStop.body), 0);
        expect(depth.depthOf(ZoomStop.dna), depth.total);
      }
    });

    test('narrows by the same factor for each equal step within a segment', () {
      final ZoomDepth depth = _depth(TestCatalog.insulin);
      final double a = depth.depthOf(ZoomStop.organ);
      final double t = depth.travelOf(ZoomStop.organ.index);
      final double w0 = depth.widthAt(a);
      final double w1 = depth.widthAt(a + t / 4);
      final double w2 = depth.widthAt(a + t / 2);
      expect(w1 / w0, closeTo(w2 / w1, 1e-9));
      expect(depth.widthAt(a), closeTo(depth.widthOf(ZoomStop.organ), 1e-12));
    });

    test('reads in metres to the chromosome and in base pairs past it', () {
      final ZoomDepth depth = _depth(TestCatalog.hemoglobin);
      expect(depth.unitAt(depth.depthOf(ZoomStop.nucleus)), ZoomUnit.metres);
      expect(depth.unitAt(depth.depthOf(ZoomStop.chromosome)), ZoomUnit.metres);
      expect(depth.unitAt(depth.depthOf(ZoomStop.band)), ZoomUnit.basePairs);
      expect(depth.widthLabel(depth.depthOf(ZoomStop.body)), '2.2 m');
      expect(depth.widthLabel(depth.depthOf(ZoomStop.tissue)), '500 µm');
      expect(depth.widthLabel(depth.depthOf(ZoomStop.dna)), '35 bp');
      // The chromosome condensed: micrometres, not millimetres.
      expect(
        depth.widthAt(depth.depthOf(ZoomStop.chromosome)),
        inInclusiveRange(1e-6, 2e-5),
      );
    });

    test('maps the rail evenly by stop, and back', () {
      final ZoomDepth depth = _depth(TestCatalog.dystrophin);
      for (final ZoomStop stop in ZoomStop.values) {
        expect(
          depth.railOf(depth.depthOf(stop)),
          closeTo(stop.index / (ZoomStop.values.length - 1), 1e-12),
        );
      }
      for (int i = 0; i <= 100; i++) {
        final double d = depth.total * i / 100;
        expect(depth.depthAtRail(depth.railOf(d)), closeTo(d, 1e-9));
      }
    });

    test('labels lengths and stretches of the genome as each reads best', () {
      expect(lengthLabel(2.2), '2.2 m');
      expect(lengthLabel(0.05), '5 cm');
      expect(lengthLabel(4e-5), '40 µm');
      expect(lengthLabel(1.2e-8), '12 nm');
      expect(basePairLabel(135086622), '135 Mb');
      expect(basePairLabel(3200000), '3.2 Mb');
      expect(basePairLabel(1608), '1.6 kb');
      expect(basePairLabel(33), '33 bp');
      final (double _, double px, String label) = scaleBar(
        3e6,
        390,
        unit: ZoomUnit.basePairs,
      );
      expect(label, '500 kb');
      expect(px, closeTo(65, 0.01));
    });
  });

  group('the camera', () {
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.hemoglobin,
      TestCatalog.dystrophin,
      TestCatalog.amylase,
      TestCatalog.p53,
    ]) {
      test('keeps the next stop on screen and moves without a jump: ${t.slug}',
          () {
        final ZoomDepth depth = _depth(t);
        const Size size = Size(390, 560);
        // A portal well off-centre in every scene: the hardest case.
        const Offset portal = Offset(0.3, -0.4);
        final ZoomCamera camera = ZoomCamera(
          depth,
          portalOf: (ZoomStop stop) => portal,
        );
        Offset? last;
        Offset? before;
        int? segment;
        const int steps = 4000;
        for (int i = 0; i <= steps; i++) {
          final double d = depth.total * i / steps;
          final (ZoomView parent, ZoomView child) = camera.at(d, size);
          final Offset onScreen = parent.toScreen(portal, size);
          expect(onScreen.dx, inInclusiveRange(-1e-6, size.width + 1e-6));
          // The child's origin is the parent's portal, at the segment's scale.
          final Offset childOrigin = child.toScreen(Offset.zero, size);
          expect((childOrigin - onScreen).distance, lessThan(1e-6));
          expect(
            child.pixelsPerUnit / parent.pixelsPerUnit,
            closeTo(depth.ratioOf(parent.stop.index), 1e-9),
          );
          // Within a segment the portal glides without a jolt.
          if (segment != parent.stop.index) {
            segment = parent.stop.index;
            last = null;
            before = null;
          }
          if (last != null && before != null) {
            final Offset jerk = childOrigin - last * 2 + before;
            expect(jerk.distance, lessThan(1.5), reason: 'd = $d');
          }
          before = last;
          last = childOrigin;
        }
        // Across each stop, the scene both segments draw is drawn the same.
        for (final ZoomStop stop in ZoomStop.values.skip(1).take(7)) {
          final double at = depth.depthOf(stop);
          final (ZoomView _, ZoomView entering) = camera.at(at - 1e-9, size);
          final (ZoomView leaving, ZoomView _) = camera.at(at, size);
          expect(entering.stop, stop);
          expect(leaving.stop, stop);
          expect(
            entering.pixelsPerUnit,
            closeTo(leaving.pixelsPerUnit, leaving.pixelsPerUnit * 1e-6),
          );
          expect(
            (entering.toScreen(portal, size) - leaving.toScreen(portal, size))
                .distance,
            lessThan(0.01),
          );
        }
      });
    }

    test('frames each stop whole, at its own scale, at its depth', () {
      final ZoomDepth depth = _depth(TestCatalog.insulin);
      final ZoomCamera camera = ZoomCamera(
        depth,
        portalOf: (ZoomStop stop) => const Offset(0.2, 0.1),
      );
      for (final ZoomStop stop in ZoomStop.values.take(8)) {
        final (ZoomView parent, ZoomView _) = camera.at(
          depth.depthOf(stop),
          const Size(390, 560),
        );
        expect(parent.stop, stop);
        expect(parent.pixelsPerUnit, closeTo(390, 1e-6));
        expect(parent.centre.distance, lessThan(1e-9));
      }
    });
  });

  group('the motion', () {
    test('takes longer to fly further, within bounds', () {
      expect(flightDuration(0, 0.1), const Duration(milliseconds: 450));
      expect(flightDuration(0, 1).inMilliseconds, 610);
      expect(flightDuration(0, 40), const Duration(milliseconds: 2600));
      final ZoomFlight flight = ZoomFlight(1, 3);
      expect(flight.at(Duration.zero), 1);
      expect(flight.at(flight.duration), 3);
      expect(flight.at(flight.duration ~/ 2), closeTo(2, 1e-9));
    });

    test('coasts a flick to the stop it would reach', () {
      final ZoomDepth depth = _depth(TestCatalog.insulin);
      final double cell = depth.depthOf(ZoomStop.cell);
      expect(flingTarget(depth, cell, 0), ZoomStop.cell);
      expect(flingTarget(depth, cell, 8), isNot(ZoomStop.cell));
      expect(flingTarget(depth, cell, -100), ZoomStop.body);
    });

    test('plays the dive from the body to the DNA, resting at each stop', () {
      final ZoomDepth depth = _depth(TestCatalog.hemoglobin);
      final PlaySchedule play = PlaySchedule(depth, from: 0);
      expect(play.length.inSeconds, inInclusiveRange(18, 32));
      expect(play.at(Duration.zero), 0);
      // Resting at the body for its dwell.
      expect(play.at(const Duration(milliseconds: 1400)), 0);
      expect(play.at(play.length), depth.total);
      double previous = -1;
      for (int ms = 0; ms <= play.length.inMilliseconds; ms += 50) {
        final double d = play.at(Duration(milliseconds: ms));
        expect(d, greaterThanOrEqualTo(previous - 1e-12));
        previous = d;
      }
      final PlaySchedule stepped = PlaySchedule(
        depth,
        from: 0,
        stepped: true,
      );
      expect(stepped.length, PlaySchedule.steppedHold * ZoomStop.values.length);
      expect(
        stepped.at(PlaySchedule.steppedHold + const Duration(milliseconds: 1)),
        depth.depthOf(ZoomStop.organ),
      );
    });
  });

  group('the gene layout', () {
    test('lays every gene out from its 5′ end, its parts in order', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final GeneRecord record = recordOf(t);
        final GeneLayout layout = GeneLayout.of(record);
        expect(layout.pieces, isNotEmpty, reason: t.slug);
        expect(layout.exonCount, record.exons.length, reason: t.slug);
        double at = layout.pieces.first.start;
        for (final GenePiece piece in layout.pieces) {
          expect(piece.start, closeTo(at, 1e-6), reason: t.slug);
          expect(piece.end, greaterThan(piece.start), reason: t.slug);
          at = piece.end;
        }
        expect(at, lessThanOrEqualTo(layout.length + 1e-6), reason: t.slug);
        final double coding = layout.pieces
            .where((GenePiece p) => p.kind == GenePieceKind.cds)
            .fold<double>(0, (double sum, GenePiece p) => sum + p.length);
        final int cds = (record.protein?.segments ?? <Segment>[]).fold<int>(
          0,
          (int sum, Segment s) => sum + s.lengthBp,
        );
        expect(coding, closeTo(cds.toDouble(), 1e-6), reason: t.slug);
      }
    });

    test('draws shortened introns at their real length', () {
      for (final ProteinTarget t in <ProteinTarget>[
        TestCatalog.dystrophin,
        TestCatalog.app,
        TestCatalog.cftr,
      ]) {
        final GeneRecord record = recordOf(t);
        expect(record.isIntronCompressed, isTrue, reason: t.slug);
        final GeneLayout layout = GeneLayout.of(record);
        final List<double> introns = <double>[
          for (final GenePiece p in layout.pieces)
            if (p.kind == GenePieceKind.intron) p.length,
        ];
        expect(
          introns,
          <double>[for (final int bp in record.realIntronBp!) bp.toDouble()],
          reason: t.slug,
        );
        expect(layout.length, record.realSpanBp!.toDouble(), reason: t.slug);
      }
    });
  });

  group('the facts', () {
    test('name no protein, and the gene only at its own stop', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomFacts facts = _facts(t);
        for (final ProteinTarget other in TestCatalog.all) {
          // A protein's name and slug in any case; a gene symbol as it is
          // written, so a unit (`Mb`) is not taken for a gene (`MB`).
          final List<RegExp> names = <RegExp>[
            RegExp(
              '\\b${RegExp.escape(other.display)}\\b',
              caseSensitive: false,
            ),
            RegExp('\\b${RegExp.escape(other.slug)}\\b'),
            if (other.slug != t.slug)
              RegExp('\\b${RegExp.escape(other.gene)}\\b'),
          ];
          for (final ZoomStop stop in ZoomStop.values) {
            final ZoomFact fact = facts.of(stop);
            final String words = stop == ZoomStop.gene
                ? fact.line
                : '${fact.title} ${fact.line}';
            for (final RegExp name in names) {
              expect(
                name.hasMatch(words),
                isFalse,
                reason: '${t.slug} at ${stop.name} names ${name.pattern}',
              );
            }
          }
        }
        expect(facts.of(ZoomStop.gene).title, startsWith('${t.gene} · '));
      }
    });

    test('group every number of a thousand or more', () {
      final RegExp ungrouped = RegExp(r'(?<![\d,])\d{4,}');
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomFacts facts = _facts(t);
        for (final ZoomStop stop in ZoomStop.values) {
          if (stop == ZoomStop.dna) {
            continue;
          }
          final ZoomFact fact = facts.of(stop);
          expect(
            ungrouped.hasMatch('${fact.title} ${fact.line}'),
            isFalse,
            reason: '${t.slug} ${stop.name}: ${fact.title} · ${fact.line}',
          );
        }
      }
    });

    test('say where each line comes from, and which stops are drawn', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomFacts facts = _facts(t);
        expect(facts.of(ZoomStop.body).source, 'HPA 25.1');
        for (final ZoomStop stop in <ZoomStop>[
          ZoomStop.organ,
          ZoomStop.tissue,
          ZoomStop.nucleus,
        ]) {
          expect(facts.of(stop).isDrawn, isTrue, reason: '${t.slug} $stop');
        }
        expect(facts.of(ZoomStop.chromosome).source, 'UCSC hg38');
        expect(facts.of(ZoomStop.gene).source, 'RefSeq record');
        expect(
          facts.of(ZoomStop.cell).isDrawn,
          _path(t).cellType == null,
          reason: t.slug,
        );
      }
    });

    test('say out loud where the zoom lands instead of a nucleus it lacks', () {
      final ZoomFact cell = _facts(TestCatalog.hemoglobin).of(ZoomStop.cell);
      expect(cell.title, 'Erythroblasts');
      expect(cell.line, contains('Erythrocytes · 521,403 nCPM'));
      expect(cell.line, contains('no nucleus'));
      expect(
        _facts(TestCatalog.insulin).of(ZoomStop.cell).line,
        isNot(contains('no nucleus')),
      );
    });

    test('say the Atlas’s top cell type where none of the organ’s stands '
        'out', () {
      final ZoomFact tnf = _facts(TestCatalog.tnf).of(ZoomStop.cell);
      expect(tnf.title, 'A cell of the bone marrow');
      expect(tnf.line, contains('highest in microglia'));
      expect(tnf.isDrawn, isTrue);
    });

    test('give the gene’s length as its record does, the walk’s', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final GeneRecord record = recordOf(t);
        final int bases = record.realSpanBp ?? record.lengthBp;
        final String title = _facts(t).of(ZoomStop.gene).title;
        expect(title, contains(' · '), reason: t.slug);
        expect(
          title,
          endsWith(
            ' bases',
          ),
        );
        expect(
          title.split(' · ').last.replaceAll(RegExp(r'[^\d]'), ''),
          '$bases',
          reason: t.slug,
        );
      }
    });

    test('never say the gene can be seen at its band', () {
      final RegExp seen = RegExp(
        r'you can see|can be seen|is visible|visible here|shown here',
        caseSensitive: false,
      );
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomFacts facts = _facts(t);
        for (final ZoomStop stop in <ZoomStop>[
          ZoomStop.chromosome,
          ZoomStop.band,
        ]) {
          final ZoomFact fact = facts.of(stop);
          expect(seen.hasMatch('${fact.title} ${fact.line}'), isFalse);
        }
        final String bands = facts.about
            .firstWhere((ZoomSource s) => s.name == 'Bands')
            .text;
        expect(bands, contains('far too small to see'));
        expect(bands, contains('at low resolution'));
      }
    });

    test('name their sources, with the Atlas version and licence', () {
      final String about = _facts(
        TestCatalog.insulin,
      ).about.map((ZoomSource s) => '${s.name} ${s.text}').join(' ');
      expect(about, contains('cytoBand table for hg38'));
      expect(about, contains('Version 25.1'));
      expect(about, contains('CC BY 4.0'));
      expect(about, contains('2022-10-28'));
      expect(about, contains('MANE Select'));
    });

    test('show the record’s first bases at the DNA, 5′ to 3′', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final GeneRecord record = recordOf(t);
        final ZoomFact dna = _facts(t).of(ZoomStop.dna);
        final int n = math.min(ZoomDepth.helixBases, record.sequence.length);
        expect(dna.title, 'Its first $n bases');
        expect(dna.line, '5′ ${record.sequence.substring(0, n)} 3′');
      }
    });
  });
}
