import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/sequence_analysis/data/datasources/sequence_remote_data_source.dart';
import '../../features/sequence_analysis/data/repositories/sequence_repository_impl.dart';
import '../../features/sequence_analysis/domain/repositories/sequence_repository.dart';
import '../../features/sequence_analysis/domain/usecases/analyse_sequence.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../network/dio_api_client.dart';

List<RepositoryProvider<Object>> buildAppProviders() {
  return <RepositoryProvider<Object>>[
    RepositoryProvider<ApiClient>(
      create: (BuildContext context) => DioApiClient(
        baseUrl: Env.apiBaseUrl,
        timeout: Env.apiTimeout,
      ),
    ),
    RepositoryProvider<SequenceRemoteDataSource>(
      create: (BuildContext context) =>
          SequenceRemoteDataSourceImpl(context.read<ApiClient>()),
    ),
    RepositoryProvider<SequenceRepository>(
      create: (BuildContext context) =>
          SequenceRepositoryImpl(context.read<SequenceRemoteDataSource>()),
    ),
    RepositoryProvider<AnalyseSequence>(
      create: (BuildContext context) =>
          AnalyseSequence(context.read<SequenceRepository>()),
    ),
  ];
}
