import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/share/nv12_packer.dart';

/// [width] × [height] RGBA, each pixel [at] its column and row.
Uint8List _rgba(int width, int height, List<int> Function(int x, int y) at) {
  final Uint8List out = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      out.setAll((y * width + x) * 4, <int>[...at(x, y), 255]);
    }
  }
  return out;
}

/// The same pixels, drawn and rasterised.
Future<ui.Image> _image(
  int width,
  int height,
  List<int> Function(int x, int y) at,
) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final List<int> c = at(x, y);
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
        Paint()
          ..isAntiAlias = false
          ..color = Color.fromARGB(255, c[0], c[1], c[2]),
      );
    }
  }
  return recorder.endRecording().toImage(width, height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nv12Reference', () {
    test('the spike\'s blue, #1E88E5, is Y 119, Cb 179, Cr 78', () {
      // y = 16 + ((47·30 + 157·136 + 16·229 + 128) >> 8) = 16 + 103
      // u = 128 + ((−26·30 − 86·136 + 112·229 + 128) >> 8) = 128 + 51
      // v = 128 + ((112·30 − 102·136 − 10·229 + 128) >> 8) = 128 − 50
      final Uint8List nv12 = nv12Reference(
        _rgba(2, 2, (_, _) => <int>[30, 136, 229]),
        2,
        2,
      );
      expect(nv12, <int>[119, 119, 119, 119, 179, 78]);
    });

    test('luma row by row, then Cb and Cr interleaved per 2×2 block', () {
      // Black on the left block, white on the right: the luma follows each
      // pixel and each block has its own chroma pair.
      final Uint8List nv12 = nv12Reference(
        _rgba(4, 2, (int x, _) => x < 2 ? <int>[0, 0, 0] : <int>[255, 255, 255]),
        4,
        2,
      );
      expect(nv12.length, 4 * 2 * 3 ~/ 2);
      expect(nv12.sublist(0, 8), <int>[16, 16, 235, 235, 16, 16, 235, 235]);
      expect(nv12.sublist(8), <int>[128, 128, 128, 128]);
    });

    test('a block\'s chroma is its rounded mean, not one corner', () {
      // Red in one corner of four: r = (255 + 2) >> 2 = 64.
      final Uint8List nv12 = nv12Reference(
        _rgba(2, 2, (int x, int y) => x + y == 0 ? <int>[255, 0, 0] : <int>[0, 0, 0]),
        2,
        2,
      );
      expect(nv12.sublist(4), <int>[
        128 + ((-26 * 64 + 128) >> 8),
        128 + ((112 * 64 + 128) >> 8),
      ]);
    });
  });

  group('Nv12Packer', () {
    test('the shader packs a frame exactly as the reference does', () async {
      final Nv12Packer? packer = await Nv12Packer.load();
      expect(packer, isNotNull, reason: 'the self-check failed here');
      List<int> at(int x, int y) => <int>[
        (x * 29 + y * 83) % 256,
        (x * 7 + y * 191 + 40) % 256,
        (x * 113 + y * 3 + 200) % 256,
      ];
      final ui.Image frame = await _image(16, 6, at);
      final ByteData rgba = (await frame.toByteData())!;
      final Uint8List packed = await packer!.pack(frame);
      expect(
        packed,
        nv12Reference(rgba.buffer.asUint8List(), 16, 6),
      );
      frame.dispose();
      packer.dispose();
    });

    test('a frame it cannot pack is refused', () async {
      final Nv12Packer packer = (await Nv12Packer.load())!;
      final ui.Image odd = await _image(6, 4, (_, _) => <int>[0, 0, 0]);
      await expectLater(packer.pack(odd), throwsArgumentError);
      odd.dispose();
      packer.dispose();
    });
  });
}
