// GPU review harness. Serve a directory containing catalog.json (an array of
// catalog rows) and <slug>.structure / <slug>.folding on localhost:8765.
// flutter run -d <simulator> -t tool/fold_review.dart
// Captures go to Documents/fold-review in the simulator's app container.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_scene/scene.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/core/catalog/protein_track.dart';
import 'package:helixpeek/core/network/track_source.dart';
import 'package:helixpeek/core/theme/anatomy_colors.dart';
import 'package:helixpeek/core/theme/app_theme.dart';
import 'package:helixpeek/shared/folding/fold_bonds.dart';
import 'package:helixpeek/shared/folding/fold_geometry.dart';
import 'package:helixpeek/shared/folding/fold_skin.dart';
import 'package:helixpeek/shared/folding/fold_timeline.dart';
import 'package:helixpeek/shared/folding/folding_track.dart';
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

  /// The whole fold every twentieth of the way, and its last fifth closely:
  /// the same moments the baseline of the blended handover was taken at.
  static final List<double> times = <double>[
    for (int i = 0; i < 16; i++) i / 20,
    for (int i = 0; i <= 16; i++) 0.8 + i * 0.0125,
  ];

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
        'somatotropin',
        'prion',
        'tnf',
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
          Node molecule,
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
        final Stopwatch binding = Stopwatch()..start();
        final List<SkinMesh> meshes = storedMeshesOf(molecule, target);
        final SkinMesh? bonds = meshes
            .where((SkinMesh mesh) => mesh.node == 'bonds')
            .firstOrNull;
        final FoldMorph fold = FoldMorph(
          FoldTimeline(geometry),
          FoldMorph.paletteOf(anatomy, loose, target),
          FoldBinding(
            SkinBinding.bind(geometry, meshes),
            bonds == null ? null : BondsBinding.bind(geometry, bonds),
          ),
        );
        binding.stop();
        root.add(fold.node);
        root.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 1.35);

        // What a frame of the fold costs on the CPU, played through once.
        final Stopwatch cost = Stopwatch();
        double worst = 0;
        for (int frame = 0; frame <= 540; frame++) {
          final int before = cost.elapsedMicroseconds;
          cost.start();
          fold.update(frame / 540);
          cost.stop();
          final double took = (cost.elapsedMicroseconds - before) / 1000;
          if (took > worst) {
            worst = took;
          }
        }
        debugPrint(
          'FOLD_REVIEW $slug binding ${binding.elapsedMilliseconds} ms; '
          'update mean ${(cost.elapsedMicroseconds / 541 / 1000).toStringAsFixed(3)} ms, '
          'worst ${worst.toStringAsFixed(3)} ms',
        );

        fold.update(0);
        await scene.warmUp(<RenderView>[
          RenderView(camera: camera, layerMask: StructureSceneView.foldLayer),
        ]);
        double t = 0;
        int layer = StructureSceneView.foldLayer;
        setState(() {
          _label = slug;
          _view = StructureSceneView(
            key: ValueKey<String>(slug),
            scene: scene,
            camera: camera,
            layerMask: () => layer,
            onTick: (_, _) => fold.update(t),
          );
        });
        for (final double at in times) {
          t = at;
          await _save(
            out,
            '$slug-t${(at * 10000).round().toString().padLeft(5, '0')}',
          );
        }
        // The page's own switch at the end: the same view, the model's layer.
        layer = StructureSceneView.modelLayer;
        await _save(out, '$slug-model');
        // And an independent render of only the stored model.
        fold.node.visible = false;
        setState(() => _view = CustomPaint(painter: _Direct(scene, camera)));
        await _save(out, '$slug-reference');
        debugPrint('FOLD_REVIEW completed $slug');
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
