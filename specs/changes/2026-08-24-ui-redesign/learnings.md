# Learnings

## U3. 桌面侧栏改版（图标+文字列表式）

- 用自定义 `_DesktopSidebar`（208px）替换 `NavigationRail`：顶部"漫画库"标题、5 个主项 + 底部固定"设置"。
- 选中态 = accent 15% 淡底 + accent 图标/加粗文字；悬停 = `surface2` 底；圆角用 `kRadiusButton`。
- 导航索引语义保持不变（设置仍为第 6 项），`_DesktopShellState` 的切换刷新逻辑零改动。
- 本次只做侧栏（用户反馈的痛点），整体配色/圆角改版（U1）留待后续按确认方向推进。
