---
title: 设置页与浅色/深色/跟随系统主题
type: feat
date: 2026-08-24
origin: specs/changes/2026-08-24-settings-theme/define.md
---

# 设置页与浅色/深色/跟随系统主题

## Summary

新增设置页与外观模式（浅色/深色/跟随系统），偏好持久化；以双套主题令牌驱动全 App 与阅读器切换。纯前端改动。

## Problem Frame

App 目前只有固定深色风格，用户希望支持浅色/深色/跟随系统并可在设置页切换。

## Requirements

- R1. 设置页提供"浅色 / 深色 / 跟随系统"三选一，切换即时生效。
- R2. 主题偏好持久化，重启后保持。
- R3. 浅色模式为完整浅色体系，覆盖全部页面与阅读器。
- R4. 跟随系统时亮/暗跟随操作系统。
- R5. 阅读器浅色下为浅底浅工具栏，交互不变。
- R6. 桌面侧栏与手机"我的"页均可进入设置页。
- R7. 不改变布局、交互、接口与数据层行为。

## Key Technical Decisions

- **`ThemeExtension<AppColors>` 承载双套颜色**：组件通过 `context.appColors.*` 取色，替代当前单套 `k*` 常量。
- **`MaterialApp` 提供 `theme`/`darkTheme`/`themeMode`**：`themeMode` 由 Riverpod `Notifier` 驱动并持久化到 `shared_preferences`。
- **设置页为独立页面**：先只做外观区，入口在桌面侧栏与手机"我的"页。

## High-Level Technical Design

颜色双套映射（深色沿用现有，浅色为 GitHub 浅色体系）：

| 令牌 | 深色 | 浅色 |
| --- | --- | --- |
| `bg` | `#0d1117` | `#f6f8fa` |
| `surface1` | `#161b22` | `#ffffff` |
| `surface2` | `#1c2128` | `#ffffff` |
| `border` | `#30363d` | `#d0d7de` |
| `accent` | `#58a6ff` | `#0969da` |
| `text1` | `#e6edf3` | `#1f2328` |
| `text2` | `#8b949e` | `#57606a` |
| `readerBg` | `#000000` | `#f6f8fa` |
| `readerBar` | `#161b22` | `#ffffff` |

主题状态流：`SettingsScreen` → `themeModeProvider` → `MaterialApp.themeMode`；`Notifier` 写入 `shared_preferences`，启动时读取。

## Implementation Units

### U1. ✅ 双套主题令牌（ThemeExtension）(PR #9)

- **Goal:** 主题从单套深色常量扩展为浅/深双套，组件可经 `context.appColors` 取色。
- **Requirements:** R3, R7
- **Dependencies:** 无
- **Files:** `lib/theme.dart`
- **Approach:** 定义 `AppColors`（`ThemeExtension`）含浅/深两套值，`buildAppTheme(Brightness)` 构建对应主题并注册 extension；新增 `appColors` 上下文扩展。
- **Verification:** `flutter analyze` 无问题；深色模式外观与现状一致。

### U2. ✅ 主题偏好状态与持久化 (PR #9)

- **Goal:** 主题模式由 Riverpod 状态驱动并持久化。
- **Requirements:** R1, R2, R4, R7
- **Dependencies:** U1
- **Files:** `lib/providers/settings_provider.dart`（新建）、`lib/main.dart`、`pubspec.yaml`
- **Approach:** 新增 `shared_preferences` 依赖；`ThemeModeNotifier` 持有模式并在 setter 中持久化；`main()` 启动时读取偏好；`MaterialApp` 提供 `theme`/`darkTheme`/`themeMode`。
- **Verification:** 选择模式即时生效；重启后保持；跟随系统随 OS 切换。

### U3. ✅ 设置页 (PR #9)

- **Goal:** 设置页提供外观三选一。
- **Requirements:** R1, R7
- **Dependencies:** U2
- **Files:** `lib/screens/settings_screen.dart`（新建）
- **Approach:** 页面含"外观"区：`SegmentedButton<ThemeMode>` 三选项（浅色/深色/跟随系统），选择即写入 provider。
- **Verification:** 三个选项可切换且即时生效。

### U4. ✅ 入口 (PR #9)

- **Goal:** 桌面侧栏与手机"我的"页可进入设置页。
- **Requirements:** R6, R7
- **Dependencies:** U3
- **Files:** `lib/main.dart`、`lib/screens/mine_screen.dart`
- **Approach:** 侧栏新增"设置"目的地；"我的"页 AppBar 加齿轮按钮。
- **Verification:** 两端都能进入设置页，导航逻辑不变。

### U5. ✅ 全 App 改用主题色 (PR #9)

- **Goal:** 各页面/组件从 `context.appColors` 取色，浅色下全 App 正确呈现。
- **Requirements:** R3, R7
- **Dependencies:** U1
- **Files:** `lib/widgets/*.dart`、`lib/screens/*.dart`
- **Approach:** 把 UI 打磨引入的 `k*` 常量引用替换为 `context.appColors.*`（卡片、状态组件、导航、首页、详情、发现、搜索、我的/列表、目录、进度条）。
- **Verification:** 深色不变、浅色全页面协调；`flutter analyze` 无问题。

### U6. ✅ 阅读器浅色适配 (PR #9)

- **Goal:** 阅读器跟随主题：浅底浅工具栏，交互不变。
- **Requirements:** R5, R7
- **Dependencies:** U5
- **Files:** `lib/screens/reader_screen.dart`、`lib/widgets/reader_progress_bar.dart`
- **Approach:** 阅读器画布/工具栏/进度条/重试占位改用 `appColors.readerBg`/`readerBar`/`text1` 等。
- **Verification:** 深色下仍为黑底；浅色下为浅底浅工具栏；键盘/沉浸/重试/续章行为不变。

## Acceptance Examples

- AE1. 设置页选"浅色"后全 App 立即变浅，重启保持。Covers R1, R2。
- AE2. 选"跟随系统"后随 OS 亮暗切换。Covers R4。
- AE3. 浅色模式进入阅读器为浅底浅工具栏，交互正常。Covers R5。

## Scope Boundaries

**Deferred to Follow-Up Work**

- 其他设置项（阅读方向、默认字号、缓存管理）、自定义强调色。

## Risks & Dependencies

- `shared_preferences` 为新增依赖，需要 `flutter pub add` 并重新解析依赖。
- 浅色配色需要人工核对各页面对比度；深色模式必须保持现状不变。

## Spec Impact

- `specs/settings.spec.md` — new：设置页与外观模式（浅色/深色/跟随系统、持久化、入口）。
- `specs/ui-style.convention.md` — updated：颜色令牌扩展为浅/深双套，组件经 `ThemeExtension` 取色。
- `specs/reader.spec.md` — updated：阅读器背景跟随主题（深色黑底/浅色浅底），交互不变。
- `specs/app-shell.spec.md` — updated：桌面侧栏新增"设置"入口，手机"我的"页可进入设置。
