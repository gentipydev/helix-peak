import 'dart:math' as math;
import 'dart:ui';

import '../domain/genome_replication.dart';

/// An opened-out view of an established fork. Proteins are spread apart to
/// expose their active sites; nucleotide spacing is compressed. The two 100-nt
/// fragments share actual sequence coordinates with the timeline.
class ReplicationGeometry {
  const ReplicationGeometry(this.frame, {this.top = 27, this.bottom = 550});
  final ReplicationFrame frame;
  static const Size designSize = Size(360, 600);
  static const double pitch = 1.8;
  final double top;
  final double bottom;

  // Follow the fork, as the Ribosome follows its decoding centre.
  double yOf(double index) => forkY + (frame.fork - index) * pitch;
  double get forkY => 170;
  double get firstVisible => frame.fork - (bottom - forkY) / pitch;

  static double _ease(double t) {
    final double v = t.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  Offset centre(double index, {required bool leading}) {
    final double opened = _ease((frame.fork - index) / 58);
    return Offset(180 + (leading ? -1 : 1) * (12 + 91 * opened), yOf(index));
  }

  Offset template(double index, {required bool leading}) {
    if (index >= frame.fork) {
      final double angle = (index - frame.fork) * math.pi * 2 / 38;
      return Offset(
        180 + (leading ? -1 : 1) * 12 * math.cos(angle),
        yOf(index),
      );
    }
    final Offset axis = centre(index, leading: leading);
    final double gap = frame.fork - index;
    final double paired;
    if (leading) {
      paired = _ease((frame.leadingTip - index) / 12);
    } else if (index < 0) {
      paired = 1;
    } else if (index >= 200) {
      paired = 0;
    } else {
      paired = _ease((index - frame.tipOf(index.floor() ~/ 100)) / 12);
    }
    final double twist = 1 + paired * (math.cos(index * math.pi * 2 / 38) - 1);
    final double spread = 12 * _ease(gap / 18);
    return axis + Offset((leading ? -1 : 1) * spread * twist, 0);
  }

  Offset daughter(double index, {required bool leading}) {
    final Offset axis = centre(index, leading: leading);
    return axis * 2 - template(index, leading: leading);
  }

  Offset get leadingEnzyme => centre(frame.leadingTip, leading: true);
  Offset get laggingEnzyme => centre(frame.deltaTip, leading: false);
  Offset get primase =>
      centre(frame.tipOf(frame.activeFragment), leading: false);
  Offset get nick => daughter(89.5, leading: false);
}
