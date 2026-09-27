import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import 'lab_scope.dart';
import 'mutate/presentation/mutate_screen.dart';
import 'presentation/lab_index_screen.dart';
import 'presentation/lab_protein_picker.dart';

/// The lab's routes, or none: the lab is built only where [Env.labEnabled]
/// says so. `lib/app.dart` spreads these into the app's router.
List<RouteBase> get labRoutes =>
    Env.labEnabled ? buildLabRoutes() : const <RouteBase>[];

/// The features the index lists, in the order they arrived.
const List<LabFeature> labFeatures = <LabFeature>[
  LabFeature(
    title: 'Mutate it yourself',
    summary: 'Change one base of a gene and watch what it does to the protein.',
    path: '${RoutePaths.lab}/mutate',
  ),
];

/// Every route under [RoutePaths.lab], whatever the flag says. One shell
/// holds them all, so they share one [LabScope] and its cache.
List<RouteBase> buildLabRoutes() => <RouteBase>[
  ShellRoute(
    builder: (BuildContext context, GoRouterState state, Widget child) =>
        LabScope(child: child),
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.lab,
        builder: (BuildContext context, GoRouterState state) =>
            const LabIndexScreen(features: labFeatures),
        routes: <RouteBase>[
          _picked(
            'mutate',
            title: 'Mutate',
            lead: 'Pick a protein, then a base of its gene to change.',
            screen: (String slug) => MutateRoute(slug: slug),
          ),
        ],
      ),
    ],
  ),
];

/// A flow at `/lab/[path]`: a protein picker there, and the flow's own screen
/// for each protein at `/lab/[path]/<slug>`.
GoRoute _picked(
  String path, {
  required String title,
  required String lead,
  required Widget Function(String slug) screen,
}) => GoRoute(
  path: path,
  builder: (BuildContext context, GoRouterState state) => LabProteinPicker(
    title: title,
    base: '${RoutePaths.lab}/$path',
    lead: lead,
  ),
  routes: <RouteBase>[
    GoRoute(
      path: ':slug',
      builder: (BuildContext context, GoRouterState state) =>
          screen(state.pathParameters['slug']!),
    ),
  ],
);
