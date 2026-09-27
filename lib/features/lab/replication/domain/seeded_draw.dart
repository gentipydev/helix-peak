/// Numbers drawn from a seed, the same on every platform and every SDK:
/// `dart:math`'s seeded [Random] is only promised to repeat within one.
///
/// Marsaglia's 32-bit xorshift. It is for choosing lengths and places a
/// picture can show, not for anything a statistic rests on beyond that.
final class SeededDraw {
  SeededDraw(int seed) : _state = seed & 0xffffffff;

  int _state;

  int _next() {
    int x = _state == 0 ? 0x9e3779b9 : _state;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    return _state = x & 0xffffffff;
  }

  /// A whole number from [low] to [high], both included.
  int between(int low, int high) => low + _next() % (high - low + 1);

  /// A number above 0 and below 1.
  double unit() => (_next() + 0.5) / 4294967296;
}

/// A seed from [text]: 32-bit FNV-1a over its code units.
int seedOf(String text) {
  int hash = 0x811c9dc5;
  for (final int unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}
