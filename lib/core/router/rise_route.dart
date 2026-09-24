import 'dart:async';

import 'package:flutter/cupertino.dart';

/// How long a page takes to rise, or to sink back: as long as a walk's slide.
const Duration _riseDuration = Duration(milliseconds: 400);

/// A page that rises from the bottom over the one it is opened from, and
/// sinks back down when it closes: a full-screen dialog's own motion, on every
/// platform. Android's ordinary page comes in from the side while the page
/// under it moves off, which from a sheet going down made two motions going
/// two ways.
///
/// [over] is a sheet the page is opened from. It stays where it is while the
/// page rises over it, and is taken away once the page covers it, so closing
/// the page goes back to what was under the sheet.
Route<T> riseRoute<T>(
  BuildContext context,
  WidgetBuilder builder, {
  Route<Object?>? over,
}) => _RiseRoute<T>(
  builder: builder,
  duration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : _riseDuration,
  over: over,
);

class _RiseRoute<T> extends PageRouteBuilder<T> {
  _RiseRoute({
    required WidgetBuilder builder,
    required Duration duration,
    this.over,
  }) : super(
         fullscreenDialog: true,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         // The route scope a `MaterialPageRoute` gives its page, which a bare
         // `PageRouteBuilder` leaves out.
         pageBuilder:
             (
               BuildContext context,
               Animation<double> animation,
               Animation<double> secondaryAnimation,
             ) => Semantics(
               scopesRoute: true,
               explicitChildNodes: true,
               child: builder(context),
             ),
         transitionsBuilder:
             (
               BuildContext context,
               Animation<double> animation,
               Animation<double> secondaryAnimation,
               Widget child,
             ) => CupertinoFullscreenDialogTransition(
               primaryRouteAnimation: animation,
               secondaryRouteAnimation: secondaryAnimation,
               linearTransition: false,
               child: child,
             ),
       );

  /// The sheet the page was opened from, until the page covers it.
  final Route<Object?>? over;

  @override
  TickerFuture didPush() {
    final TickerFuture entrance = super.didPush();
    if (over case final Route<Object?> sheet) {
      // Only once the page has risen all the way: until then the sheet is
      // what the reader sees above it. A page closed before it got there
      // never completes its entrance, and leaves the sheet as it was.
      unawaited(
        entrance.then((_) {
          if (sheet.isActive) {
            sheet.navigator?.removeRoute(sheet);
          }
        }),
      );
    }
    return entrance;
  }
}
