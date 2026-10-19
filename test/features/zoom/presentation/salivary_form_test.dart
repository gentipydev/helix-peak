import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_figure.dart';
import 'package:helixpeek/features/zoom/domain/anatomy_tables.dart';
import 'package:helixpeek/features/zoom/domain/zoom_depth.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/lobules.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/salivary_gland/salivary_anatomy.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/salivary_gland/salivary_form.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/organs/salivary_gland/salivary_style.dart';
import 'package:helixpeek/features/zoom/presentation/scenes/tube_course.dart';

final TissueAnatomy _anatomy = tissueAnatomy['salivary gland']!;
final double _view =
    _anatomy.metres * ZoomDepth.organMargin / ZoomDepth.salivaryUpright;

AnatomyPart _part(AnatomyFigure body) => body.parts[_anatomy.uberon]!;

SalivaryForm _form([AnatomyFigure? body]) => SalivaryForm.place(
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

/// How far [p] lies from the line through [points], open or [closed].
double _toLine(List<Offset> points, Offset p, {bool closed = false}) {
  double least = double.infinity;
  final int n = points.length;
  for (int i = 0; i < (closed ? n : n - 1); i++) {
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

/// Whether the segments from [a] to [b] and from [c] to [d] cross.
bool _cross(Offset a, Offset b, Offset c, Offset d) {
  double side(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  final double d1 = side(c, d, a);
  final double d2 = side(c, d, b);
  final double d3 = side(a, b, c);
  final double d4 = side(a, b, d);
  return d1 * d2 < 0 && d3 * d4 < 0;
}

/// Whether the lines through [a] and [b] cross anywhere.
bool _crosses(List<Offset> a, List<Offset> b) {
  for (int i = 0; i + 1 < a.length; i++) {
    for (int j = 0; j + 1 < b.length; j++) {
      if (_cross(a[i], a[i + 1], b[j], b[j + 1])) {
        return true;
      }
    }
  }
  return false;
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

/// [tube]'s middle line in millimetres, followed closely.
List<Offset> _line(SalivaryForm form, TubeCourse tube) => <Offset>[
  for (final Offset p in tube.centres) form.toMm(p),
];

/// Where [line] first runs out of [outline], or its end.
int _leaves(List<Offset> line, List<Offset> outline) {
  for (int i = 0; i < line.length; i++) {
    if (!_inside(outline, line[i])) {
      return i;
    }
  }
  return line.length - 1;
}

void main() {
  test('the parotid is 60 mm from pole to pole, about the middle of the '
      'body’s outline of it, and is sampled where the body is, on either '
      'figure', () {
    for (final AnatomyFigure body in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final SalivaryForm form = _form(body);
      final List<Offset> outline = <Offset>[
        for (final Offset p in form.outlinePoints) form.toMm(p),
      ];
      final Rect box = _bounds(outline);
      expect(box.height, closeTo(SalivaryAnatomy.length, 1.5));
      expect(
        form.mm(SalivaryAnatomy.length),
        closeTo(_anatomy.metres / _view, 1e-12),
      );
      expect(box.center.distance, lessThan(2));
      // Where the body goes into it, which an organ that follows the body
      // keeps: inside the parotid, well in from its edge.
      final AnatomyPart part = _part(body);
      final double real = _anatomy.metres / part.extent;
      final Offset site = (part.site - part.centre) * (real / _view);
      expect((form.site - site).distance, lessThan(1e-9));
      expect(form.contains(form.site), isTrue);
      expect(
        _toLine(outline, form.toMm(form.site), closed: true),
        greaterThan(8),
      );
    }
  });

  test('its parts are the sizes they are measured at', () {
    final SalivaryForm form = _form();
    // The parotid's superficial lobe, front to back: a median 36 mm, its
    // interquartile range 12 (Fang et al. 2019).
    final Rect parotid = _bounds(SalivaryAnatomy.parotid);
    expect(parotid.width, inInclusiveRange(30, 42));
    // The submandibular gland: a median 35 mm front to back and 23 top to
    // bottom (Fang et al. 2019).
    final Rect submandibular = _bounds(SalivaryAnatomy.submandibular);
    expect(submandibular.width, inInclusiveRange(31, 38));
    expect(submandibular.height, inInclusiveRange(16, 31));
    // The duct, from the hilum to its bend at the masseter's front edge,
    // 35 ± 8 mm, and no wider than its lumen at its widest, 2 mm (Avishai
    // et al. 2022).
    final List<Offset> duct = SalivaryAnatomy.duct.points;
    final int bend = duct.length - 2;
    double run = (duct[1] - SalivaryAnatomy.hilum).distance;
    for (int i = 1; i < bend; i++) {
      run += (duct[i + 1] - duct[i]).distance;
    }
    expect(run, inInclusiveRange(35.25 - 7.81, 35.25 + 7.81));
    for (final double r in SalivaryAnatomy.duct.radii) {
      expect(2 * r, inInclusiveRange(0.8, 2));
    }
    // The accessory gland a mean 15.8 by 5.0 mm, 10.5 ± 6.1 in front of
    // the main gland (Ahn et al. 2017).
    expect(SalivaryAnatomy.accessoryLength, 15.8);
    expect(SalivaryAnatomy.accessoryWidth, 5.0);
    final List<Offset> accessory = <Offset>[
      for (final Offset p in form.accessoryPoints) form.toMm(p),
    ];
    double gap = double.infinity;
    for (final Offset p in accessory) {
      gap = math.min(gap, _toLine(SalivaryAnatomy.parotid, p, closed: true));
    }
    expect(gap, inInclusiveRange(10.5 - 6.1, 10.5 + 6.1));
    // The superficial temporal artery 1.88 ± 0.40 mm across, crossing the
    // arch 10.9 ± 4.1 mm in front of the tragus (Nguyen et al. 2026); its
    // vein 0.5 to 2 mm (Nokovitch et al. 2021).
    for (final double r in SalivaryAnatomy.artery.radii) {
      expect(2 * r, inInclusiveRange(1.48, 2.28));
    }
    for (final double r in SalivaryAnatomy.vein.radii) {
      expect(2 * r, inInclusiveRange(0.5, 2));
    }
    double tragus = double.infinity;
    for (final Offset p in SalivaryAnatomy.ear) {
      if (p.dy > -25 && p.dy < -12) {
        tragus = math.min(tragus, p.dx);
      }
    }
    final double arch = SalivaryAnatomy.arch.points[1].dy;
    double crossing = SalivaryAnatomy.artery.points.first.dx;
    for (int i = 0; i + 1 < SalivaryAnatomy.artery.points.length; i++) {
      final Offset a = SalivaryAnatomy.artery.points[i];
      final Offset b = SalivaryAnatomy.artery.points[i + 1];
      if ((a.dy - arch) * (b.dy - arch) <= 0) {
        crossing = a.dx + (b.dx - a.dx) * (arch - a.dy) / (b.dy - a.dy);
      }
    }
    expect(tragus - crossing, inInclusiveRange(10.9 - 4.1, 10.9 + 4.1));
    // The facial nerve's branches thinner than the divisions they leave,
    // 2 and 1.4 mm across (Khoa et al. 2019).
    for (final AnatomyTube nerve in SalivaryAnatomy.nerves) {
      for (final double r in nerve.radii) {
        expect(2 * r, lessThan(1.4));
      }
    }
    // The ear 66 mm long and 28 wide, between women's mean and men's (Cho
    // et al. 2025), give or take a millimetre.
    final Rect ear = _bounds(SalivaryAnatomy.ear);
    expect(ear.height, inInclusiveRange(64.5 - 1, 67.1 + 1));
    expect(ear.width, inInclusiveRange(27.3 - 1, 29.2 + 1));
    // Every tube as wide at each of its points as it is given.
    for (final AnatomyTube tube in <AnatomyTube>[
      SalivaryAnatomy.duct,
      SalivaryAnatomy.arch,
      SalivaryAnatomy.mandible,
      SalivaryAnatomy.artery,
      SalivaryAnatomy.vein,
      ...SalivaryAnatomy.nerves,
    ]) {
      expect(tube.radii.length, tube.points.length);
    }
  });

  test('the duct leaves the parotid’s front edge, crosses the masseter and '
      'turns in at its front edge, its accessory gland above it', () {
    final SalivaryForm form = _form();
    final List<Offset> parotid = <Offset>[
      for (final Offset p in form.outlinePoints) form.toMm(p),
    ];
    final List<Offset> masseter = <Offset>[
      for (final Offset p in form.masseterPoints) form.toMm(p),
    ];
    final List<Offset> duct = _line(form, form.duct);
    // From under the parotid's edge, out of its front.
    expect(_inside(parotid, duct.first), isTrue);
    final int out = _leaves(duct, parotid);
    expect(out, lessThan(duct.length ~/ 3));
    expect(duct[out].dx, lessThan(parotid.first.dx));
    for (int i = out; i < duct.length; i++) {
      expect(_inside(parotid, duct[i]), isFalse);
    }
    // Over the masseter all the way to its front edge, where it ends.
    final List<double> overMasseter = <double>[
      for (int i = out; i < duct.length; i++)
        if (_inside(masseter, duct[i])) 1 else 0,
    ];
    expect(
      overMasseter.reduce((double a, double b) => a + b) /
          overMasseter.length,
      greaterThan(0.85),
    );
    expect(_toLine(masseter, duct.last, closed: true), lessThan(2.5));
    // The accessory gland above the duct, along it.
    const Offset accessory = SalivaryAnatomy.accessory;
    double below = 0;
    for (int i = 0; i + 1 < duct.length; i++) {
      if ((duct[i].dx - accessory.dx) * (duct[i + 1].dx - accessory.dx) <=
          0) {
        below = duct[i].dy;
      }
    }
    expect(accessory.dy, lessThan(below - SalivaryAnatomy.accessoryWidth / 2));
  });

  test('the facial nerve’s branches leave the gland’s edge, none crossing '
      'another or the duct, the buccal below the duct', () {
    final SalivaryForm form = _form();
    final List<Offset> parotid = <Offset>[
      for (final Offset p in form.outlinePoints) form.toMm(p),
    ];
    final List<List<Offset>> nerves = <List<Offset>>[
      for (final TubeCourse nerve in form.nerves) _line(form, nerve),
    ];
    expect(nerves, hasLength(6));
    for (final List<Offset> nerve in nerves) {
      // Out from under the gland's edge, and away from it.
      expect(_inside(parotid, nerve.first), isTrue);
      final int out = _leaves(nerve, parotid);
      expect(out, lessThan(nerve.length ~/ 4));
      for (int i = out; i < nerve.length; i++) {
        expect(_inside(parotid, nerve[i]), isFalse);
      }
    }
    final List<Offset> duct = _line(form, form.duct);
    for (int a = 0; a < nerves.length; a++) {
      expect(_crosses(nerves[a], duct), isFalse, reason: 'branch $a');
      for (int b = a + 1; b < nerves.length; b++) {
        expect(_crosses(nerves[a], nerves[b]), isFalse, reason: '$a, $b');
      }
    }
    // The zygomatic branches above the duct, the buccal below it, where
    // they run beside it.
    double yAt(List<Offset> line, double x) {
      for (int i = 0; i + 1 < line.length; i++) {
        if ((line[i].dx - x) * (line[i + 1].dx - x) <= 0) {
          final double t = (x - line[i].dx) / (line[i + 1].dx - line[i].dx);
          return line[i].dy + (line[i + 1].dy - line[i].dy) * t;
        }
      }
      return double.nan;
    }

    for (final double x in <double>[-25, -32, -40]) {
      final double d = yAt(duct, x);
      expect(yAt(nerves[1], x), lessThan(d));
      expect(yAt(nerves[2], x), lessThan(d));
      expect(yAt(nerves[3], x), greaterThan(d));
    }
  });

  test('the lobules tile each gland at about their size', () {
    final SalivaryForm form = _form();
    for (final (List<Offset> outline, Lobules lobules, int least)
        in <(List<Offset>, Lobules, int)>[
          (form.outlinePoints, form.lobules, 150),
          (form.accessoryPoints, form.accessoryLobules, 4),
          (form.submandibularPoints, form.submandibularLobules, 50),
        ]) {
      expect(lobules.all.length, greaterThanOrEqualTo(least));
      double across = 0;
      for (final Lobule lobule in lobules.all) {
        expect(_inside(outline, lobule.centre), isTrue);
        across += 2 * lobule.radius;
      }
      across /= lobules.all.length;
      expect(
        form.toMm(Offset(across, 0)).dx,
        inInclusiveRange(0.6 * SalivaryStyle.lobule, SalivaryStyle.lobule),
      );
    }
  });

  test('for a duct cell the window lays the ducts bare from the hilum to '
      'where the tissue is sampled, inside the parotid', () {
    for (final AnatomyFigure body in <AnatomyFigure>[
      AnatomyFigure.female,
      AnatomyFigure.male,
    ]) {
      final SalivaryForm form = _form(body);
      expect(form.window.contains(form.site), isTrue);
      expect(
        form.window.contains(form.place(SalivaryAnatomy.hilum)),
        isTrue,
      );
      for (final (Offset p, Offset _) in form.windowEdge) {
        expect(form.contains(p), isTrue);
      }
      final PathMetric branch = form.siteBranch.computeMetrics().single;
      final Offset end = branch.getTangentForOffset(branch.length)!.position;
      expect((end - form.site).distance, lessThan(1e-6));
    }
  });

  test('each part is named on what it names', () {
    final SalivaryForm form = _form();
    double nearest(TubeCourse tube, Offset p) {
      double least = double.infinity;
      for (int i = 0; i < tube.length; i++) {
        least = math.min(
          least,
          (tube.centres[i] - p).distance - tube.radius[i],
        );
      }
      return least;
    }

    expect(nearest(form.duct, form.ductName), lessThanOrEqualTo(0));
    expect(
      form.nerves
          .map((TubeCourse n) => nearest(n, form.nerveName))
          .reduce(math.min),
      lessThanOrEqualTo(0),
    );
    expect(form.submandibular.contains(form.submandibularName), isTrue);
  });

  test('the gland is laid the same every time', () {
    final SalivaryForm a = _form();
    final SalivaryForm b = _form();
    for (final (Lobules x, Lobules y) in <(Lobules, Lobules)>[
      (a.lobules, b.lobules),
      (a.accessoryLobules, b.accessoryLobules),
      (a.submandibularLobules, b.submandibularLobules),
    ]) {
      expect(x.all.length, y.all.length);
      for (int i = 0; i < x.all.length; i++) {
        expect(x.all[i].centre, y.all[i].centre);
        expect(x.all[i].reach, y.all[i].reach);
      }
    }
  });
}
