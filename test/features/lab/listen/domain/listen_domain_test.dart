import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/genetic_code.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/listen/domain/audio_track.dart';
import 'package:helixpeek/features/lab/listen/domain/dna_score.dart';
import 'package:helixpeek/features/lab/listen/domain/dna_voice.dart';
import 'package:helixpeek/features/lab/listen/domain/listen_captions.dart';
import 'package:helixpeek/features/lab/listen/domain/playhead.dart';
import 'package:helixpeek/shared/anatomy/anatomy_stages.dart';

import '../../../../support/test_catalog.dart';
import '../../replication/replication_fixtures.dart';
import '../listen_fixtures.dart';

final Map<String, AnatomyModel> _models = <String, AnatomyModel>{};

AnatomyModel _model(ProteinTarget target) => _models.putIfAbsent(
  target.slug,
  () => AnatomyModel.derive(recordOf(target), chain: target.chain),
);

AnatomyStage _stage(AnatomyModel model, StageKind kind) =>
    model.stages.firstWhere((AnatomyStage s) => s.kind == kind);

/// The clinical words R9.1 keeps inside ClinVar's own quotations.
const List<String> _clinical = <String>[
  'pathogenic',
  'benign',
  'disease',
  'causes',
  'uncertain significance',
];

void main() {
  group('the audio track', () {
    test('every protein’s file carries its own map, a note a residue', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final AudioTrack track = audioOf(target);
        expect(track.residues, target.facts.residues, reason: target.slug);
        expect(
          track.sequence,
          recordOf(target).protein!.translation,
          reason: target.slug,
        );
        expect(track.onsetMs.length, track.residues, reason: target.slug);
        expect(track.onsetMs.first, 0, reason: target.slug);
        for (int i = 1; i < track.residues; i++) {
          expect(track.onsetMs[i], greaterThan(track.onsetMs[i - 1]));
        }
        expect(
          track.durationMs,
          ListenTempo.millisecondsOf(track.residues * track.noteSamples),
          reason: target.slug,
        );
        expect(track.samples, track.residues * track.noteSamples);
        expect(track.sampleRate, ListenTempo.sampleRate);
      }
    });

    test('the app’s tempo is the one the track was baked at', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final AudioTrack track = audioOf(target);
        expect(
          ListenTempo.noteSamplesFor(track.residues),
          track.noteSamples,
          reason: target.slug,
        );
        for (int i = 0; i < track.residues; i++) {
          expect(
            track.onsetMs[i],
            ListenTempo.millisecondsOf(i * track.noteSamples),
          );
        }
      }
    });

    test('the mapping is read from the file, not written again here', () {
      final AudioTrack insulin = audioOf(TestCatalog.insulin);
      expect(insulin.hydropathy, hasLength(20));
      expect(insulin.hydropathy['I'], 4.5);
      expect(insulin.hydropathy['R'], -4.5);
      expect(insulin.pitchScale, 'Kyte & Doolittle 1982');
      expect(insulin.pitchNotes, 'C major pentatonic, C4 to C6');
      expect(
        insulin.timbres.map((TimbreMapping m) => m.timbre),
        NoteTimbre.values,
      );
      expect(insulin.mappingOf(NoteTimbre.helix).sound, 'a held reed');
      expect(insulin.foldingSource, isTrue);
      expect(insulin.conservationSource, isTrue);
      expect(insulin.accentSource, isTrue);
      expect(insulin.foldingPdb, '3I40');
      expect(insulin.clinvarRetrieved, startsWith('2026-'));
    });

    test('loudness runs from twelve decibels under full to full', () {
      final AudioTrack insulin = audioOf(TestCatalog.insulin);
      for (int i = 0; i < insulin.residues; i++) {
        final double db = insulin.levelDbOf(i);
        expect(db, inInclusiveRange(-12, 0));
        expect(db, closeTo(-12 * (1 - insulin.loudness![i]), 1e-9));
      }
    });

    test('a tick is a residue a ClinVar record is at, numbered from one', () {
      final AudioTrack glucagon = audioOf(TestCatalog.glucagon);
      expect(glucagon.accent, hasLength(3));
      expect(glucagon.accent.every((int n) => n >= 1 && n <= 180), isTrue);
    });

    test('refuses another protein’s file', () {
      expect(
        () => AudioTrack.fromM4a(
          audioBytes(TestCatalog.insulin),
          TestCatalog.glucagon,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses a file that carries no map', () {
      final Uint8List bytes = audioBytes(TestCatalog.insulin);
      // The map is the file's last box: cut it off, and the rest is the
      // audio as the muxer wrote it.
      final Uint8List map = AudioTrack.mapOf(bytes)!;
      final Uint8List audio = Uint8List.sublistView(
        bytes,
        0,
        bytes.length - map.length - 24,
      );
      expect(AudioTrack.mapOf(audio), isNull);
      expect(
        () => AudioTrack.fromM4a(audio, TestCatalog.insulin),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses a box that claims more than the file holds', () {
      final Uint8List bytes = Uint8List.fromList(<int>[
        0, 0, 0, 0x40, 0x66, 0x74, 0x79, 0x70, 0, 0, 0, 0, //
      ]);
      expect(() => AudioTrack.mapOf(bytes), throwsA(isA<FormatException>()));
    });
  });

  group('the playhead', () {
    const List<int> onsets = <int>[0, 125, 250, 375];

    test('is the last note to have started', () {
      expect(noteAt(onsets, 0), 0);
      expect(noteAt(onsets, 124), 0);
      expect(noteAt(onsets, 125), 1);
      expect(noteAt(onsets, 380), 3);
    });

    test('holds the first before it and the last after it', () {
      expect(noteAt(onsets, -40), 0);
      expect(noteAt(onsets, 99999), 3);
    });

    test('agrees with reading the map note by note', () {
      final List<int> dystrophin = audioOf(TestCatalog.dystrophin).onsetMs;
      final math.Random random = math.Random(7);
      for (int k = 0; k < 2000; k++) {
        final int ms = random.nextInt(dystrophin.last + 200);
        int expected = 0;
        for (int i = 0; i < dystrophin.length; i++) {
          if (dystrophin[i] <= ms) {
            expected = i;
          }
        }
        expect(noteAt(dystrophin, ms), expected, reason: '$ms ms');
      }
    });
  });

  group('the tempo', () {
    test('an eighth of a second a note up to 960, then faster', () {
      expect(ListenTempo.noteSamplesFor(110), 2000);
      expect(ListenTempo.noteSamplesFor(960), 2000);
      expect(ListenTempo.noteSamplesFor(961), 1997);
      expect(ListenTempo.noteSamplesFor(3685), 521);
    });

    test('no note under 25 ms', () {
      expect(ListenTempo.noteSamplesFor(4800), 400);
      expect(ListenTempo.noteSamplesFor(4801), isNull);
      expect(ListenTempo.noteSamplesFor(0), isNull);
    });

    test('milliseconds round half up, as the backend’s onsets do', () {
      expect(ListenTempo.millisecondsOf(8 * 521), 261);
      expect(ListenTempo.millisecondsOf(2000), 125);
    });
  });

  group('DNA mode', () {
    test('every codon translates to its residue, and a stop ends it', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final DnaScore score = DnaScore.of(_model(target), spliced: true);
        final String protein = recordOf(target).protein!.translation;
        expect(score.codons, protein.length + 1, reason: target.slug);
        for (final DnaStep step in score.steps) {
          final String amino = GeneticCode.translate(step.bases)!;
          expect(
            amino,
            step.codon! < protein.length ? protein[step.codon!] : '*',
            reason: '${target.slug} codon ${step.codon! + 1}',
          );
        }
      }
    });

    test('a codon lasts as long as its residue’s note on the track', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final DnaScore score = DnaScore.of(_model(target), spliced: false);
        expect(
          score.noteSamples,
          audioOf(target).noteSamples,
          reason: target.slug,
        );
      }
    });

    test('insulin’s gene: codons, then its second intron, then the rest', () {
      final DnaScore gene = DnaScore.of(
        _model(TestCatalog.insulin),
        spliced: false,
      );
      expect(gene.codons, 111);
      expect(gene.introns, 1);
      expect(gene.intronBases, 787);
      expect(gene.intronLengthBp, 787);
      expect(gene.steps.first.bases, 'ATG');
      final Iterable<String> introns = gene.steps
          .where((DnaStep s) => s.kind == DnaStepKind.intron)
          .map((DnaStep s) => s.intron!);
      expect(introns.toSet(), <String>{'intron 2'});
      // The intron falls between two codons, all of it in one stretch.
      final int first = gene.steps.indexWhere(
        (DnaStep s) => s.kind == DnaStepKind.intron,
      );
      expect(
        gene.steps
            .skip(first)
            .take(787)
            .every((DnaStep s) => s.kind == DnaStepKind.intron),
        isTrue,
      );
      expect(gene.samples, 111 * 2000 + 787 * DnaScore.grain);
    });

    test('spliced, the introns are gone and the codons run on', () {
      final DnaScore mrna = DnaScore.of(
        _model(TestCatalog.insulin),
        spliced: true,
      );
      expect(mrna.steps, hasLength(111));
      expect(mrna.introns, 0);
      expect(mrna.samples, 111 * 2000);
    });

    test('a gene read off the minus strand still plays 5′ to 3′', () {
      for (final ProteinTarget target in <ProteinTarget>[
        TestCatalog.relaxin,
        TestCatalog.glucagon,
      ]) {
        expect(recordOf(target).strand, -1);
        final DnaScore gene = DnaScore.of(_model(target), spliced: false);
        expect(gene.steps.first.bases, 'ATG', reason: target.slug);
        expect(gene.steps.first.codon, 0);
        expect(
          GeneticCode.translate(gene.steps.last.bases),
          '*',
          reason: target.slug,
        );
        expect(gene.introns, greaterThan(0), reason: target.slug);
      }
    });

    test('a coding sequence in one exon sounds the same spliced or not', () {
      final DnaScore gene = DnaScore.of(
        _model(TestCatalog.prion),
        spliced: false,
      );
      final DnaScore mrna = DnaScore.of(
        _model(TestCatalog.prion),
        spliced: true,
      );
      expect(gene.introns, 0);
      expect(gene.samples, mrna.samples);
    });

    test('a shortened intron plays only the bases its page draws', () {
      for (final ProteinTarget target in <ProteinTarget>[
        TestCatalog.dystrophin,
        TestCatalog.app,
        TestCatalog.cftr,
      ]) {
        final AnatomyModel model = _model(target);
        expect(model.record.isIntronCompressed, isTrue);
        final DnaScore gene = DnaScore.of(model, spliced: false);
        expect(gene.intronBases, lessThan(gene.intronLengthBp));
        final AnatomyStage page = _stage(model, StageKind.gene);
        for (final DnaStep step in gene.steps) {
          expect(page.cellAt(step.position), isNot(-1));
        }
      }
    });

    test('every step is marked where its page draws it', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final AnatomyModel model = _model(target);
        final AnatomyStage gene = _stage(model, StageKind.gene);
        final AnatomyStage mrna = _stage(model, StageKind.mrna);
        for (final DnaStep step in DnaScore.of(model, spliced: false).steps) {
          expect(gene.cellAt(step.position), isNot(-1), reason: target.slug);
        }
        for (final DnaStep step in DnaScore.of(model, spliced: true).steps) {
          // On the transcript a codon is marked whole: its three cells.
          expect(
            mrna.codonCellsAt(mrna.cellAt(step.position)),
            hasLength(3),
            reason: '${target.slug} codon ${step.codon! + 1}',
          );
        }
      }
    });

    test('the timing map starts at zero and only moves on', () {
      final DnaScore gene = DnaScore.of(
        _model(TestCatalog.hemoglobin),
        spliced: false,
      );
      expect(gene.onsetMs.first, 0);
      for (int i = 1; i < gene.onsetMs.length; i++) {
        expect(gene.onsetMs[i], greaterThanOrEqualTo(gene.onsetMs[i - 1]));
        expect(gene.steps[i].onset, greaterThan(gene.steps[i - 1].onset));
      }
      expect(gene.durationMs, ListenTempo.millisecondsOf(gene.samples));
    });
  });

  group('DNA mode’s voice', () {
    test('a base plays its own letter, and T plays E', () {
      expect(DnaVoice.nameOf(DnaVoice.pitchOf('A', 3)), 'A3');
      expect(DnaVoice.nameOf(DnaVoice.pitchOf('C', 4)), 'C4');
      expect(DnaVoice.nameOf(DnaVoice.pitchOf('G', 5)), 'G5');
      expect(DnaVoice.pitchOf('T', 4), DnaVoice.pitchOf('U', 4));
      expect(DnaVoice.nameOf(DnaVoice.pitchOf('T', 4)), 'E4');
      expect(DnaVoice.pitchOf('C', 4), 60);
    });

    test('a codon is its bases low to high, one octave apart', () {
      expect(DnaVoice.chordOf('ATG').map(DnaVoice.nameOf), <String>[
        'A3',
        'E4',
        'G5',
      ]);
      expect(DnaVoice.chordOf('AAA').map(DnaVoice.nameOf), <String>[
        'A3',
        'A4',
        'A5',
      ]);
    });

    test('a chord sounds its three notes', () {
      final Float64List chord = DnaVoice.chord('ATG', 4000);
      final List<double> spectrum = _spectrum(chord);
      for (final int pitch in DnaVoice.chordOf('ATG')) {
        final double f = DnaVoice.hertz(pitch);
        final double at = _near(spectrum, f, 4000);
        final double between = _near(spectrum, f * 1.12, 4000);
        expect(at, greaterThan(20 * between), reason: '$f Hz');
      }
    });

    test('no chord of the 64 clips', () {
      const String bases = 'ACGT';
      for (final String a in bases.split('')) {
        for (final String b in bases.split('')) {
          for (final String c in bases.split('')) {
            final Float64List chord = DnaVoice.chord('$a$b$c', 2000);
            expect(
              chord.map((double v) => v.abs()).reduce(math.max),
              lessThan(0.95),
            );
          }
        }
      }
    });

    test('no step clicks into the next: each starts and ends in silence', () {
      final DnaScore gene = DnaScore.of(
        _model(TestCatalog.insulin),
        spliced: false,
      );
      final Int16List samples = DnaVoice.render(gene);
      expect(samples, hasLength(gene.samples));
      for (final DnaStep step in gene.steps) {
        expect(samples[step.onset], 0);
        expect(samples[step.onset + step.length - 1], 0);
      }
    });

    test('an intron rustles more quietly than a codon sings', () {
      double rms(Float64List x) => math.sqrt(
        x.fold<double>(0, (double s, double v) => s + v * v) / x.length,
      );
      expect(
        rms(DnaVoice.grain('G', DnaScore.grain)),
        lessThan(rms(DnaVoice.chord('GGG', 2000))),
      );
    });

    test('the WAV says what it holds', () {
      final Uint8List wav = DnaVoice.wav(
        Int16List.fromList(<int>[0, 100, -100]),
      );
      final ByteData data = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav, 0, 4), 'RIFF');
      expect(String.fromCharCodes(wav, 8, 12), 'WAVE');
      expect(String.fromCharCodes(wav, 12, 16), 'fmt ');
      expect(data.getUint16(20, Endian.little), 1);
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), ListenTempo.sampleRate);
      expect(data.getUint16(34, Endian.little), 16);
      expect(String.fromCharCodes(wav, 36, 40), 'data');
      expect(data.getUint32(40, Endian.little), 6);
      expect(data.getInt16(46, Endian.little), 100);
      expect(wav, hasLength(50));
    });
  });

  group('the words', () {
    test('the announcement names every channel and its property', () {
      final String said = ListenCaptions.mapping(audioOf(TestCatalog.insulin));
      for (final String word in <String>[
        'pitch',
        'hydropathy',
        'hydrophobic',
        'structure',
        'loudness',
        'conservation',
        'tick',
        'ClinVar record',
      ]) {
        expect(said, contains(word));
      }
    });

    test('the piece in words, from the track alone', () {
      final List<String> words = ListenCaptions.describe(
        audioOf(TestCatalog.insulin),
        TestCatalog.insulin,
      );
      final String all = words.join(' ');
      expect(all, contains('110 notes'));
      expect(all, contains('13.8 seconds'));
      expect(all, contains('eight a second'));
      expect(all, contains('residues 7 to 16'));
      expect(all, contains('30 residues in a helix, a held reed'));
      expect(all, contains('59 residues with no structure'));
      expect(all, contains('65 of 110 residues have a ClinVar record'));
    });

    test('a long protein says it plays faster, and why', () {
      final String all = ListenCaptions.describe(
        audioOf(TestCatalog.dystrophin),
        TestCatalog.dystrophin,
      ).join(' ');
      expect(all, contains('about 31 a second'));
      expect(all, contains('Longer than 960 residues'));
      expect(all, contains('2 minutes'));
    });

    test('a residue as it sounds', () {
      final AudioTrack insulin = audioOf(TestCatalog.insulin);
      final String cys = ListenCaptions.residue(insulin, 30);
      expect(cys, startsWith('Cys31 · hydropathy +2.5, G5 · '));
      expect(cys, contains('conservation '));
      final String signal = ListenCaptions.residue(insulin, 0);
      expect(signal, contains('no structure, a hollow swell'));
    });

    test('no sentence says a variant does anything clinical', () {
      for (final ProteinTarget target in TestCatalog.all) {
        final AudioTrack track = audioOf(target);
        final List<String> said = <String>[
          ListenCaptions.mapping(track),
          ...ListenCaptions.describe(track, target),
          for (int i = 0; i < track.residues; i += 7)
            ListenCaptions.residue(track, i),
        ];
        for (final String line in said) {
          for (final String word in _clinical) {
            expect(line.toLowerCase(), isNot(contains(word)), reason: line);
          }
        }
      }
    });

    test('DNA mode in words: what splicing takes out', () {
      final AnatomyModel insulin = _model(TestCatalog.insulin);
      final String all = ListenCaptions.describeDna(
        DnaScore.of(insulin, spliced: false),
        DnaScore.of(insulin, spliced: true),
        TestCatalog.insulin,
      ).join(' ');
      expect(all, contains('111 codons'));
      expect(all, contains('One intron interrupts it: 787 bases'));
      expect(all, contains('Spliced, it is gone'));
      expect(all, isNot(contains('shortened')));

      final AnatomyModel dmd = _model(TestCatalog.dystrophin);
      expect(
        ListenCaptions.describeDna(
          DnaScore.of(dmd, spliced: false),
          DnaScore.of(dmd, spliced: true),
          TestCatalog.dystrophin,
        ).join(' '),
        contains('drawn shortened from'),
      );

      final AnatomyModel prion = _model(TestCatalog.prion);
      expect(
        ListenCaptions.describeDna(
          DnaScore.of(prion, spliced: false),
          DnaScore.of(prion, spliced: true),
          TestCatalog.prion,
        ).join(' '),
        contains('No intron interrupts its coding sequence'),
      );
    });

    test('a step as it sounds', () {
      final AnatomyModel insulin = _model(TestCatalog.insulin);
      final String protein = recordOf(TestCatalog.insulin).protein!.translation;
      final DnaScore gene = DnaScore.of(insulin, spliced: false);
      final DnaScore mrna = DnaScore.of(insulin, spliced: true);
      expect(
        ListenCaptions.dnaStep(gene, 0, protein),
        'codon 1 · ATG · Met1 · A3 E4 G5',
      );
      expect(
        ListenCaptions.dnaStep(mrna, 0, protein),
        startsWith('codon 1 · AUG'),
      );
      expect(
        ListenCaptions.dnaStep(mrna, mrna.steps.length - 1, protein),
        contains('· stop ·'),
      );
      final int intron = gene.steps.indexWhere(
        (DnaStep s) => s.kind == DnaStepKind.intron,
      );
      expect(
        ListenCaptions.dnaStep(gene, intron, protein),
        matches(RegExp(r'^intron 2 · [ACGT] · a grain$')),
      );
    });

    test('durations read as a sentence says them', () {
      expect(ListenCaptions.duration(13750), '13.8 seconds');
      expect(ListenCaptions.duration(96250), '1 minute 36 seconds');
      expect(ListenCaptions.duration(119993), '2 minutes');
    });
  });
}

/// The magnitude spectrum of [x], zero-padded to a power of two.
List<double> _spectrum(Float64List x) {
  int n = 1;
  while (n < x.length) {
    n <<= 1;
  }
  final List<double> re = List<double>.filled(n, 0);
  final List<double> im = List<double>.filled(n, 0);
  for (int i = 0; i < x.length; i++) {
    // Hann, so a note's sidelobes do not stand in for a neighbour.
    re[i] = x[i] * 0.5 * (1 - math.cos(2 * math.pi * i / (x.length - 1)));
  }
  // Iterative radix-2 FFT.
  for (int i = 1, j = 0; i < n; i++) {
    int bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final double r = re[i];
      re[i] = re[j];
      re[j] = r;
      final double m = im[i];
      im[i] = im[j];
      im[j] = m;
    }
  }
  for (int length = 2; length <= n; length <<= 1) {
    final double angle = -2 * math.pi / length;
    for (int i = 0; i < n; i += length) {
      for (int k = 0; k < length ~/ 2; k++) {
        final double wr = math.cos(angle * k);
        final double wi = math.sin(angle * k);
        final int a = i + k;
        final int b = a + length ~/ 2;
        final double tr = re[b] * wr - im[b] * wi;
        final double ti = re[b] * wi + im[b] * wr;
        re[b] = re[a] - tr;
        im[b] = im[a] - ti;
        re[a] += tr;
        im[a] += ti;
      }
    }
  }
  return <double>[
    for (int i = 0; i <= n ~/ 2; i++) math.sqrt(re[i] * re[i] + im[i] * im[i]),
  ];
}

/// The spectrum's peak within a few bins of [hz], for [length] samples.
double _near(List<double> spectrum, double hz, int length) {
  final int n = (spectrum.length - 1) * 2;
  final int bin = (hz * n / ListenTempo.sampleRate).round();
  double peak = 0;
  for (
    int k = math.max(0, bin - 3);
    k <= math.min(spectrum.length - 1, bin + 3);
    k++
  ) {
    peak = math.max(peak, spectrum[k]);
  }
  return peak;
}
