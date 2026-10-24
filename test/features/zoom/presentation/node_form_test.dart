import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/lymph_node/node_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/lymph_node/node_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['lymphoid tissue']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

NodeForm _form([NodeHome home = NodeHome.sinuses]) =>
    NodeForm(view: _view, home: home);

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

bool _inside(List<Offset> polygon, Offset p) =>
    (Path()..addPolygon(polygon, true)).contains(p);

/// How far [p] is from the closed polygon or open line [points].
double _distanceTo(List<Offset> points, Offset p, {bool closed = true}) {
  double best = double.infinity;
  final int n = points.length;
  for (int i = 0; i < (closed ? n : n - 1); i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final Offset ab = b - a;
    final double length = _dot(ab, ab);
    final double t = length == 0
        ? 0
        : (_dot(p - a, ab) / length).clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}

void main() {
  test('the node is drawn at its real size, a normal node’s: under 10 mm '
      'across its short axis, its long axis more than twice that', () {
    final NodeForm form = _form();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    final double long = form.box.width / form.scale;
    final double short = form.box.height / form.scale;
    expect(long, closeTo(NodeAnatomy.length, 0.1));
    expect(short, lessThan(10));
    expect(long / short, greaterThan(2));
    // About 2 cm, as its card says.
    expect(long, inInclusiveRange(15, 25));
    expect(_anatomy.metres, 0.02);
  });

  test('its hilum is a slight depression on one side, the cortex missing '
      'there and the medulla reaching the surface', () {
    final NodeForm form = _form();
    // The notch, under the middle of its foot.
    final double foot = form.outlinePoints.first.dy / form.scale;
    expect(foot, closeTo(NodeAnatomy.width / 2 - NodeAnatomy.hilumDepth, 0.1));
    final (int from, int to) = NodeForm.runIndices;
    expect(form.atHilum(0), isTrue);
    expect(form.atHilum(from), isFalse);
    expect(form.atHilum(to), isFalse);
    expect(form.atHilum(to + 1), isTrue);
    // No band of the cortex reaches the hilum's middle.
    expect(
      _distanceTo(form.cortexBand, form.outlinePoints.first) / form.scale,
      greaterThan(1),
    );
  });

  test('the bands lie under the capsule in order, the follicles in the '
      'cortex, the cords and the sinuses in the medulla, the trabeculae '
      'running a third of the way in at most', () {
    final NodeForm form = _form();
    for (final NodeFollicle f in form.follicles) {
      expect(form.contains(f.centre), isTrue);
      expect(_inside(form.cortexBand, f.centre), isTrue);
      final Offset? g = f.germ;
      if (g != null) {
        expect((g - f.centre).distance + f.germRadius, lessThan(f.radius));
      }
    }
    // A germinal centre in every other follicle.
    expect(
      form.follicles.where((NodeFollicle f) => f.germ != null).length,
      (NodeAnatomy.follicles + 1) ~/ 2,
    );
    for (final List<Offset> line in <List<Offset>>[
      ...form.cords,
      ...form.medullarySinuses,
    ]) {
      for (final Offset p in line.skip(2)) {
        expect(form.contains(p), isTrue);
        expect(_inside(form.cortexBand, p), isFalse);
      }
    }
    const double half = NodeAnatomy.width / 2;
    for (final (Offset a, Offset b) in form.trabeculae) {
      expect(_distanceTo(form.outlinePoints, a), lessThan(form.mm(0.05)));
      expect((b - a).distance / form.scale, lessThanOrEqualTo(half / 3 + 0.1));
    }
  });

  test('the afferents come in all round its convex side, fading out toward '
      'where they come from; the efferent, the artery and the vein leave at '
      'the hilum, cut short', () {
    final NodeForm form = _form();
    for (final TubeCourse t in form.afferents) {
      expect(form.contains(t.centres.first), isFalse);
      expect(
        _distanceTo(form.outlinePoints, t.centres.last) / form.scale,
        lessThan(0.6),
      );
      expect(t.shown.first, lessThan(0.01));
      expect(t.centres.last.dy, lessThan(form.mm(2)));
    }
    final Offset hilum = form.outlinePoints.first;
    for (final TubeCourse t in <TubeCourse>[
      form.efferent,
      form.artery,
      form.vein,
    ]) {
      expect((t.centres.first - hilum).distance / form.scale, lessThan(2.5));
      expect(t.centres.last.dy, greaterThan(hilum.dy));
      expect(t.cutEnd, isTrue);
    }
  });

  test('the zoom goes in through the subcapsular sinus at the node’s '
      'crown', () {
    final NodeForm form = _form();
    expect(form.contains(form.site), isTrue);
    final double depth =
        _distanceTo(form.outlinePoints, form.site) / form.scale;
    expect(depth, lessThan(NodeAnatomy.sinus));
    expect(form.site.dy, lessThan(0));
  });

  test('the home is told by the Atlas’s name for the cell', () {
    expect(NodeHome.of('Lymphatic endothelial cells'), NodeHome.sinuses);
    expect(NodeHome.of('B-cells'), NodeHome.follicles);
    expect(NodeHome.of('Germinal center B-cells'), NodeHome.follicles);
    expect(NodeHome.of('Follicular dendritic cells'), NodeHome.follicles);
    expect(NodeHome.of('T-cells'), NodeHome.paracortex);
    expect(NodeHome.of('Dendritic cells'), NodeHome.paracortex);
    expect(NodeHome.of('Plasma cells'), NodeHome.cords);
    expect(NodeHome.of('Fibroblasts'), NodeHome.cortex);
    expect(NodeHome.of(null), NodeHome.cortex);
  });
}
