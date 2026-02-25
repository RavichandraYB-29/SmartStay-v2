import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// ADMIN DESIGN SYSTEM
// Centralized tokens for the SmartStay admin UI
// ─────────────────────────────────────────────

class AdminColors {
  AdminColors._();

  // Brand
  static const primary = Color(0xFF6C3BFF);
  static const primaryLight = Color(0xFF9B7BFF);
  static const secondary = Color(0xFF00C2A8);
  static const pink = Color(0xFFE940AF);

  // Status
  static const success = Color(0xFF22C55E);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDBEAFE);

  // Backgrounds
  static const scaffoldLight = Color(0xFFF4F6FB);
  static const scaffoldDark = Color(0xFF0F1117);
  static const cardLight = Colors.white;
  static const cardBorder = Color(0xFFE8ECEF);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // Stat card gradients (background tints)
  static const hostelsBg = Color(0xFFEDE9FE);
  static const floorsBg = Color(0xFFDBEAFE);
  static const roomsBg = Color(0xFFFCE7F3);
  static const residentsBg = Color(0xFFD1FAE5);
  static const bedsBg = Color(0xFFFEF3C7);
  static const pendingBg = Color(0xFFFEE2E2);

  // Stat card icon colors
  static const hostelsIcon = Color(0xFF7C3AED);
  static const floorsIcon = Color(0xFF2563EB);
  static const roomsIcon = Color(0xFFDB2777);
  static const residentsIcon = Color(0xFF059669);
  static const bedsIcon = Color(0xFFD97706);
  static const pendingIcon = Color(0xFFDC2626);
}

class AdminGradients {
  AdminGradients._();

  static const primary = LinearGradient(
    colors: [Color(0xFF6C3BFF), Color(0xFF9B4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const teal = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const pink = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const indigo = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6C3BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emerald = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const amber = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const rose = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const blue = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card header gradients (subtle, for form section headers)
  static const headerLight = LinearGradient(
    colors: [Color(0xFFEFF6FF), Color(0xFFEDE9FE)],
  );

  static const headerTeal = LinearGradient(
    colors: [Color(0xFFE0F2FE), Color(0xFFCCFBF1)],
  );

  static const headerPurple = LinearGradient(
    colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)],
  );
}

class AdminShadows {
  AdminShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const cardHover = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const header = [
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const fab = [
    BoxShadow(
      color: Color(0x336C3BFF),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

class AdminRadius {
  AdminRadius._();

  static const sm = BorderRadius.all(Radius.circular(10));
  static const md = BorderRadius.all(Radius.circular(14));
  static const lg = BorderRadius.all(Radius.circular(18));
  static const xl = BorderRadius.all(Radius.circular(24));

  static const smValue = 10.0;
  static const mdValue = 14.0;
  static const lgValue = 18.0;
  static const xlValue = 24.0;
}

class AdminSpacing {
  AdminSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const pagePadding = EdgeInsets.all(20);
  static const cardPadding = EdgeInsets.all(20);
  static const sectionGap = SizedBox(height: 24);
  static const itemGap = SizedBox(height: 16);
  static const smallGap = SizedBox(height: 8);
}
