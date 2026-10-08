import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/install_id.dart';

/// [InstallId]: made once, kept, and read back the same; never in the way.

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('install_id_test'));
  tearDown(() => folder.deleteSync(recursive: true));

  test('is made once, kept, and read back the same', () async {
    final String first = await InstallId(directory: folder).read();
    expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(File('${folder.path}/install_id').readAsStringSync(), first);
    expect(await InstallId(directory: folder).read(), first);
  });

  test('one that is not an id is made again', () async {
    File('${folder.path}/install_id').writeAsStringSync('not an id');
    final String id = await InstallId(directory: folder).read();
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(File('${folder.path}/install_id').readAsStringSync(), id);
  });

  test('nowhere to keep it, this run has its own, the same each time', () async {
    final File blocked = File('${folder.path}/file')..writeAsStringSync('');
    final InstallId install = InstallId(directory: Directory('${blocked.path}/below'));
    final String id = await install.read();
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(await install.read(), id);
  });

  test('two installs are not the same', () async {
    final Directory other = Directory.systemTemp.createTempSync('install_id_other');
    addTearDown(() => other.deleteSync(recursive: true));
    expect(
      await InstallId(directory: folder).read(),
      isNot(await InstallId(directory: other).read()),
    );
  });
}
