import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/track_source.dart';

/// The sound a residue's note is played in: the structure the fold places it
/// in, as the track's map writes it, one letter a residue.
enum NoteTimbre {
  helix('H'),
  strand('E'),
  coil('C'),

  /// Nothing the fold says: outside the solved chains, or loose in them, or
  /// every residue of a protein with no folding track.
  none('-');

  const NoteTimbre(this.code);

  final String code;

  static NoteTimbre fromCode(String code) {
    for (final NoteTimbre timbre in NoteTimbre.values) {
      if (timbre.code == code) {
        return timbre;
      }
    }
    throw FormatException('A timbre the audio track does not define: $code');
  }
}

/// One timbre as the track describes it: the structure and what it sounds like.
@immutable
final class TimbreMapping {
  const TimbreMapping({
    required this.timbre,
    required this.structure,
    required this.sound,
  });

  final NoteTimbre timbre;

  /// `helix`, `strand`, `coil`, `none`: the folding track's word.
  final String structure;

  /// `a held reed`: what a reader hears.
  final String sound;
}

/// The `audio` track: a protein as sound, one note a residue, and the map
/// from each residue to the millisecond its note starts.
///
/// Baked by `pipeline/audio/` in the backend. The file is an `.m4a` whose map
/// rides in a `uuid` box after the audio (ISO/IEC 14496-12's place for data it
/// does not define), so the track is one object: the player plays the bytes
/// as they are, and this reads the map out of them. The edit list in the file
/// skips the encoder's priming, so the player's position zero is the first
/// note's first sample and the map's onsets are exact.
///
/// Pitch is hydropathy, timbre secondary structure, loudness conservation,
/// and a tick marks a residue a ClinVar record is reported at. The mapping is
/// the track's, and so is how it is described: [pitchScale], [timbres] and
/// the rest are read from the file, never written again here.
@immutable
final class AudioTrack {
  const AudioTrack({
    required this.audio,
    required this.sequence,
    required this.sampleRate,
    required this.samples,
    required this.durationMs,
    required this.noteSamples,
    required this.onsetMs,
    required this.pitch,
    required this.timbre,
    required this.loudness,
    required this.accent,
    required this.pitchScale,
    required this.pitchNotes,
    required this.hydropathy,
    required this.timbres,
    required this.foldingSource,
    required this.loudnessRangeDb,
    required this.flatDb,
    required this.conservationSource,
    required this.accentSource,
    required this.accentSound,
    required this.foldingPdb,
    required this.constraintModel,
    required this.clinvarRetrieved,
  });

  /// Parses one file, refusing one that carries no map, names another
  /// protein, or whose map is not one entry a residue.
  factory AudioTrack.fromM4a(Uint8List bytes, ProteinTarget target) {
    final Uint8List? carried = mapOf(bytes);
    if (carried == null) {
      throw FormatException(
        'The audio track for ${target.slug} carries no map',
      );
    }
    final Map<String, dynamic> map =
        jsonDecode(utf8.decode(carried)) as Map<String, dynamic>;
    if (map['slug'] != target.slug ||
        map['gene'] != target.gene ||
        map['uniprot'] != target.uniprot) {
      throw FormatException(
        'An audio track for another protein, not ${target.slug}',
      );
    }
    if (map['schema_version'] != schemaVersion) {
      throw FormatException(
        'An audio track this app cannot read: schema '
        '${map['schema_version']}',
      );
    }
    final int residues = map['residues'] as int;
    final String sequence = map['sequence'] as String;
    final List<int> onsets = _ints(map['onset_ms']);
    final List<int> pitch = _ints(map['pitch']);
    final String timbres = map['timbre'] as String;
    final List<dynamic>? loud = map['loudness'] as List<dynamic>?;
    if (residues != target.facts.residues ||
        sequence.length != residues ||
        onsets.length != residues ||
        pitch.length != residues ||
        timbres.length != residues ||
        (loud != null && loud.length != residues)) {
      throw FormatException(
        'The audio track for ${target.slug} is not one note a residue',
      );
    }
    for (int i = 1; i < onsets.length; i++) {
      if (onsets[i] <= onsets[i - 1]) {
        throw FormatException(
          'The audio track for ${target.slug} goes back in time at residue '
          '${i + 1}',
        );
      }
    }
    final Map<String, dynamic> audio = map['audio'] as Map<String, dynamic>;
    final Map<String, dynamic> tempo = map['tempo'] as Map<String, dynamic>;
    final Map<String, dynamic> mapping = map['mapping'] as Map<String, dynamic>;
    final Map<String, dynamic> pitchMap =
        mapping['pitch'] as Map<String, dynamic>;
    final Map<String, dynamic> timbreMap =
        mapping['timbre'] as Map<String, dynamic>;
    final Map<String, dynamic> loudnessMap =
        mapping['loudness'] as Map<String, dynamic>;
    final Map<String, dynamic> accentMap =
        mapping['accent'] as Map<String, dynamic>;
    final Map<String, dynamic> sources =
        map['sources'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final List<dynamic> range = loudnessMap['range_db'] as List<dynamic>;
    return AudioTrack(
      audio: bytes,
      sequence: sequence,
      sampleRate: audio['sample_rate'] as int,
      samples: audio['samples'] as int,
      durationMs: audio['duration_ms'] as int,
      noteSamples: tempo['note_samples'] as int,
      onsetMs: Int32List.fromList(onsets),
      pitch: Uint8List.fromList(pitch),
      timbre: List<NoteTimbre>.unmodifiable(<NoteTimbre>[
        for (int i = 0; i < timbres.length; i++)
          NoteTimbre.fromCode(timbres[i]),
      ]),
      loudness: loud == null
          ? null
          : Float64List.fromList(<double>[
              for (final dynamic level in loud) (level as num).toDouble(),
            ]),
      accent: Set<int>.unmodifiable(_ints(map['accent'])),
      pitchScale: pitchMap['scale'] as String,
      pitchNotes: pitchMap['notes'] as String,
      hydropathy: Map<String, double>.unmodifiable(<String, double>{
        for (final MapEntry<String, dynamic> entry
            in (pitchMap['hydropathy'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as num).toDouble(),
      }),
      timbres: List<TimbreMapping>.unmodifiable(<TimbreMapping>[
        for (final dynamic raw in timbreMap['timbres'] as List<dynamic>)
          TimbreMapping(
            timbre: NoteTimbre.fromCode(
              (raw as Map<String, dynamic>)['code'] as String,
            ),
            structure: raw['structure'] as String,
            sound: raw['sound'] as String,
          ),
      ]),
      foldingSource: timbreMap['source'] != null,
      loudnessRangeDb: (range.first as num).toDouble(),
      flatDb: (loudnessMap['flat_db'] as num).toDouble(),
      conservationSource: loudnessMap['source'] != null,
      accentSource: accentMap['source'] != null,
      accentSound: accentMap['sound'] as String,
      foldingPdb:
          (sources['folding'] as Map<String, dynamic>?)?['pdb'] as String?,
      constraintModel:
          (sources['constraint'] as Map<String, dynamic>?)?['model'] as String?,
      clinvarRetrieved:
          (sources['clinvar'] as Map<String, dynamic>?)?['retrieved_at']
              as String?,
    );
  }

  /// [target]'s track, read through [tracks].
  static Future<AudioTrack> load(
    ProteinTarget target, {
    required TrackSource tracks,
  }) async => AudioTrack.fromM4a(
    await tracks.read(target.slug, TrackKind.audio),
    target,
  );

  /// The map's version this app reads.
  static const int schemaVersion = 1;

  /// The identifier of the box the map rides in: `MAP_UUID` in the backend's
  /// `pipeline/audio/m4a.py`.
  static final Uint8List mapUuid = Uint8List.fromList(<int>[
    0x6a, 0x05, 0xe1, 0xb0, 0x31, 0x33, 0x56, 0x06, //
    0xaa, 0x35, 0xc3, 0x37, 0x8b, 0x60, 0x7c, 0x32,
  ]);

  /// The map's bytes: the body of the file's one top-level `uuid` box named
  /// [mapUuid], or null where there is none. Refuses a file whose boxes do
  /// not add up, or that carries two maps.
  static Uint8List? mapOf(Uint8List bytes) {
    final ByteData data = ByteData.sublistView(bytes);
    Uint8List? found;
    int at = 0;
    while (at < bytes.length) {
      if (bytes.length - at < 8) {
        throw FormatException('${bytes.length - at} stray bytes at $at');
      }
      int size = data.getUint32(at);
      final String kind = String.fromCharCodes(bytes, at + 4, at + 8);
      int header = 8;
      if (size == 1) {
        if (bytes.length - at < 16) {
          throw FormatException('The $kind box at $at is cut short');
        }
        size = data.getUint32(at + 8) * 0x100000000 + data.getUint32(at + 12);
        header = 16;
      } else if (size == 0) {
        size = bytes.length - at;
      }
      if (size < header || at + size > bytes.length) {
        throw FormatException('The $kind box at $at claims $size bytes');
      }
      if (kind == 'uuid' &&
          size >= header + 16 &&
          listEquals(
            Uint8List.sublistView(bytes, at + header, at + header + 16),
            mapUuid,
          )) {
        if (found != null) {
          throw const FormatException('The file carries two maps');
        }
        found = Uint8List.sublistView(bytes, at + header + 16, at + size);
      }
      at += size;
    }
    return found;
  }

  static List<int> _ints(Object? raw) => <int>[
    for (final dynamic value in raw as List<dynamic>) value as int,
  ];

  /// The file as stored: what the player is handed.
  final Uint8List audio;

  /// The record's translation, the residues played.
  final String sequence;

  final int sampleRate;

  /// Samples the file plays, and how long that is.
  final int samples;
  final int durationMs;

  /// How long each note is, in samples.
  final int noteSamples;

  /// The timing map: when each residue's note starts, in milliseconds, the
  /// first at zero.
  final Int32List onsetMs;

  /// Each residue's note, as a MIDI note number.
  final Uint8List pitch;

  final List<NoteTimbre> timbre;

  /// Each residue's conservation, 0 to 1, or null for a protein with no
  /// constraint track, whose notes all play at [flatDb].
  final Float64List? loudness;

  /// The residues a tick opens: those a ClinVar record is reported at,
  /// numbered from 1.
  final Set<int> accent;

  /// `Kyte & Doolittle 1982`, and the scale it is set on:
  /// `C major pentatonic, C4 to C6`.
  final String pitchScale;
  final String pitchNotes;

  /// Each residue's hydropathy on [pitchScale], by one-letter code.
  final Map<String, double> hydropathy;

  final List<TimbreMapping> timbres;

  /// Whether the timbres came from a folding track, or the protein has none.
  final bool foldingSource;

  /// The quietest level, in decibels under full, where the least conserved
  /// residue plays; the most conserved plays at full.
  final double loudnessRangeDb;

  /// The one level every note plays at when there is no constraint track.
  final double flatDb;

  final bool conservationSource;

  /// Whether ticks came from a ClinVar snapshot, and what a tick sounds like.
  final bool accentSource;
  final String accentSound;

  /// Where the mapping came from: the fold's PDB entry, the constraint
  /// model, the ClinVar snapshot's date.
  final String? foldingPdb;
  final String? constraintModel;
  final String? clinvarRetrieved;

  int get residues => sequence.length;

  /// What [timbre] sounds like, as the track says.
  TimbreMapping mappingOf(NoteTimbre timbre) =>
      timbres.firstWhere((TimbreMapping m) => m.timbre == timbre);

  /// The level residue [index] (from 0) plays at, in decibels under full.
  double levelDbOf(int index) {
    final Float64List? levels = loudness;
    return levels == null ? flatDb : loudnessRangeDb * (1 - levels[index]);
  }

  Duration get duration => Duration(milliseconds: durationMs);
}
