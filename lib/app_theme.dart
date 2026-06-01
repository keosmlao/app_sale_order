import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Theme State Management ──────────────────────────────────────────────────
enum AppThemeMode { light, dark }

class ThemeService {
  static final ValueNotifier<AppThemeMode> themeModeNotifier = ValueNotifier(
    AppThemeMode.light,
  );

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
  // Brand — ODG commerce palette. Teal carries primary actions and workflow
  // progress; amber is reserved for attention, promotion, and sales accents.
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF115E59);
  static const primaryLight = Color(0xFF14B8A6);
  static const primary50 = Color(0xFFECFDF5);
  static const primary100 = Color(0xFFCCFBF1);
  static const accent = Color(0xFFF59E0B);

  // Secondary brand — kept under the old name for compatibility.
  static const brandOrange = Color(0xFFF59E0B);
  static const brandOrangeDark = Color(0xFFD97706);
  static const brandOrangeLight = Color(0xFFFBBF24);
  static const brandOrange50 = Color(0xFFFFF7ED);

  // Status — distinct from brand so they read as status, not as accent.
  static const success = Color(0xFF24A148); // success green
  static const warning = Color(0xFFF59E0B); // amber-500
  static const danger = Color(0xFFEF4444); // red-500
  static const info = Color(0xFF0EA5E9); // sky-500

  // Surfaces — warm grouped background with high-contrast card surfaces.
  static Color get bg =>
      ThemeService.isDark ? const Color(0xFF071A1A) : const Color(0xFFF7F8F3);
  static Color get cardBg =>
      ThemeService.isDark ? const Color(0xFF0D2424) : const Color(0xFFFFFFFF);
  static Color get cardElev =>
      ThemeService.isDark ? const Color(0xFF133333) : const Color(0xFFF0F5F1);
  static Color get border =>
      ThemeService.isDark ? const Color(0xFF1E4644) : const Color(0xFFDCE7E0);
  static Color get divider =>
      ThemeService.isDark ? const Color(0xFF183A39) : const Color(0xFFE6EEE8);

  // Typography — tuned for dense Lao business interfaces.
  static Color get textPrimary =>
      ThemeService.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
  static Color get textSecondary =>
      ThemeService.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  static Color get textMuted =>
      ThemeService.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textSoft =>
      ThemeService.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

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

// ── Typography helpers ──────────────────────────────────────────────────────
// Apply to TextStyles showing numbers in columns (money totals, KPI
// values, table cells). Aligns digits so columns stay vertically tidy
// regardless of which digits appear in the number.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

// ── Corner Radii ────────────────────────────────────────────────────────────
const double kRadiusSm = 8;
const double kRadiusMd = 12;
const double kRadiusLg = 16;
const double kRadiusXl = 20;
const double kRadius2xl = 28;
const double kRadiusPill = 999;

// Spacing scale — single source of truth so screen padding stays consistent.
const double kSpace1 = 4;
const double kSpace2 = 8;
const double kSpace3 = 12;
const double kSpace4 = 16;
const double kSpace5 = 20;
const double kSpace6 = 24;
const double kSpace8 = 32;
const double kSpace10 = 40;

// Motion tokens — match Material 3 Expressive durations.
const Duration kMotionFast = Duration(milliseconds: 180);
const Duration kMotionMed = Duration(milliseconds: 260);
const Duration kMotionSlow = Duration(milliseconds: 420);

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
    border: Border.all(
      color: AppColors.border.withValues(
        alpha: ThemeService.isDark ? 0.42 : 0.7,
      ),
      width: 0.8,
    ),
    boxShadow: elevated
        ? [
            BoxShadow(
              color: ThemeService.isDark
                  ? Colors.black.withValues(alpha: 0.24)
                  : const Color(0x120F766E),
              blurRadius: 16,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
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
        color: AppColors.primary.withValues(
          alpha: ThemeService.isDark ? 0.35 : 0.15,
        ),
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
  colors: [
    AppColors.cardBg,
    ThemeService.isDark ? const Color(0xFF102D2C) : const Color(0xFFFAFCF8),
  ],
);

LinearGradient get kPosActionGradient => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.primary, AppColors.primaryLight],
);

LinearGradient get kAppBackgroundGradient => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomLeft,
  colors: ThemeService.isDark
      ? const [Color(0xFF071A1A), Color(0xFF0B2422)]
      : const [Color(0xFFF7F8F3), Color(0xFFEEF7F3)],
);

// ─── Page Transitions ──────────────────────────────────────────────────────
// Same easing on every platform so push/pop feel coherent: a soft slide
// from right + cross-fade. Slower than the platform default to read as
// intentional, not jittery.

class _SoftSlideTransitionBuilder extends PageTransitionsBuilder {
  const _SoftSlideTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Curves.easeOutCubic;
    final slide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: curve));
    final fade = CurvedAnimation(parent: animation, curve: curve);
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }
}

// ─── Modern UI Kit (sectioned design) ──────────────────────────────────────
// Shared widgets used across every screen to keep section headers, hero
// panels, and card surfaces consistent. Each screen builds its layout
// from these primitives instead of hand-rolling decoration + shadows.

class PageSection extends StatelessWidget {
  const PageSection({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.step,
    this.complete = false,
  });

  final IconData icon;
  final Color accent;
  final String label;
  // Right-aligned chip (e.g. "3 ລາຍການ"). Pre-styled by the section.
  final String? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  // When set, the leading badge becomes a numbered step circle (or a green
  // check once [complete]) — turns a stack of sections into a guided
  // step-by-step flow. Null keeps the plain icon chip (dashboard etc).
  final int? step;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 4, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: complete
                      ? AppColors.success
                      : accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(step != null ? 15 : 9),
                ),
                child: complete
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : (step != null
                          ? Text(
                              '$step',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            )
                          : Icon(icon, color: accent, size: 17)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trailing!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(
              color: AppColors.border.withValues(
                alpha: ThemeService.isDark ? 0.3 : 0.6,
              ),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeService.isDark
                    ? const Color(0x1F000000)
                    : const Color(0x05000000),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

// Legacy `GradientHero` callers keep working, but now render as a subtle
// branded sales panel instead of a plain card.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.child,
    this.onTap,
    this.colors,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 16, 18),
  });

  final Widget child;
  final VoidCallback? onTap;
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final heroColors = colors ?? [AppColors.primary, AppColors.primaryLight];
    final accent = heroColors.first;
    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: ThemeService.isDark ? 0.28 : 0.14),
            AppColors.cardBg,
          ],
        ),
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: AppColors.textPrimary),
        child: IconTheme.merge(
          data: IconThemeData(color: accent),
          child: child,
        ),
      ),
    );
    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: container,
    );
  }
}

// ─── Skeleton (shimmer) loaders ────────────────────────────────────────────
// Replace bare CircularProgressIndicators on data-bound screens with these.
// `SkeletonBox` is a single shimmering placeholder rectangle; compose a few
// to mimic the shape of the real content (rows, hero card, KPI grid…).

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeService.isDark
        ? const Color(0xFF1F2A3C)
        : const Color(0xFFE6EDF3);
    final highlight = ThemeService.isDark
        ? const Color(0xFF2A3A52)
        : const Color(0xFFF5F8FB);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        // Shift the gradient stop based on the animation value so the
        // highlight band travels left → right across the box.
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + (t * 2.5), 0),
              end: Alignment(1 + (t * 2.5), 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

// Pre-baked skeleton patterns — drop into any FutureBuilder while data
// is loading. Each is a stack of SkeletonBox rows shaped like the
// content the screen normally renders.
class SkeletonListPlaceholder extends StatelessWidget {
  const SkeletonListPlaceholder({
    super.key,
    this.rowCount = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.tileHeight = 64,
  });
  final int rowCount;
  final EdgeInsetsGeometry padding;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: rowCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const SkeletonBox(width: 40, height: 40, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SkeletonBox(height: 12, width: 180),
                    SizedBox(height: 8),
                    SkeletonBox(height: 10, width: 100),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SkeletonBox(width: 60, height: 14),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonHeroPlaceholder extends StatelessWidget {
  const SkeletonHeroPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 90, height: 10),
            SizedBox(height: 12),
            SkeletonBox(width: 220, height: 30, radius: 6),
            SizedBox(height: 10),
            Row(
              children: [
                SkeletonBox(width: 80, height: 10),
                SizedBox(width: 12),
                SkeletonBox(width: 80, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Tiny inline stat for hero panels — label string with a leading icon
// in the inherited (typically white) tint.
class HeroStat extends StatelessWidget {
  const HeroStat({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Theme Data Builders ─────────────────────────────────────────────────────

ThemeData buildAppTheme() => buildLightTheme();

ThemeData buildLightTheme() {
  final scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primary50,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: const Color(0xFF111827),
    surface: Colors.white,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.cardElev,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
  );

  TextStyle text(double size, FontWeight weight, [Color? color]) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    height: 1.3,
  );

  return ThemeData(
    fontFamily: GoogleFonts.notoSansLao().fontFamily,
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.cardBg,
    dividerColor: AppColors.divider,
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
      bodyLarge: text(15, FontWeight.w400, AppColors.textPrimary),
      bodyMedium: text(14, FontWeight.w400, AppColors.textPrimary),
      bodySmall: text(13, FontWeight.w400, AppColors.textSecondary),
      labelLarge: text(14, FontWeight.w600),
      labelMedium: text(12, FontWeight.w500, AppColors.textSecondary),
      labelSmall: text(11, FontWeight.w500, AppColors.textMuted),
    ),

    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      actionsIconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
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
      fillColor: AppColors.cardElev,
      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: AppColors.textMuted,
      suffixIconColor: AppColors.textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: false,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.cardElev,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.25),
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
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.25),
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
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border, width: 1),
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
      backgroundColor: AppColors.cardElev,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      side: BorderSide.none,
      selectedColor: AppColors.primary50,
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: AppColors.textPrimary,
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

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.cardElev,
      circularTrackColor: AppColors.cardElev,
    ),

    // App-wide page push/pop animation — same easing on every platform so
    // Android doesn't fade and iOS doesn't slide, both get a soft slide+fade.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SoftSlideTransitionBuilder(),
        TargetPlatform.iOS: _SoftSlideTransitionBuilder(),
        TargetPlatform.fuchsia: _SoftSlideTransitionBuilder(),
        TargetPlatform.linux: _SoftSlideTransitionBuilder(),
        TargetPlatform.macOS: _SoftSlideTransitionBuilder(),
        TargetPlatform.windows: _SoftSlideTransitionBuilder(),
      },
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF12312F),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      actionTextColor: AppColors.primaryLight,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.3,
      ),
      contentTextStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      modalBackgroundColor: AppColors.cardBg,
      showDragHandle: false,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
      dense: false,
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    iconTheme: IconThemeData(color: AppColors.textSecondary, size: 22),

    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      dividerColor: Colors.transparent,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardBg,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
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
        return AppColors.border;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      side: BorderSide(color: AppColors.border, width: 1.5),
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
    primaryContainer: const Color(0xFF123A38),
    onPrimaryContainer: AppColors.primaryLight,
    secondary: AppColors.accent,
    onSecondary: const Color(0xFF111827),
    surface: AppColors.cardBg,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.cardElev,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
  );

  TextStyle text(double size, FontWeight weight, [Color? color]) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    height: 1.3,
  );

  return ThemeData(
    fontFamily: GoogleFonts.notoSansLao().fontFamily,
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.cardBg,
    dividerColor: AppColors.divider,
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
      bodyLarge: text(15, FontWeight.w400, AppColors.textPrimary),
      bodyMedium: text(14, FontWeight.w400, AppColors.textPrimary),
      bodySmall: text(13, FontWeight.w400, AppColors.textMuted),
      labelLarge: text(14, FontWeight.w600),
      labelMedium: text(12, FontWeight.w500, AppColors.textMuted),
      labelSmall: text(11, FontWeight.w500, AppColors.textSoft),
    ),

    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      actionsIconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
    ),

    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardElev,
      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primaryLight,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: AppColors.textMuted,
      suffixIconColor: AppColors.textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: false,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.cardElev,
        disabledForegroundColor: AppColors.textSoft,
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.25),
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
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.25),
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
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border, width: 1),
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
      backgroundColor: AppColors.cardElev,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusXl),
      ),
      side: BorderSide.none,
      selectedColor: const Color(0xFF123A38),
      checkmarkColor: AppColors.primaryLight,
      labelStyle: TextStyle(
        color: AppColors.textPrimary,
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

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primaryLight,
      linearTrackColor: AppColors.cardElev,
      circularTrackColor: AppColors.cardElev,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF12312F),
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
      backgroundColor: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.3,
      ),
      contentTextStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
        height: 1.5,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
      ),
      modalBackgroundColor: AppColors.cardBg,
      showDragHandle: false,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textMuted,
      textColor: AppColors.textPrimary,
      dense: false,
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    iconTheme: IconThemeData(color: AppColors.textMuted, size: 22),

    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSoft,
      indicatorColor: AppColors.primaryLight,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      dividerColor: Colors.transparent,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardBg,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.textSoft,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
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
        return AppColors.cardBg;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.border;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      side: BorderSide(color: AppColors.border, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSm / 2),
      ),
    ),
  );
}

// ─── App Background ──────────────────────────────────────────────────────────
// Flat solid surface — replaces the prior ambient-blob painter for a calmer,
// faster POS aesthetic. The CustomPainter class is kept so any direct callers
// keep compiling, but it now draws a single fill.

class AmbientBackgroundPainter extends CustomPainter {
  AmbientBackgroundPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF071A1A) : const Color(0xFFF7F8F3);
    canvas.drawRect(Offset.zero & size, paint);
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
        return ColoredBox(
          color: isDark ? const Color(0xFF071A1A) : const Color(0xFFF7F8F3),
          child: child,
        );
      },
    );
  }
}

// ─── Card Container ──────────────────────────────────────────────────────────
// Solid surface with a hairline border and tiny shadow — replaces the prior
// glass blur effect. Cheaper to paint and easier to read on Lao/Thai text.
// Class is still called `GlassCard` so existing call sites keep working.

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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.border.withValues(
            alpha: ThemeService.isDark ? 0.3 : 0.6,
          ),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeService.isDark
                ? const Color(0x1F000000)
                : const Color(0x05000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── POS Helpers ─────────────────────────────────────────────────────────────
// Common building blocks used by the redesigned screens.

class StatusPalette {
  final Color bg;
  final Color fg;
  const StatusPalette(this.bg, this.fg);
}

StatusPalette statusPalette(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return StatusPalette(
        const Color(0xFFF59E0B).withValues(alpha: 0.12),
        const Color(0xFFB45309),
      );
    case 'PAID':
      return StatusPalette(
        const Color(0xFF10B981).withValues(alpha: 0.12),
        const Color(0xFF047857),
      );
    case 'SHIPPED':
      return StatusPalette(
        const Color(0xFF0EA5E9).withValues(alpha: 0.12),
        const Color(0xFF0369A1),
      );
    case 'COMPLETED':
      return StatusPalette(
        const Color(0xFF6366F1).withValues(alpha: 0.12),
        const Color(0xFF4338CA),
      );
    case 'CANCELLED':
    case 'CANCELED':
      return StatusPalette(
        const Color(0xFFEF4444).withValues(alpha: 0.12),
        const Color(0xFFB91C1C),
      );
    default:
      return StatusPalette(AppColors.cardElev, AppColors.textSecondary);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.icon});
  final String status;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final p = statusPalette(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: p.fg),
            const SizedBox(width: 4),
          ],
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: p.fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.subtitle,
  });
  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: c),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
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

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
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

// ═════════════════════════════════════════════════════════════════════════════
// MODERN DESIGN SYSTEM — v2.0
// Added 2026-05. New primitives the redesigned screens build on top of.
// Old widgets above stay for compatibility with screens not yet migrated.
// ═════════════════════════════════════════════════════════════════════════════

// ─── Ambient gradient background ────────────────────────────────────────────
// Replaces the flat GlassBackground for hero-tier surfaces. A soft, three-stop
// radial wash that feels less "POS terminal" and more "modern app".

class AmbientGradientBackground extends StatelessWidget {
  const AmbientGradientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == AppThemeMode.dark;
        return Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF071A1A),
                      Color(0xFF0B2422),
                      Color(0xFF1C2A1F),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF9FAF5),
                      Color(0xFFEEF7F3),
                      Color(0xFFF6F0E6),
                    ],
                  ),
          ),
          child: child,
        );
      },
    );
  }
}

// ─── Brand mark ─────────────────────────────────────────────────────────────
// Animated breathing "O" — the visual signature on splash/login.

class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = 88, this.animate = true});
  final double size;
  final bool animate;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final glow = 24 + (t * 12);
        return Container(
          width: widget.size,
          height: widget.size,
          padding: EdgeInsets.all(widget.size * 0.14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.size * 0.28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28 + (t * 0.12)),
                blurRadius: glow,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Image.asset('assets/images/odm.png', fit: BoxFit.contain),
        );
      },
    );
  }
}

// ─── Icon bubble ────────────────────────────────────────────────────────────
// Standardized circular icon container — small/medium/large variants.

enum BubbleSize { sm, md, lg }

class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.icon,
    this.color,
    this.size = BubbleSize.md,
    this.filled = false,
  });
  final IconData icon;
  final Color? color;
  final BubbleSize size;
  // When true, the bubble is solid in [color]; when false (default) it's a
  // 12%-alpha tint with the icon in [color]. Filled reads as a CTA, tinted
  // reads as a label.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final (box, iconSize, radius) = switch (size) {
      BubbleSize.sm => (28.0, 14.0, 9.0),
      BubbleSize.md => (40.0, 20.0, 12.0),
      BubbleSize.lg => (56.0, 26.0, 16.0),
    };
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: filled ? Colors.white : c),
    );
  }
}

// ─── Modern surface card ────────────────────────────────────────────────────
// Replaces ad-hoc Containers with shadow + border. Use this for every list
// row, tile, and modal section.

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(kSpace4),
    this.onTap,
    this.radius = kRadiusLg,
    this.accent,
    this.dense = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  // Optional left-edge accent stripe (e.g. status color).
  final Color? accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    // iOS Clean: flat white card with a hairline border. No shadow — depth
    // is implied by the [AppColors.bg] grouped background showing through
    // the spacing between cards.
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.border.withValues(
            alpha: ThemeService.isDark ? 0.35 : 0.6,
          ),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeService.isDark
                ? const Color(0x22000000)
                : const Color(0x06000000),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    Widget wrapped = card;
    if (accent != null) {
      wrapped = Stack(
        children: [
          card,
          Positioned(
            left: 0,
            top: 12,
            bottom: 12,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      );
    }
    if (onTap == null) return wrapped;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: wrapped,
      ),
    );
  }
}

// ─── Metric card ────────────────────────────────────────────────────────────
// KPI tile with optional trend arrow. Replaces StatTile on dashboards.

enum TrendDir { up, down, flat }

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.trend,
    this.trendLabel,
    this.subtitle,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final TrendDir? trend;
  // E.g. "+12%" or "-3 pcs". Renders next to the trend arrow.
  final String? trendLabel;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.primary;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                IconBubble(icon: icon!, color: c, size: BubbleSize.sm),
                const SizedBox(width: kSpace2),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
              fontFeatures: kTabularFigures,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (trend != null && trendLabel != null) ...[
            const SizedBox(height: kSpace1),
            _TrendBadge(dir: trend!, label: trendLabel!),
          ] else if (subtitle != null) ...[
            const SizedBox(height: kSpace1),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.dir, required this.label});
  final TrendDir dir;
  final String label;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (dir) {
      TrendDir.up => (Icons.trending_up_rounded, AppColors.success),
      TrendDir.down => (Icons.trending_down_rounded, AppColors.danger),
      TrendDir.flat => (Icons.trending_flat_rounded, AppColors.textMuted),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: kTabularFigures,
          ),
        ),
      ],
    );
  }
}

// ─── Section title (modern) ─────────────────────────────────────────────────
// Cleaner replacement for SectionHeader/PageSection — no decoration, just
// a heading + optional action chip on the right.

class ModernSectionTitle extends StatelessWidget {
  const ModernSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
      kSpace4,
      kSpace4,
      kSpace4,
      kSpace2,
    ),
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ─── Quick action button ────────────────────────────────────────────────────
// Compact CTA used on dashboards and the action dock. Big icon stacked over
// a one-line label.

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badge,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  // Tiny number badge (e.g. pending approvals count) on the top-right of
  // the icon. Null = no badge.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace3,
            vertical: kSpace3,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconBubble(icon: icon, color: c, size: BubbleSize.md),
                  if (badge != null && badge! > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                          border: Border.all(color: AppColors.cardBg, width: 2),
                        ),
                        child: Text(
                          badge! > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: kSpace2),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Segmented toggle ───────────────────────────────────────────────────────
// Modern segmented control replacing CupertinoSegmented/ToggleButtons.

class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.compact = false,
  });
  final T value;
  final List<({T value, String label, IconData? icon})> segments;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDark;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF152A20) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seg in segments)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(seg.value),
                child: AnimatedContainer(
                  duration: kMotionFast,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? kSpace3 : kSpace4,
                    vertical: compact ? 6 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: seg.value == value
                        ? AppColors.cardBg
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                    boxShadow: seg.value == value
                        ? [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.4)
                                  : const Color(0x14000000),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (seg.icon != null) ...[
                        Icon(
                          seg.icon,
                          size: compact ? 13 : 15,
                          color: seg.value == value
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        SizedBox(width: compact ? 4 : 6),
                      ],
                      Flexible(
                        child: Text(
                          seg.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: seg.value == value
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: compact ? 11 : 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Filter chip row ────────────────────────────────────────────────────────
// Single-select horizontal chip row. Solves the duplicated chip logic in
// orders/inventory/approval screens.

class ChipFilterRow<T> extends StatelessWidget {
  const ChipFilterRow({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: kSpace4),
  });
  final T value;
  final List<({T value, String label, int? count, Color? color})> items;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: kSpace2),
            _FilterChip(
              label: items[i].label,
              count: items[i].count,
              color: items[i].color,
              selected: items[i].value == value,
              onTap: () => onChanged(items[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final bg = selected ? c : AppColors.cardBg;
    final fg = selected ? Colors.white : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kMotionFast,
        padding: const EdgeInsets.symmetric(
          horizontal: kSpace4,
          vertical: kSpace2 + 1,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.primary50,
                  borderRadius: BorderRadius.circular(kRadiusPill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Search field ───────────────────────────────────────────────────────────
// Standardized search bar with leading icon + optional clear button.

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint = 'ຄົ້ນຫາ…',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.trailing,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, v, _) {
        final hasText = v.text.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.only(left: kSpace4, right: kSpace2),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
              const SizedBox(width: kSpace2),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: kSpace3,
                    ),
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (hasText)
                IconButton(
                  splashRadius: 18,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textMuted,
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
              if (trailing != null) trailing!,
            ],
          ),
        );
      },
    );
  }
}

// ─── Hero panel (modern) ────────────────────────────────────────────────────
// More expressive replacement for GradientHero. Adds an aurora-like blob
// in the corner for depth, with content rendered on top.

class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.child,
    this.colors,
    this.padding = const EdgeInsets.fromLTRB(
      kSpace5,
      kSpace5,
      kSpace5,
      kSpace5,
    ),
    this.height,
  });
  final Widget child;
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final themeColors = colors ?? [AppColors.primary, AppColors.accent];
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeColors,
        ),
        borderRadius: BorderRadius.circular(kRadius2xl),
        boxShadow: [
          BoxShadow(
            color: themeColors.first.withValues(
              alpha: ThemeService.isDark ? 0.35 : 0.2,
            ),
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating bottom nav ────────────────────────────────────────────────────
// Pill-shaped, floating bottom navigation that sits above content with a
// soft shadow. Used by the redesigned HomeScreen.

// iOS Clean tab bar — flat white surface, hairline top border, icon + label
// stacked vertically. Looks like native UITabBar.
class FloatingPillNav extends StatelessWidget {
  const FloatingPillNav({
    super.key,
    required this.index,
    required this.items,
    required this.onTap,
  });
  final int index;
  final List<({IconData icon, IconData activeIcon, String label})> items;
  final ValueChanged<int> onTap;

  static const double _barHeight = 52;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: _barHeight,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _TabItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  label: items[i].label,
                  selected: i == index,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(selected ? activeIcon : icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error banner ───────────────────────────────────────────────────────────
// Standardized inline error / info banner — replaces ad-hoc Container+Icon
// patterns scattered through screens.

enum BannerKind { error, success, info, warning }

class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.kind,
    required this.message,
    this.action,
  });
  final BannerKind kind;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      BannerKind.error => (AppColors.danger, Icons.error_outline_rounded),
      BannerKind.success => (
        AppColors.success,
        Icons.check_circle_outline_rounded,
      ),
      BannerKind.info => (AppColors.info, Icons.info_outline_rounded),
      BannerKind.warning => (AppColors.warning, Icons.warning_amber_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace4,
        vertical: kSpace3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: kSpace2), action!],
        ],
      ),
    );
  }
}

// ─── Loading spinner (branded) ──────────────────────────────────────────────
// Replaces bare CircularProgressIndicator with a centered branded version.

class BrandedSpinner extends StatelessWidget {
  const BrandedSpinner({super.key, this.label, this.size = 22});
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: kSpace3),
            Text(
              label!,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PremiumBackButton extends StatelessWidget {
  const PremiumBackButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: kSpace2),
      child: IconButton(
        tooltip: 'ກັບຄືນ',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.cardElev,
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(
              color: AppColors.border.withValues(
                alpha: ThemeService.isDark ? 0.35 : 0.6,
              ),
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 14,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

PreferredSizeWidget premiumAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  Widget? leading,
  bool centerTitle = false,
}) {
  return AppBar(
    title: Text(
      title,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    ),
    centerTitle: centerTitle,
    backgroundColor: AppColors.cardBg,
    elevation: 0,
    scrolledUnderElevation: 0,
    shape: Border(
      bottom: BorderSide(
        color: AppColors.border.withValues(
          alpha: ThemeService.isDark ? 0.35 : 0.6,
        ),
        width: 0.8,
      ),
    ),
    leading:
        leading ??
        (Navigator.of(context).canPop() ? const PremiumBackButton() : null),
    leadingWidth: leading != null
        ? 56
        : (Navigator.of(context).canPop() ? 56 : null),
    actions: actions,
  );
}
