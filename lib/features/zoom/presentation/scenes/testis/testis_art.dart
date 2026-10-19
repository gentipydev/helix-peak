import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/cell_archetypes.dart';
import '../../zoom_inks.dart';
import '../coloured_mesh.dart';
import '../specimen_light.dart';
import '../tube_course.dart';
import 'testis_anatomy.dart';
import 'testis_form.dart';
import 'testis_style.dart';

/// Where in the testis the zoom's cell lives, which its drawing lights in
/// the mark: the seminiferous tubules, for a germ cell, a Sertoli cell, a
/// peritubular cell or any other; the interstitium between them, for a
/// Leydig cell.
enum TestisHome {
  tubules,
  interstitium;

  /// Where a cell of [shape] lives.
  static TestisHome of(CellShape shape) =>
      shape == CellShape.endocrine ? interstitium : tubules;
}

/// The testis cut down its length, drawn as a fresh specimen under the
/// zoom's one lamp: its lobules each a low cushion of coiled tubules, lit,
/// on the darker interstitium, pale septa between them, the pearly tunica
/// round them, the mediastinum with the rete's dark channels; and round it
/// the epididymis, knobbly and darker, its head lifted off the upper pole
/// on the efferent ductules, the vas deferens rising from its tail into
/// the cord with the testicular artery and the veins of the pampiniform
/// plexus, in the blood red, and the tunica vaginalis a faint film round
/// them all.
///
/// Where the zoom's cell lives is in the mark, by its kind and never by
/// gene: the tubules washed in it for a cell of the tubules; for a Leydig
/// cell, a dust of their clusters through the interstitium.
///
/// Everything costly is built once, for one form, one home and one set of
/// inks: meshes in the scene's units, so a frame only hands them on.
final class TestisArt {
  TestisArt(this.form, this.inks, {required this.home})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final TestisForm form;
  final ZoomInks inks;
  final TestisHome home;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  bool get _leydig => home == TestisHome.interstitium;

  /// What shows between the tubules, and what the step from the body draws
  /// the testis's bed in.
  static Color bedOf(ZoomInks inks) =>
      inks.shade(TestisStyle.interstitiumShade);

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final SpecimenTone _tubuleTone = _tone(inks.lit(TestisStyle.tubuleLit));
  late final SpecimenTone _tunicaTone = _tone(inks.lit(TestisStyle.tunicaLit));
  late final SpecimenTone _mediastinumTone = _tone(
    inks.lit(TestisStyle.mediastinumLit),
  );
  late final SpecimenTone _epididymisTone = _tone(
    inks.lit(TestisStyle.epididymisLit),
  );
  late final SpecimenTone _ductuleTone = _tone(
    inks.lit(TestisStyle.ductuleLit),
  );
  late final SpecimenTone _vasTone = _tone(inks.lit(TestisStyle.vasLit));
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, TestisStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, TestisStyle.vein)!,
  );

  static final List<double> _columns = <double>[
    for (final double u in TestisStyle.columns.reversed) -u,
    ...TestisStyle.columns.skip(1),
  ];

  // The testis.

  /// The tubules, each a lit tube lying on its lobule's cushion.
  late final List<ui.Vertices> _tubules = _build(_layTubules);

  void _layTubules(ColouredMesh mesh) {
    final double half = form.mm(TestisStyle.tubule / 2);
    final double wash = _leydig ? 0 : TestisStyle.wash;
    final math.Random random = math.Random(101);
    final List<double> lobuleTone = <double>[
      for (int k = 0; k < form.lobules.length; k++)
        1 + TestisStyle.lobuleTone * (2 * random.nextDouble() - 1),
    ];
    for (final TestisTubule tubule in form.tubules) {
      final List<Offset> points = tubule.points;
      final int n = points.length;
      if (n < 2) {
        continue;
      }
      final TestisLobule lobule = form.lobules[tubule.lobule];
      final double tone =
          lobuleTone[tubule.lobule] *
          (1 + TestisStyle.tubuleTone * (2 * random.nextDouble() - 1));
      mesh.begin(3 * n);
      final int first = mesh.next;
      for (int i = 0; i < n; i++) {
        final Offset a =
            points[tubule.closed ? (i - 1 + n) % n : math.max(0, i - 1)];
        final Offset b =
            points[tubule.closed ? (i + 1) % n : math.min(n - 1, i + 1)];
        final Offset t = b - a;
        final double length = t.distance;
        final Offset across = length <= 0
            ? const Offset(0, 1)
            : Offset(-t.dy, t.dx) / length;
        final (double cx, double cy, double cz) = lobule.cushion.normalAt(
          points[i],
        );
        final Offset c = form.place(points[i]);
        for (final double u in const <double>[-1, 0, 1]) {
          final double side = u * _edgeTurn;
          final (double nx, double ny, double nz) = _unit(
            across.dx * side + TestisStyle.cushionTilt * cx,
            across.dy * side + TestisStyle.cushionTilt * cy,
            math.sqrt(1 - side * side),
          );
          final Offset p = c + across * (half * u);
          mesh.vertex(
            p.dx,
            p.dy,
            _palette.colour(
              _tubuleTone,
              _light.light(nx, ny, nz, form: cz) * tone,
              sheen: _light.sheen(nx, ny, nz) * 0.8,
              wash: wash,
            ),
          );
        }
      }
      final int rows = tubule.closed ? n : n - 1;
      for (int i = 0; i < rows; i++) {
        final int a = first + 3 * i;
        final int b = first + 3 * ((i + 1) % n);
        for (int k = 0; k < 2; k++) {
          mesh
            ..triangle(a + k, a + k + 1, b + k)
            ..triangle(a + k + 1, b + k + 1, b + k);
        }
      }
    }
  }

  /// How far round a tubule its edges are lit as turning, a sine.
  static const double _edgeTurn = 0.9;

  /// The tunica albuginea: a rim round the cut face, flat where it is cut
  /// and turning away toward the testis's outer face.
  late final List<ui.Vertices> _tunica = _build(_layTunica);

  void _layTunica(ColouredMesh mesh) {
    final List<Offset> outer = form.outlineMm;
    final List<Offset> inner = form.cutMm;
    final int n = outer.length;
    mesh.begin(3 * n);
    final int first = mesh.next;
    for (int i = 0; i < n; i++) {
      final Offset o = outer[i];
      final Offset c = inner[i];
      final Offset d = o - c;
      final Offset out = d.distance <= 0 ? Offset.zero : d / d.distance;
      for (final (Offset p, double turn) in <(Offset, double)>[
        (c, 0),
        ((o + c) / 2, TestisStyle.tunicaMiddle),
        (o, TestisStyle.tunicaOuter),
      ]) {
        final double nz = math.sqrt(1 - turn * turn);
        final double nx = out.dx * turn;
        final double ny = out.dy * turn;
        final Offset q = form.place(p);
        mesh.vertex(
          q.dx,
          q.dy,
          _palette.colour(
            _tunicaTone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz),
          ),
        );
      }
    }
    for (int i = 0; i < n; i++) {
      final int a = first + 3 * i;
      final int b = first + 3 * ((i + 1) % n);
      mesh
        ..triangle(a, a + 1, b)
        ..triangle(a + 1, b + 1, b)
        ..triangle(a + 1, a + 2, b + 1)
        ..triangle(a + 2, b + 2, b + 1);
    }
  }

  /// The mediastinum: fibrous, from its free edge to the tunica, a little
  /// rounded across.
  late final List<ui.Vertices> _mediastinum = _build(_layMediastinum);

  void _layMediastinum(ColouredMesh mesh) {
    final List<Offset> edge = form.edgeMm;
    final List<Offset> cut = form.cutMm;
    final int n = edge.length;
    const List<double> across = <double>[-1, -0.5, 0, 0.5, 1];
    mesh.begin(across.length * n);
    final int first = mesh.next;
    for (int i = 0; i < n; i++) {
      final Offset e = edge[i];
      Offset back = cut.first;
      for (final Offset p in cut) {
        if ((p - e).distanceSquared < (back - e).distanceSquared) {
          back = p;
        }
      }
      // Past the cut's edge, under the tunica, so it meets it.
      Offset way = back - e;
      final double length = way.distance;
      way = length <= 0 ? Offset.zero : way / length;
      final Offset b = back + way * 0.3;
      for (final double u in across) {
        final Offset p = Offset.lerp(e, b, (u + 1) / 2)!;
        final double turn = 0.35 * u;
        final double nx = way.dx * turn;
        final double ny = way.dy * turn;
        final double nz = math.sqrt(1 - turn * turn);
        final Offset q = form.place(p);
        mesh.vertex(
          q.dx,
          q.dy,
          _palette.colour(
            _mediastinumTone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz) * 0.6,
          ),
        );
      }
    }
    for (int i = 0; i + 1 < n; i++) {
      for (int k = 0; k + 1 < across.length; k++) {
        final int a = first + i * across.length + k;
        final int b = a + across.length;
        mesh
          ..triangle(a, a + 1, b)
          ..triangle(a + 1, b + 1, b);
      }
    }
  }

  /// The rete's spaces, a sponge of them, as one path.
  late final Path _rete = () {
    final Path path = Path();
    for (final (Offset at, double long, double wide, double angle)
        in form.reteSpaces) {
      final double c = math.cos(angle);
      final double s = math.sin(angle);
      path.addPolygon(<Offset>[
        for (int k = 0; k < 12; k++)
          () {
            final double a = 2 * math.pi * k / 12;
            final double x = long * math.cos(a);
            final double y = wide * math.sin(a);
            return form.place(at + Offset(x * c - y * s, x * s + y * c));
          }(),
      ], true);
    }
    return path;
  }();

  // What lies round it.

  /// The epididymis, its surface knobbly: the head's lobules, the coils of
  /// its body and tail, each a small dome with a crevice round it.
  late final List<ui.Vertices> _epididymis = _build(_layEpididymis);

  void _layEpididymis(ColouredMesh mesh) {
    final TubeCourse e = form.epididymis;
    final List<(double, double, double)> knobs = form.knobs;
    const int columns = TestisStyle.epididymisColumns;
    final List<double> us = <double>[
      for (int k = 0; k < columns; k++)
        math.sin(math.pi / 2 * (2 * k / (columns - 1) - 1)),
    ];
    final double reach = 2 * form.mm(TestisStyle.headKnob);
    mesh.begin(e.length * columns);
    final int first = mesh.next;
    int low = 0;
    for (int i = 0; i < e.length; i++) {
      final double along = e.arc[i];
      final double squeeze = form.squeezeAt(along);
      final Offset m = e.across[i];
      final Offset t = Offset(m.dy, -m.dx);
      while (low < knobs.length && knobs[low].$1 < along - reach) {
        low++;
      }
      for (final double u in us) {
        final double across = u >= 0 ? e.plus[i] * u : e.minus[i] * u;
        // The nearest knob and the next nearest, coils nearer along it than
        // across.
        double first2 = double.infinity;
        double second2 = double.infinity;
        double ds = 0;
        double dv = 0;
        double spacing = form.mm(TestisStyle.bodyKnob);
        for (
          int k = low;
          k < knobs.length && knobs[k].$1 <= along + reach;
          k++
        ) {
          final (double s, double v, double apart) = knobs[k];
          final double d2 =
              (along - s) * (along - s) * squeeze * squeeze +
              (across - v) * (across - v);
          if (d2 < first2) {
            second2 = first2;
            first2 = d2;
            ds = (along - s) * squeeze;
            dv = across - v;
            spacing = apart;
          } else if (d2 < second2) {
            second2 = d2;
          }
        }
        final double crevice = first2.isFinite && second2.isFinite
            ? (1 - (math.sqrt(second2) - math.sqrt(first2)) / (0.35 * spacing))
                  .clamp(0.0, 1.0)
            : 0.0;
        final double nzTube = math.sqrt(math.max(0, 1 - u * u));
        // Each knob a dome, its slope easing to nothing in the crevice
        // round it, where its neighbour's begins, so the light turns there
        // rather than breaking.
        final double tilt =
            TestisStyle.knobTilt / (0.5 * spacing) * (1 - crevice);
        final (double nx, double ny, double nz) = _unit(
          m.dx * u + (t.dx * ds + m.dx * dv) * tilt,
          m.dy * u + (t.dy * ds + m.dy * dv) * tilt,
          nzTube,
        );
        // The edge drawn in between two knobs.
        final double notch = u.abs() > 0.95
            ? 1 - TestisStyle.knobNotch * crevice
            : 1;
        final Offset p = e.centres[i] + m * (across * notch);
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            _epididymisTone,
            _light.light(nx, ny, nz, form: nzTube) * TestisStyle.neighbourLight,
            occlusion: TestisStyle.knobCrevice * crevice,
            sheen: _light.sheen(nx, ny, nz) * TestisStyle.neighbourLight,
          ),
        );
      }
    }
    for (int i = 0; i + 1 < e.length; i++) {
      for (int k = 0; k + 1 < columns; k++) {
        final int a = first + i * columns + k;
        final int b = a + columns;
        mesh
          ..triangle(a, a + 1, b)
          ..triangle(a + 1, b + 1, b);
      }
    }
  }

  late final List<ui.Vertices> _ductules = _build((ColouredMesh mesh) {
    for (final TubeCourse ductule in form.ductules) {
      _layTube(mesh, ductule, _ductuleTone, columns: _fine);
    }
  });

  late final List<ui.Vertices> _vas = _build(
    (ColouredMesh mesh) => _layTube(mesh, form.vas, _vasTone),
  );

  late final List<ui.Vertices> _veinsBehind = _build((ColouredMesh mesh) {
    for (final TubeCourse vein in form.veins.take(TestisAnatomy.veinsBehind)) {
      _layTube(mesh, vein, _veinTone);
    }
  });

  late final List<ui.Vertices> _artery = _build(
    (ColouredMesh mesh) => _layTube(mesh, form.artery, _arteryTone),
  );

  late final List<ui.Vertices> _veinsFront = _build((ColouredMesh mesh) {
    for (final TubeCourse vein in form.veins.skip(TestisAnatomy.veinsBehind)) {
      _layTube(mesh, vein, _veinTone);
    }
  });

  /// [tube] as a lit tube in [tone], dimmer than the testis: round it at
  /// [columns], by default the tubes' own.
  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, {
    List<double>? columns,
  }) => tube.lay(
    mesh,
    tone,
    _light,
    _palette,
    columns ?? _columns,
    brightness: TestisStyle.neighbourLight,
  );

  /// A ductule is too fine to need more than its edges and its middle.
  static const List<double> _fine = <double>[-1, 0, 1];

  // The Leydig cells, for an endocrine cell.

  /// Their clusters by size: x and y of each, in turn.
  late final List<Float32List> _leydigPoints = () {
    final int sizes = TestisStyle.leydigRadii.length;
    final List<List<double>> lists = List<List<double>>.generate(
      sizes,
      (_) => <double>[],
    );
    int sizeOf(double radius) {
      int best = 0;
      for (int k = 1; k < sizes; k++) {
        if ((form.mm(TestisStyle.leydigRadii[k] / 1000) - radius).abs() <
            (form.mm(TestisStyle.leydigRadii[best] / 1000) - radius).abs()) {
          best = k;
        }
      }
      return best;
    }

    for (final (Offset at, double radius) in <(Offset, double)>[
      ...form.leydig,
      form.siteLeydig,
    ]) {
      lists[sizeOf(radius)]
        ..add(at.dx)
        ..add(at.dy);
    }
    return <Float32List>[
      for (final List<double> l in lists) Float32List.fromList(l),
    ];
  }();

  void _paintLeydig(Canvas canvas, double line) {
    for (int k = 0; k < TestisStyle.leydigRadii.length; k++) {
      final Float32List points = _leydigPoints[k];
      if (points.isEmpty) {
        continue;
      }
      final double r = form.mm(TestisStyle.leydigRadii[k] / 1000);
      final Paint paint = Paint()..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        paint
          ..strokeWidth = math.max(
            TestisStyle.halo * r,
            TestisStyle.haloFloor * line,
          )
          ..color = inks.glow(TestisStyle.haloAlpha),
      );
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        paint
          ..strokeWidth = math.max(2 * r, TestisStyle.coreFloor * line)
          ..color = inks.glow(0.95),
      );
    }
  }

  // The shadows.

  /// The shapes that cast a shadow on what lies behind: the testis and the
  /// epididymis.
  late final Path _casting = Path()
    ..addPath(form.outline, Offset.zero)
    ..addPath(form.epididymisPath, Offset.zero);

  /// The cord's tubes' middles, for their shadows: each with its mean
  /// width.
  late final List<(Path, double)> _strands = <(Path, double)>[
    for (final TubeCourse tube in <TubeCourse>[
      form.vas,
      form.artery,
      ...form.veins,
    ])
      (tube.line, 2 * _mean(tube.radius)),
  ];

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(TestisStyle.shadowX),
      form.mm(TestisStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      _casting,
      Paint()..color = shadow.withValues(alpha: TestisStyle.shadowAlpha),
    );
    canvas.drawPath(
      _casting,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(TestisStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    for (final (Path strand, double width) in _strands) {
      canvas.drawPath(
        strand,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = shadow.withValues(alpha: 0.25),
      );
    }
    canvas.restore();
  }

  // Drawing.

  /// What the testis and what lies round it cover, their shadows included:
  /// the room a layer of them needs.
  late final Rect bounds = () {
    Rect box = form.outline
        .getBounds()
        .expandToInclude(form.epididymisPath.getBounds())
        .expandToInclude(form.sac.getBounds());
    for (final TubeCourse tube in <TubeCourse>[
      form.vas,
      form.artery,
      ...form.veins,
    ]) {
      double widest = 0;
      for (final double r in tube.radius) {
        widest = math.max(widest, r);
      }
      box = box.expandToInclude(tube.line.getBounds().inflate(widest));
    }
    return box.inflate(form.mm(TestisStyle.shadowY + TestisStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _tubules,
    _tunica,
    _mediastinum,
    _rete,
    _epididymis,
    _ductules,
    _vas,
    _veinsBehind,
    _artery,
    _veinsFront,
    _casting,
    _strands,
    form.mediastinum,
    form.septaPath,
    bounds,
    if (_leydig) _leydigPoints,
  ];

  /// Draws it all, in the scene's units at the testis's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The tunica vaginalis, a film behind it all.
    canvas.drawPath(
      form.sac,
      Paint()
        ..color = inks
            .lit(TestisStyle.sacLit)
            .withValues(alpha: TestisStyle.sacAlpha),
    );
    canvas.drawPath(
      form.sac,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = inks.lit(0.5).withValues(alpha: TestisStyle.sacEdgeAlpha),
    );
    // The cord, behind the epididymis, which lies on it.
    _draw(canvas, _vas);
    _draw(canvas, _veinsBehind);
    _draw(canvas, _artery);
    _draw(canvas, _veinsFront);
    _draw(canvas, _ductules);
    _draw(canvas, _epididymis);
    // The testis: the interstitium, the mediastinum and the rete, the
    // tubules, the septa, the tunica.
    canvas.drawPath(form.cut, Paint()..color = bedOf(inks));
    canvas.save();
    canvas.clipPath(form.mediastinum);
    _draw(canvas, _mediastinum);
    canvas.drawPath(_rete, Paint()..color = inks.shade(TestisStyle.reteShade));
    canvas.restore();
    _draw(canvas, _tubules);
    canvas.drawPath(
      form.septaPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(TestisStyle.septum),
          TestisStyle.septumFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.lit(TestisStyle.septumLit),
    );
    _draw(canvas, _tunica);
    if (_leydig) {
      _paintLeydig(canvas, line);
    }
  }

  /// Every mesh's vertices as built, for tests, each tagged with the part
  /// it draws: where each lies, in the scene's units, and its colour.
  @visibleForTesting
  List<(String, Float32List, Int32List)> get meshData {
    final List<(String, Float32List, Int32List)> out =
        <(String, Float32List, Int32List)>[];
    void add(String part, void Function(ColouredMesh) lay) {
      final ColouredMesh mesh = ColouredMesh(keep: true);
      lay(mesh);
      mesh.build();
      for (final ({Float32List positions, Int32List colours}) kept
          in mesh.kept) {
        out.add((part, kept.positions, kept.colours));
      }
    }

    add('tubules', _layTubules);
    add('tunica', _layTunica);
    add('mediastinum', _layMediastinum);
    add('epididymis', _layEpididymis);
    add('ductules', (ColouredMesh mesh) {
      for (final TubeCourse ductule in form.ductules) {
        _layTube(mesh, ductule, _ductuleTone, columns: _fine);
      }
    });
    add('vas', (ColouredMesh mesh) => _layTube(mesh, form.vas, _vasTone));
    add('vessels', (ColouredMesh mesh) {
      _layTube(mesh, form.artery, _arteryTone);
      for (final TubeCourse vein in form.veins) {
        _layTube(mesh, vein, _veinTone);
      }
    });
    return out;
  }

  static List<ui.Vertices> _build(void Function(ColouredMesh) lay) {
    final ColouredMesh mesh = ColouredMesh();
    lay(mesh);
    return mesh.build();
  }

  static final Paint _meshPaint = Paint();

  static void _draw(Canvas canvas, List<ui.Vertices> meshes) {
    for (final ui.Vertices vertices in meshes) {
      canvas.drawVertices(vertices, BlendMode.dst, _meshPaint);
    }
  }
}

double _mean(Float64List values) {
  double sum = 0;
  for (final double v in values) {
    sum += v;
  }
  return values.isEmpty ? 0 : sum / values.length;
}

(double, double, double) _unit(double x, double y, double z) {
  final double length = math.sqrt(x * x + y * y + z * z);
  return length <= 0 ? (0, 0, 1) : (x / length, y / length, z / length);
}
