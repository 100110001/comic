---
title: 阅读器键盘换章
date: 2026-10-09
topic: reader-chapter-keys
---

# 阅读器键盘换章

## 概述

桌面阅读器通过 Page Up 切换上一章、Page Down 切换下一章，让多章节漫画可以直接用键盘换章。

## 需求

- R1. Page Up 和 Page Down 分别切换上一章和下一章，进入目标章节第一页。
- R2. 首章的 Page Up、末章的 Page Down 不执行操作；单章节漫画两键均不换页或换书。
- R3. 左右方向键、空格、Home/End 保留既有章内翻页和定位行为，手机阅读行为保持不变。

## 决策

换章遵循工具栏上一章、下一章按钮的语义。用户已明确将 Page Up/Page Down 从原有规范的翻页操作改为换章操作。
