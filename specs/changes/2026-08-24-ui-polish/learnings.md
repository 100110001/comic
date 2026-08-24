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

## U6. 详情页

- 头部信息区改为面板：surface2 底 + 圆角 10 + 边框，桌面双栏与手机纵向布局通用。
- 封面圆角 8，标题用 `titleMedium`，作者链接/话数保持 accent，收藏与作者星标用令牌色。
- "继续阅读"按钮去掉显式样式，直接吃主题 FilledButton（accent 底黑字）。
- 章节列表标题色 `#c9d1d9` 收敛为 `kText1`，分隔线/竖线走主题。

## U7. 发现与搜索

- 发现主卡加大圆角（14）并加投影（黑 35% + 24 模糊），侧卡圆角 8、透明度 0.6 保持。
- 发现页标题/作者/话数与序列提示全部走令牌；搜索页输入框加前缀搜索图标并走输入框主题。

## U8. 我的与列表

- "我的"页 TabBar 颜色交给 `TabBarThemeData`（label accent、unselected kText2、accent 指示条），去掉显式颜色。
- 列表缩略图圆角 4→8，标题/副标题/星标/箭头全部走令牌；分隔线颜色交给 Divider 主题。

## U9. 阅读器 chrome

- 进度条条底色与文字走令牌，垂直间距收窄（8/2），Slider 走全局细轨道主题（track 3、accent、圆拇指 6）。
- 阅读器 AppBar 保持纯黑沉浸基调，加 1px 底部分隔线（随工具栏一起淡出）；标题/目录图标用 `kText1`。
- 目录抽屉底色 `kSurface1`、选中行 `kSurface2`、选中文字 accent；`_ImageRetryBox` 与移动端加载框底色收敛为 `kSurface1`。
- 阅读器交互（点击呼出、滚轮翻页、键盘、重试）未触碰，全部保持不变。
