import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Adaptive semantic & surface tokens registered on ThemeData.extensions.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color successBg;
  final Color successSolid;
  final Color warning;
  final Color warningBg;
  final Color warningSolid;
  final Color danger;
  final Color dangerBg;
  final Color dangerSolid;
  final Color info;
  final Color infoBg;
  final Color infoSolid;
  final Color secondaryAccent;
  final Color secondaryAccentBg;
  final Color tableHeaderBg;
  final Color hoverBg;
  final Color subtleBg;
  final Color elevatedBg;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textFaint;
  final Color cardShadowColor;

  const AppSemanticColors({
    required this.success,
    required this.successBg,
    required this.successSolid,
    required this.warning,
    required this.warningBg,
    required this.warningSolid,
    required this.danger,
    required this.dangerBg,
    required this.dangerSolid,
    required this.info,
    required this.infoBg,
    required this.infoSolid,
    required this.secondaryAccent,
    required this.secondaryAccentBg,
    required this.tableHeaderBg,
    required this.hoverBg,
    required this.subtleBg,
    required this.elevatedBg,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.cardShadowColor,
  });

  static const AppSemanticColors light = AppSemanticColors(
    success: AppColors.successLightMode,
    successBg: AppColors.successBgLight,
    successSolid: AppColors.successLightMode, // #059669
    warning: AppColors.warningLightMode,
    warningBg: AppColors.warningBgLight,
    warningSolid: Color(0xFFB45309), // Amber 700 (AA contrast with white)
    danger: AppColors.dangerLightMode,
    dangerBg: AppColors.dangerBgLight,
    dangerSolid: AppColors.dangerLightMode, // #DC2626
    info: AppColors.infoLightMode,
    infoBg: AppColors.infoBgLight,
    infoSolid: AppColors.infoLightMode, // #0284C7
    secondaryAccent: Color(0xFF0D9488), // Teal 600
    secondaryAccentBg: Color(0xFFF0FDFA), // Teal 50
    tableHeaderBg: AppColors.slate50,
    hoverBg: AppColors.slate100,
    subtleBg: AppColors.slate50,
    elevatedBg: AppColors.slate100,
    border: AppColors.slate200,
    borderStrong: AppColors.slate300,
    textPrimary: AppColors.slate900,
    textSecondary: AppColors.slate700,
    textMuted: AppColors.slate500,
    textFaint: AppColors.slate400,
    cardShadowColor: Color(0x0A0F172A),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: AppColors.successDarkMode,
    successBg: Color(0x2E10B981),
    successSolid: AppColors.successLightMode, // #059669 (AA contrast with white)
    warning: AppColors.warningDarkMode,
    warningBg: Color(0x2EF59E0B),
    warningSolid: Color(0xFFB45309), // Amber 700 (AA contrast with white)
    danger: AppColors.dangerDarkMode,
    dangerBg: Color(0x2EEF4444),
    dangerSolid: AppColors.dangerLightMode, // #DC2626 (AA contrast with white)
    info: AppColors.infoDarkMode,
    infoBg: Color(0x2E38BDF8),
    infoSolid: AppColors.infoLightMode, // #0284C7 (AA contrast with white)
    secondaryAccent: Color(0xFF2DD4BF), // Teal 400
    secondaryAccentBg: Color(0x2E14B8A6),
    tableHeaderBg: AppColors.slate850,
    hoverBg: Color(0xFF273549),
    subtleBg: AppColors.slate850,
    elevatedBg: Color(0xFF273549),
    border: AppColors.slate700,
    borderStrong: AppColors.slate600,
    textPrimary: AppColors.slate50,
    textSecondary: AppColors.slate300,
    textMuted: AppColors.slate400,
    textFaint: AppColors.slate500,
    cardShadowColor: Color(0x00000000),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successBg,
    Color? successSolid,
    Color? warning,
    Color? warningBg,
    Color? warningSolid,
    Color? danger,
    Color? dangerBg,
    Color? dangerSolid,
    Color? info,
    Color? infoBg,
    Color? infoSolid,
    Color? secondaryAccent,
    Color? secondaryAccentBg,
    Color? tableHeaderBg,
    Color? hoverBg,
    Color? subtleBg,
    Color? elevatedBg,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? cardShadowColor,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      successSolid: successSolid ?? this.successSolid,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      warningSolid: warningSolid ?? this.warningSolid,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerSolid: dangerSolid ?? this.dangerSolid,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      infoSolid: infoSolid ?? this.infoSolid,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      secondaryAccentBg: secondaryAccentBg ?? this.secondaryAccentBg,
      tableHeaderBg: tableHeaderBg ?? this.tableHeaderBg,
      hoverBg: hoverBg ?? this.hoverBg,
      subtleBg: subtleBg ?? this.subtleBg,
      elevatedBg: elevatedBg ?? this.elevatedBg,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      cardShadowColor: cardShadowColor ?? this.cardShadowColor,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successSolid: Color.lerp(successSolid, other.successSolid, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningSolid: Color.lerp(warningSolid, other.warningSolid, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerSolid: Color.lerp(dangerSolid, other.dangerSolid, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      infoSolid: Color.lerp(infoSolid, other.infoSolid, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      secondaryAccentBg: Color.lerp(secondaryAccentBg, other.secondaryAccentBg, t)!,
      tableHeaderBg: Color.lerp(tableHeaderBg, other.tableHeaderBg, t)!,
      hoverBg: Color.lerp(hoverBg, other.hoverBg, t)!,
      subtleBg: Color.lerp(subtleBg, other.subtleBg, t)!,
      elevatedBg: Color.lerp(elevatedBg, other.elevatedBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      cardShadowColor: Color.lerp(cardShadowColor, other.cardShadowColor, t)!,
    );
  }
}

/// Theme-backed helper facade reading directly from `ThemeData.colorScheme`
/// and `AppSemanticColors` so widgets stay 100% reactive to Light/Dark mode.
class AppThemeColors {
  final ThemeData _theme;
  final AppSemanticColors _semantic;

  AppThemeColors(this._theme)
      : _semantic = _theme.extension<AppSemanticColors>() ??
            (_theme.brightness == Brightness.dark
                ? AppSemanticColors.dark
                : AppSemanticColors.light);

  bool get isDark => _theme.brightness == Brightness.dark;
  ColorScheme get _cs => _theme.colorScheme;

  Color get bgScaffold => _theme.scaffoldBackgroundColor;
  Color get bgSubtle => _semantic.subtleBg;
  Color get bgCard => _cs.surface;
  Color get bgElevated => _semantic.elevatedBg;
  Color get bgHover => _semantic.hoverBg;
  Color get bgInput => _cs.surface;
  Color get bgInputElevated => _semantic.elevatedBg;
  Color get bgTableHead => _semantic.tableHeaderBg;
  Color get bgDialog => _cs.surface;
  Color get bgPill => _semantic.elevatedBg;

  Color get border => _semantic.border;
  Color get borderMuted => _semantic.border;
  Color get borderStrong => _semantic.borderStrong;

  Color get textPrimary => _cs.onSurface;
  Color get textSecondary => _semantic.textSecondary;
  Color get textMuted => _cs.onSurfaceVariant;
  Color get textFaint => _semantic.textFaint;

  Color get primary => _cs.primary;
  Color get onPrimary => _cs.onPrimary;
  Color get primaryContainer => _cs.primaryContainer;
  Color get onPrimaryContainer => _cs.onPrimaryContainer;

  Color get success => _semantic.success;
  Color get successBg => _semantic.successBg;
  Color get warning => _semantic.warning;
  Color get warningBg => _semantic.warningBg;
  Color get danger => _semantic.danger;
  Color get dangerBg => _semantic.dangerBg;
  Color get info => _semantic.info;
  Color get infoBg => _semantic.infoBg;
  Color get secondaryAccent => _semantic.secondaryAccent;
  Color get secondaryAccentBg => _semantic.secondaryAccentBg;

  BoxShadow get cardShadow => BoxShadow(
        color: _semantic.cardShadowColor,
        blurRadius: isDark ? 0 : 10,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      );

  List<BoxShadow> get cardShadows => isDark ? const [] : [cardShadow];
}

extension AppThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ??
      (isDarkMode ? AppSemanticColors.dark : AppSemanticColors.light);
  AppThemeColors get colors => AppThemeColors(Theme.of(this));
}

class AppTheme {
  static const double radiusCard = 12.0;
  static const double radiusControl = 8.0;

  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary, Color muted) {
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    return jakarta.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: primary,
        height: 1.2,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
        height: 1.25,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: primary,
        height: 1.3,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: primary,
        height: 1.35,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.35,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.35,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: muted,
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required AppSemanticColors semantic,
    required Color scaffoldBg,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseTheme = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final textTheme = _buildTextTheme(
      baseTheme.textTheme,
      colorScheme.onSurface,
      semantic.textSecondary,
      colorScheme.onSurfaceVariant,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusControl),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusCard),
      side: BorderSide(color: semantic.border, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [semantic],
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: colorScheme.surface,
      textTheme: textTheme,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 18),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      dividerTheme: DividerThemeData(
        color: semantic.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: semantic.elevatedBg,
          disabledForegroundColor: semantic.textFaint,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 40),
          shape: controlShape,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 40),
          shape: controlShape,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: colorScheme.surface,
          side: BorderSide(color: semantic.borderStrong),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 40),
          shape: controlShape,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 38),
          shape: controlShape,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: semantic.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: semantic.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: semantic.border.withValues(alpha: 0.6)),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          color: colorScheme.primary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: semantic.textFaint,
          fontSize: 13,
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(semantic.tableHeaderBg),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.06);
          }
          if (states.contains(WidgetState.hovered)) {
            return semantic.hoverBg.withValues(alpha: 0.65);
          }
          return colorScheme.surface;
        }),
        headingRowHeight: 44,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 68,
        horizontalMargin: 16,
        columnSpacing: 20,
        dividerThickness: 1,
        headingTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: colorScheme.onSurfaceVariant,
        ),
        dataTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        dividerColor: semantic.border,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.elevatedBg,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: semantic.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: BorderSide(color: semantic.border),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusControl),
              side: BorderSide(color: semantic.border),
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.slate800 : AppColors.slate900,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.slate50,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
        side: BorderSide(color: semantic.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.onPrimary;
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return semantic.elevatedBg;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return semantic.borderStrong;
        }),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(6),
        thickness: const WidgetStatePropertyAll(6),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
            return colorScheme.onSurfaceVariant.withValues(alpha: 0.65);
          }
          return colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
        }),
        trackColor: WidgetStatePropertyAll(semantic.border.withValues(alpha: 0.25)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate700 : AppColors.slate900,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.slate50,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.indigoLight, // #4F46E5
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: AppColors.indigoSoftLight, // #EEF2FF
      onPrimaryContainer: AppColors.indigoDeep, // #4338CA
      secondary: Color(0xFF0D9488), // Teal 600
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFF0FDFA),
      onSecondaryContainer: Color(0xFF115E59),
      tertiary: AppColors.infoLightMode, // #0284C7
      onTertiary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: AppColors.slate900, // #0F172A
      onSurfaceVariant: AppColors.slate500, // #64748B
      surfaceContainerLowest: AppColors.slate50, // #F8FAFC
      surfaceContainerLow: AppColors.slate50, // #F8FAFC
      surfaceContainer: AppColors.slate100, // #F1F5F9
      surfaceContainerHigh: AppColors.slate200, // #E2E8F0
      surfaceContainerHighest: AppColors.slate200,
      outline: AppColors.slate300, // #CBD5E1
      outlineVariant: AppColors.slate200, // #E2E8F0
      error: AppColors.dangerLightMode, // #DC2626
      onError: Color(0xFFFFFFFF),
      errorContainer: AppColors.dangerBgLight,
      onErrorContainer: Color(0xFF991B1B),
      shadow: AppColors.slate900,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      semantic: AppSemanticColors.light,
      scaffoldBg: AppColors.slate50, // #F8FAFC
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.indigoDark, // #6366F1
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0x336366F1),
      onPrimaryContainer: AppColors.indigoBright, // #818CF8
      secondary: Color(0xFF2DD4BF), // Teal 400
      onSecondary: AppColors.slate900,
      secondaryContainer: Color(0x2E14B8A6),
      onSecondaryContainer: Color(0xFF5EEAD4),
      tertiary: AppColors.infoDarkMode, // #38BDF8
      onTertiary: AppColors.slate900,
      surface: AppColors.slate800, // #1E293B
      onSurface: AppColors.slate50, // #F8FAFC
      onSurfaceVariant: AppColors.slate400, // #94A3B8
      surfaceContainerLowest: AppColors.slate900, // #0F172A
      surfaceContainerLow: AppColors.slate850, // #172033
      surfaceContainer: Color(0xFF273549),
      surfaceContainerHigh: AppColors.slate700, // #334155
      surfaceContainerHighest: AppColors.slate700,
      outline: AppColors.slate600, // #475569
      outlineVariant: AppColors.slate700, // #334155
      error: AppColors.dangerLightMode, // #DC2626 (AA contrast with white text on error buttons)
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0x2EEF4444),
      onErrorContainer: Color(0xFFFCA5A5),
      shadow: AppColors.slate950,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      semantic: AppSemanticColors.dark,
      scaffoldBg: AppColors.slate900, // #0F172A
    );
  }
}
