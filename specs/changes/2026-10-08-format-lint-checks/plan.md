---
title: 格式与 lint 校验实施计划
date: 2026-10-08
---

# 实施计划

## 范围与决策

- Flutter 使用 `dart format --output=none --set-exit-if-changed lib/ test/` 和 `flutter analyze`；后者已经加载 `flutter_lints`。
- 后端使用 Prettier 检查现有 `src/**/*.ts` 范围，ESLint 使用 TypeScript 推荐规则和 Node.js 环境，不让 lint 承担代码格式化。
- CI 拆分 Flutter 与后端检查，依赖分别按已提交的锁定文件恢复；后端执行格式和 lint，不启动服务或连接数据库。
- 当前代码必须通过新增门禁；必要修正保持业务行为不变。

## 实施单元

### U1. 接入前后端校验

- 状态：实现与本地验证完成，待创建 PR。
- 依赖：无。
- 文件：`.github/workflows/ci.yml`、`backend/package.json`、`backend/pnpm-lock.yaml`、`backend/eslint.config.mjs`、发现检查问题的源码文件、`docs/commands.md`、`.claude/commands/release.md`、`AGENTS.md`、`CLAUDE.md`。
- 验证：Flutter 格式检查、`flutter analyze`、`flutter test`；后端 `npm run format:check`、`npm run lint`；不新增镜像配置的单元测试。
- 不涉及后端功能、依赖升级专项或发版构建。

## Spec Impact

- 更新 `specs/project-layout.convention.md`，记录 Flutter 格式门禁与后端格式、lint 门禁，以及各自的执行目录和锁定依赖要求。

完成实现与检查后使用收割流程更新规范；临时过程文档的记录保留于本分支提交历史。
