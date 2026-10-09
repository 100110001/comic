# 应用图标替换计划

## 概述

以 define.md 为需求来源，保存分享页原始分辨率图片，并派生现有平台资源。原有透明图标及深色背景约定随新图同步调整。

## 需求

- R1. 保留原图人物构图及粉色背景，按平台要求缩放。
- R2. Windows 与托盘共用多尺寸 ICO；Android、iOS 与 Web 的资源引用有效。
- R3. Android 自适应与 Web maskable 预留裁切空间；iOS 资源为不透明 RGB。

## 实现单元

### U1. 替换全部平台图标

依赖：无。文件：app/windows/runner/resources/、app/android/app/src/main/res/、app/ios/Runner/Assets.xcassets/AppIcon.appiconset/、app/web/。

方案：原始图片保存于既有 app_icon.png 路径，派生各尺寸 PNG 与 PNG 编码多尺寸 ICO；Android 自适应图标在粉色背景中居中缩放；Web maskable 使用同色留白。复用既有引用，不引入运行时依赖。

验证：检查 PNG 尺寸、不透明度、ICO 帧目录、各平台资源引用；运行仓库规定的 Flutter 和后端门禁。

## 范围边界

不涉及 Flutter 业务代码、后端行为或发版版本号。按用户仓库偏好，定义、计划、实现、收割在同一分支完成，最终提交一个目标为 master 的 PR。

## 规范影响

更新 specs/ui-style.convention.md 中应用图标的来源、背景和平台裁切约定。
