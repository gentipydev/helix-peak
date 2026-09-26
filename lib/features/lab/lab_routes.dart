import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import 'lab_scope.dart';
import 'presentation/lab_index_screen.dart';

/// The lab's routes, or none: the lab is built only where [Env.labEnabled]
/// says so. `lib/app.dart` spreads these into the app's router.
List<RouteBase> get labRoutes =>
    Env.labEnabled ? buildLabRoutes() : const <RouteBase>[];

/// The features the index lists, in the order they arrived.
const List<LabFeature> labFeatures = <LabFeature>[];

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
      ),
    ],
  ),
];
