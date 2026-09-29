import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/structure/fold_handover.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handover follows closure and finishes within the fold timeline', () {
    expect(foldHandoverAt(0), 0);
    expect(foldHandoverAt(FoldTimeline.bridgesClosedAt), 0);
    expect(foldHandoverAt(1), 1);
    expect(foldHandoverAt(2), 1);
    double previous = 0;
    for (int frame = 0; frame <= 540; frame++) {
      final double p = foldHandoverAt(frame / 540);
      expect(p, inInclusiveRange(previous, 1));
      previous = p;
    }
    // Near either end, a frame must not introduce a visible jump in weight.
    const double frame = 1 / 540;
    expect(
      foldHandoverAt(FoldTimeline.bridgesClosedAt + frame),
      lessThan(0.001),
    );
    expect(1 - foldHandoverAt(1 - frame), lessThan(0.001));
  });

  Future<List<int>> pixel(double p, {bool same = false}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    const ui.Rect bounds = ui.Rect.fromLTWH(0, 0, 3, 1);
    canvas.drawRect(bounds, ui.Paint()..color = const ui.Color(0xff202020));
    paintFoldHandover(
      canvas,
      bounds,
      progress: p,
      paintFold: () => canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 2, 1),
        ui.Paint()..color = const ui.Color(0xffff0000),
      ),
      paintModel: () => canvas.drawRect(
        const ui.Rect.fromLTWH(1, 0, 2, 1),
        ui.Paint()
          ..color = same
              ? const ui.Color(0xffff0000)
              : const ui.Color(0xff00ff00),
      ),
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(3, 1);
    try {
      return (await image.toByteData())!.buffer.asUint8List().toList();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  test('different silhouettes appear gradually; endpoints are exact', () async {
    expect(await pixel(0), <int>[
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      255,
      32,
      32,
      32,
      255,
    ]);
    expect(await pixel(1), <int>[
      32,
      32,
      32,
      255,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      255,
    ]);
    final List<int> middle = await pixel(0.5);
    // Left: red fades to the background. Right: green rises from it.
    // Centre: complementary weights, with no background showing through.
    final List<int> expected = <int>[
      144,
      16,
      16,
      255,
      128,
      128,
      0,
      255,
      16,
      144,
      16,
      255,
    ];
    for (int i = 0; i < expected.length; i++) {
      expect(middle[i], closeTo(expected[i], 1), reason: 'channel $i');
    }
  });

  test('matching surface pixels keep their brightness throughout', () async {
    for (final double p in <double>[0.01, 0.1, 0.25, 0.5, 0.75, 0.99]) {
      final List<int> rgba = (await pixel(p, same: true)).sublist(4, 8);
      expect(rgba[0], closeTo(255, 1), reason: 'progress $p');
      expect(rgba.sublist(1), <int>[0, 0, 255]);
    }
  });
}
