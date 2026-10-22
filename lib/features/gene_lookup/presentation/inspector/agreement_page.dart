import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import '../../../../shared/inspector/score_bar.dart';
import 'base_identity.dart';
import 'coding_evidence.dart';
import 'gene_agreement.dart';

/// A base's substitutions as AVI and ESM-2 each read them, side by side.
///
/// Each missense substitution is ranked twice among the gene's single-base
/// missense substitutions, by AVI's Phred and by ESM-2's score, and the two
/// ranks are drawn on one track: AVI a dot, ESM-2 a ring, the farther apart
/// the more the two differ on that change. Their own numbers stay beside
/// them. A change ESM-2 cannot score — silent, a stop, the start codon — is
/// read as the app reads a ClinVar record's. Under the card, how far the two
/// agree across the gene. Opened from the base sheet's codon line, over the
/// walk, and closed back onto it; the substitutions are the sheet's rows, in
/// the sheet's order.
class AgreementPage extends StatelessWidget {
  const AgreementPage({
    required this.track,
    required this.impact,
    required this.coding,
    required this.agreement,
    required this.address,
    this.region = '',
    this.detail = '',
    this.tint,
    super.key,
  });

  final GeneImpact track;
  final BaseImpact impact;

  /// The codon the base sits in, with the residue's ESM-2 scores.
  final CodingEvidence coding;

  /// The gene's ranks, or null where nothing in it is scored by both.
  final GeneAgreement? agreement;

  /// What the sheet calls the base: `c.268`.
  final String address;

  /// `insulin A chain`: where the base sits, as the sheet says it.
  final String region;

  /// The sheet's own line for the base: its codon, residue and band.
  final String detail;

  /// The colour the grid draws the base's region in, for its letter tile.
  final Color? tint;

  /// What the values are, over the page rather than in it.
  Future<void> _about(BuildContext context, ThemeData theme) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: theme.colorScheme.surfaceContainer,
        builder: (BuildContext context) =>
            Theme(data: theme, child: const _About()),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final TextStyle? style = theme.caption;
    final GeneAgreement? gene = agreement;
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$address · AVI and ESM-2'),
          leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('agreement-info'),
              tooltip: 'About these values',
              onPressed: () => _about(context, theme),
              icon: const Icon(Icons.info_outline, size: 20),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: ListView(
            key: const ValueKey<String>('agreement-scroll'),
            // Stops at its ends on every platform, as the walk's own scroll
            // does.
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              BaseIdentity(
                key: const ValueKey<String>('agreement-identity'),
                base: impact,
                region: region,
                detail: detail,
                chromosome: track.chromosome,
                tint: tint,
              ),
              const SizedBox(height: 20),
              _Card(
                rows: AgreementRow.at(impact, coding, gene),
                gene: track.gene,
              ),
              if (gene != null) ...<Widget>[
                const SizedBox(height: 24),
                _Across(agreement: gene),
              ],
              const SizedBox(height: 24),
              Column(
                key: const ValueKey<String>('agreement-source'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _credit,
                    style: style?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(_notice, style: style),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who made the values, as the page and its sheet credit them.
const String _credit = 'AlphaGenome Atlas · Google DeepMind · ESM-2 650M';

/// The notice AlphaGenome's terms ask of anything that shows its output: the
/// terms it is given under, and what was done to it here.
const String _notice =
    'Provided under and subject to the AlphaGenome Output Terms of Use. '
    'This page ranks the Atlas’s Phred scores within the gene, beside '
    'ESM-2’s.';

const TextStyle _mono = TextStyle(
  fontFamily: AppTypography.monoFamily,
  fontSize: 13,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

/// How wide the base's letter stands, as the Contributions page sets it.
const double _letter = 26;

/// Room between the two columns of numbers.
const double _columnGap = 16;

/// A row's two cells of numbers: AVI's Phred and ESM-2's score, each with
/// its rank in the gene where it has one. Where no column is headed, the
/// Phred names its unit.
(InlineSpan, InlineSpan?) _cells(
  AgreementRow row,
  TextStyle? caption, {
  required bool headed,
}) {
  final GeneRank? avi = row.aviRank;
  final GeneRank? esm = row.esmRank;
  final double? score = row.esm;
  return (
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: row.score.phred.toStringAsFixed(1), style: _mono),
        if (!headed) TextSpan(text: ' Phred', style: caption),
        if (avi != null) TextSpan(text: ' · ${avi.label}', style: caption),
      ],
    ),
    score == null
        ? null
        : TextSpan(
            children: <InlineSpan>[
              TextSpan(text: formatScore(score), style: _mono),
              if (esm != null)
                TextSpan(text: ' · ${esm.label}', style: caption),
            ],
          ),
  );
}

/// The card: each substitution's two numbers and, for a missense change, its
/// two ranks on one track, the marks travelling to their places one row
/// after another.
class _Card extends StatelessWidget {
  const _Card({required this.rows, required this.gene});

  final List<AgreementRow> rows;
  final String gene;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool still = MediaQuery.disableAnimationsOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle? caption = theme.caption;
    final TextStyle base = DefaultTextStyle.of(context).style;
    double measure(InlineSpan span) {
      final TextPainter painter = TextPainter(
        text: TextSpan(style: base, children: <InlineSpan>[span]),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    // ESM-2's column, and the heads over both, only where a change has an
    // ESM-2 score: a base whose every change is silent has none.
    final bool scored = rows.any((AgreementRow r) => r.esm != null);
    final bool ranked = rows.any((AgreementRow r) => r.aviRank != null);
    // Each column as wide as its widest cell or its head, so that the
    // numbers stand under one another.
    const double mark = _Mark.size + 6;
    double aviColumn = scored
        ? mark + measure(TextSpan(text: 'AVI Phred', style: caption))
        : 0;
    double esmColumn = scored
        ? mark + measure(TextSpan(text: 'ESM-2', style: caption))
        : 0;
    double tags = 0;
    for (final AgreementRow row in rows) {
      final (InlineSpan avi, InlineSpan? esm) = _cells(
        row,
        caption,
        headed: scored,
      );
      aviColumn = math.max(aviColumn, measure(avi));
      if (esm != null) esmColumn = math.max(esmColumn, measure(esm));
      tags = math.max(tags, measure(TextSpan(text: row.tag, style: _mono)));
    }
    final double numbers =
        aviColumn + (esmColumn > 0 ? _columnGap + esmColumn : 0);
    return Container(
      key: const ValueKey<String>('agreement-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          // Side by side where both columns fit beside the base and its tag;
          // otherwise each number on a line of its own, under them.
          final bool stacked =
              stackScoreLabels(context) ||
              _letter + tags + 12 + numbers > box.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: still ? 1 : 0, end: 1),
            duration: still ? Duration.zero : const Duration(milliseconds: 900),
            builder: (BuildContext context, double t, Widget? _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (ranked) ...<Widget>[
                  Text(
                    'Rank among $gene missense substitutions',
                    key: const ValueKey<String>('agreement-heading'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                ],
                if (scored) ...<Widget>[
                  _Legend(
                    stacked: stacked,
                    aviColumn: aviColumn,
                    esmColumn: esmColumn,
                  ),
                  const SizedBox(height: 4),
                ],
                if (ranked) ...<Widget>[
                  Row(
                    key: const ValueKey<String>('agreement-ends'),
                    children: <Widget>[
                      const SizedBox(width: _letter),
                      Text('lowest', style: caption),
                      const Spacer(),
                      Text('highest', style: caption),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                for (final (int i, AgreementRow row)
                    in rows.indexed) ...<Widget>[
                  if (i > 0) const SizedBox(height: 14),
                  _Row(
                    row: row,
                    gene: gene,
                    stacked: stacked,
                    headed: scored,
                    aviColumn: aviColumn,
                    esmColumn: esmColumn,
                    // Each row's marks a beat after the row above.
                    travelled: Curves.easeOutCubic.transform(
                      ((t - i * 0.12) / 0.64).clamp(0.0, 1.0),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The two marks named once, over the columns they head.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.stacked,
    required this.aviColumn,
    required this.esmColumn,
  });

  final bool stacked;
  final double aviColumn;
  final double esmColumn;

  @override
  Widget build(BuildContext context) {
    final TextStyle? caption = Theme.of(context).caption;
    Widget head(bool ring, String name) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Mark(ring: ring),
        const SizedBox(width: 6),
        Text(name, style: caption),
      ],
    );
    if (stacked) {
      return Wrap(
        key: const ValueKey<String>('agreement-legend'),
        spacing: 16,
        runSpacing: 4,
        children: <Widget>[head(false, 'AVI Phred'), head(true, 'ESM-2')],
      );
    }
    return Row(
      key: const ValueKey<String>('agreement-legend'),
      children: <Widget>[
        const Spacer(),
        SizedBox(
          width: aviColumn,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: head(false, 'AVI Phred'),
          ),
        ),
        const SizedBox(width: _columnGap),
        SizedBox(
          width: esmColumn,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: head(true, 'ESM-2'),
          ),
        ),
      ],
    );
  }
}

/// One substitution: its base and what it makes, its numbers, and either its
/// two ranks on a track or why only AVI applies.
class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.gene,
    required this.stacked,
    required this.headed,
    required this.aviColumn,
    required this.esmColumn,
    required this.travelled,
  });

  final AgreementRow row;
  final String gene;
  final bool stacked;

  /// Whether the columns are headed: ESM-2's is drawn, and the marks named.
  final bool headed;
  final double aviColumn;
  final double esmColumn;
  final double travelled;

  String get _spoken {
    final String alt = row.score.base;
    final String made = row.spoken.isEmpty ? '' : ', ${row.spoken}';
    final String phred = row.score.phred.toStringAsFixed(1);
    final GeneRank? avi = row.aviRank;
    final GeneRank? esm = row.esmRank;
    final double? score = row.esm;
    return <String>[
      '$alt$made',
      'AVI Phred $phred${avi == null ? '' : ', ${avi.label} in $gene'}',
      if (score != null)
        'ESM-2 ${formatScore(score)}${esm == null ? '' : ', ${esm.label}'}',
      if (row.reading case final reading?) reading.line,
    ].join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? caption = theme.caption;
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final String alt = row.score.base;
    final (InlineSpan avi, InlineSpan? esm) = _cells(
      row,
      caption,
      headed: headed,
    );
    final GeneRank? aviRank = row.aviRank;
    final GeneRank? esmRank = row.esmRank;
    final Widget label = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        SizedBox(
          width: _letter,
          child: Text(alt, style: _mono.copyWith(fontSize: 17)),
        ),
        Text(row.tag, style: _mono.copyWith(color: muted)),
        if (!stacked) ...<Widget>[
          const Spacer(),
          SizedBox(
            width: aviColumn,
            child: Text.rich(
              avi,
              key: ValueKey<String>('agreement-avi-$alt'),
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.end,
            ),
          ),
          if (esmColumn > 0) ...<Widget>[
            const SizedBox(width: _columnGap),
            SizedBox(
              width: esmColumn,
              child: esm == null
                  ? null
                  : Text.rich(
                      esm,
                      key: ValueKey<String>('agreement-esm-$alt'),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.end,
                    ),
            ),
          ],
        ],
      ],
    );
    // A number on a line of its own, after its mark where the legend names
    // the marks.
    Widget line(bool ring, InlineSpan span, String key) => Padding(
      padding: const EdgeInsetsDirectional.only(start: _letter, top: 2),
      child: Row(
        children: <Widget>[
          if (headed) ...<Widget>[_Mark(ring: ring), const SizedBox(width: 6)],
          Expanded(child: Text.rich(span, key: ValueKey<String>(key))),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: _spoken,
      excludeSemantics: true,
      child: Column(
        key: ValueKey<String>('agreement-row-$alt'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          label,
          if (stacked) ...<Widget>[
            line(false, avi, 'agreement-avi-$alt'),
            if (esm != null) line(true, esm, 'agreement-esm-$alt'),
          ],
          if (aviRank != null && esmRank != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _letter, top: 4),
              child: SizedBox(
                height: _Track.height,
                child: CustomPaint(
                  key: ValueKey<String>('agreement-track-$alt'),
                  painter: _Track(
                    avi: aviRank.place,
                    esm: esmRank.place,
                    travelled: travelled,
                    line: theme.colorScheme.outlineVariant,
                    gap: muted,
                    ink: theme.colorScheme.onSurface,
                    ground: theme.colorScheme.surfaceContainer,
                  ),
                ),
              ),
            )
          else if (row.reading case final reading?)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _letter, top: 2),
              child: Text(
                reading.line,
                key: ValueKey<String>('agreement-reading-$alt'),
                style: caption,
              ),
            ),
        ],
      ),
    );
  }
}

/// A mark as the track draws it, for the legend and a stacked row: AVI's
/// dot, or ESM-2's ring.
class _Mark extends StatelessWidget {
  const _Mark({required this.ring});

  final bool ring;

  static const double size = _Track.ring * 2;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _Track(
          avi: ring ? null : 0,
          esm: ring ? 0 : null,
          travelled: 1,
          line: null,
          gap: null,
          ink: theme.colorScheme.onSurface,
          ground: theme.colorScheme.surfaceContainer,
        ),
      ),
    );
  }
}

/// Two ranks on one track from the gene's lowest to its highest: a hairline,
/// ESM-2's ring, AVI's dot inside a ring's room, and between them a heavier
/// rule, the gap the two models leave. A dot inside its ring is a change the
/// two rank alike. The marks set off from the lowest end and travel to their
/// places.
class _Track extends CustomPainter {
  _Track({
    required this.avi,
    required this.esm,
    required this.travelled,
    required this.line,
    required this.gap,
    required this.ink,
    required this.ground,
  });

  /// Where each mark stands, from 0 to 1; null draws none.
  final double? avi;
  final double? esm;
  final double travelled;
  final Color? line;
  final Color? gap;
  final Color ink;

  /// The card under the track, which fills the ring.
  final Color ground;

  static const double height = 12;
  static const double ring = 5;
  static const double _stroke = 1.5;
  static const double _dot = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    final double span = size.width - ring * 2;
    double x(double place) => ring + span * place * travelled;
    final Color? hairline = line;
    if (hairline != null) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = hairline
          ..strokeWidth = 1,
      );
    }
    final double? a = avi == null ? null : x(avi!);
    final double? e = esm == null ? null : x(esm!);
    final Color? between = gap;
    if (a != null && e != null && between != null && (a - e).abs() > 0.5) {
      canvas.drawLine(
        Offset(math.min(a, e), y),
        Offset(math.max(a, e), y),
        Paint()
          ..color = between
          ..strokeWidth = 2.5,
      );
    }
    if (e != null) {
      canvas
        ..drawCircle(Offset(e, y), ring, Paint()..color = ground)
        ..drawCircle(
          Offset(e, y),
          ring - _stroke / 2,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke,
        );
    }
    if (a != null) {
      canvas.drawCircle(Offset(a, y), _dot, Paint()..color = ink);
    }
  }

  @override
  bool shouldRepaint(_Track old) =>
      old.avi != avi ||
      old.esm != esm ||
      old.travelled != travelled ||
      old.line != line ||
      old.gap != gap ||
      old.ink != ink ||
      old.ground != ground;
}

/// How far the two agree across the gene: the rank correlation of all its
/// missense substitutions, and how often the two order one base's alike.
class _Across extends StatelessWidget {
  const _Across({required this.agreement});

  final GeneAgreement agreement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? rho = agreement.rho;
    final double? same = agreement.sameOrder;
    // The name at the start and its value at the end, or under it where the
    // two do not fit on one line.
    Widget stat(String key, InlineSpan name, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          key: ValueKey<String>(key),
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 2,
          children: <Widget>[
            Text.rich(name, style: theme.textTheme.bodyMedium),
            Text(value, style: _mono),
          ],
        ),
      ),
    );
    return Column(
      key: const ValueKey<String>('agreement-across'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Across ${agreement.gene} · ${grouped(agreement.count)} missense '
          'substitutions',
          style: theme.textTheme.titleSmall,
        ),
        if (rho != null)
          stat(
            'agreement-rho',
            // The sans face has no Greek; the mono face does.
            const TextSpan(
              children: <InlineSpan>[
                TextSpan(text: 'Spearman '),
                TextSpan(
                  text: 'ρ',
                  style: TextStyle(fontFamily: AppTypography.monoFamily),
                ),
              ],
            ),
            rho.toStringAsFixed(2).replaceFirst('-', '−'),
          ),
        if (same != null)
          stat(
            'agreement-order',
            const TextSpan(text: 'Same order within a base'),
            '${(same * 100).round()}% of ${grouped(agreement.pairs)} pairs',
          ),
      ],
    );
  }
}

/// What the page's values are and how it draws them, said once.
class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget section(String heading, Widget body) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(heading, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          body,
        ],
      ),
    );
    Text line(String text) => Text(text, style: theme.caption);
    return SingleChildScrollView(
      key: const ValueKey<String>('agreement-about'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('About these values', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          section(
            'The two scores',
            line(
              'AVI: the Atlas’s Phred for each substitution, calibrated '
              'across the genome’s SNVs. ESM-2: 650M, masked marginals, '
              'ln p(alt)/p(WT) for the amino acid the substitution makes.',
            ),
          ),
          section(
            'The ranks',
            line(
              'Each missense substitution is ranked among the gene’s '
              'single-base missense substitutions twice: by AVI, the dot, and '
              'by ESM-2, the ring. Top is the share that scores at least as '
              'high; past half, bottom is the share that scores at most as '
              'high. The farther apart the two marks, the more the two models '
              'differ on that change.',
            ),
          ),
          section(
            'Not ranked',
            line(
              'A silent change, a stop, and any change in the start codon: '
              'ESM-2 scores one amino acid in place of another, so only AVI '
              'applies.',
            ),
          ),
          section(
            'Across the gene',
            line(
              'Spearman’s rank correlation between the two over the same '
              'substitutions. Same order: of every two missense substitutions '
              'at one base, the share both models put in the same order; '
              'pairs tied in either are left out, and half would be chance.',
            ),
          ),
          section(
            'One input shared',
            line(
              'AVI integrates AlphaMissense among its coding features, so on '
              'a missense change it overlaps ESM-2 rather than confirming it.',
            ),
          ),
          section(
            'Source',
            Column(
              key: const ValueKey<String>('agreement-about-source'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                line('$_credit. $_notice'),
                const SizedBox(height: 6),
                line(
                  'The terms: deepmind.google.com/science/alphagenome/'
                  'output-terms',
                ),
                const SizedBox(height: 6),
                line(
                  'Avsec et al., Advancing regulatory variant effect '
                  'prediction with AlphaGenome. Nature 649, 1206–1218 '
                  '(2026). doi:10.1038/s41586-025-10014-0',
                ),
                const SizedBox(height: 6),
                line(
                  'ESM-2: Lin et al., Evolutionary-scale prediction of '
                  'atomic-level protein structure with a language model. '
                  'Science 379, 1123–1130 (2023). doi:10.1126/science.ade2574',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
