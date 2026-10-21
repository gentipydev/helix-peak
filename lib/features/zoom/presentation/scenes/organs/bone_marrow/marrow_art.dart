import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../cut_face.dart';
import '../../specimen_light.dart';
import 'marrow_form.dart';
import 'marrow_style.dart';

/// The femur cut down its length, drawn as a fresh specimen under the
/// zoom's one lamp: the marrow flat, the red marrow in the mark and the
/// yellow a warm neutral, both crossed by the pale trabeculae of the spongy
/// bone, which come in finer as the view closes on them; the cortex an
/// ivory cut face, its outer edge lit as the bone's surface turns away; the
/// cartilage glassy over the head and the condyles; the growth plates'
/// scars fine bright lines; the nutrient artery in the blood red, coming in
/// through its canal and running up and down the cavity.
///
/// Where the zoom's cell lives is in the mark, by the kind of organ: the red
/// marrow, the marrow the Atlas reads, for every kind of cell.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class MarrowArt {
  MarrowArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final MarrowForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  late final CutFace _face = CutFace(
    _light,
    _palette,
    sheen: MarrowStyle.cutSheen,
  );

  /// The yellow marrow's tone, which the step from the body draws the
  /// femur's bed in.
  static Color bedOf(ZoomInks inks) => inks.lit(MarrowStyle.yellowLit);

  /// The red marrow's one tone: the mark over a neutral, as the brain's
  /// cortex is.
  static Color redOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(MarrowStyle.redMark),
    inks.lit(MarrowStyle.redLit),
  );

  late final Color _yellow = bedOf(inks);
  late final Color _red = redOf(inks);

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final SpecimenTone _cortexTone = _tone(inks.lit(MarrowStyle.cortexLit));
  late final Color _cartilageColour = inks.lit(MarrowStyle.cartilageLit);
  late final Color _ligament = inks.lit(MarrowStyle.ligamentLit);

  /// A cut face whose first edge is the bone's surface, turning away from
  /// the eye there, and whose second is cut, cushioned a little.
  static const List<(double, double, double)> _rimmed =
      <(double, double, double)>[
        (0, MarrowStyle.rimOuter, 0),
        (MarrowStyle.rim / 2, MarrowStyle.rimMiddle, 0),
        (MarrowStyle.rim, 0, 0),
        (1, -MarrowStyle.cushion, 0),
      ];

  // The cortex and the cartilage.

  late final List<ui.Vertices> _cortex = _build(_layCortex);

  void _layCortex(ColouredMesh mesh) => _face.lay(
    mesh,
    <Offset>[...form.surface, form.surface.first],
    <Offset>[...form.wall, form.wall.first],
    (int _) => _cortexTone,
    _rimmed,
  );

  late final List<ui.Vertices> _cartilage = _build(_layCartilage);

  void _layCartilage(ColouredMesh mesh) {
    final int n = form.outlinePoints.length;
    for (final (int from, int to) in form.cartilageRuns) {
      // Forward from its first point to its last, round the end if need be.
      final List<int> run = <int>[from];
      while (run.last != to) {
        run.add((run.last + 1) % n);
      }
      _face.lay(
        mesh,
        <Offset>[for (final int i in run) form.outlinePoints[i]],
        <Offset>[for (final int i in run) form.surface[i]],
        (int k) =>
            _tone(Color.lerp(_cartilageColour, _ligament, form.fovea[run[k]])!),
        _rimmed,
        alpha: (int _) => MarrowStyle.cartilageAlpha,
      );
    }
  }

  // The trabeculae, by level, thick and thin, in tiles.

  late final double _tile = form.mm(MarrowStyle.tile);

  /// Each level's lines as paths, by whether they are of the thick groups,
  /// and by the tile each starts in, whole, so no line is broken where it
  /// crosses into the next.
  late final List<Map<bool, Map<(int, int), Path>>> _levels = () {
    final List<Map<bool, Map<(int, int), Path>>> out =
        <Map<bool, Map<(int, int), Path>>>[
          for (int level = 0; level < 3; level++)
            <bool, Map<(int, int), Path>>{},
        ];
    for (final TrabecularLine line in form.trabeculae) {
      final Offset first = line.points.first;
      out[line.level]
          .putIfAbsent(line.thick >= _thick, () => <(int, int), Path>{})
          .putIfAbsent((
            (first.dx / _tile).floor(),
            (first.dy / _tile).floor(),
          ), Path.new)
          .addPolygon(line.points, false);
    }
    return out;
  }();

  /// How thick a group's trabeculae are, at least, to be drawn as the thick
  /// ones are.
  static const double _thick = 0.3;

  /// How much of [level] shows at [perMm] pixels a millimetre: the first
  /// always, the others coming in evenly over a span of densities.
  static double levelShown(int level, double perMm) {
    final (double from, double to) = MarrowStyle.levelIn[level];
    if (to <= from) {
      return 1;
    }
    if (perMm <= from) {
      return 0;
    }
    return (math.log(perMm / from) / math.log(to / from)).clamp(0.0, 1.0);
  }

  void _paintTrabeculae(Canvas canvas, double line) {
    final double perMm = form.mm(1) / line;
    final Color colour = inks.lit(MarrowStyle.trabeculaLit);
    for (int level = 0; level < 3; level++) {
      final double shown = levelShown(level, perMm);
      if (shown <= 0.002) {
        continue;
      }
      for (final MapEntry<bool, Map<(int, int), Path>> kind
          in _levels[level].entries) {
        final double width = math.max(
          form.mm(kind.key ? 0.35 : 0.2),
          MarrowStyle.levelFloor[level] * line,
        );
        final Paint paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colour.withValues(
            alpha: MarrowStyle.levelAlpha[level] * shown,
          );
        // Each tile on its own, so the canvas passes over the many the view
        // has left as it closes in.
        for (final Path path in kind.value.values) {
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  // The scars and the nutrient artery.

  late final Path _scars = () {
    final Path path = Path();
    for (final List<Offset> scar in form.scars) {
      path.addPolygon(scar, false);
    }
    return path;
  }();

  late final Path _ascending = Path()..addPolygon(form.ascending, false);
  late final Path _descending = Path()..addPolygon(form.descending, false);
  late final Path _twigs = () {
    final Path path = Path();
    for (final (Offset a, Offset b) in form.twigs) {
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();
  late final Path _canal = Path()
    ..moveTo(form.canal.$1.dx, form.canal.$1.dy)
    ..lineTo(form.canal.$2.dx, form.canal.$2.dy);

  late final Color _artery = Color.lerp(
    inks.blood,
    inks.ground,
    MarrowStyle.artery,
  )!;

  /// A stroke of [colour], [width] wide, fading in from [fade].$1 to
  /// [fade].$2 where given.
  Paint _vessel(Color colour, double width, [(Offset, Offset)? fade]) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colour;
    if (fade != null) {
      paint.shader = ui.Gradient.linear(fade.$1, fade.$2, <Color>[
        colour.withValues(alpha: 0),
        colour,
      ]);
    }
    return paint;
  }

  void _paintArtery(Canvas canvas, double line) {
    final double vessel = math.max(
      form.mm(MarrowStyle.nutrient),
      MarrowStyle.vesselFloor * line,
    );
    final double branch = math.max(
      form.mm(MarrowStyle.branch),
      MarrowStyle.vesselFloor * line,
    );
    final double twig = math.max(
      form.mm(MarrowStyle.twig),
      MarrowStyle.twigFloor * line,
    );
    // The canal and the artery in it end square at the bone's faces.
    canvas.drawPath(
      _canal,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(MarrowStyle.canal),
          (MarrowStyle.vesselFloor + 0.6) * line,
        )
        ..color = inks.shade(MarrowStyle.canalShade),
    );
    canvas.drawPath(
      _canal,
      _vessel(_artery, vessel)..strokeCap = StrokeCap.butt,
    );
    canvas.drawPath(_twigs, _vessel(_artery, twig));
    canvas.drawPath(_ascending, _vessel(_artery, branch, form.ascendingFade));
    canvas.drawPath(_descending, _vessel(_artery, branch, form.descendingFade));
  }

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(MarrowStyle.shadowX),
      form.mm(MarrowStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: MarrowStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(MarrowStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the femur covers, its shadow included: the room a layer of it
  /// needs.
  late final Rect bounds = form.box.inflate(
    form.mm(MarrowStyle.shadowY + MarrowStyle.shadowSoft),
  );

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _cortex,
    _cartilage,
    _levels,
    _scars,
    _ascending,
    _descending,
    _twigs,
    _canal,
    form.marrow,
    form.red,
    bounds,
  ];

  /// Draws it all, in the scene's units at the femur's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    // The marrow: yellow, and red where the zoom's cell lives; the spongy
    // bone's trabeculae across it, and the growth plates' scars.
    canvas.drawPath(form.marrow, Paint()..color = _yellow);
    canvas.drawPath(form.red, Paint()..color = _red);
    _paintTrabeculae(canvas, line);
    canvas.drawPath(
      _scars,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(
          form.mm(MarrowStyle.scar),
          MarrowStyle.scarFloor * line,
        )
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = inks.lit(MarrowStyle.scarLit),
    );
    // The cortex and the cartilage.
    _draw(canvas, _cortex);
    _draw(canvas, _cartilage);
    // The nutrient artery through its canal and up and down the cavity.
    _paintArtery(canvas, line);
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..strokeJoin = StrokeJoin.round
        ..color = inks
            .lit(MarrowStyle.edgeLit)
            .withValues(alpha: MarrowStyle.edgeAlpha),
    );
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

    add('cortex', _layCortex);
    add('cartilage', _layCartilage);
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
