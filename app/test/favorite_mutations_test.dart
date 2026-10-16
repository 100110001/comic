import 'dart:async';

import 'package:comic/models/chapter.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/models/favorite_author.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/services/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Detail = ({
  Comic comic,
  List<Chapter> chapters,
  bool favorited,
  bool authorFavorited,
  ({int chapterId, int pageNumber})? progress,
});

class _FavoriteClient extends ApiClient {
  _FavoriteClient({super.generation = 0})
    : super(baseUrl: 'http://example.test');
  final writes = <Completer<void>>[];
  final detailReads = <(int, Completer<_Detail>)>[];
  final favoriteReads = <Completer<List<Comic>>>[];
  final authorReads = <Completer<List<FavoriteAuthor>>>[];

  @override
  Future<_Detail> getComic(int id) {
    final read = Completer<_Detail>();
    detailReads.add((id, read));
    return read.future;
  }

  void completeDetail(
    int index, {
    bool favorited = false,
    bool authorFavorited = false,
  }) {
    final (id, read) = detailReads[index];
    read.complete((
      comic: Comic(id: id, title: '漫画$id', author: '同作者', favorited: favorited),
      chapters: const <Chapter>[],
      favorited: favorited,
      authorFavorited: authorFavorited,
      progress: null,
    ));
  }

  @override
  Future<List<Comic>> getFavorites() {
    final read = Completer<List<Comic>>();
    favoriteReads.add(read);
    return read.future;
  }

  @override
  Future<List<FavoriteAuthor>> getFavoriteAuthors() {
    final read = Completer<List<FavoriteAuthor>>();
    authorReads.add(read);
    return read.future;
  }

  @override
  Future<void> setFavorite(int comicId, bool favorited) {
    final write = Completer<void>();
    writes.add(write);
    return write.future;
  }

  @override
  Future<void> setAuthorFavorite(String author, bool favorited) =>
      setFavorite(0, favorited);
}

void main() {
  late _FavoriteClient client;
  late ProviderContainer container;
  setUp(() {
    client = _FavoriteClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
  });
  tearDown(() {
    container.dispose();
    client.close();
  });

  test('收藏同目标共享请求，确认后立即更新；后台失败保留确认值，外部刷新仍可更新', () async {
    final subscription = container.listen(comicDetailProvider(1), (_, _) {});
    addTearDown(subscription.close);
    final ready = container.read(comicDetailProvider(1).future);
    client.completeDetail(0);
    await ready;
    final mutations = container.read(favoriteMutationsProvider.notifier);
    final first = mutations.setComicFavorite(comicId: 1, favorited: true);
    final duplicate = mutations.setComicFavorite(comicId: 1, favorited: true);
    expect(identical(first, duplicate), isTrue);
    expect(client.writes, hasLength(1));
    expect(container.read(favoriteMutationsProvider).comicBusy(1), isTrue);
    client.writes.single.complete();
    await first;
    expect(container.read(comicDetailProvider(1)).value!.favorited, isTrue);
    expect(container.read(favoriteMutationsProvider).comicBusy(1), isFalse);
    final refresh = container.read(comicDetailProvider(1).future);
    final failure = expectLater(refresh, throwsException);
    client.detailReads.last.$2.completeError(Exception('刷新失败'));
    await failure;
    expect(container.read(comicDetailProvider(1)).value!.favorited, isTrue);
    container.invalidate(comicDetailProvider(1));
    final next = container.read(comicDetailProvider(1).future);
    client.completeDetail(client.detailReads.length - 1);
    await next;
    expect(container.read(comicDetailProvider(1)).value!.favorited, isFalse);
  });

  test('离开操作页面后仍同步收藏列表；失败不删除条目', () async {
    final list = container.read(favoritesProvider.future);
    client.favoriteReads.single.complete(const [
      Comic(id: 1, title: '漫画1', favorited: true),
    ]);
    await list;
    final mutations = container.read(favoriteMutationsProvider.notifier);
    final failure = mutations.setComicFavorite(comicId: 1, favorited: false);
    final rejected = expectLater(failure, throwsStateError);
    client.writes.last.completeError(StateError('拒绝'));
    await rejected;
    expect(container.read(favoritesProvider).value, hasLength(1));
    final success = mutations.setComicFavorite(comicId: 1, favorited: false);
    client.writes.last.complete();
    await success;
    expect(container.read(favoritesProvider).value, isEmpty);
    final refresh = container.read(favoritesProvider.future);
    client.favoriteReads.last.complete([]);
    await refresh;
  });

  test('切换服务器清空旧详情与收藏，旧变更完成不污染新服务器', () async {
    final detail = container.read(comicDetailProvider(1).future);
    client.completeDetail(0);
    await detail;
    final list = container.read(favoritesProvider.future);
    client.favoriteReads.single.complete(const [Comic(id: 1, title: '旧服务器')]);
    await list;
    final oldMutation = container
        .read(favoriteMutationsProvider.notifier)
        .setComicFavorite(comicId: 1, favorited: true);
    final nextClient = _FavoriteClient(generation: 1);
    addTearDown(nextClient.close);
    container.updateOverrides([
      apiClientProvider.overrideWithValue(nextClient),
    ]);
    expect(container.read(currentComicDetailProvider(1)).value, isNull);
    expect(container.read(currentFavoritesProvider).value, isNull);
    expect(container.read(favoriteMutationsProvider).comicBusy(1), isFalse);
    client.writes.single.complete();
    await oldMutation;
    final nextDetail = container.read(comicDetailProvider(1).future);
    final failed = expectLater(nextDetail, throwsException);
    nextClient.detailReads.single.$2.completeError(Exception('新服务器离线'));
    await failed;
    expect(container.read(currentComicDetailProvider(1)).value, isNull);
    expect(container.read(currentComicDetailProvider(1)).hasError, isTrue);
    container.invalidate(comicDetailProvider(1));
    final retry = container.read(comicDetailProvider(1).future);
    nextClient.completeDetail(1);
    expect((await retry).favorited, isFalse);
    expect(nextClient.writes, isEmpty);
  });

  test('作者确认同步同作者各详情并淘汰首屏旧结果', () async {
    final first = container.read(comicDetailProvider(1).future);
    client.completeDetail(0);
    await first;
    final second = container.read(comicDetailProvider(2).future);
    client.completeDetail(1);
    await second;
    container.read(comicDetailProvider(3));
    final pending = container
        .read(favoriteMutationsProvider.notifier)
        .setAuthorFavorite(author: '同作者', favorited: true);
    client.writes.single.complete();
    await pending;
    expect(
      container.read(comicDetailProvider(1)).value!.authorFavorited,
      isTrue,
    );
    expect(
      container.read(comicDetailProvider(2)).value!.authorFavorited,
      isTrue,
    );
    final newest = container.read(comicDetailProvider(3).future);
    client.completeDetail(2);
    client.completeDetail(client.detailReads.length - 1, authorFavorited: true);
    expect((await newest).authorFavorited, isTrue);
  });
}
