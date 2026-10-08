import 'dart:async';
import 'dart:io';
import 'package:comic/models/comic.dart';
import 'package:comic/models/reading_progress_entry.dart';
import 'package:comic/providers/reading_progress_provider.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/services/progress_storage_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/progress_storage.dart';

const origin = 'http://example.com';
ReadingProgressEntry position(int page, {String url = origin}) =>
    ReadingProgressEntry(
      comic: Comic(id: 1, title: '漫画', serverUrl: url),
      chapterId: 10,
      chapterTitle: '章节',
      pageNumber: page,
    );

class ProgressClient extends ApiClient {
  ProgressClient({super.baseUrl = origin, super.generation = 0});
  final pages = <int>[];
  bool fail = false;
  Completer<void>? blocked;
  @override
  Future<void> updateProgress({
    required int comicId,
    required int chapterId,
    required int pageNumber,
  }) async {
    pages.add(pageNumber);
    await blocked?.future;
    if (fail) throw StateError('断网');
  }
}

ProviderContainer container(MemoryProgressStorage storage) => ProviderContainer(
  overrides: [
    progressStorageProvider.overrideWithValue(storage),
    serverSessionProvider.overrideWith(
      () => ServerSessionNotifier(initialUrl: origin),
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('断网后重启恢复，成功确认后清空已同步版本', () async {
    final storage = MemoryProgressStorage();
    var c = container(storage);
    final client = ProgressClient()..fail = true;
    addTearDown(client.close);
    await c.read(readingProgressQueueProvider.notifier).record(position(5));
    await c.read(readingProgressQueueProvider.notifier).sync(client);
    c.dispose();
    c = container(storage);
    addTearDown(c.dispose);
    expect(
      (await c.read(
        readingProgressQueueProvider.future,
      )).single.entry.pageNumber,
      5,
    );
    client.fail = false;
    await c.read(readingProgressQueueProvider.notifier).sync(client);
    expect(c.read(readingProgressQueueProvider).requireValue, isEmpty);
  });

  test('并发同步合并，旧版本确认不删除上传中的新位置', () async {
    final c = container(MemoryProgressStorage());
    addTearDown(c.dispose);
    final client = ProgressClient()..blocked = Completer<void>();
    addTearDown(client.close);
    final queue = c.read(readingProgressQueueProvider.notifier);
    await queue.record(position(1));
    final upload = queue.sync(client);
    expect(identical(upload, queue.sync(client)), isTrue);
    while (client.pages.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await queue.record(position(2));
    client.blocked!.complete();
    await upload;
    expect(
      c.read(readingProgressQueueProvider).requireValue.single.entry.pageNumber,
      2,
    );
    await queue.sync(client);
    expect(client.pages, [1, 2]);
    expect(c.read(readingProgressQueueProvider).requireValue, isEmpty);
  });

  test('A→B→A 后旧会话不能确认删除断点，新会话才补传', () async {
    final c = container(MemoryProgressStorage());
    addTearDown(c.dispose);
    final queue = c.read(readingProgressQueueProvider.notifier);
    final old = ProgressClient()..blocked = Completer<void>();
    addTearDown(old.close);
    await queue.record(position(3));
    final upload = queue.sync(old);
    while (old.pages.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final session = c.read(serverSessionProvider.notifier);
    await session.save('http://other.com');
    expect(c.read(localReadingProgressProvider(1)), isNull);
    await queue.record(position(7, url: 'http://other.com'));
    await session.save(origin);
    old.blocked!.complete();
    await upload;
    expect(c.read(readingProgressQueueProvider).requireValue.length, 2);
    final current = ProgressClient(generation: 2);
    addTearDown(current.close);
    await queue.sync(current);
    expect(current.pages, [3]);
    expect(
      c.read(readingProgressQueueProvider).requireValue.single.serverUrl,
      'http://other.com',
    );
  });

  test('写入失败不发布未持久化位置，后续写入仍能重试', () async {
    final storage = MemoryProgressStorage();
    final c = container(storage);
    addTearDown(c.dispose);
    final queue = c.read(readingProgressQueueProvider.notifier);
    await queue.record(position(1));
    storage.failWrite = true;
    await expectLater(queue.record(position(2)), throwsStateError);
    expect(
      c.read(readingProgressQueueProvider).requireValue.single.entry.pageNumber,
      1,
    );
    storage.failWrite = false;
    await queue.record(position(2));
    expect(
      c.read(readingProgressQueueProvider).requireValue.single.entry.pageNumber,
      2,
    );
  });

  test('原生文件替换与重新读取保留最后完成的写入', () async {
    final directory = await Directory.systemTemp.createTemp('comic-progress-');
    addTearDown(() => directory.delete(recursive: true));
    final storage = FileProgressStorage(directory: () async => directory);
    expect(await storage.read(), isNull);
    await storage.write('第一版');
    await storage.write('第二版');
    await File(
      '${directory.path}/pending-reading-progress.json.tmp',
    ).writeAsString('中断写入');
    expect(
      await FileProgressStorage(directory: () async => directory).read(),
      '第二版',
    );
  });
}
