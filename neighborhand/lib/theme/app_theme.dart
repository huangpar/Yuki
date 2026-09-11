import 'package:flutter/material.dart';

/// Yuki Design System - Themeable
/// All colors, spacing, and typography in one place
/// Easy to rebrand by changing these values

class AppColors {
  // Primary brand color (Yuki green - trust, growth)
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E20);

  // Secondary color (professional blue)
  static const Color secondary = Color(0xFF1976D2);
  static const Color secondaryLight = Color(0xFF42A5F5);
  static const Color secondaryDark = Color(0xFF1565C0);

  // Accent color (action orange)
  static const Color accent = Color(0xFFF57C00);
  static const Color accentLight = Color(0xFFFFB74D);
  static const Color accentDark = Color(0xFFE65100);

  // Neutral colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFBC02D);
  static const Color success = Color(0xFF388E3C);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Borders and dividers
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Shadows
  static const Color shadowLight = Color(0x0D000000);
  static const Color shadowMedium = Color(0x1A000000);
}

class AppSpacing {
  // Spacing scale
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Common padding/margin
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);

  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: md);
}

class AppTypography {
  // Font family. Loaded at startup by brand_fonts.dart; falls back to the platform font until then.
  static const String fontFamily = 'Museo Sans';

  // Pick from the weights the font kit actually has (Museo Sans: 100, 300, 500, 700, 900);
  // anything else gets swapped for the nearest one.
  static const FontWeight headingWeight = FontWeight.w700;
  static const FontWeight bodyWeight = FontWeight.w300;
  static const FontWeight buttonWeight = FontWeight.w500;

  // Heading styles
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: headingWeight,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: headingWeight,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: headingWeight,
    color: AppColors.textPrimary,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: bodyWeight,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: bodyWeight,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: bodyWeight,
    color: AppColors.textSecondary,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: bodyWeight,
    color: AppColors.textSecondary,
  );

  // Button text
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: buttonWeight,
    color: AppColors.textInverse,
  );
}

class AppBorderRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double full = 999;
}

// Theme data for ThemeData
ThemeData get appTheme {
  return ThemeData(
    useMaterial3: true,
    fontFamily: AppTypography.fontFamily,
    // Built-in widgets (text fields, list tiles, snackbars, dialogs) read these,
    // so they match AppTypography's weights instead of Material's default 400.
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: AppTypography.headingWeight),
      headlineMedium: TextStyle(fontWeight: AppTypography.headingWeight),
      headlineSmall: TextStyle(fontWeight: AppTypography.headingWeight),
      titleLarge: TextStyle(fontWeight: AppTypography.headingWeight),
      bodyLarge: TextStyle(fontWeight: AppTypography.bodyWeight),
      bodyMedium: TextStyle(fontWeight: AppTypography.bodyWeight),
      bodySmall: TextStyle(fontWeight: AppTypography.bodyWeight),
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        textStyle: AppTypography.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        textStyle: AppTypography.button,
      ),
    ),
  );
}
