import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/biology/amino_acids.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gene_clinvar.dart';
import '../../domain/entities/variant_evidence.dart';
import '../format.dart';
import '../inspector/impact_explanation_view.dart';
import 'clinvar_colors.dart';

/// Which model's number a row carries. A sheet already shows its own model on
/// its bars, so its rows carry the other one; the overview has no bars and
/// carries both.
enum EvidenceColumn { avi, esm, both }

/// Wraps text quoted from ClinVar.
///
/// Clinical words are allowed there and nowhere else, and the copy tests find
/// the boundary by this widget rather than by guessing from the layout.
class ClinVarSourced extends StatelessWidget {
  const ClinVarSourced({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// One record: what ClinVar says, and the number the page does not already
/// show. Tapping opens the record's evidence in place.
///
/// The row is the only way a record appears anywhere — in the residue sheet,
/// the base sheet and the overview alike — so a reader learns it once.
class EvidenceRow extends StatelessWidget {
  const EvidenceRow({
    required this.evidence,
    required this.column,
    required this.expanded,
    required this.onToggle,
    this.allele = false,
    this.place = true,
    this.onResidue,
    this.onBase,
    super.key,
  });

  final VariantEvidence evidence;
  final EvidenceColumn column;
  final bool expanded;
  final VoidCallback onToggle;

  /// Cite the change as the base's own allele, `G>A`, where the sheet has
  /// already named the base; otherwise as `c.287G>A`.
  final bool allele;

  /// Whether the detail names where the record sits. A residue sheet has just
  /// said so in its own header.
  final bool place;

  /// Where the detail's links go. Null hides a link, which is what a sheet
  /// does for the page it is already on.
  final ValueChanged<int>? onResidue;
  final ValueChanged<int>? onBase;

  /// How long a row takes to open or close, where motion is on.
  static const Duration motion = Duration(milliseconds: 180);

  /// The citation's type, beside the change.
  static const TextStyle _citation = TextStyle(
    fontFamily: AppTypography.monoFamily,
    fontSize: 12,
  );

  static const double _padding = 8;

  /// How tall a closed row is: exactly this, whatever it cites, so a list of
  /// thousands can place any row without building the rows above it. Read
  /// where the rows are built, for their type and the reader's text size.
  static double closedExtent(BuildContext context) {
    final (double first, double second) = lines(context);
    // Summed as the layout sums it — the lines, then the padding round them —
    // so the two agree to the last bit.
    return first + second + _padding * 2;
  }

  /// A closed row's two lines — the change, then what ClinVar calls it — each
  /// laid out in a box of exactly this height. The overview's readout names
  /// a tapped mark on the same two lines, so it reads as the row does.
  static (double, double) lines(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;
    final DefaultTextStyle inherited = DefaultTextStyle.of(context);
    final TextHeightBehavior? behavior =
        inherited.textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final bool bold = MediaQuery.boldTextOf(context);
    final Object key = (
      type.titleSmall,
      type.bodySmall,
      inherited.style,
      behavior,
      scaler,
      bold,
    );
    if (_measured case (final Object at, final (double, double) lines)
        when at == key) {
      return lines;
    }
    // One line of [style] as a Text here would lay it out.
    double line(TextStyle? style) {
      TextStyle effective = inherited.style.merge(style);
      if (bold) {
        effective = effective.merge(
          const TextStyle(fontWeight: FontWeight.bold),
        );
      }
      final TextPainter painter = TextPainter(
        text: TextSpan(text: 'Ag', style: effective),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        textHeightBehavior: behavior,
        maxLines: 1,
      )..layout();
      final double height = painter.height;
      painter.dispose();
      return height;
    }

    final (double, double) lines = (
      math.max(line(type.titleSmall), line(_citation)),
      math.max(line(type.bodySmall), 3 + ReviewStars.size),
    );
    _measured = (key, lines);
    return lines;
  }

  /// The lines last measured, and what for: every row asks, and almost always
  /// for the same.
  static (Object, (double, double))? _measured;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final ClinVarVariant v = evidence.variant;
    final String citation = allele ? '${v.ref}>${v.alt}' : v.transcriptChange;
    // A record off the protein is already cited by its own change, allele
    // and all; saying the allele again beside it is the same fact twice.
    final bool secondary =
        citation != v.shortLabel && !(allele && v.proteinChange == null);
    final TextStyle mono = _citation.copyWith(color: muted);
    final Duration motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : EvidenceRow.motion;
    final (double first, double second) = lines(context);
    return Column(
      key: ValueKey<String>('evidence-${v.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: expanded,
          label: _spoken(evidence, column),
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey<String>('evidence-row-${v.id}'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: ClinVarDot(group: v.group, size: 10),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // One line, whatever the change: one too long for it
                        // is drawn a little smaller rather than broken or cut.
                        SizedBox(
                          height: first,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  v.shortLabel,
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (secondary) ...<Widget>[
                                  const SizedBox(width: 8),
                                  Text(citation, style: mono),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Open, the classification is read whole.
                        SizedBox(
                          height: expanded ? null : second,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (v.stars > 0) ...<Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: ReviewStars(count: v.stars),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: ClinVarSourced(
                                  child: Text(
                                    v.classification,
                                    maxLines: expanded ? null : 1,
                                    overflow: expanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Numbers(evidence: evidence, column: column),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: motion,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // With motion reduced the detail simply appears. A zero-length
        // AnimatedSize would still re-lay itself out from inside its own
        // layout, which is an error rather than a quicker animation.
        if (motion == Duration.zero)
          if (expanded)
            EvidenceDetail(
              evidence: evidence,
              place: place,
              onResidue: onResidue,
              onBase: onBase,
            )
          else
            const SizedBox.shrink()
        else
          AnimatedSize(
            duration: motion,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? EvidenceDetail(
                    evidence: evidence,
                    place: place,
                    onResidue: onResidue,
                    onBase: onBase,
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

/// The trailing numbers, tabular so a column of rows lines up.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.evidence, required this.column});

  final VariantEvidence evidence;
  final EvidenceColumn column;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle style = TextStyle(
      fontFamily: AppTypography.monoFamily,
      fontSize: 12,
      color: theme.colorScheme.onSurface,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final TextStyle unit = style.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final List<InlineSpan> parts = <InlineSpan>[
      if (column != EvidenceColumn.avi && evidence.esm != null) ...<InlineSpan>[
        TextSpan(text: 'ESM ', style: unit),
        TextSpan(text: formatScore(evidence.esm!.score), style: style),
      ],
      if (column != EvidenceColumn.esm) ...<InlineSpan>[
        if (column == EvidenceColumn.both && evidence.esm != null)
          TextSpan(text: '  ', style: unit),
        TextSpan(text: 'AVI ', style: unit),
        TextSpan(text: evidence.avi?.toStringAsFixed(1) ?? '—', style: style),
      ],
    ];
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(children: parts),
        key: ValueKey<String>('evidence-numbers-${evidence.variant.id}'),
      ),
    );
  }
}

/// The one place a record's observed and predicted evidence meet.
///
/// ClinVar's side is quoted, down to the split a conflict hides; the models'
/// side is each one's number on its own scale and a single line about where
/// those numbers sit. Nothing adds the two up.
class EvidenceDetail extends StatelessWidget {
  const EvidenceDetail({
    required this.evidence,
    this.place = true,
    this.onResidue,
    this.onBase,
    super.key,
  });

  final VariantEvidence evidence;
  final bool place;
  final ValueChanged<int>? onResidue;
  final ValueChanged<int>? onBase;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final TextStyle? small = theme.textTheme.bodySmall;
    final ClinVarVariant v = evidence.variant;
    final List<(String, List<ClinVarTrait>)> conditions = v.conditionsByClass;
    final TextStyle ids = TextStyle(
      fontFamily: AppTypography.monoFamily,
      fontSize: 11,
      color: muted,
    );
    final String? residue = evidence.residue == null
        ? null
        : '${evidence.residue!.domain} · ${evidence.residue!.title}'
              '${evidence.residue!.bondPartner == null ? '' : ' · S–S ${evidence.residue!.bondPartner}'}';
    final TextStyle number = TextStyle(
      fontFamily: AppTypography.monoFamily,
      fontSize: 13,
      color: theme.colorScheme.onSurface,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    Widget reading(String model, String value, String note, Key key) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(
            width: 36,
            child: Text(model, style: small?.copyWith(color: muted)),
          ),
          SizedBox(
            width: 52,
            child: Text(value, key: key, style: number),
          ),
          Expanded(child: Text(note, style: small)),
        ],
      ),
    );
    return Padding(
      key: ValueKey<String>('evidence-detail-${v.id}'),
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (place && residue != null)
            Text(residue, style: small?.copyWith(color: muted)),
          // Every condition, under the classification it was given for it:
          // what a combined or conflicting label is made of, and which
          // condition each part is about. The class dot is the list's own.
          ClinVarSourced(
            child: Column(
              key: ValueKey<String>('evidence-conditions-${v.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (String classification, List<ClinVarTrait> traits)
                    in conditions) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: <Widget>[
                        ClinVarDot(
                          group: ClinVarGroup.of(classification),
                          size: 7,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            classification,
                            style: small?.copyWith(color: muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The identifiers travel as one unit: beside the name when
                  // they fit, under it when they do not, never split.
                  for (final ClinVarTrait trait in traits)
                    Padding(
                      padding: const EdgeInsets.only(left: 13),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            trait.name,
                            style: trait.placeholder
                                ? small?.copyWith(color: muted)
                                : small,
                          ),
                          if (<String>[?trait.symbol, ?trait.mim]
                              case final List<String> cited
                              when cited.isNotEmpty)
                            Text(
                              cited.join(' · ').replaceAll(' ', ' '),
                              style: ids,
                            ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 2),
                Text(v.reviewStatus, style: small?.copyWith(color: muted)),
              ],
            ),
          ),
          Divider(height: 16, color: theme.colorScheme.outlineVariant),
          if (evidence.esm case final score?)
            reading(
              'ESM',
              formatScore(score.score),
              '${AminoAcids.abbreviationOf(score.aminoAcid)} in place of '
                  '${AminoAcids.abbreviationOf(v.wildtypeResidue ?? '')}',
              ValueKey<String>('evidence-esm-${v.id}'),
            ),
          reading(
            'AVI',
            evidence.avi?.toStringAsFixed(1) ?? '—',
            evidence.avi == null
                ? 'no exact score at this base'
                : '${genomeRank(evidence.avi!)} genome-wide',
            ValueKey<String>('evidence-avi-${v.id}'),
          ),
          if (evidence.reading case final EvidenceReading line)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                line.line,
                key: ValueKey<String>('evidence-reading-${v.id}'),
                style: small?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
          const SizedBox(height: 4),
          if (evidence.explanation case final request?)
            ImpactExplanationView(
              key: ValueKey('evidence-contributions-${v.id}'),
              request: request,
            ),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              // The record itself, on ClinVar, as the Atlas link opens its
              // change in the Atlas; a device with nowhere to open it gets
              // the link to paste instead.
              TextButton.icon(
                key: ValueKey<String>('evidence-copy-${v.id}'),
                style: _link,
                onPressed: () async {
                  try {
                    if (await launchUrl(
                      Uri.parse(v.url),
                      mode: LaunchMode.externalApplication,
                    )) {
                      return;
                    }
                  } on Exception {
                    // Copied below instead.
                  }
                  await Clipboard.setData(ClipboardData(text: v.url));
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          '${v.accession} link copied. Open it in your '
                          'browser.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: Text(
                  v.accession,
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFamily,
                    fontSize: 12,
                  ),
                ),
              ),
              if (onResidue != null && v.residue != null)
                TextButton(
                  key: ValueKey<String>('evidence-residue-${v.id}'),
                  style: _link,
                  onPressed: () => onResidue!(v.residue!),
                  child: const Text('Residue ›'),
                ),
              if (onBase != null)
                TextButton(
                  key: ValueKey<String>('evidence-base-${v.id}'),
                  style: _link,
                  onPressed: () => onBase!(v.position),
                  child: const Text('Base ›'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// A finger's height, and exactly that: `shrinkWrap` so the theme does
  /// not pad it to 48, and standard density because compact takes eight
  /// points off whatever size is asked for.
  static final ButtonStyle _link = TextButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
  );
}

/// What a screen reader says for a collapsed row: the change, the quoted
/// classification, and the numbers the row shows.
String _spoken(VariantEvidence e, EvidenceColumn column) {
  final ClinVarVariant v = e.variant;
  return <String>[
    v.shortLabel,
    if (v.shortLabel != v.transcriptChange) v.transcriptChange,
    'ClinVar ${v.classification}',
    if (v.stars > 0) '${v.stars} of 4 review stars',
    if (column != EvidenceColumn.avi && e.esm != null)
      'ESM ${e.esm!.score.toStringAsFixed(1)}',
    if (column != EvidenceColumn.esm)
      e.avi == null ? 'AVI unavailable' : 'AVI ${e.avi!.toStringAsFixed(1)}',
  ].join(', ');
}

/// NCBI's review stars, drawn: the fonts carry no star, and a box where one
/// should be says less than nothing. Filled stars only — the empty ones would
/// be most of every row, since no INS record has more than two.
class ReviewStars extends StatelessWidget {
  const ReviewStars({required this.count, super.key});

  final int count;

  /// A star's size, which the reader's text size does not change.
  static const double size = 12;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Icon(
            Icons.star_rounded,
            size: size,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      ],
    ),
  );
}
