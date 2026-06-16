import 'package:flutter/material.dart';

/// AURA Care-Chain palette.
///
/// Identity (validated for the Leroy Merlin pitch): deep petrol blue as the
/// brand/primary, care-green as the "safe / on-track / confirm" signal, and a
/// clinical severity system (green · amber · red). Neutrals are intentionally
/// *warm* (paper-toned, not cold white) so cards sit above the background and
/// gain depth without heavy shadows — "accessibility is the aesthetic":
/// generous contrast and legible, calm surfaces are the look.
///
/// Existing token names are preserved so every screen keeps compiling; new
/// semantic tokens are additive.
class AppColors {
  const AppColors._();

  // ── Brand (petrol) ─────────────────────────────────────────────
  static const Color primary = Color(0xFF1A5276); // petrol — brand / actions
  static const Color primaryLight = Color(0xFF2E6E91);
  static const Color primaryDark = Color(0xFF123C56);

  /// Near-black petrol ink for headings/body — AAA on light surfaces.
  static const Color ink = Color(0xFF10303C);

  // ── Care green (safe / confirm / on-track) ─────────────────────
  static const Color careGreen = Color(0xFF148F77); // accent + "ok" severity
  static const Color confirm = Color(0xFF0E7561); // filled CTA bg (white text, AA)

  // Secondary now belongs to the green family (was sky blue).
  static const Color secondary = Color(0xFF148F77);
  static const Color secondaryLight = Color(0xFF2FA890);
  static const Color secondaryDark = Color(0xFF0E7561);

  // ── Warm neutrals ──────────────────────────────────────────────
  static const Color background = Color(0xFFF7F5F1); // warm off-white app bg
  static const Color surface = Color(0xFFFFFFFF); // cards (above the warm bg)
  static const Color surfaceVariant = Color(0xFFEFEBE4); // sunken / explain block
  static const Color surfaceTinted = Color(0xFFF1EEE8);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF10303C);
  static const Color textSecondary = Color(0xFF4E5D63);
  static const Color textTertiary = Color(0xFF657076); // AA on both bg & surface

  // ── Lines ──────────────────────────────────────────────────────
  static const Color borderColor = Color(0xFFE3DED5); // warm hairline
  static const Color dividerColor = Color(0xFFE3DED5);
  static const Color focus = Color(0xFF1A5276);

  // ── Status / severity ──────────────────────────────────────────
  static const Color error = Color(0xFFC0392B); // high risk / SLA breach
  static const Color success = Color(0xFF148F77); // ok
  static const Color warning = Color(0xFF9A6109); // attention (amber, AA-hardened)

  // ── Misc ───────────────────────────────────────────────────────
  static const Color hint = Color(0xFF657076);
  static const Color link = Color(0xFF1A5276);
}
