import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/anatomy/stage_bar.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../domain/loop_pace.dart';
import '../domain/training_timeline.dart';
import '../domain/training_trace.dart';
import 'cubit/peptide_lm_cubit.dart';
import 'lm_format.dart';
import 'lm_info_sheet.dart';
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

/// The run itself: the stage on the canvas, a line of its numbers with the
/// stage's own player, and the eight stages, a tap on one playing it once
/// from its start.
class TrainingRunView extends StatefulWidget {
  const TrainingRunView({required this.trace, super.key});

  final TrainingTrace trace;

  /// A beat: two seconds, the page's one speed, slow enough to follow each
  /// change.
  static const Duration beat = Duration(seconds: 2);

  @override
  State<TrainingRunView> createState() => _TrainingRunViewState();
}

class _TrainingRunViewState extends State<TrainingRunView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const TrainingTimeline _timeline = TrainingTimeline();

  /// How far through [_stage], from 0 to 1, where it stops and holds.
  late final AnimationController _clock = AnimationController(vsync: this);
  LmStage _stage = LmStage.tokenise;
  bool _reduced = false;
  LmKit? _kit;
  int _checkpoint = 0;
  int _peptide = 0;
  late int _position = _middle(0);
  int? _head;
  bool _resumeOnForeground = false;

  /// The stage bar, inside its scroll, whose names [_reveal] brings into
  /// view.
  final GlobalKey _bar = GlobalKey();

  /// What [_reserve] was worked out for, and the height itself.
  Object? _reserveFor;
  double _reserve = 0;

  TrainingTrace get _trace => widget.trace;

  int _middle(int peptide) => _trace.peptides[peptide].inputs ~/ 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _play(LmStage.tokenise);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) _clock.stop();
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
      if (_resumeOnForeground && !_reduced) unawaited(_clock.forward());
      _resumeOnForeground = false;
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _resumeOnForeground = _resumeOnForeground || _clock.isAnimating;
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    _kit?.dispose();
    super.dispose();
  }

  /// With reduced motion, the stage played through.
  TrainingFrame _frame() => _timeline.frameIn(_stage, _reduced ? 1 : _clock.value);

  /// How tall the stage on screen's tallest caption is at [width], so that
  /// the caption's box, and the canvas over it, hold still while it plays:
  /// its captions read through the stage, the loop's once in each of its
  /// parts, each of which keeps one caption.
  double _captionReserve(
    LmView view,
    double width,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final Object key = (_stage, width, style, scaler, _checkpoint, _peptide, _position, _head);
    if (key == _reserveFor) return _reserve;
    final LmScene scene = sceneOf(_stage);
    final List<double> moments = _stage == LmStage.loop
        ? LoopPace.of(_trace).samples
        : <double>[for (int i = 0; i <= 96; i++) i / 96];
    final TextPainter painter = TextPainter(textDirection: direction, textScaler: scaler);
    double tallest = 0;
    for (final double local in moments) {
      painter
        ..text = TextSpan(
          text: scene.caption(view, _timeline.frameIn(_stage, local)),
          style: style,
        )
        ..layout(maxWidth: math.max(0, width));
      tallest = math.max(tallest, painter.height);
    }
    painter.dispose();
    _reserveFor = key;
    return _reserve = tallest;
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

  /// Shows [index]'s checkpoint in every stage; in the loop, holds it there.
  void _pick(int index) {
    setState(() => _checkpoint = index);
    if (_stage == LmStage.loop) {
      _clock
        ..stop()
        ..value = LoopPace.of(_trace).landing(index);
    }
  }

  /// Plays [stage] once from its start, and holds on its last frame.
  void _play(LmStage stage) {
    setState(() => _stage = stage);
    _clock
      ..stop()
      ..duration = TrainingRunView.beat * stage.beats;
    if (!_reduced) unawaited(_clock.forward(from: 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal(stage);
    });
  }

  /// Scrolls the stage bar just far enough to show [stage]'s name whole,
  /// where it stands partly out of view; otherwise the bar keeps still.
  void _reveal(LmStage stage) {
    final BuildContext? bar = _bar.currentContext;
    if (bar == null) return;
    // The bar names each stage by this key.
    final Key key = ValueKey<String>('stage-${stage.label}');
    Element? name;
    void visit(Element element) {
      if (name != null) return;
      if (element.widget.key == key) {
        name = element;
        return;
      }
      element.visitChildren(visit);
    }

    bar.visitChildElements(visit);
    final Element? found = name;
    if (found == null) return;
    final Duration duration = _reduced ? Duration.zero : const Duration(milliseconds: 220);
    for (final ScrollPositionAlignmentPolicy policy in <ScrollPositionAlignmentPolicy>[
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    ]) {
      unawaited(
        Scrollable.ensureVisible(
          found,
          duration: duration,
          curve: Curves.easeOutCubic,
          alignmentPolicy: policy,
        ),
      );
    }
  }

  /// Pauses the stage on screen, or plays it on from where it stands: from
  /// its start again once it has played through.
  void _toggle() {
    setState(() {
      if (_clock.isAnimating) {
        _clock.stop();
      } else {
        unawaited(_clock.forward(from: _clock.value >= 1 ? 0 : null));
      }
    });
  }

  /// The stage on screen's own info page, [info]; the stage holds still
  /// while it is up.
  Future<void> _showInfo(LmInfo info) async {
    final bool resume = _clock.isAnimating;
    _clock.stop();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => LmInfoSheet(info: info),
    );
    if (mounted && resume && !_reduced) unawaited(_clock.forward());
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
            const _Whole(
              Text(PeptideLmScreen.title, maxLines: 1),
            ),
            _Whole(
              Text(
                'Recorded run · ${grouped(_trace.model.parameters)} parameters',
                maxLines: 1,
                style: theme.caption,
              ),
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
            key: const ValueKey<String>('peptide-lm-info'),
            tooltip: 'About ${_stage.label}',
            // Built when asked for: the page is the stage's in the run's
            // numbers, at the checkpoint and focus on screen.
            onPressed: () => _showInfo(sceneOf(_stage).info(view)),
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
                      animation: _clock,
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
                            repaint: _clock,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // The icons' own inset puts them 20 from the edge, as the
            // caption is.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 8, 2),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final double reserve = _captionReserve(
                    view,
                    box.maxWidth - 2 * kMinInteractiveDimension,
                    DefaultTextStyle.of(context).style.merge(theme.textTheme.bodyMedium),
                    MediaQuery.textScalerOf(context),
                    Directionality.of(context),
                  );
                  return AnimatedBuilder(
                    animation: _clock,
                    builder: (BuildContext context, Widget? child) {
                      final TrainingFrame frame = _frame();
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(40 * textScale, reserve),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              // Each caption from the top of the stage's
                              // tallest, so that its first line holds still
                              // while the stage plays.
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: reserve),
                                child: Align(
                                  alignment: AlignmentDirectional.topStart,
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      sceneOf(frame.stage).caption(view, frame),
                                      key: const ValueKey<String>('peptide-lm-caption'),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _StagePlayer(
                              playing: _clock.isAnimating,
                              onReplay: _reduced ? null : () => _play(_stage),
                              onToggle: _reduced ? null : _toggle,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // The whole of one step and its loop in one row, at full size: it
            // scrolls sideways where a phone is too narrow for it, and is
            // centred where it is not. A tap plays a stage, the one on
            // screen again.
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                key: const ValueKey<String>('peptide-lm-stages'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ConstrainedBox(
                  key: _bar,
                  constraints: BoxConstraints(minWidth: math.max(0, box.maxWidth - 8)),
                  child: Center(
                    child: StageBar(
                      labels: <String>[
                        for (final LmStage stage in LmStage.values) stage.label,
                      ],
                      index: _stage.index,
                      reselectable: true,
                      onSelect: (int i) => _play(LmStage.values[i]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// [child], a line of the header, shrunk just enough where the header is
/// narrower than it, so the page's name is never cut short.
class _Whole extends StatelessWidget {
  const _Whole(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );
}

/// The player of the stage on screen, and of nothing else: it plays the
/// stage again from its start, and pauses it or plays it on. Off with
/// reduced motion, where each stage is one still.
class _StagePlayer extends StatelessWidget {
  const _StagePlayer({
    required this.playing,
    required this.onReplay,
    required this.onToggle,
  });

  final bool playing;
  final VoidCallback? onReplay;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle square = IconButton.styleFrom(
      minimumSize: const Size.square(kMinInteractiveDimension),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          style: square,
          tooltip: 'Replay',
          onPressed: onReplay,
          icon: const Icon(Icons.replay_rounded),
        ),
        IconButton(
          style: square,
          tooltip: playing ? 'Pause' : 'Play',
          onPressed: onToggle,
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
      ],
    );
  }
}

/// The checkpoint the eight stages show, picked from the steps that kept every
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
    final TextStyle? style = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.primary,
    );
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
      // As wide as the widest step's name, whichever is picked, its own
      // name at the end, where it always stood: the title beside it keeps
      // its room as the step changes.
      child: SizedBox(
        width: math.max(kMinInteractiveDimension, _widest(context, style) + 16),
        height: kMinInteractiveDimension,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text(
              'Step ${trace.checkpoints[selected].step}',
              key: const ValueKey<String>('peptide-lm-checkpoint'),
              style: style,
              semanticsLabel: 'Checkpoint, step ${trace.checkpoints[selected].step}',
            ),
          ),
        ),
      ),
    );
  }

  /// The width of the widest of the steps' names, as the button writes them.
  double _widest(BuildContext context, TextStyle? style) {
    final TextPainter painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    final TextStyle written = DefaultTextStyle.of(context).style.merge(style);
    double widest = 0;
    for (final TraceCheckpoint checkpoint in trace.checkpoints) {
      painter
        ..text = TextSpan(text: 'Step ${checkpoint.step}', style: written)
        ..layout();
      widest = math.max(widest, painter.width);
    }
    painter.dispose();
    return widest.ceilToDouble();
  }
}
