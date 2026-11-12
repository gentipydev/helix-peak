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
import 'package:helixpeek/features/zoom/presentation/scenes/organs/prostate/prostate_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/prostate/prostate_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['prostate']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.prostateUpright;
final AnatomyFigure _figure = AnatomyFigure.male;
final AnatomyPart _part = _figure.parts[_anatomy.uberon]!;

/// The figure's parts never drawn round an organ, the skin and the fat;
/// the figure's seminal vesicle, which the prostate draws itself; and its
/// bladder, which lies above it.
const String _skin = 'UBERON_0000014';
const String _fat = 'UBERON_0001013';
const String _vesicle = 'UBERON_0000998';
const String _bladder = 'UBERON_0001255';

/// A cell the Atlas names for each home.
const Map<ProstateHome, String> _cells = <ProstateHome, String>{
  ProstateHome.glands: 'Prostate glandular cells',
  ProstateHome.stroma: 'Smooth muscle cells',
  ProstateHome.urethra: 'Prostatic hillock cells',
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

ProstateForm _form([ProstateHome home = ProstateHome.glands]) =>
    ProstateForm.place(part: _part, anatomy: _anatomy, view: _view, home: home);

OrganArt _organ([ProstateHome home = ProstateHome.glands]) =>
    OrganArt.forTissue(
      _anatomy,
      _part,
      _view,
      figure: _figure,
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
      'tone: its glands, its stroma or its urethra’s lining; no mesh leans '
      'to it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final Color home = ProstateArt.homeOf(inks);
    expect(home, Color.alphaBlend(inks.glow(0.42), inks.lit(0.2)));
    for (final ProstateHome where in ProstateHome.values) {
      final String what = where.name;
      final ProstateForm form = _form(where);
      final ProstateArt art = ProstateArt(form, inks);
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
      ];
      expect(marked, isNotEmpty, reason: what);
      for (final Color c in marked) {
        expect(c.toARGB32(), home.toARGB32(), reason: what);
      }
      // What it lights, by name, and only that.
      final Set<String> lit = <String>{
        for (final MapEntry<String, Color> f in art.fills.entries)
          if (f.value.toARGB32() == home.toARGB32()) f.key,
      };
      expect(lit, switch (where) {
        ProstateHome.glands => <String>{'peripheral', 'central'},
        ProstateHome.stroma => <String>{'muscle'},
        ProstateHome.urethra => <String>{'lining', 'colliculus'},
      }, reason: what);
      expect(
        ProstateArt.bedOf(inks, where).toARGB32() == home.toARGB32(),
        where == ProstateHome.glands,
        reason: what,
      );
    }
  });

  testWidgets('at the hand-over the prostate is the body’s own oval, flat '
      'in the mark, with no layer or mesh; at its stop the prostate, with '
      'no layer, the figure’s own parts round it', (WidgetTester tester) async {
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
    final _Record rest = _Record();
    art.paint(rest, inks, 1 / 390, 1);
    expect(rest.layers, 0);
    expect(rest.meshes, greaterThan(0));
    expect(rest.shaded, isNotEmpty);
    expect(art.outline.contains(art.site), isTrue);
  });

  testWidgets('the figure’s seminal vesicle, which the prostate draws above '
      'its base, is not drawn round it, and its bladder is', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final double real = _anatomy.metres / _part.extent;
    Offset placed(Offset p) => (p - _part.centre) * (real / _view);
    Path outlineOf(List<Offset> contour) => Path()
      ..addPolygon(<Offset>[for (final Offset p in contour) placed(p)], true);
    final OrganArt art = _organ();
    final _Record canvas = _Record();
    art.paint(canvas, inks, 1 / 390, 1);
    final Path around = canvas.shaded.first;
    final List<Path> others = <Path>[
      for (final MapEntry<String, AnatomyPart> other in _figure.parts.entries)
        if (!<String>{_skin, _fat, _vesicle}.contains(other.key))
          for (final List<Offset> contour in other.value.contours)
            outlineOf(contour),
    ];
    int checked = 0;
    final double step = 5e-4 / _view;
    for (final List<Offset> contour in _figure.parts[_vesicle]!.contours) {
      final Path vesicle = outlineOf(contour);
      final Rect box = vesicle.getBounds();
      for (double y = box.top; y <= box.bottom; y += step) {
        for (double x = box.left; x <= box.right; x += step) {
          final Offset p = Offset(x, y);
          if (!vesicle.contains(p) ||
              art.outline.contains(p) ||
              others.any((Path o) => o.contains(p))) {
            continue;
          }
          expect(around.contains(p), isFalse, reason: '$p');
          checked++;
        }
      }
    }
    expect(checked, greaterThan(20));
    bool found = false;
    for (final List<Offset> contour in _figure.parts[_bladder]!.contours) {
      final Path bladder = outlineOf(contour);
      final Rect box = bladder.getBounds();
      for (double y = box.top; y <= box.bottom && !found; y += step) {
        for (double x = box.left; x <= box.right && !found; x += step) {
          final Offset p = Offset(x, y);
          found = bladder.contains(p) && around.contains(p);
        }
      }
    }
    expect(found, isTrue);
  });

  testWidgets('its meshes are the same every time, each within one mesh’s '
      'indices, and its bounds hold all it draws', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    for (final ProstateHome home in ProstateHome.values) {
      final ProstateArt first = ProstateArt(_form(home), inks);
      final List<(String, Float32List, Int32List)> a = first.meshData;
      final List<(String, Float32List, Int32List)> b = ProstateArt(
        _form(home),
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

  test('it names where the zoom’s cell lives, in the mark, and the central '
      'zone, a seminal vesicle, the ejaculatory duct, the verumontanum and '
      'the urethra where it is not the home, in the quiet ink, set round '
      'it', () {
    for (final ProstateHome home in ProstateHome.values) {
      final String what = home.name;
      final OrganArt art = _organ(home);
      final ProstateForm form = _form(home);
      expect(
        <String>[for (final OrganName n in art.names) n.word],
        <String>[
          home.word,
          'central\nzone',
          'seminal vesicle',
          'ejaculatory\nduct',
          'verumontanum',
          if (home != ProstateHome.urethra) 'urethra',
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
      // Inside the prostate all but the vesicle.
      for (final OrganName n in art.names) {
        expect(
          form.contains(n.at),
          n.key != 'vesicle',
          reason: '$what: ${n.word}',
        );
      }
    }
  });
}
