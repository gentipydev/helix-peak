import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/gene_layout.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_camera.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_facts.dart';
import 'package:helixpeek/features/zoom/domain/zoom_motion.dart';
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';
import 'package:helixpeek/shared/format.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';
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
      // The third ten (2026-10-17), each in a cell type the twenty do not reach.
      'phospholamban': (
        'heart muscle',
        TissueFrom.reading,
        'Cardiomyocytes',
        CellFrom.pair,
      ),
      's100b': ('brain', TissueFrom.reading, 'Bergmann glia', CellFrom.singleCell),
      'hcgbeta': (
        'placenta',
        TissueFrom.reading,
        'Syncytiotrophoblasts',
        CellFrom.singleCell,
      ),
      'ppbp': ('bone marrow', TissueFrom.reading, 'Platelets', CellFrom.singleCell),
      'pappa': (
        'placenta',
        TissueFrom.reading,
        'Decidual stromal cells',
        CellFrom.singleCell,
      ),
      'cystatinb': (
        'esophagus',
        TissueFrom.reading,
        'Esophageal apical cells',
        CellFrom.singleCell,
      ),
      'tyrp1': ('skin', TissueFrom.reading, 'Melanocytes', CellFrom.pair),
      'recoverin': (
        'retina',
        TissueFrom.reading,
        'Rod photoreceptor cells',
        CellFrom.singleCell,
      ),
      'thyroglobulin': (
        'thyroid gland',
        TissueFrom.reading,
        'Thyroid glandular cells',
        CellFrom.pair,
      ),
      'uromodulin': (
        'kidney',
        TissueFrom.reading,
        'Ascending Loop of Henle cells',
        CellFrom.pair,
      ),
      'izumo1': ('testis', TissueFrom.reading, 'Early spermatids', CellFrom.pair),
      'gapdhs': ('testis', TissueFrom.reading, 'Late spermatids', CellFrom.pair),
      'fpr1': (
        'bone marrow',
        TissueFrom.reading,
        'Neutrophils',
        CellFrom.singleCell,
      ),
      'cyp17a1': (
        'adrenal gland',
        TissueFrom.reading,
        'Adrenal cortex cells',
        CellFrom.pair,
      ),
      'b3gat1': (
        'brain',
        TissueFrom.reading,
        'Oligodendrocytes',
        CellFrom.singleCell,
      ),
      'dmc1': ('testis', TissueFrom.reading, 'Spermatocytes', CellFrom.pair),
      'dynamin1': (
        'brain',
        TissueFrom.reading,
        'Brain excitatory neurons',
        CellFrom.singleCell,
      ),
      'lgi1': (
        'choroid plexus',
        TissueFrom.reading,
        'Choroid plexus epithelial cells',
        CellFrom.singleCell,
      ),
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
                  'test/features/zoom/fixtures/v1/hemoglobin_locus.json',
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
        // Hemoglobin's red cells, and PPBP's platelets, which land in the
        // megakaryocyte that makes them.
        <String>[TestCatalog.hemoglobin.slug, 'ppbp'],
      );
    });

    test('names a cell without the qualifier the Atlas puts on a pair', () {
      expect(_path(TestCatalog.p53).cellName, 'Mitotic cells');
      expect(_path(TestCatalog.leptin).cellName, 'Adipocytes');
      expect(_path(TestCatalog.insulin).cellName, 'Beta cells');
    });

    test('names a cell without the number of the Atlas cluster it is', () {
      expect(const ZoomPath(cellType: 'Neutrophils_2').cellName, 'Neutrophils');
      expect(const ZoomPath(cellType: 'Fibroblasts_1').cellName, 'Fibroblasts');
      expect(
        const ZoomPath(cellType: 'Alveolar cells type 1').cellName,
        'Alveolar cells type 1',
      );
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

    test('find every tissue on the figure of a body that has it', () {
      for (final MapEntry<String, TissueAnatomy> e in tissueAnatomy.entries) {
        final String part = e.value.uberon;
        final bool onFemale = AnatomyFigure.female.parts.containsKey(part);
        final bool onMale = AnatomyFigure.male.parts.containsKey(part);
        switch (e.value.sex) {
          case BodySex.female:
            expect(onFemale, isTrue, reason: e.key);
          case BodySex.male:
            expect(onMale, isTrue, reason: e.key);
          case BodySex.either:
            expect(onFemale && onMale, isTrue, reason: e.key);
        }
        // And the figure the zoom picks for it has it.
        expect(
          AnatomyFigure.bodyFor(e.key, const <String>[]).parts[part],
          isNotNull,
          reason: e.key,
        );
        if (e.value.inBrain != null) {
          expect(
            AnatomyFigure.brain.parts[e.value.inBrain],
            isNotNull,
            reason: e.key,
          );
        }
      }
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

  group('the anatomogram’s figures', () {
    bool inside(List<Offset> outline, Offset p) {
      bool odd = false;
      for (int i = 0; i < outline.length; i++) {
        final Offset a = outline[i];
        final Offset b = outline[(i + 1) % outline.length];
        if ((a.dy > p.dy) != (b.dy > p.dy) &&
            p.dx < a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy)) {
          odd = !odd;
        }
      }
      return odd;
    }

    Rect boxOf(List<Offset> outline) => outline.fold<Rect>(
      Rect.fromPoints(outline.first, outline.first),
      (Rect box, Offset p) => box.expandToInclude(Rect.fromPoints(p, p)),
    );

    test('stand 1.70 m tall about their midline, and the brain is 17 cm '
        'long', () {
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ]) {
        final Rect box = boxOf(figure.silhouette);
        expect(box.top, closeTo(0, 1e-3), reason: figure.name);
        expect(box.height, closeTo(AnatomyFigure.height, 1e-3));
        expect(box.center.dx, closeTo(0, 1e-3), reason: figure.name);
        // Arms out: wider than the trunk, narrower than it is tall.
        expect(box.width, inExclusiveRange(0.7, 1.2), reason: figure.name);
      }
      final Rect brain = boxOf(AnatomyFigure.brain.silhouette);
      expect(brain.width, closeTo(0.17, 1e-3));
      expect(brain.center.distance, lessThan(1e-3));
    });

    test('draw every part inside the figure, with a place in it to go in '
        'at', () {
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
        AnatomyFigure.brain,
      ]) {
        final Rect box = boxOf(figure.silhouette).inflate(0.01);
        expect(figure.parts, isNotEmpty);
        for (final MapEntry<String, AnatomyPart> part in figure.parts.entries) {
          final String what = '${figure.name} ${part.key}';
          expect(part.value.followed.length, greaterThan(5), reason: what);
          expect(
            inside(part.value.followed, part.value.site),
            isTrue,
            reason: '$what: its site is outside its outline',
          );
          for (final List<Offset> contour in part.value.contours) {
            for (final Offset p in contour) {
              expect(box.contains(p), isTrue, reason: '$what at $p');
            }
          }
        }
      }
    });

    test('go into the bone marrow, drawn as a femur, in its upper fifth, '
        'where an adult keeps its red marrow, well inside it', () {
      double toSegment(Offset p, Offset a, Offset b) {
        final Offset ab = b - a;
        final double length = ab.dx * ab.dx + ab.dy * ab.dy;
        final double t = length == 0
            ? 0
            : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0, 1);
        return (p - (a + ab * t)).distance;
      }

      final String uberon = tissueAnatomy['bone marrow']!.uberon;
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ]) {
        final AnatomyPart part = figure.parts[uberon]!;
        final Rect box = boxOf(part.followed);
        expect(part.site.dy - box.top, lessThan(0.2 * box.height),
            reason: figure.name);
        final List<Offset> outline = part.followed;
        double edge = double.infinity;
        for (int i = 0; i < outline.length; i++) {
          final Offset b = outline[(i + 1) % outline.length];
          edge = math.min(edge, toSegment(part.site, outline[i], b));
        }
        expect(edge, greaterThan(0.015), reason: figure.name);
      }
    });

    test('go into the heart muscle in its left ventricle\'s free wall, which '
        'forms its right edge, a little over half way down', () {
      final String uberon = tissueAnatomy['heart muscle']!.uberon;
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ]) {
        final AnatomyPart part = figure.parts[uberon]!;
        final List<Offset> outline = part.followed;
        final Rect box = boxOf(outline);
        expect((part.site.dy - box.top) / box.height, closeTo(0.56, 0.01),
            reason: figure.name);
        double right = double.negativeInfinity;
        for (int i = 0; i < outline.length; i++) {
          final Offset a = outline[i];
          final Offset b = outline[(i + 1) % outline.length];
          if ((a.dy > part.site.dy) != (b.dy > part.site.dy)) {
            right = math.max(
              right,
              a.dx + (part.site.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy),
            );
          }
        }
        expect((right - part.site.dx) / box.width, closeTo(0.035, 0.01),
            reason: figure.name);
      }
    });

    test('go into skeletal muscle in its outermost outline, the vastus '
        'lateralis, 0.6 of the way down and midway across it, the view '
        'closing on the whole thigh', () {
      final String uberon = tissueAnatomy['skeletal muscle']!.uberon;
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ]) {
        final AnatomyPart part = figure.parts[uberon]!;
        double out(List<Offset> contour) => boxOf(contour).center.dx.abs();
        for (final List<Offset> other in part.others) {
          expect(out(part.followed), greaterThan(out(other)),
              reason: figure.name);
        }
        final List<Offset> outline = part.followed;
        final Rect box = boxOf(outline);
        expect((part.site.dy - box.top) / box.height, closeTo(0.6, 0.01),
            reason: figure.name);
        final List<double> crossings = <double>[
          for (int i = 0; i < outline.length; i++)
            if ((outline[i].dy > part.site.dy) !=
                (outline[(i + 1) % outline.length].dy > part.site.dy))
              outline[i].dx +
                  (part.site.dy - outline[i].dy) *
                      (outline[(i + 1) % outline.length].dx - outline[i].dx) /
                      (outline[(i + 1) % outline.length].dy - outline[i].dy),
        ]..sort();
        expect(crossings.length, 2, reason: figure.name);
        expect(part.site.dx, closeTo((crossings[0] + crossings[1]) / 2, 1e-3),
            reason: figure.name);
        Rect whole = boxOf(part.followed);
        for (final List<Offset> contour in part.contours) {
          whole = whole.expandToInclude(boxOf(contour));
        }
        expect((part.centre - whole.center).distance, lessThan(1e-3),
            reason: figure.name);
      }
    });

    test('go into the kidney three quarters of the way down, in from the '
        'side away from the midline, in its cortex at its lower pole, where '
        'a kidney is biopsied', () {
      final String uberon = tissueAnatomy['kidney']!.uberon;
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ]) {
        final AnatomyPart part = figure.parts[uberon]!;
        final List<Offset> outline = part.followed;
        final Rect box = boxOf(outline);
        expect((part.site.dy - box.top) / box.height, closeTo(0.75, 0.01),
            reason: figure.name);
        // The lateral side is the one away from the midline: the body's
        // right kidney's left on the page, the left kidney's right.
        final double side = box.center.dx < 0 ? -1 : 1;
        double edge = side * double.negativeInfinity;
        for (int i = 0; i < outline.length; i++) {
          final Offset a = outline[i];
          final Offset b = outline[(i + 1) % outline.length];
          if ((a.dy > part.site.dy) != (b.dy > part.site.dy)) {
            final double x =
                a.dx + (part.site.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
            edge = side < 0 ? math.min(edge, x) : math.max(edge, x);
          }
        }
        expect((edge - part.site.dx) * side / box.width, closeTo(0.08, 0.01),
            reason: figure.name);
      }
    });

    test('close the view on the esophagus a little below the middle of its '
        'outline, where the middle of what its scene draws lies', () {
      final String esophagus = tissueAnatomy['esophagus']!.uberon;
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ]) {
        final AnatomyPart part = figure.parts[esophagus]!;
        final Rect box = boxOf(part.followed);
        expect(part.framed, isNotNull, reason: figure.name);
        // 0.03 of its height below its box's middle, as the tool reads the
        // drawing's own outline, before it is simplified.
        expect(part.centre.dx, closeTo(box.center.dx, 5e-4),
            reason: figure.name);
        expect(part.centre.dy - box.center.dy,
            closeTo(0.03 * box.height, 1e-3), reason: figure.name);
      }
    });

    test('go into the skin on the left leg 2 cm below the knee, in its band '
        'on the leg\'s inner side, where GTEx takes it, and close the view '
        'there', () {
      final String skin = tissueAnatomy['skin']!.uberon;
      final String marrow = tissueAnatomy['bone marrow']!.uberon;
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
      ]) {
        final AnatomyPart part = figure.parts[skin]!;
        final Rect femur = boxOf(figure.parts[marrow]!.followed);
        // 2 cm below the femur's lowest point, as the tool reads the
        // drawing's own outlines, before they are simplified.
        expect(part.site.dy - femur.bottom, closeTo(0.02, 2e-3),
            reason: figure.name);
        // In the femur's leg, the left, on its side toward the middle:
        // between the figure's outline and the skin band's inner outline.
        final double side = femur.center.dx < 0 ? -1 : 1;
        double nearest(List<Offset> outline, double beyond) {
          double best = double.infinity;
          for (int i = 0; i < outline.length; i++) {
            final Offset a = outline[i];
            final Offset b = outline[(i + 1) % outline.length];
            if ((a.dy > part.site.dy) != (b.dy > part.site.dy)) {
              final double x =
                  a.dx + (part.site.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
              if (x * side > beyond) {
                best = math.min(best, x * side);
              }
            }
          }
          return best;
        }

        expect(part.contours.length, 2, reason: figure.name);
        final double outer = nearest(part.contours[0], 0);
        final double inner = nearest(part.contours[1], outer);
        expect(part.site.dx * side, greaterThan(outer), reason: figure.name);
        expect(part.site.dx * side, lessThan(inner), reason: figure.name);
        expect(inner - outer, lessThan(0.012), reason: figure.name);
        expect(part.framed, part.site, reason: figure.name);
      }
    });

    test('close the view on every other part at the middle of the outline '
        'it follows', () {
      final String muscle = tissueAnatomy['skeletal muscle']!.uberon;
      final String esophagus = tissueAnatomy['esophagus']!.uberon;
      final String skin = tissueAnatomy['skin']!.uberon;
      for (final AnatomyFigure figure in <AnatomyFigure>[
        AnatomyFigure.female,
        AnatomyFigure.male,
        AnatomyFigure.brain,
      ]) {
        for (final MapEntry<String, AnatomyPart> part in figure.parts.entries) {
          if (<String>{muscle, esophagus, skin}.contains(part.key)) {
            continue;
          }
          expect(part.value.framed, isNull, reason: part.key);
          expect(part.value.following, 0, reason: part.key);
          expect(part.value.centre, boxOf(part.value.followed).center,
              reason: part.key);
        }
      }
    });

    test('pick a body that has the tissue, and as many of the others the '
        'gene is read in as either has', () {
      AnatomyFigure body(String? tissue, [List<String> others = const []]) =>
          AnatomyFigure.bodyFor(tissue, others);
      expect(body('testis'), same(AnatomyFigure.male));
      expect(body('fallopian tube', <String>['testis']),
          same(AnatomyFigure.female));
      expect(body('liver'), same(AnatomyFigure.female));
      expect(body('liver', <String>['prostate']), same(AnatomyFigure.male));
      expect(body('liver', <String>['prostate', 'ovary']),
          same(AnatomyFigure.female));
      expect(body(null), same(AnatomyFigure.female));
    });

    test('carry their source, its commit and its licence in the file they '
        'are generated into', () {
      final String generated = File(
        'lib/features/zoom/domain/anatomy_figures.g.dart',
      ).readAsStringSync();
      final String head = generated.substring(0, generated.indexOf('const '));
      expect(head, contains('GENERATED by tool/zoom/anatomogram.py'));
      expect(head, contains('ebi-gene-expression-group/anatomogram'));
      expect(head, contains('CC BY 4.0'));
      expect(head, contains('simplified'));
      // And the tool is pinned to the commit the file says it was made at.
      final String commit = RegExp(r'[0-9a-f]{40}').firstMatch(head)!.group(0)!;
      expect(
        File('tool/zoom/anatomogram.py').readAsStringSync(),
        contains('COMMIT = "$commit"'),
      );
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
        'prion': CellShape.epithelial,
        'relaxin': CellShape.ciliated,
        'ubiquitin': CellShape.germ,
        'app': CellShape.endothelial,
        'p53': CellShape.dividing,
        'phospholamban': CellShape.cardiomyocyte,
        's100b': CellShape.glial,
        'hcgbeta': CellShape.trophoblast,
        'ppbp': CellShape.megakaryocyte,
        'pappa': CellShape.spindle,
        'cystatinb': CellShape.epithelial,
        'tyrp1': CellShape.epithelial,
        'recoverin': CellShape.neuron,
        'thyroglobulin': CellShape.acinar,
        'uromodulin': CellShape.epithelial,
        'izumo1': CellShape.germ,
        'gapdhs': CellShape.germ,
        'fpr1': CellShape.leukocyte,
        'cyp17a1': CellShape.endocrine,
        'b3gat1': CellShape.glial,
        'dmc1': CellShape.germ,
        'dynamin1': CellShape.neuron,
        'lgi1': CellShape.ciliated,
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
      expect(depth.widthLabel(depth.depthOf(ZoomStop.body)), '1.8 m');
      // The eyepiece's half-millimetre field, with the dark round it.
      expect(depth.widthLabel(depth.depthOf(ZoomStop.tissue)), '600 µm');
      expect(lengthLabel(ZoomDepth.tissueField), '500 µm');
      expect(depth.widthLabel(depth.depthOf(ZoomStop.dna)), '14 bp');
      // The chromosome condensed: micrometres, not millimetres.
      expect(
        depth.widthAt(depth.depthOf(ZoomStop.chromosome)),
        inInclusiveRange(1e-6, 2e-5),
      );
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
        for (final ZoomStop stop
            in ZoomStop.values.skip(1).take(ZoomStop.values.length - 2)) {
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
      // Every stop a segment leaves: the DNA only ends one.
      for (final ZoomStop stop in ZoomStop.values.take(ZoomStop.dna.index)) {
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
    test('takes a second and a half a step, a little longer the further, '
        'within bounds', () {
      expect(flightDuration(0, 0.1), const Duration(milliseconds: 1450));
      expect(flightDuration(0, 3).inMilliseconds, 1750);
      expect(flightDuration(0, 40), const Duration(milliseconds: 1900));
      final ZoomFlight flight = ZoomFlight(1, 3);
      expect(flight.at(Duration.zero), 1);
      expect(flight.at(flight.duration), 3);
      expect(flight.at(flight.duration ~/ 2), closeTo(2, 1e-9));
      expect(flight.speedAt(Duration.zero), 0);
      expect(flight.speedAt(flight.duration), 0);
    });

    test('sets off at the speed it is given, and comes to rest', () {
      final ZoomFlight flight = ZoomFlight(1, 3, velocity: 1.5);
      expect(flight.speedAt(Duration.zero), closeTo(1.5, 1e-9));
      expect(flight.at(flight.duration), closeTo(3, 1e-12));
      expect(flight.speedAt(flight.duration), closeTo(0, 1e-9));
      // Speed is depth a second: the speed it reports is the rate the depth
      // changes.
      const Duration step = Duration(microseconds: 100);
      for (final double share in <double>[0.1, 0.4, 0.7]) {
        final Duration at = flight.duration * share;
        final double rate =
            (flight.at(at + step) - flight.at(at - step)) /
            (2 * step.inMicroseconds / 1e6);
        expect(flight.speedAt(at), closeTo(rate, 1e-3));
      }
    });

    test('coasts a flick to the stop it would reach', () {
      final ZoomDepth depth = _depth(TestCatalog.insulin);
      final double cell = depth.depthOf(ZoomStop.cell);
      expect(flingTarget(depth, cell, 0), ZoomStop.cell);
      expect(flingTarget(depth, cell, 8), isNot(ZoomStop.cell));
      expect(flingTarget(depth, cell, -100), ZoomStop.body);
    });
  });

  group('the dive into the DNA', () {
    test('narrows from the gene to the DNA without turning back or a jolt, '
        'and every other step evenly, for all twenty', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomDepth depth = _depth(t);
        for (int k = 0; k + 1 < ZoomStop.values.length; k++) {
          if (k == ZoomStop.gene.index) {
            continue;
          }
          for (final double s in <double>[0, 0.2, 0.5, 0.9, 1]) {
            expect(depth.narrowedAt(k, s), s);
          }
        }
        const int k = 7; // the gene, the step into the DNA leaves
        expect(ZoomStop.values[k], ZoomStop.gene);
        expect(depth.narrowedAt(k, 0), 0);
        expect(depth.narrowedAt(k, 1), 1);
        // The largest second difference over [steps] even steps: halving
        // the step quarters it where the curve is smooth, and only halves it
        // across a kink; between the two, smooth.
        double bend(int steps) {
          double most = 0;
          double? last;
          double? before;
          for (int i = 0; i <= steps; i++) {
            final double now = depth.narrowedAt(k, i / steps);
            if (last != null) {
              expect(now, greaterThan(last), reason: '${t.slug} at $i');
              if (before != null) {
                most = math.max(most, (now - 2 * last + before).abs());
              }
            }
            before = last;
            last = now;
          }
          return most;
        }

        expect(bend(4000), lessThan(0.4 * bend(2000)), reason: t.slug);
        // The view's width is the dive's at every depth of the step.
        final double at = depth.depthOf(ZoomStop.gene);
        final double travel = depth.travelOf(k);
        for (final double s in <double>[0.1, 0.4, 0.8]) {
          expect(
            math.log(depth.widthAt(at + s * travel)) / math.ln10,
            closeTo(
              math.log(depth.widthOf(ZoomStop.gene)) / math.ln10 +
                  depth.narrowedAt(k, s) *
                      math.log(depth.ratioOf(k)) /
                      math.ln10,
              1e-9,
            ),
            reason: '${t.slug} at $s',
          );
        }
      }
    });

    test('spends its depth where its DNA changes, not in a long gene’s '
        'introns', () {
      final ZoomDepth depth = _depth(TestCatalog.dystrophin);
      final double gene = math.log(depth.widthOf(ZoomStop.gene)) / math.ln10;
      final double dna = math.log(depth.widthOf(ZoomStop.dna)) / math.ln10;
      // The share of the step's depth by the time the view is [width] wide.
      double spentBy(double width) {
        double low = 0;
        double high = 1;
        final double share = (gene - math.log(width) / math.ln10) / (gene - dna);
        for (int i = 0; i < 60; i++) {
          final double mid = (low + high) / 2;
          if (depth.narrowedAt(ZoomStop.gene.index, mid) < share) {
            low = mid;
          } else {
            high = mid;
          }
        }
        return low;
      }

      // Two decades and more of introns in a tenth of the step, and the
      // decade and a bit where the DNA winds and its beads are read in more
      // than a third.
      expect(spentBy(25000), lessThan(0.1));
      expect(spentBy(150) - spentBy(2500), greaterThan(0.35));
    });

    test('takes its time: a step into the DNA lasts the dive, a share of it '
        'for part of it, and no other step any longer', () {
      final ZoomDepth depth = _depth(TestCatalog.insulin);
      final double gene = depth.depthOf(ZoomStop.gene);
      final double dna = depth.depthOf(ZoomStop.dna);
      final Duration dive = Duration(
        microseconds: (ZoomDepth.diveSeconds * 1e6).round(),
      );
      expect(depth.leastFlight(gene, dna), dive);
      expect(depth.leastFlight(dna, gene), dive);
      expect(
        depth.leastFlight((gene + dna) / 2, gene).inMicroseconds,
        closeTo(dive.inMicroseconds / 2, 1),
      );
      final double band = depth.depthOf(ZoomStop.band);
      expect(depth.leastFlight(band, gene), Duration.zero);
      expect(depth.leastFlight(0, depth.depthOf(ZoomStop.organ)), Duration.zero);
      // A flight takes the longer of its own time and the least it is given.
      final ZoomFlight dive2 = ZoomFlight(
        gene,
        dna,
        minimum: depth.leastFlight(gene, dna),
      );
      expect(dive2.duration, dive);
      expect(dive2.at(dive2.duration), closeTo(dna, 1e-12));
      expect(dive2.speedAt(dive2.duration).abs(), lessThan(1e-9));
      expect(
        ZoomFlight(band, gene, minimum: depth.leastFlight(band, gene)).duration,
        flightDuration(band, gene),
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
          final ZoomFact fact = facts.of(stop);
          expect(
            ungrouped.hasMatch('${fact.title} ${fact.line}'),
            isFalse,
            reason: '${t.slug} ${stop.name}: ${fact.title} · ${fact.line}',
          );
        }
      }
    });

    test('give an organ its size, and the skin, drawn as a block of it, '
        'how thick it is', () {
      expect(_facts(TestCatalog.insulin).of(ZoomStop.organ).line,
          'About 16 cm');
      final ZoomFact skin = _facts(TestCatalog.bySlug('tyrp1')!)
          .of(ZoomStop.organ);
      expect(skin.title, 'Skin');
      expect(skin.line, 'About 2 mm thick');
    });

    test('say data, and explain nothing but at the cell', () {
      final RegExp explains = RegExp(
        r'condensed for division|one of 46|territory of its own|stained|'
        r'so its precursor|elsewhere|home of its top|cell type pair|'
        r'a field|magnified|any organ',
        caseSensitive: false,
      );
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomFacts facts = _facts(t);
        for (final ZoomStop stop in ZoomStop.values) {
          final ZoomFact fact = facts.of(stop);
          // The cell's line says what its drawing shows (the user's ask,
          // 2026-10-19); its title is still only the place.
          if (stop == ZoomStop.cell) {
            expect(explains.hasMatch(fact.title), isFalse, reason: t.slug);
            continue;
          }
          expect(
            explains.hasMatch('${fact.title} ${fact.line}'),
            isFalse,
            reason: '${t.slug} at ${stop.name}: ${fact.title} · ${fact.line}',
          );
        }
        // The nucleus and the tissue are named, with nothing to add.
        expect(facts.of(ZoomStop.nucleus).line, isEmpty);
        expect(facts.of(ZoomStop.tissue).line, isEmpty);
      }
      expect(
        _facts(TestCatalog.insulin).of(ZoomStop.chromosome).line,
        '135,086,622 bp · 36 bands',
      );
      expect(
        _facts(TestCatalog.insulin).of(ZoomStop.cell),
        isA<ZoomFact>()
            .having(
              (ZoomFact f) => f.title,
              'title',
              'Endocrine cells · Beta cells',
            )
            .having(
              (ZoomFact f) => f.line,
              'line',
              'Vesicles carry the protein from the Golgi to secretory '
                  'granules; it is secreted to the blood.',
            ),
      );
    });

    test('name the cell under the Atlas’s class for it, and say no level '
        'of it', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomPath path = _path(t);
        final ZoomFact cell = _facts(t).of(ZoomStop.cell);
        final String words = '${cell.title} ${cell.line}';
        expect(words, isNot(contains('cell type enriched')), reason: t.slug);
        expect(words, isNot(contains('nCPM')), reason: t.slug);
        if (path.cellName != null && path.cellClass != null) {
          expect(
            cell.title,
            startsWith('${path.cellClass} · '),
            reason: t.slug,
          );
        }
      }
      expect(
        _facts(TestCatalog.glucagon).of(ZoomStop.cell).title,
        'Endocrine cells · Alpha cells',
      );
      expect(
        _facts(TestCatalog.leptin).of(ZoomStop.cell).title,
        'Mesenchymal cells · Adipocytes',
      );
    });

    test('say at the cell what its drawing shows: the protein where the '
        'Atlas finds it, and where it is carried if it is secreted, and not '
        'what a reader in the field knows', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final LocusTrack track = locusOf(t);
        final String story = _facts(t).cellStory;
        final String why = '${t.slug}: $story';
        // Where a gene is transcribed goes unsaid; a cell with no nucleus
        // says only that.
        expect(story, isNot(contains('transcribed')), reason: why);
        expect(
          story.contains('nucleus'),
          _path(t).landsIn != null,
          reason: why,
        );
        expect(
          story.contains('glows'),
          !track.subcellular.isEmpty,
          reason: why,
        );
        expect(
          story.contains('has not placed the protein'),
          track.subcellular.isEmpty && !track.secreted,
          reason: why,
        );
        expect(story.contains('Vesicles carry'), track.secreted, reason: why);
        expect(_facts(t).of(ZoomStop.cell).line, story, reason: t.slug);
      }
      expect(
        _facts(TestCatalog.glucagon).cellStory,
        'The protein glows where the Atlas finds it, fainter at its '
        'additional locations. Vesicles carry it from the Golgi to secretory '
        'granules; it is secreted to the blood.',
      );
      expect(
        _facts(TestCatalog.cftr).cellStory,
        'The Atlas has not placed the protein in the cell.',
      );
    });

    test('end a secreted protein’s story where the Atlas finds it secreted '
        'to, for each of its words that says secreted', () {
      // The Atlas's secretome words, version 25.1.
      const List<String> secretome = <String>[
        'Immunoglobulin genes',
        'Intracellular and membrane',
        'Secreted - unknown location',
        'Secreted in brain',
        'Secreted in female reproductive system',
        'Secreted in male reproductive system',
        'Secreted in other tissues',
        'Secreted to blood',
        'Secreted to digestive system',
        'Secreted to extracellular matrix',
      ];
      expect(ZoomFacts.secretedTo.keys.toSet(), <String>{
        for (final String word in secretome)
          if (word.startsWith('Secreted')) word,
      });
      expect(
        _facts(TestCatalog.bySlug('s100b')!).cellStory,
        endsWith('the Atlas does not say where it is secreted to.'),
      );
      expect(
        _facts(TestCatalog.amylase).cellStory,
        endsWith('it is secreted to the digestive system.'),
      );
    });

    test('name each tissue by the architecture its slide is laid in', () {
      final Map<ProteinTarget, String> named = <ProteinTarget, String>{
        TestCatalog.insulin: 'Islet',
        TestCatalog.glucagon: 'Islet',
        TestCatalog.cftr: 'Ducts',
        TestCatalog.amylase: 'Acini',
        TestCatalog.hemoglobin: 'Erythroblastic island',
        TestCatalog.tnf: 'Marrow',
        TestCatalog.erythropoietin: 'Hepatic plates',
        TestCatalog.leptin: 'Fat lobules',
        TestCatalog.myoglobin: 'Muscle fibres',
        TestCatalog.oxytocin: 'Grey matter',
        TestCatalog.prion: 'Choroid plexus',
        TestCatalog.somatotropin: 'Endocrine cords',
        TestCatalog.relaxin: 'Mucosal folds',
        TestCatalog.ubiquitin: 'Seminiferous tubules',
        TestCatalog.app: 'Lymph node',
        TestCatalog.p53: 'Gastric glands',
      };
      for (final MapEntry<ProteinTarget, String> entry in named.entries) {
        expect(
          _facts(entry.key).of(ZoomStop.tissue).title,
          entry.value,
          reason: entry.key.slug,
        );
      }
    });

    test('say out loud where the zoom lands instead of a nucleus it lacks', () {
      final ZoomFact cell = _facts(TestCatalog.hemoglobin).of(ZoomStop.cell);
      expect(cell.title, 'Blood and immune cells · Erythroblasts');
      expect(
        cell.line,
        'Erythrocytes have no nucleus. The Atlas has not placed the protein '
        'in the cell.',
      );
      expect(
        _facts(TestCatalog.bySlug('ppbp')!).of(ZoomStop.cell).line,
        startsWith('Platelets have no nucleus. Vesicles carry'),
      );
      expect(
        _facts(TestCatalog.insulin).of(ZoomStop.cell).line,
        isNot(contains('no nucleus')),
      );
    });

    test('say the Atlas’s top cell type where none of the organ’s stands '
        'out', () {
      final ZoomFact tnf = _facts(TestCatalog.tnf).of(ZoomStop.cell);
      expect(tnf.title, 'Bone marrow cell');
      expect(tnf.line, startsWith('Top cell type: microglia. Vesicles'));
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
      }
    });

    test('credit the anatomogram and the Atlas, under their licence', () {
      expect(
        _facts(TestCatalog.insulin).credit,
        'Anatomogram EMBL-EBI · HPA 25.1 · CC BY 4.0',
      );
      // The figures' own file says whose they are, under what.
      final String head = File(
        'lib/features/zoom/domain/anatomy_figures.g.dart',
      ).readAsStringSync().substring(0, 600);
      expect(head, contains('EMBL-EBI'));
      expect(head, contains(AnatomyFigure.licence));
    });

    test('name the gene at its own stop: its length, its exons and its '
        'strand', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final GeneRecord record = recordOf(t);
        final ZoomFact gene = _facts(t).of(ZoomStop.gene);
        final int bases = record.realSpanBp ?? record.lengthBp;
        final int exons = record.exons.length;
        expect(gene.title, '${record.gene} · ${grouped(bases)} bases');
        expect(
          gene.line,
          '${spelledLeading(exons)} ${exons == 1 ? 'exon' : 'exons'} · '
          '${locusOf(t).strand < 0 ? 'reverse' : 'forward'} strand',
          reason: t.slug,
        );
      }
      final ZoomFact insulin = _facts(TestCatalog.insulin).of(ZoomStop.gene);
      expect(insulin.title, 'INS · 1,431 bases');
      expect(insulin.line, 'Three exons · reverse strand');
    });

    test('show the record’s first bases at the DNA, 5′ to 3′', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final GeneRecord record = recordOf(t);
        final ZoomFact dna = _facts(t).of(ZoomStop.dna);
        final int n = math.min(ZoomDepth.helixBases, record.sequence.length);
        expect(dna.title, 'First $n bases');
        expect(dna.line, '5′ ${record.sequence.substring(0, n)} 3′');
      }
      expect(
        _facts(TestCatalog.insulin).of(ZoomStop.dna).title,
        'First 33 bases',
      );
    });
  });
}
