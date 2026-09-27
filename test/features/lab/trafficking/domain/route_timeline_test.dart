import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/catalog/protein_target.dart';
import 'package:helixpeek/features/lab/trafficking/domain/route_timeline.dart';
import 'package:helixpeek/features/lab/trafficking/domain/trafficking_route.dart';
import 'package:helixpeek/shared/motion/animation_timeline.dart';

import '../../../../support/test_catalog.dart';
import '../trafficking_fixtures.dart';

void main() {
  test('one beat and one named phase for each step of the route', () {
    final RouteTimeline timeline = RouteTimeline(routeOf(TestCatalog.insulin));
    expect(timeline.beats, 5);
    expect(timeline.phases.map((PhaseMark p) => p.name), <String>[
      'Cytosol',
      'Endoplasmic reticulum',
      'Golgi',
      'Vesicle',
      'Outside the cell',
    ]);
    expect(timeline.phases.map((PhaseMark p) => p.t), <double>[
      0,
      0.2,
      0.4,
      0.6,
      0.8,
    ]);
  });

  test(
    'each step is reached at its own boundary, and the end holds the last',
    () {
      for (final ProteinTarget target in TestCatalog.all) {
        for (final bool topology in <bool>[true, false]) {
          final RouteTimeline timeline = RouteTimeline(
            routeOf(target, topology: topology),
          );
          for (int i = 0; i < timeline.beats; i++) {
            final RouteMoment moment = timeline.stateAt(timeline.phases[i].t);
            expect(moment.step, i, reason: target.slug);
            expect(moment.progress, 0, reason: target.slug);
          }
          final RouteMoment end = timeline.stateAt(1);
          expect(end.step, timeline.beats - 1, reason: target.slug);
          expect(end.progress, 1, reason: target.slug);
        }
      }
    },
  );

  test('a phase never shows as a number, and an unknown step says so', () {
    final RouteTimeline stops = RouteTimeline(
      routeOf(TestCatalog.p53, topology: false),
    );
    expect(stops.phases.last.name, 'Not known');
    for (final Compartment compartment in Compartment.values) {
      expect(RouteTimeline.nameOf(compartment), isNot(matches(RegExp(r'\d'))));
    }
  });
}
