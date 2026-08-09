---
date: 2026-08-09
topic: riverpod-data-layer
---

# Riverpod 服务端状态数据层

## Summary

引入 Riverpod 作为服务端状态管理：所有 API 数据访问统一收敛到 provider，采用"缓存优先 + 过期后台重取"语义；收藏、阅读进度、作者收藏等变更成功后主动失效相关查询；全量迁移现有页面。

---

## Problem Frame

当前页面直接调用 ApiService，每个页面手写 `_loading`/`_refresh`/错误处理，重复且容易遗漏；跨页面数据（收藏、最近阅读、作者收藏）经常出现"返回后是旧数据"，已多次用补丁式同步修复；请求没有缓存，重复进入页面会重复拉取。随着页面和接口增多，需要一个统一的数据层作为基础。

---

## Key Decisions

- **数据层选 Riverpod。** `AsyncNotifier` + `ref.invalidate/refresh` 提供缓存、失效、重取语义，无代码生成门槛，与现有 ApiService 兼容（provider 包装现有方法）。
- **缓存优先 + 后台重取。** 有缓存先展示，同时后台刷新；无缓存时按 loading → data/error 流程。
- **强一致操作主动失效。** 收藏、作者收藏、阅读进度等 mutation 成功后，失效相关查询，从根上解决跨页面旧数据。
- **全量迁移。** 所有页面（首页/搜索/详情/我的/阅读器/侧栏）统一走 provider，页面不再直接调用 ApiService。
- **呈现组合。** 首次加载（无缓存）转圈；错误显示重试按钮；有缓存时静默刷新、失败不打断。

---

## Requirements

**数据层**

- R1. 引入 Riverpod：所有 API 数据访问通过 provider 封装，页面不再直接调用 ApiService。
- R2. 数据获取采用"缓存优先 + 过期后台重取"语义：有缓存先展示并后台刷新，无缓存时加载。
- R3. 查询结果统一暴露 loading / error / data 状态，页面按状态渲染。

**页面迁移（全量）**

- R4. 首页（随机书库 + 悬浮续读条）迁移到 provider。
- R5. 搜索页迁移到 provider。
- R6. 详情页（漫画信息/章节/收藏/作者收藏/进度）迁移到 provider。
- R7. "我的"页（最近阅读/收藏/收藏作者）迁移到 provider。
- R8. 阅读器（章节图片、进度上报）迁移到 provider。
- R9. 桌面侧栏页面复用与手机端相同的 provider。

**失效联动**

- R10. 收藏/取消收藏后失效收藏列表、首页与搜索卡片角标相关查询。
- R11. 作者收藏切换后失效收藏作者列表与详情页作者状态。
- R12. 阅读进度更新后失效最近阅读与详情页 `progress`。
- R13. 首页刷新或换随机种子时重新拉取随机列表。

**呈现**

- R14. 首次加载（无缓存）显示加载状态；错误时显示重试入口。
- R15. 有缓存时后台静默刷新，失败不打断当前展示。

---

## Key Flows

- F1. 首次进入页面
  - **Trigger:** 用户打开无缓存数据的页面。
  - **Steps:** 查询进入 loading → 成功展示 data / 失败展示 error + 重试。
  - **Covered by:** R2, R3, R14
- F2. 返回已访问页面
  - **Trigger:** 用户回到已有缓存的页面。
  - **Steps:** 先展示缓存数据 → 后台重取 → 有新数据时更新。
  - **Covered by:** R2, R15
- F3. 变更后同步
  - **Trigger:** 用户切换收藏、作者收藏或产生阅读进度。
  - **Steps:** mutation 成功 → 失效相关查询 → 各页面展示最新状态。
  - **Covered by:** R10, R11, R12

---

## Acceptance Examples

- AE1. **Covers R2, R14.** Given 首页首次打开且无缓存，When 进入首页，Then 显示加载状态并在完成后展示随机网格；再次进入时先显示缓存内容再后台刷新。
- AE2. **Covers R10.** Given 用户从详情页取消收藏并返回首页，When 返回完成，Then 首页卡片角标自动更新为未收藏，无需手动刷新。
- AE3. **Covers R14, R15.** Given 后端不可用，When 首次进入某页面，Then 显示错误与重试按钮；已缓存页面仍可查看旧数据。
- AE4. **Covers R1.** Given 全量迁移完成，When 审查页面代码，Then 页面不再直接调用 ApiService，数据统一经由 provider。

---

## Scope Boundaries

Deferred for later:

- 缓存持久化到磁盘（离线可用）
- 分页预取与滚动预加载策略
- 请求竞态与全局取消策略的深度调优
- Riverpod 代码生成（`riverpod_generator`）的引入

---

## Dependencies / Assumptions

- 新增 Riverpod 依赖；现有 `ApiService` 保留为底层 HTTP 封装，provider 调用它。
- 假设：随机种子分页的"按种子缓存"由首页 provider 持有种子状态；刷新换种子时失效并重取。
- 假设：全量迁移期间每完成一个页面即通过构建门禁（analyze / test / web 构建）验证。
