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

  static String? _read(String key) {
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
