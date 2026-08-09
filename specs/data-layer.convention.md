---
status: complete
scope: convention
---

# 数据层（Riverpod）

## Responsibilities

定义服务端状态的数据访问约定：所有 API 数据通过 provider 获取与变更，页面与组件不直接调用 ApiService；提供会话内缓存、失效同步与统一的 loading/error 语义。

## Rules

- 所有 API 数据访问集中在 `lib/providers/`；页面与组件通过 `ref.watch` / `ref.read` 消费 provider，不直接调用 ApiService。
- 简单查询（收藏、收藏作者、最近阅读、漫画详情、章节图片）使用 FutureProvider 系列，会话内缓存。
- 有状态的查询（首页随机分页、搜索分页）使用 AsyncNotifier 持有分页状态。
- 变更（收藏、作者收藏、阅读进度）通过 mutation 助手完成：成功后按失效矩阵刷新相关查询。
- 失效矩阵：
  - 漫画收藏变更 → 失效收藏列表与漫画详情；随机/搜索列表原地更新角标，不重排、不丢已加载分页。
  - 作者收藏变更 → 失效收藏作者列表与漫画详情。
  - 阅读进度变更 → 失效最近阅读与漫画详情。
- 缓存优先：页面进入时已有缓存先展示；简单查询后台刷新；随机列表保持缓存 + 下拉刷新换种子（避免破坏分页）。
- 首次加载显示 loading，失败显示错误与重试入口；有缓存时失败不打断当前展示。
- 切换"我的"tab 或桌面侧栏入口时，后台刷新对应列表。

## Notes

- flutter_riverpod 使用 3.3.x（3.4.x 要求 Dart ≥3.12，本项目为 Dart 3.10.8）。
- mutation 助手参数类型为 `WidgetRef`（Riverpod 3 中 `WidgetRef` 不实现 `Ref`）。
