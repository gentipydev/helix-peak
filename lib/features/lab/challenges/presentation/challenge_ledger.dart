import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/puzzle_generator.dart';

/// One day's play: each round right or not, and each codon of the codon round.
@immutable
final class DayResult {
  const DayResult({
    required this.day,
    required this.rounds,
    required this.codons,
  });

  factory DayResult.fromJson(String day, Map<String, dynamic> json) =>
      DayResult(
        day: day,
        rounds: List<bool>.unmodifiable(
          (json['rounds'] as List<dynamic>).cast<bool>(),
        ),
        codons: List<bool>.unmodifiable(
          (json['codons'] as List<dynamic>).cast<bool>(),
        ),
      );

  final String day;
  final List<bool> rounds;
  final List<bool> codons;

  /// Rounds got right.
  int get right => rounds.where((bool r) => r).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rounds': rounds,
    'codons': codons,
  };
}

/// Where a reader's days are kept: on this phone, in the lab's own folder,
/// and nowhere else. No account, no leaderboard, no network.
abstract interface class ChallengeLedger {
  Future<Map<String, DayResult>> read();
  Future<void> write(DayResult result);
}

/// `lab/challenges/days.json` under the application support directory.
///
/// Like the track cache, it answers empty and does nothing where there is no
/// filesystem to use: a streak is a pleasure, not a dependency.
final class FileLedger implements ChallengeLedger {
  FileLedger({Directory? directory}) : _given = directory;

  /// Where under the application support directory the days go: the lab's.
  static const String folder = 'lab/challenges';

  final Directory? _given;

  Future<File?> _file() async {
    try {
      final Directory base = _given ?? await getApplicationSupportDirectory();
      final Directory directory = Directory('${base.path}/$folder');
      await directory.create(recursive: true);
      return File('${directory.path}/days.json');
    } on Object {
      return null;
    }
  }

  @override
  Future<Map<String, DayResult>> read() async {
    final File? file = await _file();
    try {
      if (file == null || !file.existsSync()) {
        return <String, DayResult>{};
      }
      final Map<String, dynamic> json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return <String, DayResult>{
        for (final MapEntry<String, dynamic> entry in json.entries)
          entry.key: DayResult.fromJson(
            entry.key,
            entry.value as Map<String, dynamic>,
          ),
      };
    } on Object {
      return <String, DayResult>{};
    }
  }

  @override
  Future<void> write(DayResult result) async {
    final File? file = await _file();
    if (file == null) {
      return;
    }
    final Map<String, DayResult> days = await read()
      ..[result.day] = result;
    try {
      // Beside and renamed, as the track cache writes: a process killed
      // mid-write leaves the last good file, not half of a new one.
      final File pending = File('${file.path}.part');
      await pending.writeAsString(
        jsonEncode(<String, dynamic>{
          for (final MapEntry<String, DayResult> entry in days.entries)
            entry.key: entry.value.toJson(),
        }),
        flush: true,
      );
      await pending.rename(file.path);
    } on Object {
      return;
    }
  }
}

/// Days played in a row, ending today, or yesterday where today is not played
/// yet: a streak lasts until a whole day passes unplayed.
int streakOf(Map<String, DayResult> days, DateTime today) {
  DateTime at = DateTime(today.year, today.month, today.day);
  if (!days.containsKey(PuzzleGenerator.dayOf(at))) {
    at = DateTime(at.year, at.month, at.day - 1);
  }
  int streak = 0;
  while (days.containsKey(PuzzleGenerator.dayOf(at))) {
    streak++;
    at = DateTime(at.year, at.month, at.day - 1);
  }
  return streak;
}
