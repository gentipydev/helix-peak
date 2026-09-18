import 'package:flutter/foundation.dart';

@immutable
sealed class ApiException implements Exception {
  const ApiException();

  String get userMessage;
}

@immutable
final class NetworkApiException extends ApiException {
  const NetworkApiException();

  @override
  String get userMessage =>
      'Could not reach the analysis service. Check your connection and try again.';
}

@immutable
final class TimeoutApiException extends ApiException {
  const TimeoutApiException();

  @override
  String get userMessage =>
      'The analysis service took too long to respond. Try again.';
}

@immutable
final class ServerApiException extends ApiException {
  const ServerApiException({required this.statusCode, this.detail});

  final int? statusCode;
  final String? detail;

  @override
  String get userMessage => switch (statusCode) {
        final int code when code >= 500 =>
          'The analysis service reported an error. Try again shortly.',
        400 => detail ?? 'The sequence was rejected by the analysis service.',
        // The backend answers 404 for "no such record / no such gene" and says
        // which in `detail`, so passing it through beats a generic line.
        404 => detail ?? 'That record could not be found.',
        _ => detail ?? 'The analysis service returned an unexpected response.',
      };
}

@immutable
final class UnknownApiException extends ApiException {
  const UnknownApiException();

  @override
  String get userMessage => 'Something went wrong during analysis.';
}
