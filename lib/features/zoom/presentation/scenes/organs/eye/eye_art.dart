import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/cell_archetypes.dart';
import '../../../zoom_inks.dart';
import '../../coloured_mesh.dart';
import '../../specimen_light.dart';
import '../../tube_course.dart';
import 'eye_form.dart';
import 'eye_style.dart';

/// Where in the eye the zoom's cell lives, which its drawing lights in the
/// mark: the pigment epithelium, for an epithelial cell, as the Atlas's
/// retinal pigment epithelial cells are drawn; the retina, for a rod or a
/// cone, a bipolar, amacrine or ganglion cell, Müller glia or any other.
enum EyeHome {
  retina,
  pigmentEpithelium;

  /// Where a cell of [shape] lives.
  static EyeHome of(CellShape shape) =>
      shape == CellShape.epithelial ? pigmentEpithelium : retina;
}

/// The right eye cut level through its optic nerve, drawn as a specimen
/// under the zoom's one lamp: the retina flat in its one tone, the other
/// cut faces lit softly, cushioned a little across. The sclera pale, its
/// outer edge lit as the globe's surface turns away; the cornea clear; the
/// choroid, the iris and the ciliary body dark with pigment, the ciliary
/// muscle lighter; the lens pearly on its zonules; the vitreous and the
/// chambers a clear film. Behind it the optic nerve in the honey, cut along
/// its length through the lamina cribrosa, its fascicles faint, in its
/// sheath, the central retinal artery and vein in it; and round it the
/// medial and lateral recti, dimmer, their tendons pale on the sclera, and
/// the long posterior ciliary arteries, in the blood red.
///
/// Where the zoom's cell lives is in the mark, by its kind and never by
/// gene: the retina, flat, for a cell of the retina; for a pigment
/// epithelial cell, the pigment epithelium under it.
///
/// Everything costly is built once, for one form, one home and one set of
/// inks: meshes in the scene's units, so a frame only hands them on.
final class EyeArt {
  EyeArt(this.form, this.inks, {required this.home})
    : _light = SpecimenLight(SpecimenLamp.zoom),
      _palette = SpecimenPalette(inks);

  final EyeForm form;
  final ZoomInks inks;
  final EyeHome home;
  final SpecimenLight _light;
  final SpecimenPalette _palette;

  bool get _pigmentHome => home == EyeHome.pigmentEpithelium;

  SpecimenTone _tone(Color colour) => SpecimenTone(colour, inks.shadow);

  late final SpecimenTone _scleraTone = _tone(inks.lit(EyeStyle.scleraLit));
  late final SpecimenTone _corneaTone = _tone(inks.lit(EyeStyle.corneaLit));
  late final SpecimenTone _choroidTone = _tone(inks.lit(EyeStyle.choroidLit));
  late final SpecimenTone _ciliaryTone = _tone(inks.lit(EyeStyle.ciliaryLit));
  late final SpecimenTone _muscleTone = _tone(inks.lit(EyeStyle.muscleLit));
  late final SpecimenTone _irisTone = _tone(inks.lit(EyeStyle.irisLit));
  late final SpecimenTone _lensTone = _tone(inks.lit(EyeStyle.lensLit));
  late final SpecimenTone _nucleusTone = _tone(inks.lit(EyeStyle.nucleusLit));
  late final SpecimenTone _filmTone = _tone(inks.lit(EyeStyle.filmLit));
  late final SpecimenTone _nerveTone = _tone(
    Color.lerp(inks.nerve, inks.ground, EyeStyle.nerve)!,
  );
  late final SpecimenTone _duraTone = _tone(inks.lit(EyeStyle.duraLit));
  late final SpecimenTone _gapTone = _tone(inks.shade(EyeStyle.gapShade));
  late final SpecimenTone _arteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, EyeStyle.artery)!,
  );
  late final SpecimenTone _veinTone = _tone(
    Color.lerp(inks.blood, inks.ground, EyeStyle.vein)!,
  );
  late final SpecimenTone _ciliaryArteryTone = _tone(
    Color.lerp(inks.blood, inks.ground, EyeStyle.ciliaryArteryEase)!,
  );

  /// The retina's one tone: the mark over it for a cell that lives there.
  late final Color _retina = home == EyeHome.retina
      ? Color.alphaBlend(
          inks.glow(EyeStyle.retinaMark),
          inks.lit(EyeStyle.retinaLit),
        )
      : inks.lit(EyeStyle.retinaLit);

  // The columns a cut face is laid at: how far across it from its first
  // edge to its second, how far its face turns toward the first edge there
  // (toward the second where it is negative), and how far it is shut in.

  /// A cut face, cushioned a little across.
  static const List<(double, double, double)> _cut = <(double, double, double)>[
    (0, EyeStyle.cushion, 0),
    (0.5, 0, 0),
    (1, -EyeStyle.cushion, 0),
  ];

  /// The sclera and the cornea: cut, and at their outer edge the globe's
  /// surface turning away.
  static const List<(double, double, double)> _rimmed =
      <(double, double, double)>[
        (0, EyeStyle.rimOuter, 0),
        (EyeStyle.rim / 2, EyeStyle.rimMiddle, 0),
        (EyeStyle.rim, 0, 0),
        (1, -EyeStyle.cushion, 0),
      ];

  /// A cut face with faint lines along it at [lines], from -1 to 1 across.
  static List<(double, double, double)> _lined(List<double> lines) {
    const double width = 0.03;
    double turn(double u) => EyeStyle.cushion * (1 - 2 * u);
    final List<(double, double, double)> out = <(double, double, double)>[
      (0, turn(0), 0),
    ];
    for (final double line in lines) {
      final double u = (line + 1) / 2;
      out
        ..add((u - width, turn(u - width), 0))
        ..add((u, turn(u), 1))
        ..add((u + width, turn(u + width), 0));
    }
    return out..add((1, turn(1), 0));
  }

  static final List<(double, double, double)> _fascicled = _lined(<double>[
    for (int k = 1; k <= EyeStyle.fascicles; k++)
      -1 + 2 * k / (EyeStyle.fascicles + 1),
  ]);
  static final List<(double, double, double)> _fibred = _lined(EyeStyle.fibres);

  /// A tube's columns round it, for the vessels.
  static const List<double> _round = <double>[-1, -0.7, 0, 0.7, 1];

  // The coats.

  late final List<ui.Vertices> _sclera = _build(_layScleraAndCornea);

  void _layScleraAndCornea(ColouredMesh mesh) {
    for (final EyeBand band in form.sclera) {
      _layFace(
        mesh,
        form.placed(band.outer),
        form.placed(band.inner),
        (int _) => _scleraTone,
        _rimmed,
      );
    }
    _layFace(
      mesh,
      form.placed(form.cornea.outer),
      form.placed(form.cornea.inner),
      (int _) => _corneaTone,
      _rimmed,
      alpha: (int _) => EyeStyle.corneaAlpha,
    );
  }

  late final List<ui.Vertices> _choroid = _build(_layChoroid);

  void _layChoroid(ColouredMesh mesh) {
    for (final EyeBand band in form.choroid) {
      _layFace(
        mesh,
        form.placed(band.outer),
        form.placed(band.inner),
        (int _) => _choroidTone,
        _cut,
      );
    }
  }

  /// The retina, flat, and the pigment epithelium under it.
  late final List<Path> _retinaPaths = <Path>[
    for (final EyeBand band in form.retina)
      Path()..addPolygon(form.placed(band.outline), true),
  ];
  late final List<Path> _pigmentLines = <Path>[
    for (final EyeBand band in form.retina) _polyline(form.placed(band.outer)),
  ];

  /// The retina's middle, along which its halo in the mark is drawn when
  /// it is home, as the zoom draws a home too fine to see at a glance.
  late final List<Path> _retinaMiddles = <Path>[
    for (final EyeBand band in form.retina)
      _polyline(<Offset>[
        for (int i = 0; i < band.length; i++)
          form.place((band.outer[i] + band.inner[i]) / 2),
      ]),
  ];

  // The ciliary body, the iris and the lens.

  late final List<ui.Vertices> _ciliary = _build(_layCiliary);

  void _layCiliary(ColouredMesh mesh) {
    for (final EyeBand band in form.ciliary) {
      _layFace(
        mesh,
        form.placed(band.outer),
        form.placed(band.inner),
        (int _) => _ciliaryTone,
        _cut,
      );
    }
    for (final EyeBand band in form.muscles) {
      _layFace(
        mesh,
        form.placed(band.outer),
        form.placed(band.inner),
        (int _) => _muscleTone,
        _cut,
      );
    }
  }

  late final List<ui.Vertices> _iris = _build(_layIris);

  void _layIris(ColouredMesh mesh) {
    for (final EyeBand band in form.iris) {
      _layFace(
        mesh,
        form.placed(band.outer),
        form.placed(band.inner),
        (int _) => _irisTone,
        _cut,
      );
    }
  }

  /// The iris's back, its pigment epithelium, a dark line.
  late final List<Path> _irisBacks = <Path>[
    for (final EyeBand band in form.iris) _polyline(form.placed(band.inner)),
  ];

  late final List<ui.Vertices> _lens = _build(_layLenses);

  void _layLenses(ColouredMesh mesh) {
    final Offset middle = form.place(EyeForm.lensMiddle);
    _layLens(mesh, form.placed(form.lensMm), middle, _lensTone);
    _layLens(mesh, form.placed(form.nucleusMm), middle, _nucleusTone);
  }

  /// The lens's capsule, a fine bright line round it.
  late final Path _capsule = Path()..addPolygon(form.placed(form.lensMm), true);

  late final Path _zonules = () {
    final Path path = Path();
    for (final (Offset from, Offset to) in form.zonules) {
      final Offset a = form.place(from);
      final Offset b = form.place(to);
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();

  /// The vitreous and the chambers, a clear film over the ground, its cut
  /// face cushioned as a gel's is.
  late final List<ui.Vertices> _vitreous = _build(_layVitreous);

  void _layVitreous(ColouredMesh mesh) {
    final List<Offset> outline = form.placed(form.interiorMm);
    final Rect box = form.interior.getBounds();
    _layLens(
      mesh,
      outline,
      box.center,
      _filmTone,
      tilt: EyeStyle.vitreousTilt,
      alpha: EyeStyle.filmAlpha,
    );
  }

  /// [outline], laid as rings from its rim in to [middle], the cut face's
  /// cushion turning it outward toward its rim by [tilt] there, at [alpha].
  void _layLens(
    ColouredMesh mesh,
    List<Offset> outline,
    Offset middle,
    SpecimenTone tone, {
    double tilt = EyeStyle.lensTilt,
    double alpha = 1,
  }) {
    const List<double> rings = <double>[0, 0.12, 0.3, 0.55, 0.8, 1];
    final int n = outline.length;
    mesh.begin(n * rings.length);
    final int first = mesh.next;
    for (final Offset rim in outline) {
      final Offset d = rim - middle;
      final Offset out = d.distance <= 0 ? Offset.zero : d / d.distance;
      for (final double f in rings) {
        final Offset p = Offset.lerp(rim, middle, f)!;
        final double turn = tilt * (1 - f);
        final double nz = math.sqrt(1 - turn * turn);
        final double nx = out.dx * turn;
        final double ny = out.dy * turn;
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            tone,
            _light.light(nx, ny, nz, form: nz),
            sheen: _light.sheen(nx, ny, nz) * EyeStyle.cutSheen,
            alpha: alpha,
          ),
        );
      }
    }
    for (int i = 0; i < n; i++) {
      final int a = first + i * rings.length;
      final int b = first + ((i + 1) % n) * rings.length;
      for (int k = 0; k + 1 < rings.length; k++) {
        mesh
          ..triangle(a + k, a + k + 1, b + k)
          ..triangle(a + k + 1, b + k + 1, b + k);
      }
    }
  }

  // The optic nerve.

  /// Its sheath: the subarachnoid space dark between the dura and the
  /// nerve, the dura either side.
  late final List<ui.Vertices> _sheath = _build(_laySheath);

  void _laySheath(ColouredMesh mesh) {
    final TubeCourse s = form.sheath;
    final double dura = form.mm(EyeStyle.dura);
    final List<Offset> plus = <Offset>[];
    final List<Offset> plusIn = <Offset>[];
    final List<Offset> minus = <Offset>[];
    final List<Offset> minusIn = <Offset>[];
    for (int i = 0; i < s.length; i++) {
      final Offset c = s.centres[i];
      final Offset m = s.across[i];
      plus.add(c + m * s.plus[i]);
      plusIn.add(c + m * math.max(0.0, s.plus[i] - dura));
      minus.add(c - m * s.minus[i]);
      minusIn.add(c - m * math.max(0.0, s.minus[i] - dura));
    }
    double shown(int i) => s.shown[i];
    _layFace(
      mesh,
      plusIn,
      minusIn,
      (int _) => _gapTone,
      const <(double, double, double)>[(0, 0, 0), (1, 0, 0)],
      alpha: shown,
    );
    _layFace(mesh, plus, plusIn, (int _) => _duraTone, _cut, alpha: shown);
    _layFace(mesh, minus, minusIn, (int _) => _duraTone, _cut, alpha: shown);
  }

  /// The nerve cut along its length, its fascicles faint lines along it.
  late final List<ui.Vertices> _nerve = _build(_layNerve);

  void _layNerve(ColouredMesh mesh) {
    final TubeCourse n = form.nerve;
    _layFace(
      mesh,
      <Offset>[for (int i = 0; i < n.length; i++) n.at(i, -1)],
      <Offset>[for (int i = 0; i < n.length; i++) n.at(i, 1)],
      (int _) => _nerveTone,
      _fascicled,
      shut: (int _) => EyeStyle.fascicleAlpha,
      alpha: (int i) => n.shown[i],
    );
  }

  /// The disc's cup, a hollow in the nerve's face.
  late final Path _cup = Path()..addPolygon(form.placed(form.cupMm), true);

  /// The lamina cribrosa, fine lines across the scleral canal.
  late final Path _lamina = () {
    final Path path = Path();
    for (final (Offset from, Offset to) in form.lamina) {
      final Offset a = form.place(from);
      final Offset b = form.place(to);
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    return path;
  }();

  late final List<ui.Vertices> _central = _build(_layCentral);

  void _layCentral(ColouredMesh mesh) {
    form.central[0].lay(mesh, _arteryTone, _light, _palette, _round);
    form.central[1].lay(mesh, _veinTone, _light, _palette, _round);
  }

  // What lies round it.

  /// The recti, cut along their length: each a pale tendon where it
  /// inserts, darkening into its belly, its fibres faint lines along it.
  late final List<ui.Vertices> _recti = _build(_layRecti);

  void _layRecti(ColouredMesh mesh) {
    final Color tendon = inks.lit(EyeStyle.tendonLit);
    final Color muscle = inks.lit(EyeStyle.rectusLit);
    final double run = form.mm(EyeStyle.tendonRun);
    for (final TubeCourse r in form.recti) {
      double belly(int i) => _smooth(r.arc[i] / run);
      _layFace(
        mesh,
        <Offset>[for (int i = 0; i < r.length; i++) r.at(i, -1)],
        <Offset>[for (int i = 0; i < r.length; i++) r.at(i, 1)],
        (int i) => _tone(Color.lerp(tendon, muscle, belly(i))!),
        _fibred,
        brightness: EyeStyle.neighbourLight,
        shut: (int i) => EyeStyle.fibreAlpha * belly(i),
        alpha: (int i) => r.shown[i],
      );
    }
  }

  late final List<ui.Vertices> _ciliaryArteries = _build(_layCiliaryArteries);

  void _layCiliaryArteries(ColouredMesh mesh) {
    for (final TubeCourse a in form.ciliaryArteries) {
      a.lay(
        mesh,
        _ciliaryArteryTone,
        _light,
        _palette,
        _round,
        brightness: EyeStyle.neighbourLight,
      );
    }
  }

  // The shadows.

  /// The tubes' shadows on what lies behind them, fading as they do.
  late final List<ui.Vertices> _tubeShadows = _build((ColouredMesh mesh) {
    final Offset offset = Offset(
      form.mm(EyeStyle.shadowX),
      form.mm(EyeStyle.shadowY),
    );
    for (final TubeCourse t in <TubeCourse>[...form.recti, form.sheath]) {
      mesh.begin(4 * t.length);
      final int first = mesh.next;
      for (int i = 0; i < t.length; i++) {
        final Offset a = t.at(i, -1) + offset;
        final Offset b = t.at(i, 1) + offset;
        final double alpha = EyeStyle.shadowAlpha * t.shown[i];
        for (final (double u, double share) in const <(double, double)>[
          (-0.25, 0),
          (0, 1),
          (1, 1),
          (1.25, 0),
        ]) {
          final Offset p = Offset.lerp(a, b, u)!;
          mesh.vertex(
            p.dx,
            p.dy,
            SpecimenPalette.packColour(inks.shadow, alpha * share),
          );
        }
      }
      for (int i = 0; i + 1 < t.length; i++) {
        final int a = first + 4 * i;
        final int b = a + 4;
        for (int k = 0; k < 3; k++) {
          mesh
            ..triangle(a + k, a + k + 1, b + k)
            ..triangle(a + k + 1, b + k + 1, b + k);
        }
      }
    }
  });

  void _paintShadow(Canvas canvas) {
    canvas.save();
    canvas.translate(form.mm(EyeStyle.shadowX), form.mm(EyeStyle.shadowY));
    final Color shadow = inks.shadow;
    canvas.drawPath(
      form.outline,
      Paint()..color = shadow.withValues(alpha: EyeStyle.shadowAlpha),
    );
    canvas.drawPath(
      form.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = form.mm(EyeStyle.shadowSoft)
        ..strokeJoin = StrokeJoin.round
        ..color = shadow.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  // Drawing.

  /// What the eye and what lies round it cover, their shadows included:
  /// the room a layer of them needs.
  late final Rect bounds = () {
    Rect box = form.outline.getBounds();
    for (final TubeCourse tube in <TubeCourse>[
      form.sheath,
      ...form.recti,
      ...form.ciliaryArteries,
    ]) {
      double widest = 0;
      for (final double r in tube.radius) {
        widest = math.max(widest, r);
      }
      box = box.expandToInclude(tube.line.getBounds().inflate(widest));
    }
    return box.inflate(form.mm(EyeStyle.shadowY + EyeStyle.shadowSoft));
  }();

  /// Builds every mesh and path a frame will draw.
  void prepare() => <Object?>[
    _sclera,
    _choroid,
    _retinaPaths,
    _pigmentLines,
    _retinaMiddles,
    _ciliary,
    _iris,
    _irisBacks,
    _lens,
    _capsule,
    _zonules,
    _sheath,
    _nerve,
    _cup,
    _lamina,
    _central,
    _recti,
    _ciliaryArteries,
    _tubeShadows,
    _vitreous,
    form.schlemm,
    bounds,
  ];

  /// Draws it all, in the scene's units at the eye's real size; [line] is
  /// a pixel.
  void paint(Canvas canvas, double line) {
    _paintShadow(canvas);
    _draw(canvas, _tubeShadows);
    // Round it: the recti; the vitreous and the chambers, a clear film.
    _draw(canvas, _recti);
    _draw(canvas, _vitreous);
    // The nerve in its sheath, its cup, its vessels.
    _draw(canvas, _sheath);
    _draw(canvas, _nerve);
    canvas.drawPath(_cup, Paint()..color = inks.shade(EyeStyle.cupShade));
    _draw(canvas, _central);
    // The coats: the choroid, the retina on its pigment epithelium, the
    // sclera and the cornea.
    final Paint halo = _stroke(
      inks.glow(EyeStyle.haloAlpha),
      EyeStyle.halo * line,
    );
    if (!_pigmentHome) {
      for (final Path path in _retinaMiddles) {
        canvas.drawPath(path, halo);
      }
    }
    _draw(canvas, _choroid);
    final Paint retina = Paint()..color = _retina;
    for (final Path path in _retinaPaths) {
      canvas.drawPath(path, retina);
    }
    if (_pigmentHome) {
      for (final Path path in _pigmentLines) {
        canvas.drawPath(path, halo);
      }
    }
    final Paint pigment = _stroke(
      _pigmentHome ? inks.glow(0.95) : inks.shade(EyeStyle.pigmentShade),
      (_pigmentHome ? EyeStyle.homeFloor : EyeStyle.pigmentFloor) * line,
    );
    for (final Path path in _pigmentLines) {
      canvas.drawPath(path, pigment);
    }
    _draw(canvas, _sclera);
    // The ciliary body, the iris and the lens on its zonules.
    _draw(canvas, _ciliary);
    _draw(canvas, _iris);
    final Paint back = _stroke(
      inks.shade(EyeStyle.pigmentShade),
      EyeStyle.fineFloor * line,
    );
    for (final Path path in _irisBacks) {
      canvas.drawPath(path, back);
    }
    canvas.drawPath(
      _zonules,
      _stroke(
        inks.lit(EyeStyle.zonuleLit).withValues(alpha: EyeStyle.zonuleAlpha),
        math.max(form.mm(EyeStyle.zonule), EyeStyle.fineFloor * line),
      ),
    );
    _draw(canvas, _lens);
    canvas.drawPath(
      _capsule,
      _stroke(
        inks.lit(EyeStyle.capsuleLit),
        math.max(form.mm(EyeStyle.capsule), EyeStyle.fineFloor * line),
      ),
    );
    // Schlemm's canal at the limbus; the lamina cribrosa across the canal;
    // the ciliary arteries forward between the sclera and the choroid.
    final Paint schlemm = Paint()..color = inks.shade(EyeStyle.schlemmShade);
    for (final (Offset at, Offset along) in form.schlemm) {
      canvas.save();
      final Offset c = form.place(at);
      canvas.translate(c.dx, c.dy);
      canvas.rotate(math.atan2(along.dy, along.dx));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: math.max(
            form.mm(EyeStyle.schlemmLong),
            2 * EyeStyle.schlemmFloor * line,
          ),
          height: math.max(
            form.mm(EyeStyle.schlemmWide),
            EyeStyle.schlemmFloor * line,
          ),
        ),
        schlemm,
      );
      canvas.restore();
    }
    canvas.drawPath(
      _lamina,
      _stroke(
        inks.lit(EyeStyle.laminaLit).withValues(alpha: EyeStyle.laminaAlpha),
        math.max(form.mm(EyeStyle.laminaLine), EyeStyle.fineFloor * line),
      ),
    );
    _draw(canvas, _ciliaryArteries);
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

    add('vitreous', _layVitreous);
    add('sclera', _layScleraAndCornea);
    add('choroid', _layChoroid);
    add('ciliary', _layCiliary);
    add('iris', _layIris);
    add('lens', _layLenses);
    add('sheath', _laySheath);
    add('nerve', _layNerve);
    add('recti', _layRecti);
    add('vessels', (ColouredMesh mesh) {
      _layCentral(mesh);
      _layCiliaryArteries(mesh);
    });
    return out;
  }

  // Helpers.

  /// A cut face laid in [mesh] between two edges in the scene, [a] and [b],
  /// point for point: at each of [columns] across from a to b, lit as the
  /// face there turns, in [tone] for its row, shut in by its share of
  /// [shut] for its row, at [alpha] for its row.
  void _layFace(
    ColouredMesh mesh,
    List<Offset> a,
    List<Offset> b,
    SpecimenTone Function(int) tone,
    List<(double, double, double)> columns, {
    double brightness = 1,
    double Function(int)? shut,
    double Function(int)? alpha,
  }) {
    final int n = a.length;
    final int around = columns.length;
    if (n < 2) {
      return;
    }
    mesh.begin(n * around);
    final int first = mesh.next;
    for (int i = 0; i < n; i++) {
      final Offset d = a[i] - b[i];
      final double length = d.distance;
      final Offset out = length <= 0 ? Offset.zero : d / length;
      final SpecimenTone t = tone(i);
      final double closed = shut == null ? 0 : shut(i);
      final double shown = alpha == null ? 1 : alpha(i);
      for (final (double u, double turn, double occlusion) in columns) {
        final Offset p = Offset.lerp(a[i], b[i], u)!;
        final double nz = math.sqrt(math.max(0, 1 - turn * turn));
        final double nx = out.dx * turn;
        final double ny = out.dy * turn;
        mesh.vertex(
          p.dx,
          p.dy,
          _palette.colour(
            t,
            _light.light(nx, ny, nz, form: nz) * brightness,
            occlusion: occlusion * closed,
            sheen: _light.sheen(nx, ny, nz) * EyeStyle.cutSheen * brightness,
            alpha: shown,
          ),
        );
      }
    }
    for (int i = 0; i + 1 < n; i++) {
      final int r = first + i * around;
      final int s = r + around;
      for (int k = 0; k + 1 < around; k++) {
        mesh
          ..triangle(r + k, r + k + 1, s + k)
          ..triangle(r + k + 1, s + k + 1, s + k);
      }
    }
  }

  static Path _polyline(List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  static Paint _stroke(Color colour, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = colour;

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

double _smooth(double t) {
  final double x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}
