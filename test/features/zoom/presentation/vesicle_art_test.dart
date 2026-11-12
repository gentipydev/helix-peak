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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/seminal_vesicle/vesicle_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/seminal_vesicle/vesicle_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['seminal vesicle']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.seminalVesicleUpright;
final AnatomyFigure _figure = AnatomyFigure.male;
final AnatomyPart _part = _figure.parts[_anatomy.uberon]!;

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

SeminalVesicleForm _form() =>
    SeminalVesicleForm.place(part: _part, anatomy: _anatomy, view: _view);

OrganArt _organ() =>
    OrganArt.forTissue(_anatomy, _part, _view, figure: _figure);

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

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('the mark shows only where the zoom’s cell lives, one flat '
      'tone: the opened vesicle’s mucosa; no mesh leans to it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = SeminalVesicleArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    final SeminalVesicleForm form = _form();
    final SeminalVesicleArt art = SeminalVesicleArt(form, inks);
    for (final (String part, Float32List _, Int32List colours)
        in art.meshData) {
      expect(
        colours.where((int c) => c >>> 24 != 0 && _tealness(c) > 0.01),
        isEmpty,
        reason: part,
      );
    }
    final _Record canvas = _Record();
    art
      ..prepare()
      ..paint(canvas, form.mm(0.05));
    final List<Color> marked = <Color>[
      for (final (Rect _, Color colour) in canvas.paths)
        if (_tealness(colour.toARGB32()) > 0.01) colour,
    ];
    expect(marked, isNotEmpty);
    for (final Color c in marked) {
      expect(c.toARGB32(), home.toARGB32());
    }
    expect(art.fills['mucosa']!.toARGB32(), home.toARGB32());
    for (final MapEntry<String, Color> fill in art.fills.entries) {
      if (fill.key != 'mucosa') {
        expect(
          _tealness(fill.value.toARGB32()),
          lessThan(0.01),
          reason: fill.key,
        );
      }
    }
    expect(SeminalVesicleArt.bedOf(inks).toARGB32(), home.toARGB32());
  });

  testWidgets('at the hand-over the vesicle is the body’s own outline, flat '
      'in the mark, with no layer or mesh; at its stop the specimen, with '
      'no layer, and the figure gone from round it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final double real = _anatomy.metres / _part.extent;
    Offset placed(Offset p) => (p - _part.centre) * (real / _view);
    final Rect body = Contour(<Offset>[
      for (final Offset p in _part.followed) placed(p),
    ]).toPath().getBounds();
    final OrganArt art = _organ();
    expect(art.followsBody, isTrue);
    expect(art.real, closeTo(real, 1e-12));
    final _Record handed = _Record();
    art.paint(handed, inks, 1 / 390, 1 / real, detail: 0);
    expect(handed.layers, 0);
    expect(handed.meshes, 0);
    expect(<Rect>[
      for (final (Rect bounds, Color _) in handed.paths) bounds,
    ], contains(body));
    // Part way, the figure's parts still show round it, giving way.
    final _Record midway = _Record();
    art.paint(midway, inks, 1 / 390, 1, detail: 0.3);
    expect(midway.shaded, isNotEmpty);
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
    expect(rest.shaded, isEmpty);
    expect(art.outline.contains(art.site), isTrue);
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final SeminalVesicleArt first = SeminalVesicleArt(_form(), inks);
    final List<(String, Float32List, Int32List)> a = first.meshData;
    final List<(String, Float32List, Int32List)> b = SeminalVesicleArt(
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
    final _Record canvas = _Record();
    first
      ..prepare()
      ..paint(canvas, first.form.mm(0.05));
    for (final (Rect r, Color _) in canvas.paths) {
      expect(
        first.bounds.inflate(1e-9).contains(r.topLeft) &&
            first.bounds.inflate(1e-9).contains(r.bottomRight),
        isTrue,
        reason: '$r',
      );
    }
  });

  test('it names the mucosa, in the mark, and the whole vesicle, its '
      'ampulla and its deferent duct, the ejaculatory duct and the prostate, '
      'in the quiet ink, set round it', () {
    final OrganArt art = _organ();
    final SeminalVesicleForm form = _form();
    expect(
      <String>[for (final OrganName n in art.names) n.word],
      <String>[
        'mucosa',
        'vas deferens',
        'seminal vesicle',
        'ampulla',
        'ejaculatory duct',
        'prostate',
      ],
    );
    expect(
      <bool>[for (final OrganName n in art.names) n.home],
      <bool>[true, for (int i = 1; i < art.names.length; i++) false],
    );
    expect(art.names.first.at, form.homeName);
    expect(art.columns, isEmpty);
    expect(art.named, isNotEmpty);
    // Inside the opened vesicle the mucosa alone.
    for (final OrganName n in art.names) {
      expect(form.contains(n.at), n.key == 'home', reason: n.word);
    }
  });
}
