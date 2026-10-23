import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skin/skin_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/skin/skin_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['skin']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.skinUpright;

SkinForm _form() => SkinForm(width: _anatomy.metres / _view, view: _view);

/// A cell the Atlas names for each part of the skin a cell lives in.
const Map<SkinHome, String> _cells = <SkinHome, String>{
  SkinHome.melanocytes: 'Melanocytes',
  SkinHome.basalLayer: 'Basal keratinocytes',
  SkinHome.epidermis: 'Suprabasal keratinocytes',
  SkinHome.follicle: 'Outer root sheath cells',
  SkinHome.sebaceousGland: 'Sebaceous gland cells',
  SkinHome.sweatGland: 'Eccrine sweat gland cells',
  SkinHome.dermis: 'Fibroblasts',
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
/// and how many meshes.
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
  void drawOval(Rect rect, Paint paint) => shapes.add((rect, paint.color));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      shapes.add((Rect.fromPoints(p1, p2), paint.color));

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      meshes++;

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The shapes drawn in the mark for each home, by their bounds.
List<Rect> _marked(SkinForm form, SkinHome home) {
  Rect line(List<Offset> points) =>
      (Path()..addPolygon(points, false)).getBounds();
  return switch (home) {
    SkinHome.melanocytes => <Rect>[
      line(form.basal),
      form.bulb.getBounds(),
      form.otherBulb.getBounds(),
    ],
    SkinHome.basalLayer => <Rect>[line(form.basal)],
    SkinHome.epidermis => <Rect>[
      form.epidermis.getBounds(),
      form.sideEpidermis.getBounds(),
    ],
    SkinHome.follicle => <Rect>[
      form.follicle.getBounds(),
      form.other.getBounds(),
      form.otherBulb.getBounds(),
    ],
    SkinHome.sebaceousGland => <Rect>[form.gland.getBounds()],
    SkinHome.sweatGland => <Rect>[
      for (final SkinCoil coil in form.coils) ...<Rect>[
        coil.ball.getBounds(),
        coil.loops.getBounds(),
        line(coil.duct),
      ],
    ],
    SkinHome.dermis => <Rect>[
      form.reticular.getBounds(),
      form.papillary.getBounds(),
      form.sideReticular.getBounds(),
      form.sidePapillary.getBounds(),
    ],
  };
}

bool _same(Rect a, Rect b) =>
    (a.left - b.left).abs() < 1e-6 &&
    (a.top - b.top).abs() < 1e-6 &&
    (a.right - b.right).abs() < 1e-6 &&
    (a.bottom - b.bottom).abs() < 1e-6;

void main() {
  testWidgets('the mark shows only where the zoom’s cell lives, one flat '
      'tone: nothing else leans to it, no mesh, no fill and no line', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final SkinForm form = _form();
    final Color home = Color.alphaBlend(inks.glow(0.42), inks.lit(0.2));
    for (final SkinHome where in SkinHome.values) {
      final SkinArt art = SkinArt(form, inks, home: where);
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
        if (fill.key != 'home') {
          expect(
            _tealness(fill.value.toARGB32()),
            lessThan(0.01),
            reason: '${where.name}: ${fill.key}',
          );
        }
      }
      final _Record canvas = _Record();
      art.paint(canvas, form.mm(0.03));
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
      final List<Rect> expected = _marked(form, where);
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
      'and named there', (WidgetTester tester) async {
    for (final MapEntry<SkinHome, String> cell in _cells.entries) {
      expect(SkinHome.of(cell.value), cell.key, reason: cell.value);
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
      // No name twice, and each in a column.
      final List<String> words = <String>[
        for (final OrganName name in organ.names) name.word,
      ];
      expect(words.toSet(), hasLength(words.length), reason: cell.value);
      expect(organ.columns.keys.toSet(), <String>{
        for (final OrganName name in organ.names) name.key,
      });
      expect(organ.outline.contains(organ.site), isTrue);
      expect(organ.followsBody, isFalse);
    }
    // The melanocytes' home and every layer and part besides: eight names.
    expect(
      OrganArt.forTissue(_anatomy, null, _view, cellName: 'Melanocytes').names,
      hasLength(8),
    );
  });

  testWidgets('it builds what it draws ahead of its first frame, and what '
      'it covers holds every mesh vertex and every shape', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final SkinForm form = _form();
    final SkinArt art = SkinArt(form, inks, home: SkinHome.melanocytes)
      ..prepare();
    final Rect bounds = art.bounds.inflate(1e-9);
    for (final (String part, Float32List positions, Int32List _)
        in art.meshData) {
      for (int i = 0; i + 1 < positions.length; i += 2) {
        expect(
          bounds.contains(Offset(positions[i], positions[i + 1])),
          isTrue,
          reason: part,
        );
      }
    }
    final _Record canvas = _Record();
    art.paint(canvas, form.mm(0.03));
    for (final (Rect r, Color _) in canvas.shapes) {
      expect(
        bounds.contains(r.topLeft) && bounds.contains(r.bottomRight),
        isTrue,
        reason: '$r',
      );
    }
  });
}
