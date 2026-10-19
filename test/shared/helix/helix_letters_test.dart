import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/helix/dna_helix_painter.dart';
import 'package:helixpeek/shared/helix/helix_geometry.dart';

/// Every call the painter makes, as a line each, and what it draws: each
/// disc's centre, radius and colour, and each letter where its transform
/// and its paragraph put it.
class _Calls implements Canvas {
  final List<String> lines = <String>[];
  final List<(Offset, double, Color)> discs = <(Offset, double, Color)>[];
  final List<_Letter> letters = <_Letter>[];

  Offset _at = Offset.zero;
  double _turn = 0;
  double _scale = 1;

  @override
  void save() => lines.add('save');

  @override
  void restore() {
    lines.add('restore');
    _at = Offset.zero;
    _turn = 0;
    _scale = 1;
  }

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => lines.add('clip $rect');

  @override
  void translate(double dx, double dy) {
    lines.add('translate $dx $dy');
    _at = Offset(dx, dy);
  }

  @override
  void rotate(double radians) {
    lines.add('rotate $radians');
    _turn = radians;
  }

  @override
  void scale(double sx, [double? sy]) {
    lines.add('scale $sx');
    _scale = sx;
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add(
    'line $p1 $p2 ${paint.strokeWidth} ${paint.color.toARGB32()}',
  );

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    lines.add('circle $c $radius ${paint.color.toARGB32()}');
    discs.add((c, radius, paint.color));
  }

  @override
  void drawRect(Rect rect, Paint paint) => lines.add('rect $rect');

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    lines.add('paragraph $offset');
    letters.add(
      _Letter(
        at: _at,
        turn: _turn,
        scale: _scale,
        offset: offset,
        width: paragraph.longestLine,
        height: paragraph.height,
      ),
    );
  }

  // The painter draws nothing else; a call it starts making fails here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _Letter {
  const _Letter({
    required this.at,
    required this.turn,
    required this.scale,
    required this.offset,
    required this.width,
    required this.height,
  });

  final Offset at;
  final double turn;
  final double scale;
  final Offset offset;
  final double width;
  final double height;
}

const Color _backbone = Color(0xFFB8B0A4);
const Color _adenine = Color(0xFF5FA8D3);
const Color _thymine = Color(0xFFE07A5F);
const Color _guanine = Color(0xFF81B29A);
const Color _cytosine = Color(0xFFF2CC8F);
const Color _transcript = Color(0xFF4FD1C5);
const Color _ground = Color(0xFF1C1B1A);

const TextStyle _face = TextStyle(fontSize: 12, height: 1, color: _ground);

/// Insulin's first 33 bases as the zoom lays them, 3′ end first, a quarter
/// of the way round, with [letters] where given.
_Calls _frame({HelixLetters? letters, double bases = 1}) {
  const String first = 'AGCCCTCCAGGACAGGCTGCATCAGAAGAGGCC';
  final HelixModel model = HelixModel(
    rungCount: first.length,
    sampleCount: 3 * first.length,
    bases: Uint8List.fromList(<int>[
      for (int i = first.length - 1; i >= 0; i--) HelixPalette.ofBase(first[i]),
    ]),
  );
  const double perBase = HelixModel.defaultPitch / HelixModel.basePairsPerTurn;
  final _Calls calls = _Calls();
  DnaHelixPainter(
    repaint: kAlwaysDismissedAnimation,
    rotation: const AlwaysStoppedAnimation<double>(0.27),
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
    bases: bases,
    letters: letters,
  ).paint(
    calls,
    const Size(HelixModel.defaultRadius * 4.4, first.length * perBase * 1.3),
  );
  return calls;
}

/// The discs drawn in a base's colour, not the ground's ring behind each.
List<(Offset, double, Color)> _bases(_Calls calls) => <(Offset, double, Color)>[
  for (final (Offset, double, Color) d in calls.discs)
    if (d.$3.toARGB32() != _ground.toARGB32()) d,
];

/// Each base's radius by where it is: the depth sort may settle a tie
/// differently once the balls grow, but no ball moves.
Map<Offset, double> _radii(_Calls calls) => <Offset, double>{
  for (final (Offset at, double r, Color _) in _bases(calls)) at: r,
};

void main() {
  test('letters showing none draw exactly what no letters do', () {
    expect(
      _frame(letters: const HelixLetters(style: _face, shown: 0)).lines,
      _frame().lines,
    );
  });

  test('every base is lettered, the letter centred in its ball, which is '
      'drawn larger by the growth and keeps its ring', () {
    final _Calls plain = _frame();
    final _Calls lettered = _frame(
      letters: const HelixLetters(style: _face, turn: -1.5),
    );
    final List<(Offset, double, Color)> balls = _bases(lettered);
    expect(balls, isNotEmpty);
    expect(lettered.letters, hasLength(balls.length));

    final Map<Offset, double> before = _radii(plain);
    for (final (Offset at, double r, Color _) in balls) {
      expect(
        r,
        closeTo(before[at]! * DnaHelixPainter.letteredGrowth, 1e-9),
        reason: 'the ball at $at',
      );
    }
    // Each ball's ring, the ground disc drawn just before it, is as much
    // wider than it as before.
    double ringOf(_Calls calls, Offset at) {
      final int i = calls.discs.lastIndexWhere(
        ((Offset, double, Color) d) =>
            d.$1 == at && d.$3.toARGB32() != _ground.toARGB32(),
      );
      return calls.discs[i - 1].$2 - calls.discs[i].$2;
    }

    for (final (Offset at, double _, Color _) in balls) {
      expect(ringOf(lettered, at), closeTo(ringOf(plain, at), 1e-9));
    }

    // Each letter is set right after its ball, at its centre, turned as
    // asked, whole, and centred on that point.
    final List<String> lines = lettered.lines;
    int letter = 0;
    for (int i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('paragraph')) {
        continue;
      }
      final (Offset at, double _, Color _) = balls[letter];
      final _Letter set = lettered.letters[letter];
      expect(lines[i - 5], startsWith('circle'));
      expect(set.at, at);
      expect(set.turn, -1.5);
      expect(set.scale, 1);
      expect(set.offset.dx + set.width / 2, closeTo(0, 0.5));
      expect(set.offset.dy + set.height / 2, closeTo(0, 0.5));
      letter++;
    }
  });

  test('half shown, the balls are halfway grown and the letters half size', () {
    final Map<Offset, double> before = _radii(_frame());
    final _Calls half = _frame(
      letters: const HelixLetters(style: _face, shown: 0.5),
    );
    for (final (Offset at, double r, Color _) in _bases(half)) {
      expect(
        r,
        closeTo(
          before[at]! * (1 + (DnaHelixPainter.letteredGrowth - 1) / 2),
          1e-9,
        ),
      );
    }
    expect(half.letters, isNotEmpty);
    for (final _Letter set in half.letters) {
      expect(set.scale, closeTo(0.5, 1e-12));
    }
  });

  test('a letter shrinks with its ball as the bases come in, and none is '
      'set where no base shows', () {
    final _Calls coming = _frame(
      letters: const HelixLetters(style: _face),
      bases: 0.4,
    );
    expect(coming.letters, isNotEmpty);
    for (final _Letter set in coming.letters) {
      expect(set.scale, closeTo(0.4, 1e-12));
    }
    expect(
      _frame(letters: const HelixLetters(style: _face), bases: 0).letters,
      isEmpty,
    );
  });

  test('each base slot is lettered as its base', () {
    for (int slot = 0; slot < HelixPalette.firstLit; slot++) {
      expect(HelixPalette.ofBase(HelixLetters.ofSlot[slot]), slot);
    }
    expect(HelixLetters.ofSlot, hasLength(HelixPalette.firstLit));
  });
}
