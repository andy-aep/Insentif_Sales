import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppThemeColors {
  final bool isDark;
  const AppThemeColors({required this.isDark});

  // Backgrounds & Surfaces:
  // Light: Airy Misty Sage (#CED7D8 frame -> #F4F7F7 island -> #FFFFFF card)
  // Dark : Elegant Deep Petrol (#0F1C21 frame -> #15262D island -> #1C313A card)
  Color get bgScaffold => isDark ? const Color(0xFF0F1C21) : const Color(0xFFDCE4E5);
  Color get bgSubtle => isDark ? const Color(0xFF15262D) : const Color(0xFFF4F7F7);
  Color get bgCard => isDark ? const Color(0xFF1C313A) : Colors.white;
  Color get bgElevated => isDark ? const Color(0xFF243E49) : const Color(0xFFEAF0F1);
  Color get bgHover => isDark ? const Color(0xFF2A4854) : const Color(0xFFDFE7E8);
  Color get bgInput => isDark ? const Color(0xFF182B33) : Colors.white;
  Color get bgInputElevated => isDark ? const Color(0xFF223B45) : const Color(0xFFEEF3F4);
  Color get bgTableHead => isDark ? const Color(0xFF203842) : const Color(0xFFECF1F2);
  Color get bgDialog => isDark ? const Color(0xFF1C313A) : Colors.white;
  Color get bgPill => isDark ? const Color(0xFF25404B) : const Color(0xFFE8EFF0);

  // Borders (#CED7D8 in Light, softened #316879 in Dark)
  Color get border => isDark ? const Color(0xFF2B4A56) : const Color(0xFFD5DFE0);
  Color get borderMuted => isDark ? const Color(0xFF316879) : const Color(0xFFCED7D8);
  Color get borderStrong => isDark ? const Color(0xFF4C8394) : const Color(0xFFAEC0C2);

  // Typography Colors
  Color get textPrimary => isDark ? const Color(0xFFF2F7F7) : const Color(0xFF182C33);
  Color get textSecondary => isDark ? const Color(0xFFCED7D8) : const Color(0xFF365560);
  Color get textMuted => isDark ? const Color(0xFF8AA3AA) : const Color(0xFF6B858E);
  Color get textFaint => isDark ? const Color(0xFF5D7982) : const Color(0xFF9AB0B6);

  // Diffused Natural Shadows
  BoxShadow get cardShadow => BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.24)
            : const Color(0xFF182C33).withValues(alpha: 0.04),
        blurRadius: 18,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      );

  List<BoxShadow> get cardShadows => [cardShadow];
}

extension AppThemeExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  AppThemeColors get colors => AppThemeColors(isDark: isDarkMode);
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFFDCE4E5),
      canvasColor: const Color(0xFFF4F7F7),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary, // #F47A60 Warm Coral
        secondary: AppColors.petrol, // #316879 Deep Petrol
        tertiary: AppColors.aqua, // #7FE7DC Soft Aqua
        surface: Colors.white,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF182C33),
        outline: Color(0xFFCED7D8),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFDCE4E5), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFCED7D8), width: 1),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF182C33),
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          color: const Color(0xFF365560),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFDCE4E5),
        thickness: 1,
        space: 1,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: const Color(0xFF182C33),
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: const Color(0xFF182C33),
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF182C33),
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFF365560),
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: const Color(0xFF6B858E),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F7F7),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF182C33)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF316879),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFCED7D8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCED7D8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6DFE0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.petrol, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B858E), fontSize: 13),
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF9AB0B6), fontSize: 13),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFF0F1C21),
      canvasColor: const Color(0xFF15262D),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary, // #F47A60 Warm Coral
        secondary: AppColors.aqua, // #7FE7DC Soft Aqua
        tertiary: AppColors.petrol, // #316879 Deep Petrol
        surface: Color(0xFF1C313A),
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Color(0xFF0F1C21),
        onSurface: Color(0xFFF2F7F7),
        outline: Color(0xFF2B4A56),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C313A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2B4A56), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1C313A),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF316879), width: 1),
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF2F7F7),
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          color: const Color(0xFFCED7D8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF26424D),
        thickness: 1,
        space: 1,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: const Color(0xFFF2F7F7),
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: const Color(0xFFF2F7F7),
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF2F7F7),
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFFCED7D8),
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: const Color(0xFF8AA3AA),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF15262D),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF2F7F7)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF7FE7DC),
          backgroundColor: const Color(0xFF203842),
          side: const BorderSide(color: Color(0xFF316879)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF182B33),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF316879)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2B4A56)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.aqua, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF8AA3AA), fontSize: 13),
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF5D7982), fontSize: 13),
      ),
    );
  }
}
