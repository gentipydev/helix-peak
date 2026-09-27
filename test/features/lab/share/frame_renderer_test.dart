import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/biology/gene_record.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/gene_lookup/data/models/gene_record_dto.dart';
import 'package:helixpeek/features/lab/ribosome/domain/translation_timeline.dart';
import 'package:helixpeek/features/lab/ribosome/presentation/translation_painter.dart';
import 'package:helixpeek/features/lab/share/frame_renderer.dart';

/// A picture that depends on `t` alone: a colour sweep and a moving disc.
class _Sweep extends CustomPainter {
  _Sweep(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF1E88E5),
            const Color(0xFFE53935),
            t,
          )!,
      )
      ..drawCircle(
        Offset(size.width * t, size.height / 2),
        size.shortestSide / 4,
        Paint()..color = const Color(0xFFFFFFFF),
      );
  }

  @override
  bool shouldRepaint(_Sweep old) => old.t != t;
}

Future<Uint8List> _pixels(ui.Image image) async {
  final ByteData? bytes = await image.toByteData();
  return bytes!.buffer.asUint8List();
}

/// The ribosome's own painter over insulin, in the lab's colours.
FramePainter _ribosome() {
  final GeneRecord insulin = GeneRecordDto.fromJson(
    jsonDecode(File('test/fixtures/mock/gene_ins.json').readAsStringSync())
        as Map<String, dynamic>,
  ).toEntity();
  final TranslationTimeline timeline = TranslationTimeline(insulin);
  final ThemeData theme = AppTheme.analysis;
  final ColorScheme scheme = theme.colorScheme;
  final TranslationInks inks = TranslationInks(
    background: scheme.surface,
    smallSubunit: scheme.surfaceContainerHighest,
    largeSubunit: scheme.surfaceContainerHigh,
    outline: scheme.outline,
    ink: scheme.onSurface,
    quiet: scheme.onSurfaceVariant,
    nucleotides: theme.extension<NucleotideColors>()!,
    anatomy: theme.extension<AnatomyColors>()!,
  );
  return (double t) =>
      TranslationPainter(timeline: timeline, at: () => t, inks: inks);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exactly the frames asked for, the first at 0 and the last at 1',
    () async {
      final List<double> drawn = <double>[];
      final FrameRenderer renderer = FrameRenderer(
        painter: (double t) {
          drawn.add(t);
          return _Sweep(t);
        },
        count: 7,
        size: const Size(64, 36),
        pixelRatio: 2,
      );
      int frames = 0;
      await for (final ui.Image frame in renderer.frames()) {
        expect((frame.width, frame.height), (128, 72));
        frame.dispose();
        frames++;
      }
      expect(frames, 7);
      expect(drawn, <double>[0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1]);
    },
  );

  test('one frame is t = 0', () async {
    final List<double> drawn = <double>[];
    final List<ui.Image> frames = await FrameRenderer(
      painter: (double t) {
        drawn.add(t);
        return _Sweep(t);
      },
      count: 1,
      size: const Size(8, 8),
    ).frames().toList();
    expect(frames, hasLength(1));
    expect(drawn, <double>[0]);
    frames.single.dispose();
  });

  test('frame i + 1 is not drawn before frame i has been taken', () async {
    int drawn = 0;
    final FrameRenderer renderer = FrameRenderer(
      painter: (double t) {
        drawn++;
        return _Sweep(t);
      },
      count: 5,
      size: const Size(32, 32),
    );
    int taken = 0;
    await for (final ui.Image frame in renderer.frames()) {
      taken++;
      expect(drawn, taken, reason: 'on taking frame $taken');
      // A slow consumer, such as an encoder: nothing more is drawn meanwhile.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(drawn, taken, reason: 'while frame $taken is being used');
      frame.dispose();
    }
    expect(taken, 5);
  });

  test('a consumer that stops early stops the drawing', () async {
    int drawn = 0;
    final FrameRenderer renderer = FrameRenderer(
      painter: (double t) {
        drawn++;
        return _Sweep(t);
      },
      count: 100,
      size: const Size(16, 16),
    );
    int taken = 0;
    await for (final ui.Image frame in renderer.frames()) {
      frame.dispose();
      if (++taken == 3) {
        break;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(taken, 3);
    expect(drawn, lessThanOrEqualTo(4));
  });

  test(
    'two runs of the same inputs are byte-identical, frame by frame',
    () async {
      for (final (String name, FramePainter painter, Size size)
          in <(String, FramePainter, Size)>[
            ('a sweep', _Sweep.new, const Size(120, 80)),
            ('the ribosome over insulin', _ribosome(), const Size(180, 320)),
          ]) {
        FrameRenderer renderer() => FrameRenderer(
          painter: painter,
          count: 12,
          size: size,
          pixelRatio: 2,
          background: const Color(0xFF101418),
        );
        // Lockstep, so the test never holds more than one frame of each run.
        final StreamIterator<ui.Image> first = StreamIterator<ui.Image>(
          renderer().frames(),
        );
        final StreamIterator<ui.Image> second = StreamIterator<ui.Image>(
          renderer().frames(),
        );
        int compared = 0;
        Uint8List? previous;
        bool moved = false;
        while (await first.moveNext()) {
          expect(await second.moveNext(), isTrue, reason: '$name: frame count');
          final Uint8List a = await _pixels(first.current);
          final Uint8List b = await _pixels(second.current);
          first.current.dispose();
          second.current.dispose();
          expect(a, b, reason: '$name: frame $compared');
          if (previous != null && !_same(previous, a)) {
            moved = true;
          }
          previous = a;
          compared++;
        }
        expect(await second.moveNext(), isFalse, reason: '$name: frame count');
        expect(compared, 12);
        expect(moved, isTrue, reason: '$name: the frames are not all one');
      }
    },
  );

  test('a count below one is refused', () {
    expect(
      () => const FrameRenderer(
        painter: _Sweep.new,
        count: 0,
        size: Size(8, 8),
      ).frames(),
      throwsArgumentError,
    );
  });
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
