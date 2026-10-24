import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/adipose/adipose_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/adipose/adipose_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/adipose/adipose_form.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _anatomy = tissueAnatomy['adipose tissue']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.adiposeUpright;

AdiposeForm _form() => AdiposeForm(width: _anatomy.metres / _view, view: _view);

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

/// A canvas that keeps what is drawn on it: each shape's bounds and colour.
class _Record implements Canvas {
  final List<(Rect, Color)> shapes = <(Rect, Color)>[];

  @override
  void drawPath(Path path, Paint paint) =>
      shapes.add((path.getBounds(), paint.color));

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      shapes.add((Rect.fromCircle(center: c, radius: radius), paint.color));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      shapes.add((Rect.fromPoints(p1, p2), paint.color));

  // Everything else it draws is none of these.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

bool _same(Rect a, Rect b) =>
    (a.left - b.left).abs() < 1e-6 &&
    (a.top - b.top).abs() < 1e-6 &&
    (a.right - b.right).abs() < 1e-6 &&
    (a.bottom - b.bottom).abs() < 1e-6;

void main() {
  test('its card gives the fat’s thickness, as women of normal weight have '
      'it at the abdomen, and the block is 4 cm across', () {
    expect(_anatomy.thickness, 0.01748);
    expect(_anatomy.metres, 0.04);
    expect(_anatomy.thickness! * 1e3, closeTo(AdiposeAnatomy.fat, 1e-9));
    expect(_anatomy.metres * 1e3, AdiposeAnatomy.width);
  });

  testWidgets('the mark shows only the fat, where the zoom’s cell lives, '
      'one flat tone in both its layers on both cuts; nothing else leans to '
      'it', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final AdiposeForm form = _form();
    final AdiposeArt art = AdiposeArt(form, inks);
    final Color home = Color.alphaBlend(inks.glow(0.42), inks.lit(0.2));
    expect(art.homeTone, home);
    for (final MapEntry<String, Color> fill in art.fills.entries) {
      if (fill.key != 'home') {
        expect(
          _tealness(fill.value.toARGB32()),
          lessThan(0.01),
          reason: fill.key,
        );
      }
    }
    final _Record canvas = _Record();
    art.paint(canvas, form.mm(0.05));
    final List<Rect> inMark = <Rect>[
      for (final (Rect r, Color c) in canvas.shapes)
        if (c.toARGB32() == home.toARGB32()) r,
    ];
    for (final (Rect r, Color c) in canvas.shapes) {
      if (c.toARGB32() != home.toARGB32() && c.a > 0) {
        expect(_tealness(c.toARGB32()), lessThan(0.01), reason: '$r in $c');
      }
    }
    final List<Rect> expected = <Rect>[
      form.superficial.getBounds(),
      form.deep.getBounds(),
      form.sideSuperficial.getBounds(),
      form.sideDeep.getBounds(),
    ];
    expect(inMark, hasLength(expected.length));
    for (final Rect r in expected) {
      expect(inMark.any((Rect m) => _same(m, r)), isTrue, reason: '$r');
    }
  });

  test('it names the fat where the zoom’s cell lives, in the mark, and a '
      'septum, the membranous layer, the deep fat and the rectus, each in '
      'a column', () {
    for (final String? cell in <String?>[
      'Adipocytes (Subcutaneous)',
      'Adipocytes (Visceral)',
      'Fibroblasts',
      null,
    ]) {
      final OrganArt organ = OrganArt.forTissue(
        _anatomy,
        null,
        _view,
        cellName: cell,
      );
      expect(
        <String>[for (final OrganName name in organ.names) name.word],
        <String>[
          'fat\nlobules',
          'septum',
          'Scarpa’s\nfascia',
          'deep fat',
          'rectus',
        ],
      );
      expect(
        <bool>[for (final OrganName name in organ.names) name.home],
        <bool>[true, false, false, false, false],
      );
      expect(organ.columns.keys.toSet(), <String>{
        for (final OrganName name in organ.names) name.key,
      });
      expect(organ.outline.contains(organ.site), isTrue);
      expect(organ.followsBody, isFalse);
    }
  });

  testWidgets('it builds what it draws ahead of its first frame, and what '
      'it covers holds every shape', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final AdiposeForm form = _form();
    final AdiposeArt art = AdiposeArt(form, inks)..prepare();
    final Rect bounds = art.bounds.inflate(1e-9);
    final _Record canvas = _Record();
    art.paint(canvas, form.mm(0.05));
    expect(canvas.shapes, isNotEmpty);
    for (final (Rect r, Color _) in canvas.shapes) {
      expect(
        bounds.contains(r.topLeft) && bounds.contains(r.bottomRight),
        isTrue,
        reason: '$r',
      );
    }
  });
}
