import 'package:flutter/material.dart';
export '../theme/app_theme.dart';

/// Base Design System palette tokens (Slate Neutrals + Indigo Accent + Semantic).
/// Prefer `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, and
/// `context.semantic` inside widgets so colors adapt cleanly to Light & Dark modes.
class AppColors {
  // Primary Brand Accent (Indigo)
  static const Color indigoLight = Color(0xFF4F46E5); // Indigo 600 (Light Mode primary)
  static const Color indigoDark = Color(0xFF6366F1); // Indigo 500 (Dark Mode primary)
  static const Color indigoSoftLight = Color(0xFFEEF2FF); // Indigo 50
  static const Color indigoSoftDark = Color(0xFF312E81); // Indigo 900
  static const Color indigoDeep = Color(0xFF4338CA); // Indigo 700
  static const Color indigoBright = Color(0xFF818CF8); // Indigo 400

  // Slate Neutral Scale (Tailwind / Modern SaaS Slate)
  static const Color slate50 = Color(0xFFF8FAFC); // Light scaffold background
  static const Color slate100 = Color(0xFFF1F5F9); // Light elevated surface
  static const Color slate200 = Color(0xFFE2E8F0); // Light border & divider
  static const Color slate300 = Color(0xFFCBD5E1); // Light strong border / Dark secondary text
  static const Color slate400 = Color(0xFF94A3B8); // Dark secondary text / Light faint text
  static const Color slate500 = Color(0xFF64748B); // Light muted text / Dark faint text
  static const Color slate600 = Color(0xFF475569); // Dark strong border
  static const Color slate700 = Color(0xFF334155); // Dark border & divider / Light secondary text
  static const Color slate800 = Color(0xFF1E293B); // Dark surface / card / sidebar
  static const Color slate850 = Color(0xFF172033); // Dark subtle inset / table header
  static const Color slate900 = Color(0xFF0F172A); // Dark scaffold / Light primary text
  static const Color slate950 = Color(0xFF0B1120);

  // Semantic Accents — Light Mode (high contrast on #FFFFFF / #F8FAFC)
  static const Color successLightMode = Color(0xFF059669); // Emerald 600
  static const Color successBgLight = Color(0xFFECFDF5); // Emerald 50
  static const Color warningLightMode = Color(0xFFD97706); // Amber 600
  static const Color warningBgLight = Color(0xFFFFFBEB); // Amber 50
  static const Color dangerLightMode = Color(0xFFDC2626); // Red 600
  static const Color dangerBgLight = Color(0xFFFEF2F2); // Red 50
  static const Color infoLightMode = Color(0xFF0284C7); // Sky 600
  static const Color infoBgLight = Color(0xFFF0F9FF); // Sky 50

  // Semantic Accents — Dark Mode (readable on #1E293B / #0F172A)
  static const Color successDarkMode = Color(0xFF34D399); // Emerald 400
  static const Color successBgDark = Color(0xFF064E3B); // Emerald 900 (used with alpha)
  static const Color warningDarkMode = Color(0xFFFBBF24); // Amber 400
  static const Color warningBgDark = Color(0xFF78350F); // Amber 900 (used with alpha)
  static const Color dangerDarkMode = Color(0xFFF87171); // Red 400
  static const Color dangerBgDark = Color(0xFF7F1D1D); // Red 900 (used with alpha)
  static const Color infoDarkMode = Color(0xFF38BDF8); // Sky 400
  static const Color infoBgDark = Color(0xFF0C4A6E); // Sky 900 (used with alpha)

  // Compatibility aliases mapped to the new Slate/Indigo Design System
  static const Color primary = indigoLight;
  static const Color primaryLight = indigoDark;
  static const Color primaryDark = indigoDeep;
  static const Color primaryAccent = indigoSoftLight;
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
