# Learnings

## U1 后端：favorited + seed 稳定随机分页

- `comicQuery()` 增加 `favorited`（`COUNT(DISTINCT favorites.comic_id) > 0`）与 `favorites` left join；收藏表 1:1，不影响行数。
- 列表接口 `random=1` 时支持 `seed`：`ORDER BY RAND(?)` 绑定 seed；同一 seed 顺序稳定、跨页无重复（实测 page1/page2 无重叠）。
- **修复既有 bug**：`total` 原先用带 `GROUP BY` 的 `count(*)`，返回的是某本漫画的联表行数（实测 26）而非漫画总数；改为独立 `countDistinct(comics.id)` 查询（实测 154，搜索 35 也正确）。这会影响之前搜索分页的提前停止，属持久修复。

## U2 前端数据层

- `Comic` 增加 `favorited`（默认 false）；`getComics` 支持 `seed` 参数，新增 `getRandomPage(seed, pageOffset, pageSize)`。
- `getRandomLibrary` 保留但首页不再使用，可后续清理。

## U3 首页种子分页

- 随机模式改为按种子分页：页大小 = `comicGridColumns(宽度) × 6`，滚动监听不分模式（接近底部即加载下一页）。
- 进入首页/下拉刷新时 `_seed = Random().nextInt(1 << 31)` 换种子；`_total` 到达后停止加载。
