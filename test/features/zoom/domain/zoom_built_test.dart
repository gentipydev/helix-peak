import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/domain/zoom_facts.dart';
import 'package:helixpeek/features/zoom/domain/zoom_path.dart';

import '../../../support/test_catalog.dart';
import '../coverage_fixtures.dart';
import '../record_fixtures.dart';
import '../zoom_fixtures.dart';

/// The zoom of a protein built on demand: its schema 3 `locus` track read,
/// the places in a cell only the cell drawn has, and a short gene's stop.
void main() {
  ZoomPath pathOf(ProteinTarget t) => ZoomPath.of(locusOf(t));

  group('a schema 3 track', () {
    test('reads every coverage protein, as a schema 2 one reads', () {
      for (final ProteinTarget t in Coverage.all) {
        final LocusTrack track = locusOf(t);
        expect(track.schemaVersion, 3, reason: t.slug);
        final ZoomPath path = pathOf(t);
        expect(path.baked, isTrue, reason: t.slug);
        expect(path.tissue, isNotNull, reason: t.slug);
        expect(path.tissueFrom, isNotNull, reason: t.slug);
      }
    });

    test('names an organ and a cell chosen by level as such, and the card '
        'says the Atlas finds nothing specific', () {
      final ProteinTarget xpo1 = Coverage.target('xpo1');
      final ZoomPath path = pathOf(xpo1);
      expect(path.tissue, 'lymphoid tissue');
      expect(path.tissueFrom, TissueFrom.tissueLevel);
      expect(path.cellType, 'B-cells');
      expect(path.cellFrom, CellFrom.singleCellLevel);
      final ZoomFacts facts = ZoomFacts(
        track: locusOf(xpo1),
        path: path,
        record: recordOf(xpo1),
      );
      // The reading's own words, and nothing made up for the rule.
      expect(facts.of(ZoomStop.body).title, 'Lymphoid tissue');
      expect(facts.of(ZoomStop.body).line, locusOf(xpo1).tissue.specificity);
    });

    test('a gene carried from a patch scaffold is drawn on its chromosome', () {
      final LocusTrack polr2a = locusOf(Coverage.target('polr2a'));
      expect(polr2a.chromosome, '17');
      expect(polr2a.sequence, 'NC_000017.11');
      expect(polr2a.locus, '17p13.1');
    });
  });

  group('a cell has the places its kind has', () {
    test('a spermatid has a sperm tail; a spermatocyte and every other cell '
        'have none', () {
      final ZoomPath spermatid = pathOf(Coverage.target('tekt4'));
      expect(spermatid.cellType, contains('spermatids'));
      expect(cellHas(Compartment.sperm, spermatid), isTrue);
      final ZoomPath spermatocyte = pathOf(TestCatalog.ubiquitin);
      expect(spermatocyte.cellType, 'Late primary spermatocytes');
      expect(cellHas(Compartment.sperm, spermatocyte), isFalse);
      final ZoomPath rod = pathOf(TestCatalog.bySlug('recoverin')!);
      expect(cellHas(Compartment.sperm, rod), isFalse);
    });

    test('only a dividing cell has a spindle and a cytokinetic bridge', () {
      final ZoomPath mitotic = pathOf(TestCatalog.p53);
      expect(archetypeOf(mitotic).shape, CellShape.dividing);
      expect(cellHas(Compartment.division, mitotic), isTrue);
      final ZoomPath glia = pathOf(TestCatalog.bySlug('s100b')!);
      expect(cellHas(Compartment.division, glia), isFalse);
    });

    test('every other place belongs to every cell', () {
      for (final ProteinTarget t in zoomProteins) {
        for (final Compartment c in Compartment.values) {
          if (c != Compartment.sperm && c != Compartment.division) {
            expect(cellHas(c, pathOf(t)), isTrue, reason: '${t.slug} $c');
          }
        }
      }
    });

    test('the words of places the cell has not are left out, main and '
        'additional', () {
      // BBS9's lactotroph: the cilium kept, the sperm tail's pieces gone.
      final ProteinTarget bbs9 = Coverage.target('bbs9');
      final SubcellularReading read = readingInCell(
        locusOf(bbs9).subcellular,
        pathOf(bbs9),
      );
      expect(read.main, <String>[
        'Primary cilium',
        'Primary cilium tip',
        'Primary cilium transition zone',
      ]);
      expect(read.additional, <String>['Nucleoplasm', 'Vesicles', 'Cytosol']);
      // TEKT4's spermatid keeps every one.
      final ProteinTarget tekt4 = Coverage.target('tekt4');
      expect(
        readingInCell(locusOf(tekt4).subcellular, pathOf(tekt4)).main,
        locusOf(tekt4).subcellular.main,
      );
    });

    test('a cell left with no place of the protein says so, and does not say '
        'it glows', () {
      final ProteinTarget recoverin = TestCatalog.bySlug('recoverin')!;
      // The Atlas reads recoverin in a sperm tail's mid and principal
      // pieces, which a rod has not.
      expect(locusOf(recoverin).subcellular.main, <String>[
        'Mid piece',
        'Principal piece',
      ]);
      final String story = ZoomFacts(
        track: locusOf(recoverin),
        path: pathOf(recoverin),
        record: recordOf(recoverin),
      ).cellStory;
      expect(story, 'The Atlas has not placed the protein in the cell.');
      // A spermatocyte has no acrosome yet: ubiquitin's glows in its cytosol
      // alone, with no fainter places.
      final ProteinTarget ubiquitin = TestCatalog.ubiquitin;
      expect(
        ZoomFacts(
          track: locusOf(ubiquitin),
          path: pathOf(ubiquitin),
          record: recordOf(ubiquitin),
        ).cellStory,
        'The protein glows where the Atlas finds it.',
      );
    });
  });

  group('the gene’s stop', () {
    test('a gene shorter than its least view is drawn whole in that view', () {
      for (final ProteinTarget t in zoomProteins) {
        final ZoomDepth depth = ZoomDepth(locusOf(t), path: pathOf(t));
        final double own = 1.3 * locusOf(t).geneLengthBp;
        expect(
          depth.widthOf(ZoomStop.gene),
          own < ZoomDepth.leastGeneView ? ZoomDepth.leastGeneView : own,
          reason: t.slug,
        );
      }
      final ProteinTarget miurf = Coverage.target('miurf');
      expect(
        ZoomDepth(locusOf(miurf), path: pathOf(miurf)).widthOf(ZoomStop.gene),
        ZoomDepth.leastGeneView,
      );
    });

    test('no curated gene is drawn in the least view: each fills its own', () {
      for (final ProteinTarget t in TestCatalog.all) {
        expect(
          1.3 * locusOf(t).geneLengthBp,
          greaterThan(ZoomDepth.leastGeneView),
          reason: t.slug,
        );
      }
    });
  });
}
