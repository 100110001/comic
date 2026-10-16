import 'package:shared_preferences/shared_preferences.dart';

final _pending = Expando<Future<void>>('preferenceWrites');

/// 偏好共享缓存：串行执行实际写入与失败恢复，避免恢复覆盖其他写入。
Future<bool> writePreference(
  SharedPreferences prefs,
  Future<bool> Function() write,
) {
  final operation = (_pending[prefs] ?? Future<void>.value()).then((_) async {
    try {
      final saved = await write();
      if (saved) return true;
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    await prefs.reload();
    return false;
  });
  late final Future<void> tail;
  void clearTail() {
    if (identical(_pending[prefs], tail)) _pending[prefs] = null;
  }

  tail = operation.then<void>(
    (_) => clearTail(),
    onError: (Object error, StackTrace stack) => clearTail(),
  );
  _pending[prefs] = tail;
  return operation;
}
