import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';

/// A single clock and camera for the fold and the unchanged stored model,
/// drawing one of them at a time: the fold while it plays, the model after.
/// The fold ends as the model's own mesh, so the switch changes no pixel.
class StructureSceneView extends StatefulWidget {
  const StructureSceneView({
    required this.scene,
    required this.camera,
    required this.layerMask,
    required this.onTick,
    super.key,
  });

  final Scene scene;
  final Camera camera;

  /// Which layers to draw this frame.
  final int Function() layerMask;
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

  void _paint(Canvas canvas, Size size, double pixelRatio) {
    if (size.isEmpty) {
      return;
    }
    widget.scene.renderViews(
      <RenderView>[
        RenderView(camera: widget.camera, layerMask: widget.layerMask()),
      ],
      canvas,
      region: Offset.zero & size,
      pixelRatio: pixelRatio,
    );
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
