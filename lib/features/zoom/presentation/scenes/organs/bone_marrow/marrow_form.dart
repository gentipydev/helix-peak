import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../../domain/anatomy_figure.dart';
import '../../../../domain/anatomy_tables.dart';
import '../../contour.dart';
import '../../outline_morph.dart';
import 'marrow_anatomy.dart';
import 'marrow_style.dart';

/// One line of the femur's trabeculae as laid in the scene: its points, the
/// level it comes in at (0 always, 1 and 2 as the view closes in), how
/// thick it is, and how strong.
typedef TrabecularLine = ({
  List<Offset> points,
  int level,
  double thick,
  double alpha,
});

/// The bone marrow as the zoom's organ scene draws it: the femur the
/// anatomogram draws for it, cut down its length, every shape in the
/// scene's units at its real size.
///
/// The femur is drawn from general anatomy ([MarrowAnatomy]) in its own
/// frame, stood as the figure stands its femur: leaning as the body's
/// outline of it leans, fitted to that outline's shaft, its box's middle
/// the outline's middle. The place its tissue is sampled stays the body's
/// ([site]). The step from the body draws the body's outline in toward the
/// femur's own ([outlineAt]). Everything here is geometry: what it is drawn
/// in is `MarrowArt`'s.
final class MarrowForm {
  MarrowForm({
    required List<Offset> diagram,
    required this.site,
    required double length,
    required this.view,
  }) : scale = length / MarrowAnatomy.length {
    final List<Offset> diagramDense = Contour(diagram)
        .sampled(MarrowStyle.outlineSpan)
        .points;
    lean = _leanOf(diagramDense, scale);
    _cos = math.cos(lean);
    _sin = math.sin(lean);
    // The outline, in the bone's frame, each point with the run it is on.
    final (List<Offset> knots, List<_Run> runs) = _knots();
    final List<Offset> bone = <Offset>[];
    final List<_Run> boneRuns = <_Run>[];
    final int n = knots.length;
    for (int i = 0; i < n; i++) {
      final Offset p0 = knots[(i - 1 + n) % n];
      final Offset p1 = knots[i];
      final Offset p2 = knots[(i + 1) % n];
      final Offset p3 = knots[(i + 2) % n];
      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      for (int k = 0; k < MarrowStyle.outlineSpan; k++) {
        final double t = k / MarrowStyle.outlineSpan;
        final double u = 1 - t;
        bone.add(
          p1 * (u * u * u) +
              c1 * (3 * u * u * t) +
              c2 * (3 * u * t * t) +
              p2 * (t * t * t),
        );
        boneRuns.add(runs[i]);
      }
    }
    // Its box's middle, stood, is the body's outline's.
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;
    for (final Offset p in bone) {
      final Offset q = _stand(p);
      left = math.min(left, q.dx);
      right = math.max(right, q.dx);
      top = math.min(top, q.dy);
      bottom = math.max(bottom, q.dy);
    }
    _middle = Offset((left + right) / 2, (top + bottom) / 2);
    // Drawn the same way round as the body's outline, so the one can be
    // drawn in toward the other.
    final List<Offset> placed = <Offset>[for (final Offset p in bone) place(p)];
    if (_area(placed).sign != _area(diagramDense).sign) {
      _reverse(bone);
      _reverse(boneRuns);
      _reverse(placed);
    }
    _boneOutline = bone;
    _runs = boneRuns;
    outlinePoints = placed;
    outline = _polygon(placed);
    box = _bounds(placed);
    _inward = _area(bone) > 0 ? 1.0 : -1.0;
    _morph = OutlineMorph(
      template: placed,
      diagram: diagramDense,
      diagramPath: Contour(diagram).toPath(),
      count: MarrowStyle.morphPoints,
      bed: mm(MarrowStyle.bed),
      marks: _marks,
    );
  }

  /// The form for [anatomy]'s bone marrow, where the body draws it as
  /// [part], in a view [view] metres across.
  factory MarrowForm.place({
    required AnatomyPart part,
    required TissueAnatomy anatomy,
    required double view,
  }) {
    final double real = anatomy.metres / part.extent;
    Offset placed(Offset p) => (p - part.centre) * (real / view);
    return MarrowForm(
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

  /// How far the shaft leans from upright, its top out to the side: the
  /// body's outline's, fitted.
  late final double lean;
  late final double _cos;
  late final double _sin;
  late final Offset _middle;

  /// [p], in the bone's own frame, stood as the femur stands, in
  /// millimetres.
  Offset _stand(Offset p) =>
      Offset(p.dx * _cos - p.dy * _sin, p.dx * _sin + p.dy * _cos);

  /// A point of the bone's own frame, in millimetres, in the scene.
  Offset place(Offset mm) => (_stand(mm) - _middle) * scale;

  /// A point of the scene, in the bone's own frame, in millimetres.
  Offset toBone(Offset p) {
    final Offset q = p / scale + _middle;
    return Offset(q.dx * _cos + q.dy * _sin, -q.dx * _sin + q.dy * _cos);
  }

  /// A way in the bone's frame, stood, as a unit in the scene.
  Offset stood(Offset way) {
    final Offset q = _stand(way);
    return q / q.distance;
  }

  /// [millimetres] of the real femur, in the scene's units.
  double mm(double millimetres) => millimetres * scale;

  List<Offset> placedAll(List<Offset> mm) => <Offset>[
    for (final Offset p in mm) place(p),
  ];

  // The outline, and the step from the body.

  /// The femur's outline: its points, followed closely, the same way round
  /// as the body's, their path and their box.
  late final List<Offset> outlinePoints;
  late final Path outline;
  late final Rect box;

  late final List<Offset> _boneOutline;
  late final List<_Run> _runs;

  /// Which way into the femur the outline's left hand points: 1 or -1.
  late final double _inward;

  late final OutlineMorph _morph;

  /// The outline the step from the body draws: the body's own at [settle]
  /// 0, the femur's at 1, drawn in by [bed] toward the bed it lies on.
  List<Offset> outlineAt(double settle, {double bed = 0}) =>
      _morph.at(settle, bed: bed);

  /// The path [outlineAt] draws: at [settle] 0 the very curve the body's
  /// outline is drawn by.
  Path pathAt(double settle, {double bed = 0}) =>
      _morph.pathAt(settle, bed: bed);

  /// Whether [p] lies inside the femur's outline.
  bool contains(Offset p) => _inside(outlinePoints, p);

  // The cortex and the cartilage, point for point with the outline.

  /// How thick the cartilage is at each point of the outline, and the
  /// cortex under it, in millimetres.
  late final Float64List cartilage = () {
    final Float64List out = Float64List(_boneOutline.length);
    for (int i = 0; i < out.length; i++) {
      out[i] = _cartilageAt(i);
    }
    return out;
  }();

  late final Float64List cortex = () {
    final int n = _boneOutline.length;
    Float64List t = Float64List(n);
    for (int i = 0; i < n; i++) {
      t[i] = _cortexAt(i);
    }
    for (int pass = 0; pass < MarrowStyle.cortexSmoothing; pass++) {
      final Float64List next = Float64List(n);
      for (int i = 0; i < n; i++) {
        next[i] =
            0.25 * t[(i - 1 + n) % n] + 0.5 * t[i] + 0.25 * t[(i + 1) % n];
      }
      t = next;
    }
    return t;
  }();

  /// How much of the cartilage at each point of the outline is the fovea's,
  /// where the ligament of the head holds, from 0 to 1.
  late final Float64List fovea = () {
    final Float64List out = Float64List(_boneOutline.length);
    const Offset head = MarrowAnatomy.head;
    for (int i = 0; i < out.length; i++) {
      if (_runs[i] == _Run.head) {
        final Offset p = _boneOutline[i];
        final double a =
            (math.atan2(p.dy - head.dy, p.dx - head.dx) * 180 / math.pi + 360) %
            360;
        out[i] = _headCartilage(a).$2;
      }
    }
    return out;
  }();

  /// The way out of the femur at each point of its outline, in its frame.
  late final List<Offset> _outward = () {
    final List<Offset> p = _boneOutline;
    final int n = p.length;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t = p[(i + 1) % n] - p[(i - 1 + n) % n];
          final double length = t.distance;
          return length <= 0
              ? Offset.zero
              : Offset(-t.dy, t.dx) / length * -_inward;
        }(),
    ];
  }();

  /// The bone's surface under its cartilage, and its inner wall, the
  /// marrow's edge, in the bone's frame: each point for point with the
  /// outline.
  late final List<Offset> _surfaceBone = <Offset>[
    for (int i = 0; i < _boneOutline.length; i++)
      _boneOutline[i] - _outward[i] * cartilage[i],
  ];

  late final List<Offset> _wallBone = () {
    final int n = _boneOutline.length;
    List<Offset> wall = <Offset>[
      for (int i = 0; i < n; i++)
        _boneOutline[i] - _outward[i] * (cartilage[i] + cortex[i]),
    ];
    // Evened out where a bump folds it, the lesser trochanter's.
    for (int pass = 0; pass < 3; pass++) {
      wall = <Offset>[
        for (int i = 0; i < n; i++)
          wall[(i - 1 + n) % n] * 0.25 +
              wall[i] * 0.5 +
              wall[(i + 1) % n] * 0.25,
      ];
    }
    return wall;
  }();

  /// The bone's surface and its inner wall, in the scene.
  late final List<Offset> surface = placedAll(_surfaceBone);
  late final List<Offset> wall = placedAll(_wallBone);

  /// The marrow: everything inside the bone's inner wall.
  late final Path marrow = _polygon(wall);

  /// The runs of the outline the cartilage covers, as index ranges.
  late final List<(int, int)> cartilageRuns = () {
    final List<(int, int)> out = <(int, int)>[];
    final int n = cartilage.length;
    // Start where there is none, so no run wraps round the end.
    int start = 0;
    while (start < n && cartilage[start] > 0) {
      start++;
    }
    int? from;
    for (int k = 1; k <= n; k++) {
      final int i = (start + k) % n;
      final bool covered = cartilage[i] > 0;
      if (covered && from == null) {
        from = i;
      } else if (!covered && from != null) {
        out.add((from, (i - 1 + n) % n));
        from = null;
      }
    }
    return out;
  }();

  // The marrow's regions.

  /// The red marrow: the upper end below the head's scar and the greater
  /// trochanter's, above its edge across the cavity.
  late final Path red = Path.combine(
    PathOperation.intersect,
    marrow,
    _polygon(
      placedAll(<Offset>[
        ..._curve(MarrowAnatomy.headScar, 6),
        const Offset(-70, -177),
        const Offset(-70, -104),
        ..._curve(MarrowAnatomy.redEdge, 8),
        const Offset(45, -117),
        const Offset(45, -183),
        ..._curve(MarrowAnatomy.trochanterScar, 6).reversed,
        const Offset(-5, -230),
        const Offset(-16.8, -230),
      ]),
    ),
  );

  /// Whether [p], in the bone's frame, lies in the red marrow.
  bool inRed(Offset p) => red.contains(place(p));

  /// The growth plates' scars, in the scene.
  late final List<List<Offset>> scars = <List<Offset>>[
    for (final List<Offset> scar in <List<Offset>>[
      MarrowAnatomy.headScar,
      MarrowAnatomy.trochanterScar,
      MarrowAnatomy.lowerScar,
    ])
      placedAll(_curve(scar, 6)),
  ];

  // The trabeculae.

  /// The marrow, rastered in the bone's frame, to keep the trabeculae in.
  late final _Mask _mask = _Mask(_wallBone, MarrowStyle.maskCell);

  /// Every line of the trabeculae, in the scene: the streams of each group,
  /// each wavering a little, and the struts bracing each to its neighbours,
  /// which make the streams a lattice.
  late final List<TrabecularLine> trabeculae = () {
    final math.Random random = math.Random(MarrowStyle.seed);
    return <TrabecularLine>[
      for (final Trabeculae group in MarrowAnatomy.upper)
        ..._family(_streams(group, random), group.apart, group.thick, random),
      ..._family(
        _longitudinal(),
        MarrowAnatomy.longitudinalApart,
        MarrowAnatomy.longitudinalThick,
        random,
      ),
    ];
  }();

  /// A group of the upper femur's streams: each arising on the inner wall
  /// between the group's two origins, leaving it as the group says and
  /// arriving where it ends, square to the head's surface where it ends in
  /// the head; each its own place in the group, in the bone's frame.
  List<_Stream> _streams(Trabeculae group, math.Random random) {
    final double span = math.max(
      (group.to - group.from).distance,
      (group.endTo - group.endFrom).distance,
    );
    final int count = math.max(4, (span / group.apart).round());
    return <_Stream>[
      for (int k = 0; k < count; k++)
        () {
          final double t =
              (k +
                  0.5 +
                  MarrowStyle.streamJitter * (random.nextDouble() - 0.5)) /
              count;
          final (Offset start, Offset _) = _onWall(
            Offset.lerp(group.from, group.to, t)!,
          );
          final (Offset end, Offset out) = _onWall(
            Offset.lerp(group.endFrom, group.endTo, t)!,
          );
          final Offset leave = _unit(
            Offset.lerp(group.leaveFrom, group.leaveTo, t)!,
          );
          final Offset arrive = group.toHead
              ? out
              : _unit(Offset.lerp(group.arriveFrom, group.arriveTo, t)!);
          final double length = (end - start).distance;
          return (
            k: k,
            points: _cubic(
              start,
              start + leave * (length * MarrowStyle.leaveReach),
              end - arrive * (length * MarrowStyle.arriveReach),
              end,
            ),
            faint: false,
          );
        }(),
    ];
  }

  /// The lower femur's longitudinal streams: each leaving the shaft's inner
  /// wall where it flares out past it, or, near the middle, from among the
  /// others, thin and faint, straight down to the scar and then curving to
  /// meet the joint square.
  List<_Stream> _longitudinal() {
    final List<_Stream> out = <_Stream>[];
    const double apart = MarrowAnatomy.longitudinalApart;
    final double left = _mask.left + apart;
    final double right = _mask.right - apart;
    final int count = ((right - left) / apart).floor();
    final double middle = _wallMiddleAt(MarrowAnatomy.longitudinalTop);
    for (int k = 0; k <= count; k++) {
      final double x = left + k * apart;
      // Down the shaft until the marrow reaches out to it.
      double y = MarrowAnatomy.longitudinalTop;
      while (y < MarrowAnatomy.cavityBottom + 80 && !_mask.has(Offset(x, y))) {
        y += MarrowStyle.lineStep;
      }
      if (!_mask.has(Offset(x, y))) {
        continue;
      }
      final double scar = _scarAt(x);
      if (scar <= y + 2) {
        continue;
      }
      final Offset bend = Offset(x, scar);
      // On down to the joint's inner surface below it.
      double floor = scar;
      while (_mask.has(Offset(x, floor + MarrowStyle.lineStep))) {
        floor += MarrowStyle.lineStep;
      }
      final (Offset end, Offset outward) = _onWall(Offset(x, floor + 1));
      final double drop = (end - bend).distance;
      out.add((
        k: k,
        points: <Offset>[
          for (double v = y; v < scar; v += MarrowStyle.lineStep) Offset(x, v),
          ..._cubic(
            bend,
            bend + const Offset(0, 1) * (drop * MarrowStyle.leaveReach),
            end - outward * (drop * MarrowStyle.arriveReach),
            end,
          ),
        ],
        faint: (x - middle).abs() < MarrowStyle.centralReach,
      ));
    }
    return out;
  }

  /// A family of streams laid as lines: each wavering a little about its
  /// course, and braced to its neighbours by struts across the gap between
  /// them, every few gaps along it, at the level the pair of them is drawn
  /// at. [apart] is how far apart the streams are at the finest, [thick]
  /// how thick.
  List<TrabecularLine> _family(
    List<_Stream> streams,
    double apart,
    double thick,
    math.Random random,
  ) {
    final List<TrabecularLine> out = <TrabecularLine>[];
    int levelOf(_Stream s) =>
        s.faint ? math.max(1, _levelOf(s.k)) : _levelOf(s.k);
    final List<List<Offset>> waved = <List<Offset>>[
      for (final _Stream s in streams) _waved(s.points, apart, random),
    ];
    for (int i = 0; i < streams.length; i++) {
      for (final List<Offset> run in _kept(waved[i])) {
        out.add((
          points: placedAll(run),
          level: levelOf(streams[i]),
          thick: thick,
          alpha: streams[i].faint ? MarrowStyle.centralAlpha : 1,
        ));
      }
    }
    for (int level = 0; level < 3; level++) {
      final List<int> members = <int>[
        for (int i = 0; i < streams.length; i++)
          if (levelOf(streams[i]) <= level) i,
      ];
      for (int m = 0; m + 1 < members.length; m++) {
        final int a = members[m];
        final int b = members[m + 1];
        if (math.max(levelOf(streams[a]), levelOf(streams[b])) != level) {
          continue;
        }
        final double gap = (streams[b].k - streams[a].k) * apart;
        final bool faint = streams[a].faint || streams[b].faint;
        for (final List<Offset> strut in _struts(
          waved[a],
          waved[b],
          gap,
          random,
        )) {
          for (final List<Offset> run in _kept(strut)) {
            out.add((
              points: placedAll(run),
              level: level,
              thick: thick * MarrowStyle.strutThick,
              alpha: faint ? MarrowStyle.centralAlpha : 1,
            ));
          }
        }
      }
    }
    return out;
  }

  /// [points] wavering about their course, a little more than a tenth of
  /// the gap to a neighbour either way, over a few gaps, not at all where
  /// they leave and meet the bone's walls.
  static List<Offset> _waved(
    List<Offset> points,
    double apart,
    math.Random random,
  ) {
    final int n = points.length;
    if (n < 3) {
      return points;
    }
    final double phase = random.nextDouble() * 2 * math.pi;
    final double phase2 = random.nextDouble() * 2 * math.pi;
    const double wave = MarrowStyle.waveLength;
    final List<double> along = <double>[0];
    for (int i = 1; i < n; i++) {
      along.add(along.last + (points[i] - points[i - 1]).distance);
    }
    final double total = along.last;
    return <Offset>[
      for (int i = 0; i < n; i++)
        () {
          final Offset t =
              points[math.min(n - 1, i + 1)] - points[math.max(0, i - 1)];
          final double length = t.distance;
          if (length <= 0) {
            return points[i];
          }
          final Offset normal = Offset(-t.dy, t.dx) / length;
          final double s = along[i];
          final double taper = math.min(1.0, math.min(s, total - s) / wave);
          final double w =
              math.sin(2 * math.pi * s / wave + phase) +
              0.5 * math.sin(2 * math.pi * s / (0.45 * wave) + phase2);
          return points[i] + normal * (MarrowStyle.waveAmp * apart * taper * w);
        }(),
    ];
  }

  /// Struts from [a] across to [b], [gap] apart, every few gaps along [a],
  /// each from a point of it to the nearest point of [b], where that is
  /// near enough to be its neighbour there.
  static List<List<Offset>> _struts(
    List<Offset> a,
    List<Offset> b,
    double gap,
    math.Random random,
  ) {
    final List<List<Offset>> out = <List<Offset>>[];
    double next = gap * MarrowStyle.strutEvery * (0.5 + random.nextDouble());
    double along = 0;
    for (int i = 1; i < a.length; i++) {
      along += (a[i] - a[i - 1]).distance;
      if (along < next) {
        continue;
      }
      next =
          along +
          gap *
              (MarrowStyle.strutEvery +
                  MarrowStyle.strutJitter * (random.nextDouble() - 0.5));
      final Offset p = a[i];
      Offset q = b.first;
      double nearest = double.infinity;
      for (final Offset c in b) {
        final double d = (c - p).distance;
        if (d < nearest) {
          nearest = d;
          q = c;
        }
      }
      if (nearest > gap * MarrowStyle.strutReach || nearest <= 0) {
        continue;
      }
      final int steps = math.max(2, (nearest / MarrowStyle.lineStep).ceil());
      out.add(<Offset>[
        for (int k = 0; k <= steps; k++) Offset.lerp(p, q, k / steps)!,
      ]);
    }
    return out;
  }

  /// A line's level: every fourth always drawn, every second as the view
  /// closes in, the rest closer still.
  static int _levelOf(int k) => k % 4 == 0
      ? 0
      : k.isEven
      ? 1
      : 2;

  /// The point of the inner wall nearest [p], in the bone's frame, drawn in
  /// a little off it, and the way out of the bone there.
  (Offset, Offset) _onWall(Offset p) {
    int best = 0;
    double nearest = double.infinity;
    for (int i = 0; i < _wallBone.length; i++) {
      final double d = (_wallBone[i] - p).distance;
      if (d < nearest) {
        nearest = d;
        best = i;
      }
    }
    final Offset out = _outward[best];
    return (_wallBone[best] - out * MarrowStyle.wallClear, out);
  }

  /// The middle of the marrow across, at height [y] in the bone's frame.
  double _wallMiddleAt(double y) {
    final List<double> xs = _crossings(_wallBone, y);
    return xs.length < 2 ? 0 : (xs.first + xs.last) / 2;
  }

  /// The lower scar's height at [x], in the bone's frame.
  late final List<Offset> _lowerScar = _curve(MarrowAnatomy.lowerScar, 6);

  double _scarAt(double x) {
    final List<Offset> s = _lowerScar;
    if (x <= s.first.dx) {
      return s.first.dy;
    }
    for (int i = 0; i + 1 < s.length; i++) {
      if (x <= s[i + 1].dx) {
        final double t = (x - s[i].dx) / (s[i + 1].dx - s[i].dx);
        return s[i].dy + (s[i + 1].dy - s[i].dy) * t;
      }
    }
    return s.last.dy;
  }

  /// [points]' runs that lie in the marrow.
  List<List<Offset>> _kept(List<Offset> points) {
    final List<List<Offset>> out = <List<Offset>>[];
    List<Offset> run = <Offset>[];
    for (final Offset p in points) {
      if (_mask.has(p)) {
        run.add(p);
      } else if (run.isNotEmpty) {
        if (run.length > 1) {
          out.add(run);
        }
        run = <Offset>[];
      }
    }
    if (run.length > 1) {
      out.add(run);
    }
    return out;
  }

  // The nutrient artery.

  /// Its canal through the cortex, and its branches and twigs in the
  /// cavity, in the scene.
  late final (Offset, Offset) canal = (
    place(MarrowAnatomy.foramen),
    place(MarrowAnatomy.canalInner),
  );
  late final List<Offset> ascending = placedAll(
    _curve(MarrowAnatomy.ascending, 6),
  );
  late final List<Offset> descending = placedAll(
    _curve(MarrowAnatomy.descending, 6),
  );
  late final List<(Offset, Offset)> twigs = <(Offset, Offset)>[
    for (final (Offset a, Offset b) in MarrowAnatomy.twigs)
      (place(a), place(b)),
  ];

  /// Where the branches fade, along the shaft: the ascending's top and the
  /// descending's foot, in the scene.
  late final (Offset, Offset) ascendingFade = (
    place(MarrowAnatomy.ascending.last),
    place(
      MarrowAnatomy.ascending.last +
          const Offset(0, MarrowAnatomy.ascendingFade),
    ),
  );
  late final (Offset, Offset) descendingFade = (
    place(MarrowAnatomy.descending.last),
    place(
      MarrowAnatomy.descending.last -
          const Offset(0, MarrowAnatomy.descendingFade),
    ),
  );
  // Where each part is named, and the columns the names are set in.

  late final Offset trabecularName = place(MarrowAnatomy.trabecularName);
  late final Offset corticalName = place(MarrowAnatomy.corticalName);
  late final Offset yellowName = place(MarrowAnatomy.yellowName);

  /// The outline's outermost points to the left and the right at the height
  /// of [at], in the scene.
  (Offset, Offset) edgesAt(Offset at) {
    final List<double> xs = _crossings(outlinePoints, at.dy);
    if (xs.length < 2) {
      return (at, at);
    }
    return (Offset(xs.first, at.dy), Offset(xs.last, at.dy));
  }

  /// Where the step from the body meets the femur's outline and the body's,
  /// beside their tops: the head's medial side, the greater trochanter's
  /// lateral one, the condyles' outer sides, and either side of the shaft
  /// at three heights, each picked out of either outline alike, so that
  /// nothing slides along the shaft as the one draws in to the other. (Not
  /// their feet: of two condyles standing nearly level, either may hang
  /// the lower.)
  static final List<int Function(List<Offset>)> _marks =
      <int Function(List<Offset>)>[
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0, 0.2),
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0, 0.25),
        (List<Offset> p) => OutlineMarks.outermost(p, 1, 0.85, 1),
        (List<Offset> p) => OutlineMarks.outermost(p, -1, 0.85, 1),
        for (final double side in <double>[-1, 1])
          for (final double down in MarrowStyle.shaftMarks)
            (List<Offset> p) => OutlineMarks.level(p, side, down),
      ];

  // The outline in the bone's frame, run by run.

  (List<Offset>, List<_Run>) _knots() {
    final List<Offset> knots = <Offset>[];
    final List<_Run> runs = <_Run>[];
    void add(Iterable<Offset> points, _Run run) {
      for (final Offset p in points) {
        knots.add(p);
        runs.add(run);
      }
    }

    const Offset head = MarrowAnatomy.head;
    const double r = MarrowAnatomy.headRadius;
    const double angle = MarrowAnatomy.neckShaft * math.pi / 180;
    final Offset along = Offset(-math.sin(angle), math.cos(angle));
    final Offset across = Offset(-along.dy, along.dx);
    final double neck = (head - MarrowAnatomy.neckFoot).distance;
    final double junction = math.sqrt(
      r * r - MarrowAnatomy.neckWaist * MarrowAnatomy.neckWaist,
    );
    Offset onNeck(double s, double w) =>
        MarrowAnatomy.neckFoot + along * s + across * w;
    final Offset upper = onNeck(neck - junction, MarrowAnatomy.neckWaist);
    final Offset lower = onNeck(neck - junction, -MarrowAnatomy.neckWaist);
    double degrees(Offset p) =>
        math.atan2(p.dy - head.dy, p.dx - head.dx) * 180 / math.pi;
    final double from = degrees(lower);
    final double to = degrees(upper) + 360;
    // The head, from its lower junction with the neck round its medial side
    // and its top to its upper one.
    const int steps = 46;
    add(<Offset>[
      for (int k = 0; k <= steps; k++)
        () {
          final double rad = (from + (to - from) * k / steps) * math.pi / 180;
          return head + Offset(math.cos(rad), math.sin(rad)) * r;
        }(),
    ], _Run.head);
    add(<Offset>[
      onNeck(neck - junction - 10, MarrowAnatomy.neckWaist + 0.3),
    ], _Run.neck);
    add(MarrowAnatomy.trochanter, _Run.lateral);
    add(MarrowAnatomy.lateralShaft, _Run.lateral);
    add(MarrowAnatomy.condyles, _Run.condyles);
    add(MarrowAnatomy.medialShaft, _Run.medial);
    add(MarrowAnatomy.lesserTrochanter, _Run.medial);
    add(<Offset>[
      onNeck(neck - junction - 9, -MarrowAnatomy.neckWaist - 1.2),
    ], _Run.medial);
    return (knots, runs);
  }

  double _cartilageAt(int i) {
    final Offset p = _boneOutline[i];
    switch (_runs[i]) {
      case _Run.head:
        const Offset head = MarrowAnatomy.head;
        final double a =
            (math.atan2(p.dy - head.dy, p.dx - head.dx) * 180 / math.pi + 360) %
            360;
        return _headCartilage(a).$1 * _margin(i, _Run.head);
      case _Run.condyles:
        for (final (Offset a, Offset b) in <(Offset, Offset)>[
          MarrowAnatomy.lateralCartilage,
          MarrowAnatomy.medialCartilage,
        ]) {
          final int ia = _nearest(a);
          final int ib = _nearest(b);
          final int lo = math.min(ia, ib);
          final int hi = math.max(ia, ib);
          if (i >= lo && i <= hi) {
            const double reach = MarrowAnatomy.cartilageMargin;
            final double inFrom = _arcBetween(lo, i);
            final double inTo = _arcBetween(i, hi);
            return MarrowAnatomy.condyleCartilage *
                _smooth(inFrom / reach) *
                _smooth(inTo / reach);
          }
        }
        return 0;
      case _Run.neck || _Run.lateral || _Run.medial:
        return 0;
    }
  }

  /// The head's cartilage at [degrees] round it: how thick, thickest round
  /// the fovea and thinner toward the rims, and how much of it is the fovea,
  /// bare of cartilage, the ligament of the head holding there.
  static (double, double) _headCartilage(double degrees) {
    final double d = (degrees - MarrowAnatomy.fovea).abs();
    final double past = math.max(0, d - MarrowAnatomy.foveaReach);
    return (
      MarrowAnatomy.rimCartilage +
          (MarrowAnatomy.headCartilage - MarrowAnatomy.rimCartilage) *
              _smooth(1 - past / 110),
      1 - _smooth(past / 3),
    );
  }

  double _cortexAt(int i) {
    final Offset p = _boneOutline[i];
    switch (_runs[i]) {
      case _Run.head:
        return MarrowAnatomy.subchondral;
      case _Run.neck:
        return MarrowAnatomy.neckCortex;
      case _Run.lateral:
        return _profile(MarrowAnatomy.lateralCortex, p.dy);
      case _Run.medial:
        return _profile(MarrowAnatomy.medialCortex, p.dy);
      case _Run.condyles:
        // The notch's roof, thickened; the joint's shell; the epicondyles'
        // sides as the shaft's.
        if (p.dx > 1 && p.dx < 15 && p.dy < 212) {
          return MarrowAnatomy.notchRoof;
        }
        if (p.dy < 205) {
          return _profile(
            p.dx > 0 ? MarrowAnatomy.lateralCortex : MarrowAnatomy.medialCortex,
            p.dy,
          );
        }
        return MarrowAnatomy.subchondral;
    }
  }

  /// How far the cartilage of [run] has come in from its margin at point
  /// [i], from 0 to 1.
  double _margin(int i, _Run run) {
    final int n = _runs.length;
    int a = i;
    while (_runs[(a - 1 + n) % n] == run && (a - 1 + n) % n != i) {
      a = (a - 1 + n) % n;
    }
    int b = i;
    while (_runs[(b + 1) % n] == run && (b + 1) % n != i) {
      b = (b + 1) % n;
    }
    const double reach = MarrowAnatomy.cartilageMargin;
    return _smooth(_arcBetween(a, i) / reach) *
        _smooth(_arcBetween(i, b) / reach);
  }

  /// How far along the outline from point [from] to point [to], forward.
  double _arcBetween(int from, int to) {
    final int n = _boneOutline.length;
    double sum = 0;
    for (int i = from; i != to; i = (i + 1) % n) {
      sum += (_boneOutline[(i + 1) % n] - _boneOutline[i]).distance;
    }
    return sum;
  }

  int _nearest(Offset p) {
    int best = 0;
    double nearest = double.infinity;
    for (int i = 0; i < _boneOutline.length; i++) {
      final double d = (_boneOutline[i] - p).distance;
      if (d < nearest) {
        nearest = d;
        best = i;
      }
    }
    return best;
  }

  // Helpers.

  static double _profile(List<(double, double)> stations, double y) {
    if (y <= stations.first.$1) {
      return stations.first.$2;
    }
    for (int i = 0; i + 1 < stations.length; i++) {
      final (double y0, double t0) = stations[i];
      final (double y1, double t1) = stations[i + 1];
      if (y <= y1) {
        return t0 + (t1 - t0) * (y - y0) / (y1 - y0);
      }
    }
    return stations.last.$2;
  }

  /// The shaft's lean, from upright with its top out to the side, of the
  /// outline [diagram] in the scene, whose millimetre is [scale]: fitted to
  /// the middles of its spans down the shaft.
  static double _leanOf(List<Offset> diagram, double scale) {
    final List<Offset> middles = <Offset>[];
    const int rows = 60;
    for (int k = 0; k < rows; k++) {
      final double y =
          (MarrowStyle.leanFrom +
              (MarrowStyle.leanTo - MarrowStyle.leanFrom) * k / (rows - 1)) *
          scale;
      final List<double> xs = _crossings(diagram, y);
      if (xs.length >= 2) {
        middles.add(Offset((xs.first + xs.last) / 2, y));
      }
    }
    if (middles.length < 2) {
      return 0;
    }
    double mx = 0;
    double my = 0;
    for (final Offset p in middles) {
      mx += p.dx;
      my += p.dy;
    }
    mx /= middles.length;
    my /= middles.length;
    double across = 0;
    double down = 0;
    for (final Offset p in middles) {
      across += (p.dy - my) * (p.dx - mx);
      down += (p.dy - my) * (p.dy - my);
    }
    return down <= 0 ? 0 : -math.atan(across / down);
  }

  /// Where the closed outline [points] crosses the level [y], left to right.
  static List<double> _crossings(List<Offset> points, double y) {
    final List<double> xs = <double>[];
    final int n = points.length;
    for (int i = 0; i < n; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % n];
      if ((a.dy <= y) != (b.dy <= y)) {
        xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
      }
    }
    return xs..sort();
  }

  /// The open curve through [points], [per] points from each to the next.
  static List<Offset> _curve(List<Offset> points, int per) {
    final int n = points.length;
    Offset knot(int i) => i < 0
        ? points[0] * 2 - points[1]
        : i >= n
        ? points[n - 1] * 2 - points[n - 2]
        : points[i];
    final List<Offset> out = <Offset>[];
    for (int i = 0; i + 1 < n; i++) {
      final Offset p0 = knot(i - 1);
      final Offset p1 = knot(i);
      final Offset p2 = knot(i + 1);
      final Offset p3 = knot(i + 2);
      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      for (int k = 0; k < per; k++) {
        final double t = k / per;
        final double u = 1 - t;
        out.add(
          p1 * (u * u * u) +
              c1 * (3 * u * u * t) +
              c2 * (3 * u * t * t) +
              p2 * (t * t * t),
        );
      }
    }
    return out..add(points.last);
  }

  /// The cubic from [a] to [d] by [b] and [c], at about a line step apart.
  static List<Offset> _cubic(Offset a, Offset b, Offset c, Offset d) {
    final double reach = (b - a).distance + (c - b).distance + (d - c).distance;
    final int steps = math.max(2, (reach / MarrowStyle.lineStep).ceil());
    return <Offset>[
      for (int k = 0; k <= steps; k++)
        () {
          final double t = k / steps;
          final double u = 1 - t;
          return a * (u * u * u) +
              b * (3 * u * u * t) +
              c * (3 * u * t * t) +
              d * (t * t * t);
        }(),
    ];
  }

  static Offset _unit(Offset p) {
    final double d = p.distance;
    return d <= 0 ? Offset.zero : p / d;
  }

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static void _reverse<T>(List<T> list) {
    final List<T> reversed = list.reversed.toList();
    list
      ..clear()
      ..addAll(reversed);
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

/// The runs of the femur's outline, each with its own cortex and
/// cartilage.
enum _Run { head, neck, lateral, condyles, medial }

/// One stream of a family of trabeculae in the bone's frame: its place in
/// the family, its points, and whether it is one of the lower end's faint
/// central ones.
typedef _Stream = ({int k, List<Offset> points, bool faint});

/// The marrow rastered in the bone's frame: which cells of a grid over it
/// lie inside its inner wall.
final class _Mask {
  _Mask(List<Offset> outline, this.cell) {
    double l = double.infinity;
    double t = double.infinity;
    double r = double.negativeInfinity;
    double b = double.negativeInfinity;
    for (final Offset p in outline) {
      l = math.min(l, p.dx);
      r = math.max(r, p.dx);
      t = math.min(t, p.dy);
      b = math.max(b, p.dy);
    }
    left = l;
    top = t;
    right = r;
    bottom = b;
    _columns = ((r - l) / cell).ceil() + 1;
    _rows = ((b - t) / cell).ceil() + 1;
    _inside = Uint8List(_columns * _rows);
    for (int j = 0; j < _rows; j++) {
      final List<double> xs = MarrowForm._crossings(outline, t + j * cell);
      for (int k = 0; k + 1 < xs.length; k += 2) {
        final int from = ((xs[k] - l) / cell).ceil();
        final int to = ((xs[k + 1] - l) / cell).floor();
        for (int i = math.max(0, from); i <= math.min(_columns - 1, to); i++) {
          _inside[j * _columns + i] = 1;
        }
      }
    }
  }

  final double cell;
  late final double left;
  late final double top;
  late final double right;
  late final double bottom;
  late final int _columns;
  late final int _rows;
  late final Uint8List _inside;

  bool has(Offset p) {
    final int i = ((p.dx - left) / cell).round();
    final int j = ((p.dy - top) / cell).round();
    if (i < 0 || j < 0 || i >= _columns || j >= _rows) {
      return false;
    }
    return _inside[j * _columns + i] == 1;
  }
}

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
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
