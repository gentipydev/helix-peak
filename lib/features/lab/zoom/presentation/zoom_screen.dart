import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../../presentation/lab_protein_picker.dart';
import '../domain/locus_track.dart';
import '../domain/zoom_captions.dart';
import '../domain/zoom_path.dart';
import '../domain/zoom_scale.dart';
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

/// One protein's locus track, and its record for the gene's first bases,
/// both through the lab's own tracks.
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

/// `/lab/zoom/<slug>`: from a body down to one protein's gene.
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
                  bases: record.sequence,
                ),
            },
          ),
        ),
  );
}

/// One continuous pinch from a body down to a gene.
///
/// Seven levels (body, organ, tissue, cell, nucleus, chromosome, gene) on one
/// value whose logarithm is the view's width, so a pinch moves through all of
/// them without a break, and lets go at the nearest. A chip for each level
/// goes straight there. The organ and the cell are the Human Protein Atlas's
/// reading of where the gene is read; where the cells it names have no
/// nucleus the zoom lands in the precursor that has one, and the caption says
/// so. The chromosome is the locus track's, the gene's band marked on it; the
/// gene, its record's first bases. At the gene, the walk is offered, from its
/// start.
class ZoomScreen extends StatefulWidget {
  const ZoomScreen({
    required this.target,
    required this.track,
    required this.bases,
    super.key,
  });

  final ProteinTarget target;
  final LocusTrack track;

  /// The gene's letters, 5' to 3', as its record holds them.
  final String bases;

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

  /// What each level's chip says.
  static String nameOf(ZoomLevel level) => switch (level) {
    ZoomLevel.body => 'Body',
    ZoomLevel.organ => 'Organ',
    ZoomLevel.tissue => 'Tissue',
    ZoomLevel.cell => 'Cell',
    ZoomLevel.nucleus => 'Nucleus',
    ZoomLevel.chromosome => 'Chromosome',
    ZoomLevel.gene => 'Gene',
  };

  @override
  State<ZoomScreen> createState() => _ZoomScreenState();
}

class _ZoomScreenState extends State<ZoomScreen>
    with SingleTickerProviderStateMixin {
  late final ZoomScale _scale = ZoomScale(widget.track);
  late final ZoomCaptions _captions = ZoomCaptions(widget.track);
  late final ZoomPath _path = ZoomPath.of(widget.track);
  final ValueNotifier<double> _zoom = ValueNotifier<double>(0);
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Animation<double>? _towards;
  double _pinchFrom = 0;

  /// Each level's chip, to keep the one the zoom is nearest in view: the row
  /// is wider than a phone.
  final Map<ZoomLevel, GlobalKey> _chips = <ZoomLevel, GlobalKey>{
    for (final ZoomLevel level in ZoomLevel.values) level: GlobalKey(),
  };
  ZoomLevel _shown = ZoomLevel.body;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      final Animation<double>? towards = _towards;
      if (towards != null) {
        _zoom.value = towards.value;
      }
    });
    _zoom.addListener(_follow);
  }

  @override
  void dispose() {
    _zoom.removeListener(_follow);
    _snap.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// Scrolls the chip row to the level the zoom has come nearest, once the
  /// frame that selects it is laid out.
  void _follow() {
    final ZoomLevel level = _level;
    if (level == _shown) {
      return;
    }
    _shown = level;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? chip = _chips[level]?.currentContext;
      if (!mounted || chip == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          chip,
          alignment: 0.5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  ZoomLevel get _level => _scale.nearest(_zoom.value);

  void _goTo(ZoomLevel level) {
    final double target = _scale.zoomOf(level);
    if (MediaQuery.disableAnimationsOf(context)) {
      _snap.stop();
      _zoom.value = target;
      return;
    }
    _towards = Tween<double>(
      begin: _zoom.value,
      end: target,
    ).animate(CurvedAnimation(parent: _snap, curve: Curves.easeInOutCubic));
    _snap
      ..reset()
      ..forward();
  }

  void _pinchStart(ScaleStartDetails details) {
    _snap.stop();
    _pinchFrom = _zoom.value;
  }

  void _pinchUpdate(ScaleUpdateDetails details) {
    if (details.scale == 1) {
      return;
    }
    // Spreading two fingers by a factor narrows the view by it.
    _zoom.value = _scale.zoomAt(_scale.widthAt(_pinchFrom) / details.scale);
  }

  void _pinchEnd(ScaleEndDetails details) => _goTo(_level);

  void _deeper() {
    final int next = (_level.index + 1).clamp(0, ZoomLevel.values.length - 1);
    _goTo(ZoomLevel.values[next]);
  }

  /// The tallest caption's height, set in [style] at [width]: the box every
  /// level's caption is given, so none is cut short and the canvas keeps its
  /// size as the zoom moves from one level to the next.
  double _tallest(BuildContext context, TextStyle style, double width) {
    double tallest = 0;
    for (final ZoomLevel level in ZoomLevel.values) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: _captions.captionOf(level), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return tallest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle labels =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    final TextStyle? note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: Text(ZoomScreen.titleOf(widget.target))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final TextStyle caption = DefaultTextStyle.of(context).style
                .merge(theme.textTheme.bodyMedium);
            // Every caption fits its box whole. Only at a text size that
            // would take more than a third of the screen does the box scroll.
            final double box = math.min(
              _tallest(
                context,
                caption,
                constraints.maxWidth - 2 * AppSpacing.screenPadding,
              ),
              constraints.maxHeight / 3,
            );
            return ValueListenableBuilder<double>(
              valueListenable: _zoom,
              builder: (BuildContext context, double zoom, Widget? canvas) {
                final ZoomLevel level = _scale.nearest(zoom);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Semantics(
                        label:
                            'A zoom from a body to a gene, at the '
                            '${ZoomScreen.nameOf(level).toLowerCase()}. '
                            'Pinch, or pick a level below.',
                        child: canvas,
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                      ),
                      child: Row(
                        children: <Widget>[
                          for (final ZoomLevel l in ZoomLevel.values)
                            Padding(
                              key: _chips[l],
                              padding: const EdgeInsets.only(
                                right: AppSpacing.xs,
                              ),
                              child: ChoiceChip(
                                key: ValueKey<String>('zoom-level-${l.name}'),
                                label: Text(ZoomScreen.nameOf(l)),
                                selected: l == level,
                                onSelected: (_) => _goTo(l),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.sm,
                        AppSpacing.screenPadding,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SizedBox(
                            key: const ValueKey<String>('zoom-caption-box'),
                            height: box,
                            child: SingleChildScrollView(
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _captions.captionOf(level),
                                  key: const ValueKey<String>('zoom-caption'),
                                  style: caption,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _captions.sources,
                            key: const ValueKey<String>('zoom-sources'),
                            style: note,
                          ),
                          if (level == ZoomLevel.gene) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            FilledButton(
                              key: const ValueKey<String>('zoom-walk'),
                              onPressed: () => context.push(
                                RoutePaths.geneFor(widget.target),
                              ),
                              child: const Text('Open the walk, from its gene'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _pinchStart,
                onScaleUpdate: _pinchUpdate,
                onScaleEnd: _pinchEnd,
                onDoubleTap: _deeper,
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey<String>('zoom-canvas'),
                    size: Size.infinite,
                    painter: ZoomPainter(
                      scale: _scale,
                      path: _path,
                      bases: widget.bases,
                      at: () => _zoom.value,
                      inks: ZoomInks.of(context),
                      labels: labels,
                      repaint: _zoom,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
