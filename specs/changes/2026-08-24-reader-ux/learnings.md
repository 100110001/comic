# Learnings

## U1. 键盘翻页

- 键盘处理用 `CallbackShortcuts` + `Focus` 包裹**整个 Scaffold**（不是只包主体），否则焦点落在 AppBar 按钮上时按键无法冒泡到快捷键。
- `Home`/`End` 通过 `_goToPage` 直达章内首尾，只在章内跳转，不触发续章/续书。
- 空格与 PageDown 同为下一页；←/PageUp 为上一页，页首时复用 `_prevPage` 的"回上一章"语义。
- 环境事实：本机 dart/flutter CLI 在无网络访问的沙箱里会卡死（连 `dart format` 都会挂起等待），需要在正常网络环境下运行；构建门禁全程用提权方式执行。
