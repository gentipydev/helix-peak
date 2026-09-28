import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/catalog/protein_target.dart';
import '../../../../core/evidence/protein_constraint.dart';
import '../../../../core/network/track_source.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/anatomy/anatomy_layout.dart';
import '../../../../shared/anatomy/anatomy_scene.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/ribosome/translation_flight.dart';
import '../../../../shared/ribosome/translation_painter.dart';
import '../../../../shared/ribosome/translation_timeline.dart';
import '../../presentation/lab_anatomy_view.dart';

/// Where translation ends: the released chain flies into its places on the
/// protein page, which is then the walk's own.
///
/// The page is laid out by the shared [AnatomyLayout] and drawn by the shared
/// painter from the same record, so it is the picture the walk shows, not a
/// lookalike. Each residue flies from where the translation left it to its
/// cell on that layout along the walk's own path, bowed by [AnatomyMotion.bow]
/// and set off 5′ to 3′ by [AnatomyMotion.stagger]; with reduced motion the
/// page is simply there.
///
/// From here the reader can open the walk itself. The lab never enters the
/// walk's route part of the way through: the link opens `/gene/<slug>` at its
/// start, the way every other way into the walk does.
class TranslationEnding extends StatefulWidget {
  const TranslationEnding({
    required this.timeline,
    required this.model,
    required this.target,
    required this.onReplay,
    super.key,
  });

  final TranslationTimeline timeline;

  /// The same record's anatomy, derived as the walk derives it.
  final AnatomyModel model;
  final ProteinTarget target;
  final VoidCallback onReplay;

  static const Duration flight = TranslationFlightPainter.duration;

  @override
  State<TranslationEnding> createState() => _TranslationEndingState();
}

class _TranslationEndingState extends State<TranslationEnding>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: TranslationEnding.flight,
  );

  ProteinConstraint? _constraint;
  bool _conservation = false;
  bool _started = false;

  int get _page => widget.model.stages.indexWhere(
    (AnatomyStage s) => s.kind == StageKind.protein,
  );

  @override
  void initState() {
    super.initState();
    // A protein with no constraint track is drawn without one, exactly as the
    // walk draws it: the page, with no conservation to switch to.
    if (widget.target.scored) {
      unawaited(_loadConstraint());
    }
  }

  Future<void> _loadConstraint() async {
    try {
      final ProteinConstraint constraint = await ProteinConstraint.load(
        widget.target,
        tracks: context.read<TrackSource>(),
      );
      if (mounted) {
        setState(() => _constraint = constraint);
      }
    } on Object {
      // Not ready, or not readable: the page is drawn without it.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _flight.value = 1;
    } else {
      unawaited(_flight.forward());
    }
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int page = _page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: page < 0
              ? const SizedBox.shrink()
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final Size viewport = Size(box.maxWidth, box.maxHeight);
                    final AnatomyStage stage = widget.model.stages[page];
                    final Size canvas = Size(
                      viewport.width,
                      math.max(
                        viewport.height,
                        AnatomyLayout.heightFor(stage, viewport),
                      ),
                    );
                    return AnimatedBuilder(
                      animation: _flight,
                      builder: (BuildContext context, _) => _flight.value < 1
                          ? CustomPaint(
                              key: const ValueKey<String>('ending-flight'),
                              size: viewport,
                              painter: TranslationFlightPainter(
                                starts: TranslationPainter.chainPositions(
                                  viewport,
                                  widget.timeline.stateAt(1),
                                ),
                                layout: AnatomyLayout.forStage(
                                  stage,
                                  canvas,
                                  viewport,
                                ),
                                letters: stage.letters,
                                progress: _flight.value,
                                startRadius:
                                    TranslationPainter.residueRadius *
                                    TranslationPainter.viewportScale(viewport),
                                anatomy: context.anatomyColors,
                                ground: theme.colorScheme.surface,
                              ),
                            )
                          : SingleChildScrollView(
                              child: LabAnatomyView(
                                key: const ValueKey<String>('ending-page'),
                                scene: AnatomyScene.resting(
                                  model: widget.model,
                                  index: page,
                                  canvas: canvas,
                                  viewport: viewport,
                                ),
                                constraint: _constraint,
                                conservation: _conservation,
                              ),
                            ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            0,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('ending-open-walk'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () =>
                    context.push(RoutePaths.geneFor(widget.target)),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open the walk'),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: widget.onReplay,
                child: const Text('Replay'),
              ),
              if (_constraint != null)
                FilterChip(
                  key: const ValueKey<String>('ending-conservation'),
                  label: const Text('Conservation'),
                  selected: _conservation,
                  onSelected: (bool on) => setState(() => _conservation = on),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
