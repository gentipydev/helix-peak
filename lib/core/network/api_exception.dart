import 'package:flutter/foundation.dart';

/// Transport failures, translated out of Dio's vocabulary into the app's.
///
/// The point of this type is containment: nothing above [ApiClient] should
/// know that Dio exists, so no `DioException` is allowed to escape the network
/// layer. Each case carries [userMessage], so the presentation layer renders
/// failures without switching on transport details.
@immutable
sealed class ApiException implements Exception {
  const ApiException();

  /// Copy safe to show a user. Never a stack trace, never a raw exception.
  String get userMessage;
}

/// No usable connection — offline, DNS failure, connection refused.
@immutable
final class NetworkApiException extends ApiException {
  const NetworkApiException();

  @override
  String get userMessage =>
      'Could not reach the analysis service. Check your connection and try again.';
}

/// The request outlived its timeout.
@immutable
final class TimeoutApiException extends ApiException {
  const TimeoutApiException();

  @override
  String get userMessage =>
      'The analysis service took too long to respond. Try again.';
}

/// The server answered with a non-success status.
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
        404 => 'The analysis endpoint could not be found.',
        _ => detail ?? 'The analysis service returned an unexpected response.',
      };
}

/// Anything else, including malformed response bodies.
@immutable
final class UnknownApiException extends ApiException {
  const UnknownApiException();

  @override
  String get userMessage => 'Something went wrong during analysis.';
}
