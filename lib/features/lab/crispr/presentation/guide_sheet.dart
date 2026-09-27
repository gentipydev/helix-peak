import 'package:flutter/material.dart';

import '../../../../core/biology/gene_record.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/nucleotide_colors.dart';
import '../../../../shared/anatomy/anatomy_stages.dart';
import '../../../../shared/format.dart';
import '../../../../shared/inspector/inspector_sheet.dart';
import '../../mutate/domain/apply_edit.dart';
import '../domain/base_editor.dart';
import '../domain/guide_finder.dart';
import '../domain/repair.dart';

/// What one cut offers: the guides that make it, and then what the cell can
/// be made to do with it.
///
/// The walk's own [InspectorSheet], about a break rather than a residue. It
/// opens on the guides cutting at one place; choosing one opens the three
/// repair paths, each of which ends in an edit the engine makes.
///
/// Nothing here calls a guide good or safe, and [offTarget] is on the screen
/// whether or not a guide has been chosen: these twenty bases have been
/// matched against one gene, and no search of the rest of the genome has been
/// made anywhere in this feature.
class GuideSheet extends StatefulWidget {
  const GuideSheet({
    required this.record,
    required this.model,
    required this.cut,
    required this.guides,
    required this.chosen,
    required this.controller,
    required this.slide,
    required this.onChoose,
    required this.onRepair,
    required this.onDismiss,
    super.key,
  });

  final GeneRecord record;
  final AnatomyModel model;

  /// The cut the sheet is about, as the record position 3' of it.
  final int cut;

  /// The guides cutting there.
  final List<Guide> guides;

  /// The one chosen, where one has been.
  final Guide? chosen;

  final DraggableScrollableController controller;
  final Animation<Offset> slide;
  final ValueChanged<Guide> onChoose;
  final ValueChanged<Repair> onRepair;
  final VoidCallback onDismiss;

  /// Said wherever a guide is, and never softened.
  static const String offTarget =
      'Off-targets are not searched. A guide’s twenty bases have been matched '
      'against this gene and against nothing else in the genome.';

  @override
  State<GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<GuideSheet> {
  final InspectorSheetController _inspector = InspectorSheetController();

  /// The base homology-directed repair is being written at, where one has
  /// been picked.
  int? _template;

  @override
  void didUpdateWidget(GuideSheet old) {
    super.didUpdateWidget(old);
    if (old.cut != widget.cut || old.chosen != widget.chosen) {
      _template = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Guide? chosen = widget.chosen;
    return InspectorSheet(
      sheet: widget.controller,
      controller: _inspector,
      slide: widget.slide,
      onDismiss: widget.onDismiss,
      pinIdentity: true,
      subject: (widget.cut, chosen?.from, chosen?.strand),
      resizeLabel: 'Resize the guide details',
      surfaceKey: const ValueKey<String>('crispr-sheet-surface'),
      scrollKey: const ValueKey<String>('crispr-sheet-scroll'),
      handleKey: const ValueKey<String>('crispr-sheet-handle'),
      closeKey: const ValueKey<String>('crispr-sheet-close'),
      identity: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _CutIdentity(
          model: widget.model,
          cut: widget.cut,
          guides: widget.guides.length,
        ),
      ),
      details: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.guides.isEmpty)
              const _Quiet(
                'Nothing cuts here. A cut needs twenty bases followed by an '
                'NGG, and the cut then falls three bases 5′ of it.',
                sheetKey: ValueKey<String>('crispr-no-guide'),
              )
            else ...<Widget>[
              for (final Guide guide in widget.guides)
                _GuideRow(
                  guide: guide,
                  chosen: guide == chosen,
                  onChoose: () => widget.onChoose(guide),
                ),
              const SizedBox(height: AppSpacing.sm),
              const _Quiet(
                GuideSheet.offTarget,
                sheetKey: ValueKey<String>('crispr-sheet-off-target'),
              ),
            ],
            if (chosen != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _Repairs(
                record: widget.record,
                guide: chosen,
                template: _template,
                onTemplate: (int? position) =>
                    setState(() => _template = position),
                onRepair: widget.onRepair,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where the break falls, and how many guides make it there.
class _CutIdentity extends StatelessWidget {
  const _CutIdentity({
    required this.model,
    required this.cut,
    required this.guides,
  });

  final AnatomyModel model;
  final int cut;
  final int guides;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? region = model.transcriptRoleAt(cut)?.label;
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            Icons.content_cut_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'A cut before base ${grouped(cut)}',
                key: const ValueKey<String>('crispr-cut'),
                style: theme.textTheme.titleMedium,
              ),
              Text(
                <String>[
                  if (region != null && region.isNotEmpty)
                    region[0].toUpperCase() + region.substring(1),
                  guides == 1 ? 'one guide' : '$guides guides',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One guide: its twenty bases, its PAM, and what those bases measure.
class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.guide,
    required this.chosen,
    required this.onChoose,
  });

  final Guide guide;
  final bool chosen;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NucleotideColors bases = context.nucleotideColors;
    final TextStyle? mono = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: AppTypography.monoFamily,
    );
    return InkWell(
      key: ValueKey<String>('crispr-guide-${guide.strand.name}-${guide.from}'),
      onTap: onChoose,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              chosen
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: chosen
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        for (int i = 0; i < guide.protospacer.length; i++)
                          TextSpan(
                            text: guide.protospacer[i],
                            style: TextStyle(
                              color: bases.forBase(guide.protospacer[i]),
                            ),
                          ),
                        TextSpan(
                          text: ' ${guide.pam}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    style: mono,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    <String>[
                      guide.strand == GuideStrand.sense
                          ? 'the strand drawn'
                          : 'the other strand',
                      'GC ${(guide.score.gcFraction * 100).round()}%',
                      if (guide.score.hasPolyT)
                        '${guide.score.longestPolyT} T in a row, which ends a '
                            'polymerase III transcript'
                      else
                        'no run of four T',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three paths a chosen guide's cut can take.
class _Repairs extends StatelessWidget {
  const _Repairs({
    required this.record,
    required this.guide,
    required this.template,
    required this.onTemplate,
    required this.onRepair,
  });

  final GeneRecord record;
  final Guide guide;
  final int? template;
  final ValueChanged<int?> onTemplate;
  final ValueChanged<Repair> onRepair;

  String _baseAt(int position) =>
      record.sequence[record.strand == -1
          ? record.end - position
          : position - record.start];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'What the cell does with the break',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        const _Quiet(
          'A cut is not an edit. The edit is whatever the cell finishes with, '
          'and that depends on which of these it does.',
        ),
        const SizedBox(height: AppSpacing.md),
        _endJoining(context),
        const SizedBox(height: AppSpacing.lg),
        _homologyDirected(context),
        const SizedBox(height: AppSpacing.lg),
        _baseEditing(context),
      ],
    );
  }

  Widget _endJoining(BuildContext context) {
    final List<Repair> outcomes = endJoiningOutcomes(record, guide);
    return _Path(
      title: 'End joining',
      lead:
          'The cell pushes the two ends back together and often loses or '
          'gains a few bases doing it. What comes out is a spread over many '
          'outcomes, not one; these are ${spelled(outcomes.length)} of them.',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final Repair repair in outcomes)
            OutlinedButton(
              key: ValueKey<String>('crispr-nhej-${_shape(repair.edit)}'),
              onPressed: () => onRepair(repair),
              child: Text(repairLabel(repair.edit, _baseAt)),
            ),
        ],
      ),
    );
  }

  Widget _homologyDirected(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<int> positions = hdrPositions(record, guide);
    final int? at = template;
    return _Path(
      title: 'Homology-directed repair',
      lead:
          'Supply a template whose two arms match either side of the break '
          'and the cell copies what lies between them in. It is the one path '
          'that writes what you choose, within about '
          '${spelled(hdrReach)} bases of the cut.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final int position in positions)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      key: ValueKey<String>('crispr-hdr-at-$position'),
                      selected: position == at,
                      onSelected: (_) =>
                          onTemplate(position == at ? null : position),
                      label: Text(
                        _baseAt(position),
                        style: TextStyle(
                          fontFamily: AppTypography.monoFamily,
                          color: context.nucleotideColors.forBase(
                            _baseAt(position),
                          ),
                        ),
                        semanticsLabel:
                            '${_baseAt(position)} at base ${grouped(position)}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (at != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Base ${grouped(at)} reads ${_baseAt(at)}. Write',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final String base in const <String>['A', 'C', 'G', 'T'])
                  if (base != _baseAt(at))
                    OutlinedButton(
                      key: ValueKey<String>('crispr-hdr-$base'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 48),
                        foregroundColor: context.nucleotideColors.forBase(base),
                      ),
                      onPressed: () {
                        final Repair? written = homologyDirected(
                          guide,
                          Substitution(at, base),
                        );
                        if (written != null) {
                          onRepair(written);
                        }
                      },
                      child: Text(base, semanticsLabel: 'Write $base'),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _baseEditing(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _Path(
      title: 'Base editing',
      lead:
          'No break at all: a deaminase rides with the guide and rewrites one '
          'base between places ${BaseEditor.windowFrom} and '
          '${BaseEditor.windowTo} of the twenty. Between them the '
          '${spelled(BaseEditor.all.length)} editors write '
          '${spelled(BaseEditor.changes.length)} of the twelve changes a base '
          'can make, and A to T is not one of them on either strand.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final BaseEditor editor in BaseEditor.all)
            _editor(context, editor, theme),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context, BaseEditor editor, ThemeData theme) {
    final List<Repair> edits = baseEdits(guide, editor);
    final String writes = guide.strand == GuideStrand.sense
        ? '${editor.from} to ${editor.to}'
        : '${complementOf(editor.from)} to ${complementOf(editor.to)} as the '
              'page draws it';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${editor.name} (${editor.abbreviation}) · $writes',
            style: theme.textTheme.bodyMedium,
          ),
          if (edits.isEmpty)
            const _Quiet('Nothing it rewrites sits in this guide’s window.')
          else ...<Widget>[
            if (edits.length > 1)
              _Quiet(
                'This window holds ${spelled(edits.length)} of them, and a '
                'deaminase does not choose: an editor aimed here rewrites '
                'every one. They are offered one at a time all the same, '
                'because one edit is what the engine reads.',
              ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final Repair repair in edits)
                  OutlinedButton(
                    key: ValueKey<String>(
                      'crispr-base-${editor.abbreviation}-${repair.place}',
                    ),
                    onPressed: () => onRepair(repair),
                    child: Text(
                      'Base ${grouped(repair.edit.position)}: '
                      '${_baseAt(repair.edit.position)} to '
                      '${(repair.edit as Substitution).newBase}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One repair path: what it is, and what it offers.
class _Path extends StatelessWidget {
  const _Path({required this.title, required this.lead, required this.child});

  final String title;
  final String lead;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        _Quiet(lead),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.text, {this.sheetKey});

  final String text;
  final ValueKey<String>? sheetKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      key: sheetKey,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// What one edit does to the letters, in the words the edit sheet uses.
String repairLabel(SequenceEdit edit, String Function(int position) baseAt) =>
    switch (edit) {
      Insertion(:final int position, :final String bases) =>
        bases.length == 1
            ? '${baseAt(position)} gained at the cut'
            : '${grouped(bases.length)} bases gained at the cut',
      Deletion(:final int length) =>
        length == 1
            ? 'one base lost at the cut'
            : '${spelled(length)} bases lost',
      Substitution(:final int position, :final String newBase) =>
        '${baseAt(position)} to $newBase at base ${grouped(position)}',
    };

/// A short, stable name for an outcome's shape, for a widget key.
String _shape(SequenceEdit edit) => switch (edit) {
  Insertion(:final String bases) => 'gain-${bases.length}',
  Deletion(:final int position, :final int length) =>
    'lose-$length-at-$position',
  Substitution() => 'write',
};
