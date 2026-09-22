import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../../domain/entities/protein_target.dart';
import '../clinvar/sources_note.dart';
import '../format.dart';
import 'anatomy_fasta.dart';
import 'anatomy_stages.dart';

/// Where everything on the walk comes from, and the ways to take it elsewhere.
///
/// The walk drew a record, a UniProt entry, a PDB structure and a precomputed
/// ESM-2 track without naming one of them on screen — the accession was only
/// ever visible in the loading label. A reader checking a number against its
/// source needs the source, and one who wants the sequence needs it as text.
///
/// It is also where the sources are explained, once: what ESM, AVI and ClinVar
/// each are and every caveat about them, which the sheets no longer repeat,
/// and — for a gene without a ClinVar snapshot — the one place that says so.
Future<void> showRecordSheet({
  required BuildContext context,
  required AnatomyModel model,
  required ProteinTarget target,
  required bool scored,
  required ValueChanged<int> onGoToResidue,
  bool impactScored = false,
  GeneClinVar? clinvar,
  bool clinvarFailed = false,
  VoidCallback? onOpenVariants,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
  builder: (BuildContext context) => _RecordSheet(
    model: model,
    target: target,
    scored: scored,
    onGoToResidue: onGoToResidue,
    impactScored: impactScored,
    clinvar: clinvar,
    clinvarFailed: clinvarFailed,
    onOpenVariants: onOpenVariants,
  ),
);

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({
    required this.model,
    required this.target,
    required this.scored,
    required this.onGoToResidue,
    required this.impactScored,
    required this.clinvarFailed,
    this.clinvar,
    this.onOpenVariants,
  });

  final AnatomyModel model;
  final ProteinTarget target;
  final bool scored;
  final ValueChanged<int> onGoToResidue;
  final bool impactScored;

  /// The snapshot, where one is loaded and matches the record.
  final GeneClinVar? clinvar;
  final bool clinvarFailed;
  final VoidCallback? onOpenVariants;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final TextEditingController _residue = TextEditingController();
  String? _copied;

  @override
  void dispose() {
    _residue.dispose();
    super.dispose();
  }

  AnatomyStage? _stage(StageKind kind) => widget.model.stages
      .where((AnatomyStage s) => s.kind == kind)
      .firstOrNull;

  Future<void> _copy(String what, String? fasta) async {
    if (fasta == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: fasta));
    await HapticFeedback.selectionClick();
    if (mounted) {
      setState(() => _copied = what);
    }
  }

  int? get _residueNumber {
    final int? number = int.tryParse(_residue.text.trim());
    final int length = widget.target.facts.residues;
    return number != null && number >= 1 && number <= length ? number : null;
  }

  void _go() {
    final int? number = _residueNumber;
    if (number == null) {
      return;
    }
    Navigator.of(context).pop();
    widget.onGoToResidue(number);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProteinTarget target = widget.target;
    final AnatomyModel model = widget.model;
    final AnatomyStage gene = model.stages.first;
    final AnatomyStage? mrna = _stage(StageKind.mrna);
    final AnatomyStage? mature = _stage(StageKind.maturePeptides);
    final String strand = model.record.strand == -1 ? '−' : '+';
    final int exons = target.facts.exons;

    final List<(String, String)> rows = <(String, String)>[
      (
        'Record',
        '${target.accession} · ${grouped(model.record.start)}–'
            '${grouped(model.record.end)} ($strand)',
      ),
      (
        'Gene',
        '${grouped(gene.shownCount)} bp · $exons ${exons == 1 ? 'exon' : 'exons'}'
            '${model.record.isIntronCompressed ? ' · introns drawn shortened' : ''}',
      ),
      if (mrna != null) ('Transcript', mrna.sentence),
      (
        'Precursor',
        '${target.uniprot} · ${grouped(target.facts.residues)} aa',
      ),
      if (mature != null) ('Chains', mature.sentence),
      (
        'Structure',
        'PDB ${target.structure.pdb}'
            '${switch (target.structure.modelled) {
              (final int from, final int to) => ' · residues $from–$to',
              null => '',
            }}',
      ),
      if (widget.scored)
        (
          'ESM-2',
          '650M masked marginals, precomputed · constraint min–max within '
              'this protein',
        ),
      if (widget.impactScored)
        (
          'AVI',
          'AlphaGenome Variant Impact, precomputed · GRCh38 · Phred '
              'calibrated genome-wide',
        ),
      (
        'ClinVar',
        switch (widget.clinvar) {
          final GeneClinVar snapshot =>
            'NCBI snapshot ${snapshot.snapshotDate} · '
                '${grouped(snapshot.variants.length)} of '
                '${grouped(snapshot.searchedRecords)} records mapped',
          null when !target.clinvarAvailable =>
            'not yet included for ${target.gene}',
          null when widget.clinvarFailed => 'snapshot unavailable',
          null => 'snapshot loading',
        },
      ),
    ];

    final List<(String, String?)> copies = <(String, String?)>[
      ('Protein', AnatomyFasta.protein(model, target)),
      ('CDS', AnatomyFasta.cds(model, target)),
      ('mRNA', AnatomyFasta.mrna(model, target)),
      if (mature != null) ('Chains', AnatomyFasta.chains(model, target)),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        // `useSafeArea` pays the top and the sides and leaves the bottom to the
        // sheet, so on a phone with a navigation bar the last row sat under it.
        // The two insets are never both spent: the bar's own padding drops to
        // zero while the keyboard is up and the keyboard's inset covers it.
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${target.gene} · ${target.display}',
              style: theme.textTheme.titleLarge,
            ),
            if (model.record.protein?.product case final String product)
              Text(product, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            for (final (String label, String value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 88,
                      child: Text(label, style: theme.textTheme.labelSmall),
                    ),
                    Expanded(
                      child: SelectableText(
                        value,
                        style: AppTypography.sequenceSmall(
                          theme.colorScheme.onSurface,
                        ).copyWith(letterSpacing: 0),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.onOpenVariants case final VoidCallback open)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  key: const ValueKey<String>('open-variants'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    open();
                  },
                  child: Text(
                    'ClinVar records · ${grouped(widget.clinvar?.variants.length ?? 0)} ›',
                  ),
                ),
              ),
            Theme(
              // The tile's own dividers would draw a second pair of rules
              // around what is one quiet block of text.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey<String>('about-sources'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(
                  'About these sources',
                  style: theme.textTheme.labelSmall,
                ),
                children: <Widget>[
                  SourcesNote(
                    snapshotDate: widget.clinvar?.snapshotDate,
                    included:
                        widget.target.clinvarAvailable || widget.clinvar != null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Copy as FASTA', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final (String what, String? fasta) in copies)
                  if (fasta != null)
                    OutlinedButton(
                      key: ValueKey<String>('copy-$what'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                      onPressed: () => _copy(what, fasta),
                      child: Text(_copied == what ? '$what copied' : what),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Go to residue', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('go-to-residue'),
                    controller: _residue,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.go,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '1–${grouped(target.facts.residues)}',
                      isDense: true,
                      // The cursor already shows where typing goes; the accent
                      // ring on focus only drew the eye off the sheet. The
                      // search field makes the same call.
                      focusedBorder: theme.inputDecorationTheme.enabledBorder,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _go(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey<String>('go-to-residue-go'),
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: _residueNumber == null ? null : _go,
                  child: const Text('Go'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
