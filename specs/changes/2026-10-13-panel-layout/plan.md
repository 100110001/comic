# 实施计划

## U1：排版与关闭

- 继续 PR #69；导航改为可换行按钮组，阅读配置以中性表面区分，统一间距。
- `reader_screen.dart` 遮罩显式关闭面板，不透传正文点击；`reader_settings_controls.dart` 仅调整紧凑形态。
- 既有阅读器测试补充遮罩关闭不退出、不翻页，以及内部点击不关闭；执行五项门禁。

## Spec Impact

- `specs/reader.spec.md`：外部关闭行为。
- `specs/ui-style.convention.md`：面板视觉层次。
