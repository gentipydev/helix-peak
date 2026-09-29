import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:helixpeek/shared/folding/fold_skin.dart';

/// The twenty stored models, each node as the fold page's scene holds it.
///
/// `test/fixtures/models/` keeps the `.glb` each structure bake stored, which
/// the `folding` track was matched against vertex for vertex. flutter_scene's
/// compiler turns a `.glb` into the `.fsceneb` the page loads by negating the
/// z of every vertex and normal and swapping each triangle's last two
/// corners (`packGltfPrimitive`, `GltfCoordinatePolicy.bakeNative`), and
/// keeps every float and the order of everything else. This does the same,
/// so a mesh read here is the one the page draws, float for float.
List<SkinMesh> storedMeshes(String slug) => _meshes.putIfAbsent(
  slug,
  () => _read(File('test/fixtures/models/$slug.glb').readAsBytesSync()),
);

final Map<String, List<SkinMesh>> _meshes = <String, List<SkinMesh>>{};

List<SkinMesh> _read(Uint8List bytes) {
  final ByteData data = ByteData.sublistView(bytes);
  if (data.getUint32(0, Endian.little) != 0x46546C67 ||
      data.getUint32(4, Endian.little) != 2) {
    throw const FormatException('Not a glTF 2 binary');
  }
  Map<String, dynamic>? document;
  late ByteData binary;
  int offset = 12;
  while (offset < bytes.length) {
    final int length = data.getUint32(offset, Endian.little);
    final int kind = data.getUint32(offset + 4, Endian.little);
    final Uint8List chunk = Uint8List.sublistView(
      bytes,
      offset + 8,
      offset + 8 + length,
    );
    if (kind == 0x4E4F534A) {
      document = jsonDecode(utf8.decode(chunk)) as Map<String, dynamic>;
    } else if (kind == 0x004E4942) {
      binary = ByteData.sublistView(chunk);
    }
    offset += 8 + length;
  }
  final Map<String, dynamic> doc = document!;
  final List<dynamic> accessors = doc['accessors'] as List<dynamic>;
  final List<dynamic> views = doc['bufferViews'] as List<dynamic>;

  List<num> read(int index) {
    final Map<String, dynamic> accessor =
        accessors[index] as Map<String, dynamic>;
    final Map<String, dynamic> view =
        views[accessor['bufferView'] as int] as Map<String, dynamic>;
    final int start =
        (view['byteOffset'] as int? ?? 0) + (accessor['byteOffset'] as int? ?? 0);
    final int count = accessor['count'] as int;
    final int width = switch (accessor['type'] as String) {
      'SCALAR' => 1,
      'VEC3' => 3,
      _ => throw FormatException('Unread type ${accessor['type']}'),
    };
    final int component = accessor['componentType'] as int;
    final int size = component == 5123 ? 2 : 4;
    final int stride = view['byteStride'] as int? ?? size * width;
    return <num>[
      for (int i = 0; i < count; i++)
        for (int j = 0; j < width; j++)
          switch (component) {
            5126 => binary.getFloat32(start + i * stride + j * size, Endian.little),
            5125 => binary.getUint32(start + i * stride + j * size, Endian.little),
            5123 => binary.getUint16(start + i * stride + j * size, Endian.little),
            _ => throw FormatException('Unread component $component'),
          },
    ];
  }

  final List<SkinMesh> meshes = <SkinMesh>[];
  for (final dynamic raw in doc['nodes'] as List<dynamic>) {
    final Map<String, dynamic> node = raw as Map<String, dynamic>;
    final int? mesh = node['mesh'] as int?;
    if (mesh == null) {
      continue;
    }
    final List<double> positions = <double>[];
    final List<double> normals = <double>[];
    final List<int> indices = <int>[];
    for (final dynamic p in ((doc['meshes'] as List<dynamic>)[mesh]
        as Map<String, dynamic>)['primitives'] as List<dynamic>) {
      final Map<String, dynamic> primitive = p as Map<String, dynamic>;
      final Map<String, dynamic> attributes =
          primitive['attributes'] as Map<String, dynamic>;
      final int base = positions.length ~/ 3;
      final List<num> points = read(attributes['POSITION'] as int);
      final List<num> faces = read(attributes['NORMAL'] as int);
      for (int i = 0; i < points.length; i++) {
        // z turned round, as the compiler bakes it.
        positions.add(i % 3 == 2 ? -points[i].toDouble() : points[i].toDouble());
        normals.add(i % 3 == 2 ? -faces[i].toDouble() : faces[i].toDouble());
      }
      final List<num> corners = read(primitive['indices'] as int);
      for (int t = 0; t < corners.length; t += 3) {
        // And each triangle wound the other way round, to keep its front.
        indices
          ..add(base + corners[t].toInt())
          ..add(base + corners[t + 2].toInt())
          ..add(base + corners[t + 1].toInt());
      }
    }
    meshes.add(
      SkinMesh(
        node: node['name'] as String,
        positions: Float32List.fromList(positions),
        normals: Float32List.fromList(normals),
        indices: Uint32List.fromList(indices),
      ),
    );
  }
  return meshes;
}
