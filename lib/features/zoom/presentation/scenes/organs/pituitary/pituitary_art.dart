import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../opening_rim.dart';
import '../../relief.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'pituitary_form.dart';
import 'pituitary_style.dart';

/// The pituitary gland cut down its middle, drawn as the brain's stop draws
/// the brain, under the zoom's one lamp: where the zoom's cell lives flat
/// in the mark (its anterior lobe, or its posterior); else each lobe a
/// cushioned cut face in the brain's tone for it, the posterior paler, the
/// cleft between the pars anterior and the pars intermedia a fine dark
/// line; the stalk and the hypothalamus in the brain's tone for the third
/// ventricle's walls, the chiasm white and the mammillary body grey, all of
/// it fading out above the ventricle's floor; the sphenoid bone cut in the
/// femur's ivory, its sinus emptied, in shade, fading out below and in
/// front; the dura of the diaphragma sellae a pale line either side of the
/// stalk; the portal vessels fine lit tubes in the blood red down the
/// stalk's front.
///
/// Everything costly is built once, for one form and one set of inks:
/// meshes and paths in the scene's units, so a frame only hands them on.
final class PituitaryArt {
  PituitaryArt(this.form, this.inks)
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final PituitaryForm form;
  final ZoomInks inks;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  PituitaryHome get home => form.home;

  /// Where the zoom's cell lives: one flat tone, the mark over a neutral,
  /// as the brain's cortex is.
  static Color homeOf(ZoomInks inks) => Color.alphaBlend(
    inks.glow(PituitaryStyle.homeMark),
    inks.lit(PituitaryStyle.homeLit),
  );

  /// The gland's tone where it faces the eye: what the step from the body
  /// draws its bed in, so that it comes up on its own tone; in the mark
  /// where the anterior lobe is the cell's home.
  static Color bedOf(ZoomInks inks, PituitaryHome home) {
    if (home == PituitaryHome.anterior) {
      return homeOf(inks);
    }
    final SpecimenLight light = SpecimenLight(SpecimenLamp.zoom);
    return Color(
      SpecimenPalette(inks).colour(
        SpecimenTone(inks.lit(PituitaryStyle.anteriorLit), inks.shadow),
        light.light(0, 0, 1),
        sheen: light.sheen(0, 0, 1) * PituitaryStyle.cutSheen,
      ),
    );
  }

  SpecimenTone _tone(double lit) => SpecimenTone(inks.lit(lit), inks.shadow);

  late final Color _home = homeOf(inks);
  late final SpecimenTone _anteriorTone = _tone(PituitaryStyle.anteriorLit);
  late final SpecimenTone _posteriorTone = _tone(PituitaryStyle.posteriorLit);
  late final SpecimenTone _wallTone = _tone(PituitaryStyle.wallLit);
  late final SpecimenTone _whiteTone = _tone(PituitaryStyle.whiteLit);
  late final SpecimenTone _greyTone = _tone(PituitaryStyle.greyLit);
  late final SpecimenTone _boneTone = _tone(PituitaryStyle.boneLit);
  late final SpecimenTone _sinusTone = SpecimenTone(
    inks.shade(PituitaryStyle.sinusShade),
    inks.shadow,
  );
  late final SpecimenTone _arteryTone = SpecimenTone(
    Color.lerp(inks.blood, inks.ground, PituitaryStyle.artery)!,
    inks.shadow,
  );

  static final List<double> _round = <double>[
    for (final double u in PituitaryStyle.tubeColumns.reversed) -u,
    ...PituitaryStyle.tubeColumns.skip(1),
  ];

  // The meshes.

  /// [outline] inflated and laid as a lit surface in [tone] on a grid over
  /// its box, each point as much as [shown] lets it, to be drawn clipped to
  /// it.
  void _layRelief(
    ColouredMesh mesh,
    List<Offset> outline,
    SpecimenTone tone, {
    double Function(Offset)? shown,
    double cell = PituitaryStyle.reliefCell,
    double grid = PituitaryStyle.meshCell,
    double inflation = PituitaryStyle.reliefInflation,
    double gain = 1,
    double sheen = PituitaryStyle.cutSheen,
  }) {
    // No finer than a part's size allows: a grid of more points than a
    // mesh can index draws nothing.
    final double longest = _bounds(outline).longestSide;
    final Relief relief = Relief(
      outline,
      cell: math.max(form.mm(cell), longest / PituitaryStyle.gridMost),
      inflation: inflation,
      sweeps: PituitaryStyle.reliefSweeps,
    );
    final double step = math.max(
      form.mm(grid),
      longest / PituitaryStyle.gridMost,
    );
    final Rect box = _bounds(outline).inflate(step);
    final int columns = (box.width / step).ceil() + 1;
    final int rows = (box.height / step).ceil() + 1;
    mesh.begin(columns * rows);
    final int first = mesh.next;
    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < columns; i++) {
        final Offset p = box.topLeft + Offset(i * step, j * step);
        final (double nx, double ny, double nz) = relief.normalAt(p);
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            tone,
            _light.light(nx, ny, nz, form: nz) * gain,
            sheen: _light.sheen(nx, ny, nz) * sheen,
            alpha: shown == null ? 1 : shown(p),
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

  late final List<ui.Vertices> _boneMesh = _build(_layBone);

  void _layBone(ColouredMesh mesh) => _layRelief(
    mesh,
    form.bone,
    _boneTone,
    shown: form.boneShownAt,
    cell: PituitaryStyle.boneCell,
    grid: PituitaryStyle.boneMesh,
    inflation: PituitaryStyle.boneInflation,
  );

  late final List<ui.Vertices> _sinusMesh = _build(
    (ColouredMesh mesh) => _layRelief(
      mesh,
      form.sinus,
      _sinusTone,
      shown: form.boneShownAt,
      cell: PituitaryStyle.boneCell,
      grid: PituitaryStyle.boneMesh,
      inflation: PituitaryStyle.boneInflation,
      sheen: 0,
    ),
  );

  /// What the brain draws round the stalk: each its own mesh, fading out
  /// above the third ventricle's floor.
  late final List<ui.Vertices> _hypothalamusMesh = _build(
    (ColouredMesh mesh) => _layRelief(
      mesh,
      form.hypothalamus,
      _wallTone,
      shown: form.brainShownAt,
      sheen: 1,
    ),
  );
  late final List<ui.Vertices> _mammillaryMesh = _build(
    (ColouredMesh mesh) =>
        _layRelief(mesh, form.mammillary, _greyTone, shown: form.brainShownAt),
  );
  late final List<ui.Vertices> _chiasmMesh = _build(
    (ColouredMesh mesh) => _layRelief(
      mesh,
      form.chiasm,
      _whiteTone,
      shown: form.brainShownAt,
      gain: PituitaryStyle.whiteGain,
    ),
  );
  late final List<ui.Vertices> _stalkMesh = _build(
    (ColouredMesh mesh) => _layRelief(
      mesh,
      form.stalk,
      _wallTone,
      shown: form.brainShownAt,
      sheen: 1,
    ),
  );

  /// The lobes, each cushioned, where it is not the cell's home: there it
  /// is one flat tone.
  late final List<ui.Vertices> _anteriorMesh = _build((ColouredMesh mesh) {
    if (home != PituitaryHome.anterior) {
      _layRelief(mesh, form.anterior, _anteriorTone);
    }
  });
  late final List<ui.Vertices> _posteriorMesh = _build((ColouredMesh mesh) {
    if (home != PituitaryHome.posterior) {
      _layRelief(mesh, form.posterior, _posteriorTone);
    }
  });

  /// The sinus's rim where the bone round it shows: a shadow just inside
  /// its edges that face the lamp, and light just inside those that turn
  /// from it.
  late final List<ui.Vertices> _sinusRim = _build((ColouredMesh mesh) {
    final OpeningRim rim = OpeningRim(
      toward: _light.screen,
      shadow: inks.shadow,
      light: inks.lit(PituitaryStyle.lipLit),
      shadowWidth: form.mm(PituitaryStyle.lipShadow),
      lightWidth: form.mm(PituitaryStyle.lipLight),
      shadowAlpha: PituitaryStyle.lipShadowAlpha,
      lightAlpha: PituitaryStyle.lipLightAlpha,
      probe: form.mm(0.1),
    );
    final List<Offset> run = <Offset>[];
    for (final Offset p in form.sinus) {
      if (form.boneShownAt(p) > 0.9) {
        run.add(p);
      } else if (run.isNotEmpty) {
        rim.lay(mesh, List<Offset>.of(run), _sinus);
        run.clear();
      }
    }
    if (run.isNotEmpty) {
      rim.lay(mesh, run, _sinus);
    }
  });

  /// The arteries on the stalk's front.
  late final List<ui.Vertices> _arteries = _build((ColouredMesh mesh) {
    for (final TubeCourse t in form.portalVessels) {
      t.lay(
        mesh,
        _arteryTone,
        _light,
        _palette,
        _round,
        brightness: PituitaryStyle.tubeLight,
      );
    }
  });

  // The paths.

  late final Path _bone = Path()..addPolygon(form.bone, true);
  late final Path _sinus = Path()..addPolygon(form.sinus, true);
  late final Path _hypothalamus = Path()..addPolygon(form.hypothalamus, true);
  late final Path _mammillary = Path()..addPolygon(form.mammillary, true);
  late final Path _chiasm = Path()..addPolygon(form.chiasm, true);
  late final Path _stalk = Path()..addPolygon(form.stalk, true);
  late final Path _anterior = Path()..addPolygon(form.anterior, true);
  late final Path _posterior = Path()..addPolygon(form.posterior, true);
  late final Path _cleft = Path()..addPolygon(form.cleft, false);
  late final Path _diaphragm = Path()
    ..addPolygon(form.diaphragmFront, false)
    ..addPolygon(form.diaphragmBack, false);

  /// The fossa's edge, the bone's upper face round the gland, where it is
  /// all there.
  late final Path _fossa = () {
    final Path path = Path();
    final List<Offset> run = <Offset>[
      for (final Offset p in form.bone)
        if (form.boneShownAt(p) > 0.99) p,
    ];
    return path..addPolygon(run, false);
  }();

  // The shadow.

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(
      form.mm(PituitaryStyle.shadowX),
      form.mm(PituitaryStyle.shadowY),
    );
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: PituitaryStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(PituitaryStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the gland and what is drawn round it cover, its shadow included:
  /// the room a layer of it needs.
  late final Rect bounds = () {
    Rect box = form.box;
    for (final List<Offset> part in <List<Offset>>[
      form.bone,
      form.sinus,
      form.hypothalamus,
      form.chiasm,
      form.mammillary,
      form.stalk,
    ]) {
      box = box.expandToInclude(_bounds(part));
    }
    for (final TubeCourse t in form.portalVessels) {
      for (int i = 0; i < t.length; i++) {
        box = box.expandToInclude(
          Rect.fromCircle(center: t.centres[i], radius: t.radius[i]),
        );
      }
    }
    return box.inflate(
      form.mm(PituitaryStyle.shadowY + PituitaryStyle.shadowSoft),
    );
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _boneMesh,
    _sinusMesh,
    _hypothalamusMesh,
    _mammillaryMesh,
    _chiasmMesh,
    _stalkMesh,
    _anteriorMesh,
    _posteriorMesh,
    _sinusRim,
    _arteries,
    _bone,
    _sinus,
    _hypothalamus,
    _mammillary,
    _chiasm,
    _stalk,
    _anterior,
    _posterior,
    _cleft,
    _diaphragm,
    _fossa,
    bounds,
  ];

  /// Draws it all, in the scene's units at the gland's real size; [line]
  /// is a pixel.
  void paint(Canvas canvas, double line) {
    // The sphenoid bone, cut, and its sinus, emptied, fading out below and
    // in front; the fossa's edge.
    _clipped(canvas, _bone, _boneMesh);
    _clipped(canvas, _sinus, _sinusMesh);
    canvas.save();
    canvas.clipPath(_sinus);
    _draw(canvas, _sinusRim);
    canvas.restore();
    _stroke(canvas, _fossa, line, inks.lit(PituitaryStyle.edgeLit), 0.6);
    // What the brain draws round the stalk, fading out above the third
    // ventricle's floor.
    _clipped(canvas, _hypothalamus, _hypothalamusMesh);
    _clipped(canvas, _mammillary, _mammillaryMesh);
    _clipped(canvas, _stalk, _stalkMesh);
    _clipped(canvas, _chiasm, _chiasmMesh);
    // The gland: its shadow in the fossa, each lobe, the cleft between the
    // pars anterior and the pars intermedia, its edge.
    _paintShadow(canvas);
    if (home == PituitaryHome.anterior) {
      canvas.drawPath(_anterior, Paint()..color = _home);
    } else {
      _clipped(canvas, _anterior, _anteriorMesh);
    }
    if (home == PituitaryHome.posterior) {
      canvas.drawPath(_posterior, Paint()..color = _home);
    } else {
      _clipped(canvas, _posterior, _posteriorMesh);
    }
    canvas.drawPath(
      _cleft,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(
          form.mm(PituitaryStyle.cleft),
          PituitaryStyle.cleftFloor * line,
        )
        ..color = inks.shadow.withValues(alpha: PituitaryStyle.cleftAlpha),
    );
    _stroke(
      canvas,
      form.outline,
      line,
      inks.lit(PituitaryStyle.edgeLit),
      PituitaryStyle.edgeAlpha,
    );
    // The dura over it, open round the stalk; the arteries down the stalk.
    canvas.drawPath(
      _diaphragm,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(
          form.mm(PituitaryStyle.dura),
          PituitaryStyle.duraFloor * line,
        )
        ..color = inks.lit(PituitaryStyle.duraLit),
    );
    _draw(canvas, _arteries);
  }

  void _stroke(
    Canvas canvas,
    Path path,
    double line,
    Color colour,
    double alpha,
  ) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = colour.withValues(alpha: alpha),
  );

  void _clipped(Canvas canvas, Path shape, List<ui.Vertices> meshes) {
    canvas.save();
    canvas.clipPath(shape);
    _draw(canvas, meshes);
    canvas.restore();
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

    add('bone', _layBone);
    add(
      'chiasm',
      (ColouredMesh mesh) => _layRelief(
        mesh,
        form.chiasm,
        _whiteTone,
        shown: form.brainShownAt,
        gain: PituitaryStyle.whiteGain,
      ),
    );
    add(
      'stalk',
      (ColouredMesh mesh) =>
          _layRelief(mesh, form.stalk, _wallTone, shown: form.brainShownAt),
    );
    if (home != PituitaryHome.anterior) {
      add(
        'anterior',
        (ColouredMesh mesh) => _layRelief(mesh, form.anterior, _anteriorTone),
      );
    }
    if (home != PituitaryHome.posterior) {
      add(
        'posterior',
        (ColouredMesh mesh) => _layRelief(mesh, form.posterior, _posteriorTone),
      );
    }
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
