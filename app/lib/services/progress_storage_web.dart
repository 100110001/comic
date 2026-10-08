import 'package:shared_preferences/shared_preferences.dart';
import 'progress_storage.dart';

ProgressStorage createProgressStorage() => WebProgressStorage();

class WebProgressStorage implements ProgressStorage {
  static const _key = 'pendingReadingProgress';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String contents) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      contents,
    );
    if (!saved) throw StateError('本机阅读断点保存失败');
  }
}
