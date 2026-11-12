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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/smooth_muscle/detrusor_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/smooth_muscle/detrusor_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['smooth muscle']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.smoothMuscleUpright;

/// The figure's parts never drawn round an organ, the skin and the fat;
/// the figure's bladder, drawn on the muscle's own outline; and its
/// uterus, as the anatomogram names its endometrium, below it.
const String _skin = 'UBERON_0000014';
const String _fat = 'UBERON_0001013';
const String _bladder = 'UBERON_0001255';
const String _uterus = 'UBERON_0001295';

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

DetrusorForm _form(AnatomyFigure figure) => DetrusorForm.place(
  part: figure.parts[_anatomy.uberon]!,
  anatomy: _anatomy,
  view: _view,
);

OrganArt _organ(AnatomyFigure figure) => OrganArt.forTissue(
  _anatomy,
  figure.parts[_anatomy.uberon],
  _view,
  figure: figure,
  cellName: 'Smooth muscle cells',
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
      'tone over the whole muscle; no mesh leans to it', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = DetrusorArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final DetrusorForm form = _form(figure);
      final DetrusorArt art = DetrusorArt(form, inks);
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
      final List<(Rect, Color)> marked = <(Rect, Color)>[
        for (final (Rect r, Color colour) in canvas.paths)
          if (_tealness(colour.toARGB32()) > 0.01) (r, colour),
      ];
      expect(marked, isNotEmpty, reason: figure.name);
      for (final (Rect r, Color c) in marked) {
        expect(c.toARGB32(), home.toARGB32(), reason: figure.name);
        // The whole bladder, and nothing wider.
        expect(r, form.outline.getBounds());
      }
      expect(art.fills['detrusor']!.toARGB32(), home.toARGB32());
      expect(DetrusorArt.bedOf(inks).toARGB32(), home.toARGB32());
    }
  });

  testWidgets('at the hand-over the muscle is the body’s own outline, flat '
      'in the mark, with no layer or mesh; at its stop the bladder, with no '
      'layer, the figure’s own parts round it, its uterus among them', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final AnatomyFigure figure = AnatomyFigure.female;
    final AnatomyPart part = figure.parts[_anatomy.uberon]!;
    final double real = _anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / _view);
    final Rect body = Contour(<Offset>[
      for (final Offset p in part.followed) placed(p),
    ]).toPath().getBounds();
    final OrganArt art = _organ(figure);
    expect(art.followsBody, isTrue);
    expect(art.real, closeTo(real, 1e-12));
    final _Record handed = _Record();
    art.paint(handed, inks, 1 / 390, 1 / real, detail: 0);
    expect(handed.layers, 0);
    expect(handed.meshes, 0);
    expect(<Rect>[
      for (final (Rect bounds, Color _) in handed.paths) bounds,
    ], contains(body));
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
    expect(rest.shaded, isNotEmpty);
    expect(art.outline.contains(art.site), isTrue);
    // The figure's uterus is drawn round it, outside the bladder.
    final Path around = rest.shaded.first;
    Path outlineOf(List<Offset> contour) => Path()
      ..addPolygon(<Offset>[for (final Offset p in contour) placed(p)], true);
    bool found = false;
    final double step = 5e-4 / _view;
    for (final List<Offset> contour in figure.parts[_uterus]!.contours) {
      final Path uterus = outlineOf(contour);
      final Rect box = uterus.getBounds();
      for (double y = box.top; y <= box.bottom && !found; y += step) {
        for (double x = box.left; x <= box.right && !found; x += step) {
          final Offset p = Offset(x, y);
          found =
              uterus.contains(p) &&
              !art.outline.contains(p) &&
              around.contains(p);
        }
      }
    }
    expect(found, isTrue);
    expect(<String>{_skin, _fat, _bladder}.length, 3);
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final DetrusorArt first = DetrusorArt(_form(figure), inks);
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = DetrusorArt(
        _form(figure),
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
            reason: '${figure.name}: ${a[i].$1}',
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
          reason: '${figure.name}: $r',
        );
      }
    }
  });

  test('it names the detrusor, in the mark, and the circular layer, the '
      'urachus, a ureter and the sphincter, in the quiet ink, set round '
      'it', () {
    for (final AnatomyFigure figure in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final OrganArt art = _organ(figure);
      final DetrusorForm form = _form(figure);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          'detrusor',
          'circular layer',
          'urachus',
          'ureter',
          'sphincter',
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
      // Inside the bladder the detrusor, the circular layer and the
      // sphincter alone.
      for (final OrganName n in art.names) {
        expect(
          form.contains(n.at),
          n.key == 'home' || n.key == 'circular' || n.key == 'sphincter',
          reason: '${figure.name}: ${n.word}',
        );
      }
    }
  });
}
