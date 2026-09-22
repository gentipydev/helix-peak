import 'dart:async';

import 'package:flutter/material.dart';

/// What the content inside an [InspectorSheet] can ask of the sheet around it.
///
/// The content is built by the panel above the sheet, so it cannot reach down
/// through the tree for this; the panel makes one of these, hands it over, and
/// the sheet attaches itself. The same arrangement Flutter's own scroll and
/// sheet controllers use.
class InspectorSheetController {
  _InspectorSheetState? _state;

  void _attach(_InspectorSheetState state) => _state = state;

  void _detach(_InspectorSheetState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  bool get isAttached => _state != null;

  /// The height the sheet rests at when it is showing only its header.
  double get compactSize => _state?._compactSize ?? InspectorSheet.minimumSize;

  /// Move to one of the resting heights.
  void moveTo(double size) => _state?._moveTo(size);

  /// Bring the top of the content into view, growing the sheet first where it
  /// is too small to read what has just opened there.
  void reveal({bool grow = false}) => _state?._reveal(grow: grow);

  /// Put the content back at its top without moving the sheet. Called when the
  /// subject changes, so a previous scroll position cannot hide the new
  /// subject's best rows.
  void resetScroll() => _state?._resetScroll();
}

/// The nonmodal, draggable sheet both inspectors are built in.
///
/// Everything here is the sheet as such: the two resting heights and the
/// closing one below them, the handoff between resizing and scrolling, the
/// handle and its accessibility actions, the close button, pull-down to
/// dismiss. None of it knows what is being inspected. `docs/residue-sheet-ux.md`
/// is where the behaviour is argued for; this is only where it lives.
///
/// It was extracted from the residue panel rather than written twice. Two
/// sheets that are meant to feel identical and are maintained apart do not stay
/// identical, and the gesture choreography is the part a reader would notice
/// drifting first.
class InspectorSheet extends StatefulWidget {
  const InspectorSheet({
    required this.sheet,
    required this.controller,
    required this.slide,
    required this.onDismiss,
    required this.identity,
    required this.details,
    required this.pinIdentity,
    required this.subject,
    required this.resizeLabel,
    required this.surfaceKey,
    required this.scrollKey,
    required this.handleKey,
    required this.closeKey,
    super.key,
  });

  /// Pulling below this closes the sheet; it never rests here.
  static const double minimumSize = 0.18;
  static const double initialSize = 0.62;
  static const double maximumSize = 0.92;

  /// Owned by the screen, because the screen reads the height to keep the
  /// selected cell above the sheet.
  final DraggableScrollableController sheet;

  /// Owned by the panel, for the things its content needs to ask for.
  final InspectorSheetController controller;

  final Animation<Offset> slide;
  final VoidCallback onDismiss;

  /// The block naming what is being inspected. Pinned with the controls where
  /// there is room, and part of the scrolling content where there is not.
  final Widget identity;

  /// Everything below the identity.
  final Widget details;

  final bool pinIdentity;

  /// What is being inspected. When it changes the content goes back to its top.
  final Object subject;

  /// What a screen reader calls the handle: 'Resize residue details'.
  final String resizeLabel;

  final ValueKey<String> surfaceKey;
  final ValueKey<String> scrollKey;
  final ValueKey<String> handleKey;
  final ValueKey<String> closeKey;

  @override
  State<InspectorSheet> createState() => _InspectorSheetState();
}

class _InspectorSheetState extends State<InspectorSheet> {
  ScrollController? _scroll;
  double _compactSize = 0.32;
  Offset? _dragOrigin;
  bool _canDismissDrag = false;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void didUpdateWidget(InspectorSheet old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller._detach(this);
      widget.controller._attach(this);
    }
    if (old.subject != widget.subject) {
      // Keep the chosen height and disclosure preference, but start the new
      // subject at its top. Scroll notifications must follow the rebuild.
      final Object subject = widget.subject;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.subject == subject) {
          _resetScroll();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    super.dispose();
  }

  void _resetScroll() {
    if (_scroll?.hasClients ?? false) {
      _scroll!.jumpTo(0);
    }
  }

  void _beginDrag(PointerDownEvent event) {
    _dragOrigin = event.position;
    _canDismissDrag =
        widget.sheet.isAttached &&
        widget.sheet.size <= _compactSize + 0.01 &&
        (event.localPosition.dy <= 44 ||
            !(_scroll?.hasClients ?? false) ||
            _scroll!.offset <= 0);
  }

  void _endDrag(PointerUpEvent event) {
    final Offset travel = event.position - (_dragOrigin ?? event.position);
    if (_canDismissDrag && travel.dy > 48 && travel.dy > travel.dx.abs() * 1.5) {
      widget.onDismiss();
    }
    _dragOrigin = null;
    _canDismissDrag = false;
  }

  void _moveTo(double target) {
    if (!widget.sheet.isAttached) {
      return;
    }
    if (target == _compactSize && (_scroll?.hasClients ?? false)) {
      _scroll!.jumpTo(0);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.sheet.jumpTo(target);
    } else {
      unawaited(
        widget.sheet.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _reveal({bool grow = false}) {
    if (grow &&
        widget.sheet.isAttached &&
        widget.sheet.size < InspectorSheet.initialSize) {
      _moveTo(InspectorSheet.initialSize);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(_scroll?.hasClients ?? false)) {
        return;
      }
      // The control that opened this stays available while reading further
      // down, so what it opened is brought into view without changing height.
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
    if (widget.sheet.isAttached) {
      widget.sheet.jumpTo(
        (widget.sheet.size -
                widget.sheet.pixelsToSize(details.primaryDelta ?? 0))
            .clamp(_compactSize, InspectorSheet.maximumSize),
      );
    }
  }

  void _settleHandle(DragEndDetails details) {
    if (!widget.sheet.isAttached) {
      return;
    }
    final double size = widget.sheet.size;
    final double velocity = details.primaryVelocity ?? 0;
    final List<double> stops = <double>[
      _compactSize,
      InspectorSheet.initialSize,
      InspectorSheet.maximumSize,
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bounds) {
        // Handle, identity, badge and a little breathing room. Scale the stop
        // with text rather than spending a fixed fraction of the phone.
        _compactSize =
            ((56 + MediaQuery.textScalerOf(context).scale(100)) /
                    bounds.maxHeight)
                .clamp(
                  InspectorSheet.minimumSize,
                  InspectorSheet.initialSize - 0.01,
                );
        return DraggableScrollableSheet(
          controller: widget.sheet,
          initialChildSize: InspectorSheet.initialSize,
          minChildSize: _compactSize,
          shouldCloseOnMinExtent: false,
          maxChildSize: InspectorSheet.maximumSize,
          snap: true,
          snapSizes: const <double>[InspectorSheet.initialSize],
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
                    key: widget.surfaceKey,
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
                    // sheet sits on the toolbar, and a line there reads as a
                    // seam rather than an edge.
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
                        key: widget.scrollKey,
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
                                            label: widget.resizeLabel,
                                            onDismiss: widget.onDismiss,
                                            hint: 'Tap to expand or collapse, or drag vertically',
                                            button: true,
                                            onIncrease: () =>
                                                _moveTo(InspectorSheet.maximumSize),
                                            onDecrease: () => _moveTo(
                                              widget.sheet.size >
                                                      InspectorSheet.initialSize +
                                                          0.01
                                                  ? InspectorSheet.initialSize
                                                  : _compactSize,
                                            ),
                                            child: GestureDetector(
                                              key: widget.handleKey,
                                              behavior: HitTestBehavior.opaque,
                                              onVerticalDragUpdate: _dragHandle,
                                              onVerticalDragEnd: _settleHandle,
                                              onVerticalDragCancel: () =>
                                                  _settleHandle(DragEndDetails()),
                                              onTap: () => _moveTo(
                                                widget.sheet.size >
                                                        (InspectorSheet.initialSize +
                                                                InspectorSheet
                                                                    .maximumSize) /
                                                            2
                                                    ? InspectorSheet.initialSize
                                                    : InspectorSheet.maximumSize,
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
                                            key: widget.closeKey,
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
                                  if (widget.pinIdentity) widget.identity,
                                ],
                              ),
                            ),
                          ),
                          // At short heights or large text sizes the identity
                          // scrolls away, leaving the handle within reach.
                          if (!widget.pinIdentity)
                            SliverToBoxAdapter(child: widget.identity),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverToBoxAdapter(child: widget.details),
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
