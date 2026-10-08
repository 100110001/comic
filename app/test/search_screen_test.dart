import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comic/providers/search_history_provider.dart';
import 'package:comic/providers/comics_providers.dart';
import 'package:comic/providers/reading_progress_provider.dart';
import 'package:comic/screens/home_screen.dart';
import 'helpers/progress_storage.dart';
import 'package:comic/models/comic.dart';
import 'package:comic/providers/server_provider.dart';
import 'package:comic/screens/search_screen.dart';
import 'package:comic/services/api_client.dart';
import 'package:comic/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchClient extends ApiClient {
  _SearchClient() : super(baseUrl: 'http://example.test', generation: 0);

  bool fail = true;
  final keywords = <String>[];

  @override
  Future<({List<Comic> list, int total})> getComics({
    int pageOffset = 1,
    int pageSize = 20,
    String keyword = '',
    bool random = false,
    int? seed,
  }) async {
    keywords.add(keyword);
    if (fail) throw Exception('测试搜索失败');
    return (list: <Comic>[], total: 0);
  }
}

class _EmptyLibrary extends RandomLibraryNotifier {
  @override
  Future<RandomLibraryState> build() async => const RandomLibraryState(
    seed: 1,
    pageOffset: 1,
    total: 0,
    pageSize: 30,
    comics: [],
  );
}

ProviderContainer _historyContainer(
  _SearchClient client, {
  Future<SharedPreferences>? preferences,
}) => ProviderContainer(
  overrides: [
    apiClientProvider.overrideWithValue(client),
    serverSessionProvider.overrideWith(
      () => ServerSessionNotifier(initialUrl: 'http://example.test'),
    ),
    if (preferences != null)
      searchHistoryPreferencesProvider.overrideWithValue(preferences),
    progressStorageProvider.overrideWithValue(MemoryProgressStorage()),
    randomLibraryProvider.overrideWith(_EmptyLibrary.new),
    recentReadingProvider.overrideWith((ref) async => []),
  ],
);

Widget _historyApp(
  ProviderContainer container,
  Widget home, {
  bool largeText = false,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: buildAppTheme(Brightness.dark),
    builder: largeText
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          )
        : null,
    home: home,
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('作者入口首帧后搜索，失败重试保留关键字', (tester) async {
    final client = _SearchClient();
    addTearDown(client.close);
    final container = _historyContainer(client);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _historyApp(container, const SearchScreen(initialKeyword: '测试作者')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(client.keywords, ['测试作者']);
    expect(find.text('重试'), findsOneWidget);
    expect(container.read(searchHistoryProvider).requireValue, ['测试作者']);
    await container
        .read(searchHistoryStoreProvider.notifier)
        .remember('http://example.test', '后来提交');
    client.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(client.keywords, ['测试作者', '测试作者']);
    expect(find.text('没有找到相关漫画'), findsOneWidget);
    expect(container.read(searchHistoryProvider).requireValue, [
      '后来提交',
      '测试作者',
    ]);
  });

  testWidgets('手机历史回填重搜，切换来源清空输入并显示对应历史', (tester) async {
    final client = _SearchClient()..fail = false;
    addTearDown(client.close);
    final container = _historyContainer(client);
    addTearDown(container.dispose);
    final store = container.read(searchHistoryStoreProvider.notifier);
    await store.remember('http://example.test', '原服务器');
    await store.remember('http://other.test', '另一服务器');
    await tester.pumpWidget(_historyApp(container, const SearchScreen()));
    await tester.pumpAndSettle();
    expect(client.keywords, isEmpty);
    await tester.tap(find.text('原服务器'));
    await tester.pumpAndSettle();
    expect(client.keywords, ['原服务器']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '原服务器',
    );
    await container
        .read(serverSessionProvider.notifier)
        .save('http://other.test');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('另一服务器'), findsOneWidget);
    expect(find.text('原服务器'), findsNothing);
  });

  testWidgets('窄屏大字体长词历史可删除与清空', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _SearchClient();
    addTearDown(client.close);
    final container = _historyContainer(client);
    addTearDown(container.dispose);
    final store = container.read(searchHistoryStoreProvider.notifier);
    await store.remember('http://example.test', '保留词');
    final longWord = List.filled(30, '很长的搜索关键字').join();
    await store.remember('http://example.test', longWord);
    await tester.pumpWidget(
      _historyApp(container, const SearchScreen(), largeText: true),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('删除历史：$longWord'));
    await tester.pumpAndSettle();
    expect(container.read(searchHistoryProvider).requireValue, ['保留词']);
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(container.read(searchHistoryProvider).requireValue, isEmpty);
    expect(find.text('输入关键字搜索漫画或作者'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('历史初始化等待不阻塞搜索请求', (tester) async {
    final client = _SearchClient()..fail = false;
    addTearDown(client.close);
    final preferences = Completer<SharedPreferences>();
    final container = _historyContainer(
      client,
      preferences: preferences.future,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _historyApp(container, const SearchScreen(initialKeyword: '立即搜索')),
    );
    await tester.pumpAndSettle();
    expect(client.keywords, ['立即搜索']);
    preferences.complete(await SharedPreferences.getInstance());
    await tester.pumpAndSettle();
    expect(container.read(searchHistoryProvider).requireValue, ['立即搜索']);
  });

  testWidgets('桌面历史面板回填搜索，刷新不重排，来源切换清空输入', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _SearchClient()..fail = false;
    addTearDown(client.close);
    final container = _historyContainer(client);
    addTearDown(container.dispose);
    final store = container.read(searchHistoryStoreProvider.notifier);
    await store.remember('http://example.test', '桌面关键字');
    await tester.pumpWidget(_historyApp(container, const HomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('桌面关键字'));
    await tester.pumpAndSettle();
    expect(client.keywords, ['桌面关键字']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '桌面关键字',
    );
    await store.remember('http://example.test', '更新的词');
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(client.keywords, ['桌面关键字', '桌面关键字']);
    expect(container.read(searchHistoryProvider).requireValue, [
      '更新的词',
      '桌面关键字',
    ]);
    await container
        .read(serverSessionProvider.notifier)
        .save('http://other.test');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
