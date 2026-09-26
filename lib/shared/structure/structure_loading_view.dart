import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// The chain-colored pulse shown while the protein and renderer load.
class StructureLoadingView extends StatelessWidget {
  const StructureLoadingView({super.key});

  static const String asset = 'assets/animations/process.json';

  /// Shares Lottie's asset cache with the widget so its first frame can paint
  /// before the more expensive 3D initialization starts.
  static Future<void> preload() async {
    await AssetLottie(asset).load();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Loading protein structure',
      liveRegion: true,
      child: Center(
        child: RepaintBoundary(
          child: Lottie.asset(
            asset,
            width: 128,
            height: 128,
            fit: BoxFit.contain,
            // By default Lottie snaps to the composition's own frame rate,
            // which is not the screen's. The rings only scale and fade, so
            // every in-between frame is exact and costs a handful of ellipses
            // to paint.
            frameRate: FrameRate.max,
            animate: !reducedMotion,
            controller: reducedMotion
                ? const AlwaysStoppedAnimation<double>(0.125)
                : null,
          ),
        ),
      ),
    );
  }
}
