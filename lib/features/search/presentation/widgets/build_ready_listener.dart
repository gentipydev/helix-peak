import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/catalog/protein_builds.dart';
import '../../../../core/router/app_router.dart';

/// Says when a protein's build ends while search is not on screen: a snackbar
/// on whatever screen is open, with Open where it was built. A build that
/// ended while the app was away is said when it comes back. On search itself
/// its card says it, so nothing more is.
///
/// It sits under the app's root `ScaffoldMessenger` (`MaterialApp.builder`)
/// beside the clip's, and reads the app's [ProteinBuilds]; without them it
/// says nothing.
class BuildReadyListener extends StatefulWidget {
  const BuildReadyListener({
    required this.router,
    required this.child,
    super.key,
  });

  /// Where Open goes, and how the listener knows whether search is on top.
  final GoRouter router;

  final Widget child;

  @override
  State<BuildReadyListener> createState() => _BuildReadyListenerState();
}

class _BuildReadyListenerState extends State<BuildReadyListener>
    with WidgetsBindingObserver {
  ProteinBuilds? _builds;
  StreamSubscription<ProteinBuild>? _ended;

  /// Builds that ended while the app was away, to be said when it is back.
  final List<String> _unsaid = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ProteinBuilds? builds = context.read<ProteinBuilds?>();
    if (!identical(builds, _builds)) {
      unawaited(_ended?.cancel());
      _builds = builds;
      _ended = builds?.ended.listen(_endedOne);
    }
  }

  @override
  void dispose() {
    unawaited(_ended?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _inFront {
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  bool get _onSearch {
    try {
      return widget.router.state.uri.path == RoutePaths.search;
    } on Object {
      // Nothing routed yet: no screen shows the build.
      return false;
    }
  }

  void _endedOne(ProteinBuild build) {
    if (_inFront) {
      _say(build.gene);
    } else if (!_unsaid.contains(build.gene)) {
      _unsaid.add(build.gene);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _unsaid.isEmpty) {
      return;
    }
    final List<String> unsaid = List<String>.of(_unsaid);
    _unsaid.clear();
    unsaid.forEach(_say);
  }

  void _say(String gene) {
    final ProteinBuilds? builds = _builds;
    final ProteinBuild? build = builds?.of(gene);
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    // Opened already, or its card is on screen to say it.
    if (builds == null ||
        build == null ||
        !build.pinned ||
        messenger == null ||
        !mounted ||
        _onSearch) {
      return;
    }
    // The snackbar's surface is the theme's dark one; Material's own action
    // and close colours are made for a light one and all but vanish on it.
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? slug = build.slug;
    final bool opens = build.stage == BuildStage.ready && slug != null;
    final String said = switch (build.stage) {
      BuildStage.ready when build.report?.reason != null =>
        '${build.gene} is built, without ESM-2 scores',
      BuildStage.ready => '${build.gene} is built',
      BuildStage.refused => '${build.gene} could not be built',
      _ => "${build.gene}'s build stopped",
    };
    messenger.showSnackBar(
      SnackBar(
        content: Text(said),
        showCloseIcon: true,
        closeIconColor: scheme.onSurfaceVariant,
        action: opens
            ? SnackBarAction(
                label: 'Open',
                textColor: scheme.primary,
                onPressed: () {
                  builds.opened(gene);
                  // Named, so its walk's wait is headed while its row is read.
                  unawaited(
                    widget.router.push(
                      '${RoutePaths.gene}/$slug',
                      extra: RoutePaths.walkNames(
                        gene: build.gene,
                        display: build.protein.title,
                      ),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
