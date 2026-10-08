import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

/// This install's own random id: who asked for a build, so that only this
/// phone may stop it.
///
/// There are no accounts, and the id names nobody. It is made the first time
/// it is read and kept in the app's support directory. Where it cannot be
/// kept, this run makes its own, so a build asked for now can still be
/// stopped now.
final class InstallId {
  InstallId({this.directory});

  /// Where the id is kept: the app's support directory where none is given.
  final Directory? directory;
  Future<String>? _id;

  static final RegExp _shape = RegExp(r'^[0-9a-f]{32}$');

  /// The id, read or made once per run.
  Future<String> read() => _id ??= _load();

  Future<String> _load() async {
    try {
      final Directory base = directory ?? await getApplicationSupportDirectory();
      final File file = File('${base.path}/install_id');
      if (await file.exists()) {
        final String kept = (await file.readAsString()).trim();
        if (_shape.hasMatch(kept)) {
          return kept;
        }
      }
      final String id = _fresh();
      await file.parent.create(recursive: true);
      await file.writeAsString(id);
      return id;
    } on Object {
      return _fresh();
    }
  }

  static String _fresh() {
    final Random random = Random.secure();
    return <String>[
      for (int i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
