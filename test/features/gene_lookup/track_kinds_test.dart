import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/domain/entities/protein_track.dart';

/// What lets the service serve a new kind of track without touching the walk
/// or breaking an app already installed: `tracksFromJson` skips a key
/// `TrackKind.fromWire` cannot classify, and `TrackState.fromWire` reads a
/// state it does not know as absent. These pin both, so a later change that
/// started throwing on either would fail here before it failed a reader.
void main() {
  Map<String, dynamic> row(String state) => <String, dynamic>{
    'state': state,
    'reason': null,
    'url': state == 'ready' ? 'https://cdn.example/x.json' : null,
    'format': 'json',
    'bytes': null,
    'sha256': state == 'ready' ? 'abc123' : null,
    'content_encoding': null,
    'provenance': <String, dynamic>{'model': 'm'},
  };

  test('a payload naming an unknown kind parses, without that kind', () {
    expect(TrackKind.fromWire('hologram'), isNull);
    final Map<TrackKind, TrackRef> tracks = tracksFromJson(<String, dynamic>{
      'hologram': row('ready'),
    });
    expect(tracks, isEmpty);
  });

  test('an unknown kind as a bare catalog state parses the same way', () {
    final Map<TrackKind, TrackRef> tracks = tracksFromJson(<String, dynamic>{
      'hologram': 'ready',
      'record': 'ready',
    });
    expect(tracks.keys, <TrackKind>[TrackKind.record]);
  });

  test('an unknown state on a known kind reads as absent, not a throw', () {
    expect(TrackState.fromWire('shimmering'), TrackState.absent);
    expect(TrackState.fromWire(null), TrackState.absent);

    final Map<TrackKind, TrackRef> full = tracksFromJson(<String, dynamic>{
      'clinvar': row('shimmering'),
    });
    expect(full[TrackKind.clinvar]!.state, TrackState.absent);

    final Map<TrackKind, TrackRef> bare = tracksFromJson(<String, dynamic>{
      'constraint': 'shimmering',
    });
    expect(bare[TrackKind.constraint]!.state, TrackState.absent);
  });

  test('known kinds beside unknown ones come through intact', () {
    final Map<String, dynamic> refused = row('refused')
      ..['reason'] = 'The exons exceed the page budget.';
    final Map<TrackKind, TrackRef> tracks = tracksFromJson(<String, dynamic>{
      'record': row('ready'),
      'hologram': row('ready'),
      'constraint': refused,
      'smell': 'pending',
      'impact': 'pending',
      'clinvar': row('absent'),
    });

    expect(
      tracks.keys.toSet(),
      <TrackKind>{
        TrackKind.record,
        TrackKind.constraint,
        TrackKind.impact,
        TrackKind.clinvar,
      },
    );
    final TrackRef record = tracks[TrackKind.record]!;
    expect(record.state, TrackState.ready);
    expect(record.url, 'https://cdn.example/x.json');
    expect(record.sha256, 'abc123');
    expect(record.format, 'json');
    expect(record.provenance, <String, dynamic>{'model': 'm'});
    expect(tracks[TrackKind.constraint]!.state, TrackState.refused);
    expect(
      tracks[TrackKind.constraint]!.reason,
      'The exons exceed the page budget.',
    );
    expect(tracks[TrackKind.impact]!.state, TrackState.pending);
    expect(tracks[TrackKind.clinvar]!.state, TrackState.absent);
  });

  test('every planned kind is classified, so a row naming one is kept', () {
    for (final String wire in <String>[
      'folding',
      'structure_ar',
      'trafficking',
      'locus',
      'audio',
    ]) {
      expect(TrackKind.fromWire(wire)?.wire, wire);
    }
  });
}
