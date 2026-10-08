/// Web 等无 io 平台：不拦截关闭行为。
Future<void> setupCloseToTray() async {}

void setBeforeWindowClose(Future<void> Function()? callback) {}
