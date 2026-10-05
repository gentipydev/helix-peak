import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/anatomy/sequence_scrubber.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../../presentation/lab_protein_picker.dart';
import '../domain/locus_track.dart';
import '../domain/zoom_depth.dart';
import '../domain/zoom_facts.dart';
import '../domain/zoom_motion.dart';
import 'scenes/zoom_subject.dart';
import 'zoom_about.dart';
import 'zoom_card.dart';
import 'zoom_inks.dart';
import 'zoom_painter.dart';
import 'zoom_rail.dart';

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
/// bases, both through the lab's own tracks.
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

/// `/lab/zoom/<slug>`: from a body down to one protein's DNA.
class ZoomRoute extends StatelessWidget {
  const ZoomRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) => LabTargetLoader(
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
                appBar: AppBar(title: Text(ZoomScreen.titleOf(target))),
                body: LoadingView(
                  label: 'LOADING ${target.slug.toUpperCase()}',
                ),
              ),
              ZoomFailed(:final String message) => Scaffold(
                appBar: AppBar(title: Text(ZoomScreen.titleOf(target))),
                body: ErrorView(
                  title: 'Fetch failed',
                  message: message,
                  onRetry: () => context.read<ZoomCubit>().load(),
                ),
              ),
              ZoomUnavailable(:final TrackState state, :final String? reason) =>
                Scaffold(
                  appBar: AppBar(title: Text(ZoomScreen.titleOf(target))),
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
                ),
            },
          ),
        ),
  );
}

/// What the zoom is doing between frames.
enum _Motion { idle, pinch, flight, settle, play, exit }

/// One continuous dive from a body down to a gene's DNA.
///
/// Nine stops (body, organ, tissue, cell, nucleus, chromosome, band, gene,
/// DNA) on one depth, so a pinch moves through all of them without a break
/// and a flick coasts to the stop it would reach. The rail down the right
/// edge scrubs the depth; the card below names the stop, says one thing that
/// is known of it and where that comes from, and steps or plays the dive.
/// The organ and the cell are the path the bake chose from the Human Protein
/// Atlas's reading, one that lives in the other; the chromosome, the band,
/// the gene and its first bases are data. At the DNA, the walk is offered,
/// from its start.
class ZoomScreen extends StatefulWidget {
  const ZoomScreen({
    required this.target,
    required this.track,
    required this.record,
    this.initialDepth = 0,
    super.key,
  });

  final ProteinTarget target;
  final LocusTrack track;
  final GeneRecord record;

  /// Where the zoom opens: at the body, but for a render check that frames
  /// a moment between two stops.
  @visibleForTesting
  final double initialDepth;

  static String titleOf(ProteinTarget target) => 'Zoom · ${target.display}';

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

class _ZoomScreenState extends State<ZoomScreen>
    with TickerProviderStateMixin {
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

  /// Seconds of ambient time, for the helix's slow turn: it runs only while
  /// the DNA is near and motion is allowed.
  final ValueNotifier<double> _ambient = ValueNotifier<double>(0);
  late final Ticker _ambientTicker = createTicker(
    (Duration elapsed) => _ambient.value = elapsed.inMicroseconds / 1e6,
  );

  /// How far the helix is unzipped as the walk opens.
  final ValueNotifier<double> _unzip = ValueNotifier<double>(0);

  /// How long the helix takes to unzip into the walk's rows.
  static const Duration _unzipping = Duration(milliseconds: 450);

  _Motion _motion = _Motion.idle;
  ZoomFlight? _flight;
  Simulation? _spring;
  double _springTarget = 0;
  PlaySchedule? _play;

  double _pinchFrom = 0;
  double _pinchScale = 1;

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
    _ambience(_stop.value);
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
  /// reader's finger each time a pinch or a scrub crosses one.
  void _follow() {
    final ZoomStop nearest = _d.nearest(_depth.value);
    if (nearest == _stop.value) {
      return;
    }
    _stop.value = nearest;
    _ambience(nearest);
    if (_motion == _Motion.pinch || _motion == _Motion.idle) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _set(double d) => _depth.value = d.clamp(0.0, _d.total);

  /// Runs the ambient clock while the cell or the DNA is near, for the
  /// vesicles a cell secretes and the helix's turn, and only where motion is
  /// allowed.
  void _ambience(ZoomStop nearest) {
    final bool wanted =
        (nearest == ZoomStop.dna || nearest == ZoomStop.cell) && !_reduced;
    if (wanted && !_ambientTicker.isActive) {
      unawaited(_ambientTicker.start());
    } else if (!wanted && _ambientTicker.isActive) {
      _ambientTicker.stop();
    }
  }

  void _run(_Motion motion) {
    _motion = motion;
    _ticker.stop();
    _ticker.start();
  }

  void _halt() {
    if (_motion == _Motion.exit && _unzip.value < 1) {
      _unzip.value = 0;
    }
    final bool wasPlaying = _motion == _Motion.play;
    _motion = _Motion.idle;
    _ticker.stop();
    _flight = null;
    _spring = null;
    _play = null;
    if (wasPlaying && mounted) {
      setState(() {});
    }
  }

  void _tick(Duration elapsed) {
    switch (_motion) {
      case _Motion.flight:
        final ZoomFlight flight = _flight!;
        _set(flight.at(elapsed));
        if (flight.doneAt(elapsed)) {
          _halt();
        }
      case _Motion.settle:
        final double t = elapsed.inMicroseconds / 1e6;
        final Simulation spring = _spring!;
        if (spring.isDone(t)) {
          _set(_springTarget);
          _halt();
        } else {
          _set(spring.x(t));
        }
      case _Motion.play:
        final PlaySchedule play = _play!;
        _set(play.at(elapsed));
        if (play.doneAt(elapsed)) {
          _halt();
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

  /// Flies to [stop], or cuts there under reduced motion.
  void _goTo(ZoomStop stop) {
    _halt();
    final double target = _d.depthOf(stop);
    if (_reduced) {
      _set(target);
      return;
    }
    _flight = ZoomFlight(_depth.value, target);
    _run(_Motion.flight);
  }

  void _step(int by) {
    final int next = (_d.nearest(_depth.value).index + by).clamp(
      0,
      ZoomStop.values.length - 1,
    );
    _goTo(ZoomStop.values[next]);
  }

  /// Comes to rest on [stop] from the depth now, moving at [velocity].
  void _settle(ZoomStop stop, double velocity) {
    final double target = _d.depthOf(stop);
    if (_reduced) {
      _halt();
      _set(target);
      return;
    }
    _spring = SpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: 140),
      _depth.value,
      target,
      velocity,
    );
    _springTarget = target;
    _run(_Motion.settle);
  }

  void _togglePlay() {
    if (_motion == _Motion.play) {
      _halt();
      return;
    }
    _halt();
    if (_depth.value >= _d.total - 1e-6) {
      _set(0);
    }
    _play = PlaySchedule(_d, from: _depth.value, stepped: _reduced);
    _run(_Motion.play);
    setState(() {});
  }

  void _pinchStart(ScaleStartDetails details) {
    _halt();
    _motion = _Motion.pinch;
    _pinchFrom = _depth.value;
    _pinchScale = 1;
  }

  void _pinchUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || details.scale <= 0) {
      return;
    }
    final double d =
        _pinchFrom +
        ZoomScreen.pinchGain * math.log(details.scale) / math.ln10;
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

  void _scrub(double d) {
    if (_motion != _Motion.pinch) {
      _halt();
    }
    _set(d);
  }

  void _released() {
    if (_motion == _Motion.idle) {
      _settle(_d.nearest(_depth.value), 0);
    }
  }

  void _touched(PointerDownEvent event) {
    if (_motion == _Motion.play) {
      _halt();
    }
  }

  void _about() {
    _halt();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext context) => ZoomAbout(facts: _facts),
      ),
    );
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
      appBar: AppBar(title: Text(ZoomScreen.titleOf(widget.target))),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: _touched,
                      child: GestureDetector(
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
                                        'Pinch, drag the depth rail, or step '
                                        'with the buttons below.',
                                    child: c,
                                  ),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              key: const ValueKey<String>('zoom-canvas'),
                              size: Size.infinite,
                              painter: ZoomPainter(
                                stage: _stage,
                                at: () => _depth.value,
                                clock: () => _ambient.value,
                                unzip: () => _unzip.value,
                                inks: inks,
                                labels: labels,
                                repaint: Listenable.merge(<Listenable>[
                                  _depth,
                                  _ambient,
                                  _unzip,
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // A dark strip under the rail, so its ticks and thumb read
                  // over the brightest field, a slide under the lamp.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: SequenceScrubber.width,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              theme.colorScheme.surface.withValues(alpha: 0),
                              theme.colorScheme.surface.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    right: 0,
                    width: SequenceScrubber.width,
                    child: ZoomRail(
                      depth: _d,
                      value: _depth,
                      nameOf: ZoomScreen.nameOf,
                      onScrub: _scrub,
                      onRelease: _released,
                      onStep: _step,
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<ZoomStop>(
              valueListenable: _stop,
              builder: (BuildContext context, ZoomStop stop, Widget? _) =>
                  ZoomCard(
                    facts: _facts,
                    stop: stop,
                    nameOf: ZoomScreen.nameOf,
                    playing: _motion == _Motion.play,
                    onPrevious: () => _step(-1),
                    onNext: () => _step(1),
                    onPlay: _togglePlay,
                    onAbout: _about,
                    onWalk: _walk,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
