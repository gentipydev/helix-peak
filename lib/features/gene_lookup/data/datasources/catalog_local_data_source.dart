import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The last catalog the service served, kept on disk.
///
/// Every method answers null or does nothing when the filesystem is not there,
/// and none of them throws. That is not defensiveness for its own sake: there
/// is no documents directory under `flutter test`, and the repository is
/// already correct without a cache — it starts from the bundled seed and
/// refreshes over the network. The cache only shortens the window in which a
/// reader sees the twenty bundled rows instead of the served ones.
///
/// A payload that fails to parse is discarded the same way a missing one is, so
/// changing the shape of what is written needs no migration and no version key.
///
/// `dart:io` means this does not compile for web. Nothing here targets web
/// today — `flutter_scene` draws the fold pages — and a conditional import is
/// the answer on the day something does.
final class CatalogLocalDataSource {
  const CatalogLocalDataSource();

  static const String _fileName = 'catalog.json';

  /// The rows last written, or null where there are none to read.
  Future<List<Map<String, dynamic>>?> read() async {
    try {
      final File file = await _file();
      if (!file.existsSync()) {
        return null;
      }
      final Object? parsed = jsonDecode(await file.readAsString());
      if (parsed is! List) {
        return null;
      }
      return <Map<String, dynamic>>[
        for (final Object? row in parsed)
          if (row is Map<String, dynamic>) row,
      ];
    } on Object catch (error) {
      _note('could not read', error);
      return null;
    }
  }

  /// Replaces what is on disk. A failure here costs the next launch its head
  /// start and nothing else, so it is logged rather than surfaced.
  Future<void> write(List<Map<String, dynamic>> proteins) async {
    try {
      final File file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(proteins));
    } on Object catch (error) {
      _note('could not write', error);
    }
  }

  Future<File> _file() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  void _note(String what, Object error) {
    assert(() {
      // The first line only. A missing plugin reports itself in six lines of
      // advice about binding initialisation, which is the ordinary condition
      // here rather than news.
      final String first = error.toString().split('\n').first;
      debugPrint('CatalogLocalDataSource: $what $_fileName — $first');
      return true;
    }(), 'debug-only diagnostic');
  }
}
