# Learnings

## U2 增量导入

- `upsertComic` 的匹配查询必须同时 `SELECT author`，否则 JS 侧无法核对作者，导致每次都被当作新漫画插入并撞唯一约束。
- `comics` 的唯一键是 `(title, author)`，MySQL 对 `author IS NULL` 的行不做去重（NULL 互不相等），所以作者为空的漫画依赖 JS 侧的 `title + author==null` 匹配来复用 ID。
- 章节/图片的排序覆写（`sort_order`/`page_number`）按扫描顺序逐行 UPDATE，中间插入新章节/新图片不会打乱既有顺序。
- 磁盘缺失的漫画在导入结束后做差集提示（`[missing] ...`），不做删除；种子数据有 154 部漫画、229 章节、17087 图片，连续两次 setup 后 ID 完全不变。

## U3 接口

- `PUT /api/comics/:id/progress` 校验 `chapter_id` 必须属于该漫画，否则返回 404 语义的 fail；`reading_progress.comic_id` 主键保证每本漫画只有一条记录，重复上报只更新。
- 实测连续上报 chapter 2→chapter 3 后，`GET /api/mine/recent` 只有一条记录且为最新值。
- `DELETE /api/comics/:id` 已移除，`DELETE /api/comics/1` 现在返回 404。
- `GET /api/comics/:id` 响应新增 `favorited` 字段（left 查询 favorites）。

## U5 阅读器

- **偏离计划**：当前页码没有用 `_LazyImage` 可见性回调追踪，而是用滚动偏移 + 每张图预估高度的累计偏移（与初始跳转同一套数学）计算。原因是 ListView 的 `cacheExtent` 会让视口外图片提前 build，"build 即可见"会高估页码；偏移法确定性强且与跳转逻辑复用。
- 后端章节图片接口在首次请求时用 `image-size` 填充 `width`/`height` 并落库，所以正常返回都带尺寸；未知尺寸时前端兜底按 4:3 估算。
- 初始跳转在列表布局完成后 `jumpTo`，长章节允许小幅偏差（计划明确接受的取舍）。

## 测试/门禁

- 替换了模板 `test/widget_test.dart`（引用了不存在的 `MyApp`，一直处于编译失败状态）为占位测试，符合仓库"默认不写单测"的姿态。
- `flutter analyze` 仅剩一条既有 info：`lib/services/api.dart:12` 的 `avoid_print`（`print('[API] GET ...')`），未处理。
- 后端 build（tsc）、`flutter analyze`、`flutter test` 均通过。

## 环境

- 本机 Dart/Flutter CLI 在沙箱内会挂起（等待写 Flutter SDK/pub 缓存），需要在提权环境下执行 `dart format` / `flutter analyze` / `flutter test`。
- PowerShell 管道向 node 传含日文的字面量会被破坏编码，调试时字符串应从文件读取。
