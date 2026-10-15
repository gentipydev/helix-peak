import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/zoom/domain/gene_layout.dart';
import 'package:helixpeek/features/zoom/domain/transcription.dart';

import '../../../support/test_catalog.dart';
import '../record_fixtures.dart';

Transcription _reading(ProteinTarget t) =>
    Transcription(GeneLayout.of(recordOf(t)));

double _inLine(List<RnaStretch> rna) =>
    rna.fold<double>(0, (double sum, RnaStretch s) => sum + s.length);

List<GenePiece> _introns(GeneLayout layout) => <GenePiece>[
  for (final GenePiece p in layout.pieces)
    if (p.kind == GenePieceKind.intron) p,
];

/// The gene's longest intron; of two as long, the later.
GenePiece _longestIntron(GeneLayout layout) =>
    _introns(layout)
        .reduce((GenePiece a, GenePiece b) => b.length >= a.length ? b : a);

/// The exons' bases a polymerase at [at] has read.
double _exonsRead(GeneLayout layout, double at) => layout.pieces
    .where((GenePiece p) => p.kind != GenePieceKind.intron && p.start < at)
    .fold<double>(
      0,
      (double sum, GenePiece p) => sum + math.min(p.end, at) - p.start,
    );

void main() {
  test('the gene is read by three polymerases, 5′ to 3′, each at a stage '
      'of one reading, none nearer another than 12% of the gene, for '
      'all twenty', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final Transcription reading = _reading(t);
      final double length = reading.layout.length;
      final List<double> at = <double>[
        for (final Polymerase p in reading.polymerases) p.at,
      ];
      expect(at, hasLength(3), reason: t.slug);
      // The first has just begun.
      expect(at.first, closeTo(Transcription.begun * length, 1e-9 * length));
      for (int i = 0; i < at.length; i++) {
        expect(at[i], inInclusiveRange(0, length), reason: t.slug);
        if (i > 0) {
          expect(
            at[i] - at[i - 1],
            greaterThanOrEqualTo(Transcription.apart * length),
            reason: '${t.slug}: ${i - 1} and $i',
          );
        }
      }
    }
  });

  test('one intron is being spliced, the gene\'s longest, half out, all of '
      'it there in line and looped; nothing else loops', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final Transcription reading = _reading(t);
      final GeneLayout layout = reading.layout;
      final GenePiece longest = _longestIntron(layout);
      final List<(int, RnaStretch)> looped = <(int, RnaStretch)>[
        for (int i = 0; i < reading.polymerases.length; i++)
          for (final RnaStretch s in reading.polymerases[i].rna)
            if (s.looped > 0) (i, s),
      ];
      expect(looped, hasLength(1), reason: t.slug);
      final (int on, RnaStretch stretch) = looped.single;
      expect(on, reading.splicing, reason: t.slug);
      expect(stretch.kind, GenePieceKind.intron);
      expect(
        stretch.length + stretch.looped,
        closeTo(longest.length, 1e-9 * layout.length),
        reason: t.slug,
      );
      // Half way, but where it is held at the gene's 3′ end.
      final Polymerase splicing = reading.polymerases[on];
      if (splicing.at < layout.length) {
        expect(
          stretch.looped / longest.length,
          closeTo(0.5, 1e-9),
          reason: t.slug,
        );
      }
      expect(
        reading.splicedAt(longest, splicing.at),
        inExclusiveRange(0, 1),
        reason: t.slug,
      );
    }
  });

  test(
    'each RNA is what its polymerase has read: every exon so far, and '
    'an intron only until it is half spliced out, but the one looping out',
    () {
      for (final ProteinTarget t in TestCatalog.all) {
        final Transcription reading = _reading(t);
        final GeneLayout layout = reading.layout;
        final GenePiece longest = _longestIntron(layout);
        for (final Polymerase p in reading.polymerases) {
          final String what = '${t.slug} at ${p.at.round()}';
          final bool splicing = identical(
            p,
            reading.polymerases[reading.splicing],
          );
          bool kept(GenePiece piece) {
            if (piece.kind != GenePieceKind.intron) {
              return true;
            }
            final double spliced = reading.splicedAt(piece, p.at);
            return spliced < 0.5 ||
                splicing && identical(piece, longest) && spliced < 1;
          }

          // In order, 5′ to 3′: the pieces read, but the introns spliced out.
          expect(p.rna.map((RnaStretch s) => s.kind).toList(), <GenePieceKind>[
            for (final GenePiece piece in layout.pieces)
              if (piece.start < p.at && kept(piece)) piece.kind,
          ], reason: what);
          expect(
            p.rna
                .where((RnaStretch s) => s.kind != GenePieceKind.intron)
                .fold<double>(0, (double sum, RnaStretch s) => sum + s.length),
            closeTo(_exonsRead(layout, p.at), 1e-9 * layout.length),
            reason: what,
          );
          expect(p.inLine, closeTo(_inLine(p.rna), 1e-9), reason: what);
        }
      }
    },
  );

  test('the finished mRNA is the exons alone, 5′ to 3′, joined where each '
      'intron was', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final Transcription reading = _reading(t);
      final GeneLayout layout = reading.layout;
      final double exons = _exonsRead(layout, layout.length);
      expect(
        reading.mrna.every((RnaStretch s) => s.kind != GenePieceKind.intron),
        isTrue,
        reason: t.slug,
      );
      expect(_inLine(reading.mrna), closeTo(exons, 1e-9 * exons));
      expect(
        reading.junctions,
        hasLength(layout.exonCount - 1),
        reason: t.slug,
      );
      double last = 0;
      for (final double j in reading.junctions) {
        expect(j, greaterThan(last), reason: t.slug);
        last = j;
      }
      expect(last, lessThan(exons), reason: t.slug);
    }
  });

  test('the longest RNA is the most any of the three carries in line', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final Transcription reading = _reading(t);
      expect(
        reading.longest,
        reading.polymerases
            .map((Polymerase p) => _inLine(p.rna))
            .reduce(math.max),
        reason: t.slug,
      );
    }
  });

  test('a gene with no intron is read all the same, and nothing loops', () {
    const GeneLayout layout = GeneLayout(
      pieces: <GenePiece>[
        GenePiece(start: 0, end: 100, kind: GenePieceKind.utr),
        GenePiece(start: 100, end: 1600, kind: GenePieceKind.cds),
        GenePiece(start: 1600, end: 2000, kind: GenePieceKind.utr),
      ],
      length: 2000,
    );
    final Transcription reading = Transcription(layout);
    expect(reading.polymerases.map((Polymerase p) => p.at), <Matcher>[
      closeTo(240, 1e-9),
      closeTo(1000, 1e-9),
      closeTo(1760, 1e-9),
    ]);
    expect(
      reading.polymerases
          .expand((Polymerase p) => p.rna)
          .where((RnaStretch s) => s.looped > 0),
      isEmpty,
    );
    expect(_inLine(reading.mrna), 2000);
    expect(reading.junctions, isEmpty);
  });
}
