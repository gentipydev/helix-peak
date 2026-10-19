import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/cell_archetypes.dart';
import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../lobule_domes.dart';
import '../../lobules.dart';
import '../../relief.dart';
import '../../sculpt.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'salivary_form.dart';
import 'salivary_style.dart';

/// Where in the salivary gland a cell of one kind lives.
enum SalivaryHome {
  /// The acini, which are the glands' lobules.
  acini,

  /// The ducts.
  ducts,

  /// The gland itself, for a cell of no part of it of its own.
  gland;

  /// Where a cell of [shape] lives.
  static SalivaryHome of(CellShape shape) => switch (shape) {
    CellShape.acinar => acini,
    CellShape.epithelial => ducts,
    _ => gland,
  };
}

/// The parotid in place, drawn as a fresh dissection under the zoom's one
/// lamp: its lobules each a lit dome, dark crevices between them, the
/// accessory gland above its duct, the duct a pale cord over the masseter;
/// the facial nerve's branches fanning out of its front edge in the home
/// helix's honey, the superficial temporal vessels leaving its top in the
/// blood red; and round it, dimmer, the masseter's fibres, the zygomatic
/// arch, the jaw's lower border, the ear and the submandibular gland.
///
/// Where the zoom's cell lives is in the mark, by its kind and never by
/// gene: the glands' lobules washed in it for an acinar cell or any other
/// that lives in the gland; for a duct cell the ducts, the gland's surface
/// cut away round the duct's way in to show them.
///
/// Everything costly is built once, for one form, one home and one set of
/// inks: meshes in the scene's units, so a frame only hands them on.
final class SalivaryArt {
  SalivaryArt(this.form, this.inks, {required this.home})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final SalivaryForm form;
  final ZoomInks inks;
  final SalivaryHome home;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  bool get _ducts => home == SalivaryHome.ducts;

  /// The share of the mark in the glands' lobules.
  double get _wash => _ducts ? 0 : SalivaryStyle.wash;

  /// What shows between the lobules, and what the step from the body draws
  /// the parotid's bed in.
  static Color bedOf(ZoomInks inks) =>
      inks.shade(SalivaryStyle.creviceShade);

  late final Color _crevice = bedOf(inks);

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final SpecimenTone _glandTone = _tone(
    inks.lit(SalivaryStyle.glandLit),
  );
  late final SpecimenTone _submandibularTone = _tone(
    inks.lit(SalivaryStyle.submandibularLit),
  );
  late final SpecimenTone _ductTone = _ducts
      ? SpecimenTone(inks.mark, inks.markDeep)
      : _tone(inks.lit(SalivaryStyle.ductLit));
  late final SpecimenTone _masseterTone = _tone(
    inks.lit(SalivaryStyle.masseterLit),
  );
  late final SpecimenTone _earTone = _tone(inks.lit(SalivaryStyle.earLit));
  late final SpecimenTone _conchaTone = _tone(
    inks.lit(SalivaryStyle.conchaLit),
  );
  late final SpecimenTone _boneTone = _tone(inks.lit(SalivaryStyle.boneLit));
  late final SpecimenTone _nerveTone = _tone(
    Color.lerp(inks.nerve, inks.ground, SalivaryStyle.nerve)!,
  );
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, SalivaryStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, SalivaryStyle.vein)!,
  );

  static final List<double> _columns = <double>[
    for (final double u in SalivaryStyle.columns.reversed) -u,
    ...SalivaryStyle.columns.skip(1),
  ];

  // The glands.

  /// The parotid's lobules, the accessory gland's and the submandibular
  /// gland's, each a lit dome.
  late final List<ui.Vertices> _parotid = _build(_layParotid);
  late final List<ui.Vertices> _accessory = _build(_layAccessory);
  late final List<ui.Vertices> _submandibular = _build(_laySubmandibular);

  void _layParotid(ColouredMesh mesh) => _layLobules(
    mesh,
    form.lobules,
    form.relief,
    _glandTone,
    seed: 71,
  );

  void _layAccessory(ColouredMesh mesh) => _layLobules(
    mesh,
    form.accessoryLobules,
    form.accessoryRelief,
    _glandTone,
    seed: 73,
  );

  void _laySubmandibular(ColouredMesh mesh) => _layLobules(
    mesh,
    form.submandibularLobules,
    form.submandibularRelief,
    _submandibularTone,
    seed: 79,
  );

  void _layLobules(
    ColouredMesh mesh,
    Lobules lobules,
    Relief relief,
    SpecimenTone tone, {
    required int seed,
  }) => LobuleDomes.lay(
    mesh,
    lobules.all,
    style: SalivaryStyle.lobules,
    relief: relief,
    mm: form.mm,
    light: _light,
    palette: _palette,
    tone: tone,
    wash: _wash,
    seed: seed,
  );

  /// The crevices between each gland's lobules, filled.
  late final Path _parotidBed = _bed(form.lobules);
  late final Path _accessoryBed = _bed(form.accessoryLobules);
  late final Path _submandibularBed = _bed(form.submandibularLobules);

  Path _bed(Lobules lobules) =>
      Lobules.bed(lobules.all, form.mm(SalivaryStyle.lobules.cleft));

  // What lies round them.

  /// The masseter, the ear and its concha: each its relief, lit, on a grid
  /// over its box, drawn clipped to its outline.
  late final List<ui.Vertices> _masseter = _build(
    (ColouredMesh mesh) => _layRelief(
      mesh,
      form.masseter.getBounds(),
      form.masseterRelief,
      _masseterTone,
    ),
  );
  late final List<ui.Vertices> _ear = _build(
    (ColouredMesh mesh) =>
        _layRelief(mesh, form.ear.getBounds(), form.earRelief, _earTone),
  );
  late final List<ui.Vertices> _concha = _build(
    (ColouredMesh mesh) => _layRelief(
      mesh,
      form.concha.getBounds(),
      form.conchaRelief,
      _conchaTone,
      hollow: true,
    ),
  );

  /// [relief] over [box] as a lit surface in [tone], dimmer than the
  /// gland; [hollow] turns it into a bowl.
  void _layRelief(
    ColouredMesh mesh,
    Rect box,
    Relief relief,
    SpecimenTone tone, {
    bool hollow = false,
  }) {
    final double cell = form.mm(SalivaryStyle.reliefCell);
    final Rect grid = box.inflate(cell);
    final int columns = (grid.width / cell).ceil() + 1;
    final int rows = (grid.height / cell).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = grid.topLeft + Offset(i * cell, j * cell);
        final (double rx, double ry, double nz) = relief.normalAt(p);
        final double nx = hollow ? -rx : rx;
        final double ny = hollow ? -ry : ry;
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            tone,
            _light.light(nx, ny, nz, form: nz) * SalivaryStyle.neighbourLight,
            sheen: _light.sheen(nx, ny, nz) * SalivaryStyle.neighbourLight,
          ),
        );
      }
    }
    for (int j = 0; j + 1 < rows; j++) {
      for (int i = 0; i + 1 < columns; i++) {
        final int a = first + j * columns + i;
        mesh.triangle(a, a + 1, a + columns);
        mesh.triangle(a + 1, a + columns + 1, a + columns);
      }
    }
  }

  /// The masseter's fibres, running down and back from the arch: the
  /// grooves between them, and the light along each.
  late final (Path, Path) _fibres = () {
    final Path grooves = Path();
    final Path ridges = Path();
    final Rect box = form.masseter.getBounds();
    final double step = form.mm(SalivaryStyle.fibre);
    final double lean = SalivaryStyle.fibreLean * box.height;
    for (double x = box.left - lean; x <= box.right; x += step) {
      grooves
        ..moveTo(x, box.top)
        ..lineTo(x + lean, box.bottom);
      ridges
        ..moveTo(x - 0.35 * step, box.top)
        ..lineTo(x - 0.35 * step + lean, box.bottom);
    }
    return (grooves, ridges);
  }();

  late final List<ui.Vertices> _bones = _build(_layBones);

  void _layBones(ColouredMesh mesh) {
    _layTube(mesh, form.mandible, _boneTone, light: SalivaryStyle.boneLight);
    _layTube(mesh, form.arch, _boneTone, light: SalivaryStyle.boneLight);
  }

  late final List<ui.Vertices> _nerves = _build(_layNerves);

  void _layNerves(ColouredMesh mesh) {
    for (final TubeCourse nerve in form.nerves) {
      _layTube(
        mesh,
        nerve,
        _nerveTone,
        columns: _fine,
        light: SalivaryStyle.nerveLight,
      );
    }
  }

  late final List<ui.Vertices> _duct = _build(
    (ColouredMesh mesh) => _layTube(mesh, form.duct, _ductTone, light: 1),
  );

  late final List<ui.Vertices> _vessels = _build((ColouredMesh mesh) {
    _layTube(mesh, form.vein, _veinTone);
    _layTube(mesh, form.artery, _arteryTone);
  });

  /// [tube] as a lit tube in [tone], at [light] of the gland's light, by
  /// default a neighbour's: round it at [columns], by default the tubes'
  /// own.
  void _layTube(
    ColouredMesh mesh,
    TubeCourse tube,
    SpecimenTone tone, {
    List<double>? columns,
    double light = SalivaryStyle.neighbourLight,
  }) => tube.lay(
    mesh,
    tone,
    _light,
    _palette,
    columns ?? _columns,
    brightness: light,
  );

  /// A nerve is too fine to need more than its edges and its middle.
  static const List<double> _fine = <double>[-1, 0, 1];

  // The window, for a duct cell.

  late final Color _cut = Color(
    _palette.colour(
      SpecimenTone(inks.lit(SalivaryStyle.cutLit), inks.shadow),
      _light.light(0, 0, 1),
    ),
  );

  /// The lobules' outlines, which show on the cut face as its septa.
  late final Path _septa = () {
    final Path path = Path();
    for (final Lobule lobule in form.lobules.all) {
      lobule.addTo(path);
    }
    return path;
  }();

  /// The cut's edge: in shade where its wall faces away from the light, lit
  /// where it faces it.
  late final List<ui.Vertices> _lip = _build((ColouredMesh mesh) {
    final List<(Offset, Offset)> edge = form.windowEdge;
    if (edge.length < 3) {
      return;
    }
    final Offset toward = _light.screen;
    final double jump = form.mm(1.5);
    final Color wall = inks.lit(0.62);
    // The edge in runs, broken where it leaves the gland.
    final List<List<(Offset, Offset)>> runs = <List<(Offset, Offset)>>[
      <(Offset, Offset)>[edge.first],
    ];
    for (int i = 1; i < edge.length; i++) {
      if ((edge[i].$1 - edge[i - 1].$1).distance > jump) {
        runs.add(<(Offset, Offset)>[]);
      }
      runs.last.add(edge[i]);
    }
    for (final List<(Offset, Offset)> run in runs) {
      if (run.length < 2) {
        continue;
      }
      final bool closed = (run.first.$1 - run.last.$1).distance <= jump;
      mesh.begin(2 * run.length);
      final int first = mesh.next;
      for (final (Offset p, Offset out) in run) {
        final double facing = out.dx * toward.dx + out.dy * toward.dy;
        final double width = form.mm(
          facing > 0 ? SalivaryStyle.lipShadow : SalivaryStyle.lipWall,
        );
        final int colour = facing > 0
            ? SpecimenPalette.packColour(
                inks.shadow,
                SalivaryStyle.lipShadowAlpha * facing,
              )
            : SpecimenPalette.packColour(
                wall,
                SalivaryStyle.lipWallAlpha * -facing,
              );
        final Offset inner = p - out * width;
        mesh.vertex(p.dx, p.dy, colour);
        mesh.vertex(inner.dx, inner.dy, _clear(colour));
      }
      final int count = run.length;
      for (int i = 0; i < (closed ? count : count - 1); i++) {
        final int a = first + 2 * i;
        final int b = first + 2 * ((i + 1) % count);
        mesh.triangle(a, b, a + 1);
        mesh.triangle(b, b + 1, a + 1);
      }
    }
  });

  void _paintWindow(Canvas canvas, double line) {
    canvas.save();
    canvas.clipPath(form.window);
    canvas.drawPath(form.window, Paint()..color = _cut);
    canvas.drawPath(
      _septa,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = SalivaryStyle.septum * line
        ..color = _crevice.withValues(alpha: 0.55),
    );
    final double branch = math.max(
      form.mm(SalivaryStyle.branchWidth),
      SalivaryStyle.coreFloor * line,
    );
    Sculpt.glowingStroke(canvas, form.branches, inks, width: branch);
    Sculpt.glowingStroke(canvas, form.siteBranch, inks, width: 1.3 * branch);
    Sculpt.glowingStroke(
      canvas,
      form.innerDuct,
      inks,
      width: math.max(2 * _mean(form.duct.radius), branch),
      alpha: 0.6,
    );
    canvas.restore();
    _draw(canvas, _lip);
  }

  // The shadows.

  /// The face's own parts, which cast a shadow on the ground round them.
  late final Path _face = Path()
    ..addPath(form.masseter, Offset.zero)
    ..addPath(form.ear, Offset.zero)
    ..addPath(form.submandibular, Offset.zero);

  /// The glands, which cast a shadow on the face under them.
  late final Path _glands = Path()
    ..addPath(form.outline, Offset.zero)
    ..addPath(form.accessoryPath, Offset.zero);

  /// The tubes' middles, for their shadows: each with its mean width.
  late final List<(Path, double)> _strands = <(Path, double)>[
    for (final TubeCourse tube in <TubeCourse>[
      form.duct,
      ...form.nerves,
      form.artery,
      form.vein,
      form.arch,
      form.mandible,
    ])
      (tube.line, 2 * _mean(tube.radius)),
  ];

  void _paintShadow(Canvas canvas, Path casting, {bool strands = false}) {
    canvas.save();
    canvas.translate(
      form.mm(SalivaryStyle.shadowX),
      form.mm(SalivaryStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      casting,
      Paint()..color = shadow.withValues(alpha: SalivaryStyle.shadowAlpha),
    );
    canvas.drawPath(
      casting,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(SalivaryStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    if (strands) {
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
    }
    canvas.restore();
  }

  // Drawing.

  /// What the gland and what lies round it cover, their shadows included:
  /// the room a layer of them needs.
  late final Rect bounds = () {
    Rect box = form.outline
        .getBounds()
        .expandToInclude(form.masseter.getBounds())
        .expandToInclude(form.ear.getBounds())
        .expandToInclude(form.submandibular.getBounds())
        .expandToInclude(form.accessoryPath.getBounds());
    for (final TubeCourse tube in <TubeCourse>[
      form.duct,
      ...form.nerves,
      form.artery,
      form.vein,
      form.arch,
      form.mandible,
    ]) {
      double widest = 0;
      for (final double r in tube.radius) {
        widest = math.max(widest, r);
      }
      box = box.expandToInclude(tube.line.getBounds().inflate(widest));
    }
    return box.inflate(
      form.mm(SalivaryStyle.shadowY + SalivaryStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _parotid,
    _accessory,
    _submandibular,
    _parotidBed,
    _accessoryBed,
    _submandibularBed,
    _masseter,
    _ear,
    _concha,
    _fibres,
    _bones,
    _nerves,
    _duct,
    _vessels,
    _face,
    _glands,
    _strands,
    form.scapha,
    bounds,
    if (_ducts) ...<Object?>[
      form.window,
      _septa,
      _lip,
      form.branches,
      form.siteBranch,
      form.innerDuct,
    ],
  ];

  /// Draws it all, in the scene's units at the gland's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas, _face);
    // The submandibular gland, its top under the jaw.
    canvas.drawPath(_submandibularBed, Paint()..color = _crevice);
    _draw(canvas, _submandibular);
    // The bones, and the masseter over the jaw.
    _draw(canvas, _bones);
    canvas.save();
    canvas.clipPath(form.masseter);
    _draw(canvas, _masseter);
    canvas.drawPath(
      _fibres.$1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = inks.shadow.withValues(alpha: SalivaryStyle.fibreShade),
    );
    canvas.drawPath(
      _fibres.$2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = line
        ..color = inks.text.withValues(alpha: SalivaryStyle.fibreLight),
    );
    canvas.restore();
    // The ear: its concha a bowl, the opening of its canal, the groove
    // inside its rim.
    canvas.save();
    canvas.clipPath(form.ear);
    _draw(canvas, _ear);
    canvas.save();
    canvas.clipPath(form.concha);
    _draw(canvas, _concha);
    canvas.restore();
    canvas.drawOval(
      form.meatus,
      Paint()..color = inks.shade(SalivaryStyle.meatusShade),
    );
    canvas.drawPath(
      form.scapha,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(1.6)
        ..strokeCap = StrokeCap.round
        ..color = inks.shadow.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, form.mm(0.7)),
    );
    canvas.restore();
    // The glands' shadows on the face, and what leaves them.
    _paintShadow(canvas, _glands, strands: true);
    _draw(canvas, _nerves);
    _draw(canvas, _duct);
    _draw(canvas, _vessels);
    // The accessory gland and the parotid.
    canvas.drawPath(_accessoryBed, Paint()..color = _crevice);
    _draw(canvas, _accessory);
    canvas.drawPath(_parotidBed, Paint()..color = _crevice);
    _draw(canvas, _parotid);
    if (_ducts) {
      _paintWindow(canvas, line);
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

    add('parotid', _layParotid);
    add('accessory', _layAccessory);
    add('submandibular', _laySubmandibular);
    add(
      'masseter',
      (ColouredMesh m) => _layRelief(
        m,
        form.masseter.getBounds(),
        form.masseterRelief,
        _masseterTone,
      ),
    );
    add(
      'ear',
      (ColouredMesh m) =>
          _layRelief(m, form.ear.getBounds(), form.earRelief, _earTone),
    );
    add('bones', _layBones);
    add('nerves', _layNerves);
    add('duct', (ColouredMesh m) => _layTube(m, form.duct, _ductTone, light: 1));
    add('vessels', (ColouredMesh m) {
      _layTube(m, form.vein, _veinTone);
      _layTube(m, form.artery, _arteryTone);
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

int _clear(int colour) => colour & ((1 << 24) - 1);
