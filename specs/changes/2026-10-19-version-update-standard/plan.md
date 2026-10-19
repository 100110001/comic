---
title: 最低支持版本更新机制实施计划
date: 2026-10-19
type: plan
---

# 最低支持版本更新机制实施计划

## 概述与问题

现有更新仅由设置页手动触发，缺少最低版本和安全的清单发布时间。本计划将开发判断、发版校验和应用拦截连成同一流程。

用户已确认最低支持版本并要求继续计划和实现；遵循项目偏好，沿用 `codex/version-update-standard` 和 PR #85 完成整个循环，不拆分阶段 PR。

## 需求

- R1. 覆盖 define.md 的 R1–R7：按平台比较当前版本、最低版本和最新版本，统一启动与手动检查，取消安装不能解除强更。
- R2. 覆盖 define.md 的 R8–R12：发版记录兼容性级别、递增构建号、校验最低版本和原因，安装包完成后发布清单。
- R3. 首次断网放行；保存最近有效清单，跨重启保留已知门槛；新有效清单可撤回门槛。
- R4. 开发和发布入口引用一份中文正式规范；不实际发布新版本，不抬高线上最低版本。

## 技术决策

- KTD1. 清单保持 latestVersion 和 platforms.downloadUrl，每个平台增加 minimumSupportedVersion 与 minimumSupportReason；旧清单缺少最低版本时不强更。拒绝畸形版本、无效下载地址和最低版本高于最新版本。
- KTD2. 全局 Riverpod 更新状态由应用根部的更新门控制；启动检查前不构建业务页面，手动检查发现强更时覆盖整个导航树，所有返回路径保持拦截。
- KTD3. 最近有效清单以单个版本化本地偏好保存；错误回退只使用已验证清单，保存失败仍执行本次有效策略并提示。
- KTD4. 原生 Windows/Android 的 release 启动自动检查，开发构建不自动联网；设置页仍可手动检查。普通更新启动提示允许稍后处理。
- KTD5. 新客户端从 GitHub Release 的 latest/download/update.json 读取清单；CI 先准备 draft Release，上传并核验三份资产后再发布。旧客户端使用的 master 清单仍仅有手动更新，不承诺强更。
- KTD6. 发布脚本要求变更级别及兼容性说明，默认继承最低版本；提升门槛必须给出原因。移除重复的本地自动上传通道，统一标签 CI 发布。

## 实施单元

### U1. 应用更新状态与全局入口

状态：已实现并通过五项门禁，PR #85。

- 依赖：无。覆盖 R1、R3。
- 文件：`app/lib/models/update_info.dart`、`app/lib/services/update_service.dart`、新增更新 provider 和 widget、`app/lib/main.dart`、`app/lib/screens/settings_screen.dart`、`app/lib/config.dart`。
- 做法：复用现有下载安装，集中检查与异常处理；根部更新门负责启动检查和不可绕过的强更页面，设置页共享同一状态。
- 验证：扩展现有更新测试，覆盖平台最低版本、无效清单、同主版本强更、缓存断网、门槛撤回与根部返回拦截；不为测试增加复杂架构。

### U2. 发布校验与清单公布

状态：已实现并通过五项门禁及发布流程集成测试，PR #85。

- 依赖：U1 的清单契约。覆盖 R2、R4。
- 文件：`scripts/release.ps1`、新增发布校验脚本、`.github/workflows/release.yml`、`.claude/commands/release.md`、PR 模板、`AGENTS.md`、`Readme.md`、`docs/commands.md`。
- 做法：脚本在任何写入前检查版本级别、构建号和清单；发布 CI 在创建可见 Release 前核验资产，已有正式版本不原地替换。
- 验证：在临时独立仓库执行真实准备脚本，确认递增、继承和拒绝非法发布；用发布校验脚本检查临时资产，测试缺包失败。不得执行真实 tag 推送或发布。

## 系统影响与风险

- 新机制无法约束从未安装过更新机制的历史客户端；正式规范必须保留此边界。
- 本地偏好失败不解除当前强更，但不能保证下次启动保留门槛；界面提示保存失败。
- 发布准备仍生成根目录清单供旧客户端使用，旧手动检查存在安装包尚未就绪的窗口；新自动更新通道只消费已发布资产。
- Android 系统安装器取消或返回时保留更新页，不能用唤起成功作为安装成功。
- 普通检查失败不替代实际服务器兼容协商，后者暂缓。

## 检查与完成条件

每个 br-work 单元完成前从 app 执行格式检查、flutter analyze、flutter test，从 backend 执行 npm run lint、npm run test。自检记录保存在 learnings.md；完成实现后使用 br-reaper 将事实收割到规范并删除过程目录。PR #85 保持打开供用户合并。

## Spec Impact

- 新增 `specs/versioning.convention.md`：版本分级、最低支持版本、开发记录、发布约束和过渡边界。
- 更新 `specs/settings.spec.md`：统一更新入口、最低版本、缓存与安装状态。
- 更新 `specs/app-shell.spec.md`：启动检查与覆盖所有路由的更新门。
- 更新 `specs/project-layout.convention.md`：发布脚本和 Release 资产公布顺序。
