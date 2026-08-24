# Learnings

## U1–U3. 托盘开关

- 三个单元耦合紧密（U3 依赖 U1 的 key/持久化），合并为一个提交落地。
- 关闭窗口回调直接读 `shared_preferences`（`kCloseToTrayKey`），不把 Riverpod 状态耦合进平台层；开关写盘后下次关闭立即生效。
- 开关仅 `defaultTargetPlatform == TargetPlatform.windows` 显示（托盘逻辑只在 Windows 生效）；`defaultTargetPlatform` 需要显式 `import 'package:flutter/foundation.dart'`，material 不导出它。
- 关闭时 `windowManager.destroy()` 直接退出；托盘菜单"退出"路径不变。
