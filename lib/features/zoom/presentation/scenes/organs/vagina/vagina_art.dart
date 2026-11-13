import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import 'vagina_anatomy.dart';
import 'vagina_form.dart';
import 'vagina_style.dart';

/// The vagina opened down its front wall and pinned flat, drawn as a
/// specimen under the zoom's one lamp: the front wall's two halves, where
/// the zoom goes in, flat in the mark, as the cervix's ectocervix is, cut
/// by their anatomy as crisp lines (their rugae, the anterior column's
/// halves along their cut edges and the urethral carina below, as ridges);
/// the back wall between them a deep warm mucosa, its posterior column and
/// rugae alike, the lateral sulci between the walls; the vaginal part of
/// the cervix standing out of the vault, lit as it rounds, its os a dark
/// slit, its shadow on the back wall below it; the hymen's caruncles pale
/// along the introitus.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class VaginaArt {
  VaginaArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final VaginaForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  /// Where the zoom goes in, the front wall: one flat tone, the mark over a
  /// neutral, as the cervix's ectocervix is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(VaginaStyle.homeMark),
    inks.lit(VaginaStyle.homeLit),
  );

  /// What the step from the body draws the vagina's bed in: its back
  /// wall's mucosa, the middle of what its outline covers.
  static Color bedOf(ZoomInks inks) => _fresh(
    SpecimenLight(SpecimenLamp.zoom),
    SpecimenPalette(inks),
    _warmed(inks, VaginaStyle.backLit, VaginaStyle.backWarmth),
  );

  /// A tone [lit] of the way to the bright ink, warmed [warmth] of the way
  /// toward the home helix's clay.
  static SpecimenTone _warmed(ZoomInks inks, double lit, double warmth) =>
      SpecimenTone(
        Color.lerp(inks.lit(lit), inks.bases.thymine, warmth)!,
        inks.shadow,
      );

  /// [tone] as a fresh surface facing the eye, its full sheen.
  static Color _fresh(
    SpecimenLight light,
    SpecimenPalette palette,
    SpecimenTone tone,
  ) => Color(
    palette.colour(tone, light.light(0, 0, 1), sheen: light.sheen(0, 0, 1)),
  );

  late final Color _home = homeOf(inks);
  late final Color _back = _fresh(
    _light,
    _palette,
    _warmed(inks, VaginaStyle.backLit, VaginaStyle.backWarmth),
  );
  late final Color _caruncle = _fresh(
    _light,
    _palette,
    _warmed(inks, VaginaStyle.caruncleLit, VaginaStyle.caruncleWarmth),
  );
  late final SpecimenTone _portioTone = _warmed(
    inks,
    VaginaStyle.portioLit,
    VaginaStyle.portioWarmth,
  );

  // The mesh.

  /// The vaginal part, lit as it rounds out of the vault.
  late final List<ui.Vertices> _portio = _build(_layPortio);

  void _layPortio(ColouredMesh mesh) {
    final List<Offset> shape = VaginaForm.portioMm;
    final Relief relief = Relief(
      shape,
      cell: VaginaStyle.portioCell,
      inflation: VaginaStyle.portioInflation,
      sweeps: VaginaStyle.portioSweeps,
    );
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;
    for (final Offset p in shape) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    const double cell = VaginaStyle.portioCell;
    final int columns = ((right - left) / cell).ceil() + 1;
    final int rows = ((bottom - top) / cell).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = Offset(
          math.min(right, left + i * cell),
          math.min(bottom, top + j * cell),
        );
        final (double nx, double ny, double nz) = relief.normalAt(p);
        final Offset at = form.place(p);
        mesh.vertex(
          at.dx,
          at.dy,
          _palette.colour(
            _portioTone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz),
          ),
        );
      }
    }
    for (int j = 0; j + 1 < rows; j++) {
      for (int i = 0; i + 1 < columns; i++) {
        final int a = first + j * columns + i;
        final int c = a + columns;
        mesh
          ..triangle(a, a + 1, c)
          ..triangle(a + 1, c + 1, c);
      }
    }
  }

  // The paths.

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);
  static Path _open(List<Offset> points) => Path()..addPolygon(points, false);

  late final Path _front = () {
    final Path path = Path();
    for (final List<Offset> half in form.front) {
      path.addPolygon(half, true);
    }
    return path;
  }();
  late final Path _sulci = () {
    final Path path = Path();
    for (final List<Offset> sulcus in form.sulci) {
      path.addPolygon(sulcus, false);
    }
    return path;
  }();
  late final Path _portioPath = _polygon(form.portio);
  late final Path _os = _polygon(form.os);
  late final List<Path> _columns = <Path>[
    for (final List<Offset> c in form.columns) _open(c),
  ];
  late final Path _carinae = () {
    final Path path = Path();
    for (final List<Offset> c in form.carinae) {
      path.addPolygon(c, false);
    }
    return path;
  }();
  late final Path _caruncles = () {
    final Path path = Path();
    for (final (Offset at, double r) in form.caruncles) {
      path.addOval(Rect.fromCircle(center: at, radius: r));
    }
    return path;
  }();

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(VaginaStyle.shadowX),
      form.mm(VaginaStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    final Path shape = Path()
      ..addPath(form.outline, Offset.zero)
      ..addPath(_caruncles, Offset.zero);
    canvas.drawPath(
      shape,
      Paint()..color = shadow.withValues(alpha: VaginaStyle.shadowAlpha),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(VaginaStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the vagina and its caruncles cover, their shadow included: the
  /// room a layer of it needs.
  late final Rect bounds = form.box
      .expandToInclude(_caruncles.getBounds())
      .inflate(form.mm(VaginaStyle.shadowY + VaginaStyle.shadowSoft));

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _portio,
    _front,
    _sulci,
    _portioPath,
    _os,
    _columns,
    _carinae,
    _caruncles,
    form.rugaCreases,
    form.columnCreases,
    bounds,
  ];

  /// Draws it all, in the scene's units at the vagina's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The caruncles, under the introitus's edge.
    canvas.drawPath(_caruncles, Paint()..color = _caruncle);
    canvas.drawPath(
      _caruncles,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(form.mm(0.1), VaginaStyle.lineFloor * line)
        ..color = inks.shadow.withValues(alpha: 0.3),
    );
    // The walls.
    canvas.drawPath(form.outline, Paint()..color = _back);
    canvas.drawPath(_front, Paint()..color = _home);
    canvas.save();
    canvas.clipPath(form.outline);
    _paintFolds(canvas, line, form.rugaCreases, VaginaStyle.creaseAlpha);
    for (final Path column in _columns) {
      _paintRidge(canvas, line, column, form.mm(VaginaStyle.columnLight));
    }
    _paintRidge(canvas, line, _carinae, form.mm(VaginaAnatomy.carina));
    _paintCreases(
      canvas,
      line,
      form.columnCreases,
      VaginaStyle.columnCrease,
      VaginaStyle.columnAlpha,
    );
    canvas.drawPath(
      _sulci,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(VaginaStyle.sulcusLine),
          VaginaStyle.lineFloor * line,
        )
        ..strokeJoin = StrokeJoin.round
        ..color = inks.shadow.withValues(alpha: VaginaStyle.sulcusAlpha),
    );
    // The vaginal part's shadow on the vault below it.
    canvas.save();
    canvas.translate(
      form.mm(VaginaStyle.portioShadowX),
      form.mm(VaginaStyle.portioShadowY),
    );
    canvas.drawPath(
      _portioPath,
      Paint()
        ..color = inks.shadow.withValues(alpha: VaginaStyle.portioShadowAlpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          form.mm(VaginaStyle.portioShadowSoft),
        ),
    );
    canvas.restore();
    canvas.restore();
    // The vaginal part, lit, its os.
    canvas.save();
    canvas.clipPath(_portioPath);
    _draw(canvas, _portio);
    canvas.restore();
    canvas.drawPath(
      _os,
      Paint()..color = inks.shadow.withValues(alpha: VaginaStyle.osAlpha),
    );
    _paintEdge(canvas, line, _portioPath, 0.5);
    _paintEdge(canvas, line, form.outline, 1);
  }

  void _paintEdge(Canvas canvas, double line, Path path, double strength) =>
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line
          ..strokeJoin = StrokeJoin.round
          ..color = inks
              .lit(VaginaStyle.edgeLit)
              .withValues(alpha: VaginaStyle.edgeAlpha * strength),
      );

  /// Rugae: the light on each one's far side, toward the lamp, and the
  /// crease along it at [alpha].
  void _paintFolds(Canvas canvas, double line, Path creases, double alpha) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(VaginaStyle.ridge);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      creases,
      Paint()
        ..color = inks
            .lit(VaginaStyle.ridgeLit)
            .withValues(alpha: VaginaStyle.ridgeAlpha),
    );
    canvas.restore();
    _paintCreases(canvas, line, creases, VaginaStyle.crease, alpha);
  }

  /// A ridge's pale band, [width] wide, toward the lamp.
  void _paintRidge(Canvas canvas, double line, Path ridge, double width) {
    canvas.save();
    final Offset toward = _light.screen * form.mm(VaginaStyle.columnLight);
    canvas.translate(toward.dx, toward.dy);
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(width, VaginaStyle.creaseFloor * line)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(VaginaStyle.ridgeLit)
            .withValues(alpha: VaginaStyle.columnLightAlpha),
    );
    canvas.restore();
  }

  /// [creases], [width] wide, in the shadow ink at [alpha], never thinner
  /// than a pixel or so.
  void _paintCreases(
    Canvas canvas,
    double line,
    Path creases,
    double width,
    double alpha,
  ) {
    final Color cleft = inks.shadow.withValues(alpha: alpha);
    canvas.drawPath(creases, Paint()..color = cleft);
    final double floor = VaginaStyle.creaseFloor * line;
    if (form.mm(width) < floor) {
      canvas.drawPath(
        creases,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = floor - form.mm(width)
          ..strokeJoin = StrokeJoin.round
          ..color = cleft,
      );
    }
  }

  /// Every mesh's vertices as built, for tests, each tagged with the part
  /// it draws: where each lies, in the scene's units, and its colour.
  @visibleForTesting
  List<(String, Float32List, Int32List)> get meshData {
    final List<(String, Float32List, Int32List)> out =
        <(String, Float32List, Int32List)>[];
    final ColouredMesh mesh = ColouredMesh(keep: true);
    _layPortio(mesh);
    mesh.build();
    for (final ({Float32List positions, Int32List colours}) kept in mesh.kept) {
      out.add(('portio', kept.positions, kept.colours));
    }
    return out;
  }

  /// The colours each part is filled in, by name. For tests.
  @visibleForTesting
  Map<String, Color> get fills => <String, Color>{
    'front wall': _home,
    'back wall': _back,
    'caruncles': _caruncle,
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
