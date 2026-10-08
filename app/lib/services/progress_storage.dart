import 'progress_storage_web.dart'
    if (dart.library.io) 'progress_storage_io.dart'
    as platform;

abstract class ProgressStorage {
  Future<String?> read();
  Future<void> write(String contents);
}

ProgressStorage createProgressStorage() => platform.createProgressStorage();
