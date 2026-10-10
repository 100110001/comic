---
title: 漫画详情快捷操作
type: feat
date: 2026-10-10
origin: specs/changes/2026-10-10-detail-local-actions/define.md
---

# 漫画详情快捷操作

## 概要

增加后端原文件夹打开操作与作品信息复制入口，交换阅读和收藏按钮位置。

## 需求

- R1. 目录通过漫画 ID 在后端解析并打开；客户端不提交文件路径。
- R2. 收藏按钮排在阅读按钮上方，阅读进度提示继续跟随阅读按钮。
- R3. 标题和非空作者的完整原文可复制，保留作者搜索和收藏入口。

## 技术决策

- 使用独立 POST /api/comics/:id/open-directory，由封面路径确定漫画根目录下的第一级文件夹，覆盖根目录直接放图和章节子目录两种布局。
- 规范化路径并校验真实路径仍位于漫画根目录内，拒绝根目录本身、越界与目录缺失；使用参数数组调用系统文件管理器，不拼接 shell 命令。
- Flutter 通过 provider 调用不可变会话客户端，页面防止重复点击，异步反馈检查当前来源；复制使用 Flutter Clipboard。
- 不引入新依赖，不为简单按钮写单元测试；对目录边界做独立临时验证。

## 实施单元

### U1. 已实现：详情操作与后端目录打开

- **依赖：** 无。
- **文件：** app/lib/screens/detail_screen.dart、app/lib/providers/comics_providers.dart、app/lib/services/api_client.dart、backend/src/routes/comics.ts、backend/src/services/comic-directory.ts。
- **做法：** 实现目录解析和打开接口，增加页面打开与复制操作，交换按钮顺序。
- **验证：** 五项仓库门禁、后端 TypeScript 编译；临时文件夹验证章节布局、根目录图片、路径越界和缺失目录。

## 风险

后端必须具备可用的桌面会话和文件管理器；无桌面环境或目录不可用时返回失败，不影响阅读。API 成功表示系统打开请求已完成，不能保证窗口前台显示。

## 规范影响（Spec Impact）

- 更新 specs/comics-browsing.spec.md：后端目录打开接口、目录来源与失败语义、标题和作者复制。
- 更新 specs/ui-style.convention.md：收藏在上、阅读在下及目录/复制入口。

## 界面补充

用户追加要求详情页增加色差。U1 使用现有主题令牌增加信息区渐变、话数/页数标签、粉色收藏按钮和章节序号底色；保留响应式滚动，使用真实渲染检查浅深主题与窄屏布局。
