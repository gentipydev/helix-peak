import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/lung/lung_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/lung/lung_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['lung']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

LungForm _form([AnatomyFigure? figure, LungHome home = LungHome.alveoli]) =>
    LungForm.place(
      part: _part(figure ?? AnatomyFigure.female),
      anatomy: _anatomy,
      view: _view,
      home: home,
    );

bool _inside(List<Offset> polygon, Offset p) =>
    (Path()..addPolygon(polygon, true)).contains(p);

/// How far [p] is from the polyline [points], closed or not.
double _toLine(List<Offset> points, Offset p, {bool closed = true}) {
  double best = double.infinity;
  final int n = points.length;
  for (int i = 0; i < (closed ? n : n - 1); i++) {
    final Offset a = points[i];
    final Offset ab = points[(i + 1) % n] - a;
    final double length = ab.dx * ab.dx + ab.dy * ab.dy;
    final double t = length == 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}

Rect _bounds(List<Offset> points) => points.fold<Rect>(
  Rect.fromPoints(points.first, points.first),
  (Rect r, Offset p) => r.expandToInclude(Rect.fromPoints(p, p)),
);

double _area(List<Offset> points) {
  double sum = 0;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
}

bool _crosses(Offset a, Offset b, Offset c, Offset d) {
  double side(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  return side(a, b, c) * side(a, b, d) < 0 && side(c, d, a) * side(c, d, b) < 0;
}

/// An airway's middle line, as the form lays it, in millimetres.
List<Offset> _line(LungAirway a) => TubeCourse(
  AnatomyTube(a.course, <double>[for (final Offset _ in a.course) a.radius]),
  (Offset p) => p,
  1,
  0.5,
  bend: 0.9,
).centres;

void main() {
  test('the lungs are drawn at their real size, the left one laid on the '
      'body’s outline of it on either figure, moved little to lay the '
      'place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final LungForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      // The card's 25 cm, from the apex to the lowest point of the base,
      // and about 118 mm across.
      expect(form.box.height / form.scale, closeTo(250, 1), reason: what);
      expect(form.box.width / form.scale, closeTo(118, 2), reason: what);
      expect(form.anchorShift, lessThan(10), reason: what);
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
      // The right lung beside it, on the page's left, 25 mm shorter and
      // broader; the trachea between them.
      final Rect right = _bounds(form.rightPoints);
      expect(right.right, lessThan(form.box.left), reason: what);
      expect(right.height / form.scale, closeTo(226, 2), reason: what);
      expect(right.width, greaterThan(form.box.width), reason: what);
      final double middle = form.place(Offset.zero).dx;
      for (final Offset p in form.trachea.centres) {
        expect(p.dx, closeTo(middle, 1e-9), reason: what);
        expect(p.dx, greaterThan(right.right), reason: what);
        expect(p.dx, lessThan(form.box.left), reason: what);
      }
    }
  });

  test('the zoom goes in where GTEx samples the lung: in the left upper '
      'lobe’s lower segment, the lingula below the cardiac notch, 1 cm in '
      'from its pleura, on either figure', () {
    expect(LungForm.inUpperLobe(LungAnatomy.site), isTrue);
    expect(LungForm.pleuraDepth(LungAnatomy.site), closeTo(10, 1.5));
    // Below the cardiac notch, on the lung's mediastinal side.
    double notch = 0;
    for (final Offset p in LungAnatomy.leftOutline) {
      if (p.dy > 120 && p.dy < 200) {
        notch = math.max(notch, p.dx);
      }
    }
    expect(LungAnatomy.site.dy, greaterThan(200));
    expect(LungAnatomy.site.dx, lessThan(notch));
    for (final AnatomyFigure figure in _figures) {
      final LungForm form = _form(figure);
      expect(
        form.toMm(form.site),
        _offsetNear(LungAnatomy.site),
        reason: figure.name,
      );
    }
  });

  test('where the zoom’s cell lives is read from the Atlas’s name for it, '
      'never from the gene', () {
    for (final String alveolar in <String>[
      'Alveolar cells type 1',
      'Alveolar cells type 2',
      'Transitional alveolar cells',
      'Macrophages',
      'NK-cells (Lung)',
      'Fibroblasts',
      'Endothelial cells',
    ]) {
      expect(LungHome.of(alveolar), LungHome.alveoli, reason: alveolar);
    }
    for (final String airway in <String>[
      'Respiratory ciliated cells',
      'Respiratory deuterosomal cells',
      'Respiratory basal cells',
      'Respiratory secretory cells',
      'Respiratory ionocytes',
      'Club cells',
      'Ciliated cells',
      'Neuroendocrine cells',
      'Tuft cells',
      'Submucosal glandular cells',
      'Smooth muscle cells',
    ]) {
      expect(LungHome.of(airway), LungHome.airways, reason: airway);
    }
    expect(LungHome.of('Mesothelial cells'), LungHome.pleura);
    expect(LungHome.of(null), LungHome.alveoli);
  });

  test('its outlines are simple, the fissure crosses the left one from its '
      'costal border to its base, and its lobes are the two sides of it', () {
    for (final List<Offset> outline in <List<Offset>>[LungForm.outlineMm]) {
      final int n = outline.length;
      for (int i = 0; i < n; i++) {
        for (int j = i + 2; j < n; j++) {
          if (i == 0 && j == n - 1) {
            continue;
          }
          expect(
            _crosses(
              outline[i],
              outline[(i + 1) % n],
              outline[j],
              outline[(j + 1) % n],
            ),
            isFalse,
            reason: 'edges $i and $j',
          );
        }
      }
    }
    final List<Offset> fissure = LungForm.fissureMm;
    expect(_inside(LungForm.outlineMm, fissure.first), isFalse);
    expect(_inside(LungForm.outlineMm, fissure.last), isFalse);
    expect(fissure.first.dy, lessThan(fissure.last.dy));
    expect(fissure.first.dx, greaterThan(fissure.last.dx));
    // The apex and the lingula in the upper lobe, the costophrenic angle in
    // the lower.
    expect(LungForm.inUpperLobe(const Offset(40, 8)), isTrue);
    expect(LungForm.inUpperLobe(const Offset(34, 228)), isTrue);
    expect(LungForm.inUpperLobe(const Offset(118, 240)), isFalse);
    expect(LungForm.inUpperLobe(const Offset(110, 210)), isFalse);
  });

  test('its airways run inside it and taper as they branch, those the rule '
      'lays in the upper lobe, clear of the pleura, the fissure and the '
      'site; the arteries run beside them and the veins between them', () {
    final List<LungAirway> airways = LungForm.airwaysMm;
    final int hand = LungAnatomy.airways.length;
    expect(airways.length, greaterThan(hand + 10));
    for (int k = 0; k < airways.length; k++) {
      final LungAirway a = airways[k];
      final String what = 'airway $k, generation ${a.generation}';
      expect(
        a.generation,
        inInclusiveRange(1, LungAnatomy.deepest),
        reason: what,
      );
      for (final Offset p in _line(a)) {
        expect(_inside(LungForm.outlineMm, p), isTrue, reason: what);
      }
      if (k < hand) {
        continue;
      }
      // Those the rule lays: narrower than every segmental bronchus.
      expect(a.radius, lessThan(2.6), reason: what);
      final List<Offset> line = _line(a);
      for (final Offset p in line.skip(2)) {
        expect(LungForm.inUpperLobe(p), isTrue, reason: what);
        expect(
          _toLine(LungForm.outlineMm, p),
          greaterThan(a.radius + LungAnatomy.edgeClear - 0.6),
          reason: what,
        );
        expect(
          _toLine(LungForm.fissureMm, p, closed: false),
          greaterThan(a.radius + LungAnatomy.fissureClear - 0.6),
          reason: what,
        );
        expect(
          (p - LungAnatomy.site).distance,
          greaterThan(a.radius + LungAnatomy.siteClear - 0.6),
          reason: what,
        );
      }
    }
    // Calibres by generation, as Weibel's.
    for (int g = 1; g < LungAnatomy.deepest; g++) {
      final Iterable<double> these = <double>[
        for (final LungAirway a in airways)
          if (a.generation == g) a.radius,
      ];
      final Iterable<double> next = <double>[
        for (final LungAirway a in airways)
          if (a.generation == g + 1) a.radius,
      ];
      if (these.isEmpty || next.isEmpty) {
        continue;
      }
      expect(
        next.reduce(math.max),
        lessThanOrEqualTo(these.reduce(math.max)),
        reason: 'generation ${g + 1}',
      );
    }
    // An artery beside every airway from the lobar bronchus on.
    expect(
      LungForm.besideMm,
      hasLength(airways.where((LungAirway a) => a.generation >= 2).length),
    );
    // The veins clear of every airway and artery, inside the lung.
    expect(LungForm.veinsMm, isNotEmpty);
    for (final (Offset c, double r) in LungForm.veinsMm) {
      expect(_inside(LungForm.outlineMm, c), isTrue);
      for (final LungAirway a in airways) {
        expect(
          _toLine(_line(a), c, closed: false),
          greaterThan(r + a.radius),
          reason: '$c',
        );
      }
      for (final (List<Offset> line, double a) in LungForm.besideMm) {
        expect(
          _toLine(line, c, closed: false),
          greaterThan(r + a),
          reason: '$c',
        );
      }
    }
  });

  test('its lobules’ septa lie inside the left lung, marked from under the '
      'pleura in', () {
    final List<(Offset, Offset, double)> septa = LungForm.septaMm;
    expect(septa.length, greaterThan(100));
    for (final (Offset a, Offset b, double depth) in septa) {
      final Offset middle = Offset.lerp(a, b, 0.5)!;
      expect(_inside(LungForm.outlineMm, middle), isTrue);
      expect(depth, greaterThanOrEqualTo(0));
      // About a lobule's side long.
      expect((b - a).distance, lessThan(LungAnatomy.lobule * 1.6));
    }
  });

  test('the step from the body meets the left lung’s outline and the '
      'body’s at their apices, their costal borders, their bases’ lateral '
      'corners, their lingulas, their cardiac notches and their hila, in '
      'the same order round each', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final LungForm form = _form(figure);
      final double real = _anatomy.metres / part.extent;
      final List<Offset> body = Contour(<Offset>[
        for (final Offset p in part.followed)
          (p - part.centre) * (real / _view),
      ]).sampled(8).points;
      List<int> order(List<Offset> points) {
        final List<Offset> marks = form.marksOf(points);
        final int start = points.indexOf(marks.first);
        final List<int> round = <int>[
          for (final Offset m in marks)
            (points.indexOf(m) - start) % points.length,
        ];
        return <int>[
          for (int k = 0; k < round.length; k++)
            round.where((int r) => r < round[k]).length,
        ];
      }

      final double way = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == way
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
      expect(
        form.marksOf(form.outlinePoints).toSet(),
        hasLength(6),
        reason: figure.name,
      );
      for (final List<Offset> points in <List<Offset>>[
        form.outlinePoints,
        bodyWay,
      ]) {
        final List<Offset> marks = form.marksOf(points);
        final Rect box = _bounds(points);
        expect(marks[0].dy, closeTo(box.top, 1e-9), reason: figure.name);
        // The costal border out at the box's right; the base's corner at
        // its foot, out on its right; the lingula and the hilum on its
        // left.
        expect(marks[1].dx, greaterThan(box.right - box.width * 0.05));
        expect(marks[2].dy, greaterThan(box.bottom - box.height * 0.05));
        expect(marks[2].dx, greaterThan(box.right - box.width * 0.2));
        expect(marks[3].dx, lessThan(box.center.dx));
        expect(marks[4].dx, lessThan(box.center.dx));
        expect(
          marks[4].dy,
          closeTo(box.top + box.height * 0.65, 2 * 1e-3 / _view),
        );
        expect(marks[5].dx, lessThan(box.left + box.width * 0.2));
      }
      expect(
        _bounds(form.outlineAt(1)).width,
        closeTo(form.box.width, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test('its parts are named where they are: the home where the cell lives, '
      'the trachea, the bronchus and the pulmonary artery at the hilum, the '
      'lobes either side of the fissure, the right lung on it', () {
    for (final AnatomyFigure figure in _figures) {
      final LungForm form = _form(figure);
      Offset mm(Offset p) => form.toMm(p);
      expect(form.homeName, form.site);
      expect(LungForm.inUpperLobe(mm(form.upperLobeName)), isTrue);
      expect(LungForm.inUpperLobe(mm(form.lowerLobeName)), isFalse);
      expect(form.contains(form.lowerLobeName), isTrue);
      expect(_inside(form.rightPoints, form.rightLungName), isTrue);
      expect(form.contains(form.bronchusName), isTrue);
      expect(form.contains(form.arteryName), isTrue);
      expect(mm(form.tracheaName).dx.abs(), lessThan(1e-6));
      // The bronchi's name on the nearest airway, the pleura's on the
      // outline.
      final LungForm airways = _form(figure, LungHome.airways);
      expect(<Offset>[
        for (final LungTube a in airways.airways) ...a.course.centres,
      ], contains(airways.homeName));
      final LungForm pleura = _form(figure, LungHome.pleura);
      expect(pleura.outlinePoints, contains(pleura.homeName));
    }
  });
}

Matcher _offsetNear(Offset expected) => predicate<Offset>(
  (Offset p) => (p - expected).distance < 1e-6,
  'within a micron of $expected',
);
