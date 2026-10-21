import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/evidence/gene_impact.dart';
import '../../../../core/evidence/impact_explanation_repository.dart';
import '../../../../core/evidence/impact_explanations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/inspector/impact_explanation_view.dart';
import 'coding_evidence.dart';

/// Every substitution at one base, side by side, with what the AVI model's
/// raw score is made of: its features added up in four groups, each group
/// opening onto its features, and an assay onto the track behind it.
///
/// Opened from the base sheet's "Contributions ›", over the walk, and closed
/// back onto it. The columns are the sheet's rows, in the sheet's order.
class ContributionsPage extends StatefulWidget {
  const ContributionsPage({
    required this.track,
    required this.impact,
    required this.address,
    this.coding,
    this.repository,
    super.key,
  });

  final GeneImpact track;
  final BaseImpact impact;

  /// What the sheet calls the base: `c.73`.
  final String address;

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
        ),
        body: SafeArea(
          child: FutureBuilder<GeneImpactExplanations>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<GeneImpactExplanations> snapshot) {
              final TextStyle? style = theme.caption;
              const EdgeInsets side = EdgeInsets.all(16);
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
                          final Future<GeneImpactExplanations>? next =
                              _repository?.load(widget.track);
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
                    if (data.at(request)
                        case final AlleleExplanation explanation)
                      _Column(
                        request: request,
                        explanation: explanation,
                        tag: widget.coding?.changeTo(score.base) ?? '',
                      ),
              ];
              if (columns.isEmpty) {
                return Padding(
                  padding: side,
                  child: Text(
                    'No exact AVI contributions for this base.',
                    style: style,
                  ),
                );
              }
              return ListView(
                key: const ValueKey<String>('contributions-scroll'),
                padding: side,
                children: <Widget>[
                  _Table(
                    columns: columns,
                    groups: _groups,
                    features: _features,
                    onGroup: (ContributionGroup g) => _toggle(_groups, g),
                    onFeature: (String f) => _toggle(_features, f),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'What these values are',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Signed SHAP attributions to the AVI model’s raw score, '
                    'one per input feature, across Atlas genes and biosamples; '
                    'a group is the sum of its features. Positive raises the '
                    'score, negative lowers it. They are not parts of the '
                    'Phred, and a sign says nothing about the direction of '
                    'gene activity. '
                    '${data.baseline == null ? '' : 'Each column adds up to its raw score less the model’s baseline, ${_signed(data.baseline!)}. '}'
                    'The track under an assay is the one with the largest '
                    'absolute predicted effect for that substitution; the '
                    'model reports the assay’s attribution, not which track '
                    'drove it.',
                    key: const ValueKey<String>('contributions-about'),
                    style: style,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AlphaGenome Atlas · saved ${data.generatedAt.substring(0, 10)}',
                    style: style,
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: <Widget>[
                      Text('View in Atlas', style: style),
                      for (final _Column column in columns)
                        TextButton.icon(
                          key: ValueKey<String>(
                            'contributions-atlas-${column.request.alt}',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          onPressed: () => openAtlasLink(
                            context,
                            data.atlasUrl(column.request),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: Text(
                            column.request.alt,
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFamily,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
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

/// A signed value as the table prints it: `+0.706`, `−0.012`, `0`.
String _signed(double value) => value == 0
    ? '0'
    : '${value < 0 ? '−' : '+'}${value.abs().toStringAsFixed(3)}';

/// The groups as rows and the substitutions as columns, each group opening
/// onto its features, an assay onto its tracks.
class _Table extends StatelessWidget {
  const _Table({
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
  static const double _indent = 12;

  static const TextStyle _mono = TextStyle(
    fontFamily: AppTypography.monoFamily,
    fontSize: 13,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextPainter widest = TextPainter(
      text: const TextSpan(text: '−0.000', style: _mono),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double cell = math.max(64, widest.width + 12);
    widest.dispose();
    final Color muted = theme.colorScheme.onSurfaceVariant;
    final TextStyle? name = theme.textTheme.bodyMedium;
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
          final TextPainter painter = TextPainter(
            text: TextSpan(text: part, style: name),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          word = math.max(word, painter.width);
          painter.dispose();
        }
      }
    }
    final double names = word + _indent + 4;

    Widget cells(List<String> values, {Color? color, FontWeight? weight}) =>
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String value in values)
              SizedBox(
                width: cell,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  style: _mono.copyWith(color: color, fontWeight: weight),
                ),
              ),
          ],
        );

    Widget row({
      required Widget label,
      required Widget values,
      Widget? trailing,
      double minHeight = 36,
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

    Icon chevron(bool open) =>
        Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18);

    /// Each column's track behind [feature], one line apiece.
    List<Widget> tracks(String feature, double indent) => <Widget>[
      for (final _Column column in columns)
        if (column.explanation.winners[feature] case final TrackWinner w)
          Padding(
            key: ValueKey<String>(
              'contributions-track-$feature-${column.request.alt}',
            ),
            padding: EdgeInsetsDirectional.only(start: indent, bottom: 6),
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

    final List<Widget> body = <Widget>[
      row(
        key: const ValueKey<String>('contributions-header'),
        label: const SizedBox.shrink(),
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
      row(
        key: const ValueKey<String>('contributions-phred'),
        label: Text('Phred', style: name?.copyWith(color: muted)),
        values: cells(<String>[
          for (final _Column c in columns)
            c.explanation.phred.toStringAsFixed(1),
        ], color: muted),
      ),
      for (final ContributionGroup group
          in ContributionGroup.values) ...<Widget>[
        opener(
          key: ValueKey<String>('contributions-group-${group.name}'),
          open: groups.contains(group),
          label: group.label,
          onTap: () => onGroup(group),
          child: row(
            minHeight: 44,
            label: Text(group.label, style: name),
            values: cells(<String>[
              for (final _Column c in columns)
                _signed(c.explanation.total(group)),
            ]),
            trailing: chevron(groups.contains(group)),
          ),
        ),
        if (groups.contains(group))
          if (group.features.length == 1)
            ...tracks(group.features.keys.single, _indent)
          else
            for (final MapEntry<String, String> feature
                in group.features.entries) ...<Widget>[
              if (columns.any(
                (_Column c) => c.explanation.winners.containsKey(feature.key),
              ))
                opener(
                  key: ValueKey<String>('contributions-feature-${feature.key}'),
                  open: features.contains(feature.key),
                  label: feature.value,
                  onTap: () => onFeature(feature.key),
                  child: row(
                    minHeight: 44,
                    label: Padding(
                      padding: const EdgeInsetsDirectional.only(start: _indent),
                      child: Text(
                        feature.value,
                        style: name?.copyWith(color: muted),
                      ),
                    ),
                    values: cells(<String>[
                      for (final _Column c in columns)
                        _signed(c.explanation.values[feature.key] ?? 0),
                    ], color: muted),
                    trailing: chevron(features.contains(feature.key)),
                  ),
                )
              else
                row(
                  key: ValueKey<String>('contributions-feature-${feature.key}'),
                  label: Padding(
                    padding: const EdgeInsetsDirectional.only(start: _indent),
                    child: Text(
                      feature.value,
                      style: name?.copyWith(color: muted),
                    ),
                  ),
                  values: cells(<String>[
                    for (final _Column c in columns)
                      _signed(c.explanation.values[feature.key] ?? 0),
                  ], color: muted),
                ),
              if (features.contains(feature.key))
                ...tracks(feature.key, _indent * 2),
            ],
      ],
      Divider(height: 16, color: theme.colorScheme.outlineVariant),
      row(
        key: const ValueKey<String>('contributions-sum'),
        label: Text('Sum', style: name),
        values: cells(<String>[
          for (final _Column c in columns) _signed(c.explanation.sum),
        ]),
      ),
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
