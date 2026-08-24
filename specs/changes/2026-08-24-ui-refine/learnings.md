# Learnings

## UI 细节打磨

- **标题栏合并**："漫画库"放进标题栏左侧（并入拖拽区），侧栏删掉标题；右侧 `_PageScaffold` 与发现页的重复标题一并移除（侧栏已有导航标题）。详情/阅读器是独立路由，保留各自标题。
- **导航反馈**：`_SideNavItem` 改 Stateful，`MouseRegion` + `AnimatedContainer`（160ms）过渡底色，`InkWell` 水波 accent 18%。
- **页面切换**：`TweenAnimationBuilder`（key=index，220ms 淡入 + 6px 上移）包 `IndexedStack`，页面状态保留。
- **背景色差**：`AppColors` 新增 `navBg`（深 `#1c2128` / 浅 `#f6f8fa`），标题栏与侧栏同色；浅色 `bg` 改纯白，左右对比清晰。
- **发现页**：刷新按钮改为右下角 `FloatingActionButton.small`，AppBar 移除；切换曲线改 `easeOutBack` 带回弹。
- **窗口记忆**：关闭时 `getBounds()` 写入偏好，启动 `waitUntilReadyToShow(null, ...)` 后 `setBounds` 恢复；注意该方法需要两个参数（WindowOptions?, callback）。
- **主题切换动画**：`MaterialApp` 内置 `AnimatedTheme`（200ms）且 `AppColors` 实现了 lerp，深浅切换已是平滑过渡，无需额外代码。
- **关闭按钮颜色**：X 图标默认白色（浅色模式用深色保证可见），hover 红底时切白色图标，避免红图标叠红底；`_TitleBarButton` 改 Stateful 用 MouseRegion 跟踪 hover。
- **三按钮颜色统一**：最小化/最大化/关闭平时图标同为 `text2`；关闭按钮 hover 红底时图标切白色（Windows 惯例），默认状态三者视觉一致。
