import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';

import 'fold_handover.dart';

/// A single clock and camera for the fold and the unchanged stored model.
/// Only the handover needs two renders; before and after it, draw one view.
class StructureSceneView extends StatefulWidget {
  const StructureSceneView({
    required this.scene,
    required this.camera,
    required this.handover,
    required this.onTick,
    super.key,
  });

  final Scene scene;
  final Camera camera;
  final double Function() handover;
  final SceneTickCallback onTick;

  static const int modelLayer = 1;
  static const int foldLayer = 2;

  @override
  State<StructureSceneView> createState() => _StructureSceneViewState();
}

class _StructureSceneViewState extends State<StructureSceneView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Duration? _previous;
  RenderTexture? _fold;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((Duration elapsed) {
      final double delta = _previous == null
          ? 0
          : (elapsed - _previous!).inMicroseconds / 1e6;
      _previous = elapsed;
      widget.onTick(elapsed, delta);
      _frame.value++;
    })..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A resumed page must not accumulate an off-screen rotation in one tick.
    _previous = null;
  }

  void _releaseTargets() {
    _fold?.dispose();
    _fold = null;
  }

  void _paint(Canvas canvas, Size size, double pixelRatio) {
    if (size.isEmpty) {
      return;
    }
    final double p = widget.handover();
    final Rect bounds = Offset.zero & size;
    if (p <= 0 || p >= 1) {
      _releaseTargets();
      widget.scene.renderViews(
        <RenderView>[
          RenderView(
            camera: widget.camera,
            layerMask: p <= 0
                ? StructureSceneView.foldLayer
                : StructureSceneView.modelLayer,
          ),
        ],
        canvas,
        region: bounds,
        pixelRatio: pixelRatio,
      );
      return;
    }

    final int width = (size.width * pixelRatio).ceil();
    final int height = (size.height * pixelRatio).ceil();
    _fold ??= RenderTexture(width: width, height: height);
    _fold!.resize(width, height);
    // One scene submission prepares both views with the same camera, turn,
    // lighting and tick, but independent color and depth attachments.
    // Record the model's normal screen render as GPU drawing commands,
    // reusing the scene's screen buffers. No CPU image readback is needed.
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    widget.scene.renderViews(
      <RenderView>[
        RenderView(
          camera: widget.camera,
          layerMask: StructureSceneView.foldLayer,
          target: _fold,
        ),
        RenderView(
          camera: widget.camera,
          layerMask: StructureSceneView.modelLayer,
        ),
      ],
      Canvas(recorder),
      region: bounds,
      pixelRatio: pixelRatio,
    );
    final ui.Image fold = _fold!.texture!.asImage();
    final ui.Picture model = recorder.endRecording();
    final Rect source = Rect.fromLTWH(
      0,
      0,
      width.toDouble(),
      height.toDouble(),
    );
    final Paint paint = Paint()..filterQuality = widget.scene.filterQuality;
    try {
      paintFoldHandover(
        canvas,
        bounds,
        progress: p,
        paintFold: () => canvas.drawImageRect(fold, source, bounds, paint),
        paintModel: () => canvas.drawPicture(model),
      );
    } finally {
      fold.dispose();
      model.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _StructurePainter(
      _frame,
      _paint,
      View.of(context).devicePixelRatio,
    ),
    size: Size.infinite,
  );

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _releaseTargets();
    super.dispose();
  }
}

class _StructurePainter extends CustomPainter {
  _StructurePainter(Listenable repaint, this.draw, this.pixelRatio)
    : super(repaint: repaint);

  final void Function(Canvas, Size, double) draw;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) => draw(canvas, size, pixelRatio);

  @override
  bool shouldRepaint(_StructurePainter oldDelegate) => true;
}
