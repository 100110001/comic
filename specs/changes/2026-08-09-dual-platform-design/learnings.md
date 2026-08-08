# Learnings

## U1 后端：列表随机排序 + 详情进度

- 列表接口 `random=1` 时 pageSize 上限放宽到 500（非随机保持 100）；实测一次返回全库 154 条，两次请求顺序不同。
- `random` 与 `keyword` 正交，可同时使用（排序与过滤互不影响）。
- 详情接口新增 `progress` 字段：`reading_progress` 有记录时返回 `{ chapterId, pageNumber }`，否则 `null`。
