import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static const String _defaultBaseUrl = 'http://localhost:8000';
  static const int _defaultTimeoutMs = 15000;

  static String get apiBaseUrl =>
      _read('API_BASE_URL') ?? _warnAndFallback('API_BASE_URL', _defaultBaseUrl);

  static Duration get apiTimeout {
    final String? raw = _read('API_TIMEOUT_MS');
    final int? parsed = raw == null ? null : int.tryParse(raw);
    if (parsed == null) {
      return Duration(
        milliseconds: _warnAndFallback('API_TIMEOUT_MS', _defaultTimeoutMs),
      );
    }
    return Duration(milliseconds: parsed);
  }

  /// Whether to serve the bundled fixture instead of calling the backend.
  ///
  /// `--dart-define=USE_MOCK_DATA=true` wins over the `.env` key of the same
  /// name, because `.env` is gitignored: a release build has to be able to flip
  /// modes from the build command, without a hand-edited file to forget about.
  ///
  /// Absent from both, this is false — live is and stays the default.
  static bool get useMockData {
    const String defined = String.fromEnvironment('USE_MOCK_DATA');
    final String? value = defined.isNotEmpty
        ? defined
        : _read('USE_MOCK_DATA');
    return value == '1' || value?.toLowerCase() == 'true';
  }

  static String? _read(String key) {
    // `dotenv.env` throws NotInitializedError before `load()` has run, and
    // `load(isOptional: true)` can leave the map empty rather than absent. Both
    // are answered the same way: no value, so the fallback below applies.
    if (!dotenv.isInitialized) {
      return null;
    }
    final String? value = dotenv.env[key];
    return (value == null || value.isEmpty) ? null : value;
  }

  static T _warnAndFallback<T>(String key, T fallback) {
    assert(
      () {
        debugPrint(
          'Env: "$key" is missing or empty in .env — falling back to '
          '"$fallback". Copy .env.example to .env to silence this.',
        );
        return true;
      }(),
      'debug-only diagnostic',
    );
    return fallback;
  }
}
