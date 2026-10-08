import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'progress_storage.dart';

ProgressStorage createProgressStorage() => FileProgressStorage();

class FileProgressStorage implements ProgressStorage {
  FileProgressStorage({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/pending-reading-progress.json');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (await file.exists()) return file.readAsString();
    final temporary = File('${file.path}.tmp');
    return await temporary.exists() ? temporary.readAsString() : null;
  }

  @override
  Future<void> write(String contents) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}
