import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/anatomy/anatomy_motion.dart';
import 'package:helixpeek/shared/ribosome/translation_flight.dart';

void main() {
  group('the flight', () {
    test('starts where the chain is and ends in the cell', () {
      const Offset from = Offset(10, 300);
      const Offset to = Offset(200, 40);
      expect(flightPosition(from, to, 0), from);
      expect(flightPosition(from, to, 1), to);
    });

    test('bows off the straight line by the walk’s own bow', () {
      const Offset from = Offset(0, 0);
      const Offset to = Offset(100, 0);
      final Offset middle = flightPosition(from, to, 0.5);
      expect(middle.dx, closeTo(50, 1e-9));
      // Halfway along a quadratic sits half its control point's offset.
      expect(middle.dy, closeTo(100 * AnatomyMotion.bow / 2, 1e-9));
    });

    test('sets off 5′ first, by the walk’s own stagger', () {
      expect(flightProgress(0.3, 0), greaterThan(flightProgress(0.3, 1)));
      expect(flightProgress(0, 0), 0);
      expect(flightProgress(1, 1), 1);
      expect(
        flightProgress(0.5, 0.5),
        AnatomyMotion.ease(AnatomyMotion.staggered(0.5, 0.5)),
      );
    });
  });
}
