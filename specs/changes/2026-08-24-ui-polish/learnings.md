# Learnings

## U1. 主题令牌与组件主题

- 设计令牌集中在 `lib/theme.dart`：颜色（`kBg`/`kSurface1`/`kSurface2`/`kBorder`/`kAccent`/`kText1`/`kText2`）与圆角（`kRadiusCard` 10 / `kRadiusThumb` 8 / `kRadiusButton` 8 / `kRadiusFloat` 14）。
- `NavigationRailThemeData` 没有 `iconTheme` 参数（analyze 报错），图标尺寸用默认 24，只设选中/未选中颜色。
- `TabBarThemeData.dividerColor` 与 `CardThemeData` 在当前 Flutter 版本可用。
- 主文字用 `#e6edf3` 而非纯白，次要文字 `#8b949e`，与 GitHub 深色体系一致。

## U2. 通用状态组件

- 新增 `lib/widgets/status_views.dart`：`StatusView`（圆形图标底 + 文案 + 可选 tonal 按钮）与 `EmptyListView`（带 AlwaysScrollable 的列表空态，兼容下拉刷新）。
- 移除 home/detail/discovery/search/reading_lists/reader 六处重复的错误/空态实现，统一走共用组件。
