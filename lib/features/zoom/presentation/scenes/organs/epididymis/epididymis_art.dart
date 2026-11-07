import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'epididymis_anatomy.dart';
import 'epididymis_form.dart';
import 'epididymis_style.dart';

/// The epididymis cut down its length on the back of its testis, drawn as
/// a specimen under the zoom's one lamp: where the zoom's cell lives flat
/// in the mark, as the bladder's urothelium is, cut by its anatomy as crisp
/// lines (the duct's profiles and the septa across it in the body and the
/// tail, or the efferent ductules coiled in the head's cones and the septa
/// between them); the rest of the cut a warm, quiet tone, the cones a shade
/// deeper than the duct; the tunica's inner face a line in from the edge;
/// the testis whole beside it, its tunica albuginea pale and lit, the
/// epididymis's shadow and the sinus's groove on it; the vas deferens
/// rising behind it, a pale firm tube, and the cord's artery and veins,
/// lit tubes in the blood red, fading out above; the tunica vaginalis laid
/// open round them, a faint film.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class EpididymisArt {
  EpididymisArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final EpididymisForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the bladder's urothelium is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(EpididymisStyle.homeMark),
    inks.lit(EpididymisStyle.homeLit),
  );

  /// What the step from the body draws the epididymis's bed in: the duct's
  /// cut, most of what its outline covers.
  static Color bedOf(ZoomInks inks) => _cutFace(
    SpecimenLight(SpecimenLamp.zoom),
    SpecimenPalette(inks),
    _warmed(inks, EpididymisStyle.ductLit, EpididymisStyle.ductWarmth),
  );

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  /// [tone]'s cut face where it faces the eye: less sheen than a fresh
  /// surface, being cut.
  static Color _cutFace(
    SpecimenLight light,
    SpecimenPalette palette,
    SpecimenTone tone,
  ) => Color(
    palette.colour(
      tone,
      light.light(0, 0, 1),
      sheen: light.sheen(0, 0, 1) * EpididymisStyle.cutSheen,
    ),
  );

  Color _face(SpecimenTone tone) => _cutFace(_light, _palette, tone);

  bool get _ductHome => form.home == EpididymisHome.duct;

  late final Color _home = homeOf(inks);
  late final Color _duct = _ductHome
      ? _home
      : _face(
          _warmed(inks, EpididymisStyle.ductLit, EpididymisStyle.ductWarmth),
        );
  late final Color _cones = _ductHome
      ? _face(
          _warmed(inks, EpididymisStyle.conesLit, EpididymisStyle.conesWarmth),
        )
      : _home;
  late final SpecimenTone _testisTone = _warmed(
    inks,
    EpididymisStyle.testisLit,
    EpididymisStyle.testisWarmth,
  );
  late final SpecimenTone _vasTone = _warmed(
    inks,
    EpididymisStyle.vasLit,
    EpididymisStyle.vasWarmth,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, EpididymisStyle.artery)!,
    inks.shadow,
  );
  late final SpecimenTone _veinTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, EpididymisStyle.vein)!,
    inks.shadow,
  );

  static final List<double> _round = <double>[
    for (final double u in EpididymisStyle.tubeColumns.reversed) -u,
    ...EpididymisStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// The testis, whole: an ellipsoid's face, laid as a lit surface on a
  /// grid over its box, drawn clipped to its outline; each point lit by the
  /// ellipsoid's own normal there, so its edge is smooth all round.
  late final List<ui.Vertices> _testis = _build(_layTestis);

  void _layTestis(ColouredMesh mesh) {
    const double tilt = EpididymisAnatomy.testisTilt * math.pi / 180;
    final double c = math.cos(tilt);
    final double s = math.sin(tilt);
    final Offset middle = form.place(EpididymisAnatomy.testisCentre);
    final double a = form.mm(EpididymisAnatomy.testisHalfDepth);
    final double b = form.mm(EpididymisAnatomy.testisHalfLength);
    final double high = EpididymisStyle.testisDome * a;
    final double cell = form.mm(EpididymisStyle.meshCell);
    final Rect grid = form.testis.getBounds().inflate(cell);
    final int columns = (grid.width / cell).ceil() + 1;
    final int rows = (grid.height / cell).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = grid.topLeft + Offset(i * cell, j * cell);
        // Into the testis's own frame, its upper pole up.
        final Offset d = p - middle;
        double x = d.dx * c + d.dy * s;
        double y = -d.dx * s + d.dy * c;
        final double r = math.sqrt((x / a) * (x / a) + (y / b) * (y / b));
        if (r > 0.999) {
          x *= 0.999 / r;
          y *= 0.999 / r;
        }
        final double rise = math.sqrt(
          math.max(0, 1 - (x / a) * (x / a) - (y / b) * (y / b)),
        );
        final double fx = high * x / (a * a);
        final double fy = high * y / (b * b);
        final double length = math.sqrt(fx * fx + fy * fy + rise * rise);
        // Back onto the screen.
        final double nx = (fx * c - fy * s) / length;
        final double ny = (fx * s + fy * c) / length;
        final double nz = rise / length;
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            _testisTone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz),
          ),
        );
      }
    }
    for (int j = 0; j + 1 < rows; j++) {
      for (int i = 0; i + 1 < columns; i++) {
        final int k = first + j * columns + i;
        mesh.triangle(k, k + 1, k + columns);
        mesh.triangle(k + 1, k + columns + 1, k + columns);
      }
    }
  }

  /// The cord: the vas deferens, the veins behind the artery, the artery,
  /// and the veins in front of it.
  late final List<ui.Vertices> _vas = _build(_layVas);
  late final List<ui.Vertices> _veinsBehind = _build(
    (ColouredMesh mesh) => _layVeins(mesh, behind: true),
  );
  late final List<ui.Vertices> _artery = _build(_layArtery);
  late final List<ui.Vertices> _veinsFront = _build(
    (ColouredMesh mesh) => _layVeins(mesh, behind: false),
  );

  void _layVas(ColouredMesh mesh) => _layTube(mesh, form.vas, _vasTone);

  void _layArtery(ColouredMesh mesh) =>
      _layTube(mesh, form.artery, _arteryTone);

  void _layVeins(ColouredMesh mesh, {required bool behind}) {
    for (int i = 0; i < form.veins.length; i++) {
      if ((i < EpididymisAnatomy.veinsBehind) == behind) {
        _layTube(mesh, form.veins[i], _veinTone);
      }
    }
  }

  void _layTube(ColouredMesh mesh, TubeCourse tube, SpecimenTone tone) =>
      tube.lay(
        mesh,
        tone,
        _light,
        _palette,
        _round,
        brightness: EpididymisStyle.tubeLight,
      );

  // The paths.

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static Path _lines(List<List<Offset>> lines) {
    final Path path = Path();
    for (final List<Offset> line in lines) {
      if (line.length > 1) {
        path.addPolygon(line, false);
      }
    }
    return path;
  }

  late final Path _head = _polygon(form.head);
  late final Path _ductPart = _polygon(form.duct);
  late final Path _coneSepta = _lines(form.coneSepta);
  late final Path _ductules = _lines(form.ductules);
  late final Path _ductSepta = _lines(form.ductSepta);
  late final Path _headEnd = () {
    final (Offset a, Offset b) = form.headEndLine;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
  }();
  late final Path _tunica = _polygon(form.tunica);
  late final Path _front = Path()..addPolygon(form.front, false);

  /// The duct's profiles: each one's outline, and its lumen.
  late final (Path, Path) _profiles = () {
    final Path walls = Path();
    final Path lumens = Path();
    for (final DuctProfile p in form.profiles) {
      final Float64List turn = _turn(p.at, p.turn);
      walls.addPath(
        Path()..addOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 2 * p.long,
            height: 2 * p.short,
          ),
        ),
        Offset.zero,
        matrix4: turn,
      );
      lumens.addPath(
        Path()..addOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 2 * (p.long - p.short * (1 - EpididymisStyle.lumen)),
            height: 2 * p.short * EpididymisStyle.lumen,
          ),
        ),
        Offset.zero,
        matrix4: turn,
      );
    }
    return (walls, lumens);
  }();

  static Float64List _turn(Offset at, double angle) {
    final double c = math.cos(angle);
    final double s = math.sin(angle);
    return Float64List.fromList(<double>[
      c, s, 0, 0, //
      -s, c, 0, 0,
      0, 0, 1, 0,
      at.dx, at.dy, 0, 1,
    ]);
  }

  // The shadows.

  /// The shapes that cast a shadow on the ground: the epididymis and the
  /// testis; and the cord's tubes' middles, each with its mean width.
  late final Path _casting = Path()
    ..addPath(form.outline, Offset.zero)
    ..addPath(form.testis, Offset.zero);
  late final List<(Path, double)> _strands = <(Path, double)>[
    for (final TubeCourse tube in form.beside)
      (tube.line, 2 * _mean(tube.radius)),
  ];

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(EpididymisStyle.shadowX),
      form.mm(EpididymisStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      _casting,
      Paint()..color = shadow.withValues(alpha: EpididymisStyle.shadowAlpha),
    );
    canvas.drawPath(
      _casting,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(EpididymisStyle.shadowSoft)
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

  /// What the epididymis, the testis, the sac and the cord cover, their
  /// shadows included: the room a layer of them needs.
  late final Rect bounds = () {
    Rect box = form.box
        .expandToInclude(form.testis.getBounds())
        .expandToInclude(form.sac.getBounds());
    for (final TubeCourse tube in form.beside) {
      double widest = 0;
      for (final double r in tube.radius) {
        widest = math.max(widest, r);
      }
      box = box.expandToInclude(tube.line.getBounds().inflate(widest));
    }
    return box.inflate(
      form.mm(EpididymisStyle.shadowY + EpididymisStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _testis,
    _vas,
    _veinsBehind,
    _artery,
    _veinsFront,
    _head,
    _ductPart,
    _coneSepta,
    _ductules,
    _ductSepta,
    _headEnd,
    _tunica,
    _front,
    _profiles,
    _casting,
    _strands,
    form.sac,
    bounds,
  ];

  /// Draws it all, in the scene's units at the epididymis's real size;
  /// [line] is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The tunica vaginalis, laid open, a film behind it all.
    canvas.drawPath(
      form.sac,
      Paint()
        ..color = inks
            .lit(EpididymisStyle.sacLit)
            .withValues(alpha: EpididymisStyle.sacAlpha),
    );
    canvas.drawPath(
      form.sac,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = inks.lit(0.5).withValues(alpha: EpididymisStyle.sacEdgeAlpha),
    );
    // The cord, behind the testis and the epididymis.
    _draw(canvas, _vas);
    _draw(canvas, _veinsBehind);
    _draw(canvas, _artery);
    _draw(canvas, _veinsFront);
    _paintTestis(canvas, line);
    _paintEpididymis(canvas, line);
  }

  /// The testis, whole, lit; the epididymis's shadow on it and the sinus's
  /// groove along the body; its edge.
  void _paintTestis(Canvas canvas, double line) {
    canvas.save();
    canvas.clipPath(form.testis);
    _draw(canvas, _testis);
    canvas.save();
    canvas.translate(
      form.mm(EpididymisStyle.castX),
      form.mm(EpididymisStyle.castY),
    );
    canvas.drawPath(
      form.outline,
      Paint()..color = inks.shadow.withValues(alpha: EpididymisStyle.castAlpha),
    );
    canvas.restore();
    for (final (double width, double alpha) in <(double, double)>[
      (EpididymisStyle.sinus, EpididymisStyle.sinusAlpha * 0.5),
      (EpididymisStyle.sinus * 0.45, EpididymisStyle.sinusAlpha),
    ]) {
      canvas.drawPath(
        _front,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * form.mm(width)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = inks.shadow.withValues(alpha: alpha),
      );
    }
    canvas.restore();
    _paintEdge(canvas, line, form.testis);
  }

  /// The epididymis's cut: the duct's part and the head's cones, one of
  /// them in the mark; the cones' septa and their ductules; the duct's
  /// septa and its profiles; where the head ends; the tunica and the edge.
  void _paintEpididymis(Canvas canvas, double line) {
    canvas.drawPath(_ductPart, Paint()..color = _duct);
    canvas.drawPath(_head, Paint()..color = _cones);
    canvas.save();
    canvas.clipPath(_head);
    _paintLine(
      canvas,
      line,
      _ductules,
      EpididymisStyle.ductule,
      EpididymisStyle.ductuleAlpha,
    );
    _paintLine(
      canvas,
      line,
      _coneSepta,
      EpididymisStyle.septum,
      EpididymisStyle.septumAlpha,
    );
    canvas.restore();
    canvas.save();
    canvas.clipPath(_ductPart);
    _paintLine(
      canvas,
      line,
      _ductSepta,
      EpididymisStyle.septum,
      EpididymisStyle.ductSeptumAlpha,
    );
    final (Path walls, Path lumens) = _profiles;
    canvas.drawPath(
      lumens,
      Paint()
        ..color = inks.shadow.withValues(alpha: EpididymisStyle.lumenAlpha),
    );
    _paintLine(
      canvas,
      line,
      walls,
      EpididymisStyle.wall,
      EpididymisStyle.wallAlpha,
    );
    canvas.restore();
    canvas.save();
    canvas.clipPath(form.outline);
    _paintLine(
      canvas,
      line,
      _headEnd,
      EpididymisStyle.septum,
      EpididymisStyle.septumAlpha,
    );
    canvas.restore();
    _paintLine(
      canvas,
      line,
      _tunica,
      EpididymisStyle.tunicaLine,
      EpididymisStyle.tunicaAlpha,
    );
    _paintEdge(canvas, line, form.outline);
  }

  void _paintEdge(Canvas canvas, double line, Path path) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = inks
          .lit(EpididymisStyle.edgeLit)
          .withValues(alpha: EpididymisStyle.edgeAlpha),
  );

  /// [path], a line [width] wide in the shadow ink at [alpha], never
  /// thinner than so many pixels.
  void _paintLine(
    Canvas canvas,
    double line,
    Path path,
    double width,
    double alpha,
  ) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(form.mm(width), EpididymisStyle.lineFloor * line)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = inks.shadow.withValues(alpha: alpha),
  );

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

    add('testis', _layTestis);
    add('vas', _layVas);
    add('vessels', (ColouredMesh mesh) {
      _layArtery(mesh);
      _layVeins(mesh, behind: true);
      _layVeins(mesh, behind: false);
    });
    return out;
  }

  /// The colours each part is filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'duct': _duct,
    'cones': _cones,
  };

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
