import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/anatomy/stage_bar.dart';
import '../../../shared/format.dart';
import '../../../shared/motion/timeline_controller.dart';
import '../../../shared/motion/transport_bar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../domain/training_timeline.dart';
import '../domain/training_trace.dart';
import 'cubit/peptide_lm_cubit.dart';
import 'lm_about_sheet.dart';
import 'lm_format.dart';
import 'lm_inks.dart';
import 'scenes/lm_drawing.dart';
import 'scenes/lm_scene.dart';
import 'scenes/lm_scene_painter.dart';

/// The Peptide Language Model: one recorded training run of HelixPeekLM on
/// the curated proteins' peptides, played stage by stage.
class PeptideLmScreen extends StatelessWidget {
  const PeptideLmScreen({super.key});

  static const String title = 'Peptide Language Model';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PeptideLmCubit, PeptideLmState>(
      builder: (BuildContext context, PeptideLmState state) => switch (state) {
        PeptideLmReady(:final TrainingTrace trace) => TrainingRunView(trace: trace),
        PeptideLmFailed(:final Object error) => _Waiting(
          child: ErrorView(
            title: 'The run did not load',
            message: _message(error),
            onRetry: () => context.read<PeptideLmCubit>().load(),
            action: 'Retry',
          ),
        ),
        PeptideLmLoading() => const _Waiting(
          child: LoadingView(label: 'LOADING THE TRAINING RUN'),
        ),
      },
    );
  }

  static String _message(Object error) {
    if (error is ServerApiException && error.statusCode == 404) {
      return 'The service holds no recorded run yet.';
    }
    if (error is ApiException) {
      return error.userMessage;
    }
    if (error is FormatException) {
      return 'The recorded run could not be read: ${error.message}.';
    }
    return const UnknownApiException().userMessage;
  }
}

/// The page while the run is on its way, or could not be had: the same
/// ground and title as the run itself.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(PeptideLmScreen.title)),
    body: SafeArea(child: child),
  );
}

/// The run itself: the stage on the canvas, a line of its numbers, the seven
/// stages, and the reader's controls.
class TrainingRunView extends StatefulWidget {
  const TrainingRunView({required this.trace, super.key});

  final TrainingTrace trace;

  /// A beat at 1×: a second.
  static const Duration beat = Duration(seconds: 1);

  @override
  State<TrainingRunView> createState() => _TrainingRunViewState();
}

class _TrainingRunViewState extends State<TrainingRunView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TrainingTimeline _timeline = TrainingTimeline(
    steps: widget.trace.steps.count,
  );
  late final TimelineController _controller = TimelineController(
    vsync: this,
    timeline: _timeline,
    beat: TrainingRunView.beat,
  );
  LmKit? _kit;
  int _checkpoint = 0;
  int _peptide = 0;
  late int _position = _middle(0);
  int? _head;
  bool _resumeOnForeground = false;

  TrainingTrace get _trace => widget.trace;

  int _middle(int peptide) => _trace.peptides[peptide].inputs ~/ 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.reducedMotion = MediaQuery.disableAnimationsOf(context);
      if (!_controller.reducedMotion) _controller.play();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ThemeData theme = Theme.of(context);
    final LmKit kit = LmKit(
      mono: AppTypography.sequenceSmall(theme.colorScheme.onSurfaceVariant),
      sans: theme.caption ?? theme.textTheme.labelSmall!,
      scaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      label: theme.textTheme.labelSmall,
    );
    final LmKit? before = _kit;
    if (before == null ||
        before.mono != kit.mono ||
        before.sans != kit.sans ||
        before.label != kit.label ||
        before.scaler != kit.scaler) {
      before?.dispose();
      _kit = kit;
    } else {
      kit.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_resumeOnForeground) _controller.play();
      _resumeOnForeground = false;
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _resumeOnForeground = _resumeOnForeground || _controller.isPlaying;
      _controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _kit?.dispose();
    super.dispose();
  }

  TrainingFrame _frame() {
    final TrainingFrame frame = _timeline.stateAt(_controller.t);
    return _controller.reducedMotion ? frame.completed(_trace.steps.count) : frame;
  }

  void _apply(LmHit hit) {
    switch (hit) {
      case FocusPeptide(:final int peptide):
        setState(() {
          _peptide = peptide;
          _position = _middle(peptide);
        });
      case FocusPosition(:final int position):
        setState(() => _position = position);
      case FocusHead(:final int? head):
        setState(() => _head = head);
      case PickCheckpoint(:final int index):
        _pick(index);
    }
  }

  /// Shows [index]'s checkpoint in the six stages; in the loop, goes to it.
  void _pick(int index) {
    setState(() => _checkpoint = index);
    if (_frame().stage == LmStage.loop) {
      _controller.pause();
      _controller.seek(_timeline.loopAt(_trace.checkpoints[index].step.toDouble()));
    }
  }

  /// Plays [stage] from its start.
  void _goTo(LmStage stage) {
    _controller.seek(_timeline.startOf(stage));
    if (!_controller.reducedMotion && !_controller.isPlaying) {
      _controller.play();
    }
  }

  Future<void> _showAbout() async {
    final bool resume = _controller.isPlaying;
    _controller.pause();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => LmAboutSheet(trace: _trace),
    );
    if (mounted && resume && !_controller.reducedMotion) _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LmInks inks = LmInks.of(context);
    final LmView view = LmView(
      trace: _trace,
      checkpoint: _trace.checkpoints[_checkpoint],
      peptide: _peptide,
      position: _position,
      head: _head,
      inks: inks,
      kit: _kit!,
    );
    final double textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: math.max(kToolbarHeight, 44 * textScale),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              PeptideLmScreen.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Recorded run · ${grouped(_trace.model.parameters)} parameters',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.caption,
            ),
          ],
        ),
        actions: <Widget>[
          _CheckpointMenu(
            trace: _trace,
            selected: _checkpoint,
            onSelected: _pick,
          ),
          IconButton(
            tooltip: 'How this model learns',
            onPressed: _showAbout,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size size = constraints.biggest;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (TapUpDetails details) {
                      final TrainingFrame now = _frame();
                      final LmHit? hit = sceneOf(now.stage)
                          .hitAt(size, view, details.localPosition, now);
                      if (hit != null) _apply(hit);
                    },
                    onHorizontalDragUpdate: (DragUpdateDetails details) {
                      final int? position = sceneOf(_frame().stage)
                          .positionAt(size, view, details.localPosition);
                      if (position != null && position != _position) {
                        setState(() => _position = position);
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, Widget? child) {
                        final TrainingFrame frame = _frame();
                        return Semantics(
                          label: sceneOf(frame.stage).describe(view, frame),
                          image: true,
                          child: child,
                        );
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey<String>('peptide-lm-canvas'),
                          size: Size.infinite,
                          painter: LmScenePainter(
                            view: view,
                            frame: _frame,
                            repaint: _controller,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                final TrainingFrame frame = _frame();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 40 * textScale),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        sceneOf(frame.stage).caption(view, frame),
                        key: const ValueKey<String>('peptide-lm-caption'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _controller,
              // All seven in view, the whole of one step and its loop, scaled
              // down where a phone is too narrow for them at full size.
              builder: (BuildContext context, Widget? child) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StageBar(
                    labels: <String>[
                      for (final LmStage stage in LmStage.values) stage.label,
                    ],
                    index: _frame().stage.index,
                    reselectable: true,
                    onSelect: (int i) => _goTo(LmStage.values[i]),
                  ),
                ),
              ),
            ),
            TransportBar(
              controller: _controller,
              speeds: const <double>[0.5, 1, 2, 4],
              showPhase: false,
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// The checkpoint the six stages show, picked from the steps that kept every
/// activation, each with its loss.
class _CheckpointMenu extends StatelessWidget {
  const _CheckpointMenu({
    required this.trace,
    required this.selected,
    required this.onSelected,
  });

  final TrainingTrace trace;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Checkpoint',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        for (int i = 0; i < trace.checkpoints.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              'Step ${trace.checkpoints[i].step} · '
              '${nats(trace.loss(trace.checkpoints[i].step))} nats',
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: TransportBar.target,
          minHeight: TransportBar.target,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Step ${trace.checkpoints[selected].step}',
              key: const ValueKey<String>('peptide-lm-checkpoint'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
              semanticsLabel: 'Checkpoint, step ${trace.checkpoints[selected].step}',
            ),
          ),
        ),
      ),
    );
  }
}
