---
title: 优化漫画应用的常用界面
type: feat
date: 2026-10-08
origin: specs/changes/2026-10-08-ui-refresh/define.md
---

# 优化漫画应用的常用界面

## 概要

沿用 Flutter Material 3 与现有主题令牌，统一书库、导航、个人列表和详情的层次与操作表达。整个变更按仓库偏好在同一分支和同一 PR 内完成。

---

## 问题与需求

- R1、R3：改善浅深主题面板区分，为桌面侧栏增加品牌和浏览/个人内容分组；手机采用带选中指示的 NavigationBar。
- R2、R9：漫画标题允许两行，文字区统一高度，网格随文字缩放分配空间。
- R4、R7、R8：首页展示书库或搜索结果标题、数量和刷新入口，沿用既有查询与错误处理。
- R5：续读条居中并限制最大宽度，保留原有章节与页码语义。
- R6、R9：详情突出开始/继续阅读，手机窄屏允许整页滚动，桌面分栏。
- F1–F3、AE1–AE4：浏览、搜索、续读及失败重试均沿用定义中的验收要求。

---

## 技术决策

- 保留蓝色强调色与现有颜色访问方式；浅色使用淡灰蓝背景、白色面板，深色沿用现有令牌。避免更换依赖与大幅改变阅读器。
- 保留网格列数分档和分页契约；卡片文字高度由卡片和网格共享，考虑系统字体缩放。
- 首页桌面搜索框保留，新增显式提交按钮；手机保留全屏搜索入口。刷新在搜索时重试当前关键字，在书库时换种子。
- 个人列表居中限宽并增加间距，桌面各列表显示标题与说明；设置页同样限宽并显示标题。
- 详情主按钮有进度时继续阅读，无进度时打开首章节；无章节时禁用。章节列表保持原有顺序。
- 只调整表现层；提供者、API、阅读器状态和后端不改动。

---

## 实现单元

### U1. 统一常用页面的视觉层次与操作

**状态：** 已实现，PR #40；待完成门禁和实际渲染验证。

- **目标：** 完成 R1–R9 及 F1–F3 的界面优化。
- **依赖：** 无。
- **文件：** `app/lib/theme.dart`、`app/lib/main.dart`、`app/lib/screens/home_screen.dart`、`app/lib/screens/detail_screen.dart`、`app/lib/screens/settings_screen.dart`、`app/lib/widgets/comic_card.dart`、`app/lib/widgets/comic_grid.dart`、`app/lib/widgets/reading_lists.dart`、`app/lib/widgets/status_views.dart`，必要时更新现有 UI 测试。
- **方法：** 先统一主题和导航，再改卡片与首页，最后改善详情和列表。沿用现有 StatefulWidget、ThemeExtension、Pressable 与错误反馈。
- **验证：** 从 `app/` 运行 `flutter analyze` 和 `flutter test`；查看浅/深主题的桌面和手机实际 Flutter 渲染；重点检查长标题、文字缩放、卡片底部、续读入口、空态和详情首章节操作。
- **风险：** 固定网格高度与文字缩放不匹配会溢出；详情窄屏不应让头部挤掉目录；新增按钮应避免刷新期间重复请求。

---

## 范围边界

- 不改后端、接口、持久化或阅读器核心交互。
- 不引入新依赖、在线字体或素材。
- 发现页本轮沿用现有布局，仅继承主题；其随机会话与手势不在改动范围。
- 界面预览若无法访问用户的局域网书库，使用明确标注的示例数据，不把空书库当成完整视觉验收。

---

## Spec Impact

- `specs/ui-style.convention.md`：更新浅深层次、卡片标题区、字体缩放、导航组件及统一页面间距，并移除互相冲突的旧描述。
- `specs/app-shell.spec.md`：更新首页标题、刷新操作、限宽续读条和手机导航的表现契约。
- `specs/reading-history-and-favorites.spec.md`：记录详情的开始/继续阅读操作及窄屏可滚动目录。

---

## 研究依据

- 沿用项目中既有 Material 组件与提供者模式，无需外部方案选择。
- `specs/ui-style.convention.md`、`specs/app-shell.spec.md`、`specs/comics-browsing.spec.md` 约束主题、导航、列数和分页。
- `app/test/home_screen_test.dart` 已覆盖续读位置和内容宽度对应的页大小；既有查询测试覆盖竞态与收藏同步。
