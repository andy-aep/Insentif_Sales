import 'package:flutter/material.dart';
export '../theme/app_theme.dart';

class AppColors {
  // Core 4-Color Swatch Palette:
  // 1. Deep Petrol Teal : #316879
  // 2. Warm Coral       : #F47A60
  // 3. Soft Aqua Mint   : #7FE7DC
  // 4. Misty Sage Gray  : #CED7D8

  static const Color petrol = Color(0xFF316879);
  static const Color coral = Color(0xFFF47A60);
  static const Color aqua = Color(0xFF7FE7DC);
  static const Color mist = Color(0xFFCED7D8);

  // Primary Brand Accent (Warm Coral #F47A60 + Deep Petrol #316879)
  static const Color primary = Color(0xFFF47A60); // Warm Coral (#f47a60)
  static const Color primaryLight = Color(0xFFF7927C); // Soft Coral
  static const Color primaryDark = Color(0xFFD95E44); // Deep Terracotta Coral
  static const Color primaryAccent = Color(0xFFFDECE8); // Soft Coral Blush Pill

  // Misty Sage & Petrol Neutrals
  static const Color slate50 = Color(0xFFF4F7F7); // Airy Misty Alabaster
  static const Color slate100 = Color(0xFFEBF0F1); // Light Misty Gray
  static const Color slate200 = Color(0xFFD6DFE0); // Soft Mist Border
  static const Color slate300 = Color(0xFFCED7D8); // Swatch #ced7d8
  static const Color slate400 = Color(0xFF8AA3AA); // Muted Petrol Mist
  static const Color slate500 = Color(0xFF5E7A82); // Medium Petrol Slate
  static const Color slate600 = Color(0xFF3E5C66); // Deep Slate Gray
  static const Color slate700 = Color(0xFF316879); // Swatch #316879
  static const Color slate800 = Color(0xFF203841); // Elevated Dark Petrol
  static const Color slate900 = Color(0xFF172A31); // Deep Petrol Card
  static const Color slate950 = Color(0xFF0F1C21); // Midnight Petrol Canvas

  // Semantic Accents Harmonized with the 4-Color Swatch
  static const Color success = Color(0xFF24968B); // Deepened #7fe7dc for crisp text/icons
  static const Color successLight = Color(0xFFDDF9F6); // Soft #7fe7dc Mint Pill
  static const Color warning = Color(0xFFF47A60); // Warm Coral (#f47a60)
  static const Color warningLight = Color(0xFFFDECE8); // Soft Coral Pill
  static const Color danger = Color(0xFFD9534F); // Warm Crimson Coral
  static const Color dangerLight = Color(0xFFFCE8E8); // Soft Rose Pill
  static const Color info = Color(0xFF316879); // Deep Petrol Teal (#316879)
  static const Color infoLight = Color(0xFFE3EFF2); // Soft Petrol Pill

  // Background & Surfaces
  static const Color bgDark = Color(0xFF0F1C21);
  static const Color cardDark = Color(0xFF1B3038);
  static const Color cardDarkElevated = Color(0xFF233D47);
  static const Color cardLight = Colors.white;
  static const Color borderDark = Color(0xFF2B4A56);
  static const Color borderLight = Color(0xFFD6DFE0);

  // Subtle overlays
  static Color glassWhite = Colors.white.withValues(alpha: 0.07);
  static Color glassBorder = const Color(0xFF7FE7DC).withValues(alpha: 0.14);
  static Color glassShadow = const Color(0xFF182C33).withValues(alpha: 0.05);

  // Harmonized Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF47A60), Color(0xFFE06348)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF316879), Color(0xFF24968B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF1E353E), Color(0xFF15262D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
