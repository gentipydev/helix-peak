import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/core/config/env.dart';

void main() {
  tearDown(() => dotenv.clean());

  group('Env', () {
    test('falls back to defaults with no .env loaded', () {
      dotenv.clean();
      expect(Env.apiBaseUrl, 'http://localhost:8000');
      expect(Env.apiTimeout, const Duration(milliseconds: 15000));
    });

    test('reads the values a loaded .env carries', () {
      dotenv.loadFromString(
        envString: 'API_BASE_URL=http://example.test\nAPI_TIMEOUT_MS=25000',
      );
      expect(Env.apiBaseUrl, 'http://example.test');
      expect(Env.apiTimeout, const Duration(milliseconds: 25000));
    });
  });
}
