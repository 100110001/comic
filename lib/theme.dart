import 'package:flutter/material.dart';

// ---- 圆角令牌（浅/深共用） ----
const kRadiusSmall = 6.0;
const kRadiusThumb = 8.0;
const kRadiusButton = 8.0;
const kRadiusCard = 10.0;
const kRadiusFloat = 14.0;

/// 双套颜色令牌：组件通过 `context.appColors.*` 取色。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color text1;
  final Color text2;
  final Color favorite;
  final Color star;
  final Color readerBg;
  final Color readerBar;
  final Color navBg;

  const AppColors({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.text1,
    required this.text2,
    required this.favorite,
    required this.star,
    required this.readerBg,
    required this.readerBar,
    required this.navBg,
  });

  static const dark = AppColors(
    bg: Color(0xFF0d1117),
    surface1: Color(0xFF161b22),
    surface2: Color(0xFF1c2128),
    border: Color(0xFF30363d),
    borderStrong: Color(0xFF21262d),
    accent: Color(0xFF58a6ff),
    text1: Color(0xFFe6edf3),
    text2: Color(0xFF8b949e),
    favorite: Color(0xFFf778ba),
    star: Color(0xFFf5c542),
    readerBg: Colors.black,
    readerBar: Color(0xFF161b22),
    navBg: Color(0xFF21262d),
  );

  static const light = AppColors(
    bg: Color(0xFFffffff),
    surface1: Color(0xFFffffff),
    surface2: Color(0xFFffffff),
    border: Color(0xFFd0d7de),
    borderStrong: Color(0xFFd8dee4),
    accent: Color(0xFF0969da),
    text1: Color(0xFF1f2328),
    text2: Color(0xFF57606a),
    favorite: Color(0xFFd03592),
    star: Color(0xFF9a6700),
    readerBg: Color(0xFFf6f8fa),
    readerBar: Color(0xFFffffff),
    navBg: Color(0xFFf6f8fa),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface1,
    Color? surface2,
    Color? border,
    Color? borderStrong,
    Color? accent,
    Color? text1,
    Color? text2,
    Color? favorite,
    Color? star,
    Color? readerBg,
    Color? readerBar,
    Color? navBg,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      accent: accent ?? this.accent,
      text1: text1 ?? this.text1,
      text2: text2 ?? this.text2,
      favorite: favorite ?? this.favorite,
      star: star ?? this.star,
      readerBg: readerBg ?? this.readerBg,
      readerBar: readerBar ?? this.readerBar,
      navBg: navBg ?? this.navBg,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      text1: Color.lerp(text1, other.text1, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      star: Color.lerp(star, other.star, t)!,
      readerBg: Color.lerp(readerBg, other.readerBg, t)!,
      readerBar: Color.lerp(readerBar, other.readerBar, t)!,
      navBg: Color.lerp(navBg, other.navBg, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// 全 App 主题：按亮度构建浅/深两套外观。
ThemeData buildAppTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  // 简体中文优先回退栈：Windows 用微软雅黑，Apple 用苹方，其余走思源黑体。
  // 避免系统回退到日文字体或繁体正黑体导致字形"不像简体"。
  const cjkFallback = <String>[
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'sans-serif',
  ];
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
    secondary: c.accent,
    onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
    secondaryContainer: c.surface2,
    onSecondaryContainer: c.text1,
    surface: c.surface1,
    onSurface: c.text1,
    onSurfaceVariant: c.text2,
    outline: c.border,
    error: brightness == Brightness.dark
        ? const Color(0xFFf85149)
        : const Color(0xFFcf222e),
    onError: brightness == Brightness.dark ? Colors.black : Colors.white,
  );
  final textTheme = TextTheme(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: c.text1,
      letterSpacing: 0.2,
      fontFamilyFallback: cjkFallback,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: c.text1,
      fontFamilyFallback: cjkFallback,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      color: c.text1,
      fontFamilyFallback: cjkFallback,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: c.text1,
      fontFamilyFallback: cjkFallback,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: c.text2,
      fontFamilyFallback: cjkFallback,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: c.text1,
      fontFamilyFallback: cjkFallback,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      color: c.text1,
      fontFamilyFallback: cjkFallback,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      color: c.text2,
      letterSpacing: 0.2,
      fontFamilyFallback: cjkFallback,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    textTheme: textTheme,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface1,
      foregroundColor: c.text1,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: c.text1),
      titleTextStyle: TextStyle(
        color: c.text1,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: c.surface2,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: BorderSide(color: c.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusButton),
        ),
      ).copyWith(animationDuration: const Duration(milliseconds: 150)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface1,
      hintStyle: TextStyle(color: c.text2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: c.accent,
      inactiveTrackColor: c.border,
      thumbColor: c.accent,
      overlayColor: c.accent.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface1,
      indicatorColor: c.accent.withValues(alpha: 0.15),
      selectedIconTheme: IconThemeData(color: c.accent),
      unselectedIconTheme: IconThemeData(color: c.text2),
      selectedLabelTextStyle: TextStyle(color: c.accent, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: c.text2, fontSize: 12),
      labelType: NavigationRailLabelType.all,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface1,
      selectedItemColor: c.accent,
      unselectedItemColor: c.text2,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.accent,
      unselectedLabelColor: c.text2,
      indicatorColor: c.accent,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 14),
    ),
    dividerTheme: DividerThemeData(
      color: c.borderStrong,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surface2,
      contentTextStyle: TextStyle(color: c.text1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(hoverColor: c.accent.withValues(alpha: 0.12)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      thumbColor: WidgetStatePropertyAll(c.text2.withValues(alpha: 0.3)),
      radius: const Radius.circular(4),
    ),
    hoverColor: c.accent.withValues(alpha: 0.08),
    splashColor: c.accent.withValues(alpha: 0.12),
    highlightColor: c.accent.withValues(alpha: 0.06),
  );
}
