# Learnings

## U1 数据层搭建

- flutter_riverpod 3.4.x 需要 Dart ≥3.12，本项目 Dart 3.10.8，采用 **3.3.2**（`AsyncNotifier`/`Notifier`/`FutureProvider.family` API 一致）。
- 随机分页的 seed 独立为 `randomSeedProvider`：`randomLibraryProvider` 失效重建时沿用同一种子，顺序不重排；刷新换种子走 notifier.reshuffle()。
- 收藏变更后**不失效** random/search provider（会丢已加载分页或重排），改为 notifier 内 `updateFavorited` 原地更新角标 + 失效 favorites/detail——这是对 plan"失效矩阵"的偏离，记录在案。
- `ComicDetail` 模型聚合详情接口返回（comic/chapters/favorited/authorFavorited/progress），详情页直接消费。

## U2 首页迁移

- 首页改为 `ConsumerStatefulWidget`：随机分页/搜索/续读条全部来自 provider，删除页面内 `_comics/_seed/_loading` 等手工状态。
- Riverpod 3 注意点：`AsyncValue` 取值用 `.value`（无 `valueOrNull`）；`ref.refresh` 返回 AsyncValue 且签名易错，统一用 `ref.invalidate` 触发重取。
- 收藏变更后的角标同步由 U1 的 mutation 助手（原地 `updateFavorited`）自动完成，首页不再需要"返回后同步"补丁；阅读进度变更由 `updateReadingProgress` 失效 recent，续读条自动更新。
- 随机列表不做"进入即后台重取"（会丢已加载分页），保持缓存 + 下拉刷新换种子；简单查询（recent/favorites/详情）由页面进入时 invalidate 后台刷新。
