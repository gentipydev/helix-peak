import '../../../../core/biology/amino_acids.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../shared/format.dart';
import 'audio_track.dart';
import 'dna_score.dart';
import 'dna_voice.dart';
import 'playhead.dart';

/// Every sentence Listen says, built from the track and the record: what a
/// piece maps, the piece in words for a reader who cannot hear it, and the
/// note sounding now.
///
/// A ClinVar record is named as a record in a snapshot and nothing more: what
/// it reports is ClinVar's to say, on the walk's own sheets (R9.1), and a
/// residue without one is not evidence of anything (R9.3).
abstract final class ListenCaptions {
  // -- the protein's own track -------------------------------------------------

  /// What the protein's sound maps: said once, as its piece is shown.
  static String mapping(AudioTrack track) =>
      'Each residue is a note: ${_clauses(<String>['its pitch is its hydropathy, higher the more hydrophobic', if (track.foldingSource) 'its sound is the structure the fold places it in' else 'every note is one sound, with no folding track to say more', if (track.conservationSource) 'its loudness is its conservation, louder the more conserved' else 'every note is one level, with no conservation track', if (track.accentSource) 'a tick opens a residue with a ClinVar record'])}.';

  /// The piece in words: the text alternative to listening to it.
  static List<String> describe(AudioTrack track, ProteinTarget target) {
    final int n = track.residues;
    final List<String> out = <String>[
      '${target.display} plays ${grouped(n)} notes, one a residue, over '
          '${duration(track.durationMs)}: ${_rate(track.noteSamples)} a second.'
          '${track.noteSamples < ListenTempo.noteSamples ? ' Longer than '
                    '${grouped(ListenTempo.longestSamples ~/ ListenTempo.noteSamples)} '
                    'residues, it plays faster, to fit in '
                    '${duration(ListenTempo.millisecondsOf(ListenTempo.longestSamples))}.' : ''}',
    ];

    final int width = n < 10 ? n : 10;
    final (int high, int low) = _extremes(track.pitch, width);
    out.add(
      'Its highest stretch, residues ${high + 1} to ${high + width}, is its '
      'most hydrophobic; its lowest, residues ${low + 1} to ${low + width}, '
      'its most hydrophilic. The notes run from '
      '${DnaVoice.nameOf(_min(track.pitch))} to '
      '${DnaVoice.nameOf(_max(track.pitch))} on ${track.pitchNotes}, by '
      '${track.pitchScale}.',
    );

    if (!track.foldingSource) {
      out.add(
        'Every residue is ${track.mappingOf(NoteTimbre.none).sound}: the '
        'protein has no folding track.',
      );
    } else {
      final List<String> parts = <String>[];
      for (final TimbreMapping m in track.timbres) {
        final int count = track.timbre
            .where((NoteTimbre t) => t == m.timbre)
            .length;
        if (count == 0) {
          continue;
        }
        final String residues =
            '${grouped(count)} residue${count == 1 ? '' : 's'}';
        parts.add(
          m.timbre == NoteTimbre.none
              ? '$residues with no structure the solved fold places, '
                    '${m.sound}'
              : '$residues in a ${m.structure}, ${m.sound}',
        );
      }
      out.add('${_capital(_clauses(parts))}.');
    }

    out.add(
      track.conservationSource
          ? 'The most conserved residues play at full level and the least '
                '${_db(track.loudnessRangeDb)} under it'
                '${track.constraintModel == null ? '' : ', by ${track.constraintModel}'}.'
          : 'Every note plays ${_db(track.flatDb)} under full: the protein '
                'has no conservation track.',
    );

    if (!track.accentSource) {
      out.add('No ClinVar snapshot is included, so no note has a tick.');
    } else if (track.accent.isEmpty) {
      out.add(
        'No residue has a ClinVar record in this snapshot, so no note has a tick.',
      );
    } else {
      out.add(
        '${grouped(track.accent.length)} of ${grouped(n)} residues have a '
        'ClinVar record in the snapshot'
        '${track.clinvarRetrieved == null ? '' : ' of ${track.clinvarRetrieved!.split('T').first}'}'
        ', and open with a tick.',
      );
    }
    return out;
  }

  /// Residue [index] (from 0), as it sounds: the caption while the piece is
  /// paused on it or stepped to it.
  static String residue(AudioTrack track, int index) {
    final String code = track.sequence[index];
    final NoteTimbre timbre = track.timbre[index];
    final TimbreMapping sound = track.mappingOf(timbre);
    final double? level = track.loudness?[index];
    return <String>[
      '${AminoAcids.abbreviationOf(code)}${index + 1}',
      'hydropathy ${formatScore(track.hydropathy[code] ?? 0)}, '
          '${DnaVoice.nameOf(track.pitch[index])}',
      timbre == NoteTimbre.none
          ? 'no structure, ${sound.sound}'
          : '${sound.structure}, ${sound.sound}',
      if (level != null) 'conservation ${level.toStringAsFixed(2)}',
      if (track.accent.contains(index + 1)) 'a ClinVar record',
    ].join(' · ');
  }

  // -- DNA mode ----------------------------------------------------------------

  /// What DNA mode maps: said as it is chosen.
  static String dnaMapping({required bool spliced}) =>
      'Each codon is a chord of its three bases, the first lowest: A plays A, '
      'C plays C, G plays G, and T, which names no note, plays E. '
      '${spliced ? 'Spliced, as the mRNA is: the introns are gone and the '
                'codons run on.' : 'Between codons, an intron rustles: a short grain '
                'a base.'}';

  /// DNA mode in words: what the gene plays, and what splicing takes out.
  static List<String> describeDna(
    DnaScore gene,
    DnaScore mrna,
    ProteinTarget target,
  ) => <String>[
    'Its gene plays ${grouped(gene.codons)} codons as chords, from the start '
        'codon to the stop, over ${duration(gene.durationMs)}.',
    if (gene.introns == 0)
      'No intron interrupts its coding sequence, so its gene and its mRNA '
          'sound the same.'
    else
      '${spelledLeading(gene.introns)} intron${gene.introns == 1 ? '' : 's'} '
          '${gene.introns == 1 ? 'interrupts' : 'interrupt'} it: '
          '${grouped(gene.intronBases)} bases, a grain each'
          '${gene.intronBases < gene.intronLengthBp ? ', drawn shortened from '
                    '${grouped(gene.intronLengthBp)}, and played as drawn' : ''}. '
          'Spliced, ${gene.introns == 1 ? 'it is' : 'they are'} gone, and the '
          'chords run on for ${duration(mrna.durationMs)}.',
  ];

  /// Step [index] of [score], as it sounds. [protein] is the translation,
  /// which names the residue a codon codes for.
  static String dnaStep(DnaScore score, int index, String protein) {
    final DnaStep step = score.steps[index];
    if (step.kind == DnaStepKind.intron) {
      return '${step.intron} · ${step.bases} · a grain';
    }
    final int codon = step.codon!;
    final String bases = score.spliced
        ? step.bases.replaceAll('T', 'U')
        : step.bases;
    return <String>[
      'codon ${grouped(codon + 1)}',
      bases,
      if (codon < protein.length)
        '${AminoAcids.abbreviationOf(protein[codon])}${codon + 1}'
      else
        'stop',
      DnaVoice.chordOf(step.bases).map(DnaVoice.nameOf).join(' '),
    ].join(' · ');
  }

  // -- in common ---------------------------------------------------------------

  /// How long a piece lasts, as a sentence says it: `13.8 seconds`,
  /// `1 minute 36 seconds`, `2 minutes`.
  static String duration(int ms) {
    if (ms < 60000) {
      return '${(ms / 1000).toStringAsFixed(1)} seconds';
    }
    final int seconds = (ms / 1000).round();
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    final String whole = '$minutes minute${minutes == 1 ? '' : 's'}';
    return rest == 0 ? whole : '$whole $rest second${rest == 1 ? '' : 's'}';
  }

  /// Notes a second: `eight`, or `about 31` where it is not a whole number.
  static String _rate(int noteSamples) {
    final double rate = ListenTempo.sampleRate / noteSamples;
    return rate == rate.roundToDouble()
        ? spelled(rate.round())
        : 'about ${rate.round()}';
  }

  static String _db(double db) => '${db.abs().toStringAsFixed(0)} dB';

  /// Where the highest and the lowest [width] notes in a row start.
  static (int, int) _extremes(List<int> pitch, int width) {
    int sum = 0;
    for (int i = 0; i < width; i++) {
      sum += pitch[i];
    }
    int high = 0;
    int low = 0;
    int best = sum;
    int worst = sum;
    for (int i = width; i < pitch.length; i++) {
      sum += pitch[i] - pitch[i - width];
      final int start = i - width + 1;
      if (sum > best) {
        best = sum;
        high = start;
      }
      if (sum < worst) {
        worst = sum;
        low = start;
      }
    }
    return (high, low);
  }

  static int _min(List<int> values) =>
      values.reduce((int a, int b) => a < b ? a : b);

  static int _max(List<int> values) =>
      values.reduce((int a, int b) => a > b ? a : b);

  /// Clauses that carry commas of their own, set apart by semicolons.
  static String _clauses(List<String> parts) => switch (parts.length) {
    0 => '',
    1 => parts.single,
    _ => '${parts.sublist(0, parts.length - 1).join('; ')}; and ${parts.last}',
  };

  static String _capital(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
