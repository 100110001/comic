import 'dart:async';

import 'package:comic/models/comic.dart';
import 'package:comic/models/favorite_author.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/theme.dart';
import 'package:comic/widgets/comic_card.dart';
import 'package:comic/widgets/reading_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CollectionClient extends ApiClient {
  _CollectionClient() : super(baseUrl: 'http://example.test', generation: 0);
  final comics = <Comic>[
    const Comic(id: 1, title: '第一本', favorited: true),
    const Comic(id: 2, title: '第二本', favorited: true),
  ];
  final authors = <FavoriteAuthor>[
    const FavoriteAuthor(author: '测试作者', comicCount: 2),
  ];
  Completer<void>? mutation;
  Completer<List<Comic>>? refresh;
  int mutations = 0;
  bool failRefresh = false;

  @override
  Future<List<Comic>> getFavorites() async {
    if (failRefresh) throw Exception('刷新失败');
    if (refresh != null) return refresh!.future;
    return List.of(comics);
  }

  @override
  Future<List<FavoriteAuthor>> getFavoriteAuthors() async => List.of(authors);

  @override
  Future<void> setFavorite(int comicId, bool favorited) async {
    mutations++;
    await mutation?.future;
    comics.removeWhere((comic) => comic.id == comicId);
  }

  @override
  Future<void> setAuthorFavorite(String author, bool favorited) async {
    mutations++;
    await mutation?.future;
    authors.removeWhere((item) => item.author == author);
  }
}

void main() {
  late _CollectionClient client;
  late ProviderContainer container;
  setUp(() {
    client = _CollectionClient();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        favoriteAuthorBooksProvider.overrideWith((ref, author) async => []),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    client.close();
  });

  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('收藏页直接取消、等待禁用、失败保留并允许重试', (tester) async {
    await show(tester, const FavoritesList());
    client.mutation = Completer<void>();
    await tester.tap(find.byTooltip('取消收藏').first);
    await tester.pump();
    expect(find.byTooltip('正在取消收藏'), findsOneWidget);
    expect(client.mutations, 1);
    expect(find.byType(ComicCard), findsNWidgets(2));
    client.mutation!.completeError(Exception('网络失败'));
    await tester.pumpAndSettle();
    expect(find.text('取消收藏失败'), findsOneWidget);
    expect(find.byType(ComicCard), findsNWidgets(2));

    client.mutation = null;
    await tester.tap(find.byTooltip('取消收藏').first);
    await tester.pumpAndSettle();
    expect(find.text('第一本'), findsNothing);
    expect(find.text('第二本'), findsOneWidget);
    expect(find.text('收藏的漫画 · 1 本'), findsOneWidget);
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pumpAndSettle();
    expect(find.text('暂无收藏'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('作者收藏页直接取消最后一位作者', (tester) async {
    await show(tester, const FavoriteAuthorsList());
    await tester.tap(find.byTooltip('取消收藏作者'));
    await tester.pumpAndSettle();
    expect(find.text('暂无收藏作者'), findsOneWidget);
    expect(find.text('已取消收藏作者'), findsOneWidget);
    expect(client.mutations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('下拉刷新等待真实请求，失败提示且保留现有收藏', (tester) async {
    await show(tester, const FavoritesList());
    client.refresh = Completer<List<Comic>>();
    var completed = false;
    unawaited(
      tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh()
          .then((_) {
            completed = true;
          }),
    );
    await tester.pump();
    expect(completed, isFalse);
    expect(find.byType(ComicCard), findsNWidgets(2));
    client.refresh!.completeError(Exception('网络失败'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('刷新收藏失败'), findsOneWidget);
    expect(find.byType(ComicCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消已确认但后台刷新失败仍移除卡片', (tester) async {
    await show(tester, const FavoritesList());
    client.failRefresh = true;
    await tester.tap(find.byTooltip('取消收藏').first);
    await tester.pumpAndSettle();
    expect(find.text('第一本'), findsNothing);
    expect(find.text('第二本'), findsOneWidget);
    expect(find.text('收藏的漫画 · 1 本'), findsOneWidget);
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pumpAndSettle();
    expect(find.text('暂无收藏'), findsOneWidget);
    expect(find.text('加载失败'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
