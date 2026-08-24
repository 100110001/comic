# Learnings

## UI 交互反馈修复

- 全局反馈：主题 `hoverColor` accent 8%、`splashColor` 12%、`highlightColor` 6%；`IconButtonThemeData` 只支持 `hoverColor`（`styleFrom` 没有 `splashColor` 参数），图标按钮水波走全局 splash。
- 窗口按钮：非关闭按钮 hover 半透明白 8% + 图标变 `text1`；此前最小化/最大化的 hover 色 `surface2` 与侧栏底色相同，视觉上"没反应"。
- 区域对比：深色 `navBg` `#1c2128` → `#21262d`，侧栏分隔线换 `c.border`，导航项 hover 底色 `surface2` → `c.border`（否则比侧栏还暗）。
- 转场：`PageTransitionsTheme` 全平台 `CupertinoPageTransitionsBuilder`，去掉 Windows 默认的缩放弹出。
- 注意：`final c = context.appColors;` 别加错 build（误加到 `_MobileShellState` 导致未使用/未定义）。
