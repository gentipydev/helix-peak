import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/locus_track.dart';
import '../../../domain/zoom_camera.dart';
import '../../zoom_inks.dart';
import '../band_scene.dart';
import '../zoom_scene.dart';
import 'chromosome_form.dart';
import 'chromosome_shading.dart';
import 'chromosome_style.dart';

/// The chromosome on its way into the band's map: each sister a smooth tube
/// of its bands, shaded as the chromosome at rest is, which turns with the
/// canvas to lie along the genome, merges with its sister and thins to the
/// strip's thickness. As it goes, its bands' softened edges harden, its
/// rounded ends shorten to the strip's, its centromere's waist becomes the
/// strip's pinch, and its colours ease to the strip's stains under the
/// strip's own light. Once it lies along the genome it is the strip, pixel
/// for pixel, so the map takes over from it with nothing to see.
///
/// One small mesh: where its vertices lie and what colour each is are
/// worked out afresh every frame into buffers it keeps, and the triangles
/// between them never change.
final class ChromosomeTube {
  ChromosomeTube(this.form, this.inks) : _palette = ChromosomePalette(inks);

  final ChromosomeForm form;
  final ZoomInks inks;
  final ChromosomePalette _palette;

  LocusTrack get _track => form.track;

  double get _half => form.half;

  /// Where across a sister each column lies, as the sine of its angle round
  /// it and as a share of its half-width, from the edge that comes to lie
  /// along the strip's bottom (−1) to the one along its top (1). The strip's
  /// light changes its slope at 1, 0.5, −0.1 and −1, so those are columns;
  /// below −0.1 it is not even straight (it brightens before it darkens,
  /// as its light goes from clear to the shadow), so the columns there are
  /// close enough to follow it within a shade; and they are closer toward
  /// the edges, where the chromosome's light turns fastest.
  static const List<double> columns = <double>[
    -1,
    -0.9,
    -0.8,
    -0.7,
    -0.55,
    -0.4,
    -0.25,
    -0.1,
    0.2,
    0.5,
    0.75,
    0.9,
    1,
  ];

  /// How far the soft edge round each tube reaches as it turns, in pixels:
  /// nothing else smooths a mesh's edge where a rasteriser does not
  /// multisample. It goes as the tube becomes the strip, whose edge it then
  /// has.
  static const double skirt = 1.2;

  /// Vertices across a row: the columns and a soft edge either side.
  static final int _across = columns.length + 2;

  /// How far each column of each sister is turned to the other, for the
  /// groove's shade: the left sister's first.
  static final List<double> _turned = <double>[
    for (final double side in <double>[-1, 1])
      for (final double u in columns) smoothstep((-side * u - 0.3) / 0.7),
  ];

  /// How bright each column is where the tube's width does not change, and
  /// how much it shines, this frame: most rows, worked out once rather than
  /// for every row.
  final List<double> _flatLight = List<double>.filled(columns.length, 0);
  final List<double> _flatSheen = List<double>.filled(columns.length, 0);

  /// The strip's light at each column where the tube is the strip's full
  /// thickness, this frame: channels and alpha.
  final List<(double, double, double, double)> _flatStrip =
      List<(double, double, double, double)>.filled(columns.length, (
        0,
        0,
        0,
        0,
      ));

  /// How steep a row's sides may be and still be lit as a flat one.
  static const double _flat = 1e-4;

  /// How many rows round each end follow its rounding.
  static const int _round = 16;

  /// The rows the tube is drawn through, before they move.
  late final List<_Row> _rows = () {
    final List<_Row> rows = <_Row>[];
    final double top = form.top;
    final double bottom = form.bottom;
    final double step = 0.5 * _half;
    for (double y = top + step; y < bottom - step / 2; y += step) {
      rows.add(_Row(_RowKind.along, y));
    }
    // Closer round the waist, where the tube narrows.
    final double fine = 0.15 * _half;
    for (
      double y = form.centromere - 1.5 * _half;
      y <= form.centromere + 1.5 * _half;
      y += fine
    ) {
      if (y > top && y < bottom) {
        rows.add(_Row(_RowKind.along, y));
      }
    }
    // A pair at each band's edge, either side of its softening, which meet
    // as the edge hardens into the strip's.
    final List<CytoBand> bands = _track.bands;
    for (int i = 1; i < bands.length; i++) {
      final double y = form.yOf(bands[i].start);
      final double feather = form.featherAt(i);
      rows
        ..add(_Row(_RowKind.above, y, band: i - 1, feather: feather))
        ..add(_Row(_RowKind.below, y, band: i, feather: feather));
    }
    for (int k = 0; k < _round; k++) {
      rows
        ..add(_Row(_RowKind.top, k / _round))
        ..add(_Row(_RowKind.bottom, k / _round));
    }
    return rows;
  }();

  /// Where each row lies along the chromosome this frame, and the rows in
  /// that order.
  late final Float64List _ys = Float64List(_rows.length);
  late final List<int> _order = List<int>.generate(_rows.length, (int i) => i);

  late final Float32List _positions = Float32List(_rows.length * _across * 4);
  late final Int32List _colours = Int32List(_rows.length * _across * 2);

  /// The triangles: the same every frame, between the rows in their order,
  /// for both sisters, and for the right one alone once the two lie as one.
  late final Uint16List _indices = _triangles(<int>[0, 1]);
  late final Uint16List _merged = _triangles(<int>[1]);

  Uint16List _triangles(List<int> sisters) {
    final int n = _rows.length;
    final List<int> out = <int>[];
    for (final int sister in sisters) {
      final int base = sister * n * _across;
      for (int i = 0; i + 1 < n; i++) {
        for (int j = 0; j + 1 < _across; j++) {
          final int a = base + i * _across + j;
          final int c = a + _across;
          out
            ..add(a)
            ..add(a + 1)
            ..add(c)
            ..add(a + 1)
            ..add(c + 1)
            ..add(c);
        }
      }
    }
    return Uint16List.fromList(out);
  }

  /// Each band's stain as the chromosome shades it, as the strip draws it,
  /// how thick the strip draws it, and whether the gene lies in it.
  late final List<double> _tones = <double>[
    for (final CytoBand band in _track.bands) ChromosomeStyle.tone(band.stain),
  ];
  late final List<Color> _stains = <Color>[
    for (final CytoBand band in _track.bands) BandScene.stain(inks, band.stain),
  ];
  late final List<double> _thickness = <double>[
    for (final CytoBand band in _track.bands) BandScene.thickness(band.stain),
  ];
  late final List<double> _genes = <double>[
    for (final CytoBand band in _track.bands)
      band.start >= _track.bandStart && band.end <= _track.bandEnd ? 1 : 0,
  ];

  /// The strip's light, from its top edge to its bottom.
  late final List<Color> _stripLight = BandScene.light(inks);

  /// The centromere, where the strip is pinched: the first and last of its
  /// bands, or null where the track has none.
  late final (int, int)? _pinch = () {
    int first = -1;
    int last = -1;
    for (int i = 0; i < _track.bands.length; i++) {
      if (BandScene.thickness(_track.bands[i].stain) < 1) {
        if (first < 0) {
          first = i;
        }
        last = i;
      }
    }
    return first < 0 ? null : (first, last);
  }();

  /// Where across the strip the gap beside its pinch is filled, as shares
  /// of its half-thickness from its edge in toward the pinch, which is the
  /// last: the strip's light bends there, at its stops, so closer toward
  /// the edges.
  late final List<double> _gap = <double>[
    1,
    0.9,
    0.775,
    if (_pinch case (final int first, int _))
      BandScene.thickness(_track.bands[first].stain),
  ];

  late final Uint16List _gapIndices = () {
    final List<int> out = <int>[];
    for (int half = 0; half < 2; half++) {
      for (int j = 0; j + 1 < _gap.length; j++) {
        final int a = half * _gap.length * 2 + j;
        final int c = a + _gap.length;
        out
          ..add(a)
          ..add(a + 1)
          ..add(c)
          ..add(a + 1)
          ..add(c + 1)
          ..add(c);
      }
    }
    return Uint16List.fromList(out);
  }();

  late final Float32List _gapPositions = Float32List(_gap.length * 8);
  late final Int32List _gapColours = Int32List(_gap.length * 4);

  /// Builds what it keeps now rather than at its first frame.
  void prepare() => <Object?>[
    _rows,
    _ys,
    _order,
    _positions,
    _colours,
    _indices,
    _merged,
    _tones,
    _stains,
    _thickness,
    _genes,
    _stripLight,
    _pinch,
    _gap,
    _gapIndices,
    _gapPositions,
    _gapColours,
  ];

  /// How many vertices the tube is drawn with.
  int get vertexCount => _rows.length * _across * 2;

  /// Whether the tube was last drawn as one, its right sister alone.
  bool _lastMerged = false;

  /// The vertices drawn last frame, for tests: where each lies, in the
  /// scene's units before it turns, and its colour.
  @visibleForTesting
  ({Float32List positions, Int32List colours}) get laidVertices {
    final int from = _lastMerged ? _rows.length * _across : 0;
    return (
      positions: Float32List.sublistView(_positions, from * 2),
      colours: Int32List.sublistView(_colours, from),
    );
  }

  /// The rows as last laid, in order along the tube, for tests: the band
  /// each carries; whether it is the last row of its band at an edge (-1),
  /// the first (1), or neither (0); and where the right sister's two edges
  /// lie, in the scene's units, the one that comes to lie along the strip's
  /// top first.
  @visibleForTesting
  List<({int band, int edge, Offset top, Offset bottom})> get laidRows {
    Offset at(int i) => Offset(_positions[i * 2], _positions[i * 2 + 1]);
    final int n = _rows.length;
    return <({int band, int edge, Offset top, Offset bottom})>[
      for (int p = 0; p < n; p++)
        (
          band: switch (_rows[_order[p]].kind) {
            _RowKind.above || _RowKind.below => _rows[_order[p]].band,
            _ => form.bandAt(_ys[_order[p]]),
          },
          edge: switch (_rows[_order[p]].kind) {
            _RowKind.above => -1,
            _RowKind.below => 1,
            _ => 0,
          },
          top: at((n + p) * _across + columns.length),
          bottom: at((n + p) * _across + 1),
        ),
    ];
  }

  /// The tube [turn] of the way to lying along the genome, its sisters
  /// [merge] of the way onto its axis, [thin] of the way to [target]
  /// half-width, and [strip] of the way to looking as the strip does; the
  /// strip's own map shown at [under] over it. On a canvas already turned
  /// with it, in the scene's units.
  void paint(
    Canvas canvas,
    ZoomFrame frame, {
    required double turn,
    required double merge,
    required double thin,
    required double strip,
    required double target,
    required double under,
  }) {
    _lay(frame.pixel, turn, merge, thin, strip, target);
    _lastMerged = merge >= 1;
    final ui.Vertices tube = ui.Vertices.raw(
      VertexMode.triangles,
      _positions,
      colors: _colours,
      indices: merge >= 1 ? _merged : _indices,
    );
    canvas.drawVertices(tube, BlendMode.dst, Paint());
    tube.dispose();
    if (_pinch != null && strip > 0) {
      _layGap(merge, strip, target, under);
      final ui.Vertices gap = ui.Vertices.raw(
        VertexMode.triangles,
        _gapPositions,
        colors: _gapColours,
        indices: _gapIndices,
      );
      canvas.drawVertices(gap, BlendMode.dst, Paint());
      gap.dispose();
    }
  }

  /// Where each row lies this frame, with the tube's rounded ends [cap]
  /// long and its bands' edges softened by [soften] of their reach.
  void _place(double cap, double soften) {
    for (int i = 0; i < _rows.length; i++) {
      final _Row row = _rows[i];
      _ys[i] = switch (row.kind) {
        _RowKind.along => row.at,
        _RowKind.above => row.at - row.feather * soften,
        _RowKind.below => row.at + row.feather * soften,
        _RowKind.top => form.top + cap * (1 - math.cos(math.pi / 2 * row.at)),
        _RowKind.bottom =>
          form.bottom - cap * (1 - math.cos(math.pi / 2 * row.at)),
      };
    }
    _order.sort((int a, int b) {
      final int byY = _ys[a].compareTo(_ys[b]);
      return byY != 0 ? byY : a.compareTo(b);
    });
  }

  /// The two bands a row at [y] lies between, and how far from the first
  /// to the second, with the bands' edges softened by [soften] of their
  /// reach: the same band twice away from its edges.
  (int, int, double) _bandsAt(double y, double soften) {
    final List<CytoBand> bands = _track.bands;
    final int i = form.bandAt(y);
    if (soften > 0) {
      if (i > 0) {
        final double f = form.featherAt(i) * soften;
        final double a = form.yOf(bands[i].start);
        if (f > 0 && y < a + f) {
          return (i - 1, i, ((y - (a - f)) / (2 * f)).clamp(0.0, 1.0));
        }
      }
      if (i + 1 < bands.length) {
        final double f = form.featherAt(i + 1) * soften;
        final double b = form.yOf(bands[i + 1].start);
        if (f > 0 && y > b - f) {
          return (i, i + 1, ((y - (b - f)) / (2 * f)).clamp(0.0, 1.0));
        }
      }
    }
    return (i, i, 0);
  }

  /// The strip's light at [t] of the way down across it: its colour's
  /// channels and its alpha, from 0 to 1.
  (double, double, double, double) _lightAt(double t) {
    const List<double> stops = BandScene.lightStops;
    int k = 0;
    while (k + 2 < stops.length && t > stops[k + 1]) {
      k++;
    }
    final double f = ((t - stops[k]) / (stops[k + 1] - stops[k])).clamp(
      0.0,
      1.0,
    );
    final Color a = _stripLight[k];
    final Color b = _stripLight[k + 1];
    return (
      a.r + (b.r - a.r) * f,
      a.g + (b.g - a.g) * f,
      a.b + (b.b - a.b) * f,
      a.a + (b.a - a.a) * f,
    );
  }

  /// Lays every vertex of the tube for this frame.
  void _lay(
    double pixel,
    double turn,
    double merge,
    double thin,
    double strip,
    double target,
  ) {
    final ChromosomeLight light = ChromosomeLight(turn: turn);
    final double soften = 1 - merge;
    final double cap = _half + (target - _half) * thin;
    _place(cap, soften);
    for (int j = 0; j < columns.length; j++) {
      final double u = columns[j];
      final SurfaceNormal normal = SurfaceNormal(
        u,
        0,
        math.sqrt(math.max(0, 1 - u * u)),
      );
      _flatLight[j] = light.light(
        normal.x,
        normal.y,
        normal.z,
        facing: normal.z,
      );
      _flatSheen[j] = light.sheen(normal.x, normal.y, normal.z);
      _flatStrip[j] = _lightAt((1 - u) / 2);
    }
    final int n = _rows.length;
    final double top = form.top;
    final double bottom = form.bottom;
    for (int p = 0; p < n; p++) {
      final int index = _order[p];
      final _Row row = _rows[index];
      final double y = _ys[index];
      final (int above, int below, double t) = switch (row.kind) {
        _RowKind.above || _RowKind.below => (row.band, row.band, 0.0),
        _ => _bandsAt(y, soften),
      };
      final double tone = _tones[above] + (_tones[below] - _tones[above]) * t;
      final double gene =
          (_genes[above] + (_genes[below] - _genes[above]) * t) * (1 - strip);
      final Color stainA = _stains[above];
      final Color stainB = _stains[below];
      final double sr = stainA.r + (stainB.r - stainA.r) * t;
      final double sg = stainA.g + (stainB.g - stainA.g) * t;
      final double sb = stainA.b + (stainB.b - stainA.b) * t;
      // The strip's profile: its thickness, pinched at the centromere, and
      // its rounded ends.
      final double thick =
          _thickness[above] + (_thickness[below] - _thickness[above]) * t;
      final double fromEnd = math.min(y - top, bottom - y);
      final double rounded = fromEnd >= target || target <= 0
          ? 1
          : math.sqrt(
              math.max(0, 1 - math.pow((target - fromEnd) / target, 2)),
            );
      final double art = form.widthAt(y);
      final double w = art + (target * thick * rounded - art) * thin;
      final double slope = form.slope(y) * (1 - thin);
      final double bow = form.bowAt(y) * soften;
      final double contact = form.contact(y) * soften;
      // Once the two lie as one, the right sister alone is drawn.
      for (int sister = merge >= 1 ? 1 : 0; sister < 2; sister++) {
        final double side = sister == 0 ? -1 : 1;
        final double centre = form.centreAt(side, y, merge: merge);
        final int first = (sister * n + p) * _across;
        for (int j = 0; j < columns.length; j++) {
          final double u = columns[j];
          // The chromosome's own shading, while any of it shows.
          double ar = 0;
          double ag = 0;
          double ab = 0;
          if (strip < 1) {
            double lit = _flatLight[j];
            double sheen = _flatSheen[j];
            if (slope.abs() > _flat) {
              final SurfaceNormal normal = SurfaceNormal(
                u,
                -slope,
                math.sqrt(math.max(0, 1 - u * u)),
              );
              lit = light.light(
                normal.x,
                normal.y,
                normal.z,
                facing: normal.z,
              );
              sheen = light.sheen(normal.x, normal.y, normal.z);
            }
            (ar, ag, ab) = _palette.mix(
              tone,
              lit,
              ChromosomeStyle.occlusion *
                  _turned[sister * columns.length + j] *
                  contact,
              gene,
              sheen: sheen,
            );
          }
          // The strip's colour there, once any of it shows: its stain under
          // its light, which falls across the strip's whole thickness.
          double lr = 0;
          double lg = 0;
          double lb = 0;
          double la = 0;
          if (strip > 0) {
            if (target <= 0 || (w - target).abs() < 1e-9 * target) {
              (lr, lg, lb, la) = _flatStrip[j];
            } else {
              final double across = (u * w / target).clamp(-1.0, 1.0);
              (lr, lg, lb, la) = _lightAt((1 - across) / 2);
            }
          }
          final int colour = ChromosomePalette.pack(
            1,
            ar + (lr * la + sr * (1 - la) - ar) * strip,
            ag + (lg * la + sg * (1 - la) - ag) * strip,
            ab + (lb * la + sb * (1 - la) - ab) * strip,
          );
          _vertex(first + 1 + j, centre + w * u, y + bow * u * u, colour);
          if (j == 0 || j == columns.length - 1) {
            // The soft edge beyond: the edge's colour, fading out. Lying
            // along the genome, the tube has the strip's own edge.
            final double out = (w + skirt * pixel * (1 - strip)) * u;
            final int at = j == 0 ? first : first + _across - 1;
            _vertex(at, centre + out, y + bow * u * u, _clear(colour));
          }
        }
      }
    }
  }

  void _vertex(int i, double x, double y, int colour) {
    _positions[i * 2] = x;
    _positions[i * 2 + 1] = y;
    _colours[i] = colour;
  }

  /// Lays the fill of the strip's pinch: its light over the ground, above
  /// the pinch and below it, as the strip lights the whole of its thickness
  /// there, faint enough under the map's own fill at [under] that the two
  /// show as one.
  void _layGap(double merge, double strip, double target, double under) {
    final (int first, int last) = _pinch!;
    final double from = form.yOf(_track.bands[first].start);
    final double to = form.yOf(_track.bands[last].end + 1);
    int v = 0;
    // Above the pinch, then below it.
    for (final double sign in <double>[1, -1]) {
      for (final double y in <double>[from, to]) {
        final double axis =
            (form.centreAt(-1, y, merge: merge) +
                form.centreAt(1, y, merge: merge)) /
            2;
        for (final double share in _gap) {
          final double across = sign * share;
          final (double r, double g, double b, double a) = _lightAt(
            (1 - across) / 2,
          );
          final double shown = a * strip;
          final double alpha = under >= 1
              ? 0
              : shown * (1 - under) / (1 - shown * under);
          _gapPositions[v * 2] = axis + across * target;
          _gapPositions[v * 2 + 1] = y;
          _gapColours[v] = ChromosomePalette.pack(alpha, r, g, b);
          v++;
        }
      }
    }
  }
}

/// [colour] with no alpha: where a soft edge fades to nothing.
int _clear(int colour) => colour & ((1 << 24) - 1);

/// What a row of the tube is: one at a fixed place along it, one of the
/// pair at a band's edge, or one of the rows round either end.
enum _RowKind { along, above, below, top, bottom }

final class _Row {
  const _Row(this.kind, this.at, {this.band = 0, this.feather = 0});

  final _RowKind kind;

  /// Where it lies along the chromosome, or for a row round an end, how far
  /// round it, from 0 at the very end.
  final double at;

  /// The band a row at an edge carries, and how far that edge is softened.
  final int band;
  final double feather;
}
