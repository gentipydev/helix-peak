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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vessel/aorta_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/vessel/aorta_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['blood vessel']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.vesselUpright;

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

AortaForm _form({AortaHome home = AortaHome.media}) =>
    AortaForm(length: _anatomy.metres / _view, view: _view, home: home);

/// The aorta as the zoom draws it about a cell the Atlas calls [cell].
OrganArt _organ([String? cell]) => OrganArt.forTissue(
  _anatomy,
  AnatomyFigure.female.parts[_anatomy.uberon],
  _view,
  figure: AnatomyFigure.female,
  shape: CellShape.spindle,
  cellName: cell,
);

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// does the red the arteries are drawn in.
double _tealness(int colour) {
  final double r = (colour >> 16 & 255) / 255;
  final double g = (colour >> 8 & 255) / 255;
  final double b = (colour & 255) / 255;
  return b < g ? g - r : 2 * g - r - b;
}

/// A canvas that keeps what is drawn on it: each path's bounds and colour,
/// each path drawn with a shader (the figure's faint parts), each set of
/// points and its colour, and how many layers and meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> paths = <(Rect, Color)>[];
  final List<Path> shaded = <Path>[];
  final List<(Float32List, Color)> points = <(Float32List, Color)>[];
  int layers = 0;
  int meshes = 0;

  @override
  void drawPath(Path path, Paint paint) {
    paths.add((path.getBounds(), paint.color));
    if (paint.shader != null && paint.style == PaintingStyle.fill) {
      shaded.add(path);
    }
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      meshes++;

  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) =>
      this.points.add((points, paint.color));

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('the mark shows only where the zoom’s cell lives, one coat in '
      'one flat tone, whichever the Atlas names; no mesh leans to it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = AortaArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final AortaHome coat in AortaHome.values) {
      final AortaForm form = _form(home: coat);
      final AortaArt art = AortaArt(form, inks);
      for (final (String part, Float32List _, Int32List colours)
          in art.meshData) {
        expect(
          colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
          isEmpty,
          reason: '${coat.name}: $part',
        );
      }
      for (final MapEntry<String, Color> fill in art.fills.entries) {
        expect(
          fill.value.toARGB32() == home.toARGB32(),
          fill.key == coat.name,
          reason: '${coat.name}: ${fill.key}',
        );
      }
      final _Record canvas = _Record();
      art
        ..prepare()
        ..paint(canvas, form.mm(0.25));
      expect(
        canvas.paths
            .where(((Rect, Color) p) => _tealness(p.$2.toARGB32()) > 0.01)
            .map(((Rect, Color) p) => p.$2.toARGB32())
            .toSet(),
        <int>{home.toARGB32()},
        reason: coat.name,
      );
      expect(canvas.points, isEmpty);
    }
  });

  testWidgets('it comes up over the body’s tree of vessels on its own: no '
      'outline of the body’s is followed, and nothing is layered', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final OrganArt art = _organ();
    expect(art.followsBody, isFalse);
    expect(art.real, 1);
    final _Record canvas = _Record();
    art.paint(canvas, inks, 1 / 390, 1);
    expect(canvas.layers, 0);
    expect(canvas.meshes, greaterThan(0));
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final AortaArt first = AortaArt(_form(), inks);
    final List<(String, Float32List, Int32List)> a = first.meshData;
    final List<(String, Float32List, Int32List)> b = AortaArt(
      _form(),
      inks,
    ).meshData;
    expect(a.length, b.length);
    for (int i = 0; i < a.length; i++) {
      expect(a[i].$1, b[i].$1);
      expect(a[i].$2, b[i].$2);
      expect(a[i].$3, b[i].$3);
      expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
      final Float32List xy = a[i].$2;
      for (int k = 0; k < xy.length; k += 2) {
        expect(
          first.bounds.contains(Offset(xy[k], xy[k + 1])),
          isTrue,
          reason: a[i].$1,
        );
      }
    }
  });

  test('it names where the zoom’s cell lives, in the mark, by the Atlas’s '
      'name for the cell, and the other coats, an intercostal artery and the '
      'azygos in the quiet ink, in a column at either edge', () {
    final OrganArt art = _organ();
    expect(
      <String>[for (final OrganName n in art.names) n.word],
      <String>[
        'media',
        'intima',
        'adventitia',
        'intercostal\nartery',
        'azygos\nvein',
      ],
    );
    expect(
      <bool>[for (final OrganName n in art.names) n.home],
      <bool>[true, for (int i = 1; i < art.names.length; i++) false],
    );
    expect(art.names.first.at, art.site);
    expect(art.columns.keys.toSet(), <String>{
      for (final OrganName n in art.names) n.key,
    });
    expect(art.columns['home']!.side, -1);
    expect(art.columns['azygos']!.side, -1);
    expect(art.columns['intima']!.side, 1);
    expect(art.outline.contains(art.site), isTrue);
    final OrganArt endothelial = _organ('Vascular endothelial cells');
    expect(endothelial.names.first.word, 'intima');
    expect(<String>[
      for (final OrganName n in endothelial.names) n.word,
    ], containsAll(<String>['media', 'adventitia']));
  });
}
