import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tray/close_to_tray.dart';
import 'reading_progress_provider.dart';
import 'server_provider.dart';

final progressLifecycleProvider = Provider<void>((ref) {
  final queue = ref.read(readingProgressQueueProvider.notifier);
  void sync() {
    if (!ref.mounted) return;
    unawaited(queue.sync(ref.read(apiClientProvider)).catchError((_) {}));
  }

  Future<void> checkpoint() async {
    await queue.checkpointAndFlush();
    sync();
  }

  final observer = _ProgressLifecycleObserver(sync, checkpoint);
  WidgetsBinding.instance.addObserver(observer);
  setBeforeWindowClose(checkpoint);
  ref.listen(serverSessionProvider, (_, _) {
    // 初始化与来源改变均等本轮 provider 构建结束后补传。
    scheduleMicrotask(sync);
  }, fireImmediately: true);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    setBeforeWindowClose(null);
  });
});

class _ProgressLifecycleObserver extends WidgetsBindingObserver {
  _ProgressLifecycleObserver(this.sync, this.checkpoint);
  final void Function() sync;
  final Future<void> Function() checkpoint;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync();
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(checkpoint().catchError((_) {}));
    }
  }
}
