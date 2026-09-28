import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/folding/fold_captions.dart';
import '../../../../shared/folding/fold_geometry.dart';
import '../../../../shared/folding/fold_timeline.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/motion/transport_bar.dart';
import '../../../../shared/structure/structure_rotation.dart';
import '../../../../shared/structure/structure_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../presentation/lab_protein_picker.dart';
import 'fold_cubit.dart';
import 'fold_painter.dart';

/// `/lab/folding/<slug>`: one protein's chain, folding.
class FoldRoute extends StatelessWidget {
  const FoldRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) => LabTargetLoader(
    slug: slug,
    builder: (BuildContext context, ProteinTarget target) =>
        BlocProvider<FoldCubit>(
          create: (BuildContext context) =>
              FoldCubit(target, context.read<TrackSource>())..load(),
          child: BlocBuilder<FoldCubit, FoldState>(
            builder: (BuildContext context, FoldState state) => switch (state) {
              FoldLoading() => Scaffold(
                appBar: AppBar(title: Text(FoldScreen.titleOf(target))),
                body: LoadingView(
                  label: 'LOADING ${target.slug.toUpperCase()}',
                ),
              ),
              FoldFailed(:final String message) => Scaffold(
                appBar: AppBar(title: Text(FoldScreen.titleOf(target))),
                body: ErrorView(
                  title: 'Fetch failed',
                  message: message,
                  onRetry: () => context.read<FoldCubit>().load(),
                ),
              ),
              FoldUnavailable(:final TrackState state, :final String? reason) =>
                Scaffold(
                  appBar: AppBar(title: Text(FoldScreen.titleOf(target))),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      child: Text(
                        FoldScreen.unavailable(state, reason),
                        key: const ValueKey<String>('fold-unavailable'),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              FoldReady(:final FoldGeometry geometry) => FoldScreen(
                key: ValueKey<String>(target.slug),
                target: target,
                geometry: geometry,
              ),
            },
          ),
        ),
  );
}

/// The fold animation: a chain folding in four staged steps on the shared
/// transport bar, drawn through the fold page's own camera so that its last
/// frame is the fold that page draws. It says, on every step, that it is an
/// illustration and not a simulation.
///
/// Every protein is drawn the same way; what differs is its track.
class FoldScreen extends StatefulWidget {
  const FoldScreen({required this.target, required this.geometry, super.key});

  final ProteinTarget target;
  final FoldGeometry geometry;

  /// How long one beat takes at speed 1: twelve beats, nine seconds.
  static const Duration beat = Duration(milliseconds: 750);

  static String titleOf(ProteinTarget target) => 'Folding · ${target.display}';

  /// What the screen says where the row has no fold for it.
  static String unavailable(TrackState state, String? reason) =>
      switch (state) {
        TrackState.pending => 'Its fold, residue by residue, is on its way.',
        TrackState.refused =>
          'Its fold, residue by residue, is not published: '
              '${reason ?? 'the pipeline declined'}.',
        TrackState.absent || TrackState.ready =>
          'Its fold, residue by residue, is not published yet.',
      };

  @override
  State<FoldScreen> createState() => _FoldScreenState();
}

class _FoldScreenState extends State<FoldScreen> with TickerProviderStateMixin {
  late final FoldTimeline _timeline = FoldTimeline(widget.geometry);
  late final FoldCaptions _captions = FoldCaptions(widget.geometry);
  late final TimelineController _controller = TimelineController(
    vsync: this,
    timeline: _timeline,
    beat: FoldScreen.beat,
  );

  /// The screen's own clock, in seconds, for the loose residues alone: they
  /// go on moving once the timeline has stopped.
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((Duration elapsed) {
    _clock.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  });

  /// Turned by a drag, as the fold page turns its model; no idle turn, so
  /// the last frame is the page's opening view until the reader turns it.
  final StructureRotation _rotation = StructureRotation();
  final ValueNotifier<int> _turns = ValueNotifier<int>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still =
        MediaQuery.disableAnimationsOf(context) ||
        widget.geometry.loose.isEmpty;
    if (still && _ticker.isActive) {
      _ticker.stop();
    } else if (!still && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    _clock.dispose();
    _turns.dispose();
    super.dispose();
  }

  void _turn(DragUpdateDetails details) {
    _rotation.drag(details.delta);
    _turns.value++;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final String? loose = _captions.looseNote;
    return Scaffold(
      appBar: AppBar(title: Text(FoldScreen.titleOf(widget.target))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) => Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, Widget? painted) =>
                          Semantics(
                            label: FoldPainter.describe(
                              _timeline,
                              _timeline.stateAt(_controller.t),
                            ),
                            child: painted,
                          ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey<String>('fold-canvas'),
                          size: Size.infinite,
                          painter: FoldPainter(
                            timeline: _timeline,
                            at: () => _controller.t,
                            idle: () => _clock.value,
                            rotation: () => _rotation.value,
                            inks: FoldInks.of(context, widget.target),
                            repaint: Listenable.merge(<Listenable>[
                              _controller,
                              _clock,
                              _turns,
                            ]),
                          ),
                        ),
                      ),
                    ),
                    TurnZone(viewport: box.biggest, onTurn: _turn),
                  ],
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
                    height: 108,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, _) => Text(
                        _captions.captionOf(FoldTimeline.stepAt(_controller.t)),
                        key: const ValueKey<String>('fold-caption'),
                        style: theme.textTheme.bodyMedium,
                        maxLines: 5,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ),
                  Text(
                    _captions.illustration,
                    key: const ValueKey<String>('fold-illustration'),
                    style: note,
                  ),
                  if (loose != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      loose,
                      key: const ValueKey<String>('fold-loose'),
                      style: note,
                    ),
                  ],
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
