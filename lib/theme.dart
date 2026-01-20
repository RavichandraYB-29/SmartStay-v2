import 'package:flutter/material.dart';

class AppTheme {
  /* =========================================================
     LIGHT THEME
  ========================================================= */

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    scaffoldBackgroundColor: const Color(0xFFF8F7FC),

    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C63FF),
      brightness: Brightness.light,
      primary: const Color(0xFF6C63FF),
      secondary: const Color(0xFFA5A1FF),
      surface: Colors.white,
      surfaceVariant: const Color(0xFFF1F0FA),
      outline: const Color(0xFFE3E2EA),
    ),

    cardColor: Colors.white,
    dividerColor: const Color(0xFFE3E2EA),
    dialogBackgroundColor: Colors.white,

    iconTheme: const IconThemeData(color: Color(0xFF2E2E3A)),
    primaryIconTheme: const IconThemeData(color: Color(0xFF2E2E3A)),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF2E2E3A)),
      bodyMedium: TextStyle(color: Color(0xFF2E2E3A)),
      bodySmall: TextStyle(color: Color(0xFF6B6B7A)),
      titleLarge: TextStyle(color: Color(0xFF2E2E3A)),
      titleMedium: TextStyle(color: Color(0xFF2E2E3A)),
      labelMedium: TextStyle(color: Color(0xFF6B6B7A)),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F7FC),
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFF2E2E3A)),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2E2E3A),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF6C63FF),
      foregroundColor: Colors.white,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: Color(0xFF9A9AA8)),
      labelStyle: const TextStyle(color: Color(0xFF6B6B7A)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3E2EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
    ),
  );

  /* =========================================================
     DARK THEME (FIXED)
  ========================================================= */

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    scaffoldBackgroundColor: const Color(0xFF0F1115),

    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C63FF),
      brightness: Brightness.dark,
      primary: const Color(0xFF6C63FF),
      secondary: const Color(0xFFA5A1FF),
      surface: const Color(0xFF1A1D24),
      surfaceVariant: const Color(0xFF222633),
      outline: Colors.white12,
    ),

    cardColor: const Color(0xFF1A1D24),
    dialogBackgroundColor: const Color(0xFF1A1D24),
    dividerColor: Colors.white12,

    iconTheme: const IconThemeData(color: Colors.white),
    primaryIconTheme: const IconThemeData(color: Colors.white),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Color(0xFFB5B5C3)),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      labelMedium: TextStyle(color: Color(0xFFB5B5C3)),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F1115),
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF6C63FF),
      foregroundColor: Colors.white,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1D24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: Color(0xFF8F8FA3)),
      labelStyle: const TextStyle(color: Color(0xFFB5B5C3)),

      // ✅ THIS IS THE KEY FIX
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
    ),
  );
}
