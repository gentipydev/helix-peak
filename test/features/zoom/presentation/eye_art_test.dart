import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/cell_archetypes.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/eye/eye_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/eye/eye_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/eye/eye_style.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['retina']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.eyeUpright;

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

EyeForm _form() => EyeForm(length: _anatomy.metres / _view, view: _view);

OrganArt _organ(CellShape cell, {AnatomyFigure? figure}) {
  final AnatomyFigure body = figure ?? AnatomyFigure.female;
  return OrganArt.forTissue(
    _anatomy,
    body.parts[_anatomy.uberon],
    _view,
    figure: body,
    shape: cell,
  );
}

/// Kinds of cell a path may land in in the eye, as the Atlas's cells of
/// the retina are drawn: its neurons (rods and cones, bipolar, amacrine
/// and ganglion cells), Müller glia, the pigment epithelium's cells, and
/// the endothelium of its vessels, which lives in no part of its own.
const List<CellShape> _cells = <CellShape>[
  CellShape.neuron,
  CellShape.glial,
  CellShape.epithelial,
  CellShape.endothelial,
];

/// How far a colour leans to the mark, a teal: green over red where blue
/// is below green, else green over the other two. Every neutral of the
/// app's, and every mix of them, comes out at about nothing or below; so
/// do the red the vessels are drawn in and the honey of the nerve.
double _tealness(int colour) {
  final double r = (colour >> 16 & 255) / 255;
  final double g = (colour >> 8 & 255) / 255;
  final double b = (colour & 255) / 255;
  return b < g ? g - r : 2 * g - r - b;
}

/// A canvas that keeps what is drawn on it: the paths, each its bounds,
/// filled or stroked, and its colour; the sets of points; and how many
/// layers and meshes.
class _Record implements Canvas {
  final List<(Rect, PaintingStyle, Color)> paths =
      <(Rect, PaintingStyle, Color)>[];
  final List<Float32List> points = <Float32List>[];
  int layers = 0;
  int meshes = 0;

  @override
  void drawPath(Path path, Paint paint) =>
      paths.add((path.getBounds(), paint.style, paint.color));

  @override
  void saveLayer(Rect? bounds, Paint paint) => layers++;

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      meshes++;

  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) =>
      this.points.add(points);

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('the mark shows only where the zoom’s cell lives: the retina, '
      'flat, or for a pigment epithelial cell the pigment epithelium under '
      'it; never the coats, the lens, the nerve, the recti or the vessels', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final EyeForm form = _form();
    for (final CellShape cell in _cells) {
      final EyeHome home = EyeHome.of(cell);
      expect(
        home,
        cell == CellShape.epithelial
            ? EyeHome.pigmentEpithelium
            : EyeHome.retina,
      );
      // The meshes: the coats, the vitreous, the ciliary body, the iris,
      // the lens, the nerve and its sheath, the recti and the vessels.
      final Map<String, int> teal = <String, int>{};
      for (final (String part, Float32List _, Int32List colours) in EyeArt(
        form,
        inks,
        home: home,
      ).meshData) {
        int leaning = 0;
        for (final int colour in colours) {
          if (colour >>> 24 != 0 && _tealness(colour) > 0.01) {
            leaning++;
          }
        }
        teal[part] = (teal[part] ?? 0) + leaning;
      }
      expect(
        teal.keys,
        containsAll(<String>[
          'vitreous',
          'sclera',
          'choroid',
          'ciliary',
          'iris',
          'lens',
          'sheath',
          'nerve',
          'recti',
          'vessels',
        ]),
      );
      for (final MapEntry<String, int> part in teal.entries) {
        expect(part.value, 0, reason: '${cell.name}: ${part.key}');
      }
      // The paths in the mark: for a cell of the retina its two halves,
      // filled flat, and their halo; for a pigment epithelial cell the
      // pigment epithelium under them, and its halo, the retina plain.
      final _Record canvas = _Record();
      final double line = form.mm(0.1);
      EyeArt(form, inks, home: home)
        ..prepare()
        ..paint(canvas, line);
      final List<(Rect, PaintingStyle, Color)> marked =
          <(Rect, PaintingStyle, Color)>[
            for (final (Rect, PaintingStyle, Color) drawn in canvas.paths)
              if (_tealness(drawn.$3.toARGB32()) > 0.01) drawn,
          ];
      final int fills = marked
          .where(((Rect, PaintingStyle, Color) d) => d.$2 == PaintingStyle.fill)
          .length;
      final int strokes = marked.length - fills;
      if (home == EyeHome.retina) {
        expect(fills, 2, reason: cell.name);
        expect(strokes, 2, reason: cell.name);
      } else {
        expect(fills, 0, reason: cell.name);
        expect(strokes, 4, reason: cell.name);
      }
      // All of it within the globe, its halo's breadth aside.
      final Rect globe = form.outline.getBounds().inflate(EyeStyle.halo * line);
      for (final (Rect bounds, PaintingStyle _, Color _) in marked) {
        expect(globe.contains(bounds.topLeft), isTrue, reason: '$bounds');
        expect(globe.contains(bounds.bottomRight), isTrue, reason: '$bounds');
      }
      expect(canvas.points, isEmpty, reason: cell.name);
    }
  });

  testWidgets('at rest it draws in no layer of its own, every mesh built '
      'ahead, the same every time and each within one mesh’s indices', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final EyeArt art = EyeArt(_form(), inks, home: EyeHome.retina)..prepare();
    final _Record first = _Record();
    art.paint(first, 0.01);
    final _Record again = _Record();
    art.paint(again, 0.01);
    expect(first.layers, 0);
    expect(first.meshes, greaterThan(10));
    expect(again.meshes, first.meshes);
    final List<(String, Float32List, Int32List)> a = art.meshData;
    final List<(String, Float32List, Int32List)> b = EyeArt(
      _form(),
      inks,
      home: EyeHome.retina,
    ).meshData;
    expect(a.length, b.length);
    for (int i = 0; i < a.length; i++) {
      expect(a[i].$1, b[i].$1);
      expect(a[i].$2, b[i].$2);
      expect(a[i].$3, b[i].$3);
      expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
    }
  });

  test('the step from the body crossfades: as it begins the eye is drawn '
      'about the body’s circle of it, as large as that, on either figure', () {
    for (final AnatomyFigure body in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final AnatomyPart part = body.parts[_anatomy.uberon]!;
      final OrganArt art = _organ(CellShape.neuron, figure: body);
      expect(art.followsBody, isFalse);
      final double real = _anatomy.metres / part.extent;
      expect(art.real, closeTo(real, 1e-12));
      // The body's circle, in the organ's units, where the organ's scene
      // draws the eye as large as the body drew it.
      final Rect circle = Contour(<Offset>[
        for (final Offset p in part.followed) (p - part.centre) / _view,
      ]).toPath().getBounds();
      final Rect outline = art.outline.getBounds();
      final Rect handed = Rect.fromLTRB(
        outline.left / real,
        outline.top / real,
        outline.right / real,
        outline.bottom / real,
      );
      expect(handed.width, closeTo(circle.width, 0.02 * circle.width));
      expect(handed.height, closeTo(circle.height, 0.02 * circle.height));
      expect(
        (handed.center - circle.center).distance,
        lessThan(0.02 * circle.width),
        reason: body.name,
      );
    }
  });

  test('it names the cornea, the lens and the optic nerve, and where a '
      'pigment epithelial cell lives, at the place its tissue is sampled; '
      'never the retina the card names; no more', () {
    for (final CellShape cell in _cells) {
      final OrganArt art = _organ(cell);
      final bool pigment = cell == CellShape.epithelial;
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          if (pigment) 'pigment epithelium',
          'cornea',
          'lens',
          'optic nerve',
        ],
      );
      if (pigment) {
        expect(art.names.first.home, isTrue);
        expect(art.names.first.at, art.site);
      }
      expect(
        art.names.skip(pigment ? 1 : 0).every((OrganName n) => !n.home),
        isTrue,
      );
      expect(art.outline.contains(art.site), isTrue);
      expect(art.named, isNotEmpty);
    }
  });
}
