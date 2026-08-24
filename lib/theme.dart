import 'package:flutter/material.dart';

// ---- 设计令牌：颜色 ----
const kBg = Color(0xFF0d1117);
const kSurface1 = Color(0xFF161b22);
const kSurface2 = Color(0xFF1c2128);
const kBorder = Color(0xFF30363d);
const kBorderStrong = Color(0xFF21262d);
const kAccent = Color(0xFF58a6ff);
const kText1 = Color(0xFFe6edf3);
const kText2 = Color(0xFF8b949e);
const kFavorite = Color(0xFFf778ba);
const kStar = Color(0xFFf5c542);

// ---- 设计令牌：圆角 ----
const kRadiusSmall = 6.0;
const kRadiusThumb = 8.0;
const kRadiusButton = 8.0;
const kRadiusCard = 10.0;
const kRadiusFloat = 14.0;

/// 全 App 深色主题：延续 GitHub 深色体系，统一组件外观。
ThemeData buildAppTheme() {
  final scheme = const ColorScheme.dark(
    primary: kAccent,
    onPrimary: Colors.black,
    secondaryContainer: kSurface2,
    onSecondaryContainer: kText1,
    surface: kSurface1,
    onSurface: kText1,
    onSurfaceVariant: kText2,
    outline: kBorder,
  );
  const textTheme = TextTheme(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kText1,
      letterSpacing: 0.2,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: kText1,
    ),
    bodyLarge: TextStyle(fontSize: 15, color: kText1),
    bodyMedium: TextStyle(fontSize: 14, color: kText1),
    bodySmall: TextStyle(fontSize: 12, color: kText2),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: kText1,
    ),
    labelMedium: TextStyle(fontSize: 12, color: kText1),
    labelSmall: TextStyle(fontSize: 11, color: kText2, letterSpacing: 0.2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface1,
      foregroundColor: kText1,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: kText1),
      titleTextStyle: TextStyle(
        color: kText1,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: kSurface2,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: const BorderSide(color: kBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusButton),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface1,
      hintStyle: const TextStyle(color: kText2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: kAccent,
      inactiveTrackColor: kBorder,
      thumbColor: kAccent,
      overlayColor: kAccent.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: kSurface1,
      indicatorColor: Color(0x2658a6ff),
      selectedIconTheme: IconThemeData(color: kAccent),
      unselectedIconTheme: IconThemeData(color: kText2),
      selectedLabelTextStyle: TextStyle(color: kAccent, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: kText2, fontSize: 12),
      labelType: NavigationRailLabelType.all,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurface1,
      selectedItemColor: kAccent,
      unselectedItemColor: kText2,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kAccent,
      unselectedLabelColor: kText2,
      indicatorColor: kAccent,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: kBorderStrong,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSurface2,
      contentTextStyle: const TextStyle(color: kText1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusButton),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kAccent),
    splashColor: kAccent.withValues(alpha: 0.06),
    highlightColor: kAccent.withValues(alpha: 0.05),
  );
}
