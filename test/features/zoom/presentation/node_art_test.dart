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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/lymph_node/node_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/lymph_node/node_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['lymphoid tissue']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.nodeUpright;

/// A cell the Atlas names for each part of the node a cell lives in.
const Map<NodeHome, String> _cells = <NodeHome, String>{
  NodeHome.sinuses: 'Lymphatic endothelial cells',
  NodeHome.follicles: 'B-cells',
  NodeHome.paracortex: 'T-cells',
  NodeHome.cords: 'Plasma cells',
  NodeHome.cortex: 'Fibroblasts',
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

OrganArt _organ(NodeHome home) => OrganArt.forTissue(
  _anatomy,
  AnatomyFigure.female.parts[_anatomy.uberon],
  _view,
  figure: AnatomyFigure.female,
  shape: CellShape.endothelial,
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
/// and how many layers and meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> paths = <(Rect, Color)>[];
  int layers = 0;
  int meshes = 0;

  @override
  void drawPath(Path path, Paint paint) =>
      paths.add((path.getBounds(), paint.color));

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
  testWidgets('the mark shows only where the zoom’s cell lives, one flat '
      'tone: its sinuses, its follicles, its paracortex, its cords or its '
      'cortex; no mesh leans to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = NodeArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final NodeHome where in NodeHome.values) {
      final String what = where.name;
      final NodeForm form = NodeForm(view: _view, home: where);
      final NodeArt art = NodeArt(form, inks);
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
      final List<(Rect, Color)> marked = <(Rect, Color)>[
        for (final (Rect r, Color colour) in canvas.paths)
          if (_tealness(colour.toARGB32()) > 0.01) (r, colour),
      ];
      expect(marked, hasLength(1), reason: what);
      expect(
        marked.single.$2.toARGB32(),
        where == NodeHome.sinuses ? inks.mark.toARGB32() : home.toARGB32(),
        reason: what,
      );
    }
  });

  testWidgets('it comes up over the body’s drawing of its chain, on its own: '
      'at its stop no layer, its meshes drawn', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final OrganArt art = _organ(NodeHome.sinuses);
    expect(art.followsBody, isFalse);
    expect(art.real, 1);
    expect(art.outline.contains(art.site), isTrue);
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final NodeHome home in NodeHome.values) {
      final NodeArt first = NodeArt(NodeForm(view: _view, home: home), inks);
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = NodeArt(
        NodeForm(view: _view, home: home),
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
            reason: '${home.name}: ${a[i].$1}',
          );
        }
      }
      final _Record canvas = _Record();
      first
        ..prepare()
        ..paint(canvas, first.form.mm(0.05));
      for (final (Rect r, Color _) in canvas.paths) {
        expect(
          first.bounds.inflate(1e-9).contains(r.topLeft) &&
              first.bounds.inflate(1e-9).contains(r.bottomRight),
          isTrue,
          reason: '${home.name}: $r',
        );
      }
    }
  });

  test('it names where the zoom’s cell lives, in the mark, and the '
      'follicles, the paracortex and the medulla, each but the home’s, and '
      'an afferent and the efferent lymphatic in the quiet ink, set round '
      'it', () {
    for (final NodeHome home in NodeHome.values) {
      final String what = home.name;
      final OrganArt art = _organ(home);
      final NodeForm form = NodeForm(view: _view, home: home);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          home.word,
          if (home != NodeHome.follicles) 'follicles',
          if (home != NodeHome.paracortex) 'paracortex',
          'medulla',
          'afferent lymphatic',
          'efferent lymphatic',
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
      // The parts named inside the node, but the lymphatics outside it.
      for (final OrganName n in art.names) {
        expect(
          form.contains(n.at),
          !n.word.contains('lymphatic'),
          reason: '$what: ${n.word}',
        );
      }
    }
  });
}
