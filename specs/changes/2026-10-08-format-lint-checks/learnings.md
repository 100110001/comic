# 实施记录

- 用户明确要求前后端格式与 lint 全部接入 CI；同步修改 AGENTS.md、CLAUDE.md 和发版命令，避免继续沿用排除后端的旧偏好。
- Flutter 本机版本为 3.38.9 / Dart 3.10.8，与 CI 一致；格式检查覆盖 62 个文件，无需改动 Dart 代码；分析无问题，69 项测试通过。
- 后端使用 ESLint 10 与 typescript-eslint 推荐规则，没有关闭规则来适配现有代码。初次检查发现 10 个 lint 问题和 15 个格式问题文件。
- 为章节图片查询补齐行类型，去除显式 any；移除未使用的 catch 参数；为刻意忽略的 Redis 与图片尺寸错误添加说明。保持业务处理语义。
- 初次选用 ESLint 9 后安装器提示已停止支持；确认 typescript-eslint 的 peerDependencies 支持 ESLint 10，改用 ESLint 10，并记录精确依赖于 pnpm 锁定文件。
- 后端格式检查、ESLint 和 TypeScript noEmit 检查通过，不启动服务，不执行漫画维护命令。
- 自审：Flutter 格式命令在 app/ 执行，后端命令在 backend/ 执行；CI 分别恢复锁定依赖；对外 API 没有改变。未发现需要额外业务修改的问题。
- 自审补充：Windows 开启 core.autocrlf 后，检出 TypeScript 会转成 CRLF，与 Prettier 默认 LF 不符；在 .gitattributes 明确 TypeScript 使用 LF，保证 Windows CI 与本地格式校验一致。此项是基于实际环境发现的计划补充。
- 使用与依赖安装相同的 SDK/缓存权限后，pnpm 冻结锁定文件离线安装、pnpm 格式与 lint 及 TypeScript noEmit 全部通过。
