import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/evidence/impact_explanation_repository.dart';
import '../../../../core/evidence/impact_explanations.dart';
import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/format.dart';
import 'coding_evidence.dart';
import 'impact_panel.dart' show inkOn;

/// Every substitution at one base, side by side, with what the AVI model's
/// raw score is made of.
///
/// A stacked bar for each substitution shows its four groups at once — what
/// sets one substitution above another reads at a glance — and under it the
/// groups as rows, the substitutions as columns, each group opening onto its
/// features and an assay onto the track behind it. Opened from the base
/// sheet's "Contributions ›", over the walk, and closed back onto it. The
/// substitutions are the sheet's rows, in the sheet's order.
class ContributionsPage extends StatefulWidget {
  const ContributionsPage({
    required this.track,
    required this.impact,
    required this.address,
    this.region = '',
    this.tint,
    this.coding,
    this.repository,
    super.key,
  });

  final GeneImpact track;
  final BaseImpact impact;

  /// What the sheet calls the base: `c.73`.
  final String address;

  /// `exon 2`, `insulin B chain`: where the base sits, as the sheet says it.
  final String region;

  /// The colour the grid draws the base's region in, for its letter tile.
  /// No tile without it.
  final Color? tint;

  /// The codon the base sits in, for what each substitution makes of it.
  final CodingEvidence? coding;

  /// Where the payload comes from; the app's own when null.
  final ImpactExplanationRepository? repository;

  @override
  State<ContributionsPage> createState() => _ContributionsPageState();
}

class _ContributionsPageState extends State<ContributionsPage> {
  ImpactExplanationRepository? _repository;
  Future<GeneImpactExplanations>? _future;
  final Set<ContributionGroup> _groups = <ContributionGroup>{};
  final Set<String> _features = <String>{};
  bool _about = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ImpactExplanationRepository? repository =
        widget.repository ?? context.read<ImpactExplanationRepository?>();
    if (_future == null || !identical(_repository, repository)) {
      _repository = repository;
      _future = _repository?.load(widget.track);
    }
  }

  void _toggle<T>(Set<T> open, T value) => setState(() {
    if (!open.remove(value)) open.add(value);
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.address} · Contributions'),
          leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('contributions-info'),
              tooltip: 'About these values',
              isSelected: _about,
              onPressed: () => setState(() => _about = !_about),
              icon: const Icon(Icons.info_outline, size: 20),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<GeneImpactExplanations>(
            future: _future,
            builder: (
              BuildContext context,
              AsyncSnapshot<GeneImpactExplanations> snapshot,
            ) => _body(theme, snapshot),
          ),
        ),
      ),
    );
  }

  Widget _body(
    ThemeData theme,
    AsyncSnapshot<GeneImpactExplanations> snapshot,
  ) {
    final TextStyle? style = theme.caption;
    const EdgeInsets side = EdgeInsets.fromLTRB(16, 4, 16, 24);
    if (snapshot.connectionState != ConnectionState.done) {
      return Padding(
        padding: side,
        child: Text(
          'Loading AVI contributions…',
          style: style,
          key: const ValueKey<String>('contributions-loading'),
        ),
      );
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return Padding(
        padding: side,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('AVI contributions unavailable.', style: style),
            TextButton(
              key: const ValueKey<String>('contributions-retry'),
              onPressed: () {
                final Future<GeneImpactExplanations>? next = _repository?.load(
                  widget.track,
                );
                setState(() => _future = next);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final GeneImpactExplanations data = snapshot.data!;
    final List<_Column> columns = <_Column>[
      for (final AltScore score in widget.impact.ranked)
        if (ImpactExplanationRequest.forAllele(
              widget.track,
              widget.impact.position,
              widget.impact.wildtype,
              score.base,
            )
            case final ImpactExplanationRequest request)
          if (data.at(request) case final AlleleExplanation explanation)
            _Column(
              request: request,
              explanation: explanation,
              tag: widget.coding?.changeTo(score.base) ?? '',
            ),
    ];
    if (columns.isEmpty) {
      return Padding(
        padding: side,
        child: Text('No exact AVI contributions for this base.', style: style),
      );
    }
    return ListView(
      key: const ValueKey<String>('contributions-scroll'),
      padding: side,
      children: <Widget>[
        _Identity(
          base: widget.impact,
          region: widget.region,
          chromosome: widget.track.chromosome,
          tint: widget.tint,
        ),
        if (_about) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'SHAP attributions to the AVI model’s raw score, one per input '
            'feature, across Atlas genes and biosamples; a group is the sum '
            'of its features. Positive raises the score, negative lowers it. '
            'They are not parts of the Phred, and a sign says nothing about '
            'the direction of gene activity. '
            '${data.baseline == null ? '' : 'A substitution’s attributions add up to its raw score less the model’s baseline, ${_signed(data.baseline!)}. '}'
            'A track named under an assay had the largest absolute predicted '
            'effect for that substitution; the model reports the assay’s '
            'attribution, not the track.',
            key: const ValueKey<String>('contributions-about'),
            style: style,
          ),
        ],
        const SizedBox(height: 20),
        _Composition(columns: columns),
        const SizedBox(height: 28),
        _Breakdown(
          columns: columns,
          groups: _groups,
          features: _features,
          onGroup: (ContributionGroup g) => _toggle(_groups, g),
          onFeature: (String f) => _toggle(_features, f),
        ),
        const SizedBox(height: 24),
        Text(
          'AlphaGenome Atlas · saved ${data.generatedAt.substring(0, 10)}',
          key: const ValueKey<String>('contributions-source'),
          style: style,
        ),
      ],
    );
  }
}

/// One substitution's column: its request, what explains it, and its tag.
class _Column {
  const _Column({
    required this.request,
    required this.explanation,
    required this.tag,
  });
  final ImpactExplanationRequest request;
  final AlleleExplanation explanation;

  /// What the change makes of a coding base's codon — `Leu`, `=`, `Ter`, `?`.
  final String tag;
}

/// A signed value as the page prints it: `+0.706`, `−0.012`, `0`; a
/// fourth place where three would read as a signed zero (`−0.0001`), and an
/// exponent below that (`−3e-5`).
String _signed(double value) {
  if (value == 0) return '0';
  final String sign = value < 0 ? '\u2212' : '+';
  final double size = value.abs();
  return sign +
      (size >= 0.0005
          ? size.toStringAsFixed(3)
          : size >= 0.00005
          ? size.toStringAsFixed(4)
          : size.toStringAsExponential(0));
}

/// Each group's ink: one neutral, stepped in lightness from the first group
/// down, since a hue on this page would belong to ClinVar (R9.1). The steps
/// are far enough apart to tell side by side, and a 2-point gap of the ground
/// between neighbours does the rest.
Color _tone(ThemeData theme, ContributionGroup group) =>
    theme.colorScheme.onSurface.withValues(
      alpha: switch (group) {
        ContributionGroup.coding => 0.94,
        ContributionGroup.conservation => 0.64,
        ContributionGroup.splicing => 0.42,
        ContributionGroup.expression => 0.24,
      },
    );

const TextStyle _mono = TextStyle(
  fontFamily: AppTypography.monoFamily,
  fontSize: 13,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

/// The base as the sheet showed it: its letter on its region's tint, where it
/// sits, and its coordinate.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.base,
    required this.region,
    required this.chromosome,
    required this.tint,
  });

  final BaseImpact base;
  final String region;
  final String chromosome;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? fill = tint;
    return Row(
      key: const ValueKey<String>('contributions-identity'),
      children: <Widget>[
        if (fill != null) ...<Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              base.wildtype,
              style: TextStyle(
                fontFamily: AppTypography.monoFamily,
                fontSize: 21,
                color: inkOn(
                  fill,
                  dark: theme.colorScheme.surface,
                  light: context.anatomyColors.tracer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (region.isNotEmpty)
                Text(region, style: theme.textTheme.bodyMedium),
              Text(
                '$chromosome:${grouped(base.genomic)}',
                style: theme.caption?.copyWith(
                  fontFamily: AppTypography.monoFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The hero: each substitution's raw score drawn as its groups, end to end,
/// on one scale, so a longer bar is a larger sum and its make-up shows why.
class _Composition extends StatelessWidget {
  const _Composition({required this.columns});

  final List<_Column> columns;

  static double _add(double a, double b) => a + b;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool still = MediaQuery.disableAnimationsOf(context);
    final List<List<double>> totals = <List<double>>[
      for (final _Column c in columns)
        <double>[
          for (final ContributionGroup g in ContributionGroup.values)
            c.explanation.total(g),
        ],
    ];
    // One scale for every bar: the furthest any reaches right of zero, and
    // the furthest left, so that zero stands in one place.
    final double right = totals
        .map((List<double> t) => t.where((double v) => v > 0).fold(0.0, _add))
        .fold(0.0, math.max);
    final double left = totals
        .map((List<double> t) => -t.where((double v) => v < 0).fold(0.0, _add))
        .fold(0.0, math.max);
    final List<Color> tones = <Color>[
      for (final ContributionGroup g in ContributionGroup.values)
        _tone(theme, g),
    ];
    return Container(
      key: const ValueKey<String>('contributions-composition'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: still ? 1 : 0, end: 1),
        duration: still ? Duration.zero : const Duration(milliseconds: 900),
        builder: (BuildContext context, double t, Widget? legend) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (int i, _Column c) in columns.indexed) ...<Widget>[
              if (i > 0) const SizedBox(height: 14),
              _Bar(
                column: c,
                totals: totals[i],
                tones: tones,
                left: left,
                right: right,
                // Each bar a beat after the one above it.
                grown: Curves.easeOutCubic.transform(
                  ((t - i * 0.12) / 0.64).clamp(0.0, 1.0),
                ),
              ),
            ],
            const SizedBox(height: 16),
            legend!,
          ],
        ),
        child: Wrap(
          spacing: 14,
          runSpacing: 6,
          children: <Widget>[
            for (final ContributionGroup g in ContributionGroup.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Swatch(color: _tone(theme, g)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(g.label, style: theme.caption)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// One substitution in the hero: its base and what it makes, its Phred and
/// where that sits genome-wide, then its bar and the bar's sum.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.column,
    required this.totals,
    required this.tones,
    required this.left,
    required this.right,
    required this.grown,
  });

  final _Column column;
  final List<double> totals;
  final List<Color> tones;
  final double left;
  final double right;
  final double grown;

  static const double _letter = 26;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final double phred = column.explanation.phred;
    final String alt = column.request.alt;
    final String parts = <String>[
      for (final (int i, ContributionGroup g)
          in ContributionGroup.values.indexed)
        '${g.label} ${_signed(totals[i])}',
    ].join(', ');
    return Semantics(
      container: true,
      label:
          '$alt${column.tag.isEmpty ? '' : ', ${column.tag}'}, Phred '
          '${phred.toStringAsFixed(1)}: $parts; '
          'sum ${_signed(column.explanation.sum)}',
      excludeSemantics: true,
      child: Column(
        key: ValueKey<String>('contributions-bar-$alt'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              SizedBox(
                width: _letter,
                child: Text(alt, style: _mono.copyWith(fontSize: 17)),
              ),
              Text(column.tag, style: _mono.copyWith(color: muted)),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: phred.toStringAsFixed(1), style: _mono),
                      TextSpan(
                        text: ' Phred · ${genomeRank(phred)}',
                        style: theme.caption,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(width: _letter),
              Expanded(
                child: SizedBox(
                  height: 14,
                  child: CustomPaint(
                    painter: _StackPainter(
                      totals: totals,
                      tones: tones,
                      left: left,
                      right: right,
                      grown: grown,
                      zero: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _signed(column.explanation.sum),
                style: _mono.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A substitution's groups end to end from zero: positive ones to the right
/// in the groups' order, negative ones to the left, a 2-point gap of the
/// ground between neighbours, and the outer ends rounded.
class _StackPainter extends CustomPainter {
  const _StackPainter({
    required this.totals,
    required this.tones,
    required this.left,
    required this.right,
    required this.grown,
    required this.zero,
  });

  final List<double> totals;
  final List<Color> tones;
  final double left;
  final double right;
  final double grown;
  final Color zero;

  static const double _gap = 2;
  static const Radius _end = Radius.circular(4);

  @override
  void paint(Canvas canvas, Size size) {
    final double span = left + right;
    if (span <= 0) return;
    final double unit = size.width / span;
    final double origin = left * unit;
    for (final int sign in <int>[1, -1]) {
      final List<int> drawn = <int>[
        for (int g = 0; g < totals.length; g++)
          if (totals[g] * sign > 0 && totals[g].abs() * unit * grown >= 0.5) g,
      ];
      double at = origin;
      for (final (int n, int g) in drawn.indexed) {
        final double length = totals[g].abs() * unit * grown;
        final bool last = n == drawn.length - 1;
        final double shown = math.max(0.5, length - (last ? 0 : _gap));
        final Rect rect = sign > 0
            ? Rect.fromLTWH(at, 0, shown, size.height)
            : Rect.fromLTWH(at - shown, 0, shown, size.height);
        final RRect shape = !last
            ? RRect.fromRectAndCorners(rect)
            : sign > 0
            ? RRect.fromRectAndCorners(rect, topRight: _end, bottomRight: _end)
            : RRect.fromRectAndCorners(rect, topLeft: _end, bottomLeft: _end);
        canvas.drawRRect(shape, Paint()..color = tones[g]);
        at += sign * length;
      }
    }
    if (left > 0) {
      canvas.drawLine(
        Offset(origin, -3),
        Offset(origin, size.height + 3),
        Paint()
          ..color = zero
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_StackPainter old) =>
      old.grown != grown ||
      old.left != left ||
      old.right != right ||
      old.zero != zero ||
      !listEquals(old.totals, totals) ||
      !listEquals(old.tones, tones);
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2.5),
    ),
  );
}

/// The groups as rows and the substitutions as columns, each number over a
/// bar of its size on one scale, each group opening onto its features and an
/// assay onto its tracks.
class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.columns,
    required this.groups,
    required this.features,
    required this.onGroup,
    required this.onFeature,
  });

  final List<_Column> columns;
  final Set<ContributionGroup> groups;
  final Set<String> features;
  final ValueChanged<ContributionGroup> onGroup;
  final ValueChanged<String> onFeature;

  /// The chevron's column after the numbers.
  static const double _chevron = 22;

  /// How far a feature's name and a track's line sit in from their group's.
  static const double _indent = 14;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final TextStyle? name = theme.textTheme.bodyMedium;

    double measure(String text, TextStyle? style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double width = painter.width;
      painter.dispose();
      return width;
    }

    final double cell = math.max(60, measure('−0.0000', _mono) + 8);
    // The least room the names keep before the table scrolls sideways: the
    // longest word of any, indented as a feature's, so that a name wraps
    // between its words and never inside one.
    double word = 0;
    for (final ContributionGroup group in ContributionGroup.values) {
      for (final String label in <String>[
        group.label,
        ...group.features.values,
      ]) {
        for (final String part in label.split(' ')) {
          word = math.max(word, measure(part, name));
        }
      }
    }
    final double names = word + _indent + 2;
    // One scale for every little bar on the table: the largest value on it.
    double largest = 0;
    for (final _Column c in columns) {
      for (final ContributionGroup g in ContributionGroup.values) {
        largest = math.max(largest, c.explanation.total(g).abs());
        for (final String f in g.features.keys) {
          largest = math.max(largest, (c.explanation.values[f] ?? 0).abs());
        }
      }
    }

    Widget cells(List<double> values, Color tone, {required bool quiet}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final double value in values)
          SizedBox(
            width: cell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _signed(value),
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: _mono.copyWith(color: quiet ? muted : null),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: cell - 8,
                  height: 3,
                  child: CustomPaint(
                    painter: _CellBar(
                      fraction: largest == 0 ? 0 : value / largest,
                      tone: tone,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    Widget row({
      required Widget label,
      required Widget values,
      Widget? trailing,
      double minHeight = 44,
      Key? key,
    }) => ConstrainedBox(
      key: key,
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        children: <Widget>[
          Expanded(child: label),
          values,
          SizedBox(
            width: _chevron,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: trailing,
            ),
          ),
        ],
      ),
    );

    Widget opener({
      required Key key,
      required bool open,
      required String label,
      required VoidCallback onTap,
      required Widget child,
    }) => Semantics(
      button: true,
      expanded: open,
      label: label,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );

    Icon chevron(bool open) => Icon(
      open ? Icons.expand_more : Icons.chevron_right,
      size: 18,
      color: muted,
    );

    /// Each column's track behind [feature], one line apiece.
    List<Widget> tracks(String feature, double indent) => <Widget>[
      for (final _Column column in columns)
        if (column.explanation.winners[feature] case final TrackWinner w)
          Padding(
            key: ValueKey<String>(
              'contributions-track-$feature-${column.request.alt}',
            ),
            padding: EdgeInsetsDirectional.only(start: indent, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 20,
                  child: Text(
                    column.request.alt,
                    style: _mono.copyWith(color: muted),
                  ),
                ),
                Expanded(child: Text(_describe(w), style: theme.caption)),
              ],
            ),
          ),
    ];

    /// A feature's row: a way to its tracks where it has any, plain
    /// otherwise.
    Widget feature(MapEntry<String, String> entry, Color tone) {
      final Key key = ValueKey<String>('contributions-feature-${entry.key}');
      final bool tracked = columns.any(
        (_Column c) => c.explanation.winners.containsKey(entry.key),
      );
      final bool open = features.contains(entry.key);
      final Widget content = row(
        key: tracked ? null : key,
        label: Padding(
          padding: const EdgeInsetsDirectional.only(start: _indent),
          child: Text(entry.value, style: name?.copyWith(color: muted)),
        ),
        values: cells(
          <double>[
            for (final _Column c in columns)
              c.explanation.values[entry.key] ?? 0,
          ],
          tone,
          quiet: true,
        ),
        trailing: tracked ? chevron(open) : null,
      );
      return tracked
          ? opener(
              key: key,
              open: open,
              label: entry.value,
              onTap: () => onFeature(entry.key),
              child: content,
            )
          : content;
    }

    final List<Widget> body = <Widget>[
      row(
        key: const ValueKey<String>('contributions-header'),
        minHeight: 32,
        label: Text('By group', style: theme.textTheme.titleSmall),
        values: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final _Column column in columns)
              SizedBox(
                width: cell,
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: column.request.alt,
                        style: _mono.copyWith(fontSize: 15),
                      ),
                      if (column.tag.isNotEmpty)
                        TextSpan(
                          text: ' ${column.tag}',
                          style: _mono.copyWith(color: muted),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ),
      Divider(height: 12, color: theme.colorScheme.outlineVariant),
      for (final ContributionGroup group
          in ContributionGroup.values) ...<Widget>[
        opener(
          key: ValueKey<String>('contributions-group-${group.name}'),
          open: groups.contains(group),
          label: group.label,
          onTap: () => onGroup(group),
          child: row(
            minHeight: 52,
            label: Row(
              children: <Widget>[
                _Swatch(color: _tone(theme, group)),
                const SizedBox(width: 8),
                Expanded(child: Text(group.label, style: name)),
              ],
            ),
            values: cells(
              <double>[
                for (final _Column c in columns) c.explanation.total(group),
              ],
              _tone(theme, group),
              quiet: false,
            ),
            trailing: chevron(groups.contains(group)),
          ),
        ),
        if (groups.contains(group))
          if (group.features.length == 1)
            ...tracks(group.features.keys.single, _indent)
          else
            for (final MapEntry<String, String> entry
                in group.features.entries) ...<Widget>[
              feature(entry, _tone(theme, group)),
              if (features.contains(entry.key))
                ...tracks(entry.key, _indent * 2),
            ],
      ],
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double least = names + cell * columns.length + _chevron;
        final Widget table = Column(
          key: const ValueKey<String>('contributions-table'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: body,
        );
        // Type turned up past what a phone's width holds: the table keeps its
        // columns and scrolls sideways, rather than squeezing a number.
        return box.maxWidth >= least
            ? table
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: least, child: table),
              );
      },
    );
  }

  /// A track as a line: what kind of splice evidence it is, the factor or
  /// mark it reads, its biosample and its gene, where each applies.
  static String _describe(TrackWinner w) {
    final String kind = switch (w.scorer) {
      'SPLICE_SITES' => 'splice site',
      'SPLICE_SITE_USAGE' => 'site usage',
      'SPLICE_JUNCTIONS' => 'junction',
      _ => '',
    };
    return <String>[
      kind,
      w.target,
      w.biosample,
      w.gene,
    ].where((String part) => part.isNotEmpty).join(' · ');
  }
}

/// A value's size under its number, ending where the number ends: filled where
/// it raises the score, outlined where it lowers it.
class _CellBar extends CustomPainter {
  const _CellBar({required this.fraction, required this.tone});

  /// The value over the table's largest, signed.
  final double fraction;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final double length = size.width * fraction.abs().clamp(0.0, 1.0);
    if (length < 0.5) return;
    final RRect bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - length, 0, length, size.height),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      fraction > 0 ? bar : bar.deflate(0.5),
      Paint()
        ..color = tone
        ..style = fraction > 0 ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CellBar old) =>
      old.fraction != fraction || old.tone != tone;
}
