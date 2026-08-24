# Learnings

## U2. 沉浸式工具栏

- 隐藏只改可见性、不改布局：AppBar 用 `PreferredSize` + `AnimatedOpacity` + `IgnorePointer` 包住，AppBar 槽位始终保留，页面不因隐藏而跳动。
- 隐藏计时器在 `initState` 启动（3 秒），任意交互（`MouseRegion.onHover`、`Focus.onKeyEvent`、滚轮翻页、进度条拖动）都走 `_onActivity` 恢复并重置计时。
- 指针悬停 AppBar 区域时 `_pointerOverChrome` 为 true，计时器持续顺延，不会在悬停时隐藏（R5）。
- 移动端不受影响：隐藏回调先判断 `isDesktopAt`，且移动端布局没有包 `MouseRegion`/快捷键。
- `Focus.onKeyEvent` 返回 `KeyEventResult.ignored` 让按键继续冒泡给 `CallbackShortcuts`，两者不冲突。

## U3. 翻页过渡

- 用 `AnimatedSwitcher` + `ValueKey('reader-page-N')` 实现"目标页立即替换 + 淡入淡出"：快速连翻时当前子项始终是最新页，旧页只做淡出，不阻塞新页。
- 过渡期间新旧两张图同时在树里，依赖 U1 的 `_precacheAround` 让新页通常已在图片缓存中，避免淡入时闪加载圈。
- 加载中与失败占位（`loadingBuilder`/`errorBuilder`）原样保留，符合 R6。

## U1. 键盘翻页

- 键盘处理用 `CallbackShortcuts` + `Focus` 包裹**整个 Scaffold**（不是只包主体），否则焦点落在 AppBar 按钮上时按键无法冒泡到快捷键。
- `Home`/`End` 通过 `_goToPage` 直达章内首尾，只在章内跳转，不触发续章/续书。
- 空格与 PageDown 同为下一页；←/PageUp 为上一页，页首时复用 `_prevPage` 的"回上一章"语义。
- 环境事实：本机 dart/flutter CLI 在无网络访问的沙箱里会卡死（连 `dart format` 都会挂起等待），需要在正常网络环境下运行；构建门禁全程用提权方式执行。
