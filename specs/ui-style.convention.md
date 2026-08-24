---
status: complete
scope: convention
---

# UI 样式约定

## Responsibilities

规定全 App 深色界面的视觉规范：设计令牌、组件样式与应用方式。现有代码中残留的硬编码色值属于历史偏差，新代码必须走本约定。

## 设计令牌

- 背景 `#0d1117`；面板/导航 `#161b22`；卡片/浮层 `#1c2128`；边框 `#30363d`（强分隔线 `#21262d`）。
- 强调色 `#58a6ff`；主文字 `#e6edf3`；次要文字 `#8b949e`；收藏粉 `#f778ba`；星标黄 `#f5c542`。
- 颜色令牌为**浅/深双套**（`AppColors` `ThemeExtension`），组件经 `context.appColors.*` 取色；浅色沿用 GitHub 浅色体系（背景 `#f6f8fa`、强调 `#0969da`、主文字 `#1f2328`）。圆角为单套常量。
- 导航底色 `navBg`（深 `#1c2128` / 浅 `#f6f8fa`）用于标题栏与侧栏，与内容区背景拉开色差。
- 圆角：卡片 10、缩略图 8、按钮 8、浮层 14、小角 6。
- 中文字体不打包：主题统一声明简体中文回退栈（微软雅黑 → 苹方 → Noto Sans CJK SC），避免系统回退到日文/繁体字形。
- 令牌集中定义在 `lib/theme.dart`（`AppColors.dark`/`AppColors.light` 与 `kRadius*`），页面引用主题色而非裸色值。

## 组件规范

- 所有 Material 组件外观由 `buildAppTheme()` 统一提供：AppBar、Card、按钮、输入框、Slider、导航栏、Tab、SnackBar、分隔线、进度指示器。
- 漫画封面统一由深色卡片承载（圆角 10 + 细边框），占位为 `kSurface2` 底 + `image_not_supported` 图标；收藏角标为黑 55% 底 + `kFavorite` 心形。
- 空态/错误态统一使用 `StatusView`/`EmptyListView`（`lib/widgets/status_views.dart`）：圆形图标底 + 文案 + 可选 tonal 按钮。
- 阅读器保持纯黑沉浸基调：工具栏、进度条、目录走令牌；进度条为细轨道（track 3 + accent 拇指），隐藏/呼出行为不受样式影响。
- 网格卡片文字区保持固定高度，调整字体/间距时必须同步高宽比计算，避免卡片底部留白或文字溢出。
- 交互反馈：侧栏导航项 hover 用 160ms 过渡底色 + accent 水波；网格卡片 hover 轻微放大（1.02）；侧栏页面切换 220ms 淡入 + 上移；滚动条为 8px 细样式。
- 按钮/图标 hover 底色为 accent 8–12% 或半透明白，点击水波 accent 12%；窗口标题栏最小化/最大化 hover 半透明白底 + 图标变亮，关闭按钮红底白图标。
- 深色 `navBg` 为 `#21262d`；路由推入统一为侧滑转场（`CupertinoPageTransitionsBuilder`），不使用缩放弹出。
- 发现页"换一批"为右下角悬浮按钮，页面不设重复标题（侧栏已标识位置）。

## Notes

- 非目标：浅色主题、封面图/图标重绘。
