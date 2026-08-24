# Learnings

## U1–U3. 自定义窗口标题栏

- `setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false)` 放在 `setupCloseToTray`（Windows 分支）里，与托盘设置同处初始化。
- 标题栏挂在 `MaterialApp.builder` 层：`Column(标题栏 + Expanded(child))`，覆盖所有路由（含阅读器）；组件自带 `Material` 外壳，避免 builder 层缺少 Material 祖先导致 InkWell/Tooltip 失效。
- 拖拽用 `GestureDetector.onPanStart -> windowManager.startDragging()`，双击切换最大化；最大化状态通过 `WindowListener.onWindowMaximize/onWindowUnmaximize` 同步。
- 关闭按钮只调 `windowManager.close()`，托盘 `onWindowClose` 逻辑（closeToTray 设置）零改动。
- 三个单元耦合紧密（U2/U3 依赖 U1 的平台判定），合并为一次实现提交。
