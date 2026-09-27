import 'package:flutter/material.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/clinvar/sources_note.dart';
import '../../../../shared/format.dart';
import '../domain/audio_track.dart';
import '../domain/dna_score.dart';
import '../domain/dna_voice.dart';
import '../domain/listen_captions.dart';
import '../domain/playhead.dart';

/// What Listen's sound is, and is not, in the layout the walk's About sheet
/// uses: [SourcesNote], one paragraph a channel.
///
/// It says first that the mapping is arbitrary, then which property drives
/// which channel. The protein's channels are the track's own words (its
/// scale, its timbres and what each sounds like); where the protein's track is
/// not published, only DNA mode is described, since only it can be heard.
class ListenAbout extends StatelessWidget {
  const ListenAbout({required this.target, this.track, super.key});

  final ProteinTarget target;
  final AudioTrack? track;

  /// The sentence the sheet opens on.
  static const String statement =
      'A sonification is an arbitrary mapping chosen for teaching, not a '
      'measurement. The properties behind these sounds are measured; which '
      'sound each is given was chosen, and another choice would sound '
      'different and mean the same.';

  /// Which property drives which channel, one paragraph each.
  static List<SourceEntry> channels(AudioTrack? track) {
    final String note =
        '${ListenTempo.millisecondsOf(ListenTempo.noteSamples)} ms';
    return <SourceEntry>[
      if (track != null) ...<SourceEntry>[
        SourceEntry(
          name: 'Pitch',
          text:
              'Hydropathy, on ${track.pitchScale}’s scale: the more '
              'hydrophobic a residue, the higher its note, set on '
              '${track.pitchNotes}. A signal peptide or a stretch that '
              'crosses a membrane sounds as a high run.',
        ),
        SourceEntry(
          name: 'Timbre',
          text: track.foldingSource
              ? 'Secondary structure, from the solved fold'
                    '${track.foldingPdb == null ? '' : ' (PDB ${track.foldingPdb})'}: '
                    '${_timbres(track)}.'
              : 'One sound for every residue: this protein has no folding '
                    'track.',
        ),
        SourceEntry(
          name: 'Loudness',
          text: track.conservationSource
              ? 'Conservation, from the constraint track'
                    '${track.constraintModel == null ? '' : ' (${track.constraintModel})'}: '
                    'the most conserved residue plays at full level, the '
                    'least ${track.loudnessRangeDb.abs().toStringAsFixed(0)} '
                    'dB under it.'
              : 'One level for every residue: this protein has no '
                    'conservation track.',
        ),
        SourceEntry(
          name: 'Tick',
          text: track.accentSource
              ? '${_capital(track.accentSound)}: a ClinVar record at the '
                    'residue, in the snapshot'
                    '${track.clinvarRetrieved == null ? '' : ' of ${track.clinvarRetrieved!.split('T').first}'}'
                    ', whatever the record reports. A residue without a tick '
                    'has no record in the snapshot; that is not evidence '
                    'about the residue.'
              : 'None: no ClinVar snapshot is included for this protein.',
        ),
      ],
      SourceEntry(
        name: 'DNA mode',
        text:
            'Each codon is a chord of its three bases, the first lowest: A '
            'plays A, C plays C, G plays G, and T (U on the mRNA), which names '
            'no note, plays E. An intron base is a grain of '
            '${ListenTempo.millisecondsOf(DnaScore.grain)} ms, a rustle '
            'rather than a note, so the gene rustles where its introns are '
            'and the mRNA, spliced, does not. It plays from the start codon '
            'to the stop.',
      ),
      SourceEntry(
        name: 'Tempo',
        text:
            'A note lasts $note, ${spelled(ListenTempo.sampleRate ~/ ListenTempo.noteSamples)} a second. A protein longer '
            'than ${ListenTempo.longestSamples ~/ ListenTempo.noteSamples} '
            'residues plays faster, so that no piece passes '
            '${ListenCaptions.duration(ListenTempo.millisecondsOf(ListenTempo.longestSamples))}; '
            'a codon lasts as long as its residue does.',
      ),
    ];
  }

  static String _timbres(AudioTrack track) {
    final List<String> parts = <String>[
      for (final TimbreMapping m in track.timbres)
        if (m.timbre == NoteTimbre.none)
          'a residue the fold does not place is ${m.sound}'
        else
          'a ${m.structure} is ${m.sound}',
    ];
    return parts.join('; ');
  }

  static String _capital(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey<String>('listen-about-sheet'),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'About this sound',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              statement,
              key: const ValueKey<String>('listen-about-statement'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SourcesNote(sources: channels(track)),
            Text(
              'Chord notes, lowest first: '
              '${DnaVoice.chordOf('ATG').map(DnaVoice.nameOf).join(' ')} is '
              'ATG, the start codon.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
