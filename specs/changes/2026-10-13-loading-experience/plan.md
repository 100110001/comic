---
title: 漫画加载体验与请求合并实施计划
date: 2026-10-13
type: feat
origin: specs/changes/2026-10-13-loading-experience/define.md
---

# 漫画加载体验与请求合并实施计划

## 方案

沿用 Flutter 原生动画、主题令牌、Riverpod 缓存及现有图片 provider，不增加依赖。用户已要求整个变更循环在同一分支完成，最终统一创建目标为 master 的 PR。

### U1. 加载反馈与在途请求合并

需求：R1–R5。依赖：无。

文件：`app/lib/widgets/loading_placeholders.dart`、`display_network_image.dart`、`comic_grid.dart`、`reading_lists.dart`，`app/lib/screens/detail_screen.dart`、`search_screen.dart`、`discovery_screen.dart`、`reader_screen.dart`，`app/lib/services/api_client.dart`、`app/lib/providers/comics_providers.dart`，以及对应既有测试文件。

- 共享轻量呼吸骨架与图片首帧过渡，不在动画中发起请求；禁用动画时静态展示。图片仍由原有 provider 处理，保持缓存身份和尺寸。
- 网格首屏展示有限行骨架，分页尾部展示一行占位；详情、书库与发现按各自内容形状占位，详情刷新继续展示缓存。
- 阅读图片保持原布局高度与预加载策略；首帧前展示提示和可用的下载进度，错误沿用重试入口。
- `ApiClient` 实例内以完整查询路径共享在途 GET，结束后移除；非 GET 开始与完成时清除共享表，旧请求清理不得移除新请求。不缓存结果，不合并写操作。
- 首页首次加载期间等待原请求，换批期间等待当前刷新，仍允许刷新替代旧分页。搜索依赖完整查询路径合并相同在途查询，保留现有查询代际。

验证：扩展现有测试覆盖在途合并、错误后重试、变更与来源隔离，以及慢图首帧、减少动画和小尺寸布局。运行仓库要求的五项门禁。

## 风险与边界

无限动画不能作为测试等待完成的条件，慢请求用有限帧验证。加载反馈不能改变图片尺寸、滚动位置或触发额外查询。网络原图字节量不因骨架减少，不宣称量化的生产环境减压幅度。

## 规范影响

- `specs/ui-style.convention.md`：骨架、首帧过渡、缓存刷新与减少动画反馈。
- `specs/image-loading.convention.md`：首帧占位及稳定尺寸，不改变预加载与缓存预算。
- `specs/data-layer.convention.md`：仅在途查询合并及写入后的隔离。
- `specs/comics-browsing.spec.md`：重复换批合并等待。

## 状态

U1 待实现；实现后执行规范收割。
