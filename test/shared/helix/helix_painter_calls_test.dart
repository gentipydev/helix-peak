import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/helix/dna_helix_painter.dart';
import 'package:helixpeek/shared/helix/helix_geometry.dart';

/// Every call the painter makes on its canvas, written out exactly: the
/// doubles in Dart's shortest round-trip form, the colours as ARGB.
class _Calls implements Canvas {
  final StringBuffer _out = StringBuffer();
  int count = 0;

  /// Each line's width and each circle's radius, in the order drawn.
  final List<double> lines = <double>[];
  final List<double> circles = <double>[];

  String get text => _out.toString();

  void _add(String call) {
    _out.writeln(call);
    count++;
  }

  @override
  void save() => _add('save');

  @override
  void restore() => _add('restore');

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) => _add('clip ${rect.left} ${rect.top} ${rect.right} ${rect.bottom}');

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add(paint.strokeWidth);
    _add(
      'line ${p1.dx} ${p1.dy} ${p2.dx} ${p2.dy} ${paint.strokeWidth} '
      '${paint.color.toARGB32()} ${paint.strokeCap.index}',
    );
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add(radius);
    _add('circle ${c.dx} ${c.dy} $radius ${paint.color.toARGB32()}');
  }

  @override
  void drawRect(Rect rect, Paint paint) => _add(
    'rect ${rect.left} ${rect.top} ${rect.right} ${rect.bottom} '
    '${paint.shader != null} ${paint.color.toARGB32()}',
  );

  // The painter draws nothing else; a call it starts making fails here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// FNV-1a, 64 bits, of [text]'s UTF-8: a fingerprint of a frame's calls.
String _fingerprint(String text) {
  int hash = 0xcbf29ce484222325;
  for (final int byte in utf8.encode(text)) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  String half(int bits) => bits.toRadixString(16).padLeft(8, '0');
  return half(hash >>> 32) + half(hash & 0xffffffff);
}

const Color _backbone = Color(0xFFB8B0A4);
const Color _adenine = Color(0xFF5FA8D3);
const Color _thymine = Color(0xFFE07A5F);
const Color _guanine = Color(0xFF81B29A);
const Color _cytosine = Color(0xFFF2CC8F);
const Color _transcript = Color(0xFF4FD1C5);
const Color _ground = Color(0xFF1C1B1A);

/// One frame of a painter, as its calls.
_Calls _frame(DnaHelixPainter painter, Size size) {
  final _Calls calls = _Calls();
  painter.paint(calls, size);
  return calls;
}

/// The frames the fixture holds, by name: home's helix as the home screen
/// draws it, and the zoom's helix at the DNA stop as it lies along the gene,
/// unzipping as the walk opens.
Map<String, _Calls> _frames() {
  final Map<String, _Calls> out = <String, _Calls>{};
  final HelixModel home = HelixModel();
  for (final double turn in <double>[0, 0.13, 0.37, 0.71]) {
    for (final double drift in <double>[0, 0.3]) {
      for (final double? reading in <double?>[null, 0.2, 0.53]) {
        out['home $turn $drift $reading'] = _frame(
          DnaHelixPainter(
            repaint: kAlwaysDismissedAnimation,
            rotation: AlwaysStoppedAnimation<double>(turn),
            drift: AlwaysStoppedAnimation<double>(drift),
            transcription: reading == null
                ? null
                : AlwaysStoppedAnimation<double>(reading),
            model: home,
            backbone: _backbone,
            adenine: _adenine,
            thymine: _thymine,
            guanine: _guanine,
            cytosine: _cytosine,
            transcript: _transcript,
            background: _ground,
          ),
          const Size(390, 620),
        );
      }
    }
  }
  // Insulin's first 33 bases, 3′ end first, as the zoom lays them.
  const String first = 'AGCCCTCCAGGACAGGCTGCATCAGAAGAGGCC';
  final Uint8List bases = Uint8List.fromList(<int>[
    for (int i = first.length - 1; i >= 0; i--) HelixPalette.ofBase(first[i]),
  ]);
  const double perBase = HelixModel.defaultPitch / HelixModel.basePairsPerTurn;
  const Size page = Size(
    HelixModel.defaultRadius * 4.4,
    first.length * perBase * 1.3,
  );
  for (final double unzip in <double>[0, 0.5, 1]) {
    final HelixModel model = HelixModel(
      rungCount: first.length,
      sampleCount: 3 * first.length,
      unzip: unzip,
      bases: bases,
    );
    for (final double turn in <double>[0.13, 0.5, 0.9]) {
      out['zoom $unzip $turn'] = _frame(
        DnaHelixPainter(
          repaint: kAlwaysDismissedAnimation,
          rotation: AlwaysStoppedAnimation<double>(turn),
          drift: kAlwaysDismissedAnimation,
          transcription: null,
          model: model,
          backbone: _backbone,
          adenine: _adenine,
          thymine: _thymine,
          guanine: _guanine,
          cytosine: _cytosine,
          transcript: _transcript,
          background: _ground,
          topFade: 0,
          bottomFade: 0,
          overscan: 0,
        ),
        page,
      );
    }
  }
  return out;
}

const String _fixture = 'test/shared/helix/fixtures/helix_painter_calls.json';

/// Insulin's first bases as the zoom lays them, drawn small and turned, with
/// a [strandFloor] and [bases] showing where given.
_Calls _small({double? strandFloor, double? bases}) {
  const String first = 'AGCCCTCCAGGACAGGCTGCATCAGAAGAGGCC';
  final HelixModel model = HelixModel(
    rungCount: first.length,
    sampleCount: 3 * first.length,
    bases: Uint8List.fromList(<int>[
      for (int i = first.length - 1; i >= 0; i--) HelixPalette.ofBase(first[i]),
    ]),
  );
  const double perBase = HelixModel.defaultPitch / HelixModel.basePairsPerTurn;
  DnaHelixPainter painter(double? floor, double? shown) => floor == null
      ? DnaHelixPainter(
          repaint: kAlwaysDismissedAnimation,
          rotation: const AlwaysStoppedAnimation<double>(0.3),
          drift: kAlwaysDismissedAnimation,
          transcription: null,
          model: model,
          backbone: _backbone,
          adenine: _adenine,
          thymine: _thymine,
          guanine: _guanine,
          cytosine: _cytosine,
          transcript: _transcript,
          background: _ground,
          topFade: 0,
          bottomFade: 0,
          overscan: 0,
        )
      : DnaHelixPainter(
          repaint: kAlwaysDismissedAnimation,
          rotation: const AlwaysStoppedAnimation<double>(0.3),
          drift: kAlwaysDismissedAnimation,
          transcription: null,
          model: model,
          backbone: _backbone,
          adenine: _adenine,
          thymine: _thymine,
          guanine: _guanine,
          cytosine: _cytosine,
          transcript: _transcript,
          background: _ground,
          topFade: 0,
          bottomFade: 0,
          overscan: 0,
          strandFloor: floor,
          bases: shown ?? 1,
        );
  return _frame(
    painter(strandFloor, bases),
    const Size(HelixModel.defaultRadius * 4.4, first.length * perBase * 1.3),
  );
}

void main() {
  // HELIX_CALLS_OUT=1 writes the fixture: done once, at f9add7b, before the
  // painter took its strand floor and its bases' showing.
  test('draws home\'s helix and the zoom\'s, call for call, as it did before '
      'it took a strand floor and a share of its bases', () {
    final Map<String, _Calls> frames = _frames();
    final Map<String, Object> now = <String, Object>{
      for (final MapEntry<String, _Calls> f in frames.entries)
        f.key: <String, Object>{
          'calls': f.value.count,
          'fnv1a64': _fingerprint(f.value.text),
        },
    };
    if (Platform.environment['HELIX_CALLS_OUT'] == '1') {
      File(_fixture).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(now)}\n',
      );
      return;
    }
    final Map<String, dynamic> was =
        jsonDecode(File(_fixture).readAsStringSync()) as Map<String, dynamic>;
    expect(now.keys.toSet(), was.keys.toSet());
    for (final String key in was.keys) {
      expect(now[key], was[key], reason: key);
    }
  });

  test('given its defaults, it draws exactly as given nothing', () {
    expect(_small(strandFloor: 0, bases: 1).text, _small().text);
  });

  test('draws only its backbones when none of its bases show, and thins them '
      'in between', () {
    final _Calls whole = _small();
    final _Calls none = _small(strandFloor: 0, bases: 0);
    final _Calls half = _small(strandFloor: 0, bases: 0.5);
    expect(whole.circles, isNotEmpty);
    expect(none.circles, isEmpty);
    // The backbones alone: the two strands' segments, every one of them.
    expect(none.lines.length, 2 * (3 * 33 - 1));
    expect(half.circles.length, whole.circles.length);
    final double most = whole.circles.reduce(
      (double a, double b) => a > b ? a : b,
    );
    expect(
      half.circles.reduce((double a, double b) => a > b ? a : b),
      closeTo(most / 2, 1e-9),
    );
  });

  test('draws no strand thinner than its floor, and leaves wider ones be', () {
    final _Calls free = _small(strandFloor: 0, bases: 0);
    final _Calls floored = _small(strandFloor: 2.6, bases: 0);
    expect(floored.lines.length, free.lines.length);
    for (int i = 0; i < free.lines.length; i++) {
      expect(
        floored.lines[i],
        // A paint holds its width in single precision.
        closeTo(free.lines[i] < 2.6 ? 2.6 : free.lines[i], 1e-6),
        reason: 'segment $i',
      );
    }
  });
}
