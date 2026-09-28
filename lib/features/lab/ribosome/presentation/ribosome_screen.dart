import 'package:flutter/material.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/ribosome/caption_generator.dart';
import '../../../../shared/ribosome/director.dart';
import '../../../../shared/ribosome/translation_painter.dart';
import '../../../../shared/ribosome/translation_player.dart';
import '../../../../shared/ribosome/translation_timeline.dart';
import '../../../../shared/share/frame_renderer.dart';
import '../../../../shared/share/share_action.dart';
import '../../../../shared/share/share_clip_button.dart';
import '../../presentation/lab_protein_picker.dart';
import '../../presentation/lab_record.dart';
import 'translation_ending.dart';

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
/// Played by the shared [TranslationPlayer], the walk's own from its mRNA
/// page; the ending is the lab's.
class RibosomeScreen extends StatefulWidget {
  const RibosomeScreen({required this.target, required this.record, super.key});

  final ProteinTarget target;
  final GeneRecord record;

  /// How long one beat takes at speed 1, where the director plays slowly.
  static const Duration beat = TranslationPlayer.beat;

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
            : TranslationPlayer(
                translation: translation,
                director: _director!,
                captions: _captions!,
                controller: controller,
                ending: switch (_model) {
                  final AnatomyModel model =>
                    (BuildContext context) => TranslationEnding(
                      key: const ValueKey<String>('ribosome-ending'),
                      timeline: translation,
                      model: model,
                      target: widget.target,
                      onReplay: () => controller
                        ..reset()
                        ..play(),
                    ),
                  null => null,
                },
              ),
      ),
    );
  }
}
