import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ClipOp;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_colors.dart';
import 'package:helixpeek/core/theme/nucleotide_colors.dart';
import 'package:helixpeek/features/home/presentation/widgets/dna_helix_painter.dart';
import 'package:helixpeek/features/home/presentation/widgets/helix_geometry.dart';

/// The home helix, held to what it drew before its geometry left the home
/// screen for the shared layer.
///
/// `fixtures/helix_vertices.json` was captured from the code as it stood
/// before the move, and is never regenerated: a capture taken afterwards
/// would only prove the code agrees with itself. It holds two things:
///
/// - every table [HelixModel] builds, for the model the home screen draws
///   in full, byte for byte, and for three other rung counts as a digest;
/// - every call [DnaHelixPainter] makes on its canvas, for a spread of
///   frames, as a digest of the calls written out with their exact doubles.
///
/// The first is the geometry, vertex for vertex. The second is everything
/// the home screen draws from it: projection, depth order, shading and the
/// edge fade, at many more frames than the one golden holds.
///
/// With `HELIX_VERTICES_CAPTURE` set, and no fixture on disk, it writes the
/// fixture instead. It refuses to overwrite one.
void main() {
  final File fixture = File('test/shared/helix/fixtures/helix_vertices.json');

  if ((Platform.environment['HELIX_VERTICES_CAPTURE'] ?? '').isNotEmpty) {
    test('capture the helix before its geometry moves', () {
      expect(
        fixture.existsSync(),
        isFalse,
        reason:
            'the capture is the code as it was before the move; '
            'a new one would prove nothing',
      );
      fixture
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(_capture())}\n',
        );
    });
    return;
  }

  final Map<String, dynamic> captured =
      jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;

  group('HelixModel', () {
    for (final dynamic raw in captured['models'] as List<dynamic>) {
      final Map<String, dynamic> was = raw as Map<String, dynamic>;
      final int rungs = was['rungCount'] as int;
      test('builds every table it built before, at $rungs base pairs', () {
        final HelixModel model = HelixModel(rungCount: rungs);
        expect(_scalars(model), was['scalars']);
        final Map<String, dynamic> tables =
            was['tables'] as Map<String, dynamic>;
        _tablesOf(model).forEach((String name, TypedData now) {
          final Map<String, dynamic> table =
              tables[name] as Map<String, dynamic>;
          final Uint8List bytes = _bytes(now);
          if (table['bytes'] case final String encoded) {
            _expectSameBytes(name, now, base64Decode(encoded), bytes);
          }
          expect(
            _fnv(bytes),
            table['fnv'],
            reason: '$name differs from the capture',
          );
        });
      });
    }
  });

  group('DnaHelixPainter', () {
    for (final dynamic raw in captured['frames'] as List<dynamic>) {
      final Map<String, dynamic> was = raw as Map<String, dynamic>;
      final _Frame frame = _Frame.fromJson(was);
      test('draws $frame exactly as it did', () {
        final String calls = _record(frame);
        expect(
          '\n'.allMatches(calls).length,
          was['calls'],
          reason: 'a different number of canvas calls',
        );
        expect(_fnv(utf8.encode(calls)), was['fnv']);
      });
    }
  });
}

// ------------------------------------------------------------------- capture

Map<String, dynamic> _capture() => <String, dynamic>{
  'captured':
      'from the code before lib/features/home/presentation/'
      'widgets/helix_geometry.dart moved; never regenerated',
  'models': <Map<String, dynamic>>[
    for (final int rungs in _rungCounts)
      () {
        final HelixModel model = HelixModel(rungCount: rungs);
        return <String, dynamic>{
          'rungCount': rungs,
          'scalars': _scalars(model),
          'tables': <String, dynamic>{
            for (final MapEntry<String, TypedData> table in _tablesOf(
              model,
            ).entries)
              table.key: <String, dynamic>{
                // In full for the model the home screen draws, so that a
                // failure can name the vertex; a digest for the others.
                if (rungs == HelixModel.defaultRungCount)
                  'bytes': base64Encode(_bytes(table.value)),
                'fnv': _fnv(_bytes(table.value)),
              },
          },
        };
      }(),
  ],
  'frames': <Map<String, dynamic>>[
    for (final _Frame frame in _frames)
      () {
        final String calls = _record(frame);
        return <String, dynamic>{
          ...frame.toJson(),
          'calls': '\n'.allMatches(calls).length,
          'fnv': _fnv(utf8.encode(calls)),
        };
      }(),
  ],
};

const List<int> _rungCounts = <int>[24, 48, 72, 120];

/// The frames the painter is held to: the render check's six and its still,
/// both ends of the transcription wrap, a box narrow enough to clamp the
/// radius, one short enough that the overscan sets the height, and a model
/// with half the rungs.
const List<_Frame> _frames = <_Frame>[
  _Frame(Size(342, 523), 0.08, 0.5, 0.42),
  _Frame(Size(342, 523), 0.10, 0.5, 0.50),
  _Frame(Size(342, 523), 0.12, 0.5, 0.58),
  _Frame(Size(342, 523), 0.14, 0.5, 0.66),
  _Frame(Size(342, 523), 0.16, 0.5, 0.74),
  _Frame(Size(342, 523), 0.18, 0.5, 0.82),
  _Frame(
    Size(342, 523),
    HelixModel.staticRotationTurns,
    0,
    HelixModel.staticTranscriptionTurns,
  ),
  _Frame(Size(342, 523), 0.61, 0.2, 0.9995),
  _Frame(Size(342, 523), 0.93, 0.8, 0.0005),
  _Frame(Size(160, 523), 0.37, 0.35, 0.47),
  _Frame(Size(390, 300), 0.77, 0.9, 0.61),
  _Frame(Size(342, 523), 0.25, 0.65, 0.55, rungCount: 24),
];

final class _Frame {
  const _Frame(
    this.size,
    this.rotation,
    this.drift,
    this.transcription, {
    this.rungCount = HelixModel.defaultRungCount,
  });

  factory _Frame.fromJson(Map<String, dynamic> json) {
    final List<dynamic> size = json['size'] as List<dynamic>;
    return _Frame(
      Size((size[0] as num).toDouble(), (size[1] as num).toDouble()),
      (json['rotation'] as num).toDouble(),
      (json['drift'] as num).toDouble(),
      (json['transcription'] as num).toDouble(),
      rungCount: json['rungCount'] as int,
    );
  }

  final Size size;
  final double rotation;
  final double drift;
  final double transcription;
  final int rungCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'size': <double>[size.width, size.height],
    'rotation': rotation,
    'drift': drift,
    'transcription': transcription,
    'rungCount': rungCount,
  };

  @override
  String toString() =>
      '${size.width.round()}x${size.height.round()}, '
      'rotation $rotation, drift $drift, transcription $transcription, '
      '$rungCount rungs';
}

// ------------------------------------------------------------------- reading

Map<String, dynamic> _scalars(HelixModel model) => <String, dynamic>{
  'pointCount': model.pointCount,
  'primitiveCount': model.primitiveCount,
  'turns': model.turns,
  'modelHeight': model.modelHeight,
  'bubbleHalfWidth': model.bubbleHalfWidth,
  'hybridLength': model.hybridLength,
  'transcriptSpan': model.transcriptSpan,
  'headReach': model.headReach,
  'rungDepthError': model.rungDepthError,
  'sampleAngleStep': model.sampleAngleStep,
};

Map<String, TypedData> _tablesOf(HelixModel model) => <String, TypedData>{
  'pointCos': model.pointCos,
  'pointSin': model.pointSin,
  'pointAxial': model.pointAxial,
  'pointWander': model.pointWander,
  'pointRole': model.pointRole,
  'primStart': model.primStart,
  'primEnd': model.primEnd,
  'primPalette': model.primPalette,
  'primKind': model.primKind,
  'bubbleSeparation': model.bubbleSeparation,
  'bubbleCosUnwind': model.bubbleCosUnwind,
  'bubbleSinUnwind': model.bubbleSinUnwind,
  'bubblePairing': model.bubblePairing,
  'trailPeel': model.trailPeel,
  'trailReveal': model.trailReveal,
};

Uint8List _bytes(TypedData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

/// Fails naming the first element that moved, and what it was and is now.
void _expectSameBytes(
  String name,
  TypedData now,
  Uint8List was,
  Uint8List bytes,
) {
  expect(bytes.length, was.length, reason: '$name changed length');
  final int width = now.elementSizeInBytes;
  for (int i = 0; i < bytes.length; i++) {
    if (bytes[i] == was[i]) {
      continue;
    }
    final int element = i ~/ width;
    final Object before = _element(now, was, element);
    final Object after = _element(now, bytes, element);
    fail('$name[$element] was $before before the move and is $after now');
  }
}

Object _element(TypedData like, Uint8List bytes, int index) {
  final ByteData data = ByteData.sublistView(bytes);
  return switch (like) {
    Float32List() => data.getFloat32(4 * index, Endian.host),
    Int32List() => data.getInt32(4 * index, Endian.host),
    _ => bytes[index],
  };
}

/// FNV-1a over 64 bits: a digest to tell two byte runs apart, not a secret.
/// The VM's integers wrap at 64 bits, which is the arithmetic it wants.
String _fnv(List<int> bytes) {
  int hash = 0xcbf29ce484222325;
  for (final int byte in bytes) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  String half(int bits) => bits.toRadixString(16).padLeft(8, '0');
  return half(hash >>> 32) + half(hash & 0xffffffff);
}

// ----------------------------------------------------------------- recording

/// Every call [DnaHelixPainter] makes for [frame], one per line, with each
/// double written as the shortest string that reads back as itself.
String _record(_Frame frame) {
  const AppColorTokens tokens = AppColorTokens.dark;
  const NucleotideColors bases = NucleotideColors.dark;
  final _RecordingCanvas canvas = _RecordingCanvas();
  DnaHelixPainter(
    repaint: const AlwaysStoppedAnimation<double>(0),
    rotation: AlwaysStoppedAnimation<double>(frame.rotation),
    drift: AlwaysStoppedAnimation<double>(frame.drift),
    transcription: AlwaysStoppedAnimation<double>(frame.transcription),
    model: HelixModel(rungCount: frame.rungCount),
    backbone: tokens.onSurfaceVariant,
    adenine: bases.adenine,
    thymine: bases.thymine,
    guanine: bases.guanine,
    cytosine: bases.cytosine,
    transcript: tokens.accent,
    background: tokens.surfaceBase,
  ).paint(canvas, frame.size);
  return canvas.calls.toString();
}

/// The six calls the painter makes, written down; any other is a failure.
final class _RecordingCanvas implements Canvas {
  final StringBuffer calls = StringBuffer();

  @override
  void save() => calls.writeln('save');

  @override
  void restore() => calls.writeln('restore');

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) => calls.writeln('clip ${_rect(rect)} ${clipOp.name} $doAntiAlias');

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => calls.writeln(
    'line ${p1.dx} ${p1.dy} ${p2.dx} ${p2.dy} ${_paint(paint)}',
  );

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      calls.writeln('circle ${c.dx} ${c.dy} $radius ${_paint(paint)}');

  @override
  void drawRect(Rect rect, Paint paint) =>
      calls.writeln('rect ${_rect(rect)} ${_paint(paint)}');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('the painter called ${invocation.memberName}, which it never did');

  static String _rect(Rect r) => '${r.left} ${r.top} ${r.right} ${r.bottom}';

  /// The gradient the edge fade paints with cannot be read back, so its rect
  /// and its presence are recorded; the golden holds how it looks.
  static String _paint(Paint p) =>
      '${p.color.a} ${p.color.r} ${p.color.g} ${p.color.b} '
      '${p.style.name} ${p.strokeWidth} ${p.strokeCap.name} '
      '${p.shader == null ? 'flat' : 'shaded'}';
}
