/// Spacing, radius and accessibility size tokens (WCAG 2.1 AA, spec 07).
///
/// Never hardcode spacing/sizes in widgets — reference these constants.
class AppDimensions {
  const AppDimensions._();

  // Spacing scale (4pt grid)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  // Accessibility
  /// Minimum touch target (WCAG 2.5.5).
  static const double minTouchTarget = 48;

  /// Patient voice mic button (spec 06: microfone ≥160dp).
  static const double bigMicSize = 160;

  // Responsive breakpoints (spec 07)
  static const double phoneMax = 600;
  static const double tabletMax = 1024;
}
