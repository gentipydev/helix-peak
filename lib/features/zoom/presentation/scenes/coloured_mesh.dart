import 'dart:typed_data';
import 'dart:ui' as ui;

/// Triangles with a colour at every vertex, gathered into as many meshes as
/// their 16-bit indices need.
final class ColouredMesh {
  ColouredMesh({this.keep = false});

  /// Whether to keep each mesh's vertices as well, for tests.
  final bool keep;

  /// Each mesh's vertices, when [keep]: where each lies and its colour.
  final List<({Float32List positions, Int32List colours})> kept =
      <({Float32List positions, Int32List colours})>[];

  static const int _limit = 65000;

  final List<ui.Vertices> _done = <ui.Vertices>[];
  final List<double> _positions = <double>[];
  final List<int> _colours = <int>[];
  final List<int> _indices = <int>[];

  /// The index the next vertex takes.
  int get next => _colours.length;

  /// Starts a shape of [count] vertices, in a mesh of its own if this one
  /// has no room left for it.
  void begin(int count) {
    if (_colours.length + count > _limit) {
      _flush();
    }
  }

  void vertex(double x, double y, int colour) {
    _positions
      ..add(x)
      ..add(y);
    _colours.add(colour);
  }

  void triangle(int a, int b, int c) => _indices
    ..add(a)
    ..add(b)
    ..add(c);

  void _flush() {
    if (_indices.isNotEmpty) {
      final Float32List positions = Float32List.fromList(_positions);
      final Int32List colours = Int32List.fromList(_colours);
      _done.add(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          positions,
          colors: colours,
          indices: Uint16List.fromList(_indices),
        ),
      );
      if (keep) {
        kept.add((positions: positions, colours: colours));
      }
    }
    _positions.clear();
    _colours.clear();
    _indices.clear();
  }

  List<ui.Vertices> build() {
    _flush();
    return List<ui.Vertices>.unmodifiable(_done);
  }
}
