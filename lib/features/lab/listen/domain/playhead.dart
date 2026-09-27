/// Which note is sounding at [ms] on a piece whose notes start at [onsets]
/// (ascending, the first at zero): the last one to have started. Before the
/// first, the first; past the end, the last.
///
/// This is the whole of how Listen's highlight moves: a position the audio
/// player reports goes in, a note comes out. Nothing here keeps time.
int noteAt(List<int> onsets, int ms) {
  if (onsets.isEmpty) {
    throw ArgumentError('a piece with no notes');
  }
  int low = 0;
  int high = onsets.length - 1;
  if (ms <= onsets[low]) {
    return 0;
  }
  if (ms >= onsets[high]) {
    return high;
  }
  // Invariant: onsets[low] <= ms < onsets[high].
  while (high - low > 1) {
    final int middle = (low + high) >> 1;
    if (onsets[middle] <= ms) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return low;
}

/// How long each note of a piece of [notes] notes lasts, in samples at
/// [sampleRate]: an eighth of a second, or shorter where that would run the
/// piece past two minutes. Null where a note would be under 25 ms, a click
/// rather than a pitch.
///
/// The rule the backend's `pipeline/audio/bake_audio.py` bakes the protein's
/// own track by (`note_samples`); DNA mode keeps it, so a codon lasts as long
/// as the residue it codes for. A test holds the two to each other.
abstract final class ListenTempo {
  static const int sampleRate = 16000;

  /// 125 ms: eight notes a second.
  static const int noteSamples = 2000;

  /// Two minutes.
  static const int longestSamples = 120 * sampleRate;

  /// 25 ms.
  static const int shortestNoteSamples = 400;

  static int? noteSamplesFor(int notes) {
    if (notes < 1) {
      return null;
    }
    final int fitted = longestSamples ~/ notes;
    final int samples = fitted < noteSamples ? fitted : noteSamples;
    return samples < shortestNoteSamples ? null : samples;
  }

  /// [samples] at [sampleRate] in milliseconds, to the nearest, half up: the
  /// rounding the backend's onsets use.
  static int millisecondsOf(int samples) =>
      (2 * samples * 1000 + sampleRate) ~/ (2 * sampleRate);
}
