# Learnings

## U1. 主题令牌与组件主题

- 设计令牌集中在 `lib/theme.dart`：颜色（`kBg`/`kSurface1`/`kSurface2`/`kBorder`/`kAccent`/`kText1`/`kText2`）与圆角（`kRadiusCard` 10 / `kRadiusThumb` 8 / `kRadiusButton` 8 / `kRadiusFloat` 14）。
- `NavigationRailThemeData` 没有 `iconTheme` 参数（analyze 报错），图标尺寸用默认 24，只设选中/未选中颜色。
- `TabBarThemeData.dividerColor` 与 `CardThemeData` 在当前 Flutter 版本可用。
- 主文字用 `#e6edf3` 而非纯白，次要文字 `#8b949e`，与 GitHub 深色体系一致。

## U2. 通用状态组件

- 新增 `lib/widgets/status_views.dart`：`StatusView`（圆形图标底 + 文案 + 可选 tonal 按钮）与 `EmptyListView`（带 AlwaysScrollable 的列表空态，兼容下拉刷新）。
- 移除 home/detail/discovery/search/reading_lists/reader 六处重复的错误/空态实现，统一走共用组件。

## U3. 漫画卡片与网格

- 卡片原来是白底黑字（`Colors.white` + `#1a1a1a`），在深色 App 里非常突兀；改为主题 surface2 + 主文字令牌，去掉了显式 elevation/shape。
- 文字区固定高度从 48 调到 50（标题字号 12→13），网格高宽比计算同步更新，避免文字溢出；卡片间距 10→12、页边距 12→16。
- 封面角标与"话数/P"标签统一为黑 55% 底 + 圆角 6。

## U4. 外壳导航

- 桌面侧栏与手机底部 tab 全部去掉硬编码颜色/文字样式，改由 `NavigationRailThemeData`/`BottomNavigationBarThemeData` 统一提供（选中胶囊、accent 图标、12px 标签）。
- `_PageScaffold` 与 `VerticalDivider` 走主题，移除显式色值。

## U5. 首页

- 桌面搜索框改为"胶囊"样式：surface2 底 + 圆角 8 + 细边框，最大宽度 420，替代原来的裸输入框。
- 悬浮续读条改用 surface2 + 圆角 14 + 边框 + 轻阴影，缩略图圆角 8，文字走令牌。
- AppBar 底色/搜索按钮等去掉硬编码，交给主题。
