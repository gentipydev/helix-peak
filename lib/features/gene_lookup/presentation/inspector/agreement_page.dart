import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Float32List, listEquals;
import 'package:flutter/material.dart';

import '../../../../core/evidence/gene_clinvar.dart';
import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/evidence/variant_evidence.dart';
import '../../../../core/theme/agreement_colors.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/clinvar/clinvar_colors.dart';
import '../../../../shared/clinvar/evidence_row.dart';
import '../../../../shared/format.dart';
import '../../../../shared/inspector/score_bar.dart';
import 'base_identity.dart';
import 'clinvar_agreement.dart';
import 'coding_evidence.dart';
import 'gene_agreement.dart';

/// A base's substitutions as AVI and ESM-2 each read them, side by side, and
/// as ClinVar classifies them where it has a record at the base.
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
///
/// Where ClinVar has a record at the base the page compares all three (the
/// user's ask, 2026-10-25): each change carries ClinVar's own words for it,
/// the scatter marks the gene's ClinVar records by class, and a table sets
/// each class's middle scores beside the gene's. Hue is then ClinVar's alone
/// (R9.1): the two models' marks are the page's ink, told apart by shape.
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
    this.records = const <VariantEvidence>[],
    this.clinvar,
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

  /// ClinVar's records at this base, in transcript order. None leaves the
  /// page to the two models, as it was before ClinVar joined it.
  final List<VariantEvidence> records;

  /// Where the gene's ClinVar missense records stand on both models' scales,
  /// or null where none is placed.
  final ClinVarAgreement? clinvar;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    // With ClinVar on the page hue is ClinVar's alone (R9.1): the two models'
    // denim and clay sit about 10 apart from its benign blue and pathogenic
    // rose, nearer than its own classes stand to one another. Their marks
    // take the page's ink, the dot and the ring parting by shape.
    final bool observed = records.isNotEmpty;
    final Color ink = base.colorScheme.onSurface;
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
      extensions: observed
          ? <ThemeExtension<dynamic>>[
              // Every other extension as it was. The cast is the one Flutter's
              // own ThemeData makes: the compiler asks for it, the analyzer
              // does not.
              for (final ThemeExtension<dynamic> extension
                  in base.extensions.values)
                if (extension is! AgreementColors)
                  extension as ThemeExtension<ThemeExtension<dynamic>>,
              AgreementColors(avi: ink, esm: ink),
            ]
          : null,
    );
    final TextStyle? style = theme.caption;
    final GeneAgreement? gene = agreement;
    final List<AgreementRow> rows = AgreementRow.at(
      impact,
      coding,
      gene,
      records: records,
    );
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            observed
                ? '$address · AVI, ESM-2 and ClinVar'
                : '$address · AVI and ESM-2',
          ),
          leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
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
              _Card(rows: rows, gene: track.gene, observed: observed),
              if (gene != null) ...<Widget>[
                const SizedBox(height: 24),
                _Across(
                  agreement: gene,
                  marks: <AgreementRow>[
                    for (final AgreementRow row in rows)
                      if (row.esm != null) row,
                  ],
                  observed: observed,
                  clinvar: observed ? clinvar : null,
                ),
              ],
              const SizedBox(height: 24),
              Column(
                key: const ValueKey<String>('agreement-source'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    observed ? _credits : _credit,
                    style: style?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(_compared, style: style),
                  if (observed) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(_independence, style: style),
                  ],
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

/// The two sources, as the page names them.
const String _credit = 'AlphaGenome Atlas · ESM-2';

/// The three, where ClinVar has a record at the base.
const String _credits = 'AlphaGenome Atlas · ESM-2 · ClinVar';

/// What ClinVar's part is, and what it is not, said once on the page that
/// sets it beside the models (R9.4).
const String _independence =
    'ClinVar’s classifications are quoted as its snapshot gives them; they '
    'are not an independent test of either model: AVI draws on '
    'AlphaMissense, and submitters may have weighed computational '
    'predictions.';

/// What the two are and how the page sets them side by side, in one line.
const String _compared =
    'AVI (AlphaGenome Atlas) scores each change from the DNA, ESM-2 the '
    'amino acid it makes from the protein sequence; both are ranked here '
    'among the gene’s missense substitutions.';

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

/// ClinVar's mark beside a change's tag, as the sheet's rows draw it.
const double _dot = 9;

/// The room a row keeps for that mark, so that every tag stands in line.
const double _slot = _dot + 4;

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
/// after another, and under the tracks which way the effect grows. Where
/// ClinVar has a record at the base, each change it has a record of carries
/// its mark beside the tag and its words under the track.
class _Card extends StatelessWidget {
  const _Card({required this.rows, required this.gene, required this.observed});

  final List<AgreementRow> rows;
  final String gene;

  /// Whether ClinVar has a record at the base.
  final bool observed;

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
              _letter + (observed ? _slot : 0) + tags + 12 + numbers >
                  box.maxWidth;
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
                    observed: observed,
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
/// two ranks on a track or why only AVI applies; and where ClinVar has a
/// record of it, ClinVar's mark beside what it makes and its words under the
/// track.
class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.gene,
    required this.stacked,
    required this.headed,
    required this.observed,
    required this.aviColumn,
    required this.esmColumn,
    required this.travelled,
  });

  final AgreementRow row;
  final String gene;
  final bool stacked;

  /// Whether the columns are headed: ESM-2's is drawn, and the marks named.
  final bool headed;

  /// Whether ClinVar has a record at the base, so that every row keeps room
  /// for its mark.
  final bool observed;
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
      for (final VariantEvidence e in row.records)
        'ClinVar ${e.variant.classification}'
            '${e.variant.stars > 0 ? ', ${e.variant.stars} of 4 review stars' : ''}',
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
    final List<VariantEvidence> records = row.records;
    final Text tag = Text(row.tag, style: _mono.copyWith(color: muted));
    final Widget label = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        SizedBox(
          width: _letter,
          child: Text(alt, style: _mono.copyWith(fontSize: 17)),
        ),
        // ClinVar's mark where it has a record of the change, as the sheet
        // marks the change's bar, in a slot every row keeps on such a page.
        if (observed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: _slot,
                child: records.isEmpty
                    ? null
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ClinVarDot(
                          key: ValueKey<String>('agreement-mark-$alt'),
                          group: ClinVarGroup.mostSevere(
                            records.map((VariantEvidence e) => e.variant.group),
                          ),
                          size: _dot,
                        ),
                      ),
              ),
              tag,
            ],
          )
        else
          tag,
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
                    // Two marks in one ink are joined by a quieter rule, so
                    // that the marks, not the gap, carry the row.
                    rule: observed ? muted : null,
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
          // ClinVar's words for the change, quoted as its record's row
          // quotes them: the review stars, then the classification.
          if (records.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _letter, top: 4),
              child: ClinVarSourced(
                child: Column(
                  key: ValueKey<String>('agreement-clinvar-$alt'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final VariantEvidence e in records)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (e.variant.stars > 0) ...<Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: ReviewStars(count: e.variant.stars),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              e.variant.classification,
                              style: caption,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
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
    this.rule,
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

  /// The joining rule's one colour; null shades it from the dot's ink to the
  /// ring's.
  final Color? rule;

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
      final Paint paint = Paint()..strokeWidth = 2.5;
      if (rule case final Color plain) {
        paint.color = plain;
      } else {
        paint.shader = ui.Gradient.linear(
          Offset(a, y),
          Offset(e, y),
          <Color>[aviInk, esmInk],
        );
      }
      canvas.drawLine(Offset(a, y), Offset(e, y), paint);
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
      old.ground != ground ||
      old.rule != rule;
}

/// How far the two agree across the gene: every missense substitution as a
/// dot, the rank correlation of them all, and how often the two order one
/// base's alike. Where ClinVar has a record at the base, the gene's ClinVar
/// records are marked by class among the dots, and each class's middle
/// scores stand under the numbers, beside the gene's.
class _Across extends StatelessWidget {
  const _Across({
    required this.agreement,
    required this.marks,
    this.observed = false,
    this.clinvar,
  });

  final GeneAgreement agreement;

  /// This base's missense substitutions, marked among the gene's.
  final List<AgreementRow> marks;

  /// Whether ClinVar has a record at the base.
  final bool observed;

  /// The gene's ClinVar missense records on both models' scales.
  final ClinVarAgreement? clinvar;

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
        _Scatter(
          agreement: agreement,
          marks: marks,
          observed: observed,
          clinvar: clinvar,
        ),
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
        if (clinvar case final ClinVarAgreement placed) ...<Widget>[
          const SizedBox(height: 20),
          _ClinVarClasses(clinvar: placed, agreement: agreement),
        ],
      ],
    );
  }
}

/// Where ClinVar's classes stand among the gene's missense substitutions:
/// each class's records counted, and the middle of each model's scores for
/// them, in the models' own units, over the gene's own middle. It places the
/// classes and judges no record.
class _ClinVarClasses extends StatelessWidget {
  const _ClinVarClasses({required this.clinvar, required this.agreement});

  final ClinVarAgreement clinvar;
  final GeneAgreement agreement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? caption = theme.caption;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle base = DefaultTextStyle.of(context).style;
    double measure(String text, TextStyle? style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    // Each class ClinVar has records in, in the order a reader scans them,
    // then the gene's every missense substitution, which they are read
    // against.
    final List<_ClassRow> rows = <_ClassRow>[
      for (final ClinVarClass c in clinvar.classes)
        _ClassRow(
          key: c.group.name,
          group: c.group,
          label: c.group.short,
          count: c.records,
          phred: c.phred,
          esm: c.esm,
        ),
      _ClassRow(
        key: 'all',
        label: 'Every substitution',
        count: agreement.count,
        phred: agreement.medianPhred,
        esm: agreement.medianEsm,
      ),
    ];
    double widest(Iterable<String> texts, TextStyle? style) =>
        texts.map((String t) => measure(t, style)).reduce(math.max);
    final double counts = widest(<String>[
      for (final _ClassRow row in rows) grouped(row.count),
    ], _mono);
    final double phreds = math.max(
      measure('AVI Phred', caption),
      widest(<String>[for (final _ClassRow row in rows) row.phredText], _mono),
    );
    final double esms = math.max(
      measure('ESM-2', caption),
      widest(<String>[for (final _ClassRow row in rows) row.esmText], _mono),
    );
    final double labels = widest(<String>[
      for (final _ClassRow row in rows) row.label,
    ], theme.textTheme.bodyMedium);
    Widget cell(String text, double width, String key) => SizedBox(
      width: width,
      child: Text(
        text,
        key: ValueKey<String>(key),
        style: _mono,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.end,
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        // In columns where the labels and the three columns fit side by
        // side; otherwise each class's two medians on a line under it.
        final bool stacked =
            stackScoreLabels(context) ||
            _slot + labels + 12 + counts + 2 * _columnGap + phreds + esms >
                box.maxWidth;
        Widget name(_ClassRow row) {
          // Wrapped between words where the medians stand under it, so that
          // large type never cuts a name.
          final Text text = Text(
            row.label,
            style: theme.textTheme.bodyMedium,
            maxLines: stacked ? null : 1,
            overflow: stacked ? null : TextOverflow.ellipsis,
          );
          return Row(
            children: <Widget>[
              SizedBox(
                width: _slot,
                child: row.group == null
                    ? null
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ClinVarDot(group: row.group!, size: _dot),
                      ),
              ),
              Flexible(
                child: row.group == null ? text : ClinVarSourced(child: text),
              ),
            ],
          );
        }

        return Column(
          key: const ValueKey<String>('agreement-clinvar-classes'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'ClinVar’s missense records',
              style: theme.textTheme.titleSmall,
            ),
            // The two columns headed once, over their numbers, as the card's
            // legend heads its own.
            if (!stacked) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Spacer(),
                  SizedBox(
                    width: phreds,
                    child: Text(
                      'AVI Phred',
                      style: caption,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: _columnGap),
                  SizedBox(
                    width: esms,
                    child: Text('ESM-2', style: caption, textAlign: TextAlign.end),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            for (final _ClassRow row in rows)
              Semantics(
                container: true,
                label: row.spoken,
                excludeSemantics: true,
                child: Padding(
                  key: ValueKey<String>('agreement-clinvar-class-${row.key}'),
                  padding: const EdgeInsets.only(top: 6),
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(child: name(row)),
                                const SizedBox(width: 12),
                                Text(grouped(row.count), style: _mono),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: _slot,
                                top: 2,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(text: 'AVI Phred ', style: caption),
                                    TextSpan(text: row.phredText, style: _mono),
                                    TextSpan(text: '   ESM-2 ', style: caption),
                                    TextSpan(text: row.esmText, style: _mono),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: <Widget>[
                            Expanded(child: name(row)),
                            const SizedBox(width: 12),
                            cell(
                              grouped(row.count),
                              counts,
                              'agreement-clinvar-count-${row.key}',
                            ),
                            const SizedBox(width: _columnGap),
                            cell(
                              row.phredText,
                              phreds,
                              'agreement-clinvar-avi-${row.key}',
                            ),
                            const SizedBox(width: _columnGap),
                            cell(
                              row.esmText,
                              esms,
                              'agreement-clinvar-esm-${row.key}',
                            ),
                          ],
                        ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text('medians', style: caption),
            ),
          ],
        );
      },
    );
  }
}

/// One line of the class table.
final class _ClassRow {
  const _ClassRow({
    required this.key,
    required this.label,
    required this.count,
    required this.phred,
    required this.esm,
    this.group,
  });

  final String key;

  /// ClinVar's class, or null for the gene's every substitution.
  final ClinVarGroup? group;
  final String label;
  final int count;
  final double phred;
  final double esm;

  String get phredText => _tenths(phred).toStringAsFixed(1);
  String get esmText => formatScore(_tenths(esm));

  /// [value] to one place. A median of an even count can fall halfway
  /// between two places (Other's Phreds in insulin, 29.55), and the single
  /// precision a Phred is held to would tip such a tie either way; it is
  /// rounded away from zero, as the stored decimals would round.
  static double _tenths(double value) =>
      (value.abs() * 10 + 1e-4).round() / 10 * value.sign;

  String get spoken =>
      '$label: ${grouped(count)} ${group == null ? 'missense substitutions' : 'record${count == 1 ? '' : 's'}'}; '
      'median AVI Phred $phredText; median ESM-2 $esmText';
}

/// Every missense substitution of the gene as one dot, AVI's Phred across and
/// ESM-2's score up, and this base's own changes as balls in their amino
/// acids' colours, named. Where ClinVar has a record at the base, the gene's
/// ClinVar records are marked by class, and this base's changes are rings of
/// the page's ink round their own ClinVar mark, so that hue stays ClinVar's.
class _Scatter extends StatelessWidget {
  const _Scatter({
    required this.agreement,
    required this.marks,
    required this.observed,
    this.clinvar,
  });

  final GeneAgreement agreement;
  final List<AgreementRow> marks;
  final bool observed;
  final ClinVarAgreement? clinvar;

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
    final ClinVarAgreement? placed = clinvar;
    final String classified = placed == null
        ? ''
        : '; ClinVar’s ${grouped(placed.records)} missense '
              'record${placed.records == 1 ? '' : 's'} marked by class';
    return Semantics(
      container: true,
      label:
          'Every missense substitution in ${agreement.gene}, AVI Phred '
          'across and ESM-2 up, about the line where the two would rank them '
          'alike$classified$marked',
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
              observed: observed,
              clinvar: placed?.marks ?? const <ClinVarMarked>[],
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
    required this.observed,
    required this.clinvar,
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

  /// Whether ClinVar has a record at the base: this base's changes are then
  /// rings of the page's ink, round their own ClinVar mark where they have
  /// one, rather than balls in their amino acids' colours.
  final bool observed;

  /// The gene's changes ClinVar has a record of, each in its most severe
  /// class.
  final List<ClinVarMarked> clinvar;
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

  /// A ClinVar record's mark, and the ground round it that keeps it clear of
  /// the cloud and of the marks under it.
  static const double _record = 3;
  static const double _halo = 1.2;

  /// This base's own change on a page with ClinVar: an ink ring this wide.
  static const double _ring = 6.5;

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

    // Where every dot would stand if the two models ranked the gene's changes
    // alike, ρ 1: each Phred beside the ESM-2 score of the same rank, dashed
    // in the page's ink, over the cloud and under this base's own.
    final List<(double, double)> equal = agreement.equalRanks();
    final Path alike = Path();
    for (final (int i, (double, double) at) in equal.indexed) {
      final Offset point = Offset(x(at.$1), y(at.$2));
      if (i == 0) {
        alike.moveTo(point.dx, point.dy);
      } else {
        alike.lineTo(point.dx, point.dy);
      }
    }
    final Paint dash = Paint()
      ..color = ink.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final ui.PathMetric metric in alike.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 5, metric.length)),
          dash,
        );
      }
    }

    // ClinVar's records, over the cloud and the line: each change once, in
    // its most severe class, the most severe drawn last so that it lies on
    // top. A class of discs is drawn as one set of points, the ground first;
    // Other is a ring, drawn as the rest of the app draws it.
    final List<Offset> recorded = <Offset>[
      for (final ClinVarMarked m in clinvar)
        Offset(x(m.change.phred), y(m.change.esm)),
    ];
    for (final ClinVarGroup group in ClinVarGroup.bySeverity.reversed) {
      final List<Offset> at = <Offset>[
        for (final (int i, ClinVarMarked m) in clinvar.indexed)
          if (m.group == group) recorded[i],
      ];
      if (at.isEmpty) continue;
      if (ClinVarColors.hollow(group)) {
        for (final Offset point in at) {
          ClinVarColors.paintMark(canvas, point, _record, group, halo: ground);
        }
        continue;
      }
      final Float32List points = Float32List(at.length * 2);
      for (final (int i, Offset point) in at.indexed) {
        points[i * 2] = point.dx;
        points[i * 2 + 1] = point.dy;
      }
      canvas
        ..drawRawPoints(
          ui.PointMode.points,
          points,
          Paint()
            ..color = ground
            ..strokeWidth = (_record + _halo) * 2
            ..strokeCap = StrokeCap.round,
        )
        ..drawRawPoints(
          ui.PointMode.points,
          points,
          Paint()
            ..color = ClinVarColors.of(group)
            ..strokeWidth = _record * 2
            ..strokeCap = StrokeCap.round,
        );
    }

    // This base's own, in their amino acids' colours, or on a page with
    // ClinVar as ink rings. Changes that make the
    // same amino acid share its name. A name goes to the first place, of
    // beside its marks on the side with room, above or below them, at a
    // corner, or further off, where it covers no mark and no other name; that
    // failing, where it covers least. Covering is worse than leaving the plot
    // for its margin, and the margin worse than leaving the canvas. A name
    // set off from its marks is led to the nearest of them by a hairline. The
    // line's own name, ρ = 1, comes last, beside the line where it is clear.
    final Map<String, List<Offset>> made = <String, List<Offset>>{};
    final Map<String, String> letters = <String, String>{};
    // Each change of this base with the class of ClinVar's records of it,
    // for the rings of a page with ClinVar.
    final List<(Offset, ClinVarGroup?)> own = <(Offset, ClinVarGroup?)>[];
    for (final AgreementRow m in marks) {
      final double? score = m.esm;
      if (score == null) continue;
      final Offset at = Offset(x(m.score.phred), y(score));
      (made[m.tag] ??= <Offset>[]).add(at);
      letters[m.tag] = m.made ?? '';
      own.add((
        at,
        m.records.isEmpty
            ? null
            : ClinVarGroup.mostSevere(
                m.records.map((VariantEvidence e) => e.variant.group),
              ),
      ));
    }
    final List<Offset> dots = <Offset>[
      for (final List<Offset> at in made.values) ...at,
    ];
    // A name covers no mark of this base's and no other name. ClinVar's
    // records, many and small, it covers only where it must, the fewer the
    // better.
    final List<Rect> taken = <Rect>[
      for (final Offset at in dots)
        Rect.fromCircle(center: at, radius: observed ? _ring + 1.5 : 6),
    ];
    final List<Rect> records = <Rect>[
      for (final Offset at in recorded)
        Rect.fromCircle(center: at, radius: _record + _halo),
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
      for (final Rect record in records) {
        if (record.overlaps(box.inflate(2))) {
          covered += 10;
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
          // ClinVar's records crowd the plot, so on its page a name may go
          // further off, its hairline leading it back.
          if (observed) ...<Offset>[
            Offset(marked.right + 22, marked.center.dy - h / 2),
            Offset(marked.left - 22 - w, marked.center.dy - h / 2),
            Offset(marked.right + 16, marked.top - 16 - h * 2),
            Offset(marked.left - 16 - w, marked.top - 16 - h * 2),
            Offset(marked.right + 16, marked.bottom + 16 + h),
            Offset(marked.left - 16 - w, marked.bottom + 16 + h),
            Offset(marked.center.dx - w / 2, marked.top - 20 - h * 3),
            Offset(marked.center.dx - w / 2, marked.bottom + 20 + h * 2),
          ],
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
    final TextPainter one = text('ρ = 1', tick);
    final List<Rect> beside = <Rect>[
      for (final double share in <double>[0.97, 0.85, 0.7, 0.5, 0.3])
        if (equal[(share * (equal.length - 1)).round()] case (
          final double p,
          final double e,
        ))
          for (final Offset corner in <Offset>[
            // Over the line and to its left, then under it and to its right.
            Offset(x(p) - 6 - one.width, y(e) - 6 - one.height),
            Offset(x(p) + 6, y(e) + 6),
          ])
            Rect.fromLTWH(corner.dx, corner.dy, one.width, one.height),
    ];
    Rect place = beside.first;
    double paid = cost(place);
    for (final Rect other in beside.skip(1)) {
      final double price = cost(other);
      if (price < paid) {
        place = other;
        paid = price;
      }
    }
    taken.add(place.inflate(2));
    names.add((one, place));
    final Paint halo = Paint()..color = ground;
    if (observed) {
      // Each a ring of the page's ink round the change's own ClinVar mark,
      // or round an ink dot where ClinVar has no record of it: the hue on
      // the plot is ClinVar's alone.
      final Paint ring = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final Paint dot = Paint()..color = ink;
      for (final (Offset at, ClinVarGroup? group) in own) {
        canvas
          ..drawCircle(at, _ring + 1.5, halo)
          ..drawCircle(at, _ring, ring);
        if (group == null) {
          canvas.drawCircle(at, 2.5, dot);
        } else {
          ClinVarColors.paintMark(canvas, at, 3.5, group);
        }
      }
    } else {
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
      old.observed != observed ||
      !identical(old.clinvar, clinvar) ||
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
