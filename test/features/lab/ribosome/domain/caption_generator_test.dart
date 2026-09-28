import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/shared/ribosome/caption_generator.dart';
import 'package:helixpeek/shared/ribosome/director.dart';
import 'package:helixpeek/shared/ribosome/translation_timeline.dart';

import '../../../../support/test_catalog.dart';

GeneRecord _gene(String gene) => GeneRecordDto.fromJson(
  jsonDecode(File('test/fixtures/mock/gene_$gene.json').readAsStringSync())
      as Map<String, dynamic>,
).toEntity();

/// Every caption a translation shows: one per phase, and one per sampled
/// moment inside each beat.
List<String> _captions(TranslationTimeline timeline, CaptionGenerator words) {
  final Set<String> seen = <String>{};
  final List<double> ts = <double>[
    ...timeline.boundaries,
    for (int b = 0; b < timeline.beats; b++)
      for (final double u in <double>[0.1, 0.45, 0.7, 0.9])
        timeline.beatStart(b + u),
  ];
  for (final double t in ts) {
    final String? caption = words.captionFor(timeline.stateAt(t));
    if (caption != null) {
      seen.add(caption);
    }
  }
  return seen.toList();
}

/// A name no caption may carry: every catalog protein's display name, and
/// its gene symbol as a word, except where the symbol is itself a codon (GCG
/// is glucagon's gene and alanine's codon).
bool _names(String caption) {
  for (final ProteinTarget target in TestCatalog.all) {
    if (caption.toLowerCase().contains(target.display.toLowerCase())) {
      return true;
    }
    final String gene = target.gene;
    if (!RegExp(r'^[ACGT]+$').hasMatch(gene) &&
        RegExp('\\b${RegExp.escape(gene)}\\b').hasMatch(caption)) {
      return true;
    }
  }
  return false;
}

void main() {
  final Map<String, GeneRecord> records = <String, GeneRecord>{
    'insulin': _gene('ins'),
    'p53': _gene('tp53'),
    'relaxin 2': _gene('rln2'),
  };

  group('captions', () {
    records.forEach((String name, GeneRecord record) {
      test('$name: built from the record, and naming no protein', () {
        final TranslationTimeline timeline = TranslationTimeline(record);
        final List<String> captions = _captions(
          timeline,
          CaptionGenerator(timeline, record),
        );
        expect(captions.length, greaterThan(10));
        for (final String caption in captions) {
          expect(_names(caption), isFalse, reason: caption);
          expect(caption, endsWith('.'), reason: caption);
        }
      });
    });

    test('insulin’s say what its record says', () {
      final GeneRecord record = records['insulin']!;
      final TranslationTimeline timeline = TranslationTimeline(record);
      final CaptionGenerator words = CaptionGenerator(timeline, record);
      final List<String> captions = _captions(timeline, words);

      expect(
        words.captionFor(timeline.stateAt(0)),
        'The small subunit scans the 5′ UTR, 59 bases, from the cap to the '
        'start codon.',
      );
      final String minus3 = timeline.mrna[timeline.cdsStart - 3];
      final String plus4 = timeline.mrna[timeline.cdsStart + 3];
      expect(
        words.captionFor(timeline.stateAt(timeline.beatStart(3.5))),
        'The large subunit joins at the start codon. Around it, the Kozak '
        'context reads $minus3 at −3 and $plus4 at +4.',
      );
      expect(captions, contains('Residue 24 ends the signal peptide.'));
      expect(
        captions,
        contains(
          'All 24 residues of the signal peptide are out of the tunnel: '
          'signal recognition particle can bind them now.',
        ),
      );
      expect(
        captions.where(
          (String c) => c.contains('knocks off its exon junction'),
        ),
        hasLength(1),
        reason: 'the 5′ UTR junction is passed while scanning, not decoding',
      );
      expect(
        captions,
        contains(
          'The stop codon UAG reaches the A site. No tRNA reads it; a release '
          'factor does.',
        ),
      );
      expect(
        captions.where((String c) => c.contains('mature chain')),
        isNotEmpty,
      );
      expect(
        words.captionFor(timeline.stateAt(1)),
        contains('small enough for methionine aminopeptidase'),
      );
    });

    test('p53 has no signal peptide, and keeps its methionine', () {
      final GeneRecord record = records['p53']!;
      final TranslationTimeline timeline = TranslationTimeline(record);
      final CaptionGenerator words = CaptionGenerator(timeline, record);
      final List<String> captions = _captions(timeline, words);
      expect(
        captions.where((String c) => c.contains('signal peptide')),
        isEmpty,
      );
      expect(words.captionFor(timeline.stateAt(1)), contains('stays'));
    });

    test('a caption that cannot be built is null, not invented', () {
      final GeneRecord record = records['insulin']!;
      // An mRNA that starts on its start codon: no 5′ UTR to scan, and no
      // base at −3 for the Kozak context.
      final TranslationTimeline bare = TranslationTimeline.raw(
        mrna: 'ATGGCCTTTTAAGG',
        cdsStart: 0,
        protein: 'MAF',
      );
      final CaptionGenerator words = CaptionGenerator(bare, record);
      expect(words.captionFor(bare.stateAt(0)), isNull);
      expect(
        words.captionFor(bare.stateAt(bare.beatStart(3.5))),
        'The large subunit joins at the start codon, with G at +4.',
      );
    });
  });

  group('the director', () {
    final TranslationTimeline timeline = TranslationTimeline(
      records['insulin']!,
    );
    final TranslationDirector director = TranslationDirector(timeline);

    test('plays initiation, the first cycles and the stop codon slowly', () {
      expect(director.isSlow(0), isTrue);
      expect(
        director.isSlow(timeline.beatStart(timeline.beatOfCodon(3))),
        isTrue,
      );
      expect(
        director.isSlow(timeline.beatStart(timeline.firstTerminationBeat)),
        isTrue,
      );
      expect(director.isSlow(1), isTrue);
    });

    test('slows for the first residue out and the SRP window opening', () {
      expect(director.isSlow(timeline.firstExit!), isTrue);
      expect(director.isSlow(timeline.srpWindow!.$1), isTrue);
    });

    test('hurries through the cycles in between', () {
      final double middle = timeline.beatStart(timeline.beatOfCodon(80));
      expect(director.isSlow(middle), isFalse);
      expect(director.fast, greaterThanOrEqualTo(4));
      // A fast stretch takes less of the playing time than its share of t.
      final double from = timeline.beatStart(timeline.beatOfCodon(75));
      final double to = timeline.beatStart(timeline.beatOfCodon(85));
      expect(
        director.curve.wallAt(to) - director.curve.wallAt(from),
        lessThan(to - from),
      );
    });

    test('keeps a cell’s own time, 5.6 residues a second', () {
      expect(director.cellSeconds(timeline.stateAt(0)), 0);
      expect(director.cellTotal, closeTo(109 / 5.6, 1e-9));
      expect(director.cellSeconds(timeline.stateAt(1)), director.cellTotal);
      final TranslationState mid = timeline.stateAt(
        timeline.beatStart(timeline.beatOfCodon(57) + 0.9),
      );
      expect(director.cellSeconds(mid), closeTo(56 / 5.6, 1e-9));
    });
  });
}
