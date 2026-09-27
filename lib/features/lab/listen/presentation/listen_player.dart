import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// What Listen hands a player: a file's bytes, and a name whose extension
/// says what they are (`insulin.m4a`, `insulin-gene.wav`).
@immutable
final class ListenSource {
  const ListenSource({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// The one clock Listen follows.
///
/// A player says where it is, and the playhead goes there: [positions] is the
/// player's own position, as it reports it. Listen keeps no time of its own;
/// no timer, ticker or stopwatch moves the highlight, so what the reader sees
/// marked is what the player says it is playing, however it buffers, seeks or
/// stalls.
abstract interface class ListenPlayer {
  /// Where the player is in what it has loaded, as it reports it.
  Stream<Duration> get positions;

  /// Whether it is playing. False again once a piece has played to its end.
  Stream<bool> get playing;

  Future<void> load(ListenSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

typedef ListenPlayerFactory = ListenPlayer Function();

/// The platform's own player, through just_audio.
ListenPlayer platformListenPlayer() => JustAudioListenPlayer();

/// just_audio: ExoPlayer on Android, AVPlayer on iOS.
///
/// Both honour the edit list in the protein's `.m4a`, which skips the AAC
/// encoder's priming, so position zero is the first note; DNA mode's WAV has
/// no priming to skip. A piece is written to the temporary directory first,
/// as a player reads a file, not bytes.
final class JustAudioListenPlayer implements ListenPlayer {
  JustAudioListenPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  /// just_audio's own position, read once a frame: its last report from the
  /// platform, carried forward at the speed it is playing. A frame, because
  /// dystrophin plays 31 notes a second and a slower read would skip them.
  @override
  Stream<Duration> get positions => _player.createPositionStream(
    minPeriod: const Duration(milliseconds: 16),
    maxPeriod: const Duration(milliseconds: 16),
  );

  @override
  Stream<bool> get playing => _player.playerStateStream.map(
    (PlayerState state) =>
        state.playing && state.processingState != ProcessingState.completed,
  );

  @override
  Future<void> load(ListenSource source) async {
    final Directory temporary = await getTemporaryDirectory();
    final Directory folder = Directory(
      '${temporary.path}${Platform.pathSeparator}listen',
    );
    await folder.create(recursive: true);
    final File file = File(
      '${folder.path}${Platform.pathSeparator}${source.name}',
    );
    await file.writeAsBytes(source.bytes, flush: true);
    await _player.setFilePath(file.path);
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    // just_audio's play completes only when playback stops; the stream says
    // that, so nothing waits on it here.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
