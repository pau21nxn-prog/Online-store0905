import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - AnnedFinds
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color secondaryOrange = Color(0xFFF7931E);
  static const Color secondaryPink = Color(0xFFE91E63); // New brand color
  static const Color primaryColor = primaryOrange;
  
  // Social Media Brand Colors
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color instagramPink = Color(0xFFE4405F);
  static const Color tiktokBlack = Color(0xFF000000);
  
  // System Colors
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);
  static const Color warningYellow = Color(0xFFFF9800);
  
  // Light theme colors
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightSurfaceGray = Color(0xFFF0F0F0);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceGray = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  
  // Static colors for existing files (backward compatibility)
  static const Color surfaceGray = lightSurfaceGray;
  static const Color textSecondary = lightTextSecondary;
  
  // Dynamic theme-aware functions
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkBackground 
        : lightBackground;
  }
  
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkSurface 
        : lightSurface;
  }
  
  static Color surfaceGrayColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkSurfaceGray 
        : lightSurfaceGray;
  }
  
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkTextPrimary 
        : lightTextPrimary;
  }
  
  static Color textPrimaryColor(BuildContext context) {
    return textPrimary(context);
  }
  
  static Color textSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkTextSecondary 
        : lightTextSecondary;
  }

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Border radius
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: MaterialColor(
      primaryOrange.value,
      <int, Color>{
        50: const Color(0xFFFFF3E0),
        100: const Color(0xFFFFE0B2),
        200: const Color(0xFFFFCC80),
        300: const Color(0xFFFFB74D),
        400: const Color(0xFFFFA726),
        500: primaryOrange,
        600: const Color(0xFFFF8F00),
        700: const Color(0xFFFF8F00),
        800: const Color(0xFFFF8F00),
        900: const Color(0xFFE65100),
      },
    ),
    primaryColor: primaryOrange,
    scaffoldBackgroundColor: lightBackground,
    cardColor: lightSurface,
    colorScheme: const ColorScheme.light(
      primary: primaryOrange,
      secondary: secondaryOrange,
      surface: lightSurface,
      background: lightBackground,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      onBackground: lightTextPrimary,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: lightTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius8),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius8),
        borderSide: const BorderSide(color: primaryOrange, width: 2),
      ),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: MaterialColor(
      primaryOrange.value,
      <int, Color>{
        50: const Color(0xFFFFF3E0),
        100: const Color(0xFFFFE0B2),
        200: const Color(0xFFFFCC80),
        300: const Color(0xFFFFB74D),
        400: const Color(0xFFFFA726),
        500: primaryOrange,
        600: const Color(0xFFFF8F00),
        700: const Color(0xFFFF8F00),
        800: const Color(0xFFFF8F00),
        900: const Color(0xFFE65100),
      },
    ),
    primaryColor: primaryOrange,
    scaffoldBackgroundColor: darkBackground,
    cardColor: darkSurface,
    colorScheme: const ColorScheme.dark(
      primary: primaryOrange,
      secondary: secondaryOrange,
      surface: darkSurface,
      background: darkBackground,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      onBackground: darkTextPrimary,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius8),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius8),
        borderSide: const BorderSide(color: Color(0xFF404040)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius8),
        borderSide: const BorderSide(color: Color(0xFF404040)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius8),
        borderSide: const BorderSide(color: primaryOrange, width: 2),
      ),
    ),
  );

  // Text Styles (compatible with both themes)
  static const TextStyle titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle priceStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryOrange,
  );

  // Brand-specific text styles for AnnedFinds
  static const TextStyle brandLogoStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: primaryOrange,
    letterSpacing: 0.5,
  );

  static const TextStyle brandTaglineStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondaryPink,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle promoMessageStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: primaryOrange,
  );
}