import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Whether [context]'s platform slides pages in the Cupertino way.
bool _slides(BuildContext context) {
  final TargetPlatform platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

Widget _slide(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => CupertinoPageTransition(
  primaryRouteAnimation: animation,
  secondaryRouteAnimation: secondaryAnimation,
  linearTransition: false,
  child: child,
);

const Duration _slideDuration = Duration(milliseconds: 400);

/// The page a walk is shown on.
///
/// On iOS a page slides in, and a drag from the left edge normally slides it
/// back out — which on the walk is exactly the drag a reader makes to go back
/// a stage, and it threw away their place in the walk. So the walk keeps the
/// platform's slide and gives up the edge gesture; the back button, Back and
/// Escape still leave it. Elsewhere it is an ordinary page.
Page<void> walkPage({
  required BuildContext context,
  required LocalKey key,
  required Widget child,
}) {
  if (!_slides(context)) {
    return MaterialPage<void>(key: key, child: child);
  }
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: _slideDuration,
    reverseTransitionDuration: _slideDuration,
    transitionsBuilder: _slide,
  );
}

/// [walkPage] for a walk pushed rather than routed to: the residue or base a
/// ClinVar record's link opens, above the list it was opened from.
///
/// It is a walk like any other, so it gives up the same edge gesture for the
/// same reason — a right drag on it steps a stage — and its header's
/// "← ClinVar" and Back are the way out of it.
Route<T> walkRoute<T>(BuildContext context, WidgetBuilder builder) {
  if (!_slides(context)) {
    return MaterialPageRoute<T>(builder: builder);
  }
  return PageRouteBuilder<T>(
    transitionDuration: _slideDuration,
    reverseTransitionDuration: _slideDuration,
    // The route scope `CustomTransitionPage` gives a walk page, which a bare
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
    transitionsBuilder: _slide,
  );
}
