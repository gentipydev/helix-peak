/// Spacing and radius scales, on a 4px grid.
///
/// Layout code uses these instead of literal numbers, so rhythm stays
/// consistent and a global adjustment is a single edit.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Generous breathing room around the primary content of a screen. The
  /// sparse layouts depend on this being large.
  static const double screenPadding = 24;
}

/// Corner radii. Kept small and consistent — this is instrument software, not
/// a consumer app, and heavily rounded corners undercut that.
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
}
