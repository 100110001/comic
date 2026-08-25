---
date: 2026-08-24
topic: tray-settings
---

# 设置页新增"关闭窗口时最小化到托盘"开关

## Summary

在设置页新增"窗口"区开关：控制 Windows 桌面版点右上角关闭时是退到系统托盘，还是直接退出。默认保持现有行为（退到托盘），偏好本地持久化。

## Problem Frame

目前 Windows 桌面版关闭窗口必然最小化到托盘，用户希望自己控制这个行为。

## Key Decisions

- **默认开启**：保持现有"退到托盘"行为，用户可手动关闭。
- **仅 Windows 显示该开关**：托盘逻辑只存在于 Windows 桌面版，其他平台不显示。
- **偏好持久化**：沿用 `shared_preferences`，关闭窗口时实时读取最新值。

## Requirements

- R1. 设置页提供"关闭窗口时最小化到系统托盘"开关，默认开启。
- R2. 开启时右上角关闭退到托盘（现状不变）；关闭时右上角关闭直接退出应用。
- R3. 开关仅在 Windows 桌面版显示。
- R4. 偏好持久化，重启保持。

## Acceptance Examples

- AE1. 关闭开关后点右上角 X，应用直接退出、不进托盘。Covers R2。
- AE2. 重新打开开关并重启应用，设置保持开启。Covers R4。

## Scope Boundaries

**Deferred for later**

- 托盘菜单项自定义、最小化到托盘时的提示气泡。
