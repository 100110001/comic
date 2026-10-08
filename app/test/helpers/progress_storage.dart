import 'package:comic/services/progress_storage.dart';

class MemoryProgressStorage implements ProgressStorage {
  String? contents;
  bool failWrite = false;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('磁盘写入失败');
    contents = value;
  }
}
