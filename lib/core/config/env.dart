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

  /// Whether this build carries the lab: `/lab`, its entry on the home screen,
  /// and every flow under `lib/features/lab/`.
  ///
  /// Off unless `.env` says `LAB_ENABLED=true`. The file is bundled when the
  /// app is built, so this is a build-time switch: a release built without the
  /// line ships none of the lab's half-built flows, and the lab's work can
  /// still merge early rather than rot on a branch. Missing is not a mistake
  /// here, so it falls back to off without the warning the other keys give.
  static bool get labEnabled => _read('LAB_ENABLED') == 'true';

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
