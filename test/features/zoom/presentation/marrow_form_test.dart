import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bone_marrow/marrow_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/bone_marrow/marrow_form.dart';

final TissueAnatomy _anatomy = tissueAnatomy['bone marrow']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.phoneAspect;

const List<AnatomyFigure Function()> _bodies = <AnatomyFigure Function()>[
  _female,
  _male,
];

AnatomyFigure _female() => AnatomyFigure.female;
AnatomyFigure _male() => AnatomyFigure.male;

AnatomyPart _part(AnatomyFigure body) => body.parts[_anatomy.uberon]!;

MarrowForm _form([AnatomyFigure? body]) => MarrowForm.place(
  part: _part(body ?? AnatomyFigure.female),
  anatomy: _anatomy,
  view: _view,
);

bool _inside(List<Offset> points, Offset p) {
  bool inside = false;
  for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
    final Offset a = points[i];
    final Offset b = points[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// How far [p] lies from the closed line through [points].
double _toLine(List<Offset> points, Offset p) {
  double least = double.infinity;
  final int n = points.length;
  for (int i = 0; i < n; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % n];
    final Offset ab = b - a;
    final double length = ab.distanceSquared;
    final double t = length == 0
        ? 0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    least = math.min(least, (a + ab * t - p).distance);
  }
  return least;
}

/// Where the closed line through [points] crosses the level [y].
List<double> _crossings(List<Offset> points, double y) {
  final List<double> xs = <double>[];
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    if ((a.dy <= y) != (b.dy <= y)) {
      xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
    }
  }
  return xs..sort();
}

Rect _bounds(List<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset p in points) {
    left = math.min(left, p.dx);
    right = math.max(right, p.dx);
    top = math.min(top, p.dy);
    bottom = math.max(bottom, p.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// The points along [path]'s outline, about a millimetre of [form] apart.
List<Offset> _along(Path path, MarrowForm form) => <Offset>[
  for (final PathMetric metric in path.computeMetrics())
    for (double s = 0; s < metric.length; s += form.mm(1))
      metric.getTangentForOffset(s)!.position,
];

void main() {
  test('the femur stands 450 mm tall, about the middle of the body’s '
      'outline of it, leaning as that outline leans, and is sampled where '
      'the body is, in its red marrow, on either figure', () {
    for (final AnatomyFigure Function() figure in _bodies) {
      final AnatomyFigure body = figure();
      final MarrowForm form = _form(body);
      final String what = body.name;
      // As it stands, in millimetres.
      final List<Offset> stood = <Offset>[
        for (final Offset p in form.outlinePoints) p / form.scale,
      ];
      final Rect box = _bounds(stood);
      expect(box.height, closeTo(MarrowAnatomy.length, 1.5), reason: what);
      expect(box.center.distance, lessThan(1e-6), reason: what);
      expect(
        form.mm(MarrowAnatomy.length),
        closeTo(_anatomy.metres / _view, 1e-12),
      );
      // The shaft leans in toward the knee, as the body's outline of it
      // does: its middle follows the outline's down the shaft.
      expect(form.lean * 180 / math.pi, inInclusiveRange(3, 8), reason: what);
      final AnatomyPart part = _part(body);
      final double real = _anatomy.metres / part.extent;
      final List<Offset> diagram = <Offset>[
        for (final Offset p in part.followed)
          (p - part.centre) * (real / _view) / form.scale,
      ];
      for (double y = -100; y <= 110; y += 30) {
        final List<double> ours = _crossings(stood, y);
        final List<double> theirs = _crossings(diagram, y);
        expect(
          ((ours.first + ours.last) - (theirs.first + theirs.last)).abs() / 2,
          lessThan(3),
          reason: '$what at $y mm',
        );
      }
      // Where the body goes into it, which an organ that follows the body
      // keeps: in its red marrow, well in from the red marrow's edges.
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9), reason: what);
      expect(form.contains(form.site), isTrue, reason: what);
      expect(form.red.contains(form.site), isTrue, reason: what);
      expect(
        _along(
          form.red,
          form,
        ).map((Offset p) => (p - form.site).distance).reduce(math.min),
        greaterThan(form.mm(10)),
        reason: what,
      );
    }
  });

  test('its parts are the sizes they are measured at', () {
    final MarrowForm form = _form();
    // The head's radius and its place: where a neck meeting the shaft at
    // 127° (127.2 ± 5.2°, Kulkarni et al. 2020) puts a head 39 mm from the
    // shaft's axis (37.5 ± 4.6). The head 47 mm across (47.0 ± 2.3, Kanz et
    // al. 2015).
    const double angle = MarrowAnatomy.neckShaft * math.pi / 180;
    final Offset along = Offset(-math.sin(angle), math.cos(angle));
    final Offset head =
        MarrowAnatomy.neckFoot +
        along * (MarrowAnatomy.offset / math.sin(angle));
    expect((head - MarrowAnatomy.head).distance, lessThan(0.01));
    expect(MarrowAnatomy.neckShaft, closeTo(127.2, 5.2));
    expect(MarrowAnatomy.offset, closeTo(37.5, 4.6));
    expect(MarrowAnatomy.headRadius * 2, closeTo(47.0, 2.3));
    final List<Offset> bone = <Offset>[
      for (final Offset p in form.outlinePoints) form.toBone(p),
    ];
    // Round its medial side and its top, away from its junctions with the
    // neck, the head is a sphere's section.
    for (final Offset p in bone) {
      final Offset d = p - MarrowAnatomy.head;
      final double degrees =
          (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
      if (degrees > 95 && degrees < 340 && d.distance < 40) {
        expect(d.distance, closeTo(MarrowAnatomy.headRadius, 0.2));
      }
    }
    // The shaft 27.9 ± 2.5 mm across at its middle, the condyles 79.6 ±
    // 4.6 (Kanz et al. 2015).
    final List<double> middle = _crossings(bone, 0);
    expect(middle.last - middle.first, closeTo(27.9, 2.5));
    double left = double.infinity;
    double right = double.negativeInfinity;
    for (final Offset p in bone) {
      if (p.dy > 185) {
        left = math.min(left, p.dx);
        right = math.max(right, p.dx);
      }
    }
    expect(right - left, closeTo(79.6, 4.6));
    // The cavity at its isthmus, 11.9 ± 1.7 mm across (Kulkarni et al.
    // 2020), 10.71 ± 2.2 (Thiesen et al. 2022); the cortex there what the
    // shaft's breadth leaves round it.
    final List<Offset> wall = <Offset>[
      for (final Offset p in form.wall) form.toBone(p),
    ];
    double isthmus = double.infinity;
    double at = 0;
    for (double y = -90; y <= 40; y += 2) {
      final List<double> xs = _crossings(wall, y);
      if (xs.last - xs.first < isthmus) {
        isthmus = xs.last - xs.first;
        at = y;
      }
    }
    expect(isthmus, inInclusiveRange(10.71 - 2.2, 11.9 + 1.7));
    final List<double> shaft = _crossings(bone, at);
    expect((shaft.last - shaft.first - isthmus) / 2, inInclusiveRange(7, 9.5));
    // As the femur stands, its greater trochanter about 1 cm lower than its
    // head, and its two condyles' lower surfaces nearly level (Gray 1918).
    final List<Offset> stood = <Offset>[
      for (final Offset p in form.outlinePoints) p / form.scale,
    ];
    final double top = stood.map((Offset p) => p.dy).reduce(math.min);
    final double trochanter = <double>[
      for (final Offset p in stood)
        if (p.dx > form.place(const Offset(0, -200)).dx / form.scale) p.dy,
    ].reduce(math.min);
    expect(trochanter - top, inInclusiveRange(8, 16));
    double medial = double.negativeInfinity;
    double lateral = double.negativeInfinity;
    final double notch = form.place(const Offset(8, 205.5)).dx / form.scale;
    for (final Offset p in stood) {
      if (p.dx < notch) {
        medial = math.max(medial, p.dy);
      } else {
        lateral = math.max(lateral, p.dy);
      }
    }
    expect((medial - lateral).abs(), lessThan(4));
    // The head's cartilage 2.8 mm thick round the fovea and thinner toward
    // its rims (Nakanishi et al. 2001), none in the fovea; the condyles'
    // 2.3 (Sandhar et al. 2026).
    final List<double> cartilage = <double>[
      for (int i = 0; i < form.cartilage.length; i++) form.cartilage[i],
    ];
    expect(cartilage.reduce(math.max), closeTo(2.8, 0.05));
    expect(
      <double>[
        for (int i = 0; i < bone.length; i++)
          if (bone[i].dy > 195) cartilage[i],
      ].reduce(math.max),
      closeTo(MarrowAnatomy.condyleCartilage, 0.05),
    );
    expect(<double>[
      for (int i = 0; i < bone.length; i++)
        if (form.fovea[i] > 0.99) cartilage[i],
    ], isNotEmpty);
  });

  test('the cartilage lies on the cortex, and the cortex round the marrow, '
      'each inside the last', () {
    for (final AnatomyFigure Function() figure in _bodies) {
      final MarrowForm form = _form(figure());
      final int n = form.outlinePoints.length;
      expect(form.surface.length, n);
      expect(form.wall.length, n);
      for (int i = 0; i < n; i++) {
        expect(form.cartilage[i], greaterThanOrEqualTo(0));
        expect(form.cortex[i], greaterThan(0.75));
        expect(
          (form.surface[i] - form.outlinePoints[i]).distance,
          closeTo(form.mm(form.cartilage[i]), 1e-9),
        );
        expect(_inside(form.outlinePoints, form.wall[i]), isTrue);
      }
      // The cartilage covers the head and the condyles, and nothing else.
      expect(form.cartilageRuns.length, 3);
    }
  });

  test('the red marrow is a young adult’s: between the trochanters, below '
      'the head’s scar and the greater trochanter’s, running in and out '
      'across the top of the cavity; the head, the greater trochanter, the '
      'shaft and the lower end yellow', () {
    final MarrowForm form = _form();
    bool red(Offset bone) => form.red.contains(form.place(bone));
    bool marrow(Offset bone) => form.marrow.contains(form.place(bone));
    for (final Offset p in <Offset>[
      MarrowAnatomy.neckFoot,
      const Offset(-8, -150),
      const Offset(10, -140),
      const Offset(0, -122),
    ]) {
      expect(marrow(p) && red(p), isTrue, reason: '$p');
    }
    for (final Offset p in <Offset>[
      MarrowAnatomy.head,
      const Offset(14, -208),
      const Offset(0, -60),
      const Offset(0, 60),
      const Offset(4, 190),
    ]) {
      expect(marrow(p), isTrue, reason: '$p');
      expect(red(p), isFalse, reason: '$p');
    }
    final Rect box = _bounds(<Offset>[
      for (final Offset p in _along(form.red, form)) form.toBone(p),
    ]);
    expect(box.bottom, lessThan(-100));
    expect(box.top, greaterThan(-206));
  });

  test('the trabeculae keep to the spongy bone of its two ends, in the '
      'groups Koch traced', () {
    final MarrowForm form = _form();
    final List<Offset> wall = form.wall;
    int inHead = 0;
    for (final TrabecularLine line in form.trabeculae) {
      for (final Offset p in line.points) {
        final Offset bone = form.toBone(p);
        expect(
          _inside(wall, p) || _toLine(wall, p) < form.mm(0.6),
          isTrue,
          reason: '$bone',
        );
        // None down the middle of the cavity.
        expect(bone.dy < -95 || bone.dy > 75, isTrue, reason: '$bone');
      }
      if ((form.toBone(line.points.last) - MarrowAnatomy.head).distance <
          MarrowAnatomy.headRadius) {
        inHead++;
      }
      expect(line.level, inInclusiveRange(0, 2));
    }
    // The principal groups end in the head; every level is drawn.
    expect(inHead, greaterThan(20));
    for (int level = 0; level < 3; level++) {
      expect(
        form.trabeculae.where((TrabecularLine l) => l.level == level),
        isNotEmpty,
      );
    }
  });

  test('the nutrient canal opens on the shaft’s medial face in its middle '
      'third, and runs upward through the cortex into the cavity', () {
    final MarrowForm form = _form();
    const Offset outer = MarrowAnatomy.foramen;
    const Offset inner = MarrowAnatomy.canalInner;
    final double top = <double>[
      for (final Offset p in form.outlinePoints) form.toBone(p).dy,
    ].reduce(math.min);
    // 29 to 69% of its length from its upper end (Kizilkanat et al. 2007),
    // in its middle third.
    final double index = (outer.dy - top) / MarrowAnatomy.length;
    expect(index, inInclusiveRange(1 / 3, 2 / 3));
    expect(outer.dx, lessThan(0));
    expect(inner.dy, lessThan(outer.dy));
    expect(form.contains(form.canal.$1), isTrue);
    expect(_toLine(form.outlinePoints, form.canal.$1), lessThan(form.mm(1)));
    expect(form.marrow.contains(form.canal.$2), isTrue);
    expect(form.ascending.first, form.canal.$2);
    expect(form.descending.first, form.canal.$2);
  });

  test('each part is named on what it names', () {
    for (final AnatomyFigure Function() figure in _bodies) {
      final MarrowForm form = _form(figure());
      // The trabecular bone in the head's spongy bone; the cortical bone in
      // the cortex; the yellow marrow in the cavity.
      expect(form.marrow.contains(form.trabecularName), isTrue);
      expect(
        (form.toBone(form.trabecularName) - MarrowAnatomy.head).distance,
        lessThan(MarrowAnatomy.headRadius - 4),
      );
      expect(form.contains(form.corticalName), isTrue);
      expect(form.marrow.contains(form.corticalName), isFalse);
      expect(form.marrow.contains(form.yellowName), isTrue);
      expect(form.red.contains(form.yellowName), isFalse);
      // The columns their names are set in are found at their heights.
      for (final Offset at in <Offset>[
        form.site,
        form.trabecularName,
        form.corticalName,
        form.yellowName,
      ]) {
        final (Offset left, Offset right) = form.edgesAt(at);
        expect(left.dy, at.dy);
        expect(right.dy, at.dy);
        expect(left.dx, lessThan(at.dx));
        expect(right.dx, greaterThan(at.dx));
      }
    }
  });

  test('the femur is laid the same every time', () {
    final MarrowForm a = _form();
    final MarrowForm b = _form();
    expect(a.outlinePoints, b.outlinePoints);
    expect(a.wall, b.wall);
    expect(a.trabeculae.length, b.trabeculae.length);
    for (int i = 0; i < a.trabeculae.length; i++) {
      expect(a.trabeculae[i].points, b.trabeculae[i].points);
      expect(a.trabeculae[i].level, b.trabeculae[i].level);
    }
  });
}
