import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../zoom_inks.dart';
import '../coloured_mesh.dart';
import '../sculpt.dart';
import '../zoom_scene.dart';
import 'chromosome_form.dart';
import 'chromosome_shading.dart';
import 'chromosome_style.dart';

/// A chromosome at rest, its form a scanning micrograph's and its surface
/// lit as the zoom's organs are, under the same lamp: two sisters, knobbly
/// with opaque lobes of chromatin, each lobe lit from the upper left with a
/// moist sheen and dark in the crevices round it, each sister darker toward
/// its edges and along the groove where they touch, a shadow under them, the
/// bands soft changes of tone, the centromere's waist and its two
/// kinetochores tinted in its ink and every chromatid's ends in the
/// telomeres', and the gene as two FISH spots, one on each sister.
///
/// Everything costly is built once, for one form in one set of inks: the
/// body and its relief are meshes in the scene's units, so a frame only
/// hands them on, at any magnification. The form's look tunes it.
final class ChromosomeArt {
  ChromosomeArt(this.form, this.inks)
    : _light = ChromosomeLight(look: form.look),
      _palette = ChromosomePalette(inks, look: form.look);

  final ChromosomeForm form;
  final ZoomInks inks;
  final ChromosomeLight _light;
  final ChromosomePalette _palette;

  double get _half => form.half;

  ChromosomeLookSpec get _look => form.look;

  /// Each sister's body, its lobes and its kinetochore, left then right.
  late final List<List<ui.Vertices>> _sisters = <List<ui.Vertices>>[
    _sister(-1),
    _sister(1),
  ];

  /// Each sister's granules, left then right.
  late final List<List<ui.Vertices>> _granules = <List<ui.Vertices>>[
    _grains(-1),
    _grains(1),
  ];

  /// Each sister's outline, for its shadow and its coat.
  late final List<Path> _outlines = <Path>[
    form.chromatid(-1).toPath(),
    form.chromatid(1).toPath(),
  ];

  /// The groove where the sisters touch: the right sister's inner edge, the
  /// one drawn over the other, darkest where the arms meet at the waist.
  late final Path _seam = () {
    final Path path = Path();
    final Float64List rows = form.bodyRows;
    for (int i = 0; i < rows.length; i++) {
      final double y = rows[i];
      final double x = form.centreAt(1, y) - form.widthAt(y);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }();

  late final Rect _seamBox = _seam.getBounds().inflate(_half);

  late final Shader _seamShade = () {
    const int stops = 33;
    final double top = form.top;
    final double length = form.bottom - top;
    final List<double> at = <double>[];
    final List<Color> colours = <Color>[];
    for (int i = 0; i < stops; i++) {
      final double t = i / (stops - 1);
      final double y = top + length * t;
      final double d = ((y - form.centromere).abs() - _half) / (0.8 * _half);
      final double crotch = math.exp(-d * d);
      at.add(t);
      colours.add(
        inks.shadow.withValues(
          alpha: (form.contact(y) * (0.45 + 0.55 * crotch)).clamp(0.0, 1.0),
        ),
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colours,
      stops: at,
    ).createShader(
      Rect.fromLTRB(_seamBox.left, top, _seamBox.right, top + length),
    );
  }();

  /// What the chromosome at rest covers, its shadow and its relief included,
  /// in the scene's units: the room a layer of it needs.
  late final Rect bounds = _outlines[0]
      .getBounds()
      .expandToInclude(_outlines[1].getBounds())
      .inflate(_look.boundsInflate * _half);

  /// The body's colour averaged over its area on both sisters, lit as it
  /// is, the gene's wash and the centromere's and telomeres' tints left out:
  /// what the territory's mark gives way to as the chromosome condenses out
  /// of it.
  late final Color meanTone = () {
    final Float64List rows = form.bodyRows;
    final List<double> columns = _columns;
    double r = 0;
    double g = 0;
    double b = 0;
    double total = 0;
    for (final double side in <double>[-1, 1]) {
      for (int i = 0; i + 1 < rows.length; i++) {
        final double y = (rows[i] + rows[i + 1]) / 2;
        final double w = form.widthAt(y);
        final double slope = form.slope(y);
        final double tone = form.toneAt(y);
        for (int j = 0; j + 1 < columns.length; j++) {
          final double u = (columns[j] + columns[j + 1]) / 2;
          final double area =
              (rows[i + 1] - rows[i]) * w * (columns[j + 1] - columns[j]);
          final SurfaceNormal n = SurfaceNormal(
            u,
            -slope,
            math.sqrt(math.max(0, 1 - u * u)),
          );
          final _Lit s = _surface(side, y, u, n.x, n.y, n.z, facing: n.z);
          final (double, double, double) mix = _palette.mix(
            tone,
            s.light,
            s.occlusion,
            0,
            sheen: s.sheen,
          );
          r += mix.$1 * area;
          g += mix.$2 * area;
          b += mix.$3 * area;
          total += area;
        }
      }
    }
    return total <= 0
        ? inks.lit(_look.paleLit)
        : Color.from(
            alpha: 1,
            red: r / total,
            green: g / total,
            blue: b / total,
          );
  }();

  /// Builds every mesh now rather than at the first frame.
  void prepare() => <Object?>[
    _sisters,
    _granules,
    _outlines,
    _seamShade,
    bounds,
    meanTone,
  ];

  /// The chromosome at rest, without its spots. On its way into the band's
  /// map, each sister is moved [merge] of the way onto the axis at the
  /// band's height and thinned [thin] of the way to [target] half-width
  /// there, as the tube under it is: its shadow, its coat and the groove
  /// go with it.
  void paintRest(
    Canvas canvas,
    ZoomFrame frame, {
    double merge = 0,
    double thin = 0,
    double target = 0,
  }) {
    final double pixel = frame.pixel;
    final bool still = merge == 0 && thin == 0;
    // [draw] for sister [i], moved with it.
    void sister(int i, void Function() draw) {
      if (still) {
        draw();
        return;
      }
      canvas.save();
      _toward(canvas, i == 0 ? -1 : 1, merge, thin, target);
      draw();
      canvas.restore();
    }

    // The shadow the sisters cast, under them and to the lower right, as the
    // organs cast theirs. Nothing else lies round them.
    canvas.save();
    canvas.translate(_look.shadowX * _half, _look.shadowY * _half);
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        canvas.drawPath(
          _outlines[i],
          Paint()..color = inks.shadow.withValues(alpha: _look.shadowAlpha),
        );
        canvas.drawPath(
          _outlines[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _look.shadowSoft * _half
            ..strokeJoin = StrokeJoin.round
            ..color = inks.shadow.withValues(alpha: 0.12),
        );
      });
    }
    canvas.restore();
    final Paint mesh = Paint();
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        for (final ui.Vertices vertices in _sisters[i]) {
          canvas.drawVertices(vertices, BlendMode.dst, mesh);
        }
        for (final ui.Vertices vertices in _granules[i]) {
          canvas.drawVertices(vertices, BlendMode.dst, mesh);
        }
      });
    }
    // The groove, soft and then sharp: the right sister's facing side.
    sister(1, () {
      canvas.drawPath(
        _seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * pixel
          ..strokeCap = StrokeCap.round
          ..shader = _seamShade
          ..color = inks.shadow.withValues(alpha: 0.3),
      );
      canvas.drawPath(
        _seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2 * pixel, 0.07 * _half)
          ..strokeCap = StrokeCap.round
          ..shader = _seamShade,
      );
    });
  }

  /// Moves [canvas] so that sister [side] is drawn [merge] of the way onto
  /// the axis at the band's height and [thin] of the way to [target]
  /// half-width there, about its own middle.
  void _toward(
    Canvas canvas,
    double side,
    double merge,
    double thin,
    double target,
  ) {
    final double y = form.bandY;
    final double from = form.centreAt(side, y);
    final double w = form.widthAt(y);
    canvas.translate(form.centreAt(side, y, merge: merge), 0);
    canvas.scale(w <= 0 ? 1 : (w + (target - w) * thin) / w, 1);
    canvas.translate(-from, 0);
  }

  /// The spots' core: the mark lightened toward the bright ink.
  late final Color _core = Color.lerp(inks.mark, inks.text, 0.55)!;

  /// The gene's two FISH spots, one on each sister at its height: a core of
  /// the mark lightened toward the bright ink, in its glow.
  void paintSpots(Canvas canvas, {double opacity = 1, double merge = 0}) {
    if (opacity <= 0.002) {
      return;
    }
    final double r = form.fishRadius;
    for (final double side in <double>[-1, 1]) {
      paintSpot(
        canvas,
        form.fish(side, merge: merge),
        r,
        _look.fishGlow * r,
        0.38 * opacity,
        opacity,
      );
    }
  }

  /// One FISH spot at [at]: its core [radius] across, at [opacity], in a
  /// glow of the mark [reach] out and [glow] at its heart.
  void paintSpot(
    Canvas canvas,
    Offset at,
    double radius,
    double reach,
    double glow,
    double opacity,
  ) {
    Sculpt.glow(canvas, at, reach, inks, glow);
    final Rect box = Rect.fromCircle(center: at, radius: radius);
    canvas.drawOval(
      box,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _core.withValues(alpha: opacity),
            inks.glow(0.95 * opacity),
            inks.glow(0.35 * opacity),
            inks.glow(0),
          ],
          stops: const <double>[0, 0.42, 0.75, 1],
        ).createShader(box),
    );
  }

  /// The spots flaring as the chromosome is reached, [t] of the way through
  /// the beat: nothing before it starts or after it ends.
  void paintFlare(Canvas canvas, ZoomFrame frame, double t, double opacity) {
    if (t <= 0 || t >= 1 || opacity <= 0) {
      return;
    }
    final double r = form.fishRadius;
    final double out = Curves.easeOutCubic.transform(t);
    for (final double side in <double>[-1, 1]) {
      final Offset at = form.fish(side);
      Sculpt.glow(
        canvas,
        at,
        r * (1.2 + 1.6 * out),
        inks,
        0.5 * math.sin(math.pi * t) * opacity,
      );
      Sculpt.ping(
        canvas,
        at,
        r,
        r * 1.6,
        t,
        frame.pixel,
        inks,
        opacity: opacity,
      );
    }
  }

  // The meshes.

  /// How a surface facing (nx, ny, nz) at [y], [u] of the way across the
  /// tube (the sine of its angle round it), on chromatid [side], is lit,
  /// where the sister's own face turns [facing] of the way toward the eye:
  /// its light, the shade of the groove where it is turned to its sister,
  /// and its sheen.
  _Lit _surface(
    double side,
    double y,
    double u,
    double nx,
    double ny,
    double nz, {
    required double facing,
  }) {
    final double turned = _smoothstep(0.3, 1, -side * u);
    return (
      light: _light.light(nx, ny, nz, facing: facing),
      occlusion: _look.occlusion * turned * form.contact(y),
      sheen: _light.sheen(nx, ny, nz),
    );
  }

  /// How far the chromatin at [y] is tinted toward the centromere's ink and
  /// toward the telomeres'.
  ({double centromere, double telomere}) _tints(double y) => (
    centromere: _look.centromereTint * form.centromereAt(y),
    telomere: _look.telomereTint * form.telomereAt(y),
  );

  /// How far across the tube each of the body's columns lies, from one
  /// edge to the other: the sine of its angle round it.
  late final List<double> _columns = <double>[
    for (final double u in _look.columns.reversed) -u,
    ..._look.columns.skip(1),
  ];

  /// Every mesh's vertices as built, for tests: where each lies, in the
  /// scene's units, and its colour.
  @visibleForTesting
  List<({Float32List positions, Int32List colours})> get meshData {
    final List<({Float32List positions, Int32List colours})> out =
        <({Float32List positions, Int32List colours})>[];
    for (final double side in <double>[-1, 1]) {
      for (final void Function(ColouredMesh, double) lay
          in <void Function(ColouredMesh, double)>[_laySister, _layGrains]) {
        final ColouredMesh mesh = ColouredMesh(keep: true);
        lay(mesh, side);
        mesh.build();
        out.addAll(mesh.kept);
      }
    }
    return out;
  }

  List<ui.Vertices> _sister(double side) {
    final ColouredMesh mesh = ColouredMesh();
    _laySister(mesh, side);
    return mesh.build();
  }

  void _laySister(ColouredMesh mesh, double side) {
    final Float64List rows = form.bodyRows;
    final List<double> columns = _columns;
    final int across = columns.length;
    // The body: a sheet of rows across the tube, lit vertex by vertex.
    mesh.begin(rows.length * across);
    final int first = mesh.next;
    for (final double y in rows) {
      final double w = form.widthAt(y);
      final double centre = form.centreAt(side, y);
      final double bow = form.bowAt(y);
      final double slope = form.slope(y);
      final double tone = form.toneAt(y);
      final double gene = form.geneAt(y);
      final ({double centromere, double telomere}) tint = _tints(y);
      for (final double u in columns) {
        final double nz = math.sqrt(math.max(0, 1 - u * u));
        final SurfaceNormal n = SurfaceNormal(u, -slope, nz);
        final _Lit s = _surface(side, y, u, n.x, n.y, n.z, facing: n.z);
        mesh.vertex(
          centre + w * u,
          y + bow * u * u,
          _palette.colour(
            tone,
            s.light,
            s.occlusion,
            gene,
            1,
            centromere: tint.centromere,
            telomere: tint.telomere,
            sheen: s.sheen,
          ),
        );
      }
    }
    for (int i = 0; i + 1 < rows.length; i++) {
      for (int j = 0; j + 1 < across; j++) {
        final int a = first + i * across + j;
        final int b = a + 1;
        final int c = a + across;
        final int d = c + 1;
        mesh.triangle(a, b, c);
        mesh.triangle(b, d, c);
      }
    }
    // The lobes, each over the crevice round it: a lobe laid after another
    // shades it where the two meet, as a crevice between them would.
    final KnobField knobs = form.knobs(side);
    for (int k = 0; k < knobs.length; k++) {
      if (knobs.kind[k] == KnobField.lobe) {
        _skirt(mesh, side, knobs, k);
        _dome(mesh, side, knobs, k);
      }
    }
    _plate(mesh, side);
  }

  /// Where knob [k] lies on screen, its surface's normal there, and the
  /// two axes of the ellipse it is seen as: a disc on the surface, squashed
  /// along the way the surface turns from the eye.
  _Knob _place(double side, KnobField knobs, int k) {
    final double y = knobs.y[k];
    final double phi = knobs.phi[k];
    final double u = math.sin(phi);
    final double r = knobs.radius[k];
    final SurfaceNormal n = SurfaceNormal(u, -form.slope(y), math.cos(phi));
    final double flat = math.sqrt(n.x * n.x + n.y * n.y);
    final double dx = flat < 1e-6 ? 1 : n.x / flat;
    final double dy = flat < 1e-6 ? 0 : n.y / flat;
    final double squash = math.max(n.z, 0.45);
    return _Knob(
      x: form.centreAt(side, y) + form.widthAt(y) * u,
      y: y + form.bowAt(y) * u * u,
      normal: n,
      // The squashed axis, along the turn, and the full one across it.
      ax: dx * r * squash,
      ay: dy * r * squash,
      bx: -dy * r,
      by: dx * r,
    );
  }

  void _skirt(ColouredMesh mesh, double side, KnobField knobs, int k) =>
      _skirtOf(mesh, _place(side, knobs, k));

  /// The crevice round [p]: shade falling away from its edge.
  void _skirtOf(ColouredMesh mesh, _Knob p) {
    const int ring = 12;
    mesh.begin(ring * 2);
    final int first = mesh.next;
    final int dark = _palette.shadow(_look.skirtAlpha);
    final int clear = _palette.shadow(0);
    for (final (double scale, int colour) in <(double, int)>[
      (_look.skirtInner, dark),
      (_look.skirtOuter, clear),
    ]) {
      for (int i = 0; i < ring; i++) {
        final Offset at = p.at(2 * math.pi * i / ring, scale);
        mesh.vertex(at.dx, at.dy, colour);
      }
    }
    for (int i = 0; i < ring; i++) {
      final int a = first + i;
      final int b = first + (i + 1) % ring;
      mesh.triangle(a, b, a + ring);
      mesh.triangle(b, b + ring, a + ring);
    }
  }

  void _dome(ColouredMesh mesh, double side, KnobField knobs, int k) {
    final double y = knobs.y[k];
    _domeOf(
      mesh,
      side,
      _place(side, knobs, k),
      y,
      math.sin(knobs.phi[k]),
      knobs.radius[k],
      form.geneAt(y),
      _tints(y),
    );
  }

  /// [p] as a small opaque dome at [y], [u] of the way across the tube and
  /// [r] across: lit as the surface under it is, its rim tilted out from its
  /// top, so it is lit on the side toward the light and in shade on the
  /// other, with its sheen between, [gene] of the way into the gene's band
  /// and tinted by [tint].
  void _domeOf(
    ColouredMesh mesh,
    double side,
    _Knob p,
    double y,
    double u,
    double r,
    double gene,
    ({double centromere, double telomere}) tint,
  ) {
    const int ring = 14;
    final double tone = form.toneAt(y);
    final SurfaceNormal base = p.normal;
    _Lit lit(double tilt, double a) {
      // The ring's normal, tilted out from the dome's top toward [a].
      final Offset out = p.at(a, 1) - Offset(p.x, p.y);
      final double length = out.distance;
      final SurfaceNormal n = length < 1e-12
          ? base
          : SurfaceNormal(
              base.x + tilt * out.dx / length,
              base.y + tilt * out.dy / length,
              base.z,
            );
      // Darker toward the sister's edges, as the surface under it is.
      return _surface(side, y, u, n.x, n.y, n.z, facing: base.z);
    }

    mesh.begin(1 + ring * 3);
    final int centre = mesh.next;
    final _Lit top = lit(0, 0);
    mesh.vertex(
      p.x + _light.screen.dx * 0.22 * r,
      p.y + _light.screen.dy * 0.22 * r,
      _palette.colour(
        tone,
        top.light,
        top.occlusion,
        gene,
        1,
        centromere: tint.centromere,
        telomere: tint.telomere,
        sheen: top.sheen,
      ),
    );
    final List<int> rim = <int>[];
    for (final (double scale, double tilt) in <(double, double)>[
      (0.62, 0.4 * _look.lobeTilt),
      (1, _look.lobeTilt),
    ]) {
      for (int i = 0; i < ring; i++) {
        final double a = 2 * math.pi * i / ring;
        final _Lit s = lit(tilt, a);
        final int colour = _palette.colour(
          tone,
          s.light,
          s.occlusion,
          gene,
          1,
          centromere: tint.centromere,
          telomere: tint.telomere,
          sheen: s.sheen,
        );
        if (scale == 1) {
          rim.add(colour);
        }
        final Offset at = p.at(a, scale);
        mesh.vertex(at.dx, at.dy, colour);
      }
    }
    for (int i = 0; i < ring; i++) {
      final Offset at = p.at(2 * math.pi * i / ring, 1.25);
      mesh.vertex(at.dx, at.dy, _clear(rim[i]));
    }
    for (int i = 0; i < ring; i++) {
      final int a = centre + 1 + i;
      final int b = centre + 1 + (i + 1) % ring;
      mesh.triangle(centre, a, b);
      for (int band = 0; band < 2; band++) {
        final int a0 = a + band * ring;
        final int b0 = b + band * ring;
        mesh.triangle(a0, b0, a0 + ring);
        mesh.triangle(b0, b0 + ring, a0 + ring);
      }
    }
  }

  /// The kinetochore: a small plate on the sister's outer face at the
  /// waist, in the centromere's ink, seated in a crevice of its own and lit
  /// as a lobe is.
  void _plate(ColouredMesh mesh, double side) {
    final Offset at = form.kinetochore(side);
    final double rx = _look.plateX * _half;
    final double ry = _look.plateY * _half;
    final double u = side * _look.plateOut;
    final _Knob plate = _Knob(
      x: at.dx,
      y: at.dy,
      normal: SurfaceNormal(u, 0, math.sqrt(1 - u * u)),
      ax: rx,
      ay: 0,
      bx: 0,
      by: ry,
    );
    _skirtOf(mesh, plate);
    _domeOf(mesh, side, plate, form.centromere, u, rx, 0, (
      centromere: _look.kinetochoreTint,
      telomere: 0,
    ));
  }

  List<ui.Vertices> _grains(double side) {
    final ColouredMesh mesh = ColouredMesh();
    _layGrains(mesh, side);
    return mesh.build();
  }

  void _layGrains(ColouredMesh mesh, double side) {
    const int ring = 6;
    final KnobField knobs = form.knobs(side);
    final int pit = _palette.shadow(_look.pitAlpha);
    for (int k = 0; k < knobs.length; k++) {
      final int kind = knobs.kind[k];
      if (kind == KnobField.lobe) {
        continue;
      }
      final _Knob p = _place(side, knobs, k);
      final int heart = kind == KnobField.bump ? _bump(side, knobs, k, p) : pit;
      mesh.begin(1 + ring);
      final int centre = mesh.next;
      mesh.vertex(p.x, p.y, heart);
      for (int i = 0; i < ring; i++) {
        final Offset at = p.at(2 * math.pi * i / ring, 1);
        mesh.vertex(at.dx, at.dy, _clear(heart));
      }
      for (int i = 0; i < ring; i++) {
        mesh.triangle(centre, centre + 1 + i, centre + 1 + (i + 1) % ring);
      }
    }
  }

  /// The heart of granule [k], [p], standing out of the surface: the
  /// chromatin's own colour where it lies, lit a little nearer its full
  /// tone, never past it.
  int _bump(double side, KnobField knobs, int k, _Knob p) {
    final double y = knobs.y[k];
    final SurfaceNormal n = p.normal;
    final _Lit s = _surface(
      side,
      y,
      math.sin(knobs.phi[k]),
      n.x,
      n.y,
      n.z,
      facing: n.z,
    );
    final ({double centromere, double telomere}) tint = _tints(y);
    return _palette.colour(
      form.toneAt(y),
      s.light + (1 - s.light) * _look.bumpLift,
      s.occlusion,
      form.geneAt(y),
      _look.bumpAlpha,
      centromere: tint.centromere,
      telomere: tint.telomere,
    );
  }
}

/// How a point of the surface is lit: its light, the groove's shade on it,
/// and its sheen.
typedef _Lit = ({double light, double occlusion, double sheen});

/// [colour] with no alpha: where a soft edge fades to nothing.
int _clear(int colour) => colour & ((1 << 24) - 1);

double _smoothstep(double from, double to, double x) {
  final double t = ((x - from) / (to - from)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A knob as it is seen: its middle, its surface's normal, and the two
/// half-axes of its ellipse.
final class _Knob {
  const _Knob({
    required this.x,
    required this.y,
    required this.normal,
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
  });

  final double x;
  final double y;
  final SurfaceNormal normal;
  final double ax;
  final double ay;
  final double bx;
  final double by;

  /// The point [scale] of the way out to its edge, at angle [a] round it.
  Offset at(double a, double scale) {
    final double c = math.cos(a) * scale;
    final double s = math.sin(a) * scale;
    return Offset(x + ax * c + bx * s, y + ay * c + by * s);
  }
}
