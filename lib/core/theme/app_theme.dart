import 'package:flutter/material.dart';

/// App theme definitions supporting both Light and Dark modes.
/// Designed with Material 3 and curated financial color palettes.
class AppTheme {
  AppTheme._();

  // Emerald/Teal brand colors for financial reliability and elegance
  static const Color _primaryLight = Color(0xFF00684A);
  static const Color _primaryContainerLight = Color(0xFF97F5C5);
  static const Color _secondaryLight = Color(0xFF4C6356);
  static const Color _surfaceLight = Color(0xFFFBFDFA);
  static const Color _backgroundLight = Color(0xFFF5F7F6);

  static const Color _primaryDark = Color(0xFF7BDAAA);
  static const Color _primaryContainerDark = Color(0xFF005139);
  static const Color _secondaryDark = Color(0xFFB3CCBD);
  static const Color _surfaceDark = Color(0xFF191C1A);
  static const Color _backgroundDark = Color(0xFF111413);

  /// Light Theme
  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryLight,
      brightness: Brightness.light,
      primary: _primaryLight,
      primaryContainer: _primaryContainerLight,
      secondary: _secondaryLight,
      surface: _surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundLight,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        indicatorColor: _primaryContainerLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryLight, width: 2),
        ),
      ),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryLight,
      brightness: Brightness.dark,
      primary: _primaryDark,
      primaryContainer: _primaryContainerDark,
      secondary: _secondaryDark,
      surface: _surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundDark,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF242826),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: 3,
        backgroundColor: Color(0xFF1E2220),
        indicatorColor: _primaryContainerDark,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF242826),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3E4340)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3E4340)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryDark, width: 2),
        ),
      ),
    );
  }
}
