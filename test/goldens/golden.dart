import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one environment the committed goldens were made in, named the way
/// `tool/goldens/run.sh` names the container it runs: the Flutter release, the
/// OS and the CPU.
///
/// A golden is a picture of what the engine drew, and the engine hands text to
/// the host's rasteriser: FreeType on Linux, DirectWrite on Windows, CoreText
/// on macOS. The same frame drawn on two hosts differs at every glyph edge, so
/// a golden is compared only where it was made. Changing this string means
/// regenerating every golden, alone in one commit. docs/goldens.md has the rest.
const String goldenEnvironment = 'flutter-3.47.5-linux-x86_64';

/// Whether this run compares frames against the committed goldens.
final bool comparesGoldens =
    Platform.environment['HELIX_GOLDEN_ENV'] == goldenEnvironment;

/// Where [expectScreen] also writes each frame as a PNG, for looking at.
final String _shotDir = Platform.environment['SHOT_DIR'] ?? '';

/// The `skip` for a group of golden tests: null wherever they have something
/// to do, which is the golden environment, or anywhere `SHOT_DIR` is set.
///
/// Anywhere else they skip, and say so. A golden run that compared nothing
/// and still reported a pass would be the worst of both.
final String? goldenSkip = comparesGoldens || _shotDir.isNotEmpty
    ? null
    : 'goldens compare only in $goldenEnvironment: run tool/goldens/goldens.sh '
          '(or set SHOT_DIR to write the frames here without comparing)';

/// Checks the frame on screen against the committed golden [path], which is
/// relative to the test file, as `matchesGoldenFile` reads it.
///
/// With `SHOT_DIR` set it also writes the frame there, at twice the size and
/// under the golden's own file name, which is what the screenshot writers did
/// before they compared anything.
///
/// [boundary] is the repaint boundary to capture; by default the first one in
/// the tree, which is the one each test wraps its app in.
Future<void> expectScreen(
  WidgetTester tester,
  String path, {
  Finder? boundary,
}) async {
  final Finder capture = boundary ?? find.byType(RepaintBoundary).first;
  if (_shotDir.isNotEmpty) {
    await _writeShot(tester, capture, path.split('/').last);
  }
  if (comparesGoldens) {
    await expectLater(capture, matchesGoldenFile(path));
  }
}

Future<void> _writeShot(
  WidgetTester tester,
  Finder capture,
  String name,
) async {
  final RenderRepaintBoundary boundary =
      tester.firstRenderObject(capture) as RenderRepaintBoundary;
  // Both of these resolve on the real event loop, which the fake clock inside
  // testWidgets never pumps; awaited directly they hang until the test times
  // out. runAsync hands them a loop that actually turns.
  final ByteData? bytes = await tester.runAsync<ByteData>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return data!;
  });
  final File file = File('$_shotDir/$name')..parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}
