import 'dart:async';

import 'package:comic/models/comic.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/services/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Page = ({List<Comic> list, int total});

class _Request {
  _Request(this.page, this.size, this.keyword, this.seed, this.recent);

  final int page;
  final int size;
  final String keyword;
  final int? seed;
  final bool recent;
  final result = Completer<_Page>();

  void complete({int total = 90, int firstId = 0}) {
    final start = (page - 1) * size;
    result.complete((
      list: [
        for (var i = start; i < start + size && i < total; i++)
          Comic(id: firstId + i, title: '$keyword$i'),
      ],
      total: total,
    ));
  }
}

class _DelayedClient extends ApiClient {
  _DelayedClient({super.generation = 0})
    : super(baseUrl: 'http://example.test');

  final requests = <_Request>[];

  @override
  Future<_Page> getComics({
    int pageOffset = 1,
    int pageSize = 20,
    String keyword = '',
    bool random = false,
    int? seed,
    bool recent = false,
  }) {
    final request = _Request(pageOffset, pageSize, keyword, seed, recent);
    requests.add(request);
    return request.result.future;
  }
}

void main() {
  late _DelayedClient client;
  late ProviderContainer container;

  setUp(() {
    client = _DelayedClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
  });

  tearDown(() {
    container.dispose();
    client.close();
  });

  Future<RandomLibraryNotifier> randomLibrary() async {
    final ready = container.read(randomLibraryProvider.future);
    client.requests.last.complete();
    await ready;
    return container.read(randomLibraryProvider.notifier);
  }

  test('作者封面只展示精确作者作品且不改变搜索查询', () async {
    final subscription = container.listen(
      favoriteAuthorBooksProvider('作者'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final ready = container.read(favoriteAuthorBooksProvider('作者').future);
    expect(client.requests.single.keyword, '作者');
    client.requests.single.result.complete((
      list: const [
        Comic(id: 1, title: '标题命中作者', author: '其他人'),
        Comic(id: 2, title: '作品一', author: '作者'),
        Comic(id: 3, title: '作品二', author: '作者'),
        Comic(id: 4, title: '作品三', author: '作者'),
      ],
      total: 4,
    ));
    expect((await ready).map((comic) => comic.id), [2, 3]);
    expect(container.read(searchProvider).requireValue.keyword, '');
  });

  test('作者封面查询切换服务器后淘汰旧响应', () async {
    SharedPreferences.setMockInitialValues({});
    final clients = <_DelayedClient>[];
    final isolated = ProviderContainer(
      overrides: [
        apiClientFactoryProvider.overrideWithValue(({
          required baseUrl,
          required generation,
        }) {
          final next = _DelayedClient(generation: generation);
          clients.add(next);
          return next;
        }),
      ],
    );
    addTearDown(isolated.dispose);
    final subscription = isolated.listen(
      favoriteAuthorBooksProvider('作者'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await isolated.read(serverSessionProvider.notifier).save('http://new.test');
    await isolated.pump();
    final ready = isolated.read(favoriteAuthorBooksProvider('作者').future);
    clients.last.requests.single.result.complete((
      list: const [Comic(id: 100, title: '新作品', author: '作者')],
      total: 1,
    ));
    await ready;
    clients.first.requests.single.result.complete((
      list: const [Comic(id: 1, title: '旧作品', author: '作者')],
      total: 1,
    ));
    await isolated.pump();
    expect(
      isolated.read(favoriteAuthorBooksProvider('作者')).requireValue.single.id,
      100,
    );
  });

  test('新搜索先返回时忽略旧搜索的成功与失败', () async {
    final notifier = container.read(searchProvider.notifier);
    final old = notifier.search('旧');
    final current = notifier.search('新');
    client.requests[1].complete(firstId: 100);
    await current;
    client.requests[0].complete();
    await old;
    expect(container.read(searchProvider).requireValue.keyword, '新');
    expect(container.read(searchProvider).requireValue.comics.first.id, 100);

    final failure = notifier.search('失败');
    final success = notifier.search('最新');
    client.requests[3].complete();
    await success;
    client.requests[2].result.completeError(Exception('旧查询失败'));
    await expectLater(failure, completes);
    expect(container.read(searchProvider).hasError, isFalse);
    expect(container.read(searchProvider).requireValue.keyword, '最新');
  });

  test('清空搜索淘汰尚未返回的查询且不发送空关键字请求', () async {
    final notifier = container.read(searchProvider.notifier);
    final pending = notifier.search('旧');
    await notifier.search('');
    client.requests.single.complete();
    await pending;
    expect(client.requests, hasLength(1));
    expect(container.read(searchProvider).requireValue.keyword, isEmpty);
    expect(container.read(searchProvider).requireValue.comics, isEmpty);
  });

  test('搜索分页互斥并保留请求期间的收藏角标', () async {
    final notifier = container.read(searchProvider.notifier);
    final first = notifier.search('漫画');
    client.requests.single.complete();
    await first;
    final more = notifier.loadMore();
    await notifier.loadMore();
    expect(client.requests, hasLength(2));
    expect(container.read(searchProvider).requireValue.isLoadingMore, isTrue);
    notifier.updateFavorited(0, true);
    client.requests.last.complete();
    await more;
    expect(container.read(searchProvider).requireValue.comics, hasLength(60));
    expect(
      container.read(searchProvider).requireValue.comics.first.favorited,
      isTrue,
    );
    expect(container.read(searchProvider).requireValue.isLoadingMore, isFalse);
  });

  test('新搜索淘汰旧分页且等待期间不再加载旧查询', () async {
    final notifier = container.read(searchProvider.notifier);
    final first = notifier.search('旧');
    client.requests.last.complete();
    await first;
    final more = notifier.loadMore();
    final latest = notifier.search('新');
    await notifier.loadMore();
    expect(client.requests, hasLength(3));
    client.requests[2].complete(firstId: 100);
    await latest;
    client.requests[1].complete();
    await more;
    final state = container.read(searchProvider).requireValue;
    expect(state.keyword, '新');
    expect(state.comics, hasLength(30));
    expect(state.comics.first.id, 100);
  });

  test('搜索失败保留关键字与缓存并支持重试', () async {
    final notifier = container.read(searchProvider.notifier);
    final first = notifier.search('漫画');
    client.requests.last.complete();
    await first;
    final refresh = notifier.search('漫画');
    final failed = expectLater(refresh, throwsException);
    client.requests.last.result.completeError(Exception('连接失败'));
    await failed;
    expect(container.read(searchProvider).value!.comics, hasLength(30));
    expect(container.read(searchProvider).value!.keyword, '漫画');
    expect(container.read(searchProvider).isLoading, isFalse);
    final retry = notifier.search('漫画');
    client.requests.last.complete(firstId: 100);
    await retry;
    expect(container.read(searchProvider).hasError, isFalse);
    expect(container.read(searchProvider).requireValue.comics.first.id, 100);
  });

  test('动态页大小缩小扩大均保留完整唯一序列', () async {
    final notifier = await randomLibrary();
    final seed = container.read(randomLibraryProvider).requireValue.seed;
    for (final size in [18, 42, 24, 36, 18]) {
      notifier.setPageSize(size);
      final count = client.requests.length;
      final more = notifier.loadMore();
      if (client.requests.length > count) {
        expect(client.requests.last.size, size);
        expect(client.requests.last.seed, seed);
        client.requests.last.complete();
      }
      await more;
    }
    final ids = container
        .read(randomLibraryProvider)
        .requireValue
        .comics
        .map((c) => c.id);
    expect(ids, List.generate(90, (i) => i));
  });

  test('首次加载期间和分页期间保留最新布局页大小', () async {
    final ready = container.read(randomLibraryProvider.future);
    final notifier = container.read(randomLibraryProvider.notifier);
    notifier.setPageSize(18);
    client.requests.last.complete();
    await ready;
    expect(container.read(randomLibraryProvider).requireValue.pageSize, 18);
    final more = notifier.loadMore();
    notifier.setPageSize(42);
    notifier.updateFavorited(0, true);
    client.requests.last.complete();
    await more;
    final state = container.read(randomLibraryProvider).requireValue;
    expect(state.pageSize, 42);
    expect(state.comics, hasLength(36));
    expect(state.comics.first.favorited, isTrue);
  });

  test('切换最近入库淘汰旧分页，刷新与续页保持最近排序', () async {
    final notifier = await randomLibrary();
    final old = notifier.loadMore();
    container.read(librarySortProvider.notifier).select(LibrarySort.recent);
    final ready = container.read(randomLibraryProvider.future);
    expect(client.requests.last.recent, isTrue);
    expect(client.requests.last.seed, isNull);
    client.requests.last.complete(firstId: 100);
    await ready;
    client.requests[1].complete();
    await old;
    expect(
      container.read(randomLibraryProvider).requireValue.comics.first.id,
      100,
    );
    final more = notifier.loadMore();
    expect(client.requests.last.recent, isTrue);
    client.requests.last.complete(firstId: 100);
    await more;
    expect(
      container.read(randomLibraryProvider).requireValue.comics,
      hasLength(60),
    );
    final seed = container.read(randomSeedProvider);
    final refresh = notifier.reshuffle();
    expect(client.requests.last.recent, isTrue);
    expect(client.requests.last.page, 1);
    client.requests.last.complete(firstId: 200);
    await refresh;
    expect(container.read(randomSeedProvider), seed);
    expect(
      container.read(randomLibraryProvider).requireValue.comics.first.id,
      200,
    );
  });

  test('快速切换排序不接受过期首屏或刷新失败', () async {
    final notifier = await randomLibrary();
    final oldRefresh = notifier.reshuffle();
    container.read(librarySortProvider.notifier).select(LibrarySort.recent);
    container.read(randomLibraryProvider);
    final recentRequest = client.requests.last;
    container.read(librarySortProvider.notifier).select(LibrarySort.random);
    final ready = container.read(randomLibraryProvider.future);
    client.requests.last.complete(firstId: 300);
    await ready;
    recentRequest.complete(firstId: 100);
    client.requests[1].result.completeError(Exception('过期刷新失败'));
    await oldRefresh;
    await container.pump();
    final current = container.read(randomLibraryProvider).requireValue;
    expect(current.sort, LibrarySort.random);
    expect(current.comics.first.id, 300);
    expect(current.error, isNull);
  });

  test('随机分页互斥且失败后可再次加载', () async {
    final notifier = await randomLibrary();
    final more = notifier.loadMore();
    await notifier.loadMore();
    expect(client.requests, hasLength(2));
    final failed = expectLater(more, throwsException);
    client.requests.last.result.completeError(Exception('分页失败'));
    await failed;
    expect(
      container.read(randomLibraryProvider).requireValue.isLoadingMore,
      isFalse,
    );
    expect(
      container.read(randomLibraryProvider).requireValue.comics,
      hasLength(30),
    );
    final retry = notifier.loadMore();
    client.requests.last.complete();
    await retry;
    expect(
      container.read(randomLibraryProvider).requireValue.comics,
      hasLength(60),
    );
  });

  test('阅读快照跨不整页续接，失败可重试且不受首页换排序影响', () async {
    final notifier = await randomLibrary();
    notifier.setPageSize(18);
    final session = notifier.readingSession();
    expect((await session.prev(10))?.id, 9);
    final failed = expectLater(session.next(29), throwsException);
    expect(client.requests.last.page, 2);
    expect(client.requests.last.size, 18);
    client.requests.last.result.completeError(Exception('续页失败'));
    await failed;
    container.read(librarySortProvider.notifier).select(LibrarySort.recent);
    final ready = container.read(randomLibraryProvider.future);
    client.requests.last.complete(firstId: 100);
    await ready;
    final next = session.next(29);
    expect(client.requests.last.recent, isFalse);
    client.requests.last.complete(total: 32);
    expect((await next)?.id, 30);
    // 详情加载失败后，重试仍指向同一本，不提前移动游标。
    expect((await session.next(29))?.id, 30);
    expect((await session.next(30))?.id, 31);
    expect(session.canNext(31), isFalse);
    final count = client.requests.length;
    expect(await session.next(31), isNull);
    expect(client.requests, hasLength(count));
    expect(session.canPrev(0), isFalse);
  });

  test('最近阅读序列续页保留排序，服务器变化淘汰在途响应', () async {
    SharedPreferences.setMockInitialValues({});
    container.read(librarySortProvider.notifier).select(LibrarySort.recent);
    final notifier = await randomLibrary();
    final session = notifier.readingSession();
    final next = session.next(29);
    final request = client.requests.last;
    expect(request.recent, isTrue);
    expect(request.seed, isNull);
    await container
        .read(serverSessionProvider.notifier)
        .save('http://new.test');
    request.complete();
    expect(await next, isNull);
    expect(await session.prev(10), isNull);
    expect(session.canNext(10), isFalse);
  });

  test('洗牌淘汰旧分页且旧失败不解除新分页的互斥', () async {
    final notifier = await randomLibrary();
    final old = notifier.loadMore();
    final refresh = notifier.reshuffle();
    await notifier.loadMore();
    expect(client.requests, hasLength(3));
    client.requests[2].complete(firstId: 100);
    await refresh;
    final more = notifier.loadMore();
    client.requests[1].result.completeError(Exception('旧分页失败'));
    await expectLater(old, completes);
    await notifier.loadMore();
    expect(client.requests, hasLength(4));
    client.requests[3].complete(firstId: 100);
    await more;
    final ids = container
        .read(randomLibraryProvider)
        .requireValue
        .comics
        .map((c) => c.id);
    expect(ids, List.generate(60, (i) => 100 + i));
  });

  test('首次请求未完成时重复洗牌等待同一次首屏', () async {
    final old = container.read(randomLibraryProvider.future);
    final notifier = container.read(randomLibraryProvider.notifier);
    final refresh = notifier.reshuffle();
    await container.pump();
    expect(client.requests, hasLength(1));
    client.requests[0].complete(firstId: 100);
    await refresh;
    await old;
    await container.pump();
    expect(
      container.read(randomLibraryProvider).requireValue.comics.first.id,
      100,
    );
  });

  test('换批重复触发共享等待，失败后可以重新换批', () async {
    final notifier = await randomLibrary();
    final first = notifier.reshuffle();
    final duplicate = notifier.reshuffle();
    expect(identical(first, duplicate), isTrue);
    expect(client.requests, hasLength(2));
    final failed = expectLater(first, throwsException);
    client.requests.last.result.completeError(Exception('换批失败'));
    await failed;
    final retry = notifier.reshuffle();
    expect(client.requests, hasLength(3));
    client.requests.last.complete(firstId: 100);
    await retry;
    expect(
      container.read(randomLibraryProvider).requireValue.comics.first.id,
      100,
    );
  });

  test('切换服务器后旧搜索不能覆盖新会话', () async {
    SharedPreferences.setMockInitialValues({});
    final clients = <_DelayedClient>[];
    final isolated = ProviderContainer(
      overrides: [
        apiClientFactoryProvider.overrideWithValue(({
          required baseUrl,
          required generation,
        }) {
          final next = _DelayedClient(generation: generation);
          clients.add(next);
          return next;
        }),
      ],
    );
    addTearDown(isolated.dispose);
    final notifier = isolated.read(searchProvider.notifier);
    final old = notifier.search('旧服务器');
    await isolated.read(serverSessionProvider.notifier).save('http://new.test');
    await isolated.read(searchProvider.future);
    final latest = isolated.read(searchProvider.notifier).search('新服务器');
    clients.last.requests.single.complete(firstId: 100);
    await latest;
    clients.first.requests.single.complete();
    await old;
    expect(isolated.read(searchProvider).requireValue.keyword, '新服务器');
    expect(isolated.read(searchProvider).requireValue.comics.first.id, 100);
  });
}
