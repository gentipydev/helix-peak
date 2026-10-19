import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import '../../relief.dart';
import '../../tube_course.dart';
import 'testis_anatomy.dart';
import 'testis_style.dart';

/// One of the testis's lobules as the cut shows it: its outline, in
/// millimetres; the place it narrows to, its apex at the mediastinum or the
/// fork of the septum it lies in; whether it reaches the mediastinum; and
/// the low cushion it stands up off the cut face as.
final class TestisLobule {
  TestisLobule(this.outline, this.apex, {required this.reachesMediastinum});

  final List<Offset> outline;
  final Offset apex;
  final bool reachesMediastinum;

  late final Offset centre = () {
    Offset sum = Offset.zero;
    for (final Offset p in outline) {
      sum += p;
    }
    return sum / outline.length.toDouble();
  }();

  late final Relief cushion = Relief(
    outline,
    cell: TestisStyle.cushionCell,
    inflation: TestisStyle.cushion,
    sweeps: TestisStyle.cushionSweeps,
  );

  bool contains(Offset p) => _inside(outline, p);

  /// How far [p] lies from its outline.
  double toEdge(Offset p) => _toLine(outline, p, closed: true);
}

/// A seminiferous tubule's course across the cut, in millimetres, and the
/// lobule it lies in: a loop, or, where its lobule reaches the mediastinum,
/// a loop opened at the lobule's apex, its two ends running on straight
/// into the mediastinum as the tubuli recti.
final class TestisTubule {
  const TestisTubule(this.points, {required this.closed, required this.lobule});

  final List<Offset> points;
  final bool closed;
  final int lobule;
}

/// A septum: its course from the mediastinum to the tunica, in
/// millimetres, how far round the cut's edge it ends, and, where it forks,
/// its branch from the point [fork] of its course to the tunica.
final class TestisSeptum {
  const TestisSeptum(
    this.course,
    this.root,
    this.end, {
    this.branch,
    this.fork = -1,
    this.branchEnd = 0,
  });

  final List<Offset> course;

  /// How far along the mediastinum's edge it leaves it, and how far round
  /// the cut's edge it ends, in millimetres.
  final double root;
  final double end;

  final List<Offset>? branch;
  final int fork;
  final double branchEnd;
}

/// The testis as the zoom's organ scene draws it, and what lies round it:
/// every shape in the scene's units at the testis's real size, the middle
/// of the body's outline of it at the origin. The anatomy is
/// `TestisAnatomy`'s, in millimetres, its origin there too; the place its
/// tissue is sampled stays the body's ([site]), the middle of its cut face.
/// The step from the body draws the body's outline in toward the testis's
/// own ([outlineAt]). Everything here is geometry: what it is drawn in is
/// `TestisArt`'s.
final class TestisForm {
  TestisForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
  }) : scale = length / TestisAnatomy.length {
    final List<Offset> knots = <Offset>[
      for (final Offset p in TestisAnatomy.testis) place(p),
    ];
    final List<Offset> dense = Contour(knots)
        .sampled(TestisStyle.outlineSpan)
        .points;
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(TestisStyle.outlineSpan)
        .points;
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final bool flip = _area(dense).sign != _area(diagramDense).sign;
    final List<Offset> template = flip ? knots.reversed.toList() : knots;
    outline = Contour(template).toPath();
    outlinePoints = Contour(template).sampled(TestisStyle.outlineSpan).points;
    // The two outlines met at their tops and at the back.
    _morph = OutlineMorph(
      template: outlinePoints,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: TestisStyle.morphPoints,
      bed: mm(TestisStyle.bed),
    );
  }

  /// The form for [anatomy]'s testis, where the body draws it as [part], in
  /// a view [view] metres across.
  factory TestisForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return TestisForm(
      diagram: <Offset>[for (final Offset p in part.followed) placed(p)],
      site: placed(part.site),
      length: anatomy.metres / view,
      view: view,
    );
  }

  /// Where the tissue is sampled: the body's own place for it.
  final Offset site;

  /// How many metres one of the scene's units is.
  final double view;

  /// One of the anatomy's millimetres, in the scene's units.
  final double scale;

  /// A point of the anatomy, in millimetres, in the scene.
  Offset place(Offset mm) => mm * scale;

  /// A point of the scene, in the anatomy's millimetres.
  Offset toMm(Offset p) => p / scale;

  /// [millimetres] of the real testis, in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  List<Offset> _placed(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  // The outline, and the step from the body.

  /// The testis's outline, smooth, and the points it is followed by.
  late final Path outline;
  late final List<Offset> outlinePoints;

  late final OutlineMorph _morph;

  /// The outline the step from the body draws: the body's own at [settle]
  /// 0, the testis's at 1, drawn in by [bed] toward the bed it lies on.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// The path [outlineAt] draws: at [settle] 0 the very curve the body's
  /// outline is drawn by.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// Whether [p] lies inside the testis's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The cut face and the tunica.

  /// The outline in millimetres, followed closely, and the tunica's inner
  /// face, every point of it the outline's drawn in by the tunica: the cut
  /// face's edge.
  late final List<Offset> outlineMm = const Contour(TestisAnatomy.testis)
      .sampled(TestisStyle.outlineSpan)
      .points;
  late final double _inward = _area(outlineMm) > 0 ? 1.0 : -1.0;
  late final List<Offset> cutMm = _inset(outlineMm, TestisAnatomy.tunica);

  /// The cut face's edge, in the scene.
  late final Path cut = Path()..addPolygon(_placed(cutMm), true);

  // The mediastinum.

  /// Its free edge, from its upper end to its lower, each end on the cut's
  /// edge, in millimetres.
  late final List<Offset> edgeMm = () {
    final List<Offset> line = _open(TestisAnatomy.mediastinumEdge);
    line[0] = cutMm[_nearest(cutMm, line.first)];
    line[line.length - 1] = cutMm[_nearest(cutMm, line.last)];
    return line;
  }();

  late final List<double> _edgeAlong = _along(edgeMm);

  /// The mediastinum, in millimetres, reaching out past the cut's edge, and
  /// in the scene, bounded by it.
  late final List<Offset> mediastinumMm = const Contour(<Offset>[
    ...TestisAnatomy.mediastinumEdge,
    ...TestisAnatomy.mediastinumBack,
  ]).sampled(TestisStyle.outlineSpan).points;
  late final Path mediastinum = Path.combine(
    PathOperation.intersect,
    cut,
    Path()..addPolygon(_placed(mediastinumMm), true),
  );

  /// The rete testis, in the mediastinum's upper part.
  late final List<Offset> reteMm = const Contour(TestisAnatomy.rete)
      .sampled(TestisStyle.outlineSpan)
      .points;
  late final Path rete = Path()..addPolygon(_placed(reteMm), true);

  /// The rete's spaces, a sponge of them: each where it lies, in
  /// millimetres, its half-length and half-width, and which way it lies,
  /// along the mediastinum give or take.
  late final List<(Offset, double, double, double)> reteSpaces = () {
    final math.Random random = math.Random(59);
    const double step = TestisStyle.reteStep;
    final Rect box = _bounds(reteMm);
    final List<(Offset, double, double, double)> out =
        <(Offset, double, double, double)>[];
    for (int tries = 0; tries < 6000; tries++) {
      final Offset p = Offset(
        box.left + random.nextDouble() * box.width,
        box.top + random.nextDouble() * box.height,
      );
      if (!_inside(reteMm, p) || _toLine(reteMm, p, closed: true) < 0.12) {
        continue;
      }
      if (out.any(
        ((Offset, double, double, double) q) => (q.$1 - p).distance < step,
      )) {
        continue;
      }
      final int i = _nearest(edgeMm, p);
      final Offset way =
          edgeMm[math.min(edgeMm.length - 1, i + 1)] -
          edgeMm[math.max(0, i - 1)];
      final double angle =
          math.atan2(way.dy, way.dx) + (random.nextDouble() - 0.5) * 0.9;
      final double long =
          TestisStyle.reteShort +
          (TestisStyle.reteLong - TestisStyle.reteShort) * random.nextDouble();
      final double wide =
          TestisStyle.reteShort * (0.6 + 0.4 * random.nextDouble());
      out.add((p, long / 2, wide / 2, angle));
    }
    return out;
  }();

  // The septa.

  /// The cut's edge from the mediastinum's upper end the long way round, by
  /// the front, to its lower end, and how far along it each point lies.
  late final List<Offset> freeMm = () {
    final int n = cutMm.length;
    final int top = _nearest(cutMm, edgeMm.first);
    final int bottom = _nearest(cutMm, edgeMm.last);
    List<Offset> walk(int step) {
      final List<Offset> out = <Offset>[];
      for (int i = top; ; i = (i + step + n) % n) {
        out.add(cutMm[i]);
        if (i == bottom) {
          break;
        }
      }
      return out;
    }

    double front(List<Offset> line) =>
        line.map((Offset p) => p.dx).reduce(math.max);
    final List<Offset> forward = walk(1);
    final List<Offset> backward = walk(-1);
    return front(forward) >= front(backward) ? forward : backward;
  }();

  late final List<double> _freeAlong = _along(freeMm);

  /// The septa, from the mediastinum's upper end to its lower.
  late final List<TestisSeptum> septa = _laySepta();

  List<TestisSeptum> _laySepta() {
    final math.Random random = math.Random(67);
    const int n = TestisAnatomy.septa;
    final double edge = _edgeAlong.last;
    final double from = _freeAlong[_nearest(freeMm, TestisAnatomy.septaFrom)];
    final double to = _freeAlong[_nearest(freeMm, TestisAnatomy.septaTo)];
    final List<double> ends = <double>[
      for (int k = 0; k < n; k++) from + (to - from) * (k + 0.5) / n,
    ];
    final List<TestisSeptum> out = <TestisSeptum>[];
    for (int k = 0; k < n; k++) {
      final double rootAt = edge * (0.04 + 0.92 * (k + 0.5) / n);
      final (Offset root, Offset along) = _pointOn(edgeMm, _edgeAlong, rootAt);
      final (Offset end, Offset round) = _pointOn(freeMm, _freeAlong, ends[k]);
      // Out of the mediastinum, square to its edge; into the tunica,
      // square to it.
      Offset leave = Offset(-along.dy, along.dx);
      if (_inside(mediastinumMm, root + leave * 0.3)) {
        leave = -leave;
      }
      final Offset arrive = _into(end, round);
      final List<Offset> course = _wandering(
        _bezier(root, leave, end, arrive),
        random,
      );
      List<Offset>? branch;
      int fork = -1;
      double branchEnd = 0;
      if (k % TestisStyle.forkEvery == 1 && k + 1 < n) {
        fork = (TestisStyle.forkAt * (course.length - 1)).round();
        final Offset at = course[fork];
        final Offset heading = course[fork + 1] - course[fork - 1];
        branchEnd = (ends[k] + ends[k + 1]) / 2;
        final (Offset tip, Offset tipRound) = _pointOn(
          freeMm,
          _freeAlong,
          branchEnd,
        );
        branch = _bezier(
          at,
          heading / heading.distance,
          tip,
          _into(tip, tipRound),
          points: 24,
        );
      }
      out.add(
        TestisSeptum(
          course,
          rootAt,
          ends[k],
          branch: branch,
          fork: fork,
          branchEnd: branchEnd,
        ),
      );
    }
    return out;
  }

  /// The way into the cut face from [p] on its edge, which runs [along]
  /// there.
  Offset _into(Offset p, Offset along) {
    final Offset across = Offset(-along.dy, along.dx);
    return _inside(cutMm, p + across * 0.3) ? across : -across;
  }

  /// A septum's course from [from], leaving it heading [leave], to [to],
  /// arriving against [arrive], the way into the cut face there.
  static List<Offset> _bezier(
    Offset from,
    Offset leave,
    Offset to,
    Offset arrive, {
    int points = 48,
  }) {
    final double length = (to - from).distance;
    final Offset toward = (to - from) / length;
    Offset out = leave * 0.45 + toward * 0.55;
    out = out / out.distance;
    final Offset c1 = from + out * (length * TestisStyle.septumLeave);
    final Offset c2 = to + arrive * (length * TestisStyle.septumArrive);
    return <Offset>[
      for (int k = 0; k <= points; k++)
        () {
          final double t = k / points;
          final double u = 1 - t;
          return from * (u * u * u) +
              c1 * (3 * u * u * t) +
              c2 * (3 * u * t * t) +
              to * (t * t * t);
        }(),
    ];
  }

  /// [line] wandering a little to either side of itself, its ends where
  /// they were.
  static List<Offset> _wandering(List<Offset> line, math.Random random) {
    final double phase = random.nextDouble() * 2 * math.pi;
    final int n = line.length;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final double t = i / (n - 1);
          final Offset d =
              line[math.min(n - 1, i + 1)] - line[math.max(0, i - 1)];
          final Offset across = Offset(-d.dy, d.dx) / d.distance;
          return line[i] +
              across *
                  (TestisStyle.septumWander *
                      math.sin(math.pi * t) *
                      math.sin(2 * math.pi * 1.4 * t + phase));
        }(),
    ];
  }

  /// The septa and their branches, in the scene, as lines to stroke.
  late final Path septaPath = () {
    final Path path = Path();
    void add(List<Offset> line) {
      final Offset first = place(line.first);
      path.moveTo(first.dx, first.dy);
      for (final Offset p in line.skip(1)) {
        final Offset q = place(p);
        path.lineTo(q.dx, q.dy);
      }
    }

    for (final TestisSeptum septum in septa) {
      add(septum.course);
      final List<Offset>? branch = septum.branch;
      if (branch != null) {
        add(branch);
      }
    }
    return path;
  }();

  // The lobules.

  /// The lobules between the septa, from the upper pole round to the
  /// lower; and, where a septum forks, the lobule between its branch and
  /// itself.
  late final List<TestisLobule> lobules = _layLobules();

  List<TestisLobule> _layLobules() {
    final List<TestisLobule> out = <TestisLobule>[];
    final int n = septa.length;
    final double edgeEnd = _edgeAlong.last;
    final double freeEnd = _freeAlong.last;
    for (int j = 0; j <= n; j++) {
      final TestisSeptum? left = j > 0 ? septa[j - 1] : null;
      final TestisSeptum? right = j < n ? septa[j] : null;
      final List<Offset> points = <Offset>[];
      double freeFrom = 0;
      if (left != null) {
        final List<Offset>? branch = left.branch;
        if (branch != null) {
          points
            ..addAll(left.course.sublist(0, left.fork))
            ..addAll(branch.sublist(0, branch.length - 1));
          freeFrom = left.branchEnd;
        } else {
          points.addAll(left.course.sublist(0, left.course.length - 1));
          freeFrom = left.end;
        }
      }
      points.addAll(
        _between(freeMm, _freeAlong, freeFrom, right?.end ?? freeEnd),
      );
      if (right != null) {
        points.addAll(right.course.reversed.skip(1));
      }
      final double rootFrom = right?.root ?? edgeEnd;
      final double rootTo = left?.root ?? 0;
      points.addAll(_between(edgeMm, _edgeAlong, rootFrom, rootTo));
      final (Offset apex, Offset _) = _pointOn(
        edgeMm,
        _edgeAlong,
        (rootFrom + rootTo) / 2,
      );
      out.add(TestisLobule(_dedupe(points), apex, reachesMediastinum: true));
      // The lobule a fork closes off, between the branch and its septum.
      if (left != null) {
        final List<Offset>? branch = left.branch;
        if (branch != null) {
          out.add(
            TestisLobule(
              _dedupe(<Offset>[
                ...left.course.sublist(left.fork, left.course.length - 1),
                ..._between(freeMm, _freeAlong, left.end, left.branchEnd),
                ...branch.reversed.skip(1),
              ]),
              left.course[left.fork],
              reachesMediastinum: false,
            ),
          );
        }
      }
    }
    return out;
  }

  // The seminiferous tubules.

  /// The tubules, lobule by lobule.
  late final List<TestisTubule> tubules = () {
    final math.Random random = math.Random(83);
    return <TestisTubule>[
      for (int k = 0; k < lobules.length; k++)
        ..._tubulesOf(lobules[k], k, random),
    ];
  }();

  /// The tubules of [lobule], the [index]th: laid on a grid along the
  /// lobule from its apex, as the outline of a forest of trees grown
  /// through the grid's cells from cells by the apex, each tree's outline
  /// one tubule, which so never crosses another or itself, and turns where
  /// its tree branches or ends. Where the lobule reaches the mediastinum
  /// each is opened at its tree's root and runs on into it.
  List<TestisTubule> _tubulesOf(
    TestisLobule lobule,
    int index,
    math.Random random,
  ) {
    const double pitch = TestisStyle.pitch;
    const double cell = 2 * pitch;
    // How far from the lobule's edge the course of a tubule may come.
    const double margin = TestisStyle.tubule / 2 + TestisStyle.tubuleClear;
    final Offset apex = lobule.apex;
    Offset ex = lobule.centre - apex;
    if (ex.distance <= 0) {
      return const <TestisTubule>[];
    }
    ex = ex / ex.distance;
    final Offset ey = Offset(-ex.dy, ex.dx);
    double x0 = double.infinity;
    double x1 = double.negativeInfinity;
    double y0 = double.infinity;
    double y1 = double.negativeInfinity;
    for (final Offset p in lobule.outline) {
      final Offset d = p - apex;
      final double x = d.dx * ex.dx + d.dy * ex.dy;
      final double y = d.dx * ey.dx + d.dy * ey.dy;
      x0 = math.min(x0, x);
      x1 = math.max(x1, x);
      y0 = math.min(y0, y);
      y1 = math.max(y1, y);
    }
    final int columns = ((x1 - x0) / cell).ceil();
    final int rows = ((y1 - y0) / cell).ceil();
    if (columns < 1 || rows < 1) {
      return const <TestisTubule>[];
    }
    Offset frame(double x, double y) => apex + ex * x + ey * y;
    Offset centreOf(int i, int j) =>
        frame(x0 + (i + 0.5) * cell, y0 + (j + 0.5) * cell);
    // How far inside the lobule each of the cells' corners lies, which the
    // tubule round a cell passes through: found along each row of corners
    // and each column, where the lobule's edge crosses them, the nearer of
    // the two over the root of two, so that a corner that far in both ways
    // is that far from an edge running any way.
    final List<Offset> shape = <Offset>[
      for (final Offset p in lobule.outline)
        Offset(
          (p - apex).dx * ex.dx + (p - apex).dy * ex.dy,
          (p - apex).dx * ey.dx + (p - apex).dy * ey.dy,
        ),
    ];
    final int wide = 2 * columns;
    final int tall = 2 * rows;
    final Float32List room = Float32List(wide * tall);
    for (int b = 0; b < tall; b++) {
      final List<double> cuts = _crossings(
        shape,
        y0 + (b + 0.5) * pitch,
        across: false,
      );
      for (int a = 0; a < wide; a++) {
        room[a * tall + b] = _room(cuts, x0 + (a + 0.5) * pitch);
      }
    }
    for (int a = 0; a < wide; a++) {
      final List<double> cuts = _crossings(
        shape,
        x0 + (a + 0.5) * pitch,
        across: true,
      );
      for (int b = 0; b < tall; b++) {
        final int k = a * tall + b;
        room[k] =
            math.min(room[k], _room(cuts, y0 + (b + 0.5) * pitch)) / math.sqrt2;
      }
    }
    bool clear(int a, int b) => room[a * tall + b] >= margin;
    // How much of the waves a corner takes: none at the lobule's edge, all
    // of them well inside it.
    double waved(int a, int b) =>
        _smooth((room[a * tall + b] - margin) / TestisStyle.warpFade);
    final Uint8List open = Uint8List(columns * rows);
    for (int i = 0; i < columns; i++) {
      for (int j = 0; j < rows; j++) {
        if (clear(2 * i, 2 * j) &&
            clear(2 * i, 2 * j + 1) &&
            clear(2 * i + 1, 2 * j) &&
            clear(2 * i + 1, 2 * j + 1)) {
          open[i * rows + j] = 1;
        }
      }
    }
    // The open cells in groups that touch, side to side.
    final Int32List group = Int32List(columns * rows)
      ..fillRange(0, columns * rows, -1);
    final List<List<int>> groups = <List<int>>[];
    List<int> neighbours(int k) {
      final int i = k ~/ rows;
      final int j = k % rows;
      return <int>[
        if (i + 1 < columns) k + rows,
        if (i > 0) k - rows,
        if (j + 1 < rows) k + 1,
        if (j > 0) k - 1,
      ];
    }

    for (int k = 0; k < columns * rows; k++) {
      if (open[k] == 0 || group[k] >= 0) {
        continue;
      }
      final List<int> members = <int>[k];
      group[k] = groups.length;
      for (int at = 0; at < members.length; at++) {
        for (final int m in neighbours(members[at])) {
          if (open[m] == 1 && group[m] < 0) {
            group[m] = groups.length;
            members.add(m);
          }
        }
      }
      groups.add(members);
    }
    final List<TestisTubule> out = <TestisTubule>[];
    // The tree edges each cell has: 1 toward +i, 2 toward -i, 4 toward +j,
    // 8 toward -j.
    final Uint8List links = Uint8List(columns * rows);
    final Int32List owner = Int32List(columns * rows);
    for (final List<int> members in groups) {
      if (members.length < 2) {
        continue;
      }
      final double area = members.length * cell * cell;
      final int count = (area / TestisStyle.lobulePerTubule).round().clamp(
        1,
        TestisStyle.tubulesPerLobule,
      );
      // The trees' roots: by the apex where the lobule reaches the
      // mediastinum, a few cells apart; anywhere apart otherwise.
      final List<int> order = List<int>.of(members);
      if (lobule.reachesMediastinum) {
        order.sort(
          (int a, int b) => (centreOf(a ~/ rows, a % rows) - apex).distance
              .compareTo((centreOf(b ~/ rows, b % rows) - apex).distance),
        );
      } else {
        order.shuffle(random);
      }
      final List<int> roots = <int>[];
      for (final int k in order) {
        if (roots.length >= count) {
          break;
        }
        if (roots.every(
          (int r) =>
              (r ~/ rows - k ~/ rows).abs() + (r % rows - k % rows).abs() >= 3,
        )) {
          roots.add(k);
        }
      }
      // The trees, grown together through the group's cells.
      for (final int k in members) {
        links[k] = 0;
        owner[k] = -1;
      }
      final List<List<int>> growing = <List<int>>[
        for (int t = 0; t < roots.length; t++) <int>[roots[t]],
      ];
      for (int t = 0; t < roots.length; t++) {
        owner[roots[t]] = t;
      }
      while (true) {
        final List<int> live = <int>[
          for (int t = 0; t < growing.length; t++)
            if (growing[t].isNotEmpty) t,
        ];
        if (live.isEmpty) {
          break;
        }
        final int t = live[random.nextInt(live.length)];
        final List<int> tips = growing[t];
        final int at = random.nextDouble() < TestisStyle.runOn
            ? tips.length - 1
            : random.nextInt(tips.length);
        final int k = tips[at];
        final List<int> free = <int>[
          for (final int m in neighbours(k))
            if (open[m] == 1 && group[m] == group[k] && owner[m] < 0) m,
        ];
        if (free.isEmpty) {
          tips.removeAt(at);
          continue;
        }
        final int m = free[random.nextInt(free.length)];
        owner[m] = t;
        if (m == k + rows) {
          links[k] |= 1;
          links[m] |= 2;
        } else if (m == k - rows) {
          links[k] |= 2;
          links[m] |= 1;
        } else if (m == k + 1) {
          links[k] |= 4;
          links[m] |= 8;
        } else {
          links[k] |= 8;
          links[m] |= 4;
        }
        tips.add(m);
      }
      // Each tree's outline, one tubule.
      // The tree rooted nearest the apex is opened there and runs on into
      // the mediastinum; the rest are the loops the cut shows of theirs.
      for (int t = 0; t < roots.length; t++) {
        final bool opened = lobule.reachesMediastinum && t == 0;
        final List<int> tree = <int>[
          for (final int k in members)
            if (owner[k] == t) k,
        ];
        final List<(int, int)>? nodes = _outlineOf(
          tree,
          links,
          rows,
          opened ? roots[t] : -1,
          () {
            final int r = roots[t];
            final Offset toward = apex - centreOf(r ~/ rows, r % rows);
            return Offset(
              toward.dx * ex.dx + toward.dy * ex.dy,
              toward.dx * ey.dx + toward.dy * ey.dy,
            );
          }(),
        );
        if (nodes == null || nodes.length < 4) {
          continue;
        }
        final List<Offset> course = <Offset>[
          for (final (int a, int b) in nodes)
            () {
              final Offset p = frame(
                x0 + (a + 0.5) * pitch,
                y0 + (b + 0.5) * pitch,
              );
              return p + _warp(p) * waved(a, b);
            }(),
        ];
        final Offset deep =
            apex +
            (apex - lobule.centre) /
                (apex - lobule.centre).distance *
                TestisStyle.rectus;
        // Its ends run on side by side, square to the way in; where the
        // side it was opened on lies along the way in instead, as in a
        // lobule too small to have a cell square to its apex, it stays the
        // loop it was.
        final Offset gap = course.first - course.last;
        final Offset way = deep - (course.first + course.last) / 2;
        final bool closed =
            !opened ||
            (gap.dx * way.dx + gap.dy * way.dy).abs() >
                0.5 * gap.distance * way.distance;
        final List<Offset> smooth = _bspline(course, closed: closed);
        if (closed) {
          out.add(TestisTubule(smooth, closed: true, lobule: index));
          continue;
        }
        final Offset start = smooth.first;
        final Offset finish = smooth.last;
        // Each in its own lane, to the side of the way in it starts on.
        final Offset inward = deep - (start + finish) / 2;
        final Offset lane =
            Offset(-inward.dy, inward.dx) / math.max(inward.distance, 1e-9);
        final double side =
            (start - finish).dx * lane.dx + (start - finish).dy * lane.dy < 0
            ? -1
            : 1;
        final Offset half = lane * (0.55 * pitch);
        final List<Offset> lead = _straight(deep + half * side, start);
        out.add(
          TestisTubule(
            <Offset>[
              ...lead.sublist(0, lead.length - 1),
              ...smooth,
              ..._straight(finish, deep - half * side).skip(1),
            ],
            closed: false,
            lobule: index,
          ),
        );
      }
    }
    return out;
  }

  /// The outline of the tree of [cells], whose links to one another are
  /// [links], on a grid [rows] cells tall: the fine nodes, two to a cell
  /// each way, round it in order. Where [root] is a cell of it, the
  /// outline is opened on the side of that cell that faces [toward], and
  /// runs from one end there to the other; else it is a loop.
  static List<(int, int)>? _outlineOf(
    List<int> cells,
    Uint8List links,
    int rows,
    int root,
    Offset toward,
  ) {
    final int tall = 2 * rows;
    final Map<int, List<int>> next = <int, List<int>>{};
    void join(int a, int b) {
      next.putIfAbsent(a, () => <int>[]).add(b);
      next.putIfAbsent(b, () => <int>[]).add(a);
    }

    int node(int a, int b) => a * tall + b;
    for (final int k in cells) {
      final int i = k ~/ rows;
      final int j = k % rows;
      final int l = links[k];
      if (l & 1 != 0) {
        join(node(2 * i + 1, 2 * j), node(2 * i + 2, 2 * j));
        join(node(2 * i + 1, 2 * j + 1), node(2 * i + 2, 2 * j + 1));
      } else {
        join(node(2 * i + 1, 2 * j), node(2 * i + 1, 2 * j + 1));
      }
      if (l & 2 == 0) {
        join(node(2 * i, 2 * j), node(2 * i, 2 * j + 1));
      }
      if (l & 4 != 0) {
        join(node(2 * i, 2 * j + 1), node(2 * i, 2 * j + 2));
        join(node(2 * i + 1, 2 * j + 1), node(2 * i + 1, 2 * j + 2));
      } else {
        join(node(2 * i, 2 * j + 1), node(2 * i + 1, 2 * j + 1));
      }
      if (l & 8 == 0) {
        join(node(2 * i, 2 * j), node(2 * i + 1, 2 * j));
      }
    }
    if (next.values.any((List<int> n) => n.length != 2)) {
      return null;
    }
    int from = node(2 * (cells.first ~/ rows), 2 * (cells.first % rows));
    int? avoid;
    if (root >= 0) {
      // The free side of the root's cell that faces most nearly [toward].
      final int i = root ~/ rows;
      final int j = root % rows;
      final int l = links[root];
      final List<(double, int, int)> sides = <(double, int, int)>[
        if (l & 1 == 0)
          (toward.dx, node(2 * i + 1, 2 * j), node(2 * i + 1, 2 * j + 1)),
        if (l & 2 == 0)
          (-toward.dx, node(2 * i, 2 * j), node(2 * i, 2 * j + 1)),
        if (l & 4 == 0)
          (toward.dy, node(2 * i, 2 * j + 1), node(2 * i + 1, 2 * j + 1)),
        if (l & 8 == 0)
          (-toward.dy, node(2 * i, 2 * j), node(2 * i + 1, 2 * j)),
      ];
      if (sides.isNotEmpty) {
        sides.sort(
          ((double, int, int) a, (double, int, int) b) => b.$1.compareTo(a.$1),
        );
        from = sides.first.$2;
        avoid = sides.first.$3;
      }
    }
    final List<(int, int)> out = <(int, int)>[];
    int previous = avoid ?? -1;
    int at = from;
    while (true) {
      out.add((at ~/ tall, at % tall));
      final List<int> two = next[at]!;
      final int go = two[0] == previous ? two[1] : two[0];
      previous = at;
      at = go;
      if (at == from || (avoid != null && previous == avoid)) {
        break;
      }
    }
    return out;
  }

  /// Where a lobule's tubules are laid off their grid: two waves, the same
  /// everywhere, a long one that bends whole runs of them and a short one
  /// that sets each winding, so none runs dead straight or turns square.
  static Offset _warp(Offset p) {
    const double a = TestisStyle.warp;
    const double k = 2 * math.pi / TestisStyle.warpWave;
    const double b = TestisStyle.wiggle;
    const double q = 2 * math.pi / TestisStyle.wiggleWave;
    return Offset(
      a * math.sin(k * p.dy + 1.3) * math.cos(0.7 * k * p.dx + 0.4) +
          b * math.sin(q * p.dy + 0.6) * math.cos(0.8 * q * p.dx + 2.2),
      a * math.sin(k * p.dx + 2.1) * math.cos(0.6 * k * p.dy + 1.7) +
          b * math.sin(q * p.dx + 1.9) * math.cos(0.9 * q * p.dy + 0.3),
    );
  }

  /// A smooth curve through [nodes]' corners, a point to each span and two
  /// to a span that turns: a cubic B-spline, closed or held at its ends.
  static List<Offset> _bspline(List<Offset> nodes, {required bool closed}) {
    final int n = nodes.length;
    Offset at(int i) =>
        closed ? nodes[((i % n) + n) % n] : nodes[i.clamp(0, n - 1)];
    final List<Offset> out = <Offset>[];
    final int spans = closed ? n : n - 1;
    bool turns(Offset a, Offset b, Offset c) {
      final Offset d1 = b - a;
      final Offset d2 = c - b;
      return (d1.dx * d2.dy - d1.dy * d2.dx).abs() >
          0.2 * d1.distance * d2.distance;
    }

    for (int i = 0; i < spans; i++) {
      final Offset p0 = at(i - 1);
      final Offset p1 = at(i);
      final Offset p2 = at(i + 1);
      final Offset p3 = at(i + 2);
      // A span between two turns takes a point at its middle as well; on
      // a straight run the curve is straight.
      final int samples = turns(p0, p1, p2) || turns(p1, p2, p3) ? 2 : 1;
      for (int k = 0; k < samples; k++) {
        final double t = k / samples;
        final double t2 = t * t;
        final double t3 = t2 * t;
        final double u = 1 - t;
        out.add(
          p0 * (u * u * u / 6) +
              p1 * ((3 * t3 - 6 * t2 + 4) / 6) +
              p2 * ((-3 * t3 + 3 * t2 + 3 * t + 1) / 6) +
              p3 * (t3 / 6),
        );
      }
    }
    if (!closed) {
      out.add((nodes[n - 2] + nodes[n - 1] * 5) / 6);
    }
    return out;
  }

  /// Where the closed outline [shape] crosses the line at [at] down it, or
  /// across it where [across], each the other way along the line, sorted.
  static List<double> _crossings(
    List<Offset> shape,
    double at, {
    required bool across,
  }) {
    final List<double> out = <double>[];
    final int n = shape.length;
    for (int i = 0; i < n; i++) {
      final Offset a = shape[i];
      final Offset b = shape[(i + 1) % n];
      final double ua = across ? a.dx : a.dy;
      final double ub = across ? b.dx : b.dy;
      if ((ua <= at) != (ub <= at)) {
        final double t = (at - ua) / (ub - ua);
        out.add(across ? a.dy + (b.dy - a.dy) * t : a.dx + (b.dx - a.dx) * t);
      }
    }
    return out..sort();
  }

  /// How far inside the span of [cuts], pairs of them in turn, that holds
  /// [v] it lies from that span's nearer end; none where none holds it.
  static double _room(List<double> cuts, double v) {
    for (int k = 0; k + 1 < cuts.length; k += 2) {
      if (v >= cuts[k] && v <= cuts[k + 1]) {
        return math.min(v - cuts[k], cuts[k + 1] - v);
      }
    }
    return 0;
  }

  /// Points every tenth of a millimetre or so from [from] to [to].
  static List<Offset> _straight(Offset from, Offset to) {
    final int steps = math.max(1, ((to - from).distance / 0.1).ceil());
    return <Offset>[
      for (int k = 0; k <= steps; k++) Offset.lerp(from, to, k / steps)!,
    ];
  }

  // The Leydig cells, for an endocrine cell.

  /// Their clusters in the interstitium, between the tubules: where each
  /// lies, in the scene, and its true radius, in the scene's units.
  late final List<(Offset, double)> leydig = _layLeydig();

  /// The cluster at the place the tissue is sampled.
  late final (Offset, double) siteLeydig = (
    site,
    mm(TestisStyle.siteLeydig / 1000),
  );

  List<(Offset, double)> _layLeydig() {
    final math.Random random = math.Random(89);
    // The tubules' points, in buckets.
    const double bucket = 0.3;
    final Map<int, List<Offset>> near = <int, List<Offset>>{};
    int key(int x, int y) => (x + 4096) * 8192 + (y + 4096);
    for (final TestisTubule tubule in tubules) {
      for (final Offset p in tubule.points) {
        near
            .putIfAbsent(
              key((p.dx / bucket).floor(), (p.dy / bucket).floor()),
              () => <Offset>[],
            )
            .add(p);
      }
    }
    double toTubule(Offset p) {
      double best = double.infinity;
      final int x = (p.dx / bucket).floor();
      final int y = (p.dy / bucket).floor();
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          for (final Offset q
              in near[key(x + dx, y + dy)] ?? const <Offset>[]) {
            best = math.min(best, (q - p).distanceSquared);
          }
        }
      }
      return math.sqrt(best);
    }

    final Rect box = _bounds(cutMm);
    final List<(Offset, double)> out = <(Offset, double)>[];
    int tries = 0;
    while (out.length < TestisStyle.leydig &&
        tries < TestisStyle.leydig * 400) {
      tries++;
      final Offset p = Offset(
        box.left + random.nextDouble() * box.width,
        box.top + random.nextDouble() * box.height,
      );
      final double size = random.nextDouble();
      if (!_inside(cutMm, p) || _inside(mediastinumMm, p)) {
        continue;
      }
      double radius = TestisStyle.leydigRadii.last;
      double sum = 0;
      for (int k = 0; k < TestisStyle.leydigRadii.length; k++) {
        sum += TestisStyle.leydigShares[k];
        if (size <= sum) {
          radius = TestisStyle.leydigRadii[k];
          break;
        }
      }
      final double r = radius / 1000;
      final double d = toTubule(p);
      if (d < TestisStyle.tubule / 2 + 0.2 * r ||
          d > 0.75 * TestisStyle.pitch) {
        continue;
      }
      out.add((place(p), mm(r)));
    }
    return out;
  }

  // The epididymis and the ductules.

  /// A tube of the anatomy laid in the scene, its rows at most [row]
  /// millimetres apart.
  TubeCourse tube(AnatomyTube tube, {double row = TestisStyle.tubeRow}) =>
      TubeCourse(tube, place, scale, mm(row), bend: TestisStyle.bend);

  late final TubeCourse epididymis = tube(
    TestisAnatomy.epididymis,
    row: TestisStyle.epididymisRow,
  );

  /// How far along the epididymis its head ends.
  late final double headEnd =
      epididymis.arc[epididymis.knotRows[TestisAnatomy.epididymisHead - 1]];

  /// The epididymis's outline, round both its sides.
  late final List<Offset> epididymisPoints = <Offset>[
    for (int i = 0; i < epididymis.length; i++) epididymis.at(i, 1),
    for (int i = epididymis.length - 1; i >= 0; i--) epididymis.at(i, -1),
  ];
  late final Path epididymisPath = Path()..addPolygon(epididymisPoints, true);

  /// How far past the head [along] the epididymis lies, from 0 in the head
  /// to 1 a few millimetres on.
  double pastHead(double along) => ((along - headEnd) / mm(4)).clamp(0.0, 1.0);

  /// How much nearer to one another its knobs lie along it than across it,
  /// [along] it: as near in the head, whose knobs are its lobules, and
  /// nearer in the rest, whose knobs are coils lying across it.
  double squeezeAt(double along) =>
      1 + (TestisStyle.coilSqueeze - 1) * pastHead(along);

  /// The knobs its surface is made of: the head's lobules and the coils of
  /// the rest, each where it lies along it and across it, in the scene's
  /// units, and how far apart it lies from the next.
  late final List<(double, double, double)> knobs = () {
    final math.Random random = math.Random(97);
    final TubeCourse e = epididymis;
    final double total = e.arc.last;
    double apart(double along) => mm(
      TestisStyle.headKnob +
          (TestisStyle.bodyKnob - TestisStyle.headKnob) * pastHead(along),
    );

    final List<(double, double, double)> out = <(double, double, double)>[];
    // The knobs laid so far, in stretches along it as long as the widest
    // apart two may lie.
    final double stretch = mm(TestisStyle.headKnob);
    final Map<int, List<int>> near = <int, List<int>>{};
    for (int tries = 0; tries < 6000; tries++) {
      final double along = random.nextDouble() * total;
      final int row = _rowAt(e.arc, along);
      final double across = (2 * random.nextDouble() - 1) * e.radius[row];
      final double spacing = apart(along);
      final double squeeze = squeezeAt(along);
      final int at = (along / stretch).floor();
      bool clear = true;
      for (int k = at - 1; k <= at + 1 && clear; k++) {
        for (final int i in near[k] ?? const <int>[]) {
          final (double s, double v, double _) = out[i];
          final double ds = (s - along) * squeeze;
          final double dv = v - across;
          if (ds * ds + dv * dv < 0.8 * spacing * spacing) {
            clear = false;
            break;
          }
        }
      }
      if (clear) {
        near.putIfAbsent(at, () => <int>[]).add(out.length);
        out.add((along, across, spacing));
      }
    }
    out.sort(
      ((double, double, double) a, (double, double, double) b) =>
          a.$1.compareTo(b.$1),
    );
    return out;
  }();

  /// The efferent ductules, each coiling more as it nears the head.
  late final List<TubeCourse> ductules = () {
    final (Offset fromA, Offset fromB) = TestisAnatomy.ductulesFrom;
    final (double toA, double toB) = TestisAnatomy.ductulesTo;
    const int n = TestisAnatomy.ductules;
    final TubeCourse e = epididymis;
    // Where each reaches the head: on its underside, the side facing the
    // testis, a little way into it.
    Offset into(double share) {
      final int row = _rowAt(e.arc, share * headEnd);
      final Offset c = e.centres[row];
      final Offset m = e.across[row];
      final double sign = (c + m).distanceSquared < (c - m).distanceSquared
          ? 1
          : -1;
      return toMm(
        c + m * (sign * (e.radius[row] - mm(TestisStyle.ductuleInto))),
      );
    }

    return <TubeCourse>[
      for (int k = 0; k < n; k++)
        () {
          final double f = (k + 0.5) / n;
          final Offset from = Offset.lerp(fromA, fromB, f)!;
          final Offset to = into(toA + (toB - toA) * f);
          final double length = (to - from).distance;
          final Offset along = (to - from) / length;
          final Offset across = Offset(-along.dy, along.dx);
          const double half = TestisStyle.coilWave / 2;
          final int steps = math.max(2, (length / half).floor());
          // Each in step with the next, so neighbours wind side by side
          // rather than into one another.
          final List<Offset> points = <Offset>[
            for (int s = 0; s <= steps; s++)
              () {
                final double t = s / steps;
                final double coil =
                    TestisStyle.coilFrom +
                    (TestisStyle.coilTo - TestisStyle.coilFrom) * _smooth(t);
                final double side = s == 0 || s == steps
                    ? 0
                    : (s.isEven ? 1 : -1);
                return from + along * (length * t) + across * (coil * side);
              }(),
          ];
          return tube(
            AnatomyTube(points, <double>[
              for (int s = 0; s <= steps; s++) TestisStyle.ductule / 2,
            ]),
            row: TestisStyle.ductuleRow,
          );
        }(),
    ];
  }();

  // The cord.

  late final TubeCourse vas = tube(TestisAnatomy.vas);
  late final TubeCourse artery = tube(TestisAnatomy.artery);
  late final List<TubeCourse> veins = <TubeCourse>[
    for (final AnatomyTube vein in TestisAnatomy.veins) tube(vein),
  ];

  // The tunica vaginalis.

  late final List<Offset> sacPoints = Contour(_placed(TestisAnatomy.sac))
      .sampled(TestisStyle.outlineSpan)
      .points;
  late final Path sac = Contour(_placed(TestisAnatomy.sac)).toPath();

  // Helpers.

  /// [points], an open line, followed by a curve through them, six points
  /// to each span.
  static List<Offset> _open(List<Offset> points) {
    final int n = points.length;
    Offset at(int i) => i < 0
        ? points[0] * 2 - points[1]
        : i >= n
        ? points[n - 1] * 2 - points[n - 2]
        : points[i];
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < n - 1; i++) {
      final Offset p0 = at(i - 1);
      final Offset p1 = at(i);
      final Offset p2 = at(i + 1);
      final Offset p3 = at(i + 2);
      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      for (int k = 0; k < 6; k++) {
        final double t = k / 6;
        final double u = 1 - t;
        out.add(
          p1 * (u * u * u) +
              c1 * (3 * u * u * t) +
              c2 * (3 * u * t * t) +
              p2 * (t * t * t),
        );
      }
    }
    out.add(points.last);
    return out;
  }

  /// [points] drawn in by [by] toward the inside of the outline they go
  /// round, which runs the way the testis's does.
  List<Offset> _inset(List<Offset> points, double by) {
    final int n = points.length;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t = points[(i + 1) % n] - points[(i - 1 + n) % n];
          final double length = t.distance;
          if (length <= 0) {
            return points[i];
          }
          return points[i] + Offset(-t.dy, t.dx) / length * (by * _inward);
        }(),
    ];
  }

  /// How far along the open line [points] each of them lies.
  static List<double> _along(List<Offset> points) {
    final List<double> out = <double>[0];
    for (int i = 1; i < points.length; i++) {
      out.add(out.last + (points[i] - points[i - 1]).distance);
    }
    return out;
  }

  /// The point [at] along the line [points], whose points lie [along] it,
  /// and the way along it there.
  static (Offset, Offset) _pointOn(
    List<Offset> points,
    List<double> along,
    double at,
  ) {
    int i = 1;
    while (i < points.length - 1 && along[i] < at) {
      i++;
    }
    final double span = along[i] - along[i - 1];
    final double t = span <= 0
        ? 0
        : ((at - along[i - 1]) / span).clamp(0.0, 1.0);
    final Offset way = points[i] - points[i - 1];
    return (
      Offset.lerp(points[i - 1], points[i], t)!,
      way / math.max(way.distance, 1e-9),
    );
  }

  /// The points of the line [points], whose points lie [along] it, from
  /// [from] along it to [to], either way, its ends included.
  static List<Offset> _between(
    List<Offset> points,
    List<double> along,
    double from,
    double to,
  ) {
    final (Offset start, Offset _) = _pointOn(points, along, from);
    final (Offset end, Offset _) = _pointOn(points, along, to);
    final double low = math.min(from, to);
    final double high = math.max(from, to);
    final List<Offset> inner = <Offset>[
      for (int i = 0; i < points.length; i++)
        if (along[i] > low && along[i] < high) points[i],
    ];
    return <Offset>[start, ...(from <= to ? inner : inner.reversed), end];
  }

  static int _rowAt(Float64List arc, double at) {
    int i = 0;
    while (i < arc.length - 1 && arc[i + 1] <= at) {
      i++;
    }
    return i;
  }

  static List<Offset> _dedupe(List<Offset> points) {
    final List<Offset> out = <Offset>[];
    for (final Offset p in points) {
      if (out.isEmpty || (out.last - p).distance > 1e-6) {
        out.add(p);
      }
    }
    if (out.length > 1 && (out.first - out.last).distance <= 1e-6) {
      out.removeLast();
    }
    return out;
  }

  static int _nearest(List<Offset> points, Offset p) {
    int best = 0;
    double least = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final double d = (points[i] - p).distanceSquared;
      if (d < least) {
        least = d;
        best = i;
      }
    }
    return best;
  }

  static double _area(List<Offset> points) {
    double sum = 0;
    for (int i = 0; i < points.length; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % points.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum / 2;
  }

  static Rect _bounds(List<Offset> points) {
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
}

/// Whether [p] lies inside the closed outline [points].
bool _inside(List<Offset> points, Offset p) {
  bool inside = false;
  final int n = points.length;
  for (int i = 0, j = n - 1; i < n; j = i++) {
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
    least = math.min(least, (a + ab * t - p).distanceSquared);
  }
  return math.sqrt(least);
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
