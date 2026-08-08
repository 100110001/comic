# Learnings

## U1 后端：列表随机排序 + 详情进度

- 列表接口 `random=1` 时 pageSize 上限放宽到 500（非随机保持 100）；实测一次返回全库 154 条，两次请求顺序不同。
- `random` 与 `keyword` 正交，可同时使用（排序与过滤互不影响）。
- 详情接口新增 `progress` 字段：`reading_progress` 有记录时返回 `{ chapterId, pageNumber }`，否则 `null`。

## U2 应用外壳

- 平台判定抽到 `lib/platform.dart`（`isDesktop = kIsWeb || Windows/Linux/macOS`），比计划文件清单多一个文件，用于集中平台分支（KTD：页面内部不散落平台分支）。
- 手机壳为底部两 tab（首页/我的）；桌面壳为 `NavigationRail` 侧栏 + `IndexedStack` 内容区；最近阅读/收藏暂为占位页，U8 替换为真实列表。
- 删除了 `lib/screens/random_screen.dart`，随机能力由首页接管。
- 顺手把 `api.dart` 的 `print` 改成 `debugPrint`（`avoid_print` 门禁），保证 `flutter analyze` 返回码为 0。

## U3 首页与搜索

- 漫画卡片抽成共享组件 `lib/widgets/comic_card.dart`（首页与搜索页复用），比计划文件清单多一个文件。
- 首页随机模式全量加载（`getRandomLibrary`，pageSize 500），下拉刷新重排；关键字模式恢复分页；清空关键字回到随机。
- 续读卡片取 `GET /api/mine/recent` 首条，无记录隐藏；点击进入阅读器并定位。
- 手机首页 AppBar 为搜索图标 → `SearchScreen`（全屏搜索页，autofocus + 分页结果网格）；桌面首页保留内联输入框。
- `_ContinueCard` 中"继续阅读"按钮视觉用播放图标；页码按 0 起始 +1 显示。
