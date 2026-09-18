import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/di/dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `isOptional`: a missing or empty `.env` leaves the loader initialised with
  // no entries rather than throwing, and Env's own fallbacks take it from
  // there. A mock build carries its data in the bundle and has nothing to
  // configure, so it should not die on a file it never reads.
  await dotenv.load(isOptional: true);

  runApp(
    MultiRepositoryProvider(
      providers: buildAppProviders(),
      child: const HelixPeakApp(),
    ),
  );
}
