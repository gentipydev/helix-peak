import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/placenta/placenta_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/placenta/placenta_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/placenta/placenta_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['placenta']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.placentaUpright;

PlacentaForm _form() =>
    PlacentaForm(width: _anatomy.metres / _view, view: _view);

/// A cell the Atlas names for each part of the placenta a cell lives in.
const Map<PlacentaHome, String> _cells = <PlacentaHome, String>{
  PlacentaHome.villi: 'Syncytiotrophoblasts',
  PlacentaHome.decidua: 'Decidual stromal cells',
};

Future<ZoomInks> _inks(WidgetTester tester) async {
  late ZoomInks inks;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.analysis,
      home: Builder(
        builder: (BuildContext context) {
          inks = ZoomInks.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return inks;
}

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// do the blood red, the honey and the clay.
double _tealness(int colour) {
  final double r = (colour >> 16 & 255) / 255;
  final double g = (colour >> 8 & 255) / 255;
  final double b = (colour & 255) / 255;
  return b < g ? g - r : 2 * g - r - b;
}

/// A canvas that keeps what is drawn on it: each shape's bounds and colour,
/// the villi's dots among them, and how many meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> shapes = <(Rect, Color)>[];
  int meshes = 0;

  @override
  void drawPath(Path path, Paint paint) =>
      shapes.add((path.getBounds(), paint.color));

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      shapes.add((Rect.fromCircle(center: c, radius: radius), paint.color));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      shapes.add((Rect.fromPoints(p1, p2), paint.color));

  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) {
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;
    for (int i = 0; i + 1 < points.length; i += 2) {
      left = points[i] < left ? points[i] : left;
      right = points[i] > right ? points[i] : right;
      top = points[i + 1] < top ? points[i + 1] : top;
      bottom = points[i + 1] > bottom ? points[i + 1] : bottom;
    }
    shapes.add((
      Rect.fromLTRB(left, top, right, bottom).inflate(paint.strokeWidth / 2),
      paint.color,
    ));
  }

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      meshes++;

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The bounds of every dot of [clumps].
List<Rect> _dots(List<PlacentaClumps> clumps, double line) => <Rect>[
  for (final PlacentaClumps c in clumps)
    () {
      double left = double.infinity;
      double top = double.infinity;
      double right = double.negativeInfinity;
      double bottom = double.negativeInfinity;
      for (int i = 0; i + 1 < c.points.length; i += 2) {
        left = c.points[i] < left ? c.points[i] : left;
        right = c.points[i] > right ? c.points[i] : right;
        top = c.points[i + 1] < top ? c.points[i + 1] : top;
        bottom = c.points[i + 1] > bottom ? c.points[i + 1] : bottom;
      }
      return Rect.fromLTRB(
        left,
        top,
        right,
        bottom,
      ).inflate(c.radius > line / 2 ? c.radius : line / 2);
    }(),
];

/// The shapes drawn in the mark for each home, by their bounds.
List<Rect> _marked(PlacentaForm form, PlacentaHome home, double line) =>
    switch (home) {
      PlacentaHome.villi => <Rect>[
        form.stems.getBounds(),
        ..._dots(form.clumps, line),
        ..._dots(form.sideClumps, line),
      ],
      PlacentaHome.decidua => <Rect>[
        (Path()..addPolygon(<Offset>[
              for (final List<Offset> s in form.septaPoints) ...s,
            ], false))
            .getBounds(),
        form.basal.getBounds(),
        form.decidua.getBounds(),
        form.sideDecidua.getBounds(),
      ],
    };

bool _same(Rect a, Rect b) =>
    (a.left - b.left).abs() < 1e-6 &&
    (a.top - b.top).abs() < 1e-6 &&
    (a.right - b.right).abs() < 1e-6 &&
    (a.bottom - b.bottom).abs() < 1e-6;

void main() {
  test('its card gives the placenta’s thickness in utero, 4 cm, and the '
      'block is 5 cm across', () {
    expect(_anatomy.thickness, 0.04);
    expect(_anatomy.metres, 0.05);
    expect(_anatomy.thickness! * 1e3, closeTo(PlacentaAnatomy.thickness, 0.5));
    expect(_anatomy.metres * 1e3, PlacentaAnatomy.width);
  });

  testWidgets('the mark shows only where the zoom’s cell lives, one flat '
      'tone: its villi or its decidua; nothing else leans to it, no mesh, '
      'no fill and no line', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final PlacentaForm form = _form();
    final double line = form.mm(0.05);
    final Color home = Color.alphaBlend(inks.glow(0.42), inks.lit(0.2));
    for (final PlacentaHome where in PlacentaHome.values) {
      final PlacentaArt art = PlacentaArt(form, inks, home: where);
      expect(art.homeTone, home, reason: where.name);
      for (final (String part, Float32List _, Int32List colours)
          in art.meshData) {
        expect(
          colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
          isEmpty,
          reason: '${where.name}: $part',
        );
      }
      for (final MapEntry<String, Color> fill in art.fills.entries) {
        if (fill.key != 'home' && fill.key != where.name) {
          expect(
            _tealness(fill.value.toARGB32()),
            lessThan(0.01),
            reason: '${where.name}: ${fill.key}',
          );
        }
      }
      expect(art.fills[where.name], home, reason: where.name);
      final _Record canvas = _Record();
      art.paint(canvas, line);
      expect(canvas.meshes, greaterThan(0));
      final List<Rect> inMark = <Rect>[
        for (final (Rect r, Color c) in canvas.shapes)
          if (c.toARGB32() == home.toARGB32()) r,
      ];
      for (final (Rect r, Color c) in canvas.shapes) {
        if (c.toARGB32() != home.toARGB32() && c.a > 0) {
          expect(
            _tealness(c.toARGB32()),
            lessThan(0.01),
            reason: '${where.name}: $r in $c',
          );
        }
      }
      final List<Rect> expected = _marked(form, where, line);
      for (final Rect r in expected) {
        expect(
          inMark.any((Rect m) => _same(m, r)),
          isTrue,
          reason: '${where.name}: $r not in the mark',
        );
      }
      for (final Rect m in inMark) {
        expect(
          expected.any((Rect r) => _same(m, r)),
          isTrue,
          reason: '${where.name}: $m in the mark',
        );
      }
    }
  });

  testWidgets('a cell is drawn where the Atlas’s name for it says it lives, '
      'and named there; the same six names whichever it is', (
    WidgetTester tester,
  ) async {
    final List<Set<String>> words = <Set<String>>[];
    for (final MapEntry<PlacentaHome, String> cell in _cells.entries) {
      expect(PlacentaHome.of(cell.value), cell.key, reason: cell.value);
      final OrganArt organ = OrganArt.forTissue(
        _anatomy,
        null,
        _view,
        cellName: cell.value,
      );
      final List<OrganName> homes = <OrganName>[
        for (final OrganName name in organ.names)
          if (name.home) name,
      ];
      expect(homes, hasLength(1), reason: cell.value);
      expect(homes.single.word, cell.key.word, reason: cell.value);
      expect(organ.names.first, homes.single, reason: cell.value);
      // No name twice, and each in a column.
      final List<String> named = <String>[
        for (final OrganName name in organ.names) name.word,
      ];
      expect(named.toSet(), hasLength(named.length), reason: cell.value);
      expect(organ.names, hasLength(6), reason: cell.value);
      expect(organ.columns.keys.toSet(), <String>{
        for (final OrganName name in organ.names) name.key,
      });
      expect(organ.outline.contains(organ.site), isTrue);
      expect(organ.followsBody, isFalse);
      words.add(named.toSet());
    }
    expect(words.first, words.last);
  });

  testWidgets('it builds what it draws ahead of its first frame, the same '
      'every time, and what it covers holds every mesh vertex and every '
      'shape', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final PlacentaForm form = _form();
    for (final PlacentaHome home in PlacentaHome.values) {
      final PlacentaArt art = PlacentaArt(form, inks, home: home)..prepare();
      final List<(String, Float32List, Int32List)> again = PlacentaArt(
        _form(),
        inks,
        home: home,
      ).meshData;
      final Rect bounds = art.bounds.inflate(1e-9);
      final List<(String, Float32List, Int32List)> meshes = art.meshData;
      expect(meshes.length, again.length);
      for (int i = 0; i < meshes.length; i++) {
        final (String part, Float32List positions, Int32List colours) =
            meshes[i];
        expect(positions, again[i].$2, reason: part);
        expect(colours, again[i].$3, reason: part);
        expect(positions.length ~/ 2, lessThanOrEqualTo(65000), reason: part);
        for (int k = 0; k + 1 < positions.length; k += 2) {
          expect(
            bounds.contains(Offset(positions[k], positions[k + 1])),
            isTrue,
            reason: part,
          );
        }
      }
      final _Record canvas = _Record();
      art.paint(canvas, form.mm(0.05));
      for (final (Rect r, Color _) in canvas.shapes) {
        expect(
          bounds.contains(r.topLeft) && bounds.contains(r.bottomRight),
          isTrue,
          reason: '${home.name}: $r',
        );
      }
    }
  });
}
