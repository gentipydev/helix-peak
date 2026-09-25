import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_exception.dart';

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
      throw const UnknownApiException();
    } on DioException catch (error) {
      throw apiExceptionFrom(error);
    }
  }
}

/// What one Dio failure means, in the vocabulary the app reports.
///
/// Lifted out of [DioApiClient] when [TrackClient] started fetching bytes
/// through a Dio of its own: a blob that times out and a JSON call that times
/// out are the same thing to the reader, and two copies of this switch would
/// have been two chances to stop saying so.
ApiException apiExceptionFrom(DioException error) {
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

String? _detailFrom(dynamic data) {
  if (data is Map<String, dynamic>) {
    final dynamic detail = data['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
  }
  return null;
}
