import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_layout.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_scene.dart';
import 'package:helixpeek/features/gene_lookup/presentation/anatomy/anatomy_stages.dart';

import 'anatomy_fixture.dart';

const Size _canvas = Size(342, 621);

void main() {
  final AnatomyModel model = AnatomyModel.derive(insulin());
  final AnatomyScene splicing = AnatomyScene.between(
    model: model,
    fromIndex: 0,
    toIndex: 1,
    canvas: _canvas,
    viewport: _canvas,
  );

  group('the two staggers', () {
    test('the page turn keeps the one it was tuned to', () {
      // [AnatomyMotion.staggered] took a parameter when the reading frame
      // needed a longer sweep of its own. Every existing caller passes none,
      // and must still get the number the reflow was built on.
      for (final double u in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(
          AnatomyMotion.staggered(0.6, u),
          AnatomyMotion.staggered(0.6, u, lead: AnatomyMotion.stagger),
          reason: 'at u = $u',
        );
      }
    });

    test('the frame sweeps for longer than the reflow does', () {
      // The reflow is one event among the seven the splice is running; the
      // groove is the only thing moving on a page that has settled, so it is
      // given the room to be read as a sweep.
      expect(
        AnatomyMotion.codonStagger,
        greaterThan(AnatomyMotion.stagger),
      );
      expect(
        AnatomyMotion.staggered(0.5, 1, lead: AnatomyMotion.codonStagger),
        lessThan(AnatomyMotion.staggered(0.5, 1)),
      );
    });
  });

  group('the reflow', () {
    test('starts every cell where it was and lands it where it goes', () {
      for (int cell = 0; cell < splicing.from.count; cell += 37) {
        expect(
          splicing.positionOf(cell, 0),
          splicing.fromLayout.centreOf(cell),
          reason: 'cell $cell does not start where it was drawn',
        );
        final int landing = splicing.target[cell];
        if (landing >= 0) {
          final Offset end = splicing.positionOf(cell, 1);
          expect(
            (end - splicing.toLayout.centreOf(landing)).distance,
            lessThan(1e-9),
            reason: 'cell $cell does not arrive where the next stage draws it',
          );
        }
      }
    });

    test("ripples 5' to 3' rather than moving all at once", () {
      const double t = 0.4;
      double travelled(int cell) =>
          (splicing.positionOf(cell, t) - splicing.positionOf(cell, 0)).distance;

      // The last base of the gene has not set off while the first is well on
      // its way — transcription and translation both run in that direction.
      expect(AnatomyMotion.staggered(t, 0), greaterThan(0.5));
      expect(AnatomyMotion.staggered(t, 1), lessThan(0.2));
      expect(travelled(splicing.from.count - 1), lessThan(travelled(0)));
    });

    test('curves rather than sliding straight', () {
      // Whichever surviving cell travels furthest: an arc is only meaningful
      // over a real distance, and the reflow moves cells by wildly different
      // amounts.
      int cell = 0;
      double furthest = 0;
      for (int c = 0; c < splicing.from.count; c++) {
        if (splicing.target[c] < 0) {
          continue;
        }
        final double distance =
            (splicing.positionOf(c, 1) - splicing.positionOf(c, 0)).distance;
        if (distance > furthest) {
          furthest = distance;
          cell = c;
        }
      }

      final Offset start = splicing.positionOf(cell, 0);
      final Offset end = splicing.positionOf(cell, 1);
      final Offset middle = splicing.positionOf(cell, 0.5);
      final Offset straight = (start + end) / 2;

      expect((end - start).distance, greaterThan(20));
      expect((middle - straight).distance, greaterThan(1));
    });

    test('departing cells drift outward, never in place and never inward', () {
      final Offset centre = Offset(_canvas.width / 2, _canvas.height / 2);
      int checked = 0;
      for (int cell = 0; cell < splicing.from.count; cell += 23) {
        if (splicing.target[cell] >= 0) {
          continue;
        }
        checked++;
        final Offset start = splicing.positionOf(cell, 0);
        final Offset end = splicing.departurePoint(cell);
        expect(
          (end - start).distance,
          closeTo(splicing.fromLayout.cell * AnatomyMotion.driftCells, 1e-6),
          reason: 'cell $cell did not drift',
        );
        expect(
          (end - centre).distance,
          greaterThan((start - centre).distance),
          reason: 'cell $cell drifted inward',
        );
      }
      expect(checked, greaterThan(20));
    });

    test('the drift is flattened, so it parts sideways', () {
      // Straight up or down out of the middle of the canvas would be a radial
      // burst; the horizontal component has to dominate away from the centre.
      final Offset away = AnatomyMotion.driftDirection(
        const Offset(60, 500),
        _canvas,
      );
      expect(away.dx.abs(), greaterThan(away.dy.abs()));
      expect(away.dx, lessThan(0));
    });
  });

  group('reverse', () {
    test('is the forward scene read backwards, not a second animation', () {
      // Both directions build the scene from the earlier stage, so there is
      // only ever one reflow to get right — and running it from 1 to 0 is what
      // reinserts the introns rather than glitching.
      final AnatomyScene backwards = AnatomyScene.between(
        model: model,
        fromIndex: 0,
        toIndex: 1,
        canvas: _canvas,
        viewport: _canvas,
      );
      for (int cell = 0; cell < splicing.from.count; cell += 53) {
        expect(backwards.target[cell], splicing.target[cell]);
        expect(
          backwards.positionOf(cell, 0),
          splicing.positionOf(cell, 0),
        );
      }
    });
  });

  group('layout invariants the painter relies on', () {
    test('the connector bulge is reserved, so no turn is clipped away', () {
      for (final AnatomyStage stage in model.stages) {
        final AnatomyLayout layout = AnatomyLayout.fit(
          blocks: stage.blocks,
          canvas: _canvas,
        );
        final Rect bounds = layout.connectors().getBounds();
        if (bounds.isEmpty) {
          continue;
        }
        expect(bounds.left, greaterThanOrEqualTo(-1e-6));
        expect(bounds.right, lessThanOrEqualTo(_canvas.width + 1e-6));
      }
    });
  });
}
