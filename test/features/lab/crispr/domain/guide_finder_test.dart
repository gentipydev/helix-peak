import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/crispr/domain/guide_finder.dart';
import 'package:helixpeek/features/lab/crispr/domain/guide_score.dart';
import 'package:helixpeek/features/lab/mutate/domain/apply_edit.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

// The test's own reading of a record, and its own scan for sites, written
// from the definition rather than from the finder so that the two can be held
// against each other.

/// R2.1: a minus-strand sequence is read from the far end, never complemented.
String _baseAt(GeneRecord record, int position) =>
    record.sequence[record.strand == -1
        ? record.end - position
        : position - record.start];

String _complement(String base) => switch (base) {
  'A' => 'T',
  'C' => 'G',
  'G' => 'C',
  'T' => 'A',
  _ => base,
};

String _reverseComplement(String bases) =>
    <String>[for (int i = bases.length - 1; i >= 0; i--) _complement(bases[i])]
        .join();

final RegExp _real = RegExp(r'^[ACGT]+$');

/// One site as the test reads it: the twenty bases, the PAM, and the record
/// position of the first of the twenty as the record reads them.
typedef _Site = ({
  GuideStrand strand,
  String protospacer,
  String pam,
  int from,
});

String _key(_Site site) =>
    '${site.strand.name} ${site.from} ${site.protospacer} ${site.pam}';

String _keyOf(Guide guide) => _key((
  strand: guide.strand,
  protospacer: guide.protospacer,
  pam: guide.pam,
  from: guide.from,
));

/// Every site the letters hold, found by reading each strand in turn as a
/// string of its own: twenty bases and then NGG.
///
/// Nothing here knows what a compressed intron is, so this is every site on
/// the page, including the ones the finder is meant to leave out.
List<_Site> _sites(GeneRecord record) {
  final String sense = record.sequence;
  final int length = sense.length;
  final bool minus = record.strand == -1;
  int positionAt(int offset) =>
      minus ? record.end - offset : record.start + offset;
  final List<_Site> sites = <_Site>[];
  for (int i = 0; i + 23 <= length; i++) {
    final String window = sense.substring(i, i + 23);
    if (!_real.hasMatch(window) || window[21] != 'G' || window[22] != 'G') {
      continue;
    }
    sites.add((
      strand: GuideStrand.sense,
      protospacer: window.substring(0, 20),
      pam: window.substring(20),
      from: positionAt(i),
    ));
  }

  // The other strand as its own 5' to 3' string. A window opening at [i] there
  // covers the sense offsets [length - 1 - i] down to [length - 23 - i], so
  // the first of its twenty bases as the record reads them is the lowest of
  // those the protospacer covers.
  final String antisense = _reverseComplement(sense);
  for (int i = 0; i + 23 <= length; i++) {
    final String window = antisense.substring(i, i + 23);
    if (!_real.hasMatch(window) || window[21] != 'G' || window[22] != 'G') {
      continue;
    }
    sites.add((
      strand: GuideStrand.antisense,
      protospacer: window.substring(0, 20),
      pam: window.substring(20),
      from: positionAt(length - 20 - i),
    ));
  }
  return sites;
}

/// What a guide's site reads on the record itself, turned back onto the
/// guide's own strand.
String _readBack(GeneRecord record, Guide guide) {
  final StringBuffer bases = StringBuffer();
  for (int place = 1; place <= guide.protospacer.length; place++) {
    bases.write(guide.asRecordWrites(_baseAt(record, guide.positionAt(place))));
  }
  return bases.toString();
}

void main() {
  final GeneRecord insulin = _gene('ins');

  group('every site insulin offers', () {
    final List<Guide> guides = GuideFinder.find(insulin);

    test('the finder and a second scan of the same definition agree', () {
      // Insulin is drawn whole, so every site its letters hold is one the
      // record really holds and the two lists are the same list.
      final List<String> found = guides.map(_keyOf).toList()..sort();
      final List<String> read = _sites(insulin).map(_key).toList()..sort();
      expect(found, read);
      expect(guides, hasLength(348));
    });

    test('both strands are searched', () {
      expect(
        guides.where((Guide g) => g.strand == GuideStrand.sense),
        hasLength(168),
      );
      expect(
        guides.where((Guide g) => g.strand == GuideStrand.antisense),
        hasLength(180),
      );
    });

    test('each one reads twenty bases and an NGG PAM off the record', () {
      for (final Guide guide in guides) {
        expect(guide.protospacer, hasLength(GuideFinder.protospacerLength));
        expect(guide.pam, hasLength(GuideFinder.pamLength));
        expect(guide.pam.substring(1), 'GG', reason: '$guide');
        expect(_readBack(insulin, guide), guide.protospacer, reason: '$guide');
        // The PAM follows base twenty, reading along the guide, which on an
        // antisense guide is back down the record past its first base.
        final StringBuffer pam = StringBuffer();
        for (int i = 1; i <= GuideFinder.pamLength; i++) {
          final int position = guide.strand == GuideStrand.sense
              ? guide.to + i * guide.step
              : guide.from - i * guide.step;
          pam.write(guide.asRecordWrites(_baseAt(insulin, position)));
        }
        expect(pam.toString(), guide.pam, reason: '$guide');
      }
    });

    test('they come in the order the record reads them', () {
      int previous = 0;
      for (final Guide guide in guides) {
        final int offset = (guide.siteFrom - insulin.start).abs();
        expect(offset, greaterThanOrEqualTo(previous), reason: '$guide');
        previous = offset;
      }
    });

    test('each carries the measure of its own bases', () {
      final Guide guide = guides.firstWhere((Guide g) => g.from == 5341);
      expect(
        guide.score.gcFraction,
        GuideScore.of(guide.protospacer).gcFraction,
      );
      expect(guide.score.gcFraction, closeTo(0.6, 1e-9));
      expect(guide.score.hasPolyT, isFalse);
    });
  });

  group('the blunt cut falls three bases 5\' of the PAM', () {
    final List<Guide> guides = GuideFinder.find(insulin);

    test('on a sense site: TACCTAGTGTGCGGGGAACG, PAM AGG', () {
      final Guide guide = guides.firstWhere(
        (Guide g) => g.from == 5341 && g.strand == GuideStrand.sense,
      );
      expect(guide.protospacer, 'TACCTAGTGTGCGGGGAACG');
      expect(guide.pam, 'AGG');
      expect((guide.from, guide.to), (5341, 5360));
      expect((guide.siteFrom, guide.siteTo), (5341, 5363));
      // Between bases seventeen and eighteen, and the record runs upwards, so
      // the base 3' of the cut is base eighteen.
      expect((guide.positionAt(17), guide.positionAt(18)), (5357, 5358));
      expect(guide.cutPosition, 5358);
      // Three bases between the cut and the PAM: 5358, 5359 and 5360.
      expect(guide.positionAt(20), 5360);
      expect(_baseAt(insulin, 5361), guide.pam[0]);
    });

    test('on an antisense site: CTGATGCAGCCTGTCCTGGA, PAM GGG', () {
      final Guide guide = guides.firstWhere(
        (Guide g) => g.from == 4991 && g.strand == GuideStrand.antisense,
      );
      expect(guide.protospacer, 'CTGATGCAGCCTGTCCTGGA');
      expect(guide.pam, 'GGG');
      // The guide reads the other way, so its first base sits at the record's
      // last, and its site reaches three bases below its twenty.
      expect((guide.from, guide.to), (4991, 5010));
      expect((guide.siteFrom, guide.siteTo), (4988, 5010));
      expect((guide.positionAt(1), guide.positionAt(20)), (5010, 4991));
      expect((guide.positionAt(17), guide.positionAt(18)), (4994, 4993));
      expect(guide.cutPosition, 4994);
      // The same three bases between the cut and the PAM, reading the guide:
      // 4993, 4992, 4991, and then the PAM at 4990.
      expect(guide.asRecordWrites(_baseAt(insulin, 4990)), guide.pam[0]);
    });

    test('always between protospacer bases seventeen and eighteen', () {
      expect(Guide.cutBetween, 17);
      for (final Guide guide in guides) {
        expect(
          (guide.positionAt(18) - guide.positionAt(17)).abs(),
          1,
          reason: '$guide',
        );
        expect(
          guide.cutPosition,
          guide.strand == GuideStrand.sense
              ? guide.positionAt(18)
              : guide.positionAt(17),
          reason: '$guide',
        );
        // An edit written at the cut is one the engine will make.
        expect(guide.positionFromCut(0), guide.cutPosition);
        expect(
          guide.positionFromCut(1) - guide.cutPosition,
          guide.step,
          reason: '$guide',
        );
      }
    });
  });

  group('a minus-strand record: RLN2', () {
    final GeneRecord relaxin = _gene('rln2');
    final List<Guide> guides = GuideFinder.find(relaxin);

    test('the finder and the second scan agree there too', () {
      final List<String> found = guides.map(_keyOf).toList()..sort();
      final List<String> read = _sites(relaxin).map(_key).toList()..sort();
      expect(found, read);
      expect(guides, hasLength(441));
    });

    test('positions run down the coordinates, as the gene is read', () {
      expect(relaxin.strand, -1);
      final Guide guide = guides.first;
      expect(guide.step, -1);
      expect(guide.strand, GuideStrand.sense);
      expect(guide.protospacer, 'AAAGACCGCTTGAGCCGGGT');
      expect(guide.pam, 'AGG');
      expect((guide.from, guide.to), (5352, 5333));
      expect((guide.siteFrom, guide.siteTo), (5352, 5330));
      expect(guide.cutPosition, 5335);
      expect(_readBack(relaxin, guide), guide.protospacer);
    });

    test('an antisense site on a minus-strand record is read back too', () {
      final Guide guide = guides.firstWhere(
        (Guide g) => g.strand == GuideStrand.antisense,
      );
      expect(guide.protospacer, 'CTTTCCCTACCCGGCTCAAG');
      expect((guide.from, guide.to), (5344, 5325));
      expect((guide.siteFrom, guide.siteTo), (5347, 5325));
      expect(guide.cutPosition, 5341);
      expect(_readBack(relaxin, guide), guide.protospacer);
    });
  });

  group('CFTR, whose introns are drawn shortened', () {
    final GeneRecord cftr = _gene('cftr');
    final List<Guide> guides = GuideFinder.find(cftr);
    const String reason =
        'This intron is drawn shortened, so an edit here cannot be placed on '
        'the chromosome.';

    test('a site reading across a shortened intron is not offered', () {
      // Intron 1 is drawn at 19365-21723, 2,359 of its 24,105 bases, and exon
      // 2 is 21724-21834, whole. These twenty-three bases are next to each
      // other on the page and 21,746 apart on the chromosome.
      const String protospacer = 'CCTCCTCTCTTTATTTTAGC';
      final StringBuffer letters = StringBuffer();
      for (int position = 21705; position <= 21727; position++) {
        letters.write(_baseAt(cftr, position));
      }
      expect(letters.toString(), '${protospacer}TGG');

      final Guide across = Guide(
        protospacer: protospacer,
        pam: 'TGG',
        strand: GuideStrand.sense,
        from: 21705,
        step: 1,
        score: GuideScore.of(protospacer),
      );
      expect((across.siteFrom, across.siteTo), (21705, 21727));
      final EditEligibility eligibility = GuideFinder.eligibilityOf(
        cftr,
        across,
      );
      expect(eligibility, isA<Ineligible>());
      expect((eligibility as Ineligible).reason, reason);
      expect(
        guides.where((Guide g) => g.siteFrom == 21705),
        isEmpty,
        reason: 'the letters hold this site; the chromosome does not',
      );
    });

    test('exactly the sites the guard rules out are left out', () {
      final List<_Site> read = _sites(cftr);
      final Set<String> offered = guides.map(_keyOf).toSet();
      expect(read, hasLength(1724));
      expect(guides, hasLength(496));
      expect(offered, hasLength(guides.length));

      for (final _Site site in read) {
        final Guide guide = Guide(
          protospacer: site.protospacer,
          pam: site.pam,
          strand: site.strand,
          from: site.from,
          step: 1,
          score: GuideScore.of(site.protospacer),
        );
        expect(
          GuideFinder.eligibilityOf(cftr, guide) is Eligible,
          offered.contains(_key(site)),
          reason: '$guide',
        );
      }
    });

    test('a site inside an exon of the same record is offered', () {
      expect(
        guides.where((Guide g) => g.siteFrom >= 21724 && g.siteTo <= 21834),
        isNotEmpty,
      );
      for (final Guide guide in guides) {
        expect(GuideFinder.eligibilityOf(cftr, guide), isA<Eligible>());
      }
    });
  });

  group('records that offer nothing', () {
    test('a record with no room for a site', () {
      const GeneRecord tiny = GeneRecord(
        gene: 'TINY',
        start: 1,
        end: 10,
        sequence: 'ACGTACGTAC',
        exons: <Exon>[],
        peptides: <Peptide>[],
      );
      expect(GuideFinder.find(tiny), isEmpty);
    });

    test('a run of unknown bases holds no site', () {
      const GeneRecord unknown = GeneRecord(
        gene: 'NNNN',
        start: 1,
        end: 26,
        sequence: 'NNNNNNNNNNNNNNNNNNNNNNNNGG',
        exons: <Exon>[],
        peptides: <Peptide>[],
      );
      expect(GuideFinder.find(unknown), isEmpty);
    });
  });
}
