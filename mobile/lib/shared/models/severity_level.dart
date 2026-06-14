/// Risk/severity level shared across surfaces (score level, alert severity).
///
/// Maps the aura-server `score.level` (`low`/`medium`/`high`).
enum SeverityLevel {
  ok,
  attention,
  high;

  static SeverityLevel fromScoreLevel(String? level) {
    switch (level) {
      case 'high':
        return SeverityLevel.high;
      case 'medium':
        return SeverityLevel.attention;
      default:
        return SeverityLevel.ok;
    }
  }
}
