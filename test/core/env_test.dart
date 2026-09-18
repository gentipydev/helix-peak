import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeak/core/config/env.dart';

/// Only the `.env` half of [Env.useMockData] is reachable from a test:
/// `String.fromEnvironment` is resolved at compile time, so the dart-define
/// branch is covered by building with the flag, not from here.
void main() {
  tearDown(() => dotenv.clean());

  group('Env.useMockData', () {
    test('is false when nothing has been loaded at all', () {
      dotenv.clean();
      expect(Env.useMockData, isFalse);
    });

    test('is false when the key is absent', () {
      dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:8000');
      expect(Env.useMockData, isFalse);
    });

    test('reads true and 1 as on', () {
      dotenv.loadFromString(envString: 'USE_MOCK_DATA=true');
      expect(Env.useMockData, isTrue);

      dotenv.loadFromString(envString: 'USE_MOCK_DATA=TRUE');
      expect(Env.useMockData, isTrue);

      dotenv.loadFromString(envString: 'USE_MOCK_DATA=1');
      expect(Env.useMockData, isTrue);
    });

    test('reads false and anything unrecognised as off', () {
      dotenv.loadFromString(envString: 'USE_MOCK_DATA=false');
      expect(Env.useMockData, isFalse);

      dotenv.loadFromString(envString: 'USE_MOCK_DATA=0');
      expect(Env.useMockData, isFalse);

      dotenv.loadFromString(envString: 'USE_MOCK_DATA=yes');
      expect(Env.useMockData, isFalse);
    });
  });

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
