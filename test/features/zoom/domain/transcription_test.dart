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

double _exons(GeneLayout layout) => layout.pieces
    .where((GenePiece p) => p.kind != GenePieceKind.intron)
    .fold<double>(0, (double sum, GenePiece p) => sum + p.length);

/// A frame a sixtieth of a second long.
const double _frame = 1 / 60;

void main() {
  test('every polymerase moves on without a jump, and comes and goes '
      'without a pop, at 60 fps, for all twenty', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final Transcription reading = _reading(t);
      final double length = reading.layout.length;
      final double speed = reading.speed;
      TranscriptionFrame? last;
      for (int f = 0; f <= 2 * Transcription.passSeconds / _frame; f++) {
        final TranscriptionFrame now = reading.at(f * _frame);
        expect(now.polymerases.length, Transcription.polymerases);
        if (last != null) {
          for (int lane = 0; lane < Transcription.polymerases; lane++) {
            final Polymerase a = last.polymerases[lane];
            final Polymerase b = now.polymerases[lane];
            final String what = '${t.slug}, lane $lane, frame $f';
            expect(
              (b.shown - a.shown).abs(),
              lessThanOrEqualTo(0.08),
              reason: what,
            );
            if (b.at >= a.at) {
              expect(
                b.at - a.at,
                closeTo(speed * _frame, 1e-6 * length),
                reason: what,
              );
            } else {
              // Back at the 5′ end for its next pass: unseen either side.
              expect(a.shown, lessThan(0.01), reason: what);
              expect(b.shown, lessThan(0.01), reason: what);
            }
            // Its RNA grows a frame's reading at most, and shrinks only as
            // an intron is spliced out or the whole is cut free, when it
            // leaves as the release it was.
            final double grew = _inLine(b.rna) - _inLine(a.rna);
            expect(
              grew,
              lessThanOrEqualTo(speed * _frame * (1 + 1e-9) + 1e-9 * length),
              reason: what,
            );
            if (a.rna.isNotEmpty && b.rna.isEmpty) {
              final Iterable<Release> freed = now.releases.where(
                (Release r) => r.lane == lane && r.age < _frame,
              );
              expect(freed, hasLength(1), reason: what);
              expect(
                _inLine(freed.single.rna),
                closeTo(_inLine(a.rna), 0.02 * length),
                reason: what,
              );
            }
          }
        }
        last = now;
      }
    }
  });

  test('an intron splicing out is all there, in line and looped; every one '
      'is out before the RNA is let go; the mRNA is the exons', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final Transcription reading = _reading(t);
      final GeneLayout layout = reading.layout;
      final double exons = _exons(layout);
      final List<GenePiece> introns = <GenePiece>[
        for (final GenePiece p in layout.pieces)
          if (p.kind == GenePieceKind.intron) p,
      ];
      for (int f = 0; f <= Transcription.passSeconds / _frame; f++) {
        final TranscriptionFrame now = reading.at(f * _frame);
        for (final Polymerase p in now.polymerases) {
          for (final RnaStretch s in p.rna) {
            if (s.looped > 0) {
              expect(s.kind, GenePieceKind.intron);
              // Looping out only once it is all transcribed: the two parts
              // are the whole intron.
              expect(
                introns.map((GenePiece g) => g.length),
                contains(closeTo(s.length + s.looped, 1e-6 * layout.length)),
                reason: '${t.slug} at $f',
              );
            }
          }
        }
        for (final Release r in now.releases) {
          expect(
            r.rna.every((RnaStretch s) => s.kind != GenePieceKind.intron),
            isTrue,
          );
          expect(_inLine(r.rna), closeTo(exons, 1e-6 * exons), reason: t.slug);
        }
        for (final Lariat l in now.lariats) {
          expect(
            introns.map((GenePiece g) => g.length),
            contains(closeTo(l.length, 1e-9)),
          );
          expect(l.age, inInclusiveRange(0, Transcription.lariatSeconds));
          expect(l.from, inInclusiveRange(0, reading.cut * reading.speed));
          expect(l.along, inInclusiveRange(0, layout.length));
        }
      }
      // Each intron comes out over the same time, soon after its 3′ end is
      // read; every one is out before the RNA is let go, once it is read to
      // the poly(A) site; and the polymerase has let go before its next pass.
      expect(reading.cut, greaterThanOrEqualTo(Transcription.readSeconds));
      expect(
        reading.cut + Transcription.letGoSeconds,
        lessThanOrEqualTo(Transcription.passSeconds),
      );
      expect(reading.splices, hasLength(introns.length));
      for (int j = 0; j < introns.length; j++) {
        final (double start, double end, double bases) = reading.splices[j];
        expect(
          start,
          closeTo(
            introns[j].end / reading.speed + Transcription.spliceDelay,
            1e-9,
          ),
        );
        expect(end - start, closeTo(Transcription.spliceSeconds, 1e-9));
        expect(end, lessThanOrEqualTo(reading.cut));
        expect(bases, introns[j].length);
      }
      // The most it carries is the most any moment shows.
      double most = 0;
      for (int f = 0; f <= Transcription.passSeconds / _frame; f++) {
        for (final Polymerase p in reading.at(f * _frame).polymerases) {
          most = math.max(most, _inLine(p.rna));
        }
      }
      expect(
        reading.longest,
        greaterThanOrEqualTo(most * 0.995),
        reason: t.slug,
      );
      expect(reading.longest, lessThanOrEqualTo(layout.length));
    }
  });

  test('what a pass leaves behind outlives the clock\'s wrap, and every '
      'lariat and release ages a frame a frame until it is gone', () {
    for (final ProteinTarget t in <ProteinTarget>[
      TestCatalog.insulin,
      TestCatalog.dystrophin,
      TestCatalog.prion,
    ]) {
      final Transcription reading = _reading(t);
      bool carried = false;
      TranscriptionFrame? last;
      for (int f = 0; f <= 2 * Transcription.passSeconds / _frame; f++) {
        final TranscriptionFrame now = reading.at(f * _frame);
        if (last != null) {
          for (final Release r in now.releases) {
            final Polymerase p = now.polymerases[r.lane];
            // Older than its polymerase's pass: the last pass's.
            final double pass = p.at / reading.speed;
            if (r.age > pass + 1e-9) {
              carried = true;
            }
            if (r.age >= _frame) {
              expect(
                last.releases.where(
                  (Release q) =>
                      q.lane == r.lane && (q.age + _frame - r.age).abs() < 1e-6,
                ),
                hasLength(1),
                reason: '${t.slug} at $f',
              );
            }
          }
          for (final Lariat l in now.lariats) {
            if (l.age >= _frame) {
              expect(
                last.lariats.where(
                  (Lariat q) =>
                      q.lane == l.lane &&
                      q.from == l.from &&
                      (q.age + _frame - l.age).abs() < 1e-6,
                ),
                hasLength(1),
                reason: '${t.slug} at $f',
              );
            }
          }
        }
        last = now;
      }
      expect(carried, isTrue, reason: t.slug);
    }
  });

  test('at rest, the still frame holds the gene being read: every '
      'polymerase on it, apart, their RNA longer toward the 3′ end', () {
    for (final ProteinTarget t in TestCatalog.all) {
      final Transcription reading = _reading(t);
      final List<double> at = <double>[
        for (final Polymerase p in reading.at(0).polymerases) p.at,
      ]..sort();
      final double even =
          reading.speed * Transcription.passSeconds / Transcription.polymerases;
      for (int i = 1; i < at.length; i++) {
        expect(at[i] - at[i - 1], greaterThan(0.39 * even), reason: t.slug);
      }
      final List<Polymerase> reading0 = reading.at(0).polymerases;
      expect(
        reading0.where((Polymerase p) => p.shown > 0.99 && p.rna.isNotEmpty),
        hasLength(greaterThanOrEqualTo(Transcription.polymerases - 2)),
        reason: t.slug,
      );
    }
  });
}
