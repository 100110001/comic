---
date: 2026-10-13
topic: app-workbench-design
origin: specs/changes/2026-10-13-app-workbench-design/define.md
---
# 前端视觉实施计划

## 设计
- 复用 AppColors 与 buildAppTheme，将后台深色 bg/surface/accent/text 配色映射到 Flutter；浅色使用冷白底与可读蓝色。保留阅读预设、收藏红心和启动图标。
- 正文16、说明14、标题28/18；导航与主要按钮16，封面角标12。漫画标题与作者的共享高度及续读占位同步更新。
- 桌面侧栏216宽，品牌与选中态使用后台式蓝色；页面标题、输入框、设置及书库面板沿用统一主题。保留封面卡片透明文字区。
- 使用现有布局测试验证深浅模式、窄矮窗口、双倍字号，必要时修正受约束尺寸；不增加网络、业务状态与持久化逻辑。

## 实现单元
### U1. ✅ 应用蓝灰工作台视觉（待回填 PR）
- 文件：app/lib/theme.dart、main.dart、screens/与widgets/内视觉层和尺寸计算。
- 检查：Dart格式、Flutter分析与完整测试，后端格式与lint；现有布局测试覆盖字体变化。生成带示例书库的可视预览检查。
- 边界：不修改后端、不改变漫画网格列数与阅读行为，不引入字体或图片依赖。

## 规范影响
- specs/ui-style.convention.md：蓝灰深浅主题、文字和面板层次。
- specs/app-shell.spec.md：桌面侧栏和大字号可读性。
