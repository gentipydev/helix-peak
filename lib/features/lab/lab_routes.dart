import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import 'ar/presentation/ar_screen.dart';
import 'crispr/presentation/crispr_screen.dart';
import 'folding/presentation/fold_screen.dart';
import 'lab_scope.dart';
import 'mutate/presentation/mutate_screen.dart';
import 'oxygen/presentation/oxygen_screen.dart';
import 'presentation/lab_index_screen.dart';
import 'presentation/lab_protein_picker.dart';
import 'ribosome/presentation/ribosome_screen.dart';
import 'sickle/domain/sickle_story.dart';
import 'sickle/presentation/sickle_screen.dart';
import 'trafficking/presentation/cell_scene_screen.dart';

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
  LabFeature(
    title: 'The ribosome',
    summary: 'Watch a protein’s own mRNA read into its chain, codon by codon.',
    path: '${RoutePaths.lab}/ribosome',
  ),
  LabFeature(
    title: 'In your room',
    summary: 'A fold at its real size, one ångström to one centimetre.',
    path: '${RoutePaths.lab}/ar',
  ),
  LabFeature(
    title: 'CRISPR',
    summary:
        'Find where a nuclease can cut a gene, and choose what the cell does '
        'with the break.',
    path: '${RoutePaths.lab}/crispr',
  ),
  LabFeature(
    title: 'The sickle cell story',
    summary:
        'Three chapters about one base: what the approved therapy edits, and '
        'what no base editor can write.',
    path: '${RoutePaths.lab}/sickle',
    subject: sickleGene,
  ),
  LabFeature(
    title: 'Where it goes',
    summary:
        'Follow a protein from the ribosome through the cell, along the route '
        'its sequence features lay out.',
    path: '${RoutePaths.lab}/trafficking',
  ),
  LabFeature(
    title: 'Folding',
    summary:
        'Watch a chain fold in four steps into the structure its last page '
        'draws. An illustration, not a simulation.',
    path: '${RoutePaths.lab}/folding',
  ),
  LabFeature(
    title: OxygenRoute.title,
    summary:
        'Four sites fill with oxygen one at a time, and the molecule tips from '
        'tense to relaxed, as the MWC model explains it.',
    path: '${RoutePaths.lab}/oxygen',
    subject: 'HBA1 + HBB',
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
          _picked(
            'ribosome',
            title: 'The ribosome',
            lead: 'Pick a protein to watch its mRNA translated.',
            screen: (String slug) => RibosomeRoute(slug: slug),
          ),
          _picked(
            'ar',
            title: 'In your room',
            lead: 'Pick a protein to stand its fold in the room.',
            screen: (String slug) => ArRoute(slug: slug),
          ),
          _picked(
            'crispr',
            title: 'CRISPR',
            lead: 'Pick a protein to look for guides in its gene.',
            screen: (String slug) => CrisprRoute(slug: slug),
          ),
          // The one flow that does not ask which protein: a story names its
          // own subject, and this one is about the gene [sickleGene].
          GoRoute(
            path: 'sickle',
            builder: (BuildContext context, GoRouterState state) =>
                const SickleRoute(),
          ),
          _picked(
            'trafficking',
            title: 'Where it goes',
            lead: 'Pick a protein to follow through the cell.',
            screen: (String slug) => CellSceneRoute(slug: slug),
          ),
          _picked(
            'folding',
            title: 'Folding',
            lead: 'Pick a protein to watch its chain fold.',
            screen: (String slug) => FoldRoute(slug: slug),
          ),
          // A story of its own subject, as the sickle story is: the assembly
          // the backend's own table names, not a protein picked from twenty.
          GoRoute(
            path: 'oxygen',
            builder: (BuildContext context, GoRouterState state) =>
                const OxygenRoute(),
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
