import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/catalog/protein_track.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/anatomy/anatomy_scene.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/anatomy/anatomy_tracer.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../gene_lookup/domain/usecases/fetch_gene.dart';
import '../../mutate/presentation/edit_ripple.dart';
import '../../presentation/lab_anatomy_view.dart';
import '../../presentation/lab_protein_picker.dart';
import '../domain/audio_track.dart';
import '../domain/dna_score.dart';
import '../domain/dna_voice.dart';
import '../domain/listen_captions.dart';
import '../domain/playhead.dart';
import 'listen_about.dart';
import 'listen_player.dart';

sealed class ListenState {
  const ListenState();
}

final class ListenLoading extends ListenState {
  const ListenLoading();
}

final class ListenFailed extends ListenState {
  const ListenFailed(this.message);

  final String message;
}

/// The record, always; the protein's own track where its row says it is
/// ready, and otherwise the row's state, which the screen says in words.
final class ListenReady extends ListenState {
  const ListenReady({
    required this.record,
    required this.track,
    required this.audioState,
    this.audioReason,
  });

  final GeneRecord record;
  final AudioTrack? track;
  final TrackState audioState;
  final String? audioReason;
}

/// One protein's record and its `audio` track, both through the lab's own
/// tracks. The track is fetched only where the row says it is ready: an
/// unpublished track is a state, and DNA mode needs only the record. A ready
/// track that fails to arrive is a failure.
class ListenCubit extends Cubit<ListenState> {
  ListenCubit(this.target, this._tracks, this._fetchGene)
    : super(const ListenLoading());

  final ProteinTarget target;
  final TrackSource _tracks;
  final FetchGene _fetchGene;

  Future<void> load() async {
    emit(const ListenLoading());
    const TrackKind kind = TrackKind.audio;
    final TrackState state = target.state(kind);
    try {
      final GeneRecord record = await _fetchGene(target.query);
      final AudioTrack? track = state == TrackState.ready
          ? await AudioTrack.load(target, tracks: _tracks)
          : null;
      if (!isClosed) {
        emit(
          ListenReady(
            record: record,
            track: track,
            audioState: state,
            audioReason: target.reason(kind),
          ),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(ListenFailed(error.userMessage));
      }
    } on Object {
      if (!isClosed) {
        emit(ListenFailed(const UnknownApiException().userMessage));
      }
    }
  }
}

/// `/lab/listen/<slug>`: a protein as sound.
class ListenRoute extends StatelessWidget {
  const ListenRoute({required this.slug, this.player, super.key});

  final String slug;

  /// The player to play through; the platform's own where null.
  final ListenPlayerFactory? player;

  @override
  Widget build(BuildContext context) => LabTargetLoader(
    slug: slug,
    builder: (BuildContext context, ProteinTarget target) =>
        BlocProvider<ListenCubit>(
          create: (BuildContext context) => ListenCubit(
            target,
            context.read<TrackSource>(),
            context.read<FetchGene>(),
          )..load(),
          child: BlocBuilder<ListenCubit, ListenState>(
            builder: (BuildContext context, ListenState state) =>
                switch (state) {
                  ListenLoading() => Scaffold(
                    appBar: AppBar(title: Text(ListenScreen.titleOf(target))),
                    body: LoadingView(
                      label: 'LOADING ${target.slug.toUpperCase()}',
                    ),
                  ),
                  ListenFailed(:final String message) => Scaffold(
                    appBar: AppBar(title: Text(ListenScreen.titleOf(target))),
                    body: ErrorView(
                      title: 'Fetch failed',
                      message: message,
                      onRetry: () => context.read<ListenCubit>().load(),
                    ),
                  ),
                  ListenReady() => ListenScreen(
                    key: ValueKey<String>(target.slug),
                    target: target,
                    record: state.record,
                    track: state.track,
                    audioState: state.audioState,
                    audioReason: state.audioReason,
                    player: player ?? platformListenPlayer,
                  ),
                },
          ),
        ),
  );
}

/// What Listen plays.
enum ListenMode {
  /// The protein's own track: a note a residue.
  protein,

  /// DNA mode: the gene from its start codon to its stop, a chord a codon,
  /// its introns a rustle.
  gene,

  /// DNA mode spliced: the codons alone, as the mRNA carries them.
  mrna,
}

/// A protein as sound, with the walk's own grid under it and a playhead that
/// follows the player.
///
/// Three things to hear. The protein: its baked track, one note a residue,
/// over its protein page. Its gene: a chord a codon and a rustle an intron
/// base, over the gene page. Its mRNA: the same codons spliced, over the
/// transcript page, which the grid reaches by the walk's own splicing when
/// the reader goes there from the gene.
///
/// The highlight is the walk's traced ring on the note sounding now, and it
/// moves only when the player reports a position ([ListenPlayer.positions]):
/// a position goes through the piece's timing map ([noteAt]) and the ring
/// goes to that note. Nothing here keeps time.
///
/// For a reader who cannot hear it: the mapping is announced as a piece is
/// shown, the piece is described in words below the controls, every control
/// is a labelled button, and a paused or stepped-to note says what it is, as
/// a live region.
class ListenScreen extends StatefulWidget {
  const ListenScreen({
    required this.target,
    required this.record,
    this.track,
    this.audioState = TrackState.absent,
    this.audioReason,
    this.player = platformListenPlayer,
    super.key,
  });

  final ProteinTarget target;
  final GeneRecord record;

  /// The protein's own track, or null where its row says it is not ready.
  final AudioTrack? track;
  final TrackState audioState;
  final String? audioReason;

  final ListenPlayerFactory player;

  static String titleOf(ProteinTarget target) => 'Listen · ${target.display}';

  /// What the screen says where the protein's own track is not ready.
  static String unavailable(TrackState state, String? reason) =>
      switch (state) {
        TrackState.pending => 'The protein’s own sound is on its way.',
        TrackState.refused =>
          'The protein’s own sound is not published: '
              '${reason ?? 'the pipeline declined'}.',
        TrackState.absent ||
        TrackState.ready => 'The protein’s own sound is not published yet.',
      };

  /// What each mode's segment says.
  static String nameOf(ListenMode mode) => switch (mode) {
    ListenMode.protein => 'Protein',
    ListenMode.gene => 'Gene',
    ListenMode.mrna => 'mRNA',
  };

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen>
    with WidgetsBindingObserver {
  late final ListenPlayer _player = widget.player();
  late final AnatomyModel _model = AnatomyModel.derive(
    widget.record,
    chain: widget.target.chain,
  );
  late final String? _dnaRefusal = DnaScore.refusal(_model);
  late final DnaScore? _gene = _dnaRefusal == null
      ? DnaScore.of(_model, spliced: false)
      : null;
  late final DnaScore? _mrna = _dnaRefusal == null
      ? DnaScore.of(_model, spliced: true)
      : null;
  late ListenMode _mode = widget.track != null
      ? ListenMode.protein
      : ListenMode.gene;

  /// The note sounding, the player's position and whether it is playing:
  /// each read by only what shows it, so a position reported every frame
  /// moves the slider without redrawing the grid.
  final ValueNotifier<int> _note = ValueNotifier<int>(0);
  final ValueNotifier<Duration> _position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<bool> _playing = ValueNotifier<bool>(false);

  final ScrollController _scroll = ScrollController();
  final List<StreamSubscription<Object?>> _listening =
      <StreamSubscription<Object?>>[];
  final Map<ListenMode, ListenSource> _sources = <ListenMode, ListenSource>{};

  /// Whether the player holds the piece shown. Positions from a piece it held
  /// before are not this one's, and are not heard.
  bool _loaded = false;
  int _generation = 0;
  String? _problem;

  /// True while the gene page splices into the transcript.
  bool _splicing = false;

  AnatomyScene? _scene;
  Object? _sceneKey;
  Map<int, int>? _stepAtPosition;

  bool get _playable =>
      _mode == ListenMode.protein ? widget.track != null : _dnaRefusal == null;

  DnaScore? get _score => switch (_mode) {
    ListenMode.protein => null,
    ListenMode.gene => _gene,
    ListenMode.mrna => _mrna,
  };

  List<int> get _onsets =>
      _mode == ListenMode.protein ? widget.track!.onsetMs : _score!.onsetMs;

  int get _durationMs => _mode == ListenMode.protein
      ? widget.track!.durationMs
      : _score!.durationMs;

  AnatomyStage _stage(StageKind kind) =>
      _model.stages.firstWhere((AnatomyStage s) => s.kind == kind);

  int _index(StageKind kind) =>
      _model.stages.indexWhere((AnatomyStage s) => s.kind == kind);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listening
      ..add(_player.positions.listen(_heard))
      ..add(_player.playing.listen((bool playing) => _playing.value = playing));
    _note.addListener(_follow);
    if (_playable) {
      unawaited(_load());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceMode());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final StreamSubscription<Object?> subscription in _listening) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    _note.dispose();
    _position.dispose();
    _playing.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_player.pause());
    }
  }

  // -- the player -------------------------------------------------------------

  ListenSource _sourceOf(ListenMode mode) => _sources.putIfAbsent(
    mode,
    () => switch (mode) {
      ListenMode.protein => ListenSource(
        bytes: widget.track!.audio,
        name: '${widget.target.slug}.m4a',
      ),
      ListenMode.gene => ListenSource(
        bytes: DnaVoice.wav(DnaVoice.render(_gene!)),
        name: '${widget.target.slug}-gene.wav',
      ),
      ListenMode.mrna => ListenSource(
        bytes: DnaVoice.wav(DnaVoice.render(_mrna!)),
        name: '${widget.target.slug}-mrna.wav',
      ),
    },
  );

  Future<void> _load() async {
    final int generation = ++_generation;
    try {
      await _player.load(_sourceOf(_mode));
      if (mounted && generation == _generation) {
        setState(() {
          _loaded = true;
          _problem = null;
        });
      }
    } on Object catch (error) {
      assert(() {
        debugPrint('helixpeek: could not load a piece to play ($error)');
        return true;
      }());
      if (mounted && generation == _generation) {
        setState(() => _problem = 'This phone could not play it.');
      }
    }
  }

  /// A position the player reports: the one thing that moves the playhead.
  void _heard(Duration position) {
    if (!_loaded) {
      return;
    }
    _position.value = position;
    _note.value = noteAt(_onsets, position.inMilliseconds);
  }

  Future<void> _toggle() async {
    if (_playing.value) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekTo(int note) async {
    final List<int> onsets = _onsets;
    final int at = note.clamp(0, onsets.length - 1);
    await _player.seek(Duration(milliseconds: onsets[at]));
  }

  Future<void> _choose(ListenMode mode) async {
    if (mode == _mode) {
      return;
    }
    final ListenMode was = _mode;
    await _player.pause();
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = mode;
      _loaded = false;
      _problem = null;
      _splicing =
          was == ListenMode.gene &&
          mode == ListenMode.mrna &&
          !MediaQuery.disableAnimationsOf(context);
      _stepAtPosition = null;
    });
    _position.value = Duration.zero;
    _note.value = 0;
    _announceMode();
    await _load();
  }

  // -- what a reader is told --------------------------------------------------

  String get _mapping => _mode == ListenMode.protein
      ? ListenCaptions.mapping(widget.track!)
      : ListenCaptions.dnaMapping(spliced: _mode == ListenMode.mrna);

  void _announceMode() {
    if (!mounted || !_playable) {
      return;
    }
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        _mapping,
        TextDirection.ltr,
      ),
    );
  }

  String _captionOf(int note) {
    if (_mode == ListenMode.protein) {
      return ListenCaptions.residue(widget.track!, note);
    }
    return ListenCaptions.dnaStep(
      _score!,
      note,
      widget.record.protein?.translation ?? '',
    );
  }

  List<String> get _words => _mode == ListenMode.protein
      ? <String>[
          _mapping,
          ...ListenCaptions.describe(widget.track!, widget.target),
        ]
      : <String>[
          _mapping,
          ...ListenCaptions.describeDna(_gene!, _mrna!, widget.target),
        ];

  void _about() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext context) =>
            ListenAbout(target: widget.target, track: widget.track),
      ),
    );
  }

  // -- the grid ---------------------------------------------------------------

  StageKind get _page => switch (_mode) {
    ListenMode.protein => StageKind.protein,
    ListenMode.gene => StageKind.gene,
    ListenMode.mrna => StageKind.mrna,
  };

  AnatomyScene _sceneFor(Size viewport) {
    final Object key = (_mode, _splicing, viewport);
    final AnatomyScene? held = _scene;
    if (held != null && key == _sceneKey) {
      return held;
    }
    final AnatomyScene scene;
    if (_splicing) {
      scene = AnatomyScene.between(
        model: _model,
        fromIndex: _index(StageKind.gene),
        toIndex: _index(StageKind.mrna),
        canvas: canvasFor(<AnatomyStage>[
          _stage(StageKind.gene),
          _stage(StageKind.mrna),
        ], viewport),
        viewport: viewport,
      );
    } else {
      scene = AnatomyScene.resting(
        model: _model,
        index: _index(_page),
        canvas: canvasFor(<AnatomyStage>[_stage(_page)], viewport),
        viewport: viewport,
      );
    }
    _sceneKey = key;
    _scene = scene;
    return scene;
  }

  /// The genomic position the ring marks for [note].
  int _tracedAt(int note) => _mode == ListenMode.protein
      ? _stage(StageKind.protein).positionAt(note)
      : _score!.steps[note].position;

  /// Keeps the note sounding on screen while a page longer than the screen
  /// plays.
  void _follow() {
    final AnatomyScene? scene = _scene;
    if (!_scroll.hasClients || scene == null || scene.isTransition) {
      return;
    }
    final int cell = scene.from.cellAt(_tracedAt(_note.value));
    if (cell < 0) {
      return;
    }
    final ScrollPosition at = _scroll.position;
    final double y = scene.fromLayout.centreOf(cell).dy;
    final double margin = scene.fromLayout.cell * 2;
    if (y < at.pixels + margin ||
        y > at.pixels + at.viewportDimension - margin) {
      _scroll.jumpTo(
        (y - at.viewportDimension / 3).clamp(0.0, at.maxScrollExtent),
      );
    }
  }

  /// A tap on a cell plays from the note it belongs to. A cell outside what
  /// the piece plays (a UTR, an intron outside the coding sequence) is not
  /// a note, and a tap there does nothing.
  void _tapped(int cell) {
    final AnatomyScene? scene = _scene;
    if (scene == null || !_loaded) {
      return;
    }
    if (_mode == ListenMode.protein) {
      unawaited(_seekTo(cell));
      return;
    }
    final Map<int, int> steps = _stepAtPosition ??= <int, int>{
      for (int i = 0; i < _score!.steps.length; i++)
        for (final int position in _score!.steps[i].positions) position: i,
    };
    final int? note = steps[scene.from.positionAt(cell)];
    if (note != null) {
      unawaited(_seekTo(note));
    }
  }

  // -- the screen -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? unpublished = widget.track == null
        ? ListenScreen.unavailable(widget.audioState, widget.audioReason)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(ListenScreen.titleOf(widget.target)),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('listen-about'),
            tooltip: 'About this sound',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _about,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                0,
              ),
              child: SegmentedButton<ListenMode>(
                key: const ValueKey<String>('listen-modes'),
                showSelectedIcon: false,
                segments: <ButtonSegment<ListenMode>>[
                  for (final ListenMode mode in ListenMode.values)
                    ButtonSegment<ListenMode>(
                      value: mode,
                      label: Text(ListenScreen.nameOf(mode)),
                      enabled: mode == ListenMode.protein
                          ? widget.track != null
                          : _dnaRefusal == null,
                    ),
                ],
                selected: <ListenMode>{_mode},
                onSelectionChanged: (Set<ListenMode> chosen) =>
                    unawaited(_choose(chosen.single)),
              ),
            ),
            if (unpublished != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: Text(
                  _dnaRefusal == null
                      ? '$unpublished Its gene can be heard.'
                      : unpublished,
                  key: const ValueKey<String>('listen-unavailable'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (!_playable)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Text(
                      _dnaRefusal ?? '',
                      key: const ValueKey<String>('listen-refused'),
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else ...<Widget>[
              _caption(theme),
              Expanded(child: _grid()),
              _controls(theme),
              _inWords(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _caption(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      AppSpacing.sm,
      AppSpacing.screenPadding,
      AppSpacing.xs,
    ),
    child: ValueListenableBuilder<bool>(
      valueListenable: _playing,
      builder: (BuildContext context, bool playing, Widget? _) =>
          ValueListenableBuilder<int>(
            valueListenable: _note,
            builder: (BuildContext context, int note, Widget? _) => Semantics(
              // Heard as it changes only while the piece stands still: a
              // screen reader cannot say eight notes a second, and a reader
              // stepping through wants each one said.
              liveRegion: !playing,
              child: Text(
                _problem ?? _captionOf(note),
                key: const ValueKey<String>('listen-caption'),
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
    ),
  );

  Widget _grid() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final Size viewport = Size(box.maxWidth, box.maxHeight);
      final AnatomyScene scene = _sceneFor(viewport);
      return SingleChildScrollView(
        controller: _scroll,
        child: ValueListenableBuilder<int>(
          valueListenable: _note,
          builder: (BuildContext context, int note, Widget? _) =>
              LabAnatomyView(
                key: const ValueKey<String>('listen-canvas'),
                scene: scene,
                tracer: _loaded ? Tracer(_tracedAt(note)) : null,
                onTap: _tapped,
                onSettled: _splicing
                    ? () {
                        if (mounted) {
                          setState(() => _splicing = false);
                        }
                      }
                    : null,
              ),
        ),
      );
    },
  );

  Widget _controls(ThemeData theme) {
    final ButtonStyle square = IconButton.styleFrom(
      minimumSize: const Size.square(48),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ValueListenableBuilder<Duration>(
            valueListenable: _position,
            builder: (BuildContext context, Duration position, Widget? _) {
              final int total = _durationMs;
              final double value = total == 0
                  ? 0
                  : (position.inMilliseconds / total).clamp(0.0, 1.0);
              return Row(
                children: <Widget>[
                  Expanded(
                    child: Slider(
                      key: const ValueKey<String>('listen-position'),
                      value: value,
                      label: 'Position',
                      semanticFormatterCallback: (double v) =>
                          '${_clock((v * total).round())} of ${_clock(total)}',
                      onChanged: _loaded
                          ? (double v) => unawaited(
                              _player.seek(
                                Duration(milliseconds: (v * total).round()),
                              ),
                            )
                          : null,
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      '${_clock(position.inMilliseconds)} / ${_clock(total)}',
                      key: const ValueKey<String>('listen-time'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _playing,
            builder: (BuildContext context, bool playing, Widget? _) => Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                IconButton(
                  key: const ValueKey<String>('listen-restart'),
                  style: square,
                  tooltip: 'From the start',
                  onPressed: _loaded ? () => unawaited(_seekTo(0)) : null,
                  icon: const Icon(Icons.replay_rounded),
                ),
                IconButton(
                  key: const ValueKey<String>('listen-previous'),
                  style: square,
                  tooltip: 'Previous note',
                  onPressed: _loaded
                      ? () => unawaited(_seekTo(_note.value - 1))
                      : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton.filled(
                  key: const ValueKey<String>('listen-play'),
                  style: square,
                  tooltip: playing ? 'Pause' : 'Play',
                  onPressed: _loaded ? () => unawaited(_toggle()) : null,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('listen-next'),
                  style: square,
                  tooltip: 'Next note',
                  onPressed: _loaded
                      ? () => unawaited(_seekTo(_note.value + 1))
                      : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The text alternative: the piece described in words, in a sheet of its
  /// own, so a long description never takes the grid's room.
  Widget _inWords(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: TextButton.icon(
      key: const ValueKey<String>('listen-words'),
      onPressed: _readWords,
      icon: const Icon(Icons.notes_rounded),
      label: const Text('The piece in words'),
    ),
  );

  void _readWords() {
    final List<String> words = _words;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          return SafeArea(
            child: SingleChildScrollView(
              key: const ValueKey<String>('listen-words-sheet'),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      'The piece in words',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final String line in words)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(line, style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// `0:07`, `1:36`.
  static String _clock(int ms) {
    final int seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
