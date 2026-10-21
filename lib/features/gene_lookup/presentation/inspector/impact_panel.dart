import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/evidence/impact_explanations.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/clinvar/clinvar_colors.dart';
import '../../../../shared/format.dart';
import '../../../../shared/inspector/inspector_sheet.dart';
import '../../../../shared/inspector/level_pips.dart';
import '../../../../shared/inspector/score_bar.dart';
import 'coding_evidence.dart';

/// What one base of the gene answers with, in the sheet the residue panel uses.
///
/// AVI is this sheet's own model, so its bars are the body. The residue a
/// coding base is read into is one line that opens that residue's own sheet,
/// rather than a second model summarised here: ESM's reading lives on the
/// protein page, and the two meet only for a ClinVar record, in its detail.
/// The sheet itself is [InspectorSheet], and substitution rows remain
/// [ScoreBar].
///
/// The words stay molecular throughout. An AVI score is a prediction about
/// splicing, expression, chromatin and coding — never about a person.
class ImpactPanel extends StatefulWidget {
  const ImpactPanel({
    required this.impact,
    required this.chromosome,
    required this.address,
    required this.region,
    required this.note,
    required this.tint,
    required this.controller,
    required this.slide,
    required this.pinIdentity,
    required this.onDismiss,
    this.coding,
    this.onNote,
    this.reported = const <String, ClinVarGroup>{},
    this.observedEvidence,
    this.explanationTrack,
    this.onOpenContributions,
    super.key,
  });

  static const double minimumSize = InspectorSheet.minimumSize;
  static const double initialSize = InspectorSheet.initialSize;
  static const double maximumSize = InspectorSheet.maximumSize;

  final BaseImpact impact;
  final GeneImpact? explanationTrack;

  /// Opens every substitution's AVI contributions on a page of their own.
  /// Offered only where [explanationTrack] explains one of them.
  final VoidCallback? onOpenContributions;

  /// The codon a coding base sits in, for what each alternative makes of it.
  /// Null off the coding sequence.
  final CodingEvidence? coding;

  /// Opens what [note] names — the residue a coding base encodes. Null makes
  /// the note plain text.
  final VoidCallback? onNote;

  /// Alternative bases ClinVar has a record for here, each with its most
  /// severe group, marked on their own bars.
  final Map<String, ClinVarGroup> reported;

  /// The ClinVar records at this base, or null for a gene without them.
  final Widget? observedEvidence;

  /// `chr11`, for the one line that says where on the chromosome this is.
  final String chromosome;

  /// How the transcript numbers this base — `c.188`, `c.−59`, `c.*54` — or the
  /// record's own base number where it has no coding number.
  final String address;

  /// `exon 2`, `intron 1`, `5′ UTR`.
  final String region;

  /// One line of context: the splice sites the intron is bounded by, or the
  /// codon the base sits in and the residue it encodes. Empty where there is
  /// nothing worth saying.
  final String note;

  /// The colour the page draws this base's region in, so the chip and the grid
  /// agree about what kind of thing has been tapped.
  final Color tint;

  final DraggableScrollableController controller;
  final Animation<Offset> slide;
  final bool pinIdentity;
  final VoidCallback onDismiss;

  @override
  State<ImpactPanel> createState() => _ImpactPanelState();
}

class _ImpactPanelState extends State<ImpactPanel> {
  final InspectorSheetController _inspector = InspectorSheetController();
  bool _explanation = false;

  void _toggleExplanation() {
    setState(() => _explanation = !_explanation);
    if (_explanation) {
      _inspector.reveal(grow: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration crossfade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final int position = widget.impact.position;
    return InspectorSheet(
      sheet: widget.controller,
      controller: _inspector,
      slide: widget.slide,
      onDismiss: widget.onDismiss,
      pinIdentity: widget.pinIdentity,
      subject: position,
      resizeLabel: 'Resize base details',
      surfaceKey: const ValueKey<String>('impact-sheet-surface'),
      scrollKey: const ValueKey<String>('impact-panel-scroll'),
      handleKey: const ValueKey<String>('impact-sheet-handle'),
      closeKey: const ValueKey<String>('impact-sheet-close'),
      identity: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: AnimatedSwitcher(
          duration: crossfade,
          child: _BaseIdentity(
            key: ValueKey<int>(position),
            impact: widget.impact,
            chromosome: widget.chromosome,
            address: widget.address,
            region: widget.region,
            tint: widget.tint,
            scaleBase: widget.coding != null,
            explanation: _explanation,
            onExplain: _toggleExplanation,
          ),
        ),
      ),
      details: AnimatedSwitcher(
        duration: crossfade,
        child: _Details(
          key: ValueKey<int>(position),
          impact: widget.impact,
          note: widget.note,
          onNote: widget.onNote,
          explanation: _explanation,
          coding: widget.coding,
          reported: widget.reported,
          observedEvidence: widget.observedEvidence,
          explanationTrack: widget.explanationTrack,
          onOpenContributions: widget.onOpenContributions,
        ),
      ),
    );
  }
}

class _BaseIdentity extends StatelessWidget {
  const _BaseIdentity({
    required this.impact,
    required this.chromosome,
    required this.address,
    required this.region,
    required this.tint,
    required this.scaleBase,
    required this.explanation,
    required this.onExplain,
    super.key,
  });

  final BaseImpact impact;
  final String chromosome;
  final String address;
  final String region;
  final Color tint;
  final bool scaleBase;
  final bool explanation;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final double baseSize = scaleBase
        ? (MediaQuery.textScalerOf(context).scale(26) + 16).clamp(
            42.0,
            double.infinity,
          )
        : 42;
    return Row(
      children: <Widget>[
        Container(
          key: const ValueKey<String>('impact-tile'),
          width: baseSize,
          height: baseSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            impact.wildtype,
            style: TextStyle(
              fontFamily: AppTypography.monoFamily,
              fontSize: 26,
              color: inkOn(
                tint,
                dark: theme.colorScheme.surface,
                light: context.anatomyColors.tracer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(address, style: theme.textTheme.titleSmall),
              // A base with no coding number is already called by its region —
              // 'intron 2 base 12' — and saying 'intron 2' under that is the
              // same fact twice.
              if (!address.contains(region))
                Text(region, style: theme.textTheme.bodySmall),
              Text(
                '$chromosome:${grouped(impact.genomic)}',
                key: const ValueKey<String>('impact-coordinate'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppTypography.monoFamily,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'About these scores',
          isSelected: explanation,
          onPressed: onExplain,
          icon: const Icon(Icons.info_outline, size: 20),
        ),
      ],
    );
  }
}

/// The ink a letter reads in on [fill]: [dark] or [light], whichever stands
/// further from it by contrast ratio.
///
/// The gene page's rule for naming its regions (`AnatomyPainter`), and here
/// for the same fills: the tile is tinted as the grid draws the base's region,
/// and an intron's near-black took the ground's own ink at 1.25 to one.
Color inkOn(Color fill, {required Color dark, required Color light}) {
  double contrast(Color a, Color b) {
    final double x = a.computeLuminance();
    final double y = b.computeLuminance();
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  return contrast(fill, dark) >= contrast(fill, light) ? dark : light;
}

class _Details extends StatelessWidget {
  const _Details({
    required this.impact,
    required this.note,
    required this.explanation,
    required this.reported,
    this.onNote,
    this.coding,
    this.observedEvidence,
    this.explanationTrack,
    this.onOpenContributions,
    super.key,
  });

  final BaseImpact impact;
  final String note;
  final VoidCallback? onNote;
  final bool explanation;
  final CodingEvidence? coding;
  final Map<String, ClinVarGroup> reported;
  final Widget? observedEvidence;
  final GeneImpact? explanationTrack;
  final VoidCallback? onOpenContributions;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Color bar = theme.colorScheme.onSurfaceVariant;
    // An estimate is drawn quieter than a measurement. The number is still
    // there to read, but nothing about it should look as solid as a score that
    // was measured for the base under the finger.
    final double weight = impact.estimated ? 0.55 : 1;
    // An estimate explains nothing: its scores are another base's.
    final bool explained =
        onOpenContributions != null &&
        !impact.estimated &&
        impact.ranked.any(
          (AltScore score) =>
              ImpactExplanationRequest.forAllele(
                explanationTrack,
                impact.position,
                impact.wildtype,
                score.base,
              ) !=
              null,
        );
    // The base that is actually there. It is not a substitution and has no
    // score of its own, so it carries no bar — an empty track and a dash,
    // rather than a zero that would read as a measurement.
    final Widget reference = ScoreBar(
      label: impact.wildtype,
      fraction: 0,
      value: '—',
      native: true,
      color: bar,
      semanticsLabel: '${impact.wildtype}, the reference base, not scored',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Opacity(
          opacity: weight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 12),
              LevelPips(
                filled: switch (impact.level) {
                  ImpactLevel.high => 3,
                  ImpactLevel.middle => 2,
                  ImpactLevel.low => 1,
                },
                label: impact.level.label,
                trailing: '${genomeRank(impact.peak)} genome-wide',
                labelKey: const ValueKey<String>('impact-level'),
              ),
              if (impact.estimated) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Estimated from position ${grouped(impact.estimatedFrom!)} · '
                  '${grouped(impact.distance)} bp away',
                  key: const ValueKey<String>('impact-estimated'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (explanation) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'AlphaGenome Variant Impact, precomputed: every substitution '
                  'at this base scored against the GRCh38 reference, for '
                  'splicing, expression, chromatin and coding effects together. '
                  'Phred = −10 log10(1 − quantile), calibrated across the '
                  'genome: 10 is the top 10% of SNVs, 20 the top 1% and 30 the '
                  'top 0.1%.',
                  key: const ValueKey<String>('impact-explanation'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _NoteLine(text: note, onTap: onNote),
              ],
              const SizedBox(height: 12),
              Text(
                'Substitutions · AVI Phred',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ScoreScale(
                low: '0',
                high: '40 or higher',
                style: theme.textTheme.labelSmall,
                highKey: const ValueKey<String>('impact-scale-end'),
              ),
              const SizedBox(height: 4),
              for (final AltScore score in impact.ranked)
                ScoreBar(
                  label: score.base,
                  fraction: score.barFraction,
                  value: score.phred.toStringAsFixed(1),
                  native: false,
                  color: bar,
                  valueKey: ValueKey<String>('impact-score-${score.base}'),
                  tag: _tag(score.base, reported[score.base], coding),
                  semanticsLabel:
                      '${score.base}, Phred ${score.phred.toStringAsFixed(1)}'
                      '${_spoken(coding?.spokenChangeTo(score.base))}'
                      '${reported[score.base] == null ? '' : ', ClinVar ${reported[score.base]!.label}'}',
                ),
              reference,
            ],
          ),
        ),
        if (explained) _ContributionsLink(onTap: onOpenContributions!),
        ?observedEvidence,
      ],
    );
  }

  /// The row's tag: its ClinVar mark, what the change makes of a coding
  /// base's codon — `His`, `=` where it keeps the amino acid, `Ter`, `?` in
  /// the start codon — or both.
  static Widget? _tag(String alt, ClinVarGroup? group, CodingEvidence? coding) {
    final String made = coding?.changeTo(alt) ?? '';
    if (group == null && made.isEmpty) {
      return null;
    }
    return Row(
      key: ValueKey<String>('impact-tag-$alt'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (group != null) ClinVarDot(group: group, size: 9),
        if (group != null && made.isNotEmpty) const SizedBox(width: 4),
        if (made.isNotEmpty)
          Text(
            made,
            style: const TextStyle(
              fontFamily: AppTypography.monoFamily,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  /// A row's change as its screen-reader label continues: `, histidine`.
  static String _spoken(String? change) =>
      change == null || change.isEmpty ? '' : ', $change';
}

/// The way to every substitution's AVI contributions, a page of its own: the
/// sheet's one row that leaves it, as the ClinVar line's "All ›" does.
class _ContributionsLink extends StatelessWidget {
  const _ContributionsLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelLarge?.copyWith(
      fontFamily: AppTypography.sansFamily,
      color: theme.colorScheme.onSurface,
    );
    return Semantics(
      button: true,
      label: 'Contributions to each AVI score',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey<String>('impact-contributions-open'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: <Widget>[
              Expanded(child: Text('Contributions', style: style)),
              Text('›', style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// The note under the level: plain where it only describes, and a way into the
/// residue's own sheet where it names one.
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Text label = Text(
      onTap == null ? text : '$text ›',
      key: const ValueKey<String>('impact-note'),
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: AppTypography.sansFamily,
        color: onTap == null
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
      ),
    );
    if (onTap == null) {
      return label;
    }
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey<String>('impact-note-link'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: label,
          ),
        ),
      ),
    );
  }
}
