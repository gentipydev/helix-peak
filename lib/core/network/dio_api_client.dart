import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_exception.dart';

/// Dio-backed [ApiClient].
///
/// This is the only file in the app that imports `dio`. Every `DioException`
/// is converted to an [ApiException] on the way out, so the rest of the
/// codebase — repositories, blocs, widgets — stays unaware of the transport.
///
/// Nothing calls this yet: the app runs against [StubSequenceRepository] until
/// the FastAPI backend exists. It is built now so that swapping in the real
/// backend is a repository change, not a networking project.
final class DioApiClient implements ApiClient {
  DioApiClient({required String baseUrl, required Duration timeout})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: timeout,
            receiveTimeout: timeout,
            sendTimeout: timeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        ) {
    assert(
      () {
        _dio.interceptors.add(
          LogInterceptor(requestBody: true, responseBody: true),
        );
        return true;
      }(),
      'debug-only request logging',
    );
  }

  /// Test seam: lets a preconfigured or mocked Dio be injected.
  @visibleForTesting
  DioApiClient.withDio(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _send(() => _dio.get<dynamic>(path, queryParameters: query));
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return _send(() => _dio.post<dynamic>(path, data: body));
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final Response<dynamic> response = await request();
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      // A 2xx with an unexpected shape is as unusable as an error status.
      throw const UnknownApiException();
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  ApiException _translate(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const TimeoutApiException(),
      DioExceptionType.connectionError => const NetworkApiException(),
      DioExceptionType.badResponse => ServerApiException(
          statusCode: error.response?.statusCode,
          detail: _detailFrom(error.response?.data),
        ),
      _ => const UnknownApiException(),
    };
  }

  /// FastAPI reports errors as `{"detail": "..."}`; surface that when present.
  String? _detailFrom(dynamic data) {
    if (data is Map<String, dynamic>) {
      final dynamic detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    return null;
  }
}
