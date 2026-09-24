// Run from the project root: dart run tool/branding/generate.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String _brandDir = 'design/branding';
final img.Color _navy = img.ColorRgb8(14, 17, 22);

Future<void> main() async {
  final File source = File('$_brandDir/helix_peek_master.png');
  if (!source.existsSync() || !File('pubspec.yaml').existsSync()) {
    throw StateError(
      'Run from the project root with the branding master present.',
    );
  }
  final img.Image? master = img.decodePng(source.readAsBytesSync());
  if (master == null || !master.hasAlpha || master.getPixel(0, 0).a != 0) {
    throw StateError(
      'The master must be a PNG with a truly transparent background.',
    );
  }
  final img.Image mark = _trim(master);
  if (mark.width < 1024 || mark.height < 512) {
    throw StateError(
      'Use a master with at least 1024 × 512 pixels of artwork.',
    );
  }

  // Only these density variants ship inside the Flutter asset bundle.
  for (final int scale in <int>[1, 2, 3, 4]) {
    final String folder = scale == 1 ? '' : '$scale.0x/';
    final img.Image canvas = img.Image(
      width: 128 * scale,
      height: 64 * scale,
      numChannels: 4,
    );
    _place(canvas, mark, fraction: 0.96);
    _save('assets/branding/${folder}helix_peek_mark.png', canvas);
  }

  // Square transparent marks and opaque icons for sharing and store artwork.
  for (final int size in <int>[32, 48, 64, 128, 256, 512, 1024]) {
    final img.Image logo = _square(mark, size, fraction: 0.80);
    final img.Image icon = _square(mark, size, fraction: 0.74, opaque: true);
    _save('$_brandDir/exports/logo-$size.png', logo);
    _save('$_brandDir/exports/app-icon-$size.png', icon);
  }

  final img.Image appIcon = _square(mark, 1024, fraction: 0.74, opaque: true);
  _save('$_brandDir/generated/app_icon.png', appIcon);

  // Android layers are 108dp. A 60%-wide mark fits inside the central 66dp
  // safe zone; the launcher config must not add another foreground inset.
  final img.Image foreground = _square(mark, 1024, fraction: 0.60);
  _save('$_brandDir/generated/adaptive_foreground.png', foreground);
  final img.Image monochrome = foreground.clone();
  for (final img.Pixel pixel in monochrome) {
    pixel
      ..r = 255
      ..g = 255
      ..b = 255;
  }
  _save('$_brandDir/generated/adaptive_monochrome.png', monochrome);

  // Desktop artwork includes its own rounded tile and transparent outer margin.
  // iOS and Android receive unmasked sources so their OS controls the shape.
  final img.Image desktop = img.Image(
    width: 1024,
    height: 1024,
    numChannels: 4,
  );
  img.fillRect(
    desktop,
    x1: 102,
    y1: 102,
    x2: 921,
    y2: 921,
    radius: 180,
    color: _navy,
  );
  _place(desktop, mark, fraction: 0.60);
  _save('$_brandDir/generated/desktop_icon.png', desktop);

  final ProcessResult result = await Process.run(
    Platform.resolvedExecutable,
    <String>['run', 'flutter_launcher_icons'],
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }

  // The package shares one source between regular and maskable web icons.
  // Write explicit maskable sources with all artwork in the central 80% circle.
  for (final int size in <int>[192, 512]) {
    _save(
      'web/icons/Icon-maskable-$size.png',
      _square(mark, size, fraction: 0.66, opaque: true),
    );
  }
  _save('web/icons/apple-touch-icon.png', _resize(appIcon, 180));
  // Keep native frames for the Windows title bar, taskbar and Explorer.
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(
    img.IcoEncoder().encodeImages(<img.Image>[
      for (final int size in <int>[16, 24, 32, 48, 64, 128, 256])
        _resize(desktop, size),
    ]),
  );
  _save('linux/runner/resources/helixpeek.png', _resize(desktop, 512));
  stdout.writeln(
    'Brand exports, Flutter densities, and platform icons generated.',
  );
}

img.Image _trim(img.Image source) {
  int left = source.width, top = source.height, right = -1, bottom = -1;
  for (final img.Pixel pixel in source) {
    // Ignore nearly invisible alpha noise when measuring the artwork bounds.
    // The crop retains the artwork's original antialiased alpha pixels.
    if (pixel.a <= 8) continue;
    left = math.min(left, pixel.x);
    top = math.min(top, pixel.y);
    right = math.max(right, pixel.x);
    bottom = math.max(bottom, pixel.y);
  }
  if (right < left) throw StateError('The master contains no visible artwork.');
  return img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

img.Image _square(
  img.Image mark,
  int size, {
  required double fraction,
  bool opaque = false,
}) {
  final img.Image canvas = img.Image(
    width: size,
    height: size,
    numChannels: opaque ? 3 : 4,
  );
  if (opaque) img.fill(canvas, color: _navy);
  _place(canvas, mark, fraction: fraction);
  return canvas;
}

void _place(img.Image canvas, img.Image mark, {required double fraction}) {
  final double factor = math.min(
    canvas.width * fraction / mark.width,
    canvas.height * fraction / mark.height,
  );
  final img.Image scaled = _resize(mark, (mark.width * factor).round());
  img.compositeImage(canvas, scaled, center: true);
}

img.Image _resize(img.Image image, int width) => img.copyResize(
  image,
  width: width,
  interpolation: img.Interpolation.average,
);

void _save(String path, img.Image image) {
  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
}
