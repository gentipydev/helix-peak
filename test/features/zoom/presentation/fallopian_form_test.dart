import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/fallopian_tube/fallopian_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/fallopian_tube/fallopian_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['fallopian tube']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

AnatomyPart _part() => AnatomyFigure.female.parts[_anatomy.uberon]!;

FallopianForm _form([FallopianHome home = FallopianHome.mucosa]) =>
    FallopianForm.place(
      part: _part(),
      anatomy: _anatomy,
      view: _view,
      figure: AnatomyFigure.female,
      home: home,
    );

bool _inside(List<Offset> polygon, Offset p) =>
    (Path()..addPolygon(polygon, true)).contains(p);

/// How far [p] is from the closed polygon [points].
double _distanceTo(List<Offset> points, Offset p) {
  double best = double.infinity;
  final int n = points.length;
  for (int i = 0; i < n; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final Offset ab = b - a;
    final double length = ab.dx * ab.dx + ab.dy * ab.dy;
    final double t = length == 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}

double _length(List<Offset> line) {
  double sum = 0;
  for (int i = 1; i < line.length; i++) {
    sum += (line[i] - line[i - 1]).distance;
  }
  return sum;
}

void main() {
  test('the tube is drawn at its real size, about 10 cm long, its isthmus '
      'the medial third, laid on the body’s outline of it, the place it is '
      'gone into on the place the body goes in, in its lumen', () {
    final FallopianForm form = _form();
    final AnatomyPart part = _part();
    expect(form.mm(1), closeTo(1e-3 / _view, 1e-15));
    // About 10 cm (Gray 1918), the card's 11.
    final double length = form.tube.arc.last / form.scale;
    expect(length, inInclusiveRange(100, 115));
    final double isthmus =
        form.tube.arc[form.rowOf(FallopianAnatomy.isthmusEnd)] / form.scale;
    expect(isthmus / length, closeTo(1 / 3, 0.05));
    // The body's outline at the share it is drawn at, and its site.
    final double real = FallopianForm.realOf(_anatomy, part);
    expect(
      real,
      closeTo(
        _anatomy.metres / part.extent * FallopianAnatomy.diagramShare,
        1e-12,
      ),
    );
    final Offset site = (part.site - part.centre) * (real / _view);
    expect((form.site - site).distance, lessThan(1e-9));
    expect(form.contains(form.site), isTrue);
    expect(_inside(form.lumen, form.site), isTrue);
    expect(form.flip, 1);
  });

  test('its isthmus is constricted and its ampulla dilated, the wall thick '
      'round the one and thin round the other; the mucosa’s folds far more '
      'in the ampulla than in the isthmus', () {
    final FallopianForm form = _form();
    final TubeCourse t = form.tube;
    final int isthmus = form.rowOf(2);
    final int ampulla = form.rowOf(8);
    expect(t.radius[ampulla], greaterThan(t.radius[isthmus] * 1.8));
    expect(form.wallAt(isthmus), greaterThan(form.wallAt(ampulla)));
    int foldsAt(int row) {
      final Offset c = t.centres[row];
      return form.folds
          .where(
            (List<Offset> f) =>
                f.any((Offset p) => (p - c).distance < t.radius[row] * 1.05),
          )
          .length;
    }

    expect(foldsAt(isthmus), lessThanOrEqualTo(3));
    expect(foldsAt(ampulla), greaterThanOrEqualTo(FallopianAnatomy.folds - 1));
  });

  test('its fimbriae ring the ostium, the ovarian fimbria the longest, '
      'reaching toward the ovary; its artery runs along the mesosalpinx '
      'under it', () {
    final FallopianForm form = _form();
    final Offset ostium = form.tube.centres.last;
    final double rim = form.tube.radius.last;
    double lengthOf(TubeCourse f) => _length(f.centres);
    for (final TubeCourse f in form.fimbriae) {
      expect((f.centres.first - ostium).distance, lessThan(rim * 1.3));
    }
    final TubeCourse ovarian = form.fimbriae[FallopianAnatomy.ovarianFimbria];
    expect(
      form.fimbriae.map(lengthOf).reduce(math.max),
      closeTo(lengthOf(ovarian), 1e-9),
    );
    final List<Offset> ovary = form.ovaryOutline!;
    final Offset middle =
        ovary.reduce((Offset a, Offset b) => a + b) / ovary.length.toDouble();
    expect(
      (ovarian.centres.last - middle).distance,
      lessThan((ovarian.centres.first - middle).distance),
    );
    for (final Offset p in form.artery.centres) {
      expect(form.contains(p), isFalse);
      expect(_inside(form.mesosalpinx, p), isTrue);
    }
  });

  test('the step from the body ends on the tube’s outline', () {
    final FallopianForm form = _form();
    final List<Offset> tube = form.outlineAt(1);
    expect(tube.length, form.outlineAt(0).length);
    for (final Offset p in tube) {
      expect(_distanceTo(form.outlinePoints, p), lessThan(form.mm(0.05)));
    }
  });

  test('the ovary and the uterus are named in the figure’s own', () {
    final FallopianForm form = _form();
    expect(_inside(form.ovaryOutline!, form.ovaryName!), isTrue);
    expect(_inside(form.uterusOutline!, form.uterusName!), isTrue);
  });

  test('the home is told by the Atlas’s name for the cell', () {
    expect(
      FallopianHome.of('Fallopian tube ciliated cells'),
      FallopianHome.mucosa,
    );
    expect(
      FallopianHome.of('Fallopian tube secretory cells'),
      FallopianHome.mucosa,
    );
    expect(FallopianHome.of('Smooth muscle cells'), FallopianHome.muscularis);
    expect(FallopianHome.of(null), FallopianHome.mucosa);
  });
}
