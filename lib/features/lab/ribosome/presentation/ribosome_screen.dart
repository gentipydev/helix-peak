import 'package:flutter/material.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/catalog/protein_target.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/motion/timeline_controller.dart';
import '../../../../shared/motion/transport_bar.dart';
import '../../presentation/lab_protein_picker.dart';
import '../../presentation/lab_record.dart';
import '../domain/one_cycle.dart';
import '../domain/translation_timeline.dart';
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

/// One elongation cycle, stepped through with the shared transport bar.
class RibosomeScreen extends StatefulWidget {
  const RibosomeScreen({required this.target, required this.record, super.key});

  final ProteinTarget target;
  final GeneRecord record;

  @override
  State<RibosomeScreen> createState() => _RibosomeScreenState();
}

class _RibosomeScreenState extends State<RibosomeScreen>
    with SingleTickerProviderStateMixin {
  TranslationTimeline? _translation;
  OneCycle? _cycle;
  TimelineController? _controller;

  @override
  void initState() {
    super.initState();
    try {
      final TranslationTimeline translation = TranslationTimeline(
        widget.record,
        chain: widget.target.chain,
      );
      if (translation.protein.length >= 2) {
        final OneCycle cycle = OneCycle(translation, codon: 2);
        _translation = translation;
        _cycle = cycle;
        _controller = TimelineController(
          vsync: this,
          timeline: cycle,
          beat: const Duration(seconds: 4),
        );
      }
    } on ArgumentError {
      // A record with no mRNA page to translate: said below, not thrown.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TranslationTimeline? translation = _translation;
    final OneCycle? cycle = _cycle;
    final TimelineController? controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text('Ribosome · ${widget.target.display}')),
      body: SafeArea(
        child: translation == null || cycle == null || controller == null
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (BuildContext context, Widget? painted) =>
                          Semantics(
                            label: TranslationPainter.describe(
                              translation,
                              cycle.stateAt(controller.t),
                            ),
                            child: painted,
                          ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey<String>('ribosome-canvas'),
                          size: Size.infinite,
                          painter: TranslationPainter(
                            timeline: translation,
                            at: () => cycle.fullT(controller.t),
                            inks: TranslationInks.of(context),
                            repaint: controller,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TransportBar(controller: controller),
                  ),
                ],
              ),
      ),
    );
  }
}
