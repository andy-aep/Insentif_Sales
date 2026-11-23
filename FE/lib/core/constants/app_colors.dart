import 'package:flutter/material.dart';
export '../theme/app_theme.dart';

/// Base Design System palette tokens (Utilitarian / Precision: Cool Zinc Neutrals +
/// single Maritime Teal brand accent + restrained Semantic status colors).
/// Prefer `Theme.of(context).colorScheme`, `Theme.of(context).textTheme`, and
/// `context.semantic` inside widgets so colors adapt cleanly to Light & Dark modes.
class AppColors {
  // Primary Brand Accent — Deep Maritime Teal (PT Susanti Megah)
  static const Color brandLight = Color(0xFF0F766E); // Teal 700 (5.4:1 with white)
  static const Color brandDark = Color(0xFF0D9488); // Teal 600 (AA with white & crisp on dark)
  static const Color brandSoftLight = Color(0xFFF0FDFA); // Teal 50 whisper surface
  static const Color brandSoftDark = Color(0xFF134E4A); // Teal 900
  static const Color brandDeep = Color(0xFF115E59); // Teal 800
  static const Color brandBright = Color(0xFF5EEAD4); // Teal 300 (dark active text/icon)

  // Neutral Carbon / Zinc Scale (Utilitarian Precision)
  static const Color slate50 = Color(0xFFF6F7F9); // Light scaffold canvas
  static const Color slate100 = Color(0xFFF1F3F6); // Light subtle inset / table header
  static const Color slate150 = Color(0xFFEAECEF); // Light hover / elevated inset
  static const Color slate200 = Color(0xFFE2E6EC); // Light 1px hairline border
  static const Color slate300 = Color(0xFFCBD2DC); // Light strong border / Dark secondary text
  static const Color slate400 = Color(0xFF94A3B8); // Dark muted text / Light faint text
  static const Color slate500 = Color(0xFF64748B); // Light muted text
  static const Color slate600 = Color(0xFF36455E); // Dark strong border
  static const Color slate700 = Color(0xFF243044); // Dark 1px hairline border
  static const Color slate800 = Color(0xFF111827); // Dark surface / card / sidebar
  static const Color slate850 = Color(0xFF161F30); // Dark subtle inset / table header
  static const Color slate875 = Color(0xFF1F2A3E); // Dark hover / elevated inset
  static const Color slate900 = Color(0xFF090D16); // Dark scaffold canvas
  static const Color slate950 = Color(0xFF05080F);

  // Ink Scale (Light Mode high-legibility charcoal)
  static const Color inkPrimary = Color(0xFF111827);
  static const Color inkSecondary = Color(0xFF374151);

  // Semantic Status Accents — Light Mode
  static const Color successLightMode = Color(0xFF15803D); // Forest Green 700
  static const Color successBgLight = Color(0xFFF0FDF4);
  static const Color warningLightMode = Color(0xFFB45309); // Amber 700
  static const Color warningBgLight = Color(0xFFFFFBEB);
  static const Color dangerLightMode = Color(0xFFDC2626); // Red 600
  static const Color dangerBgLight = Color(0xFFFEF2F2);
  static const Color infoLightMode = Color(0xFF0369A1); // Ocean Sky 700
  static const Color infoBgLight = Color(0xFFF0F9FF);

  // Semantic Status Accents — Dark Mode
  static const Color successDarkMode = Color(0xFF34D399); // Emerald 400
  static const Color successBgDark = Color(0xFF064E3B);
  static const Color warningDarkMode = Color(0xFFFBBF24); // Amber 400
  static const Color warningBgDark = Color(0xFF78350F);
  static const Color dangerDarkMode = Color(0xFFF87171); // Red 400
  static const Color dangerBgDark = Color(0xFF7F1D1D);
  static const Color infoDarkMode = Color(0xFF38BDF8); // Sky 400
  static const Color infoBgDark = Color(0xFF0C4A6E);

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
