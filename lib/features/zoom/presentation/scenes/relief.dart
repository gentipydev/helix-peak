import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A shape inflated into a rounded form, as a cushion is: how far it stands
/// up off the page at each point, highest where the shape is widest round
/// it, and the way its surface faces there.
///
/// It is solved on a grid: φ with ∇²φ = −1 inside and 0 outside, the height
/// √(2φ) times [inflation]. Over a disc that is a dome, over a strip a
/// cylinder: round in section wherever the shape goes, and higher where it
/// is wide.
final class Relief {
  Relief(
    List<Offset> shape, {
    required double cell,
    required double inflation,
    required int sweeps,
  }) : _cell = cell {
    final Rect box = _bounds(shape).inflate(2 * cell);
    _left = box.left;
    _top = box.top;
    _columns = (box.width / cell).ceil() + 1;
    _rows = (box.height / cell).ceil() + 1;
    final int count = _columns * _rows;
    final Uint8List inside = Uint8List(count);
    // Inside: by the outline's crossings along each row.
    final int n = shape.length;
    for (int j = 0; j < _rows; j++) {
      final double y = _top + j * cell;
      final List<double> crossings = <double>[];
      for (int i = 0; i < n; i++) {
        final Offset a = shape[i];
        final Offset b = shape[(i + 1) % n];
        if ((a.dy <= y) != (b.dy <= y)) {
          crossings.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
        }
      }
      crossings.sort();
      for (int k = 0; k + 1 < crossings.length; k += 2) {
        final int from = ((crossings[k] - _left) / cell).ceil();
        final int to = ((crossings[k + 1] - _left) / cell).floor();
        for (int i = math.max(1, from); i <= math.min(_columns - 2, to); i++) {
          inside[j * _columns + i] = 1;
        }
      }
    }
    // ∇²φ = −1 inside, φ = 0 outside, by successive over-relaxation.
    final Float64List phi = Float64List(count);
    const double omega = 1.85;
    final double source = cell * cell;
    for (int sweep = 0; sweep < sweeps; sweep++) {
      for (int colour = 0; colour < 2; colour++) {
        for (int j = 1; j < _rows - 1; j++) {
          for (int i = 1 + (j + colour) % 2; i < _columns - 1; i += 2) {
            final int k = j * _columns + i;
            if (inside[k] == 0) {
              continue;
            }
            final double mean =
                (phi[k - 1] +
                    phi[k + 1] +
                    phi[k - _columns] +
                    phi[k + _columns] +
                    source) /
                4;
            phi[k] += omega * (mean - phi[k]);
          }
        }
      }
    }
    _height = Float64List(count);
    double highest = 0;
    for (int k = 0; k < count; k++) {
      final double h = inflation * math.sqrt(2 * math.max(0, phi[k]));
      _height[k] = h;
      highest = math.max(highest, h);
    }
    this.highest = highest;
    _nx = Float64List(count);
    _ny = Float64List(count);
    _nz = Float64List(count);
    for (int j = 0; j < _rows; j++) {
      for (int i = 0; i < _columns; i++) {
        final int k = j * _columns + i;
        final double dx =
            (_height[j * _columns + math.min(_columns - 1, i + 1)] -
                _height[j * _columns + math.max(0, i - 1)]) /
            (2 * cell);
        final double dy =
            (_height[math.min(_rows - 1, j + 1) * _columns + i] -
                _height[math.max(0, j - 1) * _columns + i]) /
            (2 * cell);
        final double length = math.sqrt(dx * dx + dy * dy + 1);
        _nx[k] = -dx / length;
        _ny[k] = -dy / length;
        _nz[k] = 1 / length;
      }
    }
  }

  final double _cell;
  late final double _left;
  late final double _top;
  late final int _columns;
  late final int _rows;
  late final Float64List _height;
  late final Float64List _nx;
  late final Float64List _ny;
  late final Float64List _nz;

  /// The height of its highest point.
  late final double highest;

  /// How high the surface stands at [p].
  double heightAt(Offset p) => _sample(_height, p);

  /// The way the surface faces at [p]: x across the screen, y down it, z
  /// out of it.
  (double, double, double) normalAt(Offset p) {
    final double x = _sample(_nx, p);
    final double y = _sample(_ny, p);
    final double z = _sample(_nz, p);
    final double length = math.sqrt(x * x + y * y + z * z);
    return length <= 0 ? (0, 0, 1) : (x / length, y / length, z / length);
  }

  double _sample(Float64List values, Offset p) {
    final double fx = ((p.dx - _left) / _cell).clamp(0.0, _columns - 1.001);
    final double fy = ((p.dy - _top) / _cell).clamp(0.0, _rows - 1.001);
    final int i = fx.floor();
    final int j = fy.floor();
    final double tx = fx - i;
    final double ty = fy - j;
    final int k = j * _columns + i;
    final double top = values[k] + (values[k + 1] - values[k]) * tx;
    final double bottom =
        values[k + _columns] +
        (values[k + _columns + 1] - values[k + _columns]) * tx;
    return top + (bottom - top) * ty;
  }
}

/// The box round [points].
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
