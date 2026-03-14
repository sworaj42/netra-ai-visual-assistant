import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // 1. Color Palette (Strictly User Defined)
  // ---------------------------------------------------------------------------
  
  // Backgrounds
  static const Color backgroundLight = Color(0xFFF7F7F8); // Soft Off-White
  static const Color surfaceWhite    = Color(0xFFFFFFFF); // Pure White (Cards)
  static const Color surfaceDark     = Color(0xFF1F1F23); // Charcoal (Dark Cards/AppBars)

  // Primary Action / Brand
  static const Color primaryBrand    = Color(0xFFE53935); // Netra Red
  static const Color primaryBrandDark= Color(0xFFC62828); // Darker Red (Pressed)
  
  // Text
  static const Color textPrimary     = Color(0xFF111114); // Near-Black Charcoal
  static const Color textSecondary   = Color(0xFF6B6B75); // Muted Gray
  
  // Accents & Borders
  static const Color borderColor     = Color(0xFFE6E6EA); // Light Gray
  static const Color dividerColor    = Color(0xFFE0E0E0); 

  // Legacy/Alias mapping for existing widgets to avoid breakage before refactor
  // Ideally we replace these usages, but for now we map them to the new palette.
  static const Color primaryBlue     = surfaceDark;       // Map "Blue" slot to Charcoal
  static const Color primaryGreen    = primaryBrand;      // Map "Green" slot to Crimson

  // ---------------------------------------------------------------------------
  // 2. Gradients (Redefined for Professional Look)
  // ---------------------------------------------------------------------------
  
  // Charcoal Gradient (Executive)
  static const LinearGradient charcoalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2C2C30), Color(0xFF111114)], 
  );

  // Crimson Gradient (Accent)
  static const LinearGradient crimsonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF5350), Color(0xFFD32F2F)], 
  );

  // Aliases for gradients
  static const LinearGradient blueGradient = charcoalGradient;
  static const LinearGradient greenGradient = crimsonGradient;

  // ---------------------------------------------------------------------------
  // 3. Spacing & Radius Constants
  // ---------------------------------------------------------------------------
  static const double spacingXS = 4.0;
  static const double spacingS  = 8.0;
  static const double spacingM  = 12.0; // Standard spacing
  static const double spacingL  = 16.0; // Section padding
  static const double spacingXL = 24.0; // Screen padding

  static const double radiusS   = 8.0;
  static const double radiusM   = 12.0; // Buttons
  static const double radiusL   = 16.0; // Cards

  // ---------------------------------------------------------------------------
  // 4. Shadows (Soft & Subtle)
  // ---------------------------------------------------------------------------
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
     BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  // ---------------------------------------------------------------------------
  // 5. Theme Data
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: surfaceDark,
        secondary: primaryBrand,
        surface: surfaceWhite,
        background: backgroundLight,
        error: primaryBrand,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),

      // App Bar
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: backgroundLight, // Clean look
        foregroundColor: textPrimary,     // Dark text
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.0,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0, // We handle shadows manually usually, or use low elevation
        color: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingS),
      ),

      // Text Theme
      textTheme: const TextTheme(
        // Screen Titles
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        // Card Titles
        titleLarge: TextStyle(
          fontSize: 17, // 16-18
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.0,
        ),
        // Body / Subtitles
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, // 13-14
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: primaryBrand, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      
      // Divider
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
