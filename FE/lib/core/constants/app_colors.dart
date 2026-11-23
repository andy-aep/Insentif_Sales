import 'package:flutter/material.dart';
export '../theme/app_theme.dart';

/// Base Design System palette tokens — "Maritime Trade Ledger".
/// Warm Alabaster Paper & Deep Brine Ink (Light) + Night Cargo Deck (Dark).
/// Prefer `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, and
/// `context.semantic` inside widgets so colors adapt cleanly to Light & Dark modes.
class AppColors {
  // Primary Brand Accent — Deep Maritime Viridian
  static const Color brandLight = Color(0xFF0B5D51); // Primary Light (>7:1 on ivory)
  static const Color brandDark = Color(0xFF1F9E8B); // Primary Dark (Night Cargo Deck)
  static const Color brandSoftLight = Color(0xFFDFECE8); // Warm Viridian mist container
  static const Color brandSoftDark = Color(0xFF173832); // Dark Viridian container
  static const Color brandDeep = Color(0xFF084239); // On primaryContainer Light
  static const Color brandBright = Color(0xFF6CE0CE); // On primaryContainer Dark

  // Warm Alabaster Paper Scale (Light Mode)
  static const Color paperCanvas = Color(0xFFF6F4EE); // Warm Alabaster scaffold canvas
  static const Color paperCard = Color(0xFFFCFBF7); // Warm Ivory Paper surface
  static const Color paperInset = Color(0xFFEFECE4); // Warm Sand table head / inset
  static const Color paperHover = Color(0xFFE6E2D8); // Warm hover / elevated inset
  static const Color paperBorder = Color(0xFFDDD8CE); // 1px crisp rule
  static const Color paperBorderStrong = Color(0xFFC5BEB0); // Strong outline & chart target bar

  // Deep Brine Ink & Hero Contrast Surface
  static const Color inkPrimary = Color(0xFF161816); // Deep Brine Charcoal
  static const Color inkSecondary = Color(0xFF3E423E);
  static const Color inkMuted = Color(0xFF6E736D);
  static const Color inkFaint = Color(0xFF9A9E97);
  static const Color brineHeroLight = Color(0xFF142623); // Editorial & Hero Dark Brine panel
  static const Color brineHeroDark = Color(0xFF192E2A); // Night Cargo Hero spotlight
  static const Color brineHeroBorder = Color(0xFF27453F);
  static const Color pewterSecondary = Color(0xFF525B56);
  static const Color pewterBgLight = Color(0xFFEAECE9);

  // Night Cargo Deck Scale (Dark Mode — warm mineral slate, never pure black invert)
  static const Color cargoCanvas = Color(0xFF0E1211);
  static const Color cargoSurface = Color(0xFF151B19);
  static const Color cargoInset = Color(0xFF1C2421);
  static const Color cargoHover = Color(0xFF232D29);
  static const Color cargoBorder = Color(0xFF28332F);
  static const Color cargoBorderStrong = Color(0xFF394742);
  static const Color cargoInkPrimary = Color(0xFFF2EFE9);
  static const Color cargoInkSecondary = Color(0xFFC7C4BC);
  static const Color cargoInkMuted = Color(0xFF8C948E);
  static const Color cargoInkFaint = Color(0xFF5E6661);

  // Semantic Status Accents — Light Mode (harmonized with Warm Alabaster)
  static const Color successLightMode = Color(0xFF1E6B43); // Deep Moss Green
  static const Color successBgLight = Color(0xFFE9F4ED);
  static const Color warningLightMode = Color(0xFFB85D19); // Burnt Amber Salt
  static const Color warningBgLight = Color(0xFFFDF1E6);
  static const Color dangerLightMode = Color(0xFFB93829); // Brick Vermilion
  static const Color dangerBgLight = Color(0xFFFCECE9);
  static const Color infoLightMode = Color(0xFF185A7A); // Deep Harbor Blue
  static const Color infoBgLight = Color(0xFFE8F2F7);

  // Semantic Status Accents — Dark Mode
  static const Color successDarkMode = Color(0xFF4CC38A);
  static const Color successBgDark = Color(0x264CC38A);
  static const Color warningDarkMode = Color(0xFFE89B54);
  static const Color warningBgDark = Color(0x26E89B54);
  static const Color dangerDarkMode = Color(0xFFE56B5E);
  static const Color dangerBgDark = Color(0x26E56B5E);
  static const Color infoDarkMode = Color(0xFF58B0DA);
  static const Color infoBgDark = Color(0x2658B0DA);

  // Compatibility aliases
  static const Color primary = brandLight;
  static const Color primaryLight = brandDark;
  static const Color primaryDark = brandDeep;
  static const Color primaryAccent = brandSoftLight;
  static const Color petrol = infoLightMode;
  static const Color aqua = successDarkMode;
  static const Color success = successLightMode;
  static const Color successLight = successBgLight;
  static const Color warning = warningLightMode;
  static const Color warningLight = warningBgLight;
  static const Color danger = dangerLightMode;
  static const Color dangerLight = dangerBgLight;
  static const Color info = infoLightMode;
  static const Color infoLight = infoBgLight;
}
