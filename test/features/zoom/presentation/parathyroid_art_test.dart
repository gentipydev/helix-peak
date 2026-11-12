import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/parathyroid/parathyroid_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/parathyroid/parathyroid_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['parathyroid gland']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.parathyroidUpright;

/// A cell the Atlas could name for each part of the gland a cell lives in.
const Map<ParathyroidHome, String?> _cells = <ParathyroidHome, String?>{
  ParathyroidHome.chief: null,
  ParathyroidHome.oxyphil: 'Oxyphil cells',
  ParathyroidHome.fat: 'Adipocytes',
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

OrganArt _organ(ParathyroidHome home) => OrganArt.forTissue(
  _anatomy,
  AnatomyFigure.female.parts[_anatomy.uberon],
  _view,
  figure: AnatomyFigure.female,
  shape: CellShape.endocrine,
  cellName: _cells[home],
);

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two.
double _tealness(int colour) {
  final double r = (colour >> 16 & 255) / 255;
  final double g = (colour >> 8 & 255) / 255;
  final double b = (colour & 255) / 255;
  return b < g ? g - r : 2 * g - r - b;
}

/// A canvas that keeps what is drawn on it: each path's bounds and colour,
/// the points' colours, and how many layers and meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> paths = <(Rect, Color)>[];
  final List<Color> points = <Color>[];
  int layers = 0;
  int meshes = 0;

  @override
  void drawPath(Path path, Paint paint) =>
      paths.add((path.getBounds(), paint.color));

  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) =>
      this.points.add(paint.color);

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      meshes++;

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('the mark shows only where the zoom’s cell lives: its chief '
      'cells or its oxyphil nodules in one flat tone, or its fat; no mesh '
      'leans to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = ParathyroidArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final ParathyroidHome where in ParathyroidHome.values) {
      final String what = where.name;
      final ParathyroidForm form = ParathyroidForm(view: _view, home: where);
      final ParathyroidArt art = ParathyroidArt(form, inks);
      for (final (String part, Float32List _, Int32List colours)
          in art.meshData) {
        expect(
          colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
          isEmpty,
          reason: '$what: $part',
        );
      }
      final _Record canvas = _Record();
      art
        ..prepare()
        ..paint(canvas, form.mm(0.05));
      final List<Color> marked = <Color>[
        for (final (Rect _, Color colour) in canvas.paths)
          if (_tealness(colour.toARGB32()) > 0.01) colour,
        for (final Color colour in canvas.points)
          if (_tealness(colour.toARGB32()) > 0.01) colour,
      ];
      expect(marked, hasLength(1), reason: what);
      expect(
        marked.single.toARGB32(),
        where == ParathyroidHome.fat ? inks.mark.toARGB32() : home.toARGB32(),
        reason: what,
      );
      final String part = switch (where) {
        ParathyroidHome.chief => 'parenchyma',
        ParathyroidHome.oxyphil => 'oxyphil',
        ParathyroidHome.fat => 'fat',
      };
      expect(
        art.fills[part]!.toARGB32(),
        marked.single.toARGB32(),
        reason: what,
      );
    }
  });

  testWidgets('it comes up over the body’s drawing of the thyroid, on its '
      'own: at its stop no layer, its meshes drawn, sampled inside it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    for (final ParathyroidHome home in ParathyroidHome.values) {
      final OrganArt art = _organ(home);
      expect(art.followsBody, isFalse);
      expect(art.real, 1);
      expect(art.outline.contains(art.site), isTrue);
      final _Record rest = _Record();
      art.paint(rest, inks, 1 / 390, 1);
      expect(rest.layers, 0);
      expect(rest.meshes, greaterThan(0));
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ParathyroidHome home in ParathyroidHome.values) {
      final ParathyroidArt first = ParathyroidArt(
        ParathyroidForm(view: _view, home: home),
        inks,
      );
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = ParathyroidArt(
        ParathyroidForm(view: _view, home: home),
        inks,
      ).meshData;
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i].$1, b[i].$1);
        expect(a[i].$2, b[i].$2);
        expect(a[i].$3, b[i].$3);
        expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
        final Float32List xy = a[i].$2;
        final Int32List colours = a[i].$3;
        for (int k = 0; k < xy.length; k += 2) {
          // A vertex the lobe's fade leaves unseen may lie past them.
          if (colours[k ~/ 2] >>> 24 == 0) {
            continue;
          }
          expect(
            first.bounds.contains(Offset(xy[k], xy[k + 1])),
            isTrue,
            reason: '${home.name}: ${a[i].$1}',
          );
        }
      }
      final _Record canvas = _Record();
      first
        ..prepare()
        ..paint(canvas, first.form.mm(0.05));
      for (final (Rect r, Color _) in canvas.paths) {
        if (r.width > first.bounds.width * 2) {
          // The lobe's whole outline, drawn only as the clip its fading
          // mesh is drawn through.
          continue;
        }
        expect(
          first.bounds.inflate(1e-9).contains(r.topLeft) &&
              first.bounds.inflate(1e-9).contains(r.bottomRight),
          isTrue,
          reason: '${home.name}: $r',
        );
      }
    }
  });

  test('it names where the zoom’s cell lives, in the mark, and the oxyphil '
      'cells and the fat, each but the home’s, the thyroid, the inferior '
      'thyroid artery and the recurrent nerve in the quiet ink, set round '
      'it', () {
    for (final ParathyroidHome home in ParathyroidHome.values) {
      final String what = home.name;
      final OrganArt art = _organ(home);
      final ParathyroidForm form = ParathyroidForm(view: _view, home: home);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          home.word,
          if (home != ParathyroidHome.oxyphil) 'oxyphil cells',
          if (home != ParathyroidHome.fat) 'fat cells',
          'thyroid',
          'inferior thyroid artery',
          'recurrent nerve',
        ],
        reason: what,
      );
      expect(
        <bool>[for (final OrganName n in art.names) n.home],
        <bool>[true, for (int i = 1; i < art.names.length; i++) false],
        reason: what,
      );
      expect(art.names.first.at, form.homeName, reason: what);
      expect(art.columns, isEmpty, reason: what);
      expect(art.named, isNotEmpty, reason: what);
      // The parts of the gland named inside it, the rest outside it.
      for (final OrganName n in art.names) {
        expect(
          form.contains(n.at),
          n.word.endsWith('cells'),
          reason: '$what: ${n.word}',
        );
      }
    }
  });
}
