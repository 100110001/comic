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
  _Request(this.page, this.size, this.keyword, this.seed);

  final int page;
  final int size;
  final String keyword;
  final int? seed;
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
  }) {
    final request = _Request(pageOffset, pageSize, keyword, seed);
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

  test('首次请求未完成时洗牌也不会被旧首屏覆盖', () async {
    final old = container.read(randomLibraryProvider.future);
    final notifier = container.read(randomLibraryProvider.notifier);
    final refresh = notifier.reshuffle();
    await container.pump();
    expect(client.requests, hasLength(2));
    client.requests[1].complete(firstId: 100);
    await refresh;
    client.requests[0].complete();
    await old;
    await container.pump();
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
