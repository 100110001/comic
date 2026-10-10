# 全页面落实计划

## 实施单元

### U5. 书库、搜索与发现布局落实（已完成，PR #62）

- 收藏改为共享封面网格，保留收藏顺序、刷新和详情入口。
- 最近阅读突出真实章节与页码；作者改为响应式卡片，显示名字、作品数量与真实封面预览，进入原有作者搜索。
- 作者预览通过 provider 查询并绑定服务器会话，失败不影响作者入口。
- 搜索补结果标题、关键字与数量；发现补上一本/开读/下一本按钮，继续使用既有序列。
- 扩展现有布局与来源隔离测试，运行五项门禁。

### U6. 真实渲染逐页检查与收割（检查完成，执行收割，PR #62）

- 实际 Flutter 渲染九页，核对桌面与窄屏；保留真实业务差异，例如首页五秒续读浮条、详情不虚构简介、阅读器显示原图并保持沉浸。
- 同步规范，删除过程目录，更新 PR #62。

## 规范影响

- specs/ui-style.convention.md
- specs/reading-history-and-favorites.spec.md
- specs/comics-browsing.spec.md
- specs/discovery.spec.md
- specs/data-layer.convention.md
