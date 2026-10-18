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

/// A chromosome at rest, drawn as a scanning micrograph shows one: two
/// velvety sisters, their surface knobbly with chromatin, bright at the
/// edges that face the light and dark in the crevices and along the groove
/// where they touch, a soft coat round them, the bands soft changes of tone,
/// and the gene as two FISH spots, one on each sister.
///
/// Everything costly is built once, for one form in one set of inks: the
/// body and its relief are meshes in the scene's units, so a frame only
/// hands them on, at any magnification.
final class ChromosomeArt {
  ChromosomeArt(this.form, this.inks)
    : _light = ChromosomeLight(),
      _palette = ChromosomePalette(inks);

  final ChromosomeForm form;
  final ZoomInks inks;
  final ChromosomeLight _light;
  final ChromosomePalette _palette;

  double get _half => form.half;

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

  /// What the chromosome at rest covers, its coat, its shadow and its relief
  /// included, in the scene's units: the room a layer of it needs.
  late final Rect bounds = _outlines[0]
      .getBounds()
      .expandToInclude(_outlines[1].getBounds())
      .inflate(1.2 * _half);

  /// The body's colour averaged over its area on both sisters, lit as it
  /// is, the gene's wash left out: what the territory's mark gives way to as
  /// the chromosome condenses out of it.
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
          final ({double light, double occlusion}) s = _surface(
            side,
            y,
            u,
            n.x,
            n.y,
            n.z,
          );
          final (double, double, double) mix = _palette.mix(
            tone,
            s.light,
            s.occlusion,
            0,
          );
          r += mix.$1 * area;
          g += mix.$2 * area;
          b += mix.$3 * area;
          total += area;
        }
      }
    }
    return total <= 0
        ? inks.lit(ChromosomeStyle.paleLit)
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

    // The shadow the sisters cast, under them and to the lower right.
    canvas.save();
    canvas.translate(
      ChromosomeStyle.shadowX * _half,
      ChromosomeStyle.shadowY * _half,
    );
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        canvas.drawPath(
          _outlines[i],
          Paint()..color = inks.shadow.withValues(alpha: 0.32),
        );
        canvas.drawPath(
          _outlines[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5 * _half
            ..strokeJoin = StrokeJoin.round
            ..color = inks.shadow.withValues(alpha: 0.12),
        );
      });
    }
    canvas.restore();
    // Their coat: half of a wide, faint stroke shows round each.
    for (int i = 0; i < 2; i++) {
      sister(i, () {
        canvas.drawPath(
          _outlines[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ChromosomeStyle.coat * _half
            ..strokeJoin = StrokeJoin.round
            ..color = inks.lit(0.3).withValues(alpha: 0.06),
        );
        canvas.drawPath(
          _outlines[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ChromosomeStyle.coatInner * _half
            ..strokeJoin = StrokeJoin.round
            ..color = inks.lit(0.3).withValues(alpha: 0.11),
        );
      });
    }
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
        ChromosomeStyle.fishGlow * r,
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

  /// How bright the surface is at [y], [u] of the way across the tube (the
  /// sine of its angle round it), on chromatid [side]: its light, and the
  /// shade of the groove where it is turned to its sister.
  ({double light, double occlusion}) _surface(
    double side,
    double y,
    double u,
    double nx,
    double ny,
    double nz,
  ) {
    final double turned = _smoothstep(0.3, 1, -side * u);
    return (
      light: _light.brightness(nx, ny, nz),
      occlusion: ChromosomeStyle.occlusion * turned * form.contact(y),
    );
  }

  /// How far across the tube each of the body's columns lies, from one
  /// edge to the other: the sine of its angle round it.
  static final List<double> _columns = <double>[
    for (final double u in ChromosomeStyle.columns.reversed) -u,
    ...ChromosomeStyle.columns.skip(1),
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
      for (final double u in columns) {
        final double nz = math.sqrt(math.max(0, 1 - u * u));
        final SurfaceNormal n = SurfaceNormal(u, -slope, nz);
        final ({double light, double occlusion}) s = _surface(
          side,
          y,
          u,
          n.x,
          n.y,
          n.z,
        );
        mesh.vertex(
          centre + w * u,
          y + bow * u * u,
          _palette.colour(tone, s.light, s.occlusion, gene, 1),
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
    // The lobes: every crevice first, then every dome over them.
    final KnobField knobs = form.knobs(side);
    for (int k = 0; k < knobs.length; k++) {
      if (knobs.kind[k] == KnobField.lobe) {
        _skirt(mesh, side, knobs, k);
      }
    }
    for (int k = 0; k < knobs.length; k++) {
      if (knobs.kind[k] == KnobField.lobe) {
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

  void _skirt(ColouredMesh mesh, double side, KnobField knobs, int k) {
    const int ring = 12;
    final _Knob p = _place(side, knobs, k);
    mesh.begin(ring * 2);
    final int first = mesh.next;
    final int dark = _palette.shadow(ChromosomeStyle.skirtAlpha);
    final int clear = _palette.shadow(0);
    for (final (double scale, int colour) in <(double, int)>[
      (ChromosomeStyle.skirtInner, dark),
      (ChromosomeStyle.skirtOuter, clear),
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
    const int ring = 14;
    final _Knob p = _place(side, knobs, k);
    final double y = knobs.y[k];
    final double tone = form.toneAt(y);
    final double gene = form.geneAt(y);
    final double u = math.sin(knobs.phi[k]);
    final SurfaceNormal base = p.normal;
    final double r = knobs.radius[k];
    ({double light, double occlusion}) lit(double tilt, double a) {
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
      return _surface(side, y, u, n.x, n.y, n.z);
    }

    mesh.begin(1 + ring * 3);
    final int centre = mesh.next;
    final ({double light, double occlusion}) top = lit(0, 0);
    mesh.vertex(
      p.x + _light.screenX * 0.22 * r,
      p.y + _light.screenY * 0.22 * r,
      _palette.colour(tone, top.light + 0.1, top.occlusion, gene, 1),
    );
    final List<int> rim = <int>[];
    for (final (double scale, double tilt) in <(double, double)>[
      (0.62, 0.4 * ChromosomeStyle.lobeTilt),
      (1, ChromosomeStyle.lobeTilt),
    ]) {
      for (int i = 0; i < ring; i++) {
        final double a = 2 * math.pi * i / ring;
        final ({double light, double occlusion}) s = lit(tilt, a);
        final int colour = _palette.colour(
          tone,
          s.light,
          s.occlusion,
          gene,
          scale < 1 ? 1 : 0.9,
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
  /// waist, a little lighter than the chromatin under it.
  void _plate(ColouredMesh mesh, double side) {
    const int ring = 12;
    final Offset at = form.kinetochore(side);
    final double rx = ChromosomeStyle.plateX * _half;
    final double ry = ChromosomeStyle.plateY * _half;
    final double u = side * ChromosomeStyle.plateOut;
    final double y = form.centromere;
    final SurfaceNormal n = SurfaceNormal(u, 0, math.sqrt(1 - u * u));
    final ({double light, double occlusion}) s = _surface(
      side,
      y,
      u,
      n.x,
      n.y,
      n.z,
    );
    final double tone = form.toneAt(y);
    mesh.begin(1 + ring * 2);
    final int centre = mesh.next;
    mesh.vertex(at.dx, at.dy, _palette.colour(tone, s.light + 0.14, 0, 0, 1));
    final int rim = _palette.colour(tone, s.light + 0.06, 0, 0, 0.95);
    for (int i = 0; i < ring; i++) {
      final double a = 2 * math.pi * i / ring;
      mesh.vertex(at.dx + rx * math.cos(a), at.dy + ry * math.sin(a), rim);
    }
    for (int i = 0; i < ring; i++) {
      final double a = 2 * math.pi * i / ring;
      mesh.vertex(
        at.dx + 1.18 * rx * math.cos(a),
        at.dy + 1.18 * ry * math.sin(a),
        _clear(rim),
      );
    }
    for (int i = 0; i < ring; i++) {
      final int a = centre + 1 + i;
      final int b = centre + 1 + (i + 1) % ring;
      mesh.triangle(centre, a, b);
      mesh.triangle(a, b, a + ring);
      mesh.triangle(b, b + ring, a + ring);
    }
  }

  List<ui.Vertices> _grains(double side) {
    final ColouredMesh mesh = ColouredMesh();
    _layGrains(mesh, side);
    return mesh.build();
  }

  void _layGrains(ColouredMesh mesh, double side) {
    const int ring = 6;
    final KnobField knobs = form.knobs(side);
    final int bump = _palette.text(ChromosomeStyle.bumpAlpha);
    final int pit = _palette.shadow(ChromosomeStyle.pitAlpha);
    for (int k = 0; k < knobs.length; k++) {
      final int kind = knobs.kind[k];
      if (kind == KnobField.lobe) {
        continue;
      }
      final _Knob p = _place(side, knobs, k);
      final int heart = kind == KnobField.bump ? bump : pit;
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
}

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
