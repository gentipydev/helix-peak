// GPU review harness. Serve a directory containing catalog.json (an array of
// catalog rows) and <slug>.structure / <slug>.folding on localhost:8765.
// flutter run -d <simulator> -t tool/fold_review.dart
// Captures go to Documents/fold-review in the simulator's app container.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Material;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_scene/scene.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';
import 'package:helixpeek/shared/structure/fold_handover.dart';
import 'package:helixpeek/shared/structure/fold_morph.dart';
import 'package:helixpeek/shared/structure/structure_model.dart';
import 'package:helixpeek/shared/structure/structure_scene_view.dart';
import 'package:helixpeek/shared/structure/structure_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(theme: AppTheme.analysis, home: const _Review()));
}

class _Source implements TrackSource {
  final HttpClient client = HttpClient();
  Future<Uint8List> get(String path) async {
    final HttpClientResponse response = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:8765/$path'),
    )).close();
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode}: $path');
    }
    final BytesBuilder bytes = BytesBuilder();
    await for (final List<int> chunk in response) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  @override
  Future<Uint8List> read(String slug, TrackKind kind) =>
      get('$slug.${kind.name}');
}

class _Review extends StatefulWidget {
  const _Review();
  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  final GlobalKey _capture = GlobalKey();
  final _Source _source = _Source();
  Widget _view = const SizedBox.expand();
  String _label = 'Preparing';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _save(Directory out, String name) async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final RenderRepaintBoundary boundary =
        _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    try {
      final ByteData bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      await File('${out.path}/$name.png')
          .writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  Future<void> _run() async {
    try {
      final List<dynamic> rows = jsonDecode(
        utf8.decode(await _source.get('catalog.json')),
      ) as List<dynamic>;
      final Directory out = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/fold-review',
      );
      await out.create(recursive: true);
      final ThemeData theme = AppTheme.analysis;
      final AnatomyColors anatomy = theme.extension<AnatomyColors>()!;
      final Color loose = theme.colorScheme.onSurfaceVariant;
      for (final String slug in <String>[
        'insulin',
        'lysozyme',
        'p53',
        'vasopressin',
        'prion',
        'cftr',
      ]) {
        final ProteinTarget target = ProteinTarget.fromJson(
          rows.cast<Map<String, dynamic>>().firstWhere(
            (Map<String, dynamic> r) => r['slug'] == slug,
          ),
        );
        final Scene scene = Scene();
        final Node root = Node(name: 'review');
        scene.add(root);
        final (
          Node model,
          PerspectiveCamera camera,
        ) = await buildStructureModel(
          scene,
          anatomy,
          target,
          _source,
          parent: root,
        );
        final FoldGeometry geometry = FoldGeometry.of(
          await FoldingTrack.load(target, tracks: _source),
        );
        final FoldMorph fold = FoldMorph(
          FoldTimeline(geometry),
          FoldMorph.paletteOf(anatomy, loose, target),
        );
        root.add(fold.node);
        root.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 1.35);
        fold.update(1);
        await scene.warmUp(<RenderView>[
          RenderView(camera: camera, layerMask: 2),
        ]);
        double t = FoldTimeline.bridgesClosedAt;
        setState(() {
          _label = slug;
          _view = StructureSceneView(
            key: ValueKey<String>(slug),
            scene: scene,
            camera: camera,
            handover: () => foldHandoverAt(t),
            onTick: (_, _) => fold.update(t),
          );
        });
        for (int frame = 0; frame <= 20; frame++) {
          t =
              FoldTimeline.bridgesClosedAt +
              (1 - FoldTimeline.bridgesClosedAt) * frame / 20;
          await _save(out, '$slug-new-${frame.toString().padLeft(2, '0')}');
        }
        // An independent render of only the stored model, without the fold
        // or the handover view, must match the new final frame pixel for pixel.
        fold.node.visible = false;
        setState(() => _view = CustomPaint(painter: _Direct(scene, camera)));
        await _save(out, '$slug-reference');
        fold.node.visible = true;
        fold.update(1);
        for (int frame = 0; frame <= 20; frame++) {
          final double opacity = 1 - frame / 20;
          for (final Node node in fold.node.children) {
            final List<Material> materials = <Material>[
              for (final MeshPrimitive primitive
                  in node.mesh?.primitives ?? <MeshPrimitive>[])
                primitive.material,
              for (final InstancedMeshComponent component
                  in node.getComponents<InstancedMeshComponent>())
                component.instancedMesh.material,
            ];
            for (final Material surface in materials) {
              final PhysicallyBasedMaterial material =
                  surface as PhysicallyBasedMaterial;
              material.alphaMode = opacity < 1
                  ? AlphaMode.blend
                  : AlphaMode.opaque;
              material.baseColorFactor = vm.Vector4(1, 1, 1, opacity);
            }
          }
          fold.node.visible = frame < 20;
          setState(() => _view = CustomPaint(painter: _Direct(scene, camera)));
          await _save(out, '$slug-overlap-${frame.toString().padLeft(2, '0')}');
        }
        debugPrint('FOLD_REVIEW completed $slug');
        model.visible = true;
      }
      debugPrint('FOLD_REVIEW output ${out.path}');
      final ProteinTarget insulin = ProteinTarget.fromJson(
        rows.cast<Map<String, dynamic>>().firstWhere(
          (Map<String, dynamic> r) => r['slug'] == 'insulin',
        ),
      );
      setState(() {
        _label = 'Live insulin fold';
        _view = RepositoryProvider<TrackSource>.value(
          value: _source,
          child: StructureView(
            viewport: const Size(390, 624),
            target: insulin,
            folds: true,
          ),
        );
      });
    } on Object catch (error, stack) {
      debugPrint('FOLD_REVIEW ERROR $error\n$stack');
      setState(() => _label = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_label)),
    body: Center(
      child: RepaintBoundary(
        key: _capture,
        child: SizedBox(
          width: 390,
          height: 624,
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _view,
          ),
        ),
      ),
    ),
  );
}

class _Direct extends CustomPainter {
  _Direct(this.scene, this.camera);
  final Scene scene;
  final Camera camera;
  @override
  void paint(Canvas canvas, Size size) =>
      scene.render(camera, canvas, viewport: Offset.zero & size);
  @override
  bool shouldRepaint(_Direct oldDelegate) => true;
}
