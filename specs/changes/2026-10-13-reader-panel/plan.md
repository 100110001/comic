# 实施计划

## U1：统一面板

- 在现有 PR #69 分支继续，修改 `app/lib/screens/reader_screen.dart`，删除独立快捷菜单及鼠标定位，进度与导航置顶，下接现有设置。
- 手机控制层只保留工具按钮，进度统一置于面板，避免重复输入。
- 适配 `app/test/reader_screen_test.dart` 既有交互用例，验证窄屏、跳页及关闭行为；执行仓库五项门禁。

## Spec Impact

- `specs/reader.spec.md`：统一入口与进度位置。
- `specs/ui-style.convention.md`：面板布局。
- `specs/settings.spec.md`：设置内进度。
