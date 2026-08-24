# Learnings

## U2. 沉浸式工具栏

- 隐藏只改可见性、不改布局：AppBar 用 `PreferredSize` + `AnimatedOpacity` + `IgnorePointer` 包住，AppBar 槽位始终保留，页面不因隐藏而跳动。
- 隐藏计时器在 `initState` 启动（3 秒），只有点击阅读区（`GestureDetector.onTap`）、按键（`Focus.onKeyEvent`）和进度条拖动会走 `_onActivity` 恢复并重置计时；**滚轮翻页按用户反馈不算交互**，不恢复工具栏也不重置隐藏计时。
- 指针悬停 AppBar 区域时 `_pointerOverChrome` 为 true，计时器持续顺延，不会在悬停时隐藏（R5）。
- 移动端不受影响：隐藏回调先判断 `isDesktopAt`，且移动端布局没有包 `MouseRegion`/快捷键。
- `Focus.onKeyEvent` 返回 `KeyEventResult.ignored` 让按键继续冒泡给 `CallbackShortcuts`，两者不冲突。

## U4. 图片失败重试

- 单图重试：失败态改为可点击的 `_ImageRetryBox`，重试前先 `imageCache.evict(NetworkImage(url))`，再靠 `ValueKey` 变化强制重建 `Image.network` 重新拉取。
- 桌面当前页图片 key 为 `page-img-$page-$_imageRetryTick`；移动端每项 key 为 `lazy-$url-$_retryTick`。
- 章节级加载失败与"真没有图"分开：`_buildChapterBody` 统一处理加载中/失败/空章/正常四态，桌面与移动端都提供"重试"按钮。
- `clamp` 返回 `num`，作为列表下标前必须 `.toInt()`，否则 analyze 报类型错误。
- `_ImageRetryBox` 做成 const 无状态组件，桌面与移动端共用。

## U1. 键盘翻页

- 键盘处理用 `CallbackShortcuts` + `Focus` 包裹**整个 Scaffold**（不是只包主体），否则焦点落在 AppBar 按钮上时按键无法冒泡到快捷键。
- `Home`/`End` 通过 `_goToPage` 直达章内首尾，只在章内跳转，不触发续章/续书。
- 空格与 PageDown 同为下一页；←/PageUp 为上一页，页首时复用 `_prevPage` 的"回上一章"语义。
- 环境事实：本机 dart/flutter CLI 在无网络访问的沙箱里会卡死（连 `dart format` 都会挂起等待），需要在正常网络环境下运行；构建门禁全程用提权方式执行。
