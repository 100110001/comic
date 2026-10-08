import 'package:comic/services/progress_storage.dart';

class MemoryProgressStorage implements ProgressStorage {
  String? contents;
  bool failWrite = false;
  bool failRead = false;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('磁盘读取失败');
    return contents;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('磁盘写入失败');
    contents = value;
  }
}
