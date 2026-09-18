import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/features/gene_lookup/presentation/structure/structure_view.dart';

/// A box the shape of the one the fold is given on a phone.
const Size _box = Size(390, 600);

/// The screen under the fold, which reads a sideways drag as a page turn.
///
/// This is what the zone exists to be protected from, so it is what the zone is
/// tested against: the real [StructureView] cannot be pumped here — it wants a
/// Flutter GPU a headless test does not have — but the gesture it is fighting
/// is the one below, and that is entirely testable.
Future<void> _pump(
  WidgetTester tester, {
  required List<double> pages,
  required List<Offset> turns,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (DragEndDetails details) =>
            pages.add(details.primaryVelocity ?? 0),
        child: Center(
          child: SizedBox.fromSize(
            size: _box,
            child: TurnZone(
              viewport: _box,
              onTurn: (DragUpdateDetails details) => turns.add(details.delta),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the turn zone', () {
    testWidgets('takes the sideways drag the page would otherwise turn on', (
      WidgetTester tester,
    ) async {
      final List<double> pages = <double>[];
      final List<Offset> turns = <Offset>[];
      await _pump(tester, pages: pages, turns: turns);

      // The drag both gestures want. A horizontal drag settles at the touch
      // slop and a pan waits for twice it, so on thresholds alone the page
      // wins this every time and the model never turns about its own axis —
      // which is the rotation that matters, and the bug this zone closes.
      await tester.fling(find.byType(TurnZone), const Offset(-180, 0), 900);
      await tester.pumpAndSettle();

      expect(turns, isNotEmpty);
      expect(pages, isEmpty);
    });

    testWidgets('turns from the first point of movement, not the 36th', (
      WidgetTester tester,
    ) async {
      final List<double> pages = <double>[];
      final List<Offset> turns = <Offset>[];
      await _pump(tester, pages: pages, turns: turns);

      // The pointer is claimed where it lands, so nothing is spent finding out
      // what it meant: ten points of drag are ten points of rotation, where a
      // pan would still be making up its mind.
      await tester.dragFrom(
        tester.getCenter(find.byType(TurnZone)),
        const Offset(10, 0),
      );
      await tester.pumpAndSettle();

      expect(turns.fold(Offset.zero, (Offset sum, Offset d) => sum + d).dx, 10);
      expect(pages, isEmpty);
    });

    testWidgets('leaves the bands above and below it to the page', (
      WidgetTester tester,
    ) async {
      final List<double> pages = <double>[];
      final List<Offset> turns = <Offset>[];
      await _pump(tester, pages: pages, turns: turns);

      final Rect box = tester.getRect(find.byType(TurnZone));
      final double band = (box.height - TurnZone.sideIn(_box)) / 2;
      expect(band, greaterThan(TurnZone.band));

      for (final double y in <double>[
        box.top + band / 2,
        box.bottom - band / 2,
      ]) {
        await tester.flingFrom(
          Offset(box.center.dx, y),
          const Offset(-180, 0),
          900,
        );
        await tester.pumpAndSettle();
      }

      expect(pages.length, 2);
      expect(turns, isEmpty);
    });
  });
}
