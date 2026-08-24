# Learnings

## U1 + U5. 双套主题令牌与全 App 改用主题色

- `AppColors`（`ThemeExtension`）承载浅/深两套颜色，`context.appColors.*` 取色；圆角保持单一常量。
- U1 与 U5 无法分离提交：删掉旧的 `k*` 颜色常量后所有引用同步报错，必须一次性把全部组件切到主题色才能通过 analyze。
- `ColorScheme` 构造需要显式 `secondary`/`onSecondary`/`onError`，否则编译报 missing required argument。
- 阅读器新增 `readerBg`/`readerBar` 令牌：深色为黑底 `#161b22` 条，浅色为浅灰底白条；`reader_progress_bar`、`_LazyImage` 加载框、`_ImageRetryBox` 都用 `readerBar`。
- 浅色强调色用 `#0969da`（onPrimary 白色），深色保持 `#58a6ff`（onPrimary 黑色）。
