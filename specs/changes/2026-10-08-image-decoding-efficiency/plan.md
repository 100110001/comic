---
title: 按显示尺寸解码图片
origin: specs/changes/2026-10-08-image-decoding-efficiency/define.md
type: perf
date: 2026-10-08
---

# 按显示尺寸解码图片

## 技术决策

- 公共 ImageProvider 包装 NetworkImage，缓存键包含原 URL、显示像素档位和 BoxFit；通过解码回调的原图尺寸计算保比例目标，不放大原图。
- 封面按 cover 的实际裁切需求计算解码尺寸，避免单宽度策略让横向封面变糊，也避免同时指定宽高拉伸原图。桌面 contain 取完整图片区域，移动 fitWidth 不限制长条页高度。
- 使用向上分档的物理尺寸；超过最大档位回退原图。网络原始字节和全局 LRU 预算沿用 Flutter，不新增依赖。
- 封面公共组件在 LayoutBuilder 中取得有限实际约束；阅读器保存当前主体尺寸，由同一工厂为显示与预加载建立 provider。首次布局或尺寸档位变化后安排帧后预加载，校验章节与窗口代际。
- 重试 await provider.evict 后重建图片；预加载使用 onError 消化预期失败，不让预加载错误干扰阅读。

## 实现单元

### U1. ✅ 公共解码与封面（同分支 PR 待创建）

- 文件：新增 app/lib/utils/display_image_provider.dart 与 app/lib/widgets/display_network_image.dart，修改封面入口 comic_card、reading_lists、home、detail、discovery。
- 验证：原比例 cover 与 contain 的真实解码尺寸、DPR、同档/跨档缓存键、来源与版本保留、超档回退及现有布局测试。

### U2. ✅ 阅读器统一显示与预加载（同分支 PR 待创建）

- 依赖：U1。
- 文件：reader_screen.dart 与既有 reader_screen_test.dart。
- 验证：桌面实际区域、移动长条宽度策略、预加载显示缓存键一致、缩图失败重试重发、窗口调整和初始续读不退化。

## 资料与研究

- 本地阅读器、封面入口及相关规范已研究，两名只读研究代理检查缓存键、预加载与规范边界。
- Flutter ResizeImage 与 Image.network 解码 API：https://api.flutter.dev/flutter/painting/ResizeImage-class.html、https://api.flutter.dev/flutter/widgets/Image/Image.network.html。
- 预加载命中依赖相同缓存键：https://api.flutter.dev/flutter/widgets/precacheImage.html。

## Spec Impact

- 新增 specs/image-loading.convention.md：公共图片解码策略、来源缓存身份、尺寸分档、原生/Web 边界。
- 更新 specs/reader.spec.md：移动和桌面解码、预加载同键、过期回调保护、实际 provider 重试。
- 检查 comics-browsing、discovery、UI 风格规范，保持封面比例、布局、分页及交互不变；通用图片规则集中于新约定，避免重复。


