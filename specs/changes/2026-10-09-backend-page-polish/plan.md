---
title: 后端页面优化实施计划
date: 2026-10-09
origin: specs/changes/2026-10-09-backend-page-polish/define.md
---

# 后端页面优化实施计划

## 摘要与问题

两个后台页面采用不同样式，调试页缺少窄屏布局且默认地址固定。此次统一工作台视觉并补齐操作反馈。

## 要求

沿用 define.md 的 R1–R5，范围限定为后端静态页面。

## 技术决策

- 使用本地共享 CSS 表达导航、颜色和通用控件，维持无外部资源依赖。
- 调试页以选择、编辑、显式发送组织操作，方法可见且可选择；请求使用超时与忙碌控制。
- 监视页延续现有图片加载、同源地址校验和轮询行为；状态与模式提供可访问反馈。

## 实现单元

### U1. 已完成：统一后台工作台并完善操作反馈

- 依赖：无。
- 文件：backend/public/index.html、backend/public/super-resolution-monitor.html、backend/public/admin.css。
- 方法：共享视觉样式；重构调试页；监视改为六列表格，右侧预览宽 360px，适应模式同时约束宽高。
- 验证：桌面和窄屏布局、GET 成功与失败、非 JSON、超时、复制、筛选、暂停刷新、对比模式与键盘焦点；执行仓库五项门禁。

## Spec Impact

- 新建 specs/backend-pages.spec.md：后台页面导航、调试操作和反馈契约。
- 更新 specs/super-resolution.spec.md：监视页的刷新反馈、模式选择和窄屏交互。

## 范围边界

不调整服务端 API、数据库、推理服务或 Flutter 产品功能；不引入前端框架。

