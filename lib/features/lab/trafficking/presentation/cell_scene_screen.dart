import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/motion/transport_bar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../presentation/lab_protein_picker.dart';
import '../domain/route_captions.dart';
import '../domain/route_timeline.dart';
import '../domain/trafficking_route.dart';
import '../domain/trafficking_track.dart';
import 'cell_painter.dart';
import 'cell_scene_cubit.dart';

/// `/lab/trafficking/<slug>`: one protein's route through the cell.
class CellSceneRoute extends StatelessWidget {
  const CellSceneRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) => LabTargetLoader(
    slug: slug,
    builder: (BuildContext context, ProteinTarget target) =>
        BlocProvider<CellSceneCubit>(
          create: (BuildContext context) =>
              CellSceneCubit(target, context.read<TrackSource>())..load(),
          child: BlocBuilder<CellSceneCubit, CellSceneState>(
            builder: (BuildContext context, CellSceneState state) =>
                switch (state) {
                  CellSceneLoading() => Scaffold(
                    appBar: AppBar(
                      title: Text(CellSceneScreen.titleOf(target)),
                    ),
                    body: LoadingView(
                      label: 'LOADING ${target.slug.toUpperCase()}',
                    ),
                  ),
                  CellSceneFailed(:final String message) => Scaffold(
                    appBar: AppBar(
                      title: Text(CellSceneScreen.titleOf(target)),
                    ),
                    body: ErrorView(
                      title: 'Fetch failed',
                      message: message,
                      onRetry: () => context.read<CellSceneCubit>().load(),
                    ),
                  ),
                  CellSceneUnavailable() => Scaffold(
                    appBar: AppBar(
                      title: Text(CellSceneScreen.titleOf(target)),
                    ),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenPadding),
                        child: Text(
                          'Its route is read from the regions of its '
                          'precursor, and none are published for it.',
                          key: const ValueKey<String>('cell-unavailable'),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  CellSceneReady(
                    :final TraffickingRoute route,
                    :final TraffickingTrack? topology,
                  ) =>
                    CellSceneScreen(
                      target: target,
                      route: route,
                      topology: topology,
                    ),
                },
          ),
        ),
  );
}

/// The one cell scene: a route played step by step on the shared transport
/// bar, the compartments lighting as the chain reaches them, and a caption
/// for each step built from the route's events and the precursor's regions.
///
/// It serves every protein the same way. What differs is the route, and the
/// route is derived; this screen draws whatever it is given, unknown steps
/// included.
class CellSceneScreen extends StatefulWidget {
  const CellSceneScreen({
    required this.target,
    required this.route,
    this.topology,
    super.key,
  });

  final ProteinTarget target;
  final TraffickingRoute route;

  /// Where the route's topology came from, or null where it has none.
  final TraffickingTrack? topology;

  /// How long one step takes at speed 1.
  static const Duration beat = Duration(milliseconds: 1800);

  static String titleOf(ProteinTarget target) =>
      'Where it goes · ${target.display}';

  @override
  State<CellSceneScreen> createState() => _CellSceneScreenState();
}

class _CellSceneScreenState extends State<CellSceneScreen>
    with SingleTickerProviderStateMixin {
  late final RouteTimeline _timeline = RouteTimeline(widget.route);
  late final RouteCaptions _captions = RouteCaptions(
    widget.route,
    chains: widget.target.facts.chains,
  );
  late final TimelineController _controller = TimelineController(
    vsync: this,
    timeline: _timeline,
    beat: CellSceneScreen.beat,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Where the topology came from, or why there is none.
  String _topology() {
    final TraffickingTrack? topology = widget.topology;
    if (topology != null) {
      return 'Which stretches cross a membrane: UniProt release '
          '${topology.release}, fetched ${topology.retrieved}.';
    }
    const TrackKind kind = TrackKind.trafficking;
    return switch (widget.target.state(kind)) {
      TrackState.pending =>
        'Which stretches cross a membrane is on its way from UniProt.',
      TrackState.refused =>
        'Which stretches cross a membrane is not published for it: '
            '${widget.target.reason(kind) ?? 'the pipeline declined'}.',
      TrackState.absent || TrackState.ready =>
        'Which stretches cross a membrane is not published for it.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: Text(CellSceneScreen.titleOf(widget.target))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? painted) => Semantics(
                  label: CellPainter.describe(
                    _timeline,
                    _timeline.stateAt(_controller.t),
                  ),
                  child: painted,
                ),
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey<String>('cell-canvas'),
                    size: Size.infinite,
                    painter: CellPainter(
                      timeline: _timeline,
                      at: () => _controller.t,
                      inks: CellInks.of(context),
                      repaint: _controller,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: 132,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, _) => Text(
                        _captions.captionOf(
                          _timeline.stateAt(_controller.t).step,
                        ),
                        key: const ValueKey<String>('cell-caption'),
                        style: theme.textTheme.bodyMedium,
                        maxLines: 6,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ),
                  Text(
                    'Worked out from its sequence features, not observed in '
                    'a cell, and it says nothing about which cells make it.',
                    key: const ValueKey<String>('cell-inferred'),
                    style: note,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _topology(),
                    key: const ValueKey<String>('cell-topology'),
                    style: note,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TransportBar(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
