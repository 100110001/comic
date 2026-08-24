---
title: 设置页新增"关闭窗口时最小化到托盘"开关
type: feat
date: 2026-08-24
origin: specs/changes/2026-08-24-tray-settings/define.md
---

# 设置页新增"关闭窗口时最小化到托盘"开关

## Summary

设置页"窗口"区新增开关，控制 Windows 桌面版关闭窗口时退到托盘还是直接退出，默认开启、持久化。

## Requirements

- R1. 设置页提供"关闭窗口时最小化到系统托盘"开关，默认开启。
- R2. 开启时关闭退到托盘；关闭时关闭直接退出。
- R3. 开关仅 Windows 桌面版显示。
- R4. 偏好持久化，重启保持。

## Key Technical Decisions

- **偏好实时读取**：关闭窗口回调直接读 `shared_preferences`，避免把 Riverpod 状态耦合进平台层。
- **开关仅 Windows 显示**：用 `defaultTargetPlatform == TargetPlatform.windows` 判定，Web 安全。

## Implementation Units

### U1. ✅ 托盘开关状态与持久化

- **Goal:** 新增 `closeToTray` 偏好状态并持久化。
- **Requirements:** R1, R4
- **Dependencies:** 无
- **Files:** `lib/providers/settings_provider.dart`、`lib/main.dart`
- **Approach:** 新增 `CloseToTrayNotifier` 与 `loadCloseToTray()`，默认 true；`main()` 启动读取并注入 override。
- **Verification:** 状态可读写，重启保持。

### U2. ✅ 设置页开关

- **Goal:** 设置页"窗口"区显示托盘开关。
- **Requirements:** R1, R3
- **Dependencies:** U1
- **Files:** `lib/screens/settings_screen.dart`
- **Approach:** 外观区下方新增"窗口"区，仅 Windows 显示 `SwitchListTile`，切换写入 provider。
- **Verification:** Windows 下显示开关且可切换；其他平台不显示。

### U3. ✅ 关闭窗口行为接入

- **Goal:** 关闭窗口时按偏好决定退托盘或退出。
- **Requirements:** R2
- **Dependencies:** U1
- **Files:** `lib/tray/close_to_tray_io.dart`
- **Approach:** `onWindowClose` 读取持久化的 `closeToTray`，开启时 `hide()`，关闭时 `destroy()`。
- **Verification:** 开关关闭后点 X 直接退出；开启时退托盘。

## Acceptance Examples

- AE1. 关闭开关后点 X 直接退出。Covers R2。
- AE2. 重启后设置保持。Covers R4。

## Scope Boundaries

**Deferred to Follow-Up Work**

- 托盘菜单项自定义、最小化提示气泡。

## Spec Impact

- `specs/settings.spec.md` — updated：Public Contract 增加"关闭窗口时最小化到托盘"开关（默认开启、仅 Windows）。
- `specs/app-shell.spec.md` — updated：Notes 更新为"关闭窗口默认最小化到托盘，可在设置页关闭"。
