---
title: 搜索历史与快速重搜
origin: specs/changes/2026-10-08-search-history/define.md
date: 2026-10-08
type: feat
---

# 搜索历史与快速重搜

## 决策

- 使用既有 SharedPreferences 保存版本化的服务器→关键字列表，AsyncNotifier 持有完整历史，当前来源通过独立 selector 过滤；操作入口捕获服务器地址。
- 初始化先恢复数据，变更串行并先保存再发布；逐来源和逐条容错，写入失败保持旧快照，后续可重试。
- 不把记录塞入通用 SearchNotifier.search：页面显式提交先独立发起历史保存，再立即搜索，不等本地 I/O；刷新和重试只执行查询。
- 共享历史列表组件支持加载、错误重试、空态、单删和清空；手机空搜索页内嵌，两个搜索栏的历史图标打开受高度限制、可滚动的底部面板，避免挤占桌面网格。
- 页面监听来源变化清空输入；历史操作与点击校验渲染时的来源，防止旧条目作用于新服务器。

## 实现单元

### U1. ✅ 持久历史与来源选择（同分支 PR 待创建）

文件：新增 app/lib/providers/search_history_provider.dart 与 app/test/search_history_test.dart。
验证：去重和 20 条上限、恢复与损坏容错、来源切换、初始化并发、提交/清空顺序和写入失败恢复。

### U2. 搜索入口与共享历史组件

依赖 U1。文件：新增 app/lib/widgets/search_history_view.dart，修改 search_screen.dart、home_screen.dart 及既有页面测试。
验证：手机/桌面回填并查询、删除/清空、刷新重试不重排、失败仍保留、来源切换输入清理、窄屏大字体与长关键字可操作。

## 研究与 Spec Impact

已阅读漫画浏览、外壳和数据层规范，并由只读研究代理检查提交入口和初始化/来源竞态。

- 更新 specs/comics-browsing.spec.md：历史语义、隔离和重搜入口。
- 更新 specs/app-shell.spec.md：桌面搜索历史入口。
- 更新 specs/data-layer.convention.md：本地历史与服务端查询独立，串行持久化与来源选择。

