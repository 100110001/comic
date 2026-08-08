---
status: complete
scope: feature
---

# 阅读记录与收藏

## Responsibilities

提供"我的"页面所需的阅读进度与收藏数据：每本漫画只保留一条最新阅读位置（章节 + 页码），收藏是漫画级别的开关。数据由后端持久化，前端"我的"页展示"最近阅读"与"收藏"两个列表，漫画详情页展示收藏状态并允许切换。

非目标：多用户/账号体系、按章节分别保留多个断点、阅读器内的翻页/缩放/方向设置。

## Public Contract

- `PUT /api/comics/:id/progress`，body `{ chapterId, pageNumber }`：记录该漫画的最新阅读位置。`chapterId` 必须属于该漫画，否则拒绝。同一漫画重复上报时覆盖旧记录，不产生第二条。
- `POST /api/comics/:id/favorite`：收藏该漫画；已收藏时重复调用无副作用。
- `DELETE /api/comics/:id/favorite`：取消收藏；未收藏时重复调用无副作用。
- `GET /api/mine/recent`：最近阅读列表，每本漫画一条，按最近更新时间倒序；每条含漫画信息、`chapterId`、章节标题与 `pageNumber`。
- `GET /api/mine/favorites`：收藏列表，按收藏时间倒序，含漫画信息与话数/图片数。
- `GET /api/comics/:id` 的响应包含 `favorited: boolean`。

页码为 0 起始（对应章节图片数组下标）。

## Invariants

- 每本漫画在 `reading_progress` 中至多一条记录。
- 收藏不区分章节，`favorites` 中每本漫画至多一条。
- 阅读进度与收藏以数据库 ID 关联漫画；重新增量导入不会改变既有 ID（见导入流程 spec），因此记录跨重新导入保持有效。
- 应用内删除漫画的功能已下线：前端详情页无删除入口，后端无对应路由。

## Notes

- 阅读记录与收藏是单机、单用户级别数据，无账号体系，不按用户区分。
- 阅读器只在离开时上报一次位置，不做阅读过程中的持续上报。
