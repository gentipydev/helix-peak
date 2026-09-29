import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Packs one drawn frame into the NV12 bytes a clip's encoder takes.
typedef Nv12Pack = Future<Uint8List> Function(ui.Image frame);

/// A clip frame packed as NV12 on the GPU, so the platform side only copies
/// rows into the encoder.
///
/// The spike measured 64 ms a frame on Android, 42 of them in the Kotlin loop
/// that turned RGBA into YUV and about 13 in moving 8.3 MB across the channel
/// (`docs/video-encoding-spike.md`). Here a fragment shader
/// (`shaders/nv12_pack.frag`) does that conversion, with the same integer
/// coefficients, and a frame crosses as 3.1 MB.
///
/// Every channel of the packed image, alpha included, carries a byte, which
/// holds only where the GPU writes and reads them back untouched. So a
/// process packs a small known frame once and compares it with
/// [nv12Reference] before any clip uses the shader; where the two differ,
/// clips are made from RGBA as they always were.
final class Nv12Packer {
  Nv12Packer._(this._shader);

  /// The shader, as `pubspec.yaml` lists it.
  static const String asset = 'shaders/nv12_pack.frag';

  final ui.FragmentShader _shader;

  static Future<Nv12Packer?>? _shared;

  /// This process's packer, loaded and checked once, or null where either
  /// failed.
  static Future<Nv12Packer?> shared() => _shared ??= load();

  /// The packer, where the platform side takes NV12: Android. iOS takes RGBA,
  /// and its vImage path already converts it quickly.
  ///
  /// A build made with `--dart-define=CLIP_NV12=false` sends RGBA everywhere,
  /// so that the two paths can be timed against each other on one phone.
  static Future<Nv12Pack?> forPlatform() async {
    const bool enabled = bool.fromEnvironment('CLIP_NV12', defaultValue: true);
    if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    return (await shared())?.pack;
  }

  /// Loads the shader and checks it against [nv12Reference]: null if it does
  /// not load, or packs anything differently.
  static Future<Nv12Packer?> load() async {
    Nv12Packer? packer;
    try {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        asset,
      );
      packer = Nv12Packer._(program.fragmentShader());
      if (await packer._agrees()) {
        return packer;
      }
      debugPrint('helixpeek: NV12 packing disagrees here; clips use RGBA');
    } on Object catch (error) {
      debugPrint('helixpeek: NV12 packing is unavailable ($error)');
    }
    packer?.dispose();
    return null;
  }

  /// [frame] as NV12: its luma row by row, then its chroma, Cb and Cr
  /// interleaved. Its width must be a multiple of four and its height even.
  Future<Uint8List> pack(ui.Image frame) async {
    final int width = frame.width;
    final int height = frame.height;
    if (width % 4 != 0 || height.isOdd) {
      throw ArgumentError.value(
        '${width}x$height',
        'frame',
        'must be a multiple of four wide and even high',
      );
    }
    _shader
      ..setFloat(0, width.toDouble())
      ..setFloat(1, height.toDouble())
      ..setImageSampler(0, frame);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width / 4, height * 1.5),
      Paint()
        ..shader = _shader
        ..blendMode = BlendMode.src,
    );
    final ui.Picture picture = recorder.endRecording();
    final ui.Image packed;
    try {
      packed = await picture.toImage(width ~/ 4, height * 3 ~/ 2);
    } finally {
      picture.dispose();
    }
    try {
      final ByteData? bytes = await packed.toByteData();
      if (bytes == null) {
        throw StateError('A packed frame could not be read back.');
      }
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      packed.dispose();
    }
  }

  void dispose() => _shader.dispose();

  /// Packs an 8×4 frame whose pixels all differ and compares the bytes with
  /// [nv12Reference] of the same frame as it was read back.
  Future<bool> _agrees() async {
    const int width = 8;
    const int height = 4;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          Paint()
            ..isAntiAlias = false
            ..blendMode = BlendMode.src
            ..color = Color.fromARGB(
              255,
              (x * 37 + y * 101) % 256,
              (x * 59 + y * 17 + 80) % 256,
              (x * 13 + y * 151 + 160) % 256,
            ),
        );
      }
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image frame;
    try {
      frame = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    try {
      final ByteData? rgba = await frame.toByteData();
      if (rgba == null) {
        return false;
      }
      final Uint8List expected = nv12Reference(
        rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        width,
        height,
      );
      return listEquals(await pack(frame), expected);
    } finally {
      frame.dispose();
    }
  }
}

/// [rgba], rows of R, G, B, A packed with no padding, as NV12: what
/// `shaders/nv12_pack.frag` must make of it.
///
/// BT.709 limited range through the integer coefficients the Kotlin path
/// uses: y = 16 + ((47r + 157g + 16b + 128) >> 8), and Cb, Cr from the
/// rounded mean of each 2×2 block, u = 128 + ((-26r - 86g + 112b + 128) >> 8)
/// and v = 128 + ((112r - 102g - 10b + 128) >> 8). Alpha is dropped.
Uint8List nv12Reference(Uint8List rgba, int width, int height) {
  final Uint8List out = Uint8List(width * height * 3 ~/ 2);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = (y * width + x) * 4;
      out[y * width + x] =
          16 +
          ((47 * rgba[i] + 157 * rgba[i + 1] + 16 * rgba[i + 2] + 128) >> 8);
    }
  }
  final int chroma = width * height;
  for (int y = 0; y < height ~/ 2; y++) {
    for (int x = 0; x < width ~/ 2; x++) {
      final int a = (y * 2 * width + x * 2) * 4;
      final int c = a + width * 4;
      int mean(int k) =>
          (rgba[a + k] + rgba[a + 4 + k] + rgba[c + k] + rgba[c + 4 + k] + 2) >>
          2;
      final int r = mean(0);
      final int g = mean(1);
      final int b = mean(2);
      final int at = chroma + y * width + x * 2;
      out[at] = 128 + ((-26 * r - 86 * g + 112 * b + 128) >> 8);
      out[at + 1] = 128 + ((112 * r - 102 * g - 10 * b + 128) >> 8);
    }
  }
  return out;
}
