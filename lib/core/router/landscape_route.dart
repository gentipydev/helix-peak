import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Whether [display] is a phone's: its shortest side under 600 points.
///
/// That is also where the platforms stop letting an app hold an orientation:
/// Android 16 ignores it on anything wider, and iPadOS whenever the app can
/// share the screen. The display is asked rather than the window, which a
/// letterboxed or split-screen app reports smaller than the screen.
bool isPhoneDisplay(ui.Display display) =>
    display.size.shortestSide / display.devicePixelRatio < 600;

/// The ways up the app is read in outside a landscape page: upright on a
/// phone, and any way on anything larger.
List<DeviceOrientation> appOrientations(ui.Display display) =>
    isPhoneDisplay(display)
    ? const <DeviceOrientation>[DeviceOrientation.portraitUp]
    : const <DeviceOrientation>[];

/// How long a landscape page and its content take to fade in or out.
const Duration _fade = Duration(milliseconds: 150);

/// How long a page waits for the screen to turn. A turn takes about a third
/// of a second; a screen that will not turn at all — a phone sharing its
/// screen with another app — must not leave the reader on an empty page.
const Duration _patience = Duration(seconds: 1);

/// A page with the whole screen to itself, turned to landscape on a phone
/// while it is open and upright again before it goes.
///
/// The screen turns behind a plain page, since iOS stretches whatever is on
/// screen while it turns: [builder]'s content appears once the screen is on
/// its side, and the page underneath is uncovered once it is upright again,
/// so it is never laid out on its side. The status bar and the home indicator
/// are hidden while it is open, where the platform lets an app hide them.
///
/// [builder] is handed the page's way out, which Back takes too; what it is
/// closed with is what the route completes with. The page is drawn in the
/// themes around [context], as a page pushed from a walk has to be.
Route<T> landscapeRoute<T>(
  BuildContext context,
  Widget Function(BuildContext context, void Function([T? result]) close)
  builder,
) {
  final CapturedThemes themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context).context,
  );
  final Duration fade = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : _fade;
  return PageRouteBuilder<T>(
    transitionDuration: fade,
    reverseTransitionDuration: fade,
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => themes.wrap(
          Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: _Landscape<T>(builder: builder),
          ),
        ),
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) => FadeTransition(opacity: animation, child: child),
  );
}

enum _Stage {
  /// The screen is on its way to landscape; nothing is drawn yet.
  turning,
  shown,

  /// The content has gone, and the screen is on its way back upright.
  leaving,
}

class _Landscape<T> extends StatefulWidget {
  const _Landscape({required this.builder});

  final Widget Function(BuildContext context, void Function([T? result]) close)
  builder;

  @override
  State<_Landscape<T>> createState() => _LandscapeState<T>();
}

class _LandscapeState<T> extends State<_Landscape<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _content = AnimationController(
    vsync: this,
    duration: _fade,
  );
  _Stage _stage = _Stage.turning;

  /// The display the page opened on, kept for handing the screen back after
  /// the page has left the tree.
  ui.Display? _display;

  /// Whether the page turns the screen: on a phone only.
  bool _turns = false;
  bool _landscape = false;

  /// The route's entrance, while it runs: the screen turns once the page
  /// covers the one below, never while that one still shows through.
  Animation<double>? _entrance;
  bool _asked = false;
  bool _handedBack = false;
  bool _popped = false;
  Timer? _wait;
  T? _result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (_display == null) {
      final ui.Display display = _display = View.of(context).display;
      _turns = isPhoneDisplay(display);
      if (!_turns) {
        // Nothing turns, so there is nothing to wait for: the content comes
        // in with the page.
        _stage = _Stage.shown;
        _content.value = 1;
      }
      final Animation<double>? entrance = ModalRoute.of(context)?.animation;
      if (entrance == null || entrance.status == AnimationStatus.completed) {
        _ask();
      } else {
        _entrance = entrance..addStatusListener(_entered);
      }
    }
    _settleLater();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _entrance?.removeStatusListener(_entered);
    _content.dispose();
    // Taken away without being closed: the screen is handed back all the
    // same.
    if (!_handedBack) {
      _handBack();
    }
    super.dispose();
  }

  void _entered(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _entrance?.removeStatusListener(_entered);
    _entrance = null;
    if (mounted && _stage != _Stage.leaving) {
      _ask();
    }
  }

  /// Asks for the whole screen, and on a phone for landscape.
  void _ask() {
    if (_asked) {
      return;
    }
    _asked = true;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    if (_turns) {
      unawaited(
        SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      _wait = Timer(_patience, _show);
    }
    _settleLater();
  }

  /// Hands the screen back as the app keeps it: the bars as they are at
  /// launch, and its own ways up.
  void _handBack() {
    _handedBack = true;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
    if (_turns) {
      unawaited(
        SystemChrome.setPreferredOrientations(appOrientations(_display!)),
      );
    }
  }

  bool _settling = false;

  /// Looks at where the screen stands once the frame is done: a page can't
  /// be popped, or its content shown, from the middle of a build.
  void _settleLater() {
    if (_settling) {
      return;
    }
    _settling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settling = false;
      _settle();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _settle() {
    if (!mounted) {
      return;
    }
    switch (_stage) {
      case _Stage.turning when _asked && _landscape:
        _show();
      case _Stage.leaving when _handedBack && (!_turns || !_landscape):
        _pop();
      default:
        break;
    }
  }

  void _show() {
    _wait?.cancel();
    _wait = null;
    if (!mounted || _stage != _Stage.turning) {
      return;
    }
    setState(() => _stage = _Stage.shown);
    if (MediaQuery.disableAnimationsOf(context)) {
      _content.value = 1;
    } else {
      unawaited(_content.forward());
    }
  }

  /// The way out: the content fades, the screen turns back upright, and only
  /// then does the page go.
  void _close([T? result]) {
    if (!mounted || _stage == _Stage.leaving) {
      return;
    }
    _result = result;
    _wait?.cancel();
    _wait = null;
    setState(() => _stage = _Stage.leaving);
    if (MediaQuery.disableAnimationsOf(context) || _content.isDismissed) {
      _content.value = 0;
      _turnBack();
    } else {
      _content.reverse().whenCompleteOrCancel(_turnBack);
    }
  }

  void _turnBack() {
    if (!mounted || _handedBack) {
      return;
    }
    // The content is dropped rather than laid out again as the screen turns.
    setState(_handBack);
    if (_turns) {
      _wait = Timer(_patience, _pop);
    }
    _settleLater();
  }

  void _pop() {
    _wait?.cancel();
    _wait = null;
    if (!mounted || _popped) {
      return;
    }
    _popped = true;
    Navigator.of(context).pop<T>(_result);
  }

  @override
  Widget build(BuildContext context) {
    final bool shown = _stage == _Stage.shown;
    final bool drawn =
        _stage == _Stage.shown || (_stage == _Stage.leaving && !_handedBack);
    return PopScope<T>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, T? _) {
        if (!didPop) {
          _close();
        }
      },
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: drawn
            ? FadeTransition(
                opacity: _content,
                child: IgnorePointer(
                  ignoring: !shown,
                  child: ExcludeSemantics(
                    excluding: !shown,
                    child: widget.builder(context, _close),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
