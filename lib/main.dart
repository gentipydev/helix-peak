import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/di/dependencies.dart';
import 'core/network/dio_api_client.dart';
import 'core/router/landscape_route.dart';
import 'features/gene_lookup/data/repositories/protein_catalog_repository.dart';

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
  // Missing configuration uses Env's development defaults.
  await dotenv.load(isOptional: true);
  final DioApiClient api = DioApiClient(
    baseUrl: Env.apiBaseUrl,
    timeout: Env.apiTimeout,
  );
  final ProteinCatalogRepository catalog = ProteinCatalogRepository(api);
  await catalog.hydrate();
  unawaited(catalog.refresh());

  runApp(
    MultiRepositoryProvider(
      providers: buildAppProviders(api: api, catalog: catalog),
      child: const HelixPeekApp(),
    ),
  );
}
