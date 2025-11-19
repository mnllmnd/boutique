import 'package:flutter/material.dart';
import 'app_settings.dart';

// Helper functions to get colors based on current theme
Color getTextColor(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
}

Color getTitleColor(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
}

Color getBackgroundColor(BuildContext context) {
  return Theme.of(context).scaffoldBackgroundColor;
}

Color getMutedColor(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
}

Color getDividerColor(BuildContext context) {
  return Theme.of(context).dividerColor;
}

Color getAdaptiveColor(BuildContext context, Color darkColor, Color lightColor) {
  final isLight = Theme.of(context).brightness == Brightness.light;
  return isLight ? lightColor : darkColor;
}

// Get Colors.white equivalent that adapts to theme
Color getWhiteEquivalent(BuildContext context) {
  return getAdaptiveColor(context, Colors.white, Colors.black);
}

// Get Colors.white.withOpacity equivalent
Color getWhiteOpacity(BuildContext context, double opacity) {
  return getAdaptiveColor(context, Colors.white.withOpacity(opacity), Colors.black.withOpacity(opacity));
}

// Palette Dark Theme Premium
const Color kBackground = Color(0xFF0F1113);       // Noir très foncé - background principal
const Color kSurface = Color(0xFF1A1E23);          // Gris très foncé - cards/surfaces
const Color kCard = Color.fromARGB(255, 18, 20, 23);             // Gris foncé - card background
const Color kAccent = Color(0xFF7C3AED);           // Violet vibrant - accent principal
const Color kAccentAlt = Color(0xFF8B5CF6);        // Violet clair - accent secondaire
const Color kMuted = Color(0xFF888888);            // Gris moyen
const Color kBorder = Color(0xFF3A3F47);           // Bordure gris foncé
const Color kSuccess = Color(0xFF2DB89A);          // Teal pour confirmations
const Color kDanger = Color(0xFFE63946);           // Rouge pour alertes
const Color kWarning = Color(0xFFF77F00);          // Orange pour avertissements
const Color kTextPrimary = Color(0xFFFFFFFF);      // Texte blanc pur
const Color kTextSecondary = Color(0xFFA0A0A0);    // Texte gris clair

// Light Theme Colors
const Color kBackgroundLight = Color(0xFFFFFFFF);  // Blanc pur - background principal
const Color kSurfaceLight = Color(0xFFFFFFFF);     // Blanc pur - cards/surfaces
const Color kCardLight = Color(0xFFFFFFFF);        // Blanc pur - card background
const Color kMutedLight = Color(0xFF666666);       // Gris foncé clair
const Color kBorderLight = Color(0xFFCCCCCC);      // Bordure gris clair
const Color kTextPrimaryLight = Color(0xFF000000); // Texte noir pur
const Color kTextSecondaryLight = Color(0xFF333333); // Texte gris foncé

// Typography - Style épuré
const double kFontSizeXS = 12.0;
const double kFontSizeS = 14.0;
const double kFontSizeM = 16.0;
const double kFontSizeL = 18.0;
const double kFontSizeXL = 24.0;
const double kFontSize2XL = 32.0;

String fmtFCFA(dynamic v) {
  try {
    return AppSettings().formatCurrency(v);
  } catch (_) {
    if (v == null) return '-';
    if (v is num) return '${v.toStringAsFixed(0)} FCFA';
    final parsed = num.tryParse(v.toString());
    if (parsed == null) return '${v.toString()} FCFA';
    return '${parsed.toStringAsFixed(0)} FCFA';
  }
}

// Theme ThemeData Dark Premium
ThemeData getAppTheme({bool lightMode = false}) {
  if (lightMode) return getAppThemeLight();
  
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kTextPrimary,
        fontSize: kFontSizeL,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: const Color(0xFF0F1113),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: const Color(0xFF0F1113),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: kFontSizeM,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent,
        side: const BorderSide(color: kBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: kFontSizeM,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAccent, width: 2),
      ),
      labelStyle: const TextStyle(
        color: kMuted,
        fontSize: kFontSizeM,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: const TextStyle(
        color: kMuted,
        fontSize: kFontSizeM,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: kTextPrimary,
        fontSize: kFontSize2XL,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        color: kTextPrimary,
        fontSize: kFontSizeXL,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: kTextPrimary,
        fontSize: kFontSizeL,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      titleMedium: TextStyle(
        color: kTextPrimary,
        fontSize: kFontSizeM,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      bodyLarge: TextStyle(
        color: kTextPrimary,
        fontSize: kFontSizeM,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
      bodyMedium: TextStyle(
        color: kTextSecondary,
        fontSize: kFontSizeS,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        color: kMuted,
        fontSize: kFontSizeXS,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    ),
    dividerColor: kBorder,
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorder, width: 1),
      ),
    ),
  );
}

// Light Theme
ThemeData getAppThemeLight() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: kBackgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurfaceLight,
      foregroundColor: kTextPrimaryLight,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kTextPrimaryLight,
        fontSize: kFontSizeL,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: kCardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorderLight, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: kFontSizeM,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent,
        side: const BorderSide(color: kBorderLight, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: kFontSizeM,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderLight, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAccent, width: 2),
      ),
      labelStyle: const TextStyle(
        color: kMutedLight,
        fontSize: kFontSizeM,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: const TextStyle(
        color: kMutedLight,
        fontSize: kFontSizeM,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: kTextPrimaryLight,
        fontSize: kFontSize2XL,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        color: kTextPrimaryLight,
        fontSize: kFontSizeXL,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: kTextPrimaryLight,
        fontSize: kFontSizeL,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      titleMedium: TextStyle(
        color: kTextPrimaryLight,
        fontSize: kFontSizeM,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      bodyLarge: TextStyle(
        color: kTextPrimaryLight,
        fontSize: kFontSizeM,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
      bodyMedium: TextStyle(
        color: kTextSecondaryLight,
        fontSize: kFontSizeS,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        color: kMutedLight,
        fontSize: kFontSizeXS,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    ),
    dividerColor: kBorderLight,
    dialogTheme: DialogThemeData(
      backgroundColor: kSurfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorderLight, width: 1),
      ),
    ),
  );
}
