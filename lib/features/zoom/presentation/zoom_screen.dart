import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/biology/gene_record.dart';
import '../../../core/catalog/protein_target.dart';
import '../../../core/catalog/protein_track.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/track_source.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../gene_lookup/data/repositories/protein_catalog_repository.dart';
import '../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../domain/locus_track.dart';
import '../domain/zoom_depth.dart';
import '../domain/zoom_facts.dart';
import '../domain/zoom_motion.dart';
import 'scenes/zoom_scene.dart';
import 'scenes/zoom_subject.dart';
import 'zoom_card.dart';
import 'zoom_inks.dart';
import 'zoom_painter.dart';

sealed class ZoomState {
  const ZoomState();
}

final class ZoomLoading extends ZoomState {
  const ZoomLoading();
}

/// The row does not say the `locus` track is ready: a state the screen
/// draws, in the row's own words, not a failure.
final class ZoomUnavailable extends ZoomState {
  const ZoomUnavailable(this.state, {this.reason});

  final TrackState state;
  final String? reason;
}

final class ZoomFailed extends ZoomState {
  const ZoomFailed(this.message);

  final String message;
}

final class ZoomReady extends ZoomState {
  const ZoomReady(this.track, this.record);

  final LocusTrack track;
  final GeneRecord record;
}

/// One protein's locus track, and its record for the gene's parts and first
/// bases, both through the app's tracks, the walk's own.
class ZoomCubit extends Cubit<ZoomState> {
  ZoomCubit(this.target, this._tracks, this._fetchGene)
    : super(const ZoomLoading());

  final ProteinTarget target;
  final TrackSource _tracks;
  final FetchGene _fetchGene;

  Future<void> load() async {
    const TrackKind kind = TrackKind.locus;
    final TrackState state = target.state(kind);
    if (state != TrackState.ready) {
      emit(ZoomUnavailable(state, reason: target.reason(kind)));
      return;
    }
    emit(const ZoomLoading());
    try {
      final LocusTrack track = await LocusTrack.load(target, tracks: _tracks);
      final GeneRecord record = await _fetchGene(target.query);
      if (!isClosed) {
        emit(ZoomReady(track, record));
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(ZoomFailed(error.userMessage));
      }
    } on Object {
      if (!isClosed) {
        emit(ZoomFailed(const UnknownApiException().userMessage));
      }
    }
  }
}

/// The zoom's header, at the walk's own height: the zoom opens over the
/// walk's gene page, and a header of another height resized the chrome under
/// the reader on the way in and again on the way back. Its title's type is
/// held where the walk holds its own, since the bar does not grow with it.
///
/// With no [target] it has no title: the wait for a protein's row, before
/// there is a name to head it with.
AppBar _zoomBar([ProteinTarget? target]) => AppBar(
  toolbarHeight: ZoomScreen.headerHeight,
  title: target == null
      ? null
      : MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Text(ZoomScreen.titleOf(target)),
        ),
);

/// `/zoom/<slug>`: from a body down to one protein's DNA.
class ZoomRoute extends StatelessWidget {
  const ZoomRoute({required this.slug, this.overWalk = false, super.key});

  final String slug;

  /// Whether the walk is the page under this one: see [ZoomScreen.overWalk].
  final bool overWalk;

  @override
  Widget build(BuildContext context) => _TargetLoader(
    slug: slug,
    builder: (BuildContext context, ProteinTarget target) =>
        BlocProvider<ZoomCubit>(
          create: (BuildContext context) => ZoomCubit(
            target,
            context.read<TrackSource>(),
            context.read<FetchGene>(),
          )..load(),
          child: BlocBuilder<ZoomCubit, ZoomState>(
            builder: (BuildContext context, ZoomState state) => switch (state) {
              ZoomLoading() => Scaffold(
                appBar: _zoomBar(target),
                body: LoadingView(
                  label: 'LOADING ${target.slug.toUpperCase()}',
                ),
              ),
              ZoomFailed(:final String message) => Scaffold(
                appBar: _zoomBar(target),
                body: ErrorView(
                  title: 'Fetch failed',
                  message: message,
                  onRetry: () => context.read<ZoomCubit>().load(),
                ),
              ),
              ZoomUnavailable(:final TrackState state, :final String? reason) =>
                Scaffold(
                  appBar: _zoomBar(target),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      child: Text(
                        ZoomScreen.unavailable(state, reason),
                        key: const ValueKey<String>('zoom-unavailable'),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ZoomReady(:final LocusTrack track, :final GeneRecord record) =>
                ZoomScreen(
                  key: ValueKey<String>(target.slug),
                  target: target,
                  track: track,
                  record: record,
                  overWalk: overWalk,
                ),
            },
          ),
        ),
  );
}

/// Resolves a slug to its catalog row, then builds [builder] with it.
///
/// The lab's `LabTargetLoader`, kept here as the zoom's own since it left the
/// lab: a deep link can arrive before the catalog, or name a protein outside
/// it, and both are answered by asking the repository for the one protein.
class _TargetLoader extends StatefulWidget {
  const _TargetLoader({required this.slug, required this.builder});

  final String slug;
  final Widget Function(BuildContext context, ProteinTarget target) builder;

  @override
  State<_TargetLoader> createState() => _TargetLoaderState();
}

class _TargetLoaderState extends State<_TargetLoader> {
  ProteinTarget? _target;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _target = context.read<ProteinCatalogRepository>().bySlug(widget.slug);
    if (_target == null) {
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    final ProteinCatalogRepository catalog = context
        .read<ProteinCatalogRepository>();
    try {
      final ProteinTarget target = await catalog.protein(widget.slug);
      if (mounted) {
        setState(() => _target = target);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProteinTarget? target = _target;
    if (target != null) {
      return widget.builder(context, target);
    }
    final Object? error = _error;
    if (error == null) {
      // Under the header's own height, which it has no name to fill yet: the
      // label sat under the status bar, and moved when a header arrived.
      return Scaffold(
        appBar: _zoomBar(),
        body: SafeArea(
          child: LoadingView(label: 'LOADING ${widget.slug.toUpperCase()}'),
        ),
      );
    }
    return Scaffold(
      appBar: _zoomBar(),
      body: ErrorView(
        title: 'Fetch failed',
        message: error is ApiException
            ? error.userMessage
            : const UnknownApiException().userMessage,
        onRetry: () {
          setState(() => _error = null);
          unawaited(_resolve());
        },
      ),
    );
  }
}

/// What the zoom is doing between frames.
enum _Motion { idle, pinch, flight, settle, exit }

/// One continuous dive from a body down to a gene's DNA.
///
/// Nine stops (body, organ, tissue, cell, nucleus, chromosome, band, gene,
/// DNA) on one depth. The card's buttons step from one to the next, a step
/// asked for mid-flight carrying straight on; a pinch moves through all of
/// them without a break and a flick coasts to the stop it would reach. The
/// card names the stop and says one thing that is known of it. The organ
/// and the cell are the path the bake chose from the Human Protein Atlas's
/// reading, one that lives in the other; the chromosome, the band, the gene
/// and its first bases are data. At the DNA, the walk is offered, from its
/// start: the one it was opened from, where there is one.
class ZoomScreen extends StatefulWidget {
  const ZoomScreen({
    required this.target,
    required this.track,
    required this.record,
    this.overWalk = false,
    this.initialDepth = 0,
    super.key,
  });

  final ProteinTarget target;
  final LocusTrack track;
  final GeneRecord record;

  /// Whether the walk is the page under this one, opened from its gene page.
  /// "Walk ›" then goes back to that walk, as the reader left it, where it
  /// would otherwise open a second one above the zoom.
  final bool overWalk;

  /// Where the zoom opens: at the body, but for a render check that frames
  /// a moment between two stops.
  @visibleForTesting
  final double initialDepth;

  static String titleOf(ProteinTarget target) => 'Zoom · ${target.display}';

  /// The header's row, the walk's and search's own.
  static const double headerHeight = 44;

  /// What the screen says where the row has no locus for it.
  static String unavailable(TrackState state, String? reason) =>
      switch (state) {
        TrackState.pending => 'Where its gene lies is on its way.',
        TrackState.refused =>
          'Where its gene lies is not published: '
              '${reason ?? 'the pipeline declined'}.',
        TrackState.absent ||
        TrackState.ready => 'Where its gene lies is not published yet.',
      };

  /// What each stop is called.
  static String nameOf(ZoomStop stop) => switch (stop) {
    ZoomStop.body => 'Body',
    ZoomStop.organ => 'Organ',
    ZoomStop.tissue => 'Tissue',
    ZoomStop.cell => 'Cell',
    ZoomStop.nucleus => 'Nucleus',
    ZoomStop.chromosome => 'Chromosome',
    ZoomStop.band => 'Band',
    ZoomStop.gene => 'Gene',
    ZoomStop.dna => 'DNA',
  };

  /// How much depth a pinch moves for each tenfold spread of the fingers.
  static const double pinchGain = 2.5;

  @override
  State<ZoomScreen> createState() => _ZoomScreenState();
}

class _ZoomScreenState extends State<ZoomScreen> with TickerProviderStateMixin {
  late final ZoomSubject _subject = ZoomSubject(
    track: widget.track,
    record: widget.record,
  );
  late final ZoomStage _stage = ZoomStage(_subject);
  late final ZoomFacts _facts = ZoomFacts(
    track: widget.track,
    path: _subject.path,
    record: widget.record,
  );
  late final ValueNotifier<double> _depth = ValueNotifier<double>(
    widget.initialDepth,
  );
  late final ValueNotifier<ZoomStop> _stop = ValueNotifier<ZoomStop>(
    _d.nearest(widget.initialDepth),
  );
  late final Ticker _ticker = createTicker(_tick);

  /// Seconds of ambient time, for what moves at rest: a helix turning,
  /// vesicles leaving a cell, the beats a stop plays as it is reached. It
  /// runs only while something on screen wants it and motion is allowed.
  final ValueNotifier<double> _ambient = ValueNotifier<double>(0);
  late final Ticker _ambientTicker = createTicker(_tickAmbient);

  /// The ambient time the clock had reached when its ticker last started.
  double _ambientFrom = 0;

  /// The ambient time at which the depth last came to rest at a stop.
  double _restedAt = 0;

  /// How far the helix is unzipped as the walk opens.
  final ValueNotifier<double> _unzip = ValueNotifier<double>(0);

  /// How long the helix takes to unzip into the walk's rows.
  static const Duration _unzipping = Duration(milliseconds: 450);

  _Motion _motion = _Motion.idle;
  ZoomFlight? _flight;
  Simulation? _spring;
  double _springTarget = 0;

  /// How long the motion now running has run, for its speed when another
  /// step takes over from it.
  Duration _elapsed = Duration.zero;

  /// The stop the motion now running is bound for.
  ZoomStop? _bound;

  /// Whether the card's stop was last reached going deeper.
  bool _forward = true;

  double _pinchFrom = 0;
  double _pinchScale = 1;

  /// The canvas's size, as last laid out: the ambient clock asks the scenes
  /// on it whether they still move.
  Size _canvas = Size.zero;

  /// Whether the stop the zoom opens on is holding its beats until every
  /// scene has built what it caches: they play once the scenes are ready,
  /// or as soon as a step is taken.
  bool _opening = true;

  /// Whether the next scene's building is waiting for nothing to move.
  bool _warmArmed = false;

  ZoomDepth get _d => _subject.depth;

  @override
  void initState() {
    super.initState();
    _depth.addListener(_follow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion may have been turned on or off.
    _wake();
  }

  @override
  void dispose() {
    _depth.removeListener(_follow);
    _ticker.dispose();
    _ambientTicker.dispose();
    _depth.dispose();
    _stop.dispose();
    _ambient.dispose();
    _unzip.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  /// Keeps the card on the stop the depth is nearest, with a tick under the
  /// reader's finger each time a pinch crosses one.
  void _follow() {
    final ZoomStop nearest = _d.nearest(_depth.value);
    if (nearest != _stop.value) {
      _forward = nearest.index > _stop.value.index;
      _stop.value = nearest;
      if (_motion == _Motion.pinch || _motion == _Motion.idle) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
    _wake();
  }

  void _set(double d) => _depth.value = d.clamp(0.0, _d.total);

  /// Seconds since the depth last came to rest, as the scenes' beats read
  /// it: long past every beat where nothing moves on its own.
  double get _dwell =>
      _reduced ? ZoomFrame.settled : _ambient.value - _restedAt;

  /// The depth has come to rest at a stop: its beats play from now.
  void _rest() {
    _opening = false;
    _restedAt = _ambient.value;
    _wake();
    _warm();
  }

  /// Starts the ambient clock where something on screen moves on its own,
  /// and motion is allowed.
  void _wake() {
    if (!mounted ||
        _opening ||
        _ambientTicker.isActive ||
        _reduced ||
        _canvas.isEmpty) {
      return;
    }
    if (_stage.wantsClock(
      _depth.value,
      _canvas,
      ZoomInks.of(context),
      dwell: _dwell,
    )) {
      _ambientFrom = _ambient.value;
      unawaited(_ambientTicker.start());
    }
  }

  /// Builds what the scenes cache, nearest the zoom's stop first, one scene
  /// after each frame and only while nothing on screen moves, so that no
  /// step pays for its scenes' first frame and no frame waits for one.
  /// Something moving (the page coming up, a step, a beat) holds it until
  /// the frame after the last that moves.
  void _warm() {
    if (_warmArmed || !mounted) {
      return;
    }
    if (_stage.prepared) {
      if (_opening && !_moving) {
        _rest();
      }
      return;
    }
    _warmArmed = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _warmArmed = false;
      if (!mounted) {
        return;
      }
      if (!_moving) {
        final ZoomStop? next = _stage.unprepared(_d.nearest(_depth.value));
        if (next != null) {
          _stage.prepare(next, ZoomInks.of(context));
        }
      }
      _warm();
    });
    // While something moves its frames come anyway; at rest, one is asked
    // for.
    if (!_moving) {
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  /// Whether anything on screen moves: the depth, under a finger or on its
  /// own, or anything animating, the page itself coming up included.
  bool get _moving =>
      _motion != _Motion.idle ||
      SchedulerBinding.instance.transientCallbackCount > 0;

  /// Builds what the scenes between [stop] and the stop the depth is at
  /// cache, before a step there moves.
  void _prepareTo(ZoomStop stop) {
    final int here = _d.nearest(_depth.value).index;
    final ZoomInks inks = ZoomInks.of(context);
    for (
      int i = math.min(here, stop.index);
      i <= math.max(here, stop.index);
      i++
    ) {
      _stage.prepare(ZoomStop.values[i], inks);
    }
  }

  void _tickAmbient(Duration elapsed) {
    _ambient.value = _ambientFrom + elapsed.inMicroseconds / 1e6;
    if (_reduced ||
        !_stage.wantsClock(
          _depth.value,
          _canvas,
          ZoomInks.of(context),
          dwell: _dwell,
        )) {
      _ambientTicker.stop();
    }
  }

  void _run(_Motion motion) {
    _motion = motion;
    _elapsed = Duration.zero;
    _ticker.stop();
    _ticker.start();
  }

  /// How fast the depth is moving now, in depth a second.
  double get _velocity => switch (_motion) {
    _Motion.flight => _flight!.speedAt(_elapsed),
    _Motion.settle => _spring!.dx(_elapsed.inMicroseconds / 1e6),
    _ => 0,
  };

  void _halt() {
    if (_motion == _Motion.exit && _unzip.value < 1) {
      _unzip.value = 0;
    }
    _motion = _Motion.idle;
    _ticker.stop();
    _flight = null;
    _spring = null;
    _bound = null;
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    switch (_motion) {
      case _Motion.flight:
        final ZoomFlight flight = _flight!;
        _set(flight.at(elapsed));
        if (flight.doneAt(elapsed)) {
          _halt();
          _rest();
        }
      case _Motion.settle:
        final double t = elapsed.inMicroseconds / 1e6;
        final Simulation spring = _spring!;
        if (spring.isDone(t)) {
          _set(_springTarget);
          _halt();
          _rest();
        } else {
          _set(spring.x(t));
        }
      case _Motion.exit:
        _unzip.value = (elapsed.inMicroseconds / _unzipping.inMicroseconds)
            .clamp(0.0, 1.0);
        if (elapsed >= _unzipping) {
          _halt();
          _openWalk();
        }
      case _Motion.idle || _Motion.pinch:
        _ticker.stop();
    }
  }

  /// Flies to [stop] from wherever the depth is and as fast as it is going,
  /// or cuts there under reduced motion.
  void _goTo(ZoomStop stop) {
    final double velocity = _velocity;
    _halt();
    final double target = _d.depthOf(stop);
    if (_reduced || (target - _depth.value).abs() < 1e-9) {
      _set(target);
      _rest();
      return;
    }
    _prepareTo(stop);
    _flight = ZoomFlight(
      _depth.value,
      target,
      velocity: velocity,
      minimum: _d.leastFlight(_depth.value, target),
      cruise: _d.cruiseOf(_depth.value, target),
    );
    _bound = stop;
    _run(_Motion.flight);
  }

  /// One stop on from the one the zoom is at, or is bound for.
  void _step(int by) {
    final ZoomStop from = _bound ?? _d.nearest(_depth.value);
    final int next = (from.index + by).clamp(0, ZoomStop.values.length - 1);
    _goTo(ZoomStop.values[next]);
  }

  /// Comes to rest on [stop] from the depth now, moving at [velocity].
  void _settle(ZoomStop stop, double velocity) {
    final double target = _d.depthOf(stop);
    if (_reduced) {
      _halt();
      _set(target);
      _rest();
      return;
    }
    _spring = SpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: 140),
      _depth.value,
      target,
      velocity,
    );
    _springTarget = target;
    _bound = stop;
    _run(_Motion.settle);
  }

  void _pinchStart(ScaleStartDetails details) {
    _halt();
    final int here = _d.nearest(_depth.value).index;
    _prepareTo(ZoomStop.values[math.max(here - 2, 0)]);
    _prepareTo(ZoomStop.values[math.min(here + 2, ZoomStop.values.length - 1)]);
    _motion = _Motion.pinch;
    _pinchFrom = _depth.value;
    _pinchScale = 1;
  }

  void _pinchUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || details.scale <= 0) {
      return;
    }
    final double d =
        _pinchFrom + ZoomScreen.pinchGain * math.log(details.scale) / math.ln10;
    _pinchScale = details.scale;
    _set(d);
  }

  void _pinchEnd(ScaleEndDetails details) {
    if (_motion != _Motion.pinch) {
      return;
    }
    _motion = _Motion.idle;
    // The recognizer's own velocity of the spread, in the depth's terms:
    // depth moves by the gain for each tenfold spread.
    final double spread = details.scaleVelocity;
    final double velocity = spread.isFinite && spread != -1
        ? ZoomScreen.pinchGain *
              spread /
              (math.max(_pinchScale, 1e-3) * math.ln10)
        : 0;
    _settle(flingTarget(_d, _depth.value, velocity), velocity);
  }

  /// Unzips the helix into the walk's rows, then opens the walk at the gene.
  void _walk() {
    _halt();
    if (_reduced) {
      _openWalk();
      return;
    }
    _run(_Motion.exit);
  }

  void _openWalk() {
    // Back to the walk this was opened from. A link that only says so, with
    // no page under it, opens the walk like any other.
    if (widget.overWalk && context.canPop()) {
      context.pop();
      return;
    }
    unawaited(
      context.push(RoutePaths.geneFor(widget.target)).then((_) {
        if (mounted) {
          _unzip.value = 0;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle labels =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 12);
    final ZoomInks inks = ZoomInks.of(context);
    return Scaffold(
      appBar: _zoomBar(widget.target),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final Size canvas = box.biggest;
                  if (canvas != _canvas) {
                    _canvas = canvas;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _wake();
                      _warm();
                    });
                  }
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _pinchStart,
                    onScaleUpdate: _pinchUpdate,
                    onScaleEnd: _pinchEnd,
                    onDoubleTap: () => _step(1),
                    child: ValueListenableBuilder<ZoomStop>(
                      valueListenable: _stop,
                      builder:
                          (BuildContext context, ZoomStop stop, Widget? c) =>
                              Semantics(
                                label:
                                    'A zoom from a body to its DNA, at the '
                                    '${ZoomScreen.nameOf(stop).toLowerCase()}. '
                                    'Step with the buttons below, or pinch.',
                                child: c,
                              ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          RepaintBoundary(
                            child: CustomPaint(
                              key: const ValueKey<String>('zoom-canvas'),
                              size: Size.infinite,
                              painter: ZoomPainter(
                                stage: _stage,
                                at: () => _depth.value,
                                unzip: () => _unzip.value,
                                inks: inks,
                                labels: labels,
                                repaint: Listenable.merge(<Listenable>[
                                  _depth,
                                  _unzip,
                                ]),
                              ),
                            ),
                          ),
                          RepaintBoundary(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: ZoomOverlayPainter(
                                stage: _stage,
                                at: () => _depth.value,
                                clock: () => _reduced ? 0 : _ambient.value,
                                dwell: () => _dwell,
                                unzip: () => _unzip.value,
                                inks: inks,
                                labels: labels,
                                caption: theme.caption ?? labels,
                                credit: _facts.credit,
                                repaint: Listenable.merge(<Listenable>[
                                  _depth,
                                  _ambient,
                                  _unzip,
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ValueListenableBuilder<ZoomStop>(
              valueListenable: _stop,
              builder: (BuildContext context, ZoomStop stop, Widget? _) =>
                  ZoomCard(
                    facts: _facts,
                    stop: stop,
                    nameOf: ZoomScreen.nameOf,
                    forward: _forward,
                    onPrevious: () => _step(-1),
                    onNext: () => _step(1),
                    onWalk: _walk,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
