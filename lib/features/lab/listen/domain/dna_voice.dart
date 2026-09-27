import 'dart:math' as math;
import 'dart:typed_data';

import 'dna_score.dart';
import 'playhead.dart';

/// DNA mode's sound, made on the phone from the record: a chord a codon and
/// a grain an intron base, as 16-bit mono WAV at [ListenTempo.sampleRate].
///
/// The protein's own sound is baked by the backend; this is the one piece the
/// app synthesises, because nothing but the record is needed to make it.
///
/// **A base's note** is its own letter where the letter names one: A plays A,
/// C plays C, G plays G; T (and U, on the mRNA), which names no note, plays
/// E. All four sit on the pentatonic scale the protein's notes are on.
/// **A codon's chord** is its three bases at once, the first an octave below
/// middle C's, the second in it, the third an octave above, so low to high is
/// 5' to 3' and a codon of one letter is still three notes. **An intron base**
/// is a 5 ms grain of its note in middle C's octave: too short to hear as a
/// pitch, a rustle rather than a chord, which is the difference splicing
/// removes.
abstract final class DnaVoice {
  /// A base's note in [octave], as a MIDI note number (middle C is C4, 60).
  static int pitchOf(String base, int octave) {
    final int step = switch (base) {
      'A' => 9,
      'C' => 0,
      'G' => 7,
      'T' || 'U' => 4,
      _ => throw ArgumentError.value(base, 'base', 'not a base'),
    };
    return 12 * (octave + 1) + step;
  }

  /// A codon's chord, lowest first: its three bases, 5' to 3', each an
  /// octave above the last.
  static List<int> chordOf(String codon) => <int>[
    pitchOf(codon[0], 3),
    pitchOf(codon[1], 4),
    pitchOf(codon[2], 5),
  ];

  static int grainOf(String base) => pitchOf(base, 4);

  /// The name a note is written with: `A3`, `E4`, `G5`.
  static String nameOf(int pitch) {
    const List<String> names = <String>[
      'C', 'C♯', 'D', 'E♭', 'E', 'F', 'F♯', 'G', 'A♭', 'A', 'B♭', 'B', //
    ];
    return '${names[pitch % 12]}${pitch ~/ 12 - 1}';
  }

  static double hertz(int pitch) => 440.0 * math.pow(2, (pitch - 69) / 12);

  /// Each chord note's harmonics, fundamental first: a soft organ.
  static const List<double> partials = <double>[1, 0.35, 0.12];

  /// A chord at full level stays well under full scale: each of its three
  /// notes is as loud as a sine of this amplitude (`test_nothing_clips`).
  static const double chordLevel = 0.15;

  /// An intron base's grain, quieter than a chord.
  static const double grainLevel = 0.3;

  /// The piece, one sample at a time.
  static Int16List render(DnaScore score) {
    final Int16List out = Int16List(score.samples);
    final Map<String, Float64List> chords = <String, Float64List>{};
    final Map<String, Float64List> grains = <String, Float64List>{};
    for (final DnaStep step in score.steps) {
      final Float64List sound = switch (step.kind) {
        DnaStepKind.codon => chords.putIfAbsent(
          step.bases,
          () => chord(step.bases, step.length),
        ),
        DnaStepKind.intron => grains.putIfAbsent(
          step.bases,
          () => grain(step.bases, step.length),
        ),
      };
      for (int i = 0; i < step.length; i++) {
        out[step.onset + i] = (sound[i] * 32767).round().clamp(-32768, 32767);
      }
    }
    return out;
  }

  /// A codon's chord, [n] samples long: a short rise, held, and a fall to
  /// silence over its last sixth, so no chord clicks into the next.
  static Float64List chord(String codon, int n) {
    final Float64List out = Float64List(n);
    final double norm = math.sqrt(
      partials.fold<double>(0, (double sum, double a) => sum + a * a) / 2,
    );
    for (final int pitch in chordOf(codon)) {
      final double f = hertz(pitch);
      for (int i = 0; i < n; i++) {
        final double t = i / ListenTempo.sampleRate;
        double wave = 0;
        for (int k = 0; k < partials.length; k++) {
          wave += partials[k] * math.sin(2 * math.pi * (k + 1) * f * t);
        }
        out[i] += chordLevel * wave / norm;
      }
    }
    final int rise = math.max(1, (n * 0.05).round());
    final int fall = math.max(2, (n * 0.15).round());
    for (int i = 0; i < n; i++) {
      double shape = i < rise ? i / rise : 1;
      if (i >= n - fall) {
        shape *= (n - 1 - i) / (fall - 1);
      }
      out[i] *= shape;
    }
    return out;
  }

  /// An intron base's grain, [n] samples long: its note, struck and gone.
  static Float64List grain(String base, int n) {
    final Float64List out = Float64List(n);
    final double f = hertz(grainOf(base));
    final double decay = n / 4;
    for (int i = 0; i < n; i++) {
      final double rise = i < 4 ? i / 4 : 1;
      out[i] =
          grainLevel *
          rise *
          math.exp(-i / decay) *
          math.sin(2 * math.pi * f * i / ListenTempo.sampleRate);
    }
    out[n - 1] = 0;
    return out;
  }

  /// [samples] as a WAV file: RIFF, 16-bit PCM, one channel.
  static Uint8List wav(Int16List samples) {
    const int rate = ListenTempo.sampleRate;
    final int data = samples.length * 2;
    final ByteData header = ByteData(44)
      ..setUint32(0, 0x52494646) // RIFF
      ..setUint32(4, 36 + data, Endian.little)
      ..setUint32(8, 0x57415645) // WAVE
      ..setUint32(12, 0x666d7420) // 'fmt '
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, 1, Endian.little) // mono
      ..setUint32(24, rate, Endian.little)
      ..setUint32(28, rate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461) // data
      ..setUint32(40, data, Endian.little);
    final Uint8List out = Uint8List(44 + data)
      ..setAll(0, header.buffer.asUint8List());
    final ByteData body = ByteData.sublistView(out, 44);
    for (int i = 0; i < samples.length; i++) {
      body.setInt16(i * 2, samples[i], Endian.little);
    }
    return out;
  }
}
