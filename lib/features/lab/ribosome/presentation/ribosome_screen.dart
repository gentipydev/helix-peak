import 'package:flutter/material.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/anatomy/sequence_scrubber.dart';
import '../../../../shared/format.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/motion/transport_bar.dart';
import '../../presentation/lab_protein_picker.dart';
import '../../presentation/lab_record.dart';
import '../../share/frame_renderer.dart';
import '../../share/share_action.dart';
import '../../share/share_clip_button.dart';
import '../domain/caption_generator.dart';
import '../domain/director.dart';
import '../domain/translation_timeline.dart';
import 'translation_ending.dart';
import 'translation_painter.dart';

/// `/lab/ribosome/<slug>`: one protein's record, fetched through the lab's
/// own tracks, translated.
class RibosomeRoute extends StatelessWidget {
  const RibosomeRoute({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return LabTargetLoader(
      slug: slug,
      builder: (BuildContext context, ProteinTarget target) => LabRecordView(
        target: target,
        title: 'Ribosome · ${target.display}',
        builder: (BuildContext context, GeneRecord record) =>
            RibosomeScreen(target: target, record: record),
      ),
    );
  }
}

/// The whole coding sequence translated, from the cap to the stop codon, and
/// then the protein it made, on the walk's own page ([TranslationEnding]).
///
/// Played on the shared transport bar, paced by the [TranslationDirector]
/// (slow where something happens once, fast in between) beside a cell-time
/// readout that never warps, and scrubbed with the walk's own
/// [SequenceScrubber] as a minimap of the mRNA, its landmarks the timeline's
/// own events. A caption, built from the record by the [CaptionGenerator],
/// says what is happening; where none can be built, none is shown.
class RibosomeScreen extends StatefulWidget {
  const RibosomeScreen({required this.target, required this.record, super.key});

  final ProteinTarget target;
  final GeneRecord record;

  /// How long one beat takes at speed 1, where the director plays slowly.
  static const Duration beat = Duration(milliseconds: 1200);

  /// How long one beat takes in a shared clip, before the clip is held to
  /// its five to fifteen seconds.
  static const Duration clipBeat = Duration(milliseconds: 120);

  @override
  State<RibosomeScreen> createState() => _RibosomeScreenState();
}

class _RibosomeScreenState extends State<RibosomeScreen>
    with SingleTickerProviderStateMixin {
  TranslationTimeline? _translation;
  AnatomyModel? _model;
  TranslationDirector? _director;
  CaptionGenerator? _captions;
  TimelineController? _controller;

  @override
  void initState() {
    super.initState();
    try {
      final TranslationTimeline translation = TranslationTimeline(
        widget.record,
        chain: widget.target.chain,
      );
      final TranslationDirector director = TranslationDirector(translation);
      _translation = translation;
      _model = AnatomyModel.derive(widget.record, chain: widget.target.chain);
      _director = director;
      _captions = CaptionGenerator(translation, widget.record);
      _controller = TimelineController(
        vsync: this,
        timeline: translation,
        beat: RibosomeScreen.beat,
        speedCurve: director.curve,
      );
    } on ArgumentError {
      // A record with no mRNA page to translate: said below, not thrown.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// The translation as a clip: the screen's own painter, paced by the same
  /// director, so a clip lingers where the screen does.
  static FramePainter _clip(
    BuildContext context,
    TranslationTimeline translation,
    TranslationDirector director,
  ) {
    final TranslationInks inks = TranslationInks.of(context);
    return (double wall) => TranslationPainter(
      timeline: translation,
      at: () => director.curve.tAt(wall),
      inks: inks,
    );
  }

  /// The minimap's landmarks: the moments the timeline itself names.
  static List<(double, String)> _landmarks(TranslationTimeline translation) {
    final List<(double, String)> marks = <(double, String)>[
      (translation.beatStart(TranslationTimeline.scanBeats), 'Start codon'),
      for (final ({int junction, double t}) passed in translation.ejcKnockoff)
        (passed.t, 'Exon junction'),
      if (translation.firstExit case final double exit)
        (exit, 'First residue out'),
      if (translation.srpWindow case (final double opens, _))
        (opens, 'Signal peptide out'),
      (translation.beatStart(translation.firstTerminationBeat), 'Stop codon'),
    ];
    return marks
      ..sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  }

  @override
  Widget build(BuildContext context) {
    final TranslationTimeline? translation = _translation;
    final TimelineController? controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ribosome · ${widget.target.display}'),
        actions: <Widget>[
          if ((translation, _director) case (
            final TranslationTimeline translation,
            final TranslationDirector director,
          ))
            ShareClipButton(
              target: widget.target,
              painter: _clip(context, translation, director),
              duration: RibosomeScreen.clipBeat * translation.beats,
            ),
          if (_model case final AnatomyModel model)
            SharePosterButton(target: widget.target, model: model),
        ],
      ),
      body: SafeArea(
        child: translation == null || controller == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Text(
                    'This record has no mRNA and coding sequence to '
                    'translate.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _playing(context, translation, controller),
      ),
    );
  }

  Widget _playing(
    BuildContext context,
    TranslationTimeline translation,
    TimelineController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? playing) =>
                controller.t >= 1 && _model != null
                ? TranslationEnding(
                    key: const ValueKey<String>('ribosome-ending'),
                    timeline: translation,
                    model: _model!,
                    target: widget.target,
                    onReplay: () => controller
                      ..reset()
                      ..play(),
                  )
                : playing!,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (BuildContext context, Widget? painted) =>
                        Semantics(
                          label: TranslationPainter.describe(
                            translation,
                            translation.stateAt(controller.t),
                          ),
                          child: painted,
                        ),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey<String>('ribosome-canvas'),
                        size: Size.infinite,
                        painter: TranslationPainter(
                          timeline: translation,
                          at: () => controller.t,
                          inks: TranslationInks.of(context),
                          repaint: controller,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: SequenceScrubber.width,
                  child: TimelineScrubber(
                    controller: controller,
                    landmarks: _landmarks(translation),
                    labelAt: (double t) {
                      final TranslationState s = translation.stateAt(t);
                      return s.codon <= translation.protein.length
                          ? 'Codon ${grouped(s.codon)}'
                          : 'Stop codon';
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, _) {
            final TranslationState state = translation.stateAt(controller.t);
            final String? caption = _captions!.captionFor(state);
            final TranslationDirector director = _director!;
            return Padding(
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
                    height: 88,
                    child: caption == null
                        ? null
                        : Text(
                            caption,
                            key: const ValueKey<String>('ribosome-caption'),
                            style: theme.textTheme.bodyMedium,
                            maxLines: 4,
                            overflow: TextOverflow.fade,
                          ),
                  ),
                  Text(
                    'In a cell: '
                    '${director.cellSeconds(state).toStringAsFixed(1)} s of '
                    '${director.cellTotal.toStringAsFixed(1)} s, at '
                    '${TranslationDirector.residuesPerSecond} residues a '
                    'second',
                    key: const ValueKey<String>('ribosome-cell-time'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TransportBar(controller: controller),
        ),
      ],
    );
  }
}
