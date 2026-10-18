import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/brain/brain_art.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/brain/brain_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organ_art.dart';
import 'package:helixpeek/features/zoom/presentation/zoom_inks.dart';

final TissueAnatomy _brain = tissueAnatomy['brain']!;
final TissueAnatomy _plexus = tissueAnatomy['choroid plexus']!;
final double _view = _brain.metres * ZoomDepth.organMargin;

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

BrainForm _form() => BrainForm(length: _brain.metres / _view, view: _view);

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

/// A canvas that keeps what is drawn on it: the circles, each its middle
/// and its colour, and how many layers and meshes.
class _Record implements Canvas {
  final List<(Offset, Color)> circles = <(Offset, Color)>[];
  int layers = 0;
  int meshes = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add((c, paint.color));

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
  testWidgets('the mark shows only where the zoom’s cell lives: the cortex’s '
      'gyri, or the choroid plexus in the ventricles; never the cut, the '
      'cerebellum or the arteries', (WidgetTester tester) async {
    final ZoomInks inks = await _inks(tester);
    final BrainForm form = _form();
    for (final BrainHome home in BrainHome.values) {
      final Map<String, (int, int)> teal = <String, (int, int)>{};
      for (final (String part, Float32List _, Int32List colours) in BrainArt(
        form,
        inks,
        home: home,
      ).meshData) {
        int leaning = 0;
        int drawn = 0;
        for (final int colour in colours) {
          if (colour >>> 24 == 0) {
            continue;
          }
          drawn++;
          if (_tealness(colour) > 0.01) {
            leaning++;
          }
        }
        final (int a, int b) = teal[part] ?? (0, 0);
        teal[part] = (a + leaning, b + drawn);
      }
      for (final MapEntry<String, (int, int)> part in teal.entries) {
        final String what = '${home.name}: ${part.key}';
        if (home == BrainHome.cortex && part.key == 'face') {
          // The gyri, every point of them drawn.
          expect(part.value.$1, part.value.$2, reason: what);
        } else {
          expect(part.value.$1, 0, reason: what);
        }
      }
      // What else is drawn in the mark: the plexus, for its own cells, in
      // the ventricles, the lateral seen through the window.
      final _Record canvas = _Record();
      BrainArt(form, inks, home: home).paint(canvas, form.mm(0.7));
      final List<(Offset, Color)> marked = <(Offset, Color)>[
        for (final (Offset, Color) circle in canvas.circles)
          if (_tealness(circle.$2.toARGB32()) > 0.01) circle,
      ];
      if (home == BrainHome.cortex) {
        expect(marked, isEmpty);
      } else {
        expect(marked, isNotEmpty);
        for (final (Offset at, Color _) in marked) {
          expect(
            form.window.contains(at) ||
                form.deep.contains(at) ||
                form.fourthVentricle.contains(at),
            isTrue,
            reason: 'at ${form.toMm(at)} mm',
          );
        }
      }
    }
  });

  testWidgets('at rest it draws in no layer of its own, every mesh built '
      'ahead, the same every time and each within one mesh’s indices', (
    WidgetTester tester,
  ) async {
    final ZoomInks inks = await _inks(tester);
    final BrainArt art = BrainArt(_form(), inks, home: BrainHome.plexus)
      ..prepare();
    final _Record first = _Record();
    art.paint(first, 0.01);
    final _Record again = _Record();
    art.paint(again, 0.01);
    expect(first.layers, 0);
    expect(first.meshes, greaterThan(BrainForm.meshed.length));
    expect(again.meshes, first.meshes);
    final List<(String, Float32List, Int32List)> a = art.meshData;
    final List<(String, Float32List, Int32List)> b = BrainArt(
      _form(),
      inks,
      home: BrainHome.plexus,
    ).meshData;
    expect(a.length, b.length);
    for (int i = 0; i < a.length; i++) {
      expect(a[i].$1, b[i].$1);
      expect(a[i].$2, b[i].$2);
      expect(a[i].$3, b[i].$3);
      expect(a[i].$2.length ~/ 2, lessThanOrEqualTo(65000), reason: a[i].$1);
    }
  });

  test('it names the cortex for a cell of the cortex, never the plexus the '
      'card names, and its five main parts round it for both', () {
    const List<String> landmarks = <String>[
      'corpus callosum',
      'thalamus',
      'hypothalamus',
      'cerebellum',
      'brainstem',
    ];
    final OrganArt cortex = OrganArt.forTissue(_brain, null, _view);
    expect(
      <String>[for (final OrganName n in cortex.names) n.word],
      <String>['cortex', ...landmarks],
    );
    expect(cortex.names.first.home, isTrue);
    expect(cortex.names.first.at, cortex.site);
    final OrganArt plexus = OrganArt.forTissue(_plexus, null, _view);
    expect(<String>[for (final OrganName n in plexus.names) n.word], landmarks);
    expect(plexus.names.every((OrganName n) => !n.home), isTrue);
    // Each named where it is drawn, and the names set round all of it.
    for (final OrganArt art in <OrganArt>[cortex, plexus]) {
      for (final OrganName name in art.names) {
        expect(art.outline.contains(name.at), isTrue, reason: name.word);
      }
      expect(art.named, isNotEmpty);
    }
  });
}
