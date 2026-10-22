import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Float32List, listEquals;
import 'package:flutter/material.dart';

import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/theme/agreement_colors.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import '../../../../shared/inspector/score_bar.dart';
import 'base_identity.dart';
import 'coding_evidence.dart';
import 'gene_agreement.dart';

/// A base's substitutions as AVI and ESM-2 each read them, side by side.
///
/// Each missense substitution shows its two numbers, AVI's Phred and ESM-2's
/// score, and is placed twice on one track among the gene's single-base
/// missense substitutions: AVI a denim dot, ESM-2 a clay ring, the farther
/// apart the more the two differ on that change, from the milder end to the
/// stronger. A change ESM-2 cannot score — silent, a stop, the start codon — is
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
    final List<AgreementRow> rows = AgreementRow.at(impact, coding, gene);
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
              _Card(rows: rows, gene: track.gene),
              if (gene != null) ...<Widget>[
                const SizedBox(height: 24),
                _Across(
                  agreement: gene,
                  marks: <AgreementRow>[
                    for (final AgreementRow row in rows)
                      if (row.esm != null) row,
                  ],
                ),
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
                  Text(_compared, style: style),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two sources, as the page names them.
const String _credit = 'AlphaGenome Atlas · ESM-2';

/// What the two are and how the page sets them side by side, in one line.
const String _compared =
    'AVI (AlphaGenome Atlas) scores each change from the DNA, ESM-2 the '
    'amino acid it makes from the protein sequence; both are ranked here '
    'among the gene’s missense substitutions.';

/// Who made the AVI values, as the page's sheet credits them.
const String _atlas = 'AlphaGenome Atlas · Google DeepMind';

/// The notice AlphaGenome's terms ask of anything that shows its output: the
/// terms it is given under, and what was done to it here. The page's sheet
/// carries it, at the user's ask for a page that names its sources alone
/// (2026-10-22).
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

/// A row's two numbers: AVI's Phred and ESM-2's score, nothing else (the
/// user's ask, 2026-10-22: the track carries the ranks). Where no column is
/// headed, the Phred names its unit.
(InlineSpan, InlineSpan?) _cells(
  AgreementRow row,
  TextStyle? caption, {
  required bool headed,
}) {
  final double? score = row.esm;
  return (
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: row.score.phred.toStringAsFixed(1), style: _mono),
        if (!headed) TextSpan(text: ' Phred', style: caption),
      ],
    ),
    score == null ? null : TextSpan(text: formatScore(score), style: _mono),
  );
}

/// The card: each substitution's two numbers and, for a missense change, its
/// two ranks on one track, the marks travelling to their places one row
/// after another, and under the tracks which way the effect grows.
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
                    'Ranked among $gene missense substitutions',
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
                if (scored) const SizedBox(height: 6),
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
                // Which way the tracks run, said by what grows along them
                // rather than by a value: ESM-2's stronger end holds its
                // lowest numbers.
                if (ranked) ...<Widget>[
                  const SizedBox(height: 8),
                  _Ends(style: caption),
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

  /// The row as a screen reader says it, the track's two places in words.
  String get _spoken {
    final String alt = row.score.base;
    final String made = row.spoken.isEmpty ? '' : ', ${row.spoken}';
    final String phred = row.score.phred.toStringAsFixed(1);
    final GeneRank? avi = row.aviRank;
    final GeneRank? esm = row.esmRank;
    final double? score = row.esm;
    return <String>[
      '$alt$made',
      'AVI Phred $phred',
      if (score != null) 'ESM-2 ${formatScore(score)}',
      if (avi != null && esm != null)
        'Among $gene missense substitutions, AVI places it in the '
            '${avi.label}, ESM-2 in the ${esm.label}',
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
    final AgreementColors models = context.agreementColors;
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
                    joined: true,
                    aviInk: models.avi,
                    esmInk: models.esm,
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
/// denim dot, or ESM-2's clay ring.
class _Mark extends StatelessWidget {
  const _Mark({required this.ring});

  final bool ring;

  static const double size = _Track.ring * 2;

  @override
  Widget build(BuildContext context) {
    final AgreementColors models = context.agreementColors;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _Track(
          avi: ring ? null : 0,
          esm: ring ? 0 : null,
          travelled: 1,
          line: null,
          joined: false,
          aviInk: models.avi,
          esmInk: models.esm,
          ground: Theme.of(context).colorScheme.surfaceContainer,
        ),
      ),
    );
  }
}

/// Under the tracks, which way they run: the milder predicted effect at the
/// start, the stronger at the end. On a narrow phone with type turned up the
/// two are drawn a little smaller rather than run off the card, as the
/// sheet's own scale is.
class _Ends extends StatelessWidget {
  const _Ends({required this.style});

  final TextStyle? style;

  static const double _gap = 16;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('agreement-ends'),
    children: <Widget>[
      const SizedBox(width: _letter),
      Expanded(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final TextScaler scaler = MediaQuery.textScalerOf(context);
            final TextStyle effective = DefaultTextStyle.of(context).style
                .merge(style);
            double width(String text) {
              final TextPainter painter = TextPainter(
                text: TextSpan(text: text, style: effective),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              final double width = painter.width;
              painter.dispose();
              return width;
            }

            const String milder = '← milder effect';
            const String stronger = 'stronger effect →';
            final double spare = box.maxWidth - width(milder) - width(stronger);
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(milder, style: style, maxLines: 1),
                  SizedBox(width: math.max(_gap, spare)),
                  Text(stronger, style: style, maxLines: 1),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

/// Two ranks on one track from the gene's milder end to its stronger: a
/// hairline, ESM-2's clay ring, AVI's denim dot inside a ring's room, and
/// between them a heavier rule shaded from the one to the other, the gap the
/// two models leave. A dot inside its ring is a change the two rank alike.
/// The marks set off from the milder end and travel to their places.
class _Track extends CustomPainter {
  _Track({
    required this.avi,
    required this.esm,
    required this.travelled,
    required this.line,
    required this.joined,
    required this.aviInk,
    required this.esmInk,
    required this.ground,
  });

  /// Where each mark stands, from 0 to 1; null draws none.
  final double? avi;
  final double? esm;
  final double travelled;
  final Color? line;

  /// Whether a rule joins the two marks.
  final bool joined;
  final Color aviInk;
  final Color esmInk;

  /// The card under the track, which fills the ring.
  final Color ground;

  static const double height = 12;
  static const double ring = 5;
  static const double _stroke = 1.75;
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
    if (joined && a != null && e != null && (a - e).abs() > 0.5) {
      canvas.drawLine(
        Offset(a, y),
        Offset(e, y),
        Paint()
          ..shader = ui.Gradient.linear(Offset(a, y), Offset(e, y), <Color>[
            aviInk,
            esmInk,
          ])
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
            ..color = esmInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke,
        );
    }
    if (a != null) {
      canvas.drawCircle(Offset(a, y), _dot, Paint()..color = aviInk);
    }
  }

  @override
  bool shouldRepaint(_Track old) =>
      old.avi != avi ||
      old.esm != esm ||
      old.travelled != travelled ||
      old.line != line ||
      old.joined != joined ||
      old.aviInk != aviInk ||
      old.esmInk != esmInk ||
      old.ground != ground;
}

/// How far the two agree across the gene: every missense substitution as a
/// dot, the rank correlation of them all, and how often the two order one
/// base's alike.
class _Across extends StatelessWidget {
  const _Across({required this.agreement, required this.marks});

  final GeneAgreement agreement;

  /// This base's missense substitutions, marked among the gene's.
  final List<AgreementRow> marks;

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
        const SizedBox(height: 10),
        _Scatter(agreement: agreement, marks: marks),
        const SizedBox(height: 4),
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

/// Every missense substitution of the gene as one dot, AVI's Phred across and
/// ESM-2's score up, and this base's own changes as balls in their amino
/// acids' colours, named.
class _Scatter extends StatelessWidget {
  const _Scatter({required this.agreement, required this.marks});

  final GeneAgreement agreement;
  final List<AgreementRow> marks;

  /// The plot's own height, before the room its words take.
  static const double _plot = 196;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle base = DefaultTextStyle.of(context).style;
    final TextStyle tick = base
        .merge(theme.caption)
        .copyWith(
          fontFamily: AppTypography.monoFamily,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        );
    final TextStyle name = base
        .merge(_mono)
        .copyWith(color: theme.colorScheme.onSurface);
    final TextPainter line = TextPainter(
      text: TextSpan(text: '0', style: tick),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final double words = line.height;
    line.dispose();
    // Each amino acid once, as the plot names it once.
    final List<String> named = <String>{
      for (final AgreementRow m in marks) m.spoken,
    }.toList();
    final String marked = switch (named.length) {
      0 => '',
      1 => '; marked: ${named.single}',
      _ =>
        '; marked: ${named.sublist(0, named.length - 1).join(', ')} and '
            '${named.last}',
    };
    return Semantics(
      container: true,
      label:
          'Every missense substitution in ${agreement.gene}, AVI Phred '
          'across and ESM-2 up$marked',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: _plot + words * 3 + 16,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey<String>('agreement-scatter'),
            painter: _ScatterPainter(
              agreement: agreement,
              marks: marks,
              cloud: theme.colorScheme.onSurfaceVariant,
              ink: theme.colorScheme.onSurface,
              ground: theme.scaffoldBackgroundColor,
              grid: theme.colorScheme.outlineVariant,
              models: context.agreementColors,
              residues: context.anatomyColors,
              tick: tick,
              name: name,
              scaler: scaler,
            ),
          ),
        ),
      ),
    );
  }
}

/// The scatter, drawn. Each model's larger effect lies up and to the right:
/// AVI's Phred runs from 0 to the sheet's own ceiling, 40, and ESM-2's score
/// from +5 at the foot to −15 at the top, so the two agreeing reads as a rise,
/// as their positive ρ does. A change past an end of either stands on it. The
/// cloud is fainter the more dots it holds, so that a dense gene still shows
/// where its dots gather.
class _ScatterPainter extends CustomPainter {
  _ScatterPainter({
    required this.agreement,
    required this.marks,
    required this.cloud,
    required this.ink,
    required this.ground,
    required this.grid,
    required this.models,
    required this.residues,
    required this.tick,
    required this.name,
    required this.scaler,
  });

  final GeneAgreement agreement;
  final List<AgreementRow> marks;
  final Color cloud;
  final Color ink;

  /// The two models' hues, for the marks their axes' names stand after.
  final AgreementColors models;

  /// The residue pages' colours, which this base's own changes wear: each
  /// ball the colour of the amino acid it makes, as the protein and chains
  /// pages draw it.
  final AnatomyColors residues;

  /// The page under the plot, which keeps a mark and its name clear of the
  /// dots behind them.
  final Color ground;
  final Color grid;
  final TextStyle tick;
  final TextStyle name;
  final TextScaler scaler;

  static const double _top = -15;
  static const double _foot = 5;
  static const List<double> _phreds = <double>[0, 10, 20, 30, 40];
  static const List<double> _scores = <double>[-15, -10, -5, 0, 5];

  @override
  void paint(Canvas canvas, Size size) {
    final List<TextPainter> painters = <TextPainter>[];
    TextPainter text(String value, TextStyle style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      painters.add(painter);
      return painter;
    }

    final List<TextPainter> across = <TextPainter>[
      for (final double v in _phreds) text(v.toStringAsFixed(0), tick),
    ];
    final List<TextPainter> up = <TextPainter>[
      for (final double v in _scores)
        text(
          v == 0
              ? '0'
              : '${v < 0 ? '\u2212' : '+'}${v.abs().toStringAsFixed(0)}',
          tick,
        ),
    ];
    final TextPainter avi = text('AVI Phred', tick);
    final TextPainter esm = text('ESM-2', tick);
    final double h = across.first.height;
    final Rect plot = Rect.fromLTRB(
      up.map((TextPainter p) => p.width).reduce(math.max) + 6,
      esm.height + 4 + h / 2,
      size.width - across.last.width / 2,
      size.height - h - 4 - avi.height - 2,
    );
    double x(double phred) =>
        plot.left +
        plot.width *
            phred.clamp(0.0, GeneImpact.barCeiling) /
            GeneImpact.barCeiling;
    double y(double score) =>
        plot.top +
        plot.height * (score.clamp(_top, _foot) - _top) / (_foot - _top);

    final Paint rule = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final (int i, double v) in _phreds.indexed) {
      final double at = x(v);
      canvas.drawLine(Offset(at, plot.top), Offset(at, plot.bottom), rule);
      final TextPainter label = across[i];
      label.paint(
        canvas,
        Offset(
          (at - label.width / 2).clamp(0.0, size.width - label.width),
          plot.bottom + 4,
        ),
      );
    }
    for (final (int i, double v) in _scores.indexed) {
      final double at = y(v);
      canvas.drawLine(Offset(plot.left, at), Offset(plot.right, at), rule);
      final TextPainter label = up[i];
      label.paint(
        canvas,
        Offset(plot.left - 6 - label.width, at - label.height / 2),
      );
    }
    // Each axis named after its model's mark, as the card's legend draws it.
    const double mark = _Track.ring * 2 + 4;
    canvas
      ..drawCircle(
        Offset(_Track.ring, esm.height / 2),
        _Track.ring - 0.875,
        Paint()
          ..color = models.esm
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.75,
      )
      ..drawCircle(
        Offset(
          size.width - avi.width - mark + _Track.ring,
          plot.bottom + 4 + h + 2 + avi.height / 2,
        ),
        3,
        Paint()..color = models.avi,
      );
    esm.paint(canvas, const Offset(mark, 0));
    avi.paint(canvas, Offset(size.width - avi.width, plot.bottom + 4 + h + 2));

    final List<ScoredChange> changes = agreement.changes;
    final Float32List points = Float32List(changes.length * 2);
    for (final (int i, ScoredChange c) in changes.indexed) {
      points[i * 2] = x(c.phred);
      points[i * 2 + 1] = y(c.esm);
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = cloud.withValues(
          alpha: (24 / math.sqrt(changes.length)).clamp(0.12, 0.5),
        )
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    // This base's own, in their amino acids' colours. Changes that make the
    // same amino acid share its name. A name goes to the first place, of beside its marks on
    // the side with room, above or below them, at a corner, or further off,
    // where it covers no mark and no other name; that failing, where it
    // covers least. Covering is worse than leaving the plot for its margin,
    // and the margin worse than leaving the canvas. A name set off from its
    // marks is led to the nearest of them by a hairline.
    final Map<String, List<Offset>> made = <String, List<Offset>>{};
    final Map<String, String> letters = <String, String>{};
    for (final AgreementRow m in marks) {
      final double? score = m.esm;
      if (score == null) continue;
      (made[m.tag] ??= <Offset>[]).add(Offset(x(m.score.phred), y(score)));
      letters[m.tag] = m.made ?? '';
    }
    final List<Offset> dots = <Offset>[
      for (final List<Offset> at in made.values) ...at,
    ];
    final List<Rect> taken = <Rect>[
      for (final Offset at in dots) Rect.fromCircle(center: at, radius: 6),
    ];
    final Rect room = plot.inflate(2);
    bool within(Rect box, Rect outer) =>
        box.left >= outer.left &&
        box.top >= outer.top &&
        box.right <= outer.right &&
        box.bottom <= outer.bottom;
    double cost(Rect box) {
      double covered = 0;
      for (final Rect other in taken) {
        final Rect both = other.intersect(box.inflate(2));
        if (both.width > 0 && both.height > 0) {
          covered += 1000 + both.width * both.height;
        }
      }
      return covered +
          (within(box, room) ? 0 : 100) +
          (within(box, Offset.zero & size) ? 0 : 100000);
    }

    final List<(TextPainter, Rect)> names = <(TextPainter, Rect)>[];
    final List<(Offset, Offset)> leads = <(Offset, Offset)>[];
    for (final MapEntry<String, List<Offset>> group in made.entries) {
      final TextPainter label = text(group.key, name);
      final double w = label.width;
      final double h = label.height;
      Rect marked = Rect.fromCircle(center: group.value.first, radius: 0);
      for (final Offset at in group.value) {
        marked = marked.expandToInclude(Rect.fromCircle(center: at, radius: 0));
      }
      final Offset right = Offset(marked.right + 8, marked.center.dy - h / 2);
      final Offset left = Offset(marked.left - 8 - w, marked.center.dy - h / 2);
      final List<Rect> tries = <Rect>[
        for (final Offset corner in <Offset>[
          if (marked.center.dx < plot.center.dx) ...<Offset>[
            right,
            left,
          ] else ...<Offset>[left, right],
          Offset(marked.center.dx - w / 2, marked.top - 8 - h),
          Offset(marked.center.dx - w / 2, marked.bottom + 8),
          Offset(marked.right + 6, marked.top - 6 - h),
          Offset(marked.left - 6 - w, marked.top - 6 - h),
          Offset(marked.right + 6, marked.bottom + 6),
          Offset(marked.left - 6 - w, marked.bottom + 6),
          Offset(marked.center.dx - w / 2, marked.top - 12 - h * 2),
          Offset(marked.center.dx - w / 2, marked.bottom + 12 + h),
        ])
          Rect.fromLTWH(corner.dx, corner.dy, w, h),
      ];
      Rect box = tries.first;
      double least = cost(box);
      for (final Rect other in tries.skip(1)) {
        final double paid = cost(other);
        if (paid < least) {
          box = other;
          least = paid;
        }
      }
      taken.add(box.inflate(2));
      names.add((label, box));
      Offset nearest = group.value.first;
      for (final Offset at in group.value) {
        if ((at - box.center).distance < (nearest - box.center).distance) {
          nearest = at;
        }
      }
      final Offset edge = Offset(
        nearest.dx.clamp(box.left, box.right),
        nearest.dy.clamp(box.top, box.bottom),
      );
      if ((edge - nearest).distance > 14) {
        final Offset towards = edge - nearest;
        leads.add((nearest + towards / towards.distance * 6, edge));
      }
    }
    final Paint halo = Paint()..color = ground;
    // Each ball in its amino acid's colour, as the residue pages draw it,
    // ringed by the ground so that a grey one stays clear of the cloud.
    for (final MapEntry<String, List<Offset>> group in made.entries) {
      final Paint ball = Paint()
        ..color = residues.forResidue(letters[group.key]!);
      for (final Offset at in group.value) {
        canvas
          ..drawCircle(at, 5.5, halo)
          ..drawCircle(at, 4, ball);
      }
    }
    final Paint lead = Paint()
      ..color = ink
      ..strokeWidth = 1;
    for (final (Offset from, Offset to) in leads) {
      canvas.drawLine(from, to, lead);
    }
    final Paint backing = Paint()..color = ground.withValues(alpha: 0.85);
    for (final (TextPainter label, Rect box) in names) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.inflate(2), const Radius.circular(3)),
        backing,
      );
      label.paint(canvas, box.topLeft);
    }
    for (final TextPainter p in painters) {
      p.dispose();
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter old) =>
      !identical(old.agreement, agreement) ||
      !listEquals(old.marks, marks) ||
      old.cloud != cloud ||
      old.ink != ink ||
      old.ground != ground ||
      old.grid != grid ||
      old.models != models ||
      old.residues != residues ||
      old.tick != tick ||
      old.name != name ||
      old.scaler != scaler;
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
              'Each missense substitution is placed twice on its track among '
              'the gene’s single-base missense substitutions: by AVI, the '
              'denim dot, and by ESM-2, the clay ring. A mark further right '
              'outranks more of the gene’s changes, by a higher Phred for '
              'AVI and a lower score for ESM-2, each its model’s stronger '
              'effect. The farther apart the two marks, the more the two '
              'models differ on that change.',
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
            'The scatter',
            line(
              'Every missense substitution in the gene as a dot: AVI’s Phred '
              'across, from 0 to 40, and ESM-2’s score up, from +5 at the '
              'foot to −15 at the top, so that each model’s larger effect '
              'lies up and to the right; each axis carries its model’s mark. '
              'A change past an end stands on it. This base’s own are balls '
              'in the colours their amino acids have on the protein and '
              'chains pages, each named.',
            ),
          ),
          section(
            'Across the gene',
            line(
              'Spearman’s rank correlation between AVI’s Phred and ESM-2’s '
              'score turned over, so that the two agreeing reads as positive, '
              'as the dots’ rise does. Same order: of every two missense '
              'substitutions at one base, the share both models put in the '
              'same order; pairs tied in either are left out, and half would '
              'be chance.',
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
                line('$_atlas. $_notice'),
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
