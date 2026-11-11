import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/contour.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/gallbladder/gallbladder_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/gallbladder/gallbladder_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['gallbladder']!;

/// The organ's view, framed by its width: the form is the same at any.
final double _view = _anatomy.metres * ZoomDepth.organMargin;

final List<AnatomyFigure> _figures = <AnatomyFigure>[
  AnatomyFigure.female,
  AnatomyFigure.male,
];

AnatomyPart _part(AnatomyFigure figure) => figure.parts[_anatomy.uberon]!;

GallbladderForm _form([AnatomyFigure? figure, bool withFigure = true]) =>
    GallbladderForm.place(
      part: _part(figure ?? AnatomyFigure.female),
      anatomy: _anatomy,
      view: _view,
      figure: withFigure ? (figure ?? AnatomyFigure.female) : null,
    );

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

double _length(List<Offset> line) {
  double sum = 0;
  for (int i = 1; i < line.length; i++) {
    sum += (line[i] - line[i - 1]).distance;
  }
  return sum;
}

void main() {
  test('the gallbladder is drawn at its real size, laid on the body’s '
      'outline of it on either figure, moved a few millimetres at most to '
      'lay the place it is gone into on the place the body goes in', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final AnatomyPart part = _part(figure);
      final GallbladderForm form = _form(figure);
      expect(form.mm(1), closeTo(1e-3 / _view, 1e-15), reason: what);
      // The card's 9 cm, fundus to neck, across the screen.
      expect(form.box.width / form.scale, closeTo(90, 1), reason: what);
      expect(form.box.height / form.scale, closeTo(41.7, 1), reason: what);
      expect(form.anchorShift, lessThan(5), reason: what);
      final Rect body = _bounds(form.outlineAt(0));
      for (final double edge in <double>[
        body.left - form.box.left,
        body.right - form.box.right,
      ]) {
        expect((edge / form.scale).abs(), lessThan(6), reason: what);
      }
      // Where the body goes in, which a gallbladder that follows the body
      // keeps.
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
    }
  });

  test('the zoom goes into its mucosa, in its body toward the fundus, well '
      'clear of its wall and of the neck, on either figure', () {
    for (final AnatomyFigure figure in _figures) {
      final String what = figure.name;
      final GallbladderForm form = _form(figure);
      final Offset site = form.toMm(form.site);
      expect(GallbladderForm.clearOfWall(site), greaterThan(10), reason: what);
      expect(GallbladderForm.pastNeck(site), lessThan(-25), reason: what);
      final double across = (form.site.dx - form.box.left) / form.box.width;
      expect(across, inInclusiveRange(0.25, 0.45), reason: what);
    }
  });

  test('it is as long and as broad as it is measured, its wall under 3 mm '
      'and thinning down its neck, the cystic duct as wide and its folds as '
      'many as they are measured', () {
    // 7 to 10 cm long (Gray 1918); 2.5 cm broad (Gray), under 4 cm on
    // ultrasound (Lucius et al. 2025).
    expect(GallbladderAnatomy.length, inInclusiveRange(70, 100));
    final double broadest = 2 * GallbladderAnatomy.half.reduce(math.max);
    expect(broadest, inInclusiveRange(25, 40));
    // Broadest toward the fundus: pear-shaped.
    final int at = GallbladderAnatomy.half.indexOf(broadest / 2);
    expect(at, lessThan(GallbladderAnatomy.neckFrom));
    // Under 3 mm (Lucius et al. 2025), thinning down the neck.
    const List<double> wall = GallbladderAnatomy.wall;
    for (int i = 0; i < wall.length; i++) {
      expect(wall[i], inInclusiveRange(0.8, 3), reason: '$i');
      if (i > 0) {
        expect(wall[i], lessThanOrEqualTo(wall[i - 1]), reason: '$i');
      }
    }
    expect(GallbladderForm.wallAt(GallbladderAnatomy.site), closeTo(2, 0.05));
    // The cystic duct 4.21 mm across (Plutecki et al. 2026), about 4 cm
    // long (Gray), laid open from the neck's end; five to twelve folds
    // (Gray).
    expect(2 * GallbladderAnatomy.cysticLumen, closeTo(4.21, 0.1));
    expect(_length(GallbladderAnatomy.cysticDuct), inInclusiveRange(28, 45));
    expect(GallbladderAnatomy.cysticFolds, inInclusiveRange(5, 12));
    expect(
      GallbladderForm.cysticFoldsMm,
      hasLength(GallbladderAnatomy.cysticFolds),
    );
    // The bile duct 3.1 to 4.4 mm across (Hela and Maitra 2025); the
    // cystic artery over 1 mm (Triantafyllou et al. 2025).
    for (final double r in GallbladderAnatomy.bileDuct.radii) {
      expect(2 * r, inInclusiveRange(3.1, 4.4));
    }
    for (final double r in GallbladderAnatomy.cysticArtery.radii) {
      expect(2 * r, greaterThanOrEqualTo(1.2));
    }
  });

  test('the wall’s coats nest from the serosa in, each inside the one '
      'before', () {
    final GallbladderForm form = _form();
    final List<List<Offset>> edges = <List<Offset>>[
      form.outlinePoints,
      ...form.coats,
    ];
    for (int k = 1; k < edges.length; k++) {
      final Path outer = Path()..addPolygon(edges[k - 1], true);
      int outside = 0;
      for (int i = 0; i < edges[k].length; i += 3) {
        if (!outer.contains(edges[k][i])) {
          outside++;
        }
      }
      expect(outside, 0, reason: 'coat $k');
      expect(
        _area(edges[k]).abs(),
        lessThan(_area(edges[k - 1]).abs()),
        reason: 'coat $k',
      );
    }
  });

  test('the honeycomb’s meshes are about 2 mm across, in the mucosa, up to '
      'the neck, where the oblique folds take over; the cystic duct’s folds '
      'lie across its lumen', () {
    final List<(Offset, Offset)> edges = GallbladderForm.meshEdgesMm;
    expect(edges.length, greaterThan(800));
    double total = 0;
    for (final (Offset a, Offset b) in edges) {
      total += (b - a).distance;
      final Offset middle = Offset.lerp(a, b, 0.5)!;
      expect(GallbladderForm.pastNeck(middle), lessThan(0));
      expect(
        GallbladderForm.clearOfWall(middle),
        greaterThan(-GallbladderAnatomy.mesh),
      );
    }
    // A packed hexagon's side, for meshes 2 mm apart, is 2 / √3 mm.
    expect(
      total / edges.length,
      closeTo(GallbladderAnatomy.mesh / math.sqrt(3), 0.35),
    );
    // Its edges shared, not drawn twice.
    final Set<String> seen = <String>{};
    for (final (Offset a, Offset b) in edges) {
      String key(Offset p) =>
          '${p.dx.toStringAsFixed(2)},${p.dy.toStringAsFixed(2)}';
      final List<String> ends = <String>[key(a), key(b)]..sort();
      expect(seen.add(ends.join(' ')), isTrue);
    }
    expect(
      GallbladderForm.neckFoldsMm,
      hasLength(GallbladderAnatomy.neckFolds.length),
    );
    for (final List<Offset> fold in GallbladderForm.neckFoldsMm) {
      final Offset middle = fold[fold.length ~/ 2];
      expect(GallbladderForm.pastNeck(middle), greaterThan(0));
      expect(GallbladderForm.clearOfWall(middle), greaterThan(0));
    }
    final List<Offset> lumen = GallbladderForm.cysticLumenMm;
    for (final List<Offset> fold in GallbladderForm.cysticFoldsMm) {
      expect(_inside(lumen, fold[fold.length ~/ 2]), isTrue);
    }
  });

  test('the cystic duct runs on from inside the neck to the bile duct’s '
      'side; the bile duct and the cystic artery run outside the '
      'gallbladder, each cut short', () {
    final GallbladderForm form = _form();
    final TubeCourse duct = form.cysticDuct;
    expect(form.contains(duct.centres.first), isTrue);
    expect(form.contains(duct.centres.last), isFalse);
    final TubeCourse bile = form.bileDuct;
    final double toBile = _distanceTo(
      bile.centres,
      duct.centres.last,
      closed: false,
    );
    expect(toBile / form.scale, inInclusiveRange(1.6, 2.6));
    expect(bile.cutEnd, isTrue);
    expect(bile.shown.first, 0);
    expect(bile.centres.last.dy, greaterThan(form.box.bottom));
    for (final TubeCourse tube in form.beside) {
      for (int i = 0; i < tube.length; i++) {
        expect(form.contains(tube.centres[i]), isFalse, reason: 'row $i');
      }
    }
    final TubeCourse artery = form.cysticArtery;
    expect(artery.cutEnd, isTrue);
    expect(artery.shown.first, 0);
    // Above the gallbladder, cut short at the right hepatic artery above
    // the neck, about 21 mm on from it (Triantafyllou et al. 2025).
    expect(artery.centres.last.dy, lessThan(form.box.top));
    final Offset neckTop = form.place(GallbladderAnatomy.spine[4]);
    final List<Offset> past = <Offset>[
      for (final Offset p in artery.centres)
        if (p.dx > neckTop.dx) p,
    ];
    expect(_length(past) / form.scale, inInclusiveRange(15, 30));
  });

  test('the step from the body meets the gallbladder’s outline and the '
      'body’s at the same places, in the same order round them from the '
      'middle of the top', () {
    for (final AnatomyFigure figure in _figures) {
      final AnatomyPart part = _part(figure);
      final GallbladderForm form = _form(figure);
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

      // Both the same way round, as the morph lays them.
      final double way = _area(form.outlinePoints).sign;
      final List<Offset> bodyWay = _area(body).sign == way
          ? body
          : body.reversed.toList();
      expect(order(form.outlinePoints), order(bodyWay), reason: figure.name);
      expect(
        form.marksOf(form.outlinePoints).toSet(),
        hasLength(4),
        reason: figure.name,
      );
      for (final List<Offset> points in <List<Offset>>[
        form.outlinePoints,
        bodyWay,
      ]) {
        final List<Offset> marks = form.marksOf(points);
        final Rect box = _bounds(points);
        // The top's middle, in its upper quarter.
        expect(
          (marks[0].dx - box.center.dx).abs(),
          lessThan(box.width * 0.06),
          reason: figure.name,
        );
        expect(
          marks[0].dy - box.top,
          lessThanOrEqualTo(box.height * 0.25),
          reason: figure.name,
        );
        // The neck's end on the right, the fundus on the left.
        expect(marks[1].dx, closeTo(box.right, box.width * 0.02));
        expect(marks[3].dx, closeTo(box.left, box.width * 0.02));
      }
      final List<Offset> settled = form.outlineAt(1);
      expect(
        _bounds(settled).width,
        closeTo(form.box.width, form.mm(1)),
        reason: figure.name,
      );
    }
  });

  test(
    'its parts are named where they are: the fundus in its round end, the '
    'neck past its start, the ducts and the artery on their courses, the '
    'figure’s liver inside the liver above it; no liver without a figure',
    () {
      for (final AnatomyFigure figure in _figures) {
        final String what = figure.name;
        final GallbladderForm form = _form(figure);
        final Offset fundus = form.toMm(form.fundusName);
        expect(
          GallbladderForm.clearOfWall(fundus),
          greaterThan(3),
          reason: what,
        );
        expect(fundus.dx, lessThan(GallbladderAnatomy.spine[1].dx));
        final Offset neck = form.toMm(form.neckName);
        expect(GallbladderForm.clearOfWall(neck), greaterThan(0), reason: what);
        expect(GallbladderForm.pastNeck(neck), greaterThan(0), reason: what);
        expect(form.cysticDuct.centres, contains(form.cysticName));
        expect(form.bileDuct.centres, contains(form.bileDuctName));
        expect(form.cysticArtery.centres, contains(form.arteryName));
        // The common bile duct below the cystic duct's opening.
        expect(
          form.bileDuctName.dy,
          greaterThan(form.cysticDuct.centres.last.dy),
        );
        final Offset liver = form.liverName!;
        expect(_inside(form.liverOutline!, liver), isTrue, reason: what);
        expect(liver.dy, lessThan(form.box.top), reason: what);
      }
      expect(_form(AnatomyFigure.female, false).liverName, isNull);
    },
  );

  test('it is the same gallbladder every time', () {
    final GallbladderForm a = _form(AnatomyFigure.male);
    final GallbladderForm b = _form(AnatomyFigure.male);
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.coats, b.coats);
    expect(a.site, b.site);
    expect(a.cysticWall, b.cysticWall);
    expect(a.liverName, b.liverName);
    expect(GallbladderForm.meshEdgesMm.length, greaterThan(800));
  });
}
