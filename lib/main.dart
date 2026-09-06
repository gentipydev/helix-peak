import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/constants/env.dart';
import 'core/network/api_client.dart';
import 'core/network/dio_api_client.dart';
import 'features/sequence_analysis/data/repositories/stub_sequence_repository.dart';
import 'features/sequence_analysis/domain/repositories/sequence_repository.dart';

/// Composition root.
///
/// Dependencies are constructed here and supplied to the widget tree — the
/// tree *is* the container, which is why there is no service locator in this
/// codebase. Repositories are app-scoped; blocs are scoped to the routes that
/// need them (see the router's `ShellRoute`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  runApp(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ApiClient>(
          create: (_) => DioApiClient(
            baseUrl: Env.apiBaseUrl,
            timeout: Env.apiTimeout,
          ),
        ),

        // ─── The backend swap point ──────────────────────────────────────
        // Everything above the SequenceRepository interface — the bloc, both
        // screens, the tests — is written against the abstraction. When the
        // FastAPI service exists, add ApiSequenceRepository in the data layer
        // and change this one line to:
        //
        //   create: (context) =>
        //       ApiSequenceRepository(context.read<ApiClient>()),
        //
        // Nothing else in the app changes.
        RepositoryProvider<SequenceRepository>(
          create: (_) => const StubSequenceRepository(),
        ),
      ],
      child: const HelixPeakApp(),
    ),
  );
}
