import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Sidebar
  static const Color sidebarBackground = Color(0xFF000000); // Pure deep black
  static const Color sidebarSurface = Color(0xFF111111);
  static const Color sidebarHover = Color(0xFF1A1A1A);
  static const Color sidebarActiveBackground = Color(0xFFFFFFFF); // Pure white active tab
  static const Color sidebarActiveText = Color(0xFFC78950); // Warm copper/gold active text & icon
  static const Color sidebarActiveGreen = Color(0xFF22C55E);
  static const Color sidebarTextMuted = Color(0xFFFFFFFF); // Clean white for inactive items
  static const Color sidebarTextActive = Color(0xFFC78950);
  static const Color sidebarBorder = Color(0xFF1F1F1F);

  // Main Background & Surface
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Accent & Brand Colors (Emerald/Green reference)
  static const Color primary = Color(0xFF10B981); // Emerald / Forest Green
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFFD1FAE5);
  static const Color primarySoft = Color(0xFFECFDF5);

  // Status & Utility Colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF15803D);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color dangerText = Color(0xFFB91C1C);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFFB45309);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoText = Color(0xFF1D4ED8);

  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFEDE9FE);
  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFFCCFBF1);
  static const Color neutral = Color(0xFF6B7280);
  static const Color neutralLight = Color(0xFFF3F4F6);
  static const Color neutralText = Color(0xFF374151);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);

  // Card Icon Tints (matching reference screenshot)
  static const Color iconBrown = Color(0xFFC28153);
  static const Color iconBrownLight = Color(0xFFFDF6F0);
  static const Color iconRed = Color(0xFFE15241);
  static const Color iconRedLight = Color(0xFFFEF2F0);
  static const Color iconBlue = Color(0xFF3B82F6);
  static const Color iconBlueLight = Color(0xFFEFF6FF);
}
