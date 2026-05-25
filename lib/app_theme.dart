import 'dart:ui';
import 'package:flutter/material.dart';

// ── Theme State Management ──────────────────────────────────────────────────
enum AppThemeMode { light, dark }

class ThemeService {
  static final ValueNotifier<AppThemeMode> themeModeNotifier = ValueNotifier(AppThemeMode.light);

  static AppThemeMode get currentMode => themeModeNotifier.value;
  static bool get isDark => currentMode == AppThemeMode.dark;

  static void toggleTheme() {
    themeModeNotifier.value = isDark ? AppThemeMode.light : AppThemeMode.dark;
  }

  static void setThemeMode(AppThemeMode mode) {
    themeModeNotifier.value = mode;
  }
}

// ── Dynamic Color Palette ───────────────────────────────────────────────────
class AppColors {
  // Brand — indigo accent scale.
  static const primary = Color(0xFF6366F1);     // indigo-500
  static const primaryDark = Color(0xFF4F46E5); // indigo-600
  static const primaryLight = Color(0xFF818CF8);// indigo-400
  static const primary50 = Color(0xFFEEF2FF);   // tint
  static const primary100 = Color(0xFFE0E7FF);  // tint+
  static const accent = Color(0xFF0EA5E9);      // sky-500

  // Status — Emerald, Amber, Red, Sky.
  static const success = Color(0xFF10B981);     // emerald-500
  static const warning = Color(0xFFF59E0B);     // amber-500
  static const danger = Color(0xFFEF4444);      // red-500
  static const info = Color(0xFF0EA5E9);        // sky-500

  // Dynamic values depending on active ThemeMode.
  static Color get bg => ThemeService.isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
  static Color get cardBg => ThemeService.isDark ? const Color(0xFF131B2E) : const Color(0xFFFFFFFF);
  static Color get cardElev => ThemeService.isDark ? const Color(0xFF1D273E) : const Color(0xFFF1F5F9);
  static Color get border => ThemeService.isDark ? const Color(0xFF232D45) : const Color(0xFFE2E8F0);
  static Color get divider => ThemeService.isDark ? const Color(0xFF1A2338) : const Color(0xFFF1F5F9);

  // Typography.
  static Color get textPrimary => ThemeService.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => ThemeService.isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get textMuted => ThemeService.isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);
  static Color get textSoft => ThemeService.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

  // ── Legacy aliases (preserve compatibility with original references) ──
  static Color get gold => primary;
  static Color get goldBright => primaryLight;
  static Color get goldDim => primaryDark;
  static Color get blue => primary;
  static Color get blueBright => primaryLight;
  static Color get blueDim => primaryDark;
  static Color get teal => primary;
  static Color get tealDark => primaryDark;
  static Color get slate50 => bg;
  static Color get slate100 => cardElev;
  static Color get slate200 => border;
  static Color get slate500 => textMuted;
  static Color get slate700 => textSecondary;
  static Color get slate900 => textPrimary;
}

// ── Corner Radii ────────────────────────────────────────────────────────────
const double kRadiusSm = 8;
const double kRadiusMd = 12;
const double kRadiusLg = 16;
const double kRadiusXl = 20;

// POS tap targets.
const double kTouchTargetMin = 48;
const double kTouchTargetLg = 56;

// Layout breakpoints.
const double kTabletBreakpoint = 720;
const double kWideBreakpoint = 960;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= kTabletBreakpoint;
bool isWide(BuildContext context) =>
    MediaQuery.of(context).size.width >= kWideBreakpoint;

class TabletConstrain extends StatelessWidget {
  const TabletConstrain({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!isTablet(context)) return child;
    return Center(
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

// ─── Surface Helpers ─────────────────────────────────────────────────────────

BoxDecoration posCardDecoration({
  double radius = kRadiusMd,
  bool elevated = true,
}) {
  return BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: elevated
        ? [
            BoxShadow(
              color: ThemeService.isDark ? const Color(0x3D000000) : const Color(0x0A000000),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ]
        : null,
  );
}

BoxDecoration posActionDecoration({double radius = kRadiusLg}) {
  return BoxDecoration(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: ThemeService.isDark ? 0.35 : 0.15),
        blurRadius: 20,
        spreadRadius: -2,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

LinearGradient get kPosCardGradient => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.cardBg, AppColors.cardBg],
    );

LinearGradient get kPosActionGradient => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primary, AppColors.primary],
    );

LinearGradient get kAppBackgroundGradient => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomLeft,
      colors: [AppColors.bg, AppColors.bg],
    );

// ─── Theme Data Builders ─────────────────────────────────────────────────────

ThemeData buildAppTheme() => buildLightTheme();

ThemeData buildLightTheme() {
  final scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primary50,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.primary,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: const Color(0xFF0F172A),
    surfaceContainerHighest: const Color(0xFFF1F5F9),
    error: AppColors.danger,
    onError: Colors.white,
    outline: const Color(0xFFE2E8F0),
    outlineVariant: const Color(0xFFF1F5F9),
  );

  TextStyle text(double size, FontWeight weight, [Color? color]) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? const Color(0xFF0F172A),
        height: 1.3,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.white,
    dividerColor: const Color(0xFFF1F5F9),
    splashFactory: InkRipple.splashFactory,
    splashColor: AppColors.primary.withValues(alpha: 0.08),
    highlightColor: AppColors.primary.withValues(alpha: 0.04),

    textTheme: TextTheme(
      displayLarge: text(34, FontWeight.w700),
      displayMedium: text(28, FontWeight.w700),
      displaySmall: text(24, FontWeight.w700),
      headlineLarge: text(22, FontWeight.w700),
      headlineMedium: text(20, FontWeight.w700),
      headlineSmall: text(18, FontWeight.w600),
      titleLarge: text(17, FontWeight.w600),
      titleMedium: text(15, FontWeight.w600),
      titleSmall: text(13, FontWeight.w600),
      bodyLarge: text(15, FontWeight.w400, const Color(0xFF0F172A)),
      bodyMedium: text(14, FontWeight.w400, const Color(0xFF0F172A)),
      bodySmall: text(13, FontWeight.w400, const Color(0xFF475569)),
      labelLarge: text(14, FontWeight.w600),
      labelMedium: text(12, FontWeight.w500, const Color(0xFF475569)),
      labelSmall: text(11, FontWeight.w500, const Color(0xFF64748B)),
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Color(0xFF0F172A),
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFF0F172A), size: 22),
      actionsIconTheme: IconThemeData(color: Color(0xFF0F172A), size: 22),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: const Color(0xFF64748B),
      suffixIconColor: const Color(0xFF64748B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: false,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFF1F5F9),
        disabledForegroundColor: const Color(0xFF64748B),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        minimumSize: const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      side: BorderSide.none,
      selectedColor: AppColors.primary50,
      checkmarkColor: AppColors.primary,
      labelStyle: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: Color(0xFFF1F5F9),
      circularTrackColor: Color(0xFFF1F5F9),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      titleTextStyle: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.3,
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 14,
        height: 1.5,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      modalBackgroundColor: Colors.white,
      showDragHandle: true,
      dragHandleColor: Color(0xFFE2E8F0),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF475569),
      textColor: Color(0xFF0F172A),
      dense: false,
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    iconTheme: const IconThemeData(color: Color(0xFF475569), size: 22),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFF1F5F9),
      thickness: 1,
      space: 1,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: const Color(0xFF0F172A),
      unselectedLabelColor: const Color(0xFF64748B),
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      dividerColor: Colors.transparent,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Color(0xFF64748B),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      showUnselectedLabels: true,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return const Color(0xFFE2E8F0);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSm / 2),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF1E294B),
    onPrimaryContainer: AppColors.primaryLight,
    secondary: AppColors.primary,
    onSecondary: Colors.white,
    surface: const Color(0xFF131B2E),
    onSurface: const Color(0xFFF8FAFC),
    surfaceContainerHighest: const Color(0xFF1D273E),
    error: AppColors.danger,
    onError: Colors.white,
    outline: const Color(0xFF232D45),
    outlineVariant: const Color(0xFF1A2338),
  );

  TextStyle text(double size, FontWeight weight, [Color? color]) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? const Color(0xFFF8FAFC),
        height: 1.3,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: const Color(0xFF131B2E),
    dividerColor: const Color(0xFF1A2338),
    splashFactory: InkRipple.splashFactory,
    splashColor: AppColors.primary.withValues(alpha: 0.15),
    highlightColor: AppColors.primary.withValues(alpha: 0.08),

    textTheme: TextTheme(
      displayLarge: text(34, FontWeight.w700),
      displayMedium: text(28, FontWeight.w700),
      displaySmall: text(24, FontWeight.w700),
      headlineLarge: text(22, FontWeight.w700),
      headlineMedium: text(20, FontWeight.w700),
      headlineSmall: text(18, FontWeight.w600),
      titleLarge: text(17, FontWeight.w600),
      titleMedium: text(15, FontWeight.w600),
      titleSmall: text(13, FontWeight.w600),
      bodyLarge: text(15, FontWeight.w400, const Color(0xFFF8FAFC)),
      bodyMedium: text(14, FontWeight.w400, const Color(0xFFF8FAFC)),
      bodySmall: text(13, FontWeight.w400, const Color(0xFF94A3B8)),
      labelLarge: text(14, FontWeight.w600),
      labelMedium: text(12, FontWeight.w500, const Color(0xFF94A3B8)),
      labelSmall: text(11, FontWeight.w500, const Color(0xFF64748B)),
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Color(0xFFF8FAFC),
      titleTextStyle: TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFFF8FAFC), size: 22),
      actionsIconTheme: IconThemeData(color: Color(0xFFF8FAFC), size: 22),
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF131B2E),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1D273E),
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primaryLight,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: const Color(0xFF64748B),
      suffixIconColor: const Color(0xFF64748B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: false,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF1D273E),
        disabledForegroundColor: const Color(0xFF64748B),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFF8FAFC),
        side: const BorderSide(color: Color(0xFF232D45), width: 1),
        minimumSize: const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1D273E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      side: BorderSide.none,
      selectedColor: const Color(0xFF1E294B),
      checkmarkColor: AppColors.primaryLight,
      labelStyle: const TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primaryLight,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryLight,
      linearTrackColor: Color(0xFF1D273E),
      circularTrackColor: Color(0xFF1D273E),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1D273E),
      contentTextStyle: const TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF131B2E),
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      titleTextStyle: const TextStyle(
        color: Color(0xFFF8FAFC),
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.3,
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        height: 1.5,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF131B2E),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      modalBackgroundColor: Color(0xFF131B2E),
      showDragHandle: true,
      dragHandleColor: Color(0xFF232D45),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF94A3B8),
      textColor: Color(0xFFF8FAFC),
      dense: false,
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    iconTheme: const IconThemeData(color: Color(0xFF94A3B8), size: 22),

    dividerTheme: const DividerThemeData(
      color: Color(0xFF1A2338),
      thickness: 1,
      space: 1,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: const Color(0xFFF8FAFC),
      unselectedLabelColor: const Color(0xFF64748B),
      indicatorColor: AppColors.primaryLight,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      dividerColor: Colors.transparent,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF131B2E),
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: Color(0xFF64748B),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      showUnselectedLabels: true,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return const Color(0xFF131B2E);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return const Color(0xFF232D45);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      side: const BorderSide(color: Color(0xFF232D45), width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSm / 2),
      ),
    ),
  );
}

// ─── Ambient Glowing Background ──────────────────────────────────────────────

class AmbientBackgroundPainter extends CustomPainter {
  AmbientBackgroundPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base color gradient
    final baseGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF070B14), Color(0xFF0E1424)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          );

    final basePaint = Paint()..shader = baseGradient.createShader(rect);
    canvas.drawRect(rect, basePaint);

    // Blurry ambient blobs
    final blobPaint1 = Paint()
      ..color = isDark
          ? const Color(0xFF6366F1).withValues(alpha: 0.09) // Indigo glow
          : const Color(0xFF818CF8).withValues(alpha: 0.08)
      ..imageFilter = ImageFilter.blur(sigmaX: 90, sigmaY: 90);

    final blobPaint2 = Paint()
      ..color = isDark
          ? const Color(0xFF0EA5E9).withValues(alpha: 0.08) // Sky glow
          : const Color(0xFF38BDF8).withValues(alpha: 0.07)
      ..imageFilter = ImageFilter.blur(sigmaX: 100, sigmaY: 100);

    final blobPaint3 = Paint()
      ..color = isDark
          ? const Color(0xFFEC4899).withValues(alpha: 0.04) // Fuchsia glow
          : const Color(0xFFF472B6).withValues(alpha: 0.04)
      ..imageFilter = ImageFilter.blur(sigmaX: 80, sigmaY: 80);

    // Draw the ambient circles with blur filter
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.15), size.width * 0.5, blobPaint1);
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.8), size.width * 0.55, blobPaint2);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), size.width * 0.4, blobPaint3);
  }

  @override
  bool shouldRepaint(covariant AmbientBackgroundPainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}

class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == AppThemeMode.dark;
        return CustomPaint(
          painter: AmbientBackgroundPainter(isDark: isDark),
          child: child,
        );
      },
    );
  }
}

// ─── Glassmorphic Card Container ─────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = kRadiusLg,
    this.borderOpacity = 0.08,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                : const Color(0xFFFFFFFF).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: borderOpacity)
                  : Colors.black.withValues(alpha: borderOpacity),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : const Color(0x05000000),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Micro-Animation Helper ──────────────────────────────────────────────────

class FadeInSlide extends StatefulWidget {
  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 16),
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
