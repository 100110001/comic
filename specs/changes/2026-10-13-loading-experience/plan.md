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

### U2. 机械硬盘原图传输排队

需求：R6；依赖：U1 已完成。

文件：`backend/src/middleware/image_transfer_limit.ts`、`backend/src/app.ts`、`backend/src/config.ts`、`backend/tests/image-transfer-limit.test.cjs`、`README.md`。

在原图静态资源处理前加入进程内共享的先进先出队列，默认并发为 1，通过 `IMAGE_MAX_CONCURRENT_READS` 配置。只在响应完成、连接断开或传输超时后释放额度；等待中的客户端断开立即移出队列。排队数有上限且有等待超时，过载返回可重试的 503。元数据 API 与超分处理不占此队列，不将事件循环或数据库改为单线程。慢客户端占用额度是降低磁盘峰值的已知代价。

验证：独立 Express 测试服务器验证串行/双并发、失败与取消释放额度、排队满载与超时、静态文件成功/304/404和其他 API 不受阻；不连接业务数据库。重新运行仓库五项门禁及后端构建。

## 规范影响

- `specs/ui-style.convention.md`：骨架、首帧过渡、缓存刷新与减少动画反馈。
- `specs/image-loading.convention.md`：首帧占位及稳定尺寸，不改变预加载与缓存预算。
- `specs/data-layer.convention.md`：仅在途查询合并及写入后的隔离。
- `specs/comics-browsing.spec.md`：重复换批合并等待。
- `specs/image-loading.convention.md`：后端原图传输额度、取消与过载语义及进程边界。

## 状态

U1、U2 已实现；最终 PR 统一承载实现与规范收割。
