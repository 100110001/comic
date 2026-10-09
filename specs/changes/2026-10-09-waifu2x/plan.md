---
title: waifu2x 2× 接入
date: 2026-10-09
origin: specs/changes/2026-10-09-waifu2x/define.md
---

# waifu2x 2× 接入

## 需求

- R1. 后端便携子进程生成 2×、关闭降噪，未启用时原有服务正常运行。
- R2. 阅读器默认关闭，先显示原图，当前页及后两页按需处理。
- R3. 失败回退、重试、独立缓存与容量限制；原漫画不被改写。
- R4. 完整来源和版本身份，过期服务器、章节和开关请求不发布状态。

## 技术决策

单 GPU 队列、当前页优先、同键去重、队列与状态数量有界。缓存键包含规范源路径、大小、修改时间、模型指纹、倍率和降噪；临时文件验证后原子发布，源变更拒绝发布。缓存目录在扫描根外，默认 2 GiB，LRU 清理及清空操作受代际保护。

Flutter 独立 provider 提交/轮询当前窗口；增强层成功解码后覆盖原图、失败隐藏，共用现有尺寸解码工厂。部署脚本准备固定版本 Windows 引擎，验证 SHA256，二进制和模型不进 Git。

## 实现单元

### U1. 已完成：后端任务与阅读器完整接入

- 依赖：无；按用户要求整个变更同分支、单 PR。
- 文件：backend/src/services/super-resolution.ts、backend/src/routes/super-resolution.ts、backend/src/config.ts、backend/src/routes/index.ts、backend/scripts/setup-waifu2x.ps1、backend/package.json、backend/.gitignore；app/lib/models/super_resolution_job.dart、app/lib/services/api_client.dart、app/lib/providers/super_resolution_provider.dart、app/lib/screens/reader_screen.dart、app/test/reader_screen_test.dart；README.md。
- 方案：短 POST 提交最多三图，GET 轮询状态及结果，不依赖 Redis。阅读器提供开关、状态、失败重试和清空缓存。
- 验证：实际引擎样本验证尺寸、去重、缓存、清空和未配置；前端覆盖关闭不请求、关闭后晚到结果和固定布局。执行 AGENTS.md 全部门禁并构建后端。

## 规范影响

- 新增 specs/super-resolution.spec.md：任务、部署、缓存、API 和失效。
- 更新 specs/reader.spec.md：可选超分、固定布局、回退。
- 更新 specs/image-loading.convention.md：后端衍生缓存边界。
- 更新 specs/data-layer.convention.md：超分 provider 的会话隔离。

## 风险与边界

后端任务不持久化；重启保留衍生文件、未完成任务可重提。单进程拥有缓存目录。超大图受像素预算限制。整章预处理、多模型和客户端推理延后。

