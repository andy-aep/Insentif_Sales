import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Consistent spacing scale (4px base grid) to eliminate arbitrary magic numbers.
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Consistent sharp border-radius tokens for Maritime Trade Ledger.
class AppRadius {
  static const double tag = 2.0;
  static const double control = 4.0;
  static const double card = 6.0;
}

/// Shared tabular figure font feature for aligned KPIs, currency, tonnage, and tables.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

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
  final Color heroSurface;
  final Color heroOnSurface;
  final Color heroMuted;
  final Color heroBorder;
  final Color heroAccent;

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
    required this.heroSurface,
    required this.heroOnSurface,
    required this.heroMuted,
    required this.heroBorder,
    required this.heroAccent,
  });

  static const AppSemanticColors light = AppSemanticColors(
    success: AppColors.successLightMode,
    successBg: AppColors.successBgLight,
    successSolid: AppColors.successLightMode,
    warning: AppColors.warningLightMode,
    warningBg: AppColors.warningBgLight,
    warningSolid: AppColors.warningLightMode,
    danger: AppColors.dangerLightMode,
    dangerBg: AppColors.dangerBgLight,
    dangerSolid: AppColors.dangerLightMode,
    info: AppColors.infoLightMode,
    infoBg: AppColors.infoBgLight,
    infoSolid: AppColors.infoLightMode,
    secondaryAccent: AppColors.pewterSecondary,
    secondaryAccentBg: AppColors.pewterBgLight,
    tableHeaderBg: AppColors.paperInset,
    hoverBg: AppColors.paperHover,
    subtleBg: AppColors.paperInset,
    elevatedBg: AppColors.paperHover,
    border: AppColors.paperBorder,
    borderStrong: AppColors.paperBorderStrong,
    textPrimary: AppColors.inkPrimary,
    textSecondary: AppColors.inkSecondary,
    textMuted: AppColors.inkMuted,
    textFaint: AppColors.inkFaint,
    cardShadowColor: Color(0x00000000),
    heroSurface: AppColors.brineHeroLight,
    heroOnSurface: AppColors.paperCanvas,
    heroMuted: Color(0xFFA7BAB5),
    heroBorder: AppColors.brineHeroBorder,
    heroAccent: AppColors.brandBright,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: AppColors.successDarkMode,
    successBg: AppColors.successBgDark,
    successSolid: AppColors.successLightMode,
    warning: AppColors.warningDarkMode,
    warningBg: AppColors.warningBgDark,
    warningSolid: AppColors.warningLightMode,
    danger: AppColors.dangerDarkMode,
    dangerBg: AppColors.dangerBgDark,
    dangerSolid: AppColors.dangerLightMode,
    info: AppColors.infoDarkMode,
    infoBg: AppColors.infoBgDark,
    infoSolid: AppColors.infoLightMode,
    secondaryAccent: AppColors.cargoInkSecondary,
    secondaryAccentBg: Color(0x268C948E),
    tableHeaderBg: AppColors.cargoInset,
    hoverBg: AppColors.cargoHover,
    subtleBg: AppColors.cargoInset,
    elevatedBg: AppColors.cargoHover,
    border: AppColors.cargoBorder,
    borderStrong: AppColors.cargoBorderStrong,
    textPrimary: AppColors.cargoInkPrimary,
    textSecondary: AppColors.cargoInkSecondary,
    textMuted: AppColors.cargoInkMuted,
    textFaint: AppColors.cargoInkFaint,
    cardShadowColor: Color(0x00000000),
    heroSurface: AppColors.brineHeroDark,
    heroOnSurface: AppColors.cargoInkPrimary,
    heroMuted: Color(0xFF9EB5AE),
    heroBorder: AppColors.brineHeroBorder,
    heroAccent: AppColors.brandBright,
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
    Color? heroSurface,
    Color? heroOnSurface,
    Color? heroMuted,
    Color? heroBorder,
    Color? heroAccent,
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
      heroSurface: heroSurface ?? this.heroSurface,
      heroOnSurface: heroOnSurface ?? this.heroOnSurface,
      heroMuted: heroMuted ?? this.heroMuted,
      heroBorder: heroBorder ?? this.heroBorder,
      heroAccent: heroAccent ?? this.heroAccent,
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
      heroSurface: Color.lerp(heroSurface, other.heroSurface, t)!,
      heroOnSurface: Color.lerp(heroOnSurface, other.heroOnSurface, t)!,
      heroMuted: Color.lerp(heroMuted, other.heroMuted, t)!,
      heroBorder: Color.lerp(heroBorder, other.heroBorder, t)!,
      heroAccent: Color.lerp(heroAccent, other.heroAccent, t)!,
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

  BoxShadow get cardShadow => const BoxShadow(color: Colors.transparent);
  List<BoxShadow> get cardShadows => const [];
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

  /// Display numeric style using Space Grotesk + tabular figures for KPIs and dashboard totals.
  TextStyle tabularNumStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? colorScheme.onSurface,
      letterSpacing: letterSpacing ?? (fontSize >= 20 ? -0.5 : -0.15),
      height: height,
      fontFeatures: kTabularFigures,
    );
  }

  /// Monospace ledger style using IBM Plex Mono + tabular figures for codes and period IDs.
  TextStyle monoStyle({
    double fontSize = 11.5,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? semantic.textMuted,
      letterSpacing: letterSpacing ?? 0.2,
      height: height,
      fontFeatures: kTabularFigures,
    );
  }
}

class AppTheme {
  static const double radiusCard = AppRadius.card; // 6px
  static const double radiusControl = AppRadius.control; // 4px
  static const double radiusTag = AppRadius.tag; // 2px

  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary, Color muted) {
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    return jakarta.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: primary,
        height: 1.15,
        fontFeatures: kTabularFigures,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
        height: 1.22,
        fontFeatures: kTabularFigures,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 18.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        color: primary,
        height: 1.28,
        fontFeatures: kTabularFigures,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: primary,
        height: 1.32,
        fontFeatures: kTabularFigures,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
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
        height: 1.48,
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
        fontFeatures: kTabularFigures,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondary,
        fontFeatures: kTabularFigures,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        color: muted,
        fontFeatures: kTabularFigures,
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
      dividerColor: semantic.border,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 44),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 44),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          minimumSize: const Size(0, 44),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        headingRowHeight: 40,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 66,
        horizontalMargin: 16,
        columnSpacing: 18,
        dividerThickness: 1,
        headingTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
          color: colorScheme.onSurfaceVariant,
        ),
        dataTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
          fontFeatures: kTabularFigures,
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
          fontFeatures: kTabularFigures,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: BorderSide(color: semantic.borderStrong),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusControl),
              side: BorderSide(color: semantic.borderStrong),
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: isDark ? AppColors.cargoInset : AppColors.inkPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.paperCanvas,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: isDark ? BorderSide(color: semantic.borderStrong) : BorderSide.none,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
        side: BorderSide(color: semantic.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusTag)),
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
        radius: const Radius.circular(radiusTag),
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
          color: isDark ? AppColors.cargoHover : AppColors.inkPrimary,
          borderRadius: BorderRadius.circular(radiusTag),
          border: isDark ? Border.all(color: semantic.borderStrong) : null,
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.paperCanvas,
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
      primary: AppColors.brandLight, // #0B5D51 Deep Maritime Viridian
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: AppColors.brandSoftLight, // #DFECE8
      onPrimaryContainer: AppColors.brandDeep, // #084239
      secondary: AppColors.pewterSecondary, // #525B56
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: AppColors.pewterBgLight,
      onSecondaryContainer: AppColors.inkPrimary,
      tertiary: AppColors.infoLightMode, // #185A7A
      onTertiary: Color(0xFFFFFFFF),
      surface: AppColors.paperCard, // #FCFBF7 Warm Ivory Paper
      onSurface: AppColors.inkPrimary, // #161816 Deep Brine Charcoal
      onSurfaceVariant: AppColors.inkMuted, // #6E736D
      surfaceContainerLowest: AppColors.paperCanvas, // #F6F4EE
      surfaceContainerLow: AppColors.paperInset, // #EFECE4
      surfaceContainer: AppColors.paperHover, // #E6E2D8
      surfaceContainerHigh: AppColors.paperBorder, // #DDD8CE
      surfaceContainerHighest: AppColors.paperBorderStrong, // #C5BEB0
      outline: AppColors.paperBorderStrong, // #C5BEB0
      outlineVariant: AppColors.paperBorder, // #DDD8CE
      error: AppColors.dangerLightMode, // #B93829 Brick Vermilion
      onError: Color(0xFFFFFFFF),
      errorContainer: AppColors.dangerBgLight,
      onErrorContainer: Color(0xFF7F2318),
      shadow: AppColors.inkPrimary,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      semantic: AppSemanticColors.light,
      scaffoldBg: AppColors.paperCanvas, // #F6F4EE Warm Alabaster
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.brandDark, // #1F9E8B Night Cargo Viridian
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: AppColors.brandSoftDark, // #173832
      onPrimaryContainer: AppColors.brandBright, // #6CE0CE
      secondary: AppColors.cargoInkSecondary, // #C7C4BC
      onSecondary: AppColors.cargoCanvas,
      secondaryContainer: AppColors.cargoInset,
      onSecondaryContainer: AppColors.cargoInkPrimary,
      tertiary: AppColors.infoDarkMode, // #58B0DA
      onTertiary: AppColors.cargoCanvas,
      surface: AppColors.cargoSurface, // #151B19
      onSurface: AppColors.cargoInkPrimary, // #F2EFE9
      onSurfaceVariant: AppColors.cargoInkMuted, // #8C948E
      surfaceContainerLowest: AppColors.cargoCanvas, // #0E1211
      surfaceContainerLow: AppColors.cargoInset, // #1C2421
      surfaceContainer: AppColors.cargoHover, // #232D29
      surfaceContainerHigh: AppColors.cargoBorder, // #28332F
      surfaceContainerHighest: AppColors.cargoBorderStrong, // #394742
      outline: AppColors.cargoBorderStrong, // #394742
      outlineVariant: AppColors.cargoBorder, // #28332F
      error: AppColors.dangerLightMode, // #B93829 (AA contrast with white button text)
      onError: Color(0xFFFFFFFF),
      errorContainer: AppColors.dangerBgDark,
      onErrorContainer: AppColors.dangerDarkMode,
      shadow: AppColors.cargoCanvas,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      semantic: AppSemanticColors.dark,
      scaffoldBg: AppColors.cargoCanvas, // #0E1211 Night Cargo Deck
    );
  }
}
