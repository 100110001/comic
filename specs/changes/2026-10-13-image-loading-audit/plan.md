# 图片加载修复计划

## 概要与需求

落实 define.md 的 R1—R4；整个循环使用同一修复分支和面向 master 的 PR。

## 关键决策

- 文件路径逐段编码，版本参数单独追加；已编码的接口 URL 不重复编码。
- 尺寸探测改为异步按需读取图片头，导入时保存尺寸；历史缺失尺寸只在请求内补有限页，余下有界后台补齐。未知尺寸保持既有回退，不阻断阅读。
- 未补齐尺寸的章节缓存短暂保留，后台更新仅作用于同 ID、同路径且宽度仍为空的记录，并在写入前核对文件大小和修改时间。
- 字号、行高与网格文字预算一致，文本使用明确的首尾行高规则，避免字体回退额外增高。
- 数据整理采用明确的旧章节 ID 白名单，事务内备份全行并复查；旧漫画仅在没有有效章节、收藏和进度时删除。

## 实现单元

### U1. ✅ 修复图片加载与整理失效索引

- 需求：R1—R4。
- 依赖：无。
- 文件：app/lib/models/comic.dart、app/lib/widgets/comic_card.dart、app/lib/providers/super_resolution_provider.dart、backend/src/routes/chapters.ts、backend/src/routes/images.ts、backend/src/scripts/seed.ts、图片元数据工具、现有回归测试。
- 方案：统一编码；异步读取尺寸；无有效版本的页保留原图失败流程但不影响同窗口其他页的增强；尺寸探测不阻塞整个章节；数据整理单独备份执行并记录结果。
- 验证：特殊字符与版本参数往返；大章节耗时与并行健康检查；原图及解析接口成功；现有前后端五项门禁；浏览器复查首页与阅读。

## 规范影响（Spec Impact）

- specs/image-loading.convention.md：图片路径编码及数据来源身份。
- specs/reader.spec.md：未知尺寸逐步补齐和缺文件页保留位置。
- specs/import-pipeline.spec.md：导入时获取当前尺寸，整理旧数据仍须显式操作。
- specs/ui-style.convention.md：固定行高与文字区域一致。

## 延后事项

- 不扩展漫画合并、自动识别改名和自动删除策略；本次业务数据整理不变成导入默认行为。
