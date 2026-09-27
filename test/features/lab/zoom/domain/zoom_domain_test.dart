import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/zoom/domain/locus_track.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_captions.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_path.dart';
import 'package:helixpeek/features/lab/zoom/domain/zoom_scale.dart';
import 'package:helixpeek/shared/format.dart';

import '../../../../support/test_catalog.dart';
import '../zoom_fixtures.dart';

void main() {
  group('the locus track', () {
    test('reads all twenty, each its chromosome whole', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final LocusTrack track = locusOf(t);
        expect(track.bands.first.start, 1, reason: t.slug);
        expect(track.bands.last.end, track.length);
        expect(track.spanStart, lessThanOrEqualTo(track.spanEnd));
        expect(track.bandStart, lessThanOrEqualTo(track.spanStart));
        expect(track.bandEnd, greaterThanOrEqualTo(track.spanEnd));
        expect(track.locus, startsWith(track.chromosome));
        expect(track.atlasLicence, 'CC BY 4.0');
      }
    });

    test('places the known genes at their bands', () {
      expect(locusOf(TestCatalog.insulin).locus, '11p15.5');
      expect(locusOf(TestCatalog.hemoglobin).locus, '11p15.4');
      final LocusTrack dmd = locusOf(TestCatalog.dystrophin);
      expect(dmd.bandNames, <String>['p21.2', 'p21.1']);
      expect(dmd.locus, 'Xp21.2-p21.1');
      // Its real span, not the record's shortened one.
      expect(dmd.geneLengthBp, greaterThan(2000000));
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

  group('the scale', () {
    test('runs from the body down to the gene without turning back, for all '
        'twenty', () {
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomScale scale = ZoomScale(locusOf(t));
        double last = -1;
        for (final ZoomLevel level in ZoomLevel.values) {
          final double z = scale.zoomOf(level);
          expect(z, greaterThan(last), reason: '${t.slug} $level');
          last = z;
          expect(
            scale.widthAt(z) / ZoomScale.widthOf(level, scale.track),
            closeTo(1, 1e-9),
          );
        }
        expect(scale.zoomOf(ZoomLevel.body), 0);
        expect(scale.zoomOf(ZoomLevel.gene), 1);
      }
    });

    test('from metres to nanometres, one logarithmic value', () {
      final ZoomScale scale = ZoomScale(locusOf(TestCatalog.insulin));
      expect(scale.widthAt(0), greaterThan(1));
      expect(scale.widthAt(1), lessThan(1e-7));
      // Equal steps of the value multiply the width by equal factors.
      final double a = scale.widthAt(0.2) / scale.widthAt(0.3);
      final double b = scale.widthAt(0.6) / scale.widthAt(0.7);
      expect(a, closeTo(b, 1e-9));
      for (final double z in <double>[0, 0.13, 0.5, 0.97, 1]) {
        expect(scale.zoomAt(scale.widthAt(z)), closeTo(z, 1e-9));
      }
    });

    test('draws the chromosome at the length its DNA condenses to', () {
      final LocusTrack x = locusOf(TestCatalog.dystrophin);
      final LocusTrack eleven = locusOf(TestCatalog.insulin);
      expect(
        ZoomScale.condensedLength(x) / ZoomScale.condensedLength(eleven),
        closeTo(x.length / eleven.length, 1e-12),
      );
      // A few micrometres: well inside the nucleus it is drawn in.
      expect(ZoomScale.condensedLength(eleven), inInclusiveRange(1e-6, 1e-5));
    });

    test('snaps to the nearest level, and crossfades between two', () {
      final ZoomScale scale = ZoomScale(locusOf(TestCatalog.insulin));
      for (final ZoomLevel level in ZoomLevel.values) {
        final double z = scale.zoomOf(level);
        expect(scale.nearest(z), level);
        expect(scale.presence(level, z), closeTo(1, 1e-9));
        for (final ZoomLevel other in ZoomLevel.values) {
          if (other != level) {
            expect(scale.presence(other, z), closeTo(0, 1e-9));
          }
        }
      }
      final double mid =
          (scale.zoomOf(ZoomLevel.cell) + scale.zoomOf(ZoomLevel.nucleus)) / 2;
      expect(
        scale.presence(ZoomLevel.cell, mid) +
            scale.presence(ZoomLevel.nucleus, mid),
        closeTo(1, 1e-9),
      );
    });

    test('labels a round length a fifth or so of the view', () {
      for (final double width in <double>[2.2, 0.3, 3e-3, 5e-5, 1.5e-5, 4e-8]) {
        final (double metres, double pixels, String label) = scaleBar(
          width,
          390,
        );
        expect(metres, lessThanOrEqualTo(width * 0.22));
        expect(metres, greaterThan(width * 0.22 / 2.6));
        expect(pixels, closeTo(metres / width * 390, 1e-9));
        expect(label, matches(RegExp(r'^\d+(\.\d)? (m|cm|mm|µm|nm)$')));
      }
      expect(lengthLabel(0.5), '50 cm');
      expect(lengthLabel(2e-5), '20 µm');
      expect(lengthLabel(1e-8), '10 nm');
      expect(lengthLabel(2), '2 m');
    });
  });

  group('the path', () {
    test('goes through the organ and cells the Atlas reads the gene in', () {
      final ZoomPath insulin = ZoomPath.of(locusOf(TestCatalog.insulin));
      expect(insulin.tissue, 'pancreas');
      expect(insulin.cellType, 'Pancreatic islet cells');
      expect(insulin.anucleate, isNull);
      for (final ProteinTarget t in <ProteinTarget>[
        TestCatalog.p53,
        TestCatalog.ubiquitin,
        TestCatalog.dystrophin,
        TestCatalog.app,
      ]) {
        expect(ZoomPath.of(locusOf(t)).tissue, isNull, reason: t.slug);
      }
    });

    test('lands in a precursor where the cells have no nucleus, read from the '
        'Atlas, not from the protein', () {
      final ZoomPath hemoglobin = ZoomPath.of(locusOf(TestCatalog.hemoglobin));
      expect(hemoglobin.cellType, 'Erythrocytes');
      expect(hemoglobin.anucleate, same(anucleateCellTypes['Erythrocytes']));
      // The only one of the twenty whose cells have none.
      expect(
        <String>[
          for (final ProteinTarget t in TestCatalog.all)
            if (ZoomPath.of(locusOf(t)).anucleate != null) t.slug,
        ],
        <String>[TestCatalog.hemoglobin.slug],
      );
    });
  });

  group('the captions', () {
    test('name no protein and no gene, at any level', () {
      final List<String> names = <String>[
        for (final ProteinTarget t in TestCatalog.all) ...<String>[
          t.display.toLowerCase(),
          t.gene.toLowerCase(),
          t.slug,
        ],
      ];
      for (final ProteinTarget t in TestCatalog.all) {
        final ZoomCaptions captions = ZoomCaptions(locusOf(t));
        final String words = <String>[
          for (final ZoomLevel level in ZoomLevel.values)
            captions.captionOf(level),
        ].join(' ').toLowerCase();
        for (final String name in names) {
          expect(
            RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(words),
            isFalse,
            reason: '${t.slug} names $name',
          );
        }
      }
    });

    test('never say the gene can be seen at the chromosome', () {
      final RegExp seen = RegExp(
        r'you can see|can be seen|is visible|visible here|shown here|'
        r'here is the gene|the gene is marked|marks the gene',
        caseSensitive: false,
      );
      for (final ProteinTarget t in TestCatalog.all) {
        final LocusTrack track = locusOf(t);
        final String chromosome = ZoomCaptions(track)
            .captionOf(ZoomLevel.chromosome);
        expect(chromosome, contains('far too small to see'), reason: t.slug);
        // A band is a stain pattern, seen at low resolution.
        expect(chromosome, contains('of stain'));
        expect(chromosome, contains('at low resolution'));
        expect(seen.hasMatch(chromosome), isFalse, reason: chromosome);
        expect(chromosome, contains('Chromosome ${track.chromosome},'));
        expect(chromosome, contains('${grouped(track.geneLengthBp)} base'));
      }
    });

    test('say out loud where the zoom lands instead of a nucleus it lacks', () {
      final String cell = ZoomCaptions(locusOf(TestCatalog.hemoglobin))
          .captionOf(ZoomLevel.cell);
      expect(cell, contains('mature red blood cells have no nucleus'));
      expect(cell, contains('erythroblasts of the bone marrow'));
      expect(cell, contains('still has its nucleus'));
      // Nobody else's cell caption says so.
      expect(
        ZoomCaptions(locusOf(TestCatalog.insulin)).captionOf(ZoomLevel.cell),
        isNot(contains('no nucleus')),
      );
    });

    test('name their sources, with the Atlas version and licence', () {
      final ZoomCaptions captions = ZoomCaptions(locusOf(TestCatalog.insulin));
      expect(captions.sources, contains('cytoBand table for hg38'));
      expect(captions.sources, contains('Human Protein Atlas, version 25.1'));
      expect(captions.sources, contains('CC BY 4.0'));
      expect(captions.sources, contains('2022-10-28'));
    });
  });
}
