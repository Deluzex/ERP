import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Sidebar (Matching Figma)
  static const Color sidebarBackground = Color(0xFF000000); // Pure deep black
  static const Color sidebarSurface = Color(0xFF111111);
  static const Color sidebarHover = Color(0xFF1A1A1A);
  static const Color sidebarActiveBackground = Color(0xFFFFFFFF); // Pure white active pill
  static const Color sidebarActiveText = Color(0xFFD9A66E); // Warm caramel gold active text & icon
  static const Color sidebarActiveGreen = Color(0xFF22C55E);
  static const Color sidebarTextMuted = Color(0xFFFFFFFF); // Clean white for inactive items
  static const Color sidebarTextActive = Color(0xFFD9A66E);
  static const Color sidebarBorder = Color(0xFF1F1F1F);

  // Main Background & Surface
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Accent & Brand Colors (Warm Caramel Gold - Figma 500 & 50)
  static const Color primary = Color(0xFFD9A66E); // Brand Primary 500
  static const Color primaryHover = Color(0xFFC68A4C); // Primary Hover
  static const Color primaryDark = Color(0xFFA86F36); // Primary Active/Dark
  static const Color primaryLight = Color(0xFFFFEDDD); // 100 Tint
  static const Color primarySoft = Color(0xFFF9F1EB); // 50 Tint (Light Cream)

  // Status & Utility Colors (Figma Frame 1272628816)
  static const Color success = Color(0xFF16A34A); // Green 500
  static const Color successLight = Color(0xFFDAF0E2); // Green 100
  static const Color successText = Color(0xFF15803D);

  static const Color danger = Color(0xFFFF383C); // Red 500
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color error = danger;

  static const Color warning = Color(0xFFFF6D20); // Orange 500
  static const Color warningLight = Color(0xFFFFEDDD); // Orange 100
  static const Color warningText = Color(0xFFB45309);

  static const Color info = Color(0xFF0068FF); // Blue 500
  static const Color infoLight = Color(0xFFD6ECFF); // Blue 100
  static const Color infoText = Color(0xFF1D4ED8);

  // Category Tag Colors (From Figma Frame 1272628816)
  static const Color categoryPurple = Color(0xFF7B47E9);
  static const Color categoryPurpleBg = Color(0xFFEAE2FB);
  static const Color categoryBlue = Color(0xFF0068FF);
  static const Color categoryBlueBg = Color(0xFFD6ECFF);
  static const Color categoryOrange = Color(0xFFFF6D20);
  static const Color categoryOrangeBg = Color(0xFFFFEDDD);
  static const Color categoryTeal = Color(0xFF00C6B3);
  static const Color categoryTealBg = Color(0xFFD6F6F3);
  static const Color categoryGreen = Color(0xFF16A34A);
  static const Color categoryGreenBg = Color(0xFFDAF0E2);
  static const Color categoryGold = Color(0xFFC6A20F);

  // Backward-compatible Aliases
  static const Color purple = categoryPurple;
  static const Color purpleLight = categoryPurpleBg;
  static const Color teal = categoryTeal;
  static const Color tealLight = categoryTealBg;

  // Neutrals & Grays (From Figma Frame 1272628816)
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFDCDCDC);
  static const Color neutral300 = Color(0xFFD9D9D9);
  static const Color neutral400 = Color(0xFFACADAD);
  static const Color neutral500 = Color(0xFF737686);
  static const Color neutral = Color(0xFF737686);
  static const Color neutralLight = Color(0xFFF5F5F5);
  static const Color neutralText = Color(0xFF374151);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF737686);
  static const Color textDisabled = Color(0xFFACADAD);

  // Card Icon Tints
  static const Color iconBrown = Color(0xFFD9A66E);
  static const Color iconBrownLight = Color(0xFFF9F1EB);
  static const Color iconRed = Color(0xFFFF383C);
  static const Color iconRedLight = Color(0xFFFEF2F0);
  static const Color iconBlue = Color(0xFF0068FF);
  static const Color iconBlueLight = Color(0xFFD6ECFF);
}
