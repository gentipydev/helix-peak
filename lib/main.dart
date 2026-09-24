import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/di/dependencies.dart';
import 'core/router/landscape_route.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A phone is read upright, before the first frame is drawn: only a chart
  // opened on the whole screen turns it, for as long as it is open
  // (`landscapeRoute`). Anything larger turns freely, as Android 16 and iPadOS
  // would have it anyway.
  final ui.FlutterView? view =
      WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view != null) {
    await SystemChrome.setPreferredOrientations(appOrientations(view.display));
  }
  // `isOptional`: a missing or empty `.env` leaves the loader initialised with
  // no entries rather than throwing, and Env's own fallbacks take it from
  // there. A mock build carries its data in the bundle and has nothing to
  // configure, so it should not die on a file it never reads.
  await dotenv.load(isOptional: true);

  runApp(
    MultiRepositoryProvider(
      providers: buildAppProviders(),
      child: const HelixPeekApp(),
    ),
  );
}
