---
title: Riverpod 服务端状态数据层
type: refactor
date: 2026-08-09
origin: specs/changes/2026-08-09-riverpod-data-layer/define.md
---

# Riverpod 服务端状态数据层

## Summary

引入 flutter_riverpod 3.x 作为服务端状态层：所有 API 数据访问收敛到 provider，采用"缓存优先 + 过期后台重取"，mutation 成功后按失效矩阵同步相关查询，并将现有页面全量迁移。

---

## Problem Frame

页面直接调用 ApiService、各自维护 loading/刷新/错误；跨页面状态（收藏、最近阅读、作者收藏）返回后易显示旧数据，已多次用补丁式同步修复；无请求缓存。需要统一数据层作为后续基础。

---

## Requirements

承接 origin 的 R-ID；括号内为实现单元。

- R1. 所有 API 数据访问通过 provider 封装，页面不再直接调用 ApiService。（U1, U2–U6）
- R2. 缓存优先 + 过期后台重取。（U1, U2–U6）
- R3. 查询统一暴露 loading/error/data。（U1, U2–U6）
- R4. 首页迁移。（U2）
- R5. 搜索页迁移。（U3）
- R6. 详情页迁移。（U4）
- R7. "我的"页迁移。（U5）
- R8. 阅读器迁移。（U6）
- R9. 桌面侧栏复用同一 provider。（U5）
- R10. 收藏变更后失效收藏列表、卡片角标相关查询。（U1, U4）
- R11. 作者收藏切换后失效收藏作者与详情页作者状态。（U1, U4）
- R12. 阅读进度更新后失效最近阅读与详情页 progress。（U1, U6）
- R13. 首页刷新/换种子重新拉取随机列表。（U2）
- R14. 首次加载转圈、错误可重试。（U1, U2–U6）
- R15. 有缓存时后台静默刷新，失败不打断。（U1, U2–U6）

---

## Key Technical Decisions

- **flutter_riverpod 3.x（最新稳定 3.4.2）。** 用 `AsyncNotifier`/`FutureProvider` 封装数据；无代码生成。
- **ApiService 保留为 HTTP 层。** provider 调用现有方法，不重写接口访问。
- **缓存语义：默认非 autoDispose provider。** 会话内保持缓存；页面进入时若已有数据则先展示并后台 `ref.refresh`，实现 stale-while-revalidate。
- **失效矩阵集中定义。** 提供"变更 → 失效查询"的统一入口（如 `invalidateAfterFavoriteChange`），mutation 成功后调用，避免散落。
- **首页随机分页状态归 provider 持有。** seed 与已加载页数存于 notifier；刷新换 seed 并失效重取。

---

## High-Level Technical Design

Provider 结构与失效联动：

```mermaid
flowchart TB
  subgraph Providers
    RL[randomLibraryProvider]
    SE[searchProvider]
    DE[comicDetailProvider(id)]
    FA[favoritesProvider]
    AF[favoriteAuthorsProvider]
    RE[recentReadingProvider]
    IM[chapterImagesProvider(id)]
  end
  Home --> RL
  Search --> SE
  Detail --> DE
  Mine --> FA
  Mine --> AF
  Mine --> RE
  Reader --> IM
  Mut[收藏/作者收藏/进度 mutation] -->|成功后失效| FA
  Mut --> AF
  Mut --> RE
  Mut --> DE
  Mut --> RL
  Mut --> SE
```

---

## Implementation Units

### U1. 数据层搭建：依赖、ProviderScope 与全部 provider

**Status:** shipped

- **Goal:** 引入 Riverpod，创建覆盖所有接口的 provider 与失效助手，接入应用根部。
- **Requirements:** R1, R2, R3, R10, R11, R12, R14, R15
- **Dependencies:** 无
- **Files:** `pubspec.yaml`, `lib/main.dart`, 新增 `lib/providers/comics_providers.dart`, `lib/providers/reader_providers.dart`
- **Approach:**
  - 添加 `flutter_riverpod` 依赖，`main.dart` 用 `ProviderScope` 包裹应用。
  - `comics_providers.dart`：`randomLibraryProvider`（AsyncNotifier，持有 seed/页数，提供换种子刷新）、`searchProvider`（关键字 + 分页）、`comicDetailProvider(id)`、`favoritesProvider`、`favoriteAuthorsProvider`、`recentReadingProvider`；mutation 方法（收藏/作者收藏）内调用 ApiService 后触发失效。
  - `reader_providers.dart`：`chapterImagesProvider(id)` 与 `updateProgress` mutation（成功后失效 recent/detail）。
  - 失效助手：收藏 → favorites + detail + random + search；作者收藏 → favoriteAuthors + detail；进度 → recent + detail。
- **Verification:** analyze/test/web 构建通过；ProviderScope 下页面仍可正常加载。

### U2. 首页迁移

**Status:** shipped

- **Goal:** 首页随机书库与悬浮续读条改由 provider 提供数据。
- **Requirements:** R2, R3, R4, R13, R14, R15
- **Dependencies:** U1
- **Files:** `lib/screens/home_screen.dart`
- **Approach:** 移除页面内 `_comics/_total/_seed/_loading` 手工状态，改 `ref.watch(randomLibraryProvider)` 渲染；刷新调用 provider 换种子；续读条数据来自 `recentReadingProvider`；进入时已有缓存则后台刷新。
- **Verification:** 首页滚动分页、刷新换序、续读条行为与迁移前一致。

### U3. 搜索页迁移

- **Goal:** 搜索关键字分页改由 provider 管理。
- **Requirements:** R2, R3, R5, R14, R15
- **Dependencies:** U1
- **Files:** `lib/screens/search_screen.dart`
- **Approach:** `searchProvider` 持有关键字与分页；页面 `ref.watch` 渲染结果，输入关键字调用 provider 重置并搜索。
- **Verification:** 搜索、分页、空态与迁移前一致。

### U4. 详情页迁移

- **Goal:** 详情/章节/收藏/作者收藏/进度统一走 provider，切换后失效联动生效。
- **Requirements:** R6, R10, R11, R12, R14, R15
- **Dependencies:** U1
- **Files:** `lib/screens/detail_screen.dart`
- **Approach:** `comicDetailProvider(comicId)` 提供漫画 + 章节 + favorited + authorFavorited + progress；收藏/作者收藏按钮调用 mutation（成功后失效矩阵刷新本页与其他页）。
- **Verification:** 详情页状态正确；收藏/作者收藏切换后返回首页/我的立即同步。

### U5. "我的"页与桌面侧栏迁移

- **Goal:** 最近阅读/收藏/收藏作者列表统一走 provider；桌面侧栏复用。
- **Requirements:** R7, R9, R10, R11, R14, R15
- **Dependencies:** U1
- **Files:** `lib/screens/mine_screen.dart`, `lib/widgets/reading_lists.dart`, `lib/main.dart`
- **Approach:** 三个列表分别 `ref.watch` 对应 provider；切 tab/侧栏入口时按 R2 后台刷新；删除列表内手工 `_load` 状态。
- **Verification:** 三个列表数据与刷新行为与迁移前一致。

### U6. 阅读器迁移 + 失效收尾

- **Goal:** 章节图片与进度上报走 provider；全量迁移后页面不再直接调用 ApiService。
- **Requirements:** R1, R8, R12, R14, R15
- **Dependencies:** U1, U4
- **Files:** `lib/screens/reader_screen.dart`, `lib/providers/reader_providers.dart`
- **Approach:** 章节图片经 `chapterImagesProvider` 获取；离开阅读器时 `updateProgress` mutation 成功后失效 recent/detail；全库检索确认无直接 ApiService 调用。
- **Verification:** 阅读器加载/进度保存正常；`rg "ApiService" lib/screens lib/widgets` 仅剩 provider 层引用。

---

## Scope Boundaries

Deferred to Follow-Up Work:

- 磁盘缓存持久化（离线可用）
- 分页预取与滚动预加载
- riverpod_generator 代码生成
- 请求竞态与全局取消调优

---

## Risks & Dependencies

- Riverpod 3.x 与 flutter_riverpod 版本 API 差异：以 3.4.2 的 `AsyncNotifier`/`ref` 语义为准，实现时先小步验证再铺开。
- 首页随机分页依赖 provider 持有 seed：刷新换种子后需保证顺序稳定、无重复（后端已支持 `RAND(seed)`）。
- 失效矩阵遗漏会导致"旧数据"回归：验收例子 AE2 必须人工验证。
- 构建门禁照旧：`flutter analyze` / `flutter test` / 后端 `tsc build` / `flutter build web`。

---

## Spec Impact

- `specs/data-layer.spec.md`（新建）：Riverpod 数据层约定——provider 覆盖全部接口、缓存优先 + 后台重取语义、失效矩阵（收藏/作者收藏/进度 → 相关查询）、页面不直接调用 ApiService。
