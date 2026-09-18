import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/anatomy_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/protein_constraint.dart';
import '../format.dart';
import 'constraint_colors.dart';

/// A nonmodal sheet: the exposed grid remains interactive at every height.
class ConstraintPanel extends StatefulWidget {
  const ConstraintPanel({
    required this.residue,
    required this.length,
    required this.controller,
    required this.slide,
    required this.pinIdentity,
    required this.onDismiss,
    super.key,
  });

  static const double minimumSize = 0.18;
  static const double initialSize = 0.62;
  static const double maximumSize = 0.92;

  final ResidueConstraint residue;

  /// Residues in the precursor [residue] is numbered against.
  final int length;
  final DraggableScrollableController controller;
  final Animation<Offset> slide;
  final bool pinIdentity;
  final VoidCallback onDismiss;

  @override
  State<ConstraintPanel> createState() => _ConstraintPanelState();
}

class _ConstraintPanelState extends State<ConstraintPanel> {
  ScrollController? _scroll;
  bool _expanded = false;
  bool _explanation = false;
  double _compactSize = 0.32;
  Offset? _dragOrigin;
  bool _canDismissDrag = false;

  void _beginDrag(PointerDownEvent event) {
    _dragOrigin = event.position;
    _canDismissDrag =
        widget.controller.isAttached &&
        widget.controller.size <= _compactSize + 0.01 &&
        (event.localPosition.dy <= 44 ||
            !(_scroll?.hasClients ?? false) ||
            _scroll!.offset <= 0);
  }

  void _endDrag(PointerUpEvent event) {
    final Offset travel = event.position - (_dragOrigin ?? event.position);
    if (_canDismissDrag &&
        travel.dy > 48 &&
        travel.dy > travel.dx.abs() * 1.5) {
      widget.onDismiss();
    }
    _dragOrigin = null;
    _canDismissDrag = false;
  }

  @override
  void didUpdateWidget(ConstraintPanel old) {
    super.didUpdateWidget(old);
    if (old.residue.index != widget.residue.index) {
      // Keep the chosen height and disclosure preference, but start the new
      // ranking at its top. Scroll notifications must follow the rebuild.
      final int index = widget.residue.index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.residue.index == index &&
            (_scroll?.hasClients ?? false)) {
          _scroll!.jumpTo(0);
        }
      });
    }
  }

  void _moveTo(double target) {
    if (!widget.controller.isAttached) {
      return;
    }
    if (target == _compactSize && (_scroll?.hasClients ?? false)) {
      _scroll!.jumpTo(0);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.controller.jumpTo(target);
    } else {
      unawaited(
        widget.controller.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _toggleExplanation() {
    setState(() => _explanation = !_explanation);
    if (!_explanation) {
      return;
    }
    if (widget.controller.isAttached &&
        widget.controller.size < ConstraintPanel.initialSize) {
      _moveTo(ConstraintPanel.initialSize);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_explanation || !(_scroll?.hasClients ?? false)) {
        return;
      }
      // The info button stays available while reading the lower scores. Bring
      // its newly opened explanation into view without changing sheet height.
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll!.jumpTo(0);
      } else {
        unawaited(
          _scroll!.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    });
  }

  void _dragHandle(DragUpdateDetails details) {
    if (widget.controller.isAttached) {
      widget.controller.jumpTo(
        (widget.controller.size -
                widget.controller.pixelsToSize(details.primaryDelta ?? 0))
            .clamp(_compactSize, ConstraintPanel.maximumSize),
      );
    }
  }

  void _settleHandle(DragEndDetails details) {
    if (!widget.controller.isAttached) {
      return;
    }
    final double size = widget.controller.size;
    final double velocity = details.primaryVelocity ?? 0;
    final List<double> stops = <double>[
      _compactSize,
      ConstraintPanel.initialSize,
      ConstraintPanel.maximumSize,
    ];
    final double target;
    if (velocity < -500) {
      target = stops.firstWhere(
        (double stop) => stop > size + 0.01,
        orElse: () => stops.last,
      );
    } else if (velocity > 500) {
      target = stops.lastWhere(
        (double stop) => stop < size - 0.01,
        orElse: () => stops.first,
      );
    } else {
      target = stops.reduce(
        (double a, double b) => (a - size).abs() < (b - size).abs() ? a : b,
      );
    }
    _moveTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool still = MediaQuery.disableAnimationsOf(context);
    final Duration crossfade = still
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final Widget identity = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: AnimatedSwitcher(
        duration: crossfade,
        child: _ResidueIdentity(
          key: ValueKey<int>(widget.residue.index),
          residue: widget.residue,
          length: widget.length,
          explanation: _explanation,
          onExplain: _toggleExplanation,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bounds) {
        // Handle, identity, tolerance badge and a little breathing room. Scale
        // the stop with text rather than spending a fixed fraction of the phone.
        _compactSize =
          ((56 + MediaQuery.textScalerOf(context).scale(100)) /
                    bounds.maxHeight)
                .clamp(
                  ConstraintPanel.minimumSize,
                  ConstraintPanel.initialSize - 0.01,
                );
        return DraggableScrollableSheet(
          controller: widget.controller,
          initialChildSize: ConstraintPanel.initialSize,
          minChildSize: _compactSize,
          shouldCloseOnMinExtent: false,
          maxChildSize: ConstraintPanel.maximumSize,
          snap: true,
          snapSizes: const <double>[ConstraintPanel.initialSize],
          snapAnimationDuration: Duration(milliseconds: still ? 1 : 220),
          expand: false,
          builder: (BuildContext context, ScrollController scroll) {
            _scroll = scroll;
            return Listener(
              onPointerDown: _beginDrag,
              onPointerUp: _endDrag,
              onPointerCancel: (_) {
                _dragOrigin = null;
                _canDismissDrag = false;
              },
              child: SlideTransition(
                position: widget.slide,
                child: GestureDetector(
                  // Diagonal drags in the sheet must not turn the molecule's page.
                  onHorizontalDragEnd: (_) {},
                  child: Material(
                    key: const ValueKey<String>('constraint-sheet-surface'),
                    color: colors.surfaceContainer,
                    elevation: 12,
                    shadowColor: Colors.black54,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    // Outlined on the top and sides only. Along the bottom the
                    // sheet sits on the conservation toolbar, and a line there
                    // reads as a seam rather than an edge.
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(color: colors.outlineVariant),
                          left: BorderSide(color: colors.outlineVariant),
                          right: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: CustomScrollView(
                        key: const ValueKey<String>('constraint-panel-scroll'),
                        controller: scroll,
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: <Widget>[
                          PinnedHeaderSliver(
                            child: ColoredBox(
                              color: colors.surfaceContainer,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    height: 44,
                                    child: Stack(
                                      children: <Widget>[
                                        Positioned.fill(
                                          left: 0,
                                          right: 0,
                                          child: Semantics(
                                            label: 'Resize residue details',
                                            onDismiss: widget.onDismiss,
                                            hint: 'Tap to expand or collapse, or drag vertically',
                                            button: true,
                                            onIncrease: () => _moveTo(
                                              ConstraintPanel.maximumSize,
                                            ),
                                            onDecrease: () => _moveTo(
                                              widget.controller.size >
                                                      ConstraintPanel
                                                              .initialSize +
                                                          0.01
                                                  ? ConstraintPanel.initialSize
                                                  : _compactSize,
                                            ),
                                            child: GestureDetector(
                                              key: const ValueKey<String>(
                                                'constraint-sheet-handle',
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onVerticalDragUpdate: _dragHandle,
                                              onVerticalDragEnd: _settleHandle,
                                              onVerticalDragCancel: () =>
                                                  _settleHandle(DragEndDetails()),
                                              onTap: () => _moveTo(
                                                widget.controller.size >
                                                        (ConstraintPanel
                                                                    .initialSize +
                                                                ConstraintPanel
                                                                    .maximumSize) /
                                                            2
                                                    ? ConstraintPanel.initialSize
                                                    : ConstraintPanel.maximumSize,
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 32,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: colors.onSurfaceVariant
                                                        .withValues(alpha: 0.45),
                                                    borderRadius:
                                                        BorderRadius.circular(2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Dismissal without discovering the
                                        // gesture: always in the pinned row.
                                        Positioned(
                                          right: 8,
                                          top: 0,
                                          bottom: 0,
                                          child: IconButton(
                                            key: const ValueKey<String>(
                                              'constraint-sheet-close',
                                            ),
                                            tooltip: 'Close',
                                            onPressed: widget.onDismiss,
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.pinIdentity) identity,
                                ],
                              ),
                            ),
                          ),
                          // At short heights or large text sizes the identity scrolls
                          // away, leaving the handle within reach.
                          if (!widget.pinIdentity)
                            SliverToBoxAdapter(child: identity),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverToBoxAdapter(
                              child: AnimatedSwitcher(
                                duration: crossfade,
                                child: _Details(
                                  key: ValueKey<int>(widget.residue.index),
                                  residue: widget.residue,
                                  length: widget.length,
                                  expanded: _expanded,
                                  explanation: _explanation,
                                  onExpand: () =>
                                      setState(() => _expanded = !_expanded),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ResidueIdentity extends StatelessWidget {
  const _ResidueIdentity({
    required this.residue,
    required this.length,
    required this.explanation,
    required this.onExplain,
    super.key,
  });
  final ResidueConstraint residue;
  final int length;
  final bool explanation;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final String? partner = residue.bondPartner;
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.anatomyColors.forResidue(residue.wildtype),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            residue.wildtype,
            style: TextStyle(
              fontFamily: AppTypography.monoFamily,
              fontSize: 26,
              color: theme.colorScheme.surface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(residue.title, style: theme.textTheme.titleSmall),
              Text(
                '${residue.domain}${partner == null ? '' : ' · S–S $partner'}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'constraint ${residue.conservation.toStringAsFixed(2)} · '
                'rank ${grouped(residue.rank)} of ${grouped(length)}',
                style: theme.textTheme.bodySmall,
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

class _Details extends StatelessWidget {
  const _Details({
    required this.residue,
    required this.length,
    required this.expanded,
    required this.explanation,
    required this.onExpand,
    super.key,
  });
  final ResidueConstraint residue;
  final int length;
  final bool expanded;
  final bool explanation;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Color accent = ConstraintColors.badge(residue.level);
    final Color bar = theme.colorScheme.onSurfaceVariant;
    final List<SubstitutionScore> visible = expanded
        ? residue.ranked
        : residue.ranked.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Container(
                width: 15,
                height: 5,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color:
                      i <
                          switch (residue.level) {
                            ConstraintLevel.high => 3,
                            ConstraintLevel.middle => 2,
                            ConstraintLevel.low => 1,
                          }
                      ? accent
                      : accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                residue.level.label,
                style: theme.textTheme.bodySmall?.copyWith(color: accent),
              ),
            ),
          ],
        ),
        if (explanation) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            // The count was insulin's 109 for every protein.
            'ESM-2 650M masked marginals, precomputed: this position masked, '
            'all 20 amino acids scored against the other '
            '${grouped(length - 1)}. Score = ln p(aa)/p(WT), so WT is 0; bars '
            'span −10 to 0. Constraint = 1 − entropy of that prediction, '
            'min–max scaled within this protein. A model prediction, not '
            'observed variation.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Substitutions · ln p(aa)/p(WT)',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            if (!_stackScoreLabels(context)) const SizedBox(width: 28),
            Text('−10', style: theme.textTheme.labelSmall),
            const Spacer(),
            Text('0 or higher', style: theme.textTheme.labelSmall),
            if (!_stackScoreLabels(context)) const SizedBox(width: 108),
          ],
        ),
        const SizedBox(height: 4),
        for (final SubstitutionScore score in visible)
          SubstitutionBar(
            score: score,
            native: score.aminoAcid == residue.wildtype,
            color: bar,
          ),
        TextButton(
          key: const ValueKey<String>('constraint-expand'),
          onPressed: onExpand,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, 40),
          ),
          child: Text(
            expanded
                ? 'Show top six'
                : '14 more · all ≤ ${formatScore(residue.ranked[6].score)}',
          ),
        ),
        Divider(height: 12, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 6),
        Text(residue.note, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

String formatScore(double value) => value == 0
    ? '0.0'
    : '${value < 0 ? '−' : '+'}${value.abs().toStringAsFixed(1)}';

// Large text gets a full-width bar below its labels, preserving both the
// requested type size and the shared visual scale.
bool _stackScoreLabels(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(13) > 19.5;

class SubstitutionBar extends StatelessWidget {
  const SubstitutionBar({
    required this.score,
    required this.native,
    required this.color,
    super.key,
  });
  final SubstitutionScore score;
  final bool native;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final ThemeData theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.sansFamily),
    );
    final Widget letter = Text(
      score.aminoAcid,
      style: const TextStyle(
        fontFamily: AppTypography.monoFamily,
        fontSize: 15,
        height: 1,
      ),
    );
    final Widget nativeLabel = Text(
      'WT',
      textAlign: TextAlign.right,
      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, height: 1),
    );
    final Widget value = Text(
      formatScore(score.score),
      key: ValueKey<String>('substitution-score-${score.aminoAcid}'),
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontFamily: AppTypography.monoFamily,
        fontSize: 13,
        height: 1,
      ),
    );
    final Widget bar = SizedBox(
      height: 17,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Container(
            height: 7,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          FractionallySizedBox(
            widthFactor: score.barFraction,
            // The native residue is the reference every other bar is measured
            // against, and always 0: an outline, so the bars that carry
            // information are the filled ones.
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: native ? null : color,
                border: native ? Border.all(color: color) : null,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
    final bool stacked = _stackScoreLabels(context);
    return Semantics(
      label:
          '${score.aminoAcid}${native ? ', wild type' : ''}, '
          'score ${score.score.toStringAsFixed(3)}',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: stacked ? 8 : 3),
        child: stacked
            ? Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      letter,
                      const Spacer(),
                      if (native) ...<Widget>[
                        nativeLabel,
                        const SizedBox(width: 12),
                      ],
                      value,
                    ],
                  ),
                  const SizedBox(height: 4),
                  bar,
                ],
              )
            : Row(
                children: <Widget>[
                  SizedBox(width: 28, child: letter),
                  Expanded(child: bar),
                  SizedBox(width: 44, child: native ? nativeLabel : null),
                  SizedBox(width: 64, child: value),
                ],
              ),
      ),
    );
  }
}
