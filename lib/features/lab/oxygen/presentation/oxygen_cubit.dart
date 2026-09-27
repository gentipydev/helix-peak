import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../domain/mwc.dart';
import '../domain/oxygen_morph.dart';

/// Where an assembly's morph comes from: its row at `/assembly/{slug}/tracks`
/// on the service, and the stored bytes that row names. Null where the row
/// does not say the morph is ready.
abstract interface class AssemblySource {
  Future<Uint8List?> morph(String slug);
}

final class ServiceAssemblySource implements AssemblySource {
  ServiceAssemblySource(this._api, {Dio? dio}) : _dio = dio ?? Dio();

  final ApiClient _api;
  final Dio _dio;

  @override
  Future<Uint8List?> morph(String slug) async {
    final Map<String, dynamic> rows = await _api.getJson(
      '/assembly/$slug/tracks',
    );
    final Map<String, dynamic>? morph = rows['morph'] as Map<String, dynamic>?;
    final String? url = morph?['url'] as String?;
    if (morph == null || morph['state'] != 'ready' || url == null) {
      return null;
    }
    final Response<List<int>> response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }
}

sealed class OxygenState {
  const OxygenState();
}

final class OxygenLoading extends OxygenState {
  const OxygenLoading();
}

/// No morph is published for the assembly: a state, not a failure.
final class OxygenUnavailable extends OxygenState {
  const OxygenUnavailable();
}

final class OxygenFailed extends OxygenState {
  const OxygenFailed(this.message);

  final String message;
}

final class OxygenReady extends OxygenState {
  const OxygenReady(this.morph);

  final OxygenMorph morph;
}

class OxygenCubit extends Cubit<OxygenState> {
  OxygenCubit(this._source) : super(const OxygenLoading());

  final AssemblySource _source;

  Future<void> load() async {
    emit(const OxygenLoading());
    try {
      final Uint8List? bytes = await _source.morph(oxygenAssembly);
      if (isClosed) {
        return;
      }
      emit(
        bytes == null
            ? const OxygenUnavailable()
            : OxygenReady(OxygenMorph.decode(bytes, oxygenAssembly)),
      );
    } on ServerApiException catch (error) {
      if (!isClosed) {
        emit(
          error.statusCode == 404
              ? const OxygenUnavailable()
              : OxygenFailed(error.userMessage),
        );
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(OxygenFailed(error.userMessage));
      }
    } on Object {
      if (!isClosed) {
        emit(OxygenFailed(const UnknownApiException().userMessage));
      }
    }
  }
}
