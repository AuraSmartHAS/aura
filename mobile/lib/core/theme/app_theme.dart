import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';

/// AURA Care-Chain theme.
///
/// Type system: **Bricolage Grotesque** for display/headlines/wordmark (a warm,
/// human display voice) over **Atkinson Hyperlegible** for everything you read —
/// a typeface designed by the Braille Institute for low-vision legibility, which
/// is the deliberate, audience-grounded body face for an accessibility-first
/// elderly-care product. Atkinson ships only 400/700, so "emphasis" uses w700.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme();

    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD7E6EE),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.careGreen,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD3ECE5),
      onSecondaryContainer: AppColors.secondaryDark,
      tertiary: AppColors.warning,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      outline: AppColors.borderColor,
      outlineVariant: AppColors.borderColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusLg)),
          side: BorderSide(color: AppColors.borderColor),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        border: _inputBorder(AppColors.borderColor),
        enabledBorder: _inputBorder(AppColors.borderColor),
        focusedBorder: _inputBorder(AppColors.primary, width: 2),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 2),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.hint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.primary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderColor,
          minimumSize: const Size(0, 52), // >= 48dp touch target, comfortable
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        side: BorderSide.none,
        labelStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: AppDimensions.xs,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        minVerticalPadding: AppDimensions.sm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 1,
        space: AppDimensions.md,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.careGreen : null,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // ── Type scale ───────────────────────────────────────────────────
  // Display/headline/title-large = Bricolage Grotesque (brand voice).
  // Title-medium and below + all body/label = Atkinson Hyperlegible.

  static TextTheme _buildTextTheme() {
    TextStyle display(double size, {double? height, FontWeight weight = FontWeight.w700, double spacing = -0.4, Color color = AppColors.ink}) =>
        GoogleFonts.bricolageGrotesque(
          fontSize: size,
          height: height == null ? null : height / size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color,
        );

    TextStyle sans(double size, {double? height, FontWeight weight = FontWeight.w400, double spacing = 0, Color color = AppColors.textPrimary}) =>
        GoogleFonts.atkinsonHyperlegible(
          fontSize: size,
          height: height == null ? null : height / size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color,
        );

    return TextTheme(
      displayLarge: display(36, height: 44, weight: FontWeight.w800, spacing: -0.6), // patient greeting (>= 32sp)
      displayMedium: display(28, height: 36),
      displaySmall: display(24, height: 32),
      headlineLarge: display(22, height: 30),
      headlineMedium: display(20, height: 28),
      headlineSmall: display(18, height: 26, weight: FontWeight.w600),
      titleLarge: display(19, height: 26, weight: FontWeight.w600, spacing: -0.2), // wordmark / app bar
      titleMedium: sans(16, height: 24, weight: FontWeight.w700),
      titleSmall: sans(14, height: 20, weight: FontWeight.w700),
      bodyLarge: sans(18, height: 27), // patient body (>= 18sp)
      bodyMedium: sans(15, height: 22),
      bodySmall: sans(13, height: 19, color: AppColors.textSecondary),
      labelLarge: sans(16, height: 22, weight: FontWeight.w700),
      labelMedium: sans(14, height: 20, weight: FontWeight.w700),
      labelSmall: sans(12, height: 16, weight: FontWeight.w700),
    );
  }
}
