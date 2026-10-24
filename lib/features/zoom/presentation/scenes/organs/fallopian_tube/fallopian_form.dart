import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../tube_course.dart';
import 'fallopian_anatomy.dart';
import 'fallopian_style.dart';

/// Where in the fallopian tube the zoom's cell lives, which its drawing
/// lights in the mark, by the Atlas's name for the cell. By the kind of
/// cell, never by gene.
enum FallopianHome {
  /// The mucosa and its folds, and the fimbriae's inner faces: their
  /// ciliated and secretory cells, and every cell that has no part of the
  /// tube of its own to be drawn at its size.
  mucosa,

  /// The muscular coat: its smooth muscle.
  muscularis;

  /// Where a cell the Atlas calls [cell] lives.
  static FallopianHome of(String? cell) {
    final String name = (cell ?? '').toLowerCase();
    if (name.contains('smooth muscle')) {
      return muscularis;
    }
    return mucosa;
  }

  /// What its name says.
  String get word => switch (this) {
    mucosa => 'mucosa',
    muscularis => 'muscularis',
  };
}

/// The anatomogram's ovary and its uterus's body, which the tube lies by.
const String _ovary = 'UBERON_0000992';
const String _uterus = 'UBERON_0001295';

/// The fallopian tube as the zoom's organ scene draws it, opened along its
/// length in place: every part in the scene's units at its real size, the
/// middle of the body's outline of it at the origin.
///
/// The tube is drawn from general anatomy ([FallopianAnatomy]) as a right
/// tube, turned over where the body follows its left, and laid on the
/// body's outline of it so that the place it is gone into in the anatomy
/// lies on the place the body goes in ([site]). The step from the body
/// draws the body's outline in toward the tube's own ([pathAt]). Everything
/// here is geometry: what it is drawn in is `FallopianArt`'s.
final class FallopianForm {
  FallopianForm({
    required List<Offset> diagram,
    required this.site,
    required double midline,
    required this.view,
    this.home = FallopianHome.mucosa,
    List<Offset>? ovary,
    List<Offset>? uterus,
  }) : scale = 1e-3 / view,
       flip = midline >= site.dx ? 1 : -1,
       ovaryOutline = ovary,
       uterusOutline = uterus {
    final List<Offset> own = _outline();
    final List<Offset> diagramDense = Contour(diagram).sampled(8).points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> template = _area(own).sign != _area(diagramDense).sign
        ? own.reversed.toList()
        : own;
    outlinePoints = template;
    outline = Path()..addPolygon(template, true);
    box = _bounds(template);
    _morph = OutlineMorph(
      template: template,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: FallopianStyle.morphPoints,
      bed: mm(FallopianStyle.bed),
      marks: _marks,
    );
  }

  /// The tube where the body draws it as [part] of [figure], in a view
  /// [view] metres across, its cells' [home] in it; the figure's ovary and
  /// uterus by it.
  factory FallopianForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
    AnatomyFigure? figure,
    FallopianHome home = FallopianHome.mucosa,
  }) {
    final double real = realOf(anatomy, part);
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    List<Offset>? nearest(String uberon) {
      final AnatomyPart? other = figure?.parts[uberon];
      if (other == null) {
        return null;
      }
      List<Offset>? best;
      double least = double.infinity;
      for (final List<Offset> c in other.contours) {
        final double d = (_bounds(c).center - part.site).distance;
        if (d < least) {
          least = d;
          best = c;
        }
      }
      return best == null
          ? null
          : <Offset>[for (final Offset p in best) placed(p)];
    }

    return FallopianForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      midline: placed(Offset(0, part.site.dy)).dx,
      view: view,
      home: home,
      ovary: nearest(_ovary),
      uterus: nearest(_uterus),
    );
  }

  /// How many times the size the body draws the tube at it is drawn: the
  /// anatomogram's tube at a real tube's length.
  static double realOf(TissueAnatomy anatomy, AnatomyPart part) =>
      anatomy.metres / part.extent * FallopianAnatomy.diagramShare;

  /// Where the body goes into the tube, in the scene: in its infundibulum.
  final Offset site;

  /// How many metres the scene's unit is.
  final double view;

  /// Where the zoom's cell lives in it.
  final FallopianHome home;

  /// How long one of the anatomy's millimetres is in the scene.
  final double scale;

  /// Which way across the anatomy is laid: 1 as it is drawn, a right tube
  /// with its uterine end to the right; -1 turned over.
  final double flip;

  /// The body's outlines of the ovary and of the uterus's body by the
  /// tube, in the scene; none where no figure is given.
  final List<Offset>? ovaryOutline;
  final List<Offset>? uterusOutline;

  late final OutlineMorph _morph;

  /// The tube's outline, round its outside, and its points.
  late final List<Offset> outlinePoints;
  late final Path outline;
  late final Rect box;

  /// [millimetres] in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) =>
      site +
      Offset(
            flip * (mm.dx - FallopianAnatomy.site.dx),
            mm.dy - FallopianAnatomy.site.dy,
          ) *
          scale;

  /// A point of the scene in the anatomy's millimetres.
  Offset toMm(Offset p) {
    final Offset d = (p - site) / scale;
    return FallopianAnatomy.site + Offset(flip * d.dx, d.dy);
  }

  /// The flat shape the step from the body draws: the body's outline at
  /// [settle] 0, the tube's at 1, and [bed] of the way on toward the bed it
  /// lies on.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// The flat shape's points, for tests.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// Whether [p] lies inside the tube's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  TubeCourse _tube(AnatomyTube tube) =>
      TubeCourse(tube, place, scale, mm(FallopianStyle.edgeStep), bend: 0.9);

  /// The tube itself, its middle line and how wide it is.
  late final TubeCourse tube = _tube(
    const AnatomyTube(FallopianAnatomy.course, FallopianAnatomy.half),
  );

  /// How far along the tube's rows each of its knots lies.
  int rowOf(int knot) => tube.knotRows[knot];

  /// How thick the wall is at row [i]: the isthmus's, thinning through the
  /// ampulla's first stretch to the ampulla's.
  double wallAt(int i) {
    final double from = rowOf(FallopianAnatomy.isthmusEnd).toDouble();
    final double to = rowOf(FallopianAnatomy.isthmusEnd + 2).toDouble();
    final double t = ((i - from) / (to - from)).clamp(0.0, 1.0);
    return mm(
      FallopianAnatomy.isthmusWall +
          (FallopianAnatomy.ampullaWall - FallopianAnatomy.isthmusWall) * t,
    );
  }

  /// The tube's outline: along one side to the ostium, round it, back
  /// along the other and round its uterine end.
  List<Offset> _outline() {
    final int n = tube.length;
    final Offset endWay = Offset(tube.across[n - 1].dy, -tube.across[n - 1].dx);
    final Offset startWay = Offset(-tube.across[0].dy, tube.across[0].dx);
    return <Offset>[
      for (int i = 0; i < n; i++) tube.at(i, 1),
      for (int k = 1; k < 8; k++)
        tube.centres[n - 1] +
            (tube.across[n - 1] * math.cos(math.pi * k / 8) -
                    endWay * math.sin(math.pi * k / 8)) *
                tube.radius[n - 1] *
                0.4,
      for (int i = n - 1; i >= 0; i--) tube.at(i, -1),
      for (int k = 1; k < 8; k++)
        tube.centres[0] +
            (tube.across[0] * -math.cos(math.pi * k / 8) -
                    startWay * math.sin(math.pi * k / 8)) *
                tube.radius[0],
    ];
  }

  /// The lumen, opened: the mucosa between the walls, from the uterine end
  /// to the ostium, closed.
  late final List<Offset> lumen = () {
    final int n = tube.length;
    Offset side(int i, double s) =>
        tube.centres[i] +
        tube.across[i] *
            (s *
                math.max(
                  0,
                  (s > 0 ? tube.plus[i] : tube.minus[i]) - wallAt(i),
                ));
    return <Offset>[
      for (int i = 0; i < n; i++) side(i, 1),
      for (int i = n - 1; i >= 0; i--) side(i, -1),
    ];
  }();

  /// The wall's cut faces either side of the lumen, each closed.
  late final List<List<Offset>> walls = () {
    final int n = tube.length;
    List<Offset> wall(double s) {
      Offset inner(int i) =>
          tube.centres[i] +
          tube.across[i] *
              (s *
                  math.max(
                    0,
                    (s > 0 ? tube.plus[i] : tube.minus[i]) - wallAt(i),
                  ));
      return <Offset>[
        for (int i = 0; i < n; i++) tube.at(i, s),
        for (int i = n - 1; i >= 0; i--) inner(i),
      ];
    }

    return <List<Offset>>[wall(1), wall(-1)];
  }();

  /// The folds of the mucosa: longitudinal lines across the lumen, as many
  /// as it is wide enough to part, wandering a little, each a run of the
  /// rows it shows in.
  late final List<List<Offset>> folds = () {
    final List<List<Offset>> out = <List<Offset>>[];
    const int count = FallopianAnatomy.folds;
    final int n = tube.length;
    for (int k = 0; k < count; k++) {
      // From the lumen's middle out: 0, 1, -1, 2, -2, ...
      final int rank = (k + 1) ~/ 2 * (k.isOdd ? 1 : -1);
      final double share = rank / (count / 2 + 0.5);
      List<Offset>? run;
      for (int i = 0; i < n; i++) {
        final double halfLumen = math.max(0, tube.radius[i] - wallAt(i));
        final int fit = (2 * halfLumen / mm(FallopianAnatomy.foldApart))
            .floor();
        final bool shows = k < math.min(count, math.max(1, fit));
        if (shows) {
          final double sway =
              mm(FallopianAnatomy.foldSway) *
              math.sin(tube.arc[i] / mm(3.1) + k * 1.7) *
              (halfLumen / mm(3));
          run ??= <Offset>[];
          run.add(
            tube.centres[i] + tube.across[i] * (share * halfLumen * 0.9 + sway),
          );
        } else if (run != null) {
          if (run.length > 1) {
            out.add(run);
          }
          run = null;
        }
      }
      if (run != null && run.length > 1) {
        out.add(run);
      }
    }
    return out;
  }();

  /// The fimbriae round the ostium, each a finger, the ovarian fimbria
  /// among them.
  late final List<TubeCourse> fimbriae = () {
    const List<Offset> c = FallopianAnatomy.course;
    final int n = c.length;
    final Offset end = c[n - 1];
    final Offset way = _unit(c[n - 1] - c[n - 2]);
    final Offset across = Offset(-way.dy, way.dx);
    final double rim = FallopianAnatomy.half.last * 0.9;
    return <TubeCourse>[
      for (final (double share, double turn, double length)
          in FallopianAnatomy.fimbriae)
        () {
          final Offset root = end + across * (rim * (2 * share - 1));
          final Offset dir = _rotate(way, turn);
          final Offset curl = _rotate(dir, turn * 0.35);
          return _tube(
            AnatomyTube(
              <Offset>[
                root - dir * 0.8,
                root + dir * (length * 0.5),
                root + dir * (length * 0.55) + curl * (length * 0.45),
              ],
              <double>[
                FallopianAnatomy.fimbriaRoot,
                (FallopianAnatomy.fimbriaRoot + FallopianAnatomy.fimbriaTip) /
                    2,
                FallopianAnatomy.fimbriaTip,
              ],
            ),
          );
        }(),
    ];
  }();

  /// The mesosalpinx: the sheet under the tube, from its uterine end to
  /// where the ampulla turns down, as deep as the anatomy sets, closed.
  late final List<Offset> mesosalpinx = () {
    final int to = rowOf(FallopianAnatomy.mesosalpinxEnd);
    final List<Offset> edge = <Offset>[
      for (int i = 0; i <= to; i++)
        tube.at(i, 1).dy > tube.at(i, -1).dy ? tube.at(i, 1) : tube.at(i, -1),
    ];
    final Offset down = Offset(0, mm(FallopianAnatomy.mesosalpinx));
    return <Offset>[...edge, for (final Offset p in edge.reversed) p + down];
  }();

  /// The tubal artery along the mesosalpinx, below the tube.
  late final TubeCourse artery = () {
    final int to = rowOf(FallopianAnatomy.mesosalpinxEnd);
    final List<Offset> points = <Offset>[
      for (int i = 0; i <= to; i += 12)
        toMm(
          (tube.at(i, 1).dy > tube.at(i, -1).dy
                  ? tube.at(i, 1)
                  : tube.at(i, -1)) +
              Offset(0, mm(FallopianAnatomy.arteryBelow)),
        ),
    ];
    return _tube(
      AnatomyTube(points, <double>[for (final Offset _ in points) 0.45]),
    );
  }();

  /// Everything drawn beside the tube, for its names to keep clear of.
  late final List<TubeCourse> beside = <TubeCourse>[...fimbriae, artery];

  // Where the parts are named.

  late final Offset isthmusName =
      tube.centres[rowOf(FallopianAnatomy.isthmusName)];
  late final Offset ampullaName =
      tube.centres[rowOf(FallopianAnatomy.ampullaName)];

  /// The mucosa named in the ampulla's lumen, among its folds, as it turns
  /// down.
  late final Offset mucosaName =
      tube.centres[rowOf(FallopianAnatomy.mucosaName)];
  late final Offset fimbriaeName = () {
    final TubeCourse f = fimbriae[FallopianAnatomy.ovarianFimbria];
    return f.centres[f.length * 2 ~/ 3];
  }();

  /// The ovary named at its middle, and the uterus just inside its border
  /// where the tube meets it; none where no figure is given.
  late final Offset? ovaryName = ovaryOutline == null
      ? null
      : _bounds(ovaryOutline!).center;
  late final Offset? uterusName = () {
    final List<Offset>? u = uterusOutline;
    if (u == null) {
      return null;
    }
    // From the tube's uterine end toward the uterus's middle, a little past
    // where the way first enters its outline: the outline is the
    // anatomogram's, its horns thin wedges.
    final Offset start = tube.centres.first;
    final Offset middle = _bounds(u).center;
    for (int k = 0; k <= 200; k++) {
      final Offset p = Offset.lerp(start, middle, k / 200)!;
      if (_inside(u, p)) {
        final Offset on = p + _unit(middle - start) * mm(1.5);
        return _inside(u, on) ? on : p;
      }
    }
    return middle;
  }();

  /// Where the step from the body meets the tube's outline and the body's,
  /// beside their tops: the uterine end, the lowest point and the lateral
  /// side's outermost, each picked out of either outline alike.
  late final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, flip, 0, 1),
        _lowest,
        (List<Offset> p) => OutlineMarks.outermost(p, -flip, 0, 0.7),
      ];

  static int _lowest(List<Offset> points) {
    int best = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy > points[best].dy) {
        best = i;
      }
    }
    return best;
  }

  /// The points of the tube's own outline where the step from the body
  /// meets the body's, for tests: in the order they are given.
  List<Offset> marksOf(List<Offset> points) => <Offset>[
    for (final int Function(List<Offset>) mark in _marks) points[mark(points)],
  ];
}

Offset _unit(Offset p) {
  final double length = p.distance;
  return length <= 0 ? Offset.zero : p / length;
}

Offset _rotate(Offset p, double a) => Offset(
  p.dx * math.cos(a) - p.dy * math.sin(a),
  p.dx * math.sin(a) + p.dy * math.cos(a),
);

bool _inside(List<Offset> polygon, Offset p) {
  bool odd = false;
  final int n = polygon.length;
  for (int i = 0; i < n; i++) {
    final Offset a = polygon[i];
    final Offset b = polygon[(i + 1) % n];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy)) {
      odd = !odd;
    }
  }
  return odd;
}

double _area(List<Offset> points) {
  double sum = 0;
  for (int i = 0; i < points.length; i++) {
    final Offset a = points[i];
    final Offset b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
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
