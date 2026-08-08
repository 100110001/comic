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

## U4 阅读器数据层

- 阅读器进入时用详情接口拉章节列表构建章节上下文；当前章节 id 定位下标，找不到时回退到第 0 章。
- 章节切换 `_goToChapter` 统一处理：重置图片/页码/待跳页，初始定位通过 `_pendingJumpPage` 在布局完成后执行。
- 上一章/下一章按钮放在阅读器 AppBar（无对应章节时禁用）；滚动接近本章底部时自动续章（`_onScroll` 内判定）。
- 进度保存仍为离开阅读器时一次，章节切换后保存的是当前章节与页码。
- 章节列表加载失败时降级为直接加载传入的章节，不阻塞阅读。

## U5 桌面阅读器

- 桌面主体为单页大图（`BoxFit.contain` 居中），`Listener.onPointerSignal` 监听滚轮：向下滚下一页、向上滚回上一页。
- 页首向上/页尾向下触发章节切换（`_prevChapter`/`_autoContinue`）。
- 底部常驻 `ReaderProgressBar`（本章第 N/M 页 + Slider 拖动跳页）；单页章节时隐藏 Slider 只显示文字。
- 目录用 `Scaffold.endDrawer` 侧边面板（`ChapterDrawer`），AppBar 目录按钮打开。
- `clamp` 返回 num，索引/滑块值需 `.toInt()`/`.toDouble()` 转换。

## U6 手机阅读器

- 手机主体保持竖向 `ListView`，底部叠加 `SafeArea` 内的 `ReaderProgressBar`（本章第 N/M 页 + Slider 拖动跳页）。
- 页码随滚动更新改为"页码变化时才 setState"（避免每个滚动帧都重建进度条）。
- 目录按钮双端共用：桌面打开 `endDrawer`，手机 `showModalBottomSheet` 抽屉。
- 滚动接近底部自动续章（U4 已在 `_onScroll` 接入）。

## U7 详情页

- `getComic` 返回值扩展为含 `progress`（`{chapterId, pageNumber}?`）的记录类型，详情页据此显示"继续阅读"按钮。
- 宽屏（≥720px）下详情页为"左侧 330px 信息栏 + 右侧章节列表"，窄屏保持纵向；继续阅读按钮在信息区。
- 继续阅读定位时章节标题从已加载的章节列表反查，找不到则传空标题。

## U8 桌面侧栏页面

- 最近阅读/收藏列表抽成共享组件 `lib/widgets/reading_lists.dart`（`RecentReadingList`/`FavoritesList`），手机"我的"tab 与桌面侧栏页共用。
- 桌面侧栏三个入口（首页/最近阅读/收藏）用 `IndexedStack` 切换，最近阅读与收藏各自包一层 `_PageScaffold`（AppBar + 列表）。
- `flutter build web --release` 通过，确认双端代码可整体编译。

## 修复：目录按钮有时无效

- **根因 1（桌面端）**：目录按钮用 `Scaffold.of(context)`，而该 `context` 位于 ReaderScreen 自己的 Scaffold 上方，向上查找到的是外层壳的 Scaffold（没有 endDrawer），点击无效果。修复：用 `Builder` 包住按钮，让 `Scaffold.of` 拿到 Scaffold 之下的 context。
- **根因 2**：`_chapters.isEmpty` 时按钮被禁用，章节列表未加载完或加载失败都会"点了没用"。修复：按钮始终可用，按下时先 `_ensureChapters()` 重试拉取章节列表；桌面端 `endDrawer` 始终挂载（空章节显示"暂无章节"），并在下一帧打开。

## 平台判定规则调整

- 规则从"Web 一律桌面、桌面系统恒桌面、移动端恒手机"改为"**Android/iOS 恒手机；Windows/Linux/macOS 与 Web 按窗口宽度（≥720px）决定**"。
- 实现：`lib/platform.dart` 暴露 `isMobilePlatform` 与 `isDesktopAt(width)`，主壳用 `_AdaptiveShell` 监听 MediaQuery 宽度实时切换桌面壳/手机壳；首页与阅读器在 build 内用同一判定。
- define.md / plan.md 的 R1、KTD、System-Wide Impact 已同步更新（原地修改，不堆叠旧文本）。

## 阅读器工具按钮：常驻 + 条件禁用

- 目录/上一章/下一章三个按钮常驻。
- 上一章/下一章在无对应章节时禁用，且禁用态图标置灰（`0xFF484f58`），与可用态白色区分，不再"看着可点"。
- 目录永远可点：章节列表为空时先提示"正在加载章节…"并重试拉取，仍为空再提示"暂无章节信息"，保证每次点击都有反馈。
- 桌面端 `endDrawer` 始终挂载（空章节显示"暂无章节"），点击目录必然有反应。
