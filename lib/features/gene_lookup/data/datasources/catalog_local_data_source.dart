import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The last complete served catalog. Cache failures never prevent a fetch.
/// Version 2 includes fold metadata that the old summaries did not carry.
final class CatalogLocalDataSource {
  const CatalogLocalDataSource({this.directory});

  final Directory? directory;

  static const String _fileName = 'catalog.v2.json';

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
      final File pending = File('${file.path}.part');
      await pending.writeAsString(jsonEncode(proteins), flush: true);
      await pending.rename(file.path);
    } on Object catch (error) {
      _note('could not write', error);
    }
  }

  Future<File> _file() async {
    final Directory root = directory ?? await getApplicationDocumentsDirectory();
    return File('${root.path}/$_fileName');
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
