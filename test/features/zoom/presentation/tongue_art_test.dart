import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/tongue/tongue_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/tongue/tongue_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['tongue']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.tongueUpright;

/// The figure's salivary glands, which lie round the mouth on either
/// figure.
const String _salivary = 'UBERON_0001044';

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

TongueForm _form(AnatomyFigure figure) =>
    TongueForm.place(part: figure.parts[_anatomy.uberon]!, view: _view);

OrganArt _organ(AnatomyFigure figure) => OrganArt.forTissue(
  _anatomy,
  figure.parts[_anatomy.uberon],
  _view,
  figure: figure,
  cellName: 'Myonuclei',
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
/// each path drawn with a shader (the figure's faint parts), and how many
/// layers and meshes.
class _Record implements Canvas {
  final List<(Rect, Color)> paths = <(Rect, Color)>[];
  final List<Path> shaded = <Path>[];
  final List<(Rect, Color)> circles = <(Rect, Color)>[];
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
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add((Rect.fromCircle(center: c, radius: radius), paint.color));

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
      'tone over the intrinsic muscle; nothing else leans to it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = TongueArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final TongueForm form = _form(figure);
      final TongueArt art = TongueArt(form, inks);
      for (final (String part, Float32List _, Int32List colours)
          in art.meshData) {
        expect(
          colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
          isEmpty,
          reason: '${figure.name}: $part',
        );
      }
      final _Record canvas = _Record();
      art
        ..prepare()
        ..paint(canvas, form.mm(0.05));
      final Rect muscle = (Path()..addPolygon(form.home, true)).getBounds();
      final List<(Rect, Color)> marked = <(Rect, Color)>[
        for (final (Rect r, Color colour) in <(Rect, Color)>[
          ...canvas.paths,
          ...canvas.circles,
        ])
          if (_tealness(colour.toARGB32()) > 0.01) (r, colour),
      ];
      expect(marked, isNotEmpty, reason: figure.name);
      for (final (Rect r, Color c) in marked) {
        expect(c.toARGB32(), home.toARGB32(), reason: figure.name);
        // The intrinsic muscle, and nothing wider.
        expect(
          muscle.inflate(1e-9).contains(r.topLeft) &&
              muscle.inflate(1e-9).contains(r.bottomRight),
          isTrue,
          reason: '${figure.name}: $r',
        );
      }
      for (final MapEntry<String, Color> fill in art.fills.entries) {
        expect(
          _tealness(fill.value.toARGB32()) > 0.01,
          fill.key == 'intrinsic',
          reason: fill.key,
        );
      }
      expect(art.fills['intrinsic']!.toARGB32(), home.toARGB32());
      expect(TongueArt.bedOf(inks).toARGB32(), home.toARGB32());
    }
  });

  testWidgets('at the hand-over the tongue is the body’s own outline, flat '
      'in the mark, with no layer or mesh; at its stop the section, with no '
      'layer, the figure’s own parts round it at a person’s size, its '
      'salivary glands among them', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final AnatomyPart part = figure.parts[_anatomy.uberon]!;
      Offset placed(Offset p) => (p - part.centre) / _view;
      final Rect body = Contour(<Offset>[
        for (final Offset p in part.followed) placed(p),
      ]).toPath().getBounds();
      final OrganArt art = _organ(figure);
      expect(art.followsBody, isTrue);
      expect(art.real, 1);
      final _Record handed = _Record();
      art.paint(handed, inks, 1 / 390, 1, detail: 0);
      expect(handed.layers, 0, reason: figure.name);
      expect(handed.meshes, 0, reason: figure.name);
      expect(<Rect>[
        for (final (Rect bounds, Color _) in handed.paths) bounds,
      ], contains(body));
      final _Record rest = _Record();
      art.paint(rest, inks, 1 / 390, 1);
      expect(rest.layers, 0, reason: figure.name);
      expect(rest.meshes, greaterThan(0), reason: figure.name);
      expect(rest.shaded, isNotEmpty, reason: figure.name);
      expect(art.outline.contains(art.site), isTrue, reason: figure.name);
      // The figure's salivary glands are drawn round it, outside the
      // section.
      final Path around = rest.shaded.first;
      final Path whole = _form(figure).whole;
      bool found = false;
      final double step = 5e-4 / _view;
      for (final List<Offset> contour in figure.parts[_salivary]!.contours) {
        final Path gland = Path()
          ..addPolygon(<Offset>[
            for (final Offset p in contour) placed(p),
          ], true);
        final Rect box = gland.getBounds();
        for (double y = box.top; y <= box.bottom && !found; y += step) {
          for (double x = box.left; x <= box.right && !found; x += step) {
            final Offset p = Offset(x, y);
            found =
                gland.contains(p) && !whole.contains(p) && around.contains(p);
          }
        }
      }
      expect(found, isTrue, reason: figure.name);
    }
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final TongueArt first = TongueArt(_form(figure), inks);
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = TongueArt(
        _form(figure),
        inks,
      ).meshData;
      expect(a.length, b.length);
      expect(a, isNotEmpty);
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
            reason: '${figure.name}: ${a[i].$1}',
          );
        }
      }
      final _Record canvas = _Record();
      first
        ..prepare()
        ..paint(canvas, first.form.mm(0.05));
      for (final (Rect r, Color _) in <(Rect, Color)>[
        ...canvas.paths,
        ...canvas.circles,
      ]) {
        expect(
          first.bounds.inflate(1e-9).contains(r.topLeft) &&
              first.bounds.inflate(1e-9).contains(r.bottomRight),
          isTrue,
          reason: '${figure.name}: $r',
        );
      }
    }
  });

  test('it names the intrinsic muscles, in the mark, and the genioglossus, '
      'the hyoglossus, the sublingual gland, the mylohyoid and the '
      'mandible, in the quiet ink, set round it', () {
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final OrganArt art = _organ(figure);
      final TongueForm form = _form(figure);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          'intrinsic muscles',
          'genioglossus',
          'hyoglossus',
          'sublingual\ngland',
          'mylohyoid',
          'mandible',
        ],
        reason: figure.name,
      );
      expect(
        <bool>[for (final OrganName n in art.names) n.home],
        <bool>[true, for (int i = 1; i < art.names.length; i++) false],
      );
      expect(art.names.first.at, form.homeName);
      expect(art.columns, isEmpty);
      expect(art.named, isNotEmpty);
      // Inside the soft tissue all but the mandible, in its bone.
      for (final OrganName n in art.names) {
        expect(
          form.contains(n.at),
          n.key != 'mandible',
          reason: '${figure.name}: ${n.word}',
        );
        expect(form.whole.contains(n.at), isTrue, reason: n.word);
      }
    }
  });
}
