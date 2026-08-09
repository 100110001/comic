# Learnings

## U1 数据层搭建

- flutter_riverpod 3.4.x 需要 Dart ≥3.12，本项目 Dart 3.10.8，采用 **3.3.2**（`AsyncNotifier`/`Notifier`/`FutureProvider.family` API 一致）。
- 随机分页的 seed 独立为 `randomSeedProvider`：`randomLibraryProvider` 失效重建时沿用同一种子，顺序不重排；刷新换种子走 notifier.reshuffle()。
- 收藏变更后**不失效** random/search provider（会丢已加载分页或重排），改为 notifier 内 `updateFavorited` 原地更新角标 + 失效 favorites/detail——这是对 plan"失效矩阵"的偏离，记录在案。
- `ComicDetail` 模型聚合详情接口返回（comic/chapters/favorited/authorFavorited/progress），详情页直接消费。
