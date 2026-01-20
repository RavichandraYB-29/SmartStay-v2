import 'package:flutter/material.dart';

class AppColors {
  // Brand colors (EXISTING)
  static const primary = Color(0xFF6C3BFF);
  static const secondary = Color(0xFF00C2A8);
  static const pink = Color(0xFFE940AF);

  // Backgrounds & cards
  static const bg = Color(0xFFF6F7FB);
  static const card = Colors.white;

  // Text colors
  static const textDark = Color(0xFF1F2937);
  static const textLight = Color(0xFF6B7280);

  // Status colors
  static const orange = Color(0xFFFF9F43);
  static const red = Color(0xFFFF4757);

  // Borders (ADDED – used by forms)
  static const border = Color(0xFFE5E7EB);

  // ✅ PRIMARY GRADIENT (ADDED – FIXES YOUR ERROR)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF6C3BFF), // primary
      Color(0xFF8B6CFF), // lighter purple
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
