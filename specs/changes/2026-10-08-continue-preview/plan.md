---
title: 首页续读提示实施计划
date: 2026-10-08
type: plan
---

# 实施单元

## U1. 自动收起续读提示

- 在 `app/lib/screens/home_screen.dart` 监听最近阅读位置，以漫画、章节、页码识别更新；新位置启动 5 秒计时，超时移除浮条及底部留白，销毁页面取消计时。
- 更新 `app/test/home_screen_test.dart` 的既有续读检查，验证提示期间定位、超时收起、相同记录刷新不重现以及新位置再次提示。
- 验证：从 `app/` 运行 `flutter analyze` 与 `flutter test`，构建 Windows、Android、Web 预览。
- 延续尚未合并的 `codex/ui-refresh` 分支和 PR #40，完成后由用户合并。

# 规范影响

- 更新 `specs/app-shell.spec.md`：续读提示显示时限与再次显示条件。
- 更新 `specs/ui-style.convention.md`：只在提示可见期间预留底部空间。
