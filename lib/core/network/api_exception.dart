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

/// A track the service named but the client has no way to fetch.
///
/// Not a [ServerApiException]: the service answered, and what it answered is
/// that this family is not ready for this protein. The walk draws that as a
/// track it does not have — a protein page without its conservation toolbar,
/// a nucleotide page whose taps move the tracer — rather than as an error, so
/// [userMessage] is the one line here no screen is expected to reach for.
@immutable
final class TrackApiException extends ApiException {
  const TrackApiException({
    required this.slug,
    required this.kind,
    required this.state,
    this.reason,
  });

  final String slug;

  /// The family, as the service names it: `constraint`, `clinvar`, `structure`.
  final String kind;

  /// `absent`, `pending` or `refused`, and never `ready`.
  final String state;

  /// The sentence a refusal carries, and null for every other state.
  final String? reason;

  @override
  String get userMessage =>
      reason ?? 'That track is not included for this protein.';

  @override
  String toString() => 'TrackApiException($slug/$kind is $state)';
}
